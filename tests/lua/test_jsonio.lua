-- Unit tests for func/ComboExplorer/runtime/JsonIO.lua
--
-- This module is the only one allowed to name `json` or `fs`, and on a machine
-- with no REFramework neither global exists - so half of it degrades and half of
-- it works. Both halves are worth pinning, and neither was.
--
-- `append` and `read_text` use plain Lua io and work here, which is what makes
-- the trial log testable at all. `encode_line` and `decode_line` reach for
-- json.dump_string / json.load_string, which this build does not have, so what
-- is checked is that they REFUSE and say why rather than returning nothing.
--
-- work-split.md claimed this file was tested. It was not; test_json.lua is about
-- tools/lua/json.lua, a different codec that never ships into the game.

local t = require("tests.lua.harness")
local JsonIO = require("func/ComboExplorer/runtime/JsonIO")

-- Written beside the other scratch files the suite already makes, and removed
-- again. A test that leaves a file behind changes the next run's answer.
local TMP = "tests/lua/.jsonio_tmp.jsonl"
local function cleanup() os.remove(TMP) end
local function contents()
    local f = io.open(TMP, "r")
    if not f then return nil end
    local text = f:read("a")
    f:close()
    return text
end

cleanup()

-- --- append -------------------------------------------------------------------

t.group("one line onto the end of a file")

do
    t.eq(JsonIO.append(TMP, "{\"a\":1}"), true, "a line is appended")
    t.eq(JsonIO.append(TMP, "{\"a\":2}"), true, "and another after it")
    t.eq(contents(), "{\"a\":1}\n{\"a\":2}\n", "in order, one per line")
end

do
    -- The newline is added here rather than expected from the caller. JSONL is
    -- one document per line, and a caller that forgot would produce a file that
    -- decodes as one enormous broken record.
    cleanup()
    JsonIO.append(TMP, "{\"a\":1}")
    JsonIO.append(TMP, "{\"a\":2}\n")
    t.eq(contents(), "{\"a\":1}\n{\"a\":2}\n",
         "a line that already ends in a newline does not get a second one")
end

do
    cleanup()
    local ok, why = JsonIO.append(TMP, 42)
    t.eq(ok, false, "a non-string is refused")
    t.ok(tostring(why):find("not a line") ~= nil, "saying so: " .. tostring(why))
    t.is_nil(contents(), "and nothing was created")

    local ok2, why2 = JsonIO.append("", "x")
    t.eq(ok2, false, "an empty path is refused")
    t.ok(tostring(why2):find("no path") ~= nil, tostring(why2))
end

do
    cleanup()
    -- A directory that does not exist. On this machine fs.create_dir is absent,
    -- so the open fails and the reason names the path - which is the whole point
    -- of the design note in the module: if io.open and json.dump_file resolve
    -- from different bases, this fails LOUDLY instead of landing a file
    -- somewhere nobody looks.
    local ok, why = JsonIO.append("tests/lua/.no_such_dir/x.jsonl", "{}")
    t.eq(ok, false, "a path whose directory is not there is refused")
    t.ok(tostring(why):find("could not open") ~= nil,
         "naming the failure rather than pretending: " .. tostring(why))
end

-- --- read_text ----------------------------------------------------------------

t.group("the whole log back, for a resume")

do
    cleanup()
    -- Both returns. Checking only the first passed with a reason bolted on,
    -- and "nil plus a reason" is how this module says something went WRONG -
    -- which a first run has not.
    local missing, why_missing = JsonIO.read_text(TMP)
    t.is_nil(missing,
             "a file that is not there reads as nothing - that is the first run, not an error")
    t.is_nil(why_missing, "and with no reason attached, because nothing failed")

    JsonIO.append(TMP, "{\"a\":1}")
    JsonIO.append(TMP, "{\"a\":2}")
    local text = JsonIO.read_text(TMP)
    t.eq(text, "{\"a\":1}\n{\"a\":2}\n", "and a file that is there comes back whole")

    -- RAW text, not split lines. ResultCollector needs the trailing newline to
    -- tell a finished line from a truncated one: an unterminated last line means
    -- the trial ran and the result was lost, which is not the same as never run.
    t.eq(text:sub(-1), "\n", "with its terminator intact")
end

do
    local nope, why = JsonIO.read_text(nil)
    t.is_nil(nope, "no path, nothing to read")
    t.ok(tostring(why):find("no path") ~= nil, tostring(why))
end

-- --- the two that need the game's json ------------------------------------------

t.group("without REFramework's json, both halves refuse and say which")

-- The asymmetry is deliberate and is the reason these are separate functions.
-- No ENCODER means nothing can be recorded, so a sweep must refuse before its
-- first trial. No DECODER means the sweep runs and repeats work - wasteful, not
-- wrong - so it degrades instead.

do
    t.eq(JsonIO.can_decode(), false, "this build has no json.load_string")

    local nope, why = JsonIO.encode_line({ a = 1 })
    t.is_nil(nope, "so encode_line produces nothing")
    t.ok(tostring(why):find("dump_string") ~= nil,
         "naming the function it needed: " .. tostring(why))

    local nope2, why2 = JsonIO.decode_line("{\"a\":1}")
    t.is_nil(nope2, "and decode_line produces nothing")
    t.ok(tostring(why2):find("load_string") ~= nil,
         "naming its own: " .. tostring(why2))
    t.ok(tostring(why2):find("run again") ~= nil,
         "and what it costs, which is repeated work rather than a wrong answer: "
         .. tostring(why2))
end

do
    t.is_nil(JsonIO.encode_line("not a table"), "a non-table is not a record")
    t.is_nil(JsonIO.decode_line(42), "and a non-string is not a line")
end

-- --- load and glob degrade too ---------------------------------------------------

t.group("the readers that were here before")

do
    local nope, why = JsonIO.load("anything.json")
    t.is_nil(nope, "load finds no reader on this machine")
    t.ok(tostring(why):find("no JSON reader") ~= nil, tostring(why))

    t.is_nil(JsonIO.load(nil), "and refuses a nil path")

    t.eq(JsonIO.can_glob(), false, "there is no fs here")
    t.is_nil(JsonIO.glob("anything"), "so glob lists nothing")
end

cleanup()

return t.finish()
