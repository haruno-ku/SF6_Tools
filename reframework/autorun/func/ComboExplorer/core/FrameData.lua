-- =========================================================
-- ComboExplorer/core/FrameData.lua - external frame data, indexed so a move in
-- the catalog can find its numbers. Pure: takes a decoded table.
-- =========================================================
--
-- WHAT THIS IS AND IS NOT FOR
--
-- Candidate generation only. A frame table saying A recovers before B starts is
-- a reason to try the pair on the real game, never evidence that it works.
-- Nothing here may promote a record past `theoretical`.
--
-- The data also has no idea Modern controls exist - a search of the Zangief
-- file for "modern", "simple" or "assist" finds nothing - so which moves are
-- reachable, and by which button, comes from command_display and only from
-- there. This module supplies startup, recovery and cancel properties for
-- moves that command_display has already decided are reachable.
--
-- THE JOIN IS THE HARD PART
--
-- command_display names a move by its classic display ("2+MP", "LP", "360+HP").
-- The frame source names it by numpad ("2MP", "5LP", "360+HP"). The two agree
-- often enough to be tempting and differ often enough to be dangerous: a bare
-- "LP" is "5LP" there, the "+" is dropped for normals but kept for motions, and
-- some entries carry a distance suffix ("63214KK (Close)").
--
-- So the lookup tries a list of candidate keys and RECORDS WHICH ONE MATCHED
-- and how. A silently fuzzy join would attach the wrong numbers to a move, and
-- wrong numbers are worse than none: no numbers produces an honest unknown,
-- while wrong ones produce a confident candidate that cannot work.
--
-- A move that finds nothing is not dropped. It gets no frame record, and the
-- candidate generator treats that as unknown rather than as "cannot link".

local M = { name = "ComboExplorer.FrameData" }

M.MATCH = {
    EXACT      = "exact",        -- the classic display is already the key
    NO_PLUS    = "no_plus",      -- "2+MP" -> "2MP"
    NEUTRAL_5  = "neutral_5",    -- "LP" -> "5LP"
    PREFIX     = "prefix",       -- "63214KK" -> "63214KK (Close)"
    NONE       = "none",
}

-- Candidate keys for one classic display, in order of confidence. Order
-- matters: an exact hit is never overridden by a fuzzier one.
function M.candidate_keys(classic)
    if type(classic) ~= "string" or classic == "" then return {} end
    local keys = {}
    local seen = {}

    local function add(k, kind)
        if k == nil or k == "" or seen[k] then return end
        seen[k] = true
        keys[#keys + 1] = { key = k, match = kind }
    end

    add(classic, M.MATCH.EXACT)

    local no_plus = classic:gsub("%+", "")
    add(no_plus, M.MATCH.NO_PLUS)

    -- A display that starts with a button rather than a direction is the
    -- neutral version, which the frame source spells with a leading 5.
    local function needs_neutral(s)
        return s:match("^[LMH][PK]") ~= nil or s:match("^[PK][PK]") ~= nil
    end
    if needs_neutral(classic) then
        add("5" .. classic, M.MATCH.NEUTRAL_5)
        add("5" .. no_plus, M.MATCH.NEUTRAL_5)
    end

    return keys
end

-- decoded: { _meta = {...}, moves = { { numpad = "2MP", startup = 8, ... }, ... } }
--
-- Accepts the trimmed shape the fixture generator emits. A different source
-- gets its own adapter producing the same shape; nothing downstream knows
-- which source it came from beyond the provenance block.
function M.index(decoded)
    if type(decoded) ~= "table" or type(decoded.moves) ~= "table" then
        return nil, "not a frame-data table"
    end

    local idx = {
        meta = decoded._meta or {},
        by_key = {},
        keys = {},
        duplicates = {},
    }

    for _, mv in ipairs(decoded.moves) do
        local k = mv.numpad
        if type(k) == "string" and k ~= "" then
            if idx.by_key[k] then
                -- Real in this data: "720+P" appears twice with different
                -- damage, and the distance variants share a stem. Recorded
                -- rather than silently overwritten, because picking one is a
                -- decision and it should be visible.
                idx.duplicates[k] = (idx.duplicates[k] or 1) + 1
            else
                idx.by_key[k] = mv
                idx.keys[#idx.keys + 1] = k
            end
        end
    end
    table.sort(idx.keys)
    return idx
end

-- Looks up one classic display. Returns record, match_info - where match_info
-- always exists and says what was tried, so an unmatched move is a documented
-- unknown rather than a silent gap.
function M.lookup(idx, classic)
    local tried = {}
    if type(idx) ~= "table" or type(idx.by_key) ~= "table" then
        return nil, { matched = false, match = M.MATCH.NONE, tried = tried,
                      reason = "no frame-data index" }
    end

    for _, cand in ipairs(M.candidate_keys(classic)) do
        tried[#tried + 1] = cand.key
        local hit = idx.by_key[cand.key]
        if hit then
            return hit, { matched = true, match = cand.match, key = cand.key, tried = tried }
        end
    end

    -- Last resort, and deliberately last: a key that begins with one of the
    -- candidates followed by a space and a bracket, which is how the source
    -- spells distance variants. Ambiguous by nature, so it says so.
    for _, cand in ipairs(M.candidate_keys(classic)) do
        local matches = {}
        for _, k in ipairs(idx.keys) do
            if k:sub(1, #cand.key + 2) == cand.key .. " (" then
                matches[#matches + 1] = k
            end
        end
        if #matches > 0 then
            return idx.by_key[matches[1]], {
                matched = true, match = M.MATCH.PREFIX, key = matches[1],
                tried = tried, ambiguous = (#matches > 1), alternatives = matches,
            }
        end
    end

    return nil, { matched = false, match = M.MATCH.NONE, tried = tried,
                  reason = "no frame data for this notation" }
end

-- --- normalised access -------------------------------------------------------

-- The frame source records a value it does not have as null rather than
-- guessing, which is the behaviour this whole project is built around. These
-- helpers preserve that: nil out means unknown, and no caller may read it as a
-- number.
local function num(v)
    if type(v) == "number" then return v end
    if type(v) == "string" then return tonumber(v) end
    return nil
end

function M.startup(rec)  return rec and num(rec.startup) or nil end
function M.on_hit(rec)   return rec and num(rec.on_hit) or nil end
function M.on_block(rec) return rec and num(rec.on_block) or nil end
function M.damage(rec)   return rec and num(rec.damage) or nil end

function M.can_cancel_into(rec, kind)
    if not rec or type(rec.cancel) ~= "table" then return nil end   -- unknown, not false
    for _, c in ipairs(rec.cancel) do
        if c == kind then return true end
    end
    return false
end

function M.has_property(rec, prop)
    if not rec or type(rec.properties) ~= "table" then return nil end
    for _, p in ipairs(rec.properties) do
        if p == prop then return true end
    end
    return false
end

-- What is missing from a record, named. Goes straight onto the candidate so a
-- reader can see which of its reasoning rested on data that was not there.
function M.missing(rec)
    local out = {}
    if not rec then
        out[#out + 1] = "no_frame_record"
        return out
    end
    if num(rec.startup) == nil then out[#out + 1] = "startup" end
    if num(rec.on_hit) == nil then out[#out + 1] = "on_hit" end
    if num(rec.damage) == nil then out[#out + 1] = "damage" end
    if type(rec.cancel) ~= "table" then out[#out + 1] = "cancel" end
    if rec.pushback == nil then out[#out + 1] = "pushback" end
    return out
end

-- Coverage across a whole catalog, for the report. A join that quietly matched
-- a third of the moves would otherwise look like a thin edge graph rather than
-- a broken lookup.
function M.coverage(idx, rows)
    local n = { rows = 0, matched = 0, exact = 0, fuzzy = 0, unmatched = 0, ambiguous = 0 }
    local unmatched = {}
    for _, row in ipairs(rows or {}) do
        n.rows = n.rows + 1
        local rec, info = M.lookup(idx, row.classic)
        if rec then
            n.matched = n.matched + 1
            if info.match == M.MATCH.EXACT then n.exact = n.exact + 1 else n.fuzzy = n.fuzzy + 1 end
            if info.ambiguous then n.ambiguous = n.ambiguous + 1 end
        else
            n.unmatched = n.unmatched + 1
            unmatched[#unmatched + 1] = { action_id = row.action_id, classic = row.classic,
                                          tried = info.tried }
        end
    end
    n.unmatched_detail = unmatched
    n.ratio = (n.rows > 0) and (n.matched / n.rows) or 0
    return n
end

return M
