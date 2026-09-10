-- Unit tests for tools/lua/json.lua
--
-- This codec only ever runs on the dev machine - inside the game REFramework
-- supplies `json` and JsonIO is the only module allowed to touch it. But it is
-- what reads command_display and writes the candidate documents, so a quiet
-- mistake here corrupts every artifact the offline pipeline produces.
--
-- Three things it is easy to get wrong and impossible to notice: an integer
-- action id coming back as a float and no longer matching a key, a null turning
-- into a value instead of staying absent, and an empty table changing shape
-- between runs.

local t = require("tests.lua.harness")
local json = dofile("tools/lua/json.lua")

-- --- round trips -------------------------------------------------------------

t.group("round trips")

local function round(v)
    return json.decode(json.encode(v))
end

t.eq(round(1), 1, "an integer")
t.eq(round(-42), -42, "a negative integer")
t.eq(round(0.5), 0.5, "a float")
t.eq(round("hello"), "hello", "a string")
t.eq(round(true), true, "true")
t.eq(round(false), false, "false")
t.eq_list(round({ 1, 2, 3 }), { 1, 2, 3 }, "a list")

local obj = round({ a = 1, b = "two", c = { 3, 4 } })
t.eq(obj.a, 1, "an object's number")
t.eq(obj.b, "two", "its string")
t.eq_list(obj.c, { 3, 4 }, "and its nested list")

-- --- an action id stays an integer -------------------------------------------

t.group("integers stay integers")

-- command_display is keyed by decimal action id. If 601 comes back as 601.0 the
-- key stops matching and the catalog silently loses the entry.
local ids = json.decode('{"601": {"x": 1}, "617": {"x": 2}}')
t.ok(ids["601"] ~= nil, "a decimal-string key survives as a string")

local n = json.decode("601")
t.eq(math.type(n), "integer", "a whole number decodes as an integer, not a float")
t.eq(json.encode(601), "601", "and encodes without a decimal point")

t.eq(math.type(json.decode("6.0")), "float", "a written float stays a float")
t.eq(json.encode(6.0), "6.0", "and keeps its point, so it does not become an integer")

-- --- null is absence, not a value --------------------------------------------

t.group("null is absence")

-- The whole pipeline reads nil as unknown. A null that became a sentinel would
-- make "the source does not know" into a value, which is the one thing this
-- project must not do.
local nulled = json.decode('{"startup": null, "on_hit": 3}')
t.is_nil(nulled.startup, "a null field decodes to nil")
t.eq(nulled.on_hit, 3, "while its neighbours come through")
-- A JSON array cannot have a hole in it, so a Lua table that has one is not an
-- array. It encodes as an object, which is lossless.
t.eq(json.encode({ 1, nil, 3 }), '{"1":1,"3":3}', "a numeric table with a hole is an object")
t.eq(json.encode({ 1, 2, 3 }), "[1,2,3]", "while a dense list is a list")

-- This is not a corner case. These documents are full of maps keyed by an
-- integer - counts by route length, partials dropped by depth - and
-- { [2] = 188, [3] = 849 } is a map, not a list missing its first element.
t.eq(json.encode({ [2] = 188, [3] = 849 }), '{"2":188,"3":849}',
     "a map keyed by integers encodes as a map")
local by_length = json.decode(json.encode({ [2] = 188, [3] = 849 }))
t.eq(by_length["2"], 188, "and comes back with string keys, as JSON objects do")

-- --- strings -----------------------------------------------------------------

t.group("strings")

t.eq(round('a "quoted" string'), 'a "quoted" string', "quotes survive")
t.eq(round("back\\slash"), "back\\slash", "backslashes survive")
t.eq(round("line\nbreak\ttab"), "line\nbreak\ttab", "control characters survive")

-- The notation tokens are Chinese, and they are what the whole catalog is keyed
-- on. UTF-8 has to pass through untouched.
local tokens = "2 + \228\184\173"
t.eq(round(tokens), tokens, "UTF-8 notation survives a round trip")
t.eq(json.decode('"\\u4e2d"'), "\228\184\173", "a \\u escape decodes to the same bytes")
t.eq(json.decode('"\\ud83c\\udfae"'), utf8.char(0x1F3AE), "a surrogate pair decodes")

t.eq(json.decode('"a\\/b"'), "a/b", "an escaped slash decodes")

-- --- shape -------------------------------------------------------------------

t.group("empty tables")

-- Lua cannot tell {} the empty list from {} the empty object. Everything empty
-- in these documents is a list, so that is the default, and a caller that needs
-- an object says so.
t.eq(json.encode({}), "[]", "an empty table encodes as a list")
t.eq(json.encode(json.EMPTY_OBJECT), "{}", "unless it is the explicit empty object")
t.eq(json.encode({ a = {} }), '{"a":[]}', "nested, too")

-- --- deterministic output ----------------------------------------------------

t.group("determinism")

-- Sorted keys mean two runs over the same data produce the same bytes, which is
-- what makes a diff between two patches readable and a checksum meaningful.
local a = json.encode({ z = 1, a = 2, m = 3 })
local b = json.encode({ m = 3, a = 2, z = 1 })
t.eq(a, b, "key order does not depend on table iteration order")
t.eq(a, '{"a":2,"m":3,"z":1}', "and the order is sorted")

local indented = json.encode({ a = 1, b = { 2, 3 } }, { indent = "  " })
t.ok(indented:find("\n") ~= nil, "an indent produces line breaks")
t.eq(json.decode(indented).b[2], 3, "and still round trips")

-- --- refusals ----------------------------------------------------------------

t.group("what it refuses")

-- JSON has no NaN or Infinity. Emitting one produces a file some parsers accept
-- and others reject, which is worse than failing here.
t.eq(pcall(json.encode, 0 / 0), false, "NaN is refused")
t.eq(pcall(json.encode, math.huge), false, "so is infinity")
t.eq(pcall(json.encode, print), false, "and a function")

local cyc = {}
cyc.self = cyc
t.eq(pcall(json.encode, cyc), false, "a table containing itself is refused rather than hanging")

t.is_nil(json.decode("{"), "an unterminated object fails")
t.is_nil(json.decode('{"a" 1}'), "a missing colon fails")
t.is_nil(json.decode('[1, 2'), "an unterminated list fails")
t.is_nil(json.decode('"unterminated'), "an unterminated string fails")
t.is_nil(json.decode('{"a":1} trailing'), "trailing content fails")
t.is_nil(json.decode(nil), "and a non-string fails")

local _, err = json.decode("{")
t.ok(type(err) == "string" and #err > 0, "with a reason, not just a nil")

-- --- the real files ----------------------------------------------------------

t.group("the files this exists to read")

-- The one that matters: the actual command_display Zangief catalogue, which is
-- 80 entries of deeply nested objects with Chinese display strings in them.
local raw, rerr = json.load_file(
    "reframework/data/TrainingComboTrials_data/command_display/Zangief.json")
t.ok(raw ~= nil, "the real command_display file decodes: " .. tostring(rerr))
if raw then
    t.eq(raw._meta.schema, "xt.command_display.v1", "with its schema tag intact")
    t.eq(raw._meta.fighter_id, 6, "and an integer fighter id")
    t.eq(math.type(raw._meta.fighter_id), "integer", "that is genuinely an integer")
    t.ok(raw["621"] ~= nil, "and entries keyed by decimal action id")
    t.ok(raw["621"].classic_command.display:find("MP") ~= nil,
         "whose nested display strings survive")

    -- Re-encoding and re-decoding it must not change anything the pipeline
    -- reads. This is the test that catches a codec that is subtly lossy.
    local again = json.decode(json.encode(raw))
    t.eq(again._meta.ac_sha256, raw._meta.ac_sha256, "a full round trip keeps the checksum")
    t.eq(again["621"].classic_command.display, raw["621"].classic_command.display,
         "and the notation")
    local n1, n2 = 0, 0
    for _ in pairs(raw) do n1 = n1 + 1 end
    for _ in pairs(again) do n2 = n2 + 1 end
    t.eq(n2, n1, "and every entry")
end

t.is_nil(json.load_file("does/not/exist.json"), "a missing file returns nil rather than raising")

return t.finish()
