-- =========================================================
-- tools/lua/json.lua - JSON for the OFFLINE CLI ONLY.
-- Never shipped into reframework/. In the game, REFramework provides `json`.
-- =========================================================
--
-- WHY THIS EXISTS AND WHY IT STAYS HERE
--
-- The offline pipeline runs on a machine with no game on it, so it has to read
-- command_display and the frame source and write the candidate documents by
-- itself. Inside the game none of that is needed: REFramework's own `json` is
-- there, and JsonIO is the only module allowed to touch it. Putting a second
-- JSON implementation into reframework/autorun would mean two encoders whose
-- output could drift, so this one lives in tools/ and install-dev.ps1 never
-- copies it.
--
-- THE EMPTY TABLE PROBLEM
--
-- Lua cannot tell {} the empty list from {} the empty object, and guessing
-- wrongly changes the shape of a document. Encoding here defaults an empty
-- table to [], because every empty thing in these documents is a list -
-- candidates, reasons, unknowns, steps - and a caller that needs {} passes an
-- explicit marker.
--
-- The related question, a table with numeric keys that are not 1..n, is settled
-- the other way: it is an object. See shape_of.
--
-- ORDERING
--
-- Object keys are sorted. Two runs over the same data then produce
-- byte-identical files, which is what makes a diff between two patches
-- readable and a checksum meaningful.

local M = { name = "tools.json" }

-- A table that must encode as {} even when empty.
M.EMPTY_OBJECT = setmetatable({}, { __tostring = function() return "{}" end })

-- --- encoding ----------------------------------------------------------------

local ESCAPES = {
    ['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f",
    ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t",
}

local function escape(s)
    return (s:gsub('[%c"\\]', function(c)
        return ESCAPES[c] or ("\\u%04x"):format(c:byte())
    end))
end

-- A table is a list only when its keys are exactly 1..n. Anything else is an
-- object, including a table whose keys are all numbers but not contiguous.
--
-- That last case is not a corner: these documents are full of maps keyed by an
-- integer - counts by route length, partials dropped by depth - and
-- { [2] = 188, [3] = 849 } is a map, not a list with a missing first element.
--
-- A JSON array cannot have a hole in it, so a Lua table that has one is not an
-- array by definition, and encoding it as an object is the only lossless answer
-- available. It comes back with string keys, which is what JSON objects have.
local function shape_of(t)
    local n = 0
    for k in pairs(t) do
        if type(k) ~= "number" then return "object" end
        n = n + 1
    end
    if n == 0 then return "array" end       -- empty defaults to a list; see above
    for i = 1, n do if t[i] == nil then return "object" end end
    return "array"
end

local function encode_number(v)
    if v ~= v or v == math.huge or v == -math.huge then
        -- JSON has no NaN or Infinity. Emitting one produces a file that some
        -- parsers accept and others reject, which is worse than failing here.
        error("cannot encode " .. tostring(v) .. " as JSON", 0)
    end
    if math.type(v) == "integer" then return tostring(v) end
    -- %.17g round-trips a double exactly; trailing ".0" keeps a whole float
    -- from silently becoming an integer on the way back.
    local s = ("%.17g"):format(v)
    if not s:find("[%.eE]") then s = s .. ".0" end
    return s
end

local function encode(v, indent, level, seen)
    local t = type(v)
    if v == nil then return "null" end
    if t == "boolean" then return v and "true" or "false" end
    if t == "number" then return encode_number(v) end
    if t == "string" then return '"' .. escape(v) .. '"' end
    if t ~= "table" then
        error("cannot encode a " .. t .. " as JSON", 0)
    end

    if seen[v] then error("cannot encode a table that contains itself", 0) end
    seen[v] = true

    local nl, pad, pad2 = "", "", ""
    if indent then
        nl = "\n"
        pad = string.rep(indent, level)
        pad2 = string.rep(indent, level + 1)
    end

    local shape = (v == M.EMPTY_OBJECT) and "object" or shape_of(v)

    local out
    if shape == "array" then
        if #v == 0 then
            out = "[]"
        else
            local parts = {}
            for i = 1, #v do
                parts[i] = pad2 .. encode(v[i], indent, level + 1, seen)
            end
            out = "[" .. nl .. table.concat(parts, "," .. nl) .. nl .. pad .. "]"
        end
    else
        local keys = {}
        for k in pairs(v) do
            if type(k) == "string" then keys[#keys + 1] = k
            elseif type(k) == "number" then keys[#keys + 1] = k
            else error("cannot encode a " .. type(k) .. " key as JSON", 0) end
        end
        -- Sorted, so the same data always gives the same bytes. Mixed key types
        -- are compared as strings rather than erroring: command_display is keyed
        -- by decimal action id, which arrives as either.
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        if #keys == 0 then
            out = "{}"
        else
            local parts = {}
            for i, k in ipairs(keys) do
                parts[i] = pad2 .. '"' .. escape(tostring(k)) .. '":'
                    .. (indent and " " or "")
                    .. encode(v[k], indent, level + 1, seen)
            end
            out = "{" .. nl .. table.concat(parts, "," .. nl) .. nl .. pad .. "}"
        end
    end

    seen[v] = nil
    return out
end

-- opts.indent : a string, e.g. "  ". nil for the compact form.
function M.encode(value, opts)
    opts = opts or {}
    return encode(value, opts.indent, 0, {})
end

-- --- decoding ----------------------------------------------------------------

local function skip_ws(s, i)
    local _, j = s:find("^[ \t\r\n]*", i)
    return (j or i - 1) + 1
end

local decode_value

local UNESCAPES = {
    ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f",
    n = "\n", r = "\r", t = "\t",
}

local function decode_string(s, i)
    -- i points at the opening quote.
    local buf = {}
    i = i + 1
    while true do
        local c = s:sub(i, i)
        if c == "" then error("unterminated string", 0) end
        if c == '"' then return table.concat(buf), i + 1 end
        if c == "\\" then
            local e = s:sub(i + 1, i + 1)
            if e == "u" then
                local hex = s:sub(i + 2, i + 5)
                local cp = tonumber(hex, 16)
                if not cp then error("bad \\u escape at " .. i, 0) end
                -- Surrogate pairs, which is how a JSON file spells anything
                -- outside the BMP. The Chinese notation tokens are inside it,
                -- but the frame source is not guaranteed to be.
                if cp >= 0xD800 and cp <= 0xDBFF and s:sub(i + 6, i + 7) == "\\u" then
                    local lo = tonumber(s:sub(i + 8, i + 11), 16)
                    if lo and lo >= 0xDC00 and lo <= 0xDFFF then
                        cp = 0x10000 + (cp - 0xD800) * 0x400 + (lo - 0xDC00)
                        i = i + 6
                    end
                end
                buf[#buf + 1] = utf8.char(cp)
                i = i + 6
            else
                local u = UNESCAPES[e]
                if u == nil then error("bad escape \\" .. e .. " at " .. i, 0) end
                buf[#buf + 1] = u
                i = i + 2
            end
        else
            local j = s:find('["\\]', i)
            if not j then error("unterminated string", 0) end
            buf[#buf + 1] = s:sub(i, j - 1)
            i = j
        end
    end
end

local function decode_number(s, i)
    local j = s:find("[^%-%+0-9eE%.]", i) or (#s + 1)
    local text = s:sub(i, j - 1)
    local n = tonumber(text)
    if n == nil then error("bad number " .. text .. " at " .. i, 0) end
    -- An integer stays an integer, so an action id does not come back as 601.0
    -- and stop matching a key.
    if not text:find("[%.eE]") then n = math.tointeger(n) or n end
    return n, j
end

decode_value = function(s, i)
    i = skip_ws(s, i)
    local c = s:sub(i, i)
    if c == "" then error("unexpected end of input", 0) end
    if c == "{" then
        local obj = {}
        i = skip_ws(s, i + 1)
        if s:sub(i, i) == "}" then return obj, i + 1 end
        while true do
            i = skip_ws(s, i)
            if s:sub(i, i) ~= '"' then error("expected a key at " .. i, 0) end
            local key
            key, i = decode_string(s, i)
            i = skip_ws(s, i)
            if s:sub(i, i) ~= ":" then error("expected ':' at " .. i, 0) end
            local val
            val, i = decode_value(s, i + 1)
            obj[key] = val
            i = skip_ws(s, i)
            local d = s:sub(i, i)
            if d == "," then i = i + 1
            elseif d == "}" then return obj, i + 1
            else error("expected ',' or '}' at " .. i, 0) end
        end
    elseif c == "[" then
        local arr = {}
        i = skip_ws(s, i + 1)
        if s:sub(i, i) == "]" then return arr, i + 1 end
        while true do
            local val
            val, i = decode_value(s, i)
            arr[#arr + 1] = val
            i = skip_ws(s, i)
            local d = s:sub(i, i)
            if d == "," then i = i + 1
            elseif d == "]" then return arr, i + 1
            else error("expected ',' or ']' at " .. i, 0) end
        end
    elseif c == '"' then
        return decode_string(s, i)
    elseif s:sub(i, i + 3) == "true" then
        return true, i + 4
    elseif s:sub(i, i + 4) == "false" then
        return false, i + 5
    elseif s:sub(i, i + 3) == "null" then
        -- Genuinely absent, and it stays absent: the whole pipeline treats nil
        -- as unknown, and turning null into a sentinel would make it a value.
        return nil, i + 4
    else
        return decode_number(s, i)
    end
end

function M.decode(text)
    if type(text) ~= "string" then return nil, "not a string" end
    local ok, value, i = pcall(decode_value, text, 1)
    if not ok then return nil, value end
    i = skip_ws(text, i)
    if i <= #text then return nil, "trailing content at " .. i end
    return value
end

-- --- files -------------------------------------------------------------------

function M.load_file(path)
    local f, err = io.open(path, "rb")
    if not f then return nil, err end
    local text = f:read("a")
    f:close()
    -- A UTF-8 BOM is legal in a file and illegal in JSON.
    text = text:gsub("^\239\187\191", "")
    return M.decode(text)
end

function M.save_file(path, value, opts)
    local text = M.encode(value, opts or { indent = "  " })
    local f, err = io.open(path, "wb")
    if not f then return nil, err end
    f:write(text)
    f:write("\n")
    f:close()
    return #text + 1
end

return M
