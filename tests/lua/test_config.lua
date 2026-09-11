-- Unit tests for func/ComboExplorer/runtime/Config.lua
--
-- Every one of the 23 modules under core/ has a test file. None of the five
-- under runtime/ did. The header of tests/lua/run.lua explains the split as
-- "anything touching sdk / re / imgui needs the game" - and Config touches none
-- of them. It names JsonIO and nothing else. It was untested because of where
-- it sits in the tree, not because of what it does.
--
-- What that left unchecked is the type-checked merge. Config's own comment says
-- it exists so a hand-edited file "that turns a number into a string would
-- otherwise reach arithmetic and throw inside a hook, where the error is
-- swallowed" - a failure with no stack trace and no message, on the machine
-- furthest from a debugger.

local t = require("tests.lua.harness")
local Config = require("func/ComboExplorer/runtime/Config")

-- --- a fake disk -------------------------------------------------------------

local function fake_io(opts)
    opts = opts or {}
    local seen = { dumped = {}, dirs = {} }
    return {
        load = function() return opts.file end,
        dump = function(path, tbl, dirs)
            seen.dumped[#seen.dumped + 1] = { path = path, tbl = tbl }
            seen.dirs[#seen.dirs + 1] = dirs
            if opts.fail_all then return false, "disk is full" end
            if opts.fail_stamped and not path:find("latest", 1, true) then
                return false, "disk is full"
            end
            return true
        end,
    }, seen
end

-- Config is a singleton with module-level state, so each block puts back what
-- it changed. Stated rather than left implicit: a test that leaks a setting
-- into the next one is the kind of thing that only fails when the order moves.
local function with_io(io_, fn)
    local saved = Config.io
    Config.io = io_
    local ok, err = pcall(fn)
    Config.io = saved
    if not ok then error(err, 0) end
end

local function reset_data()
    for k, v in pairs(Config.DEFAULTS) do
        Config.data[k] = v
        Config.source[k] = "default"
    end
end

-- --- the defaults ------------------------------------------------------------

t.group("what a fresh install believes")

t.eq(Config.data.enabled, true, "the tool is on by default")
t.eq(Config.data.allow_injection, false,
     "and injection is OFF - the register is the real gate, this is the operator's own")
t.eq(Config.source.allow_injection, "default", "recorded as a default, not as a decision")

do
    -- The rule the file's header is about: nothing unmeasured lives here. After
    -- a merge a value read from JSON is indistinguishable from a default and
    -- from a measured result, so a config file is the one place an unverified
    -- number must never be able to hide.
    for key in pairs(Config.DEFAULTS) do
        t.ok(key:find("tick") == nil or key:find("probe_a_idle") ~= nil,
             ("%q is a preference, not a measured tick count"):format(key))
    end
end

-- --- the merge ---------------------------------------------------------------

t.group("a config file is read, but not believed uncritically")

do
    reset_data()
    with_io(fake_io(), function()
        Config.load({ enabled = false, probe_a_min_samples = 9 })
    end)
    t.eq(Config.data.enabled, false, "a value of the right type is taken")
    t.eq(Config.data.probe_a_min_samples, 9, "including a number")
    t.eq(Config.source.enabled, "config file", "and the source says where it came from")
    t.eq(Config.source.probe_a_min_samples, "config file", "for each one taken")
end

do
    reset_data()
    -- The case the type check exists for. A string where a number belongs
    -- reaches arithmetic inside an input hook, and REFramework swallows the
    -- error: no stack, no message, the probe simply stops counting.
    with_io(fake_io(), function()
        Config.load({ probe_a_idle_ticks = "20", probe_b_min_frames = {} })
    end)
    t.eq(Config.data.probe_a_idle_ticks, Config.DEFAULTS.probe_a_idle_ticks,
         "a string where a number belongs does not reach the data")
    t.eq(Config.data.probe_b_min_frames, Config.DEFAULTS.probe_b_min_frames,
         "nor does a table")

    -- And it is not silent about it, which is the difference between a guard
    -- and a shrug.
    t.ok(tostring(Config.source.probe_a_idle_ticks):find("ignored") ~= nil,
         "the source says it was ignored: " .. tostring(Config.source.probe_a_idle_ticks))
    t.ok(tostring(Config.source.probe_a_idle_ticks):find("string") ~= nil,
         "naming what was in the file")
    t.ok(tostring(Config.source.probe_a_idle_ticks):find("number") ~= nil,
         "and what was expected")
end

do
    reset_data()
    -- A key nobody knows is not an error and is not adopted either. The merge
    -- walks the defaults, so the file cannot introduce settings.
    with_io(fake_io(), function()
        Config.load({ enabled = false, allow_everything = true })
    end)
    t.is_nil(Config.data.allow_everything, "an unknown key is not adopted")
    t.is_nil(Config.source.allow_everything, "and gets no source entry")
    t.eq(Config.data.enabled, false, "while the known key beside it still lands")
end

do
    reset_data()
    -- A key the file leaves out keeps its default AND keeps saying so. The trap
    -- is a merge that marks everything "config file" because a file existed.
    with_io(fake_io(), function() Config.load({ enabled = false }) end)
    t.eq(Config.source.enabled, "config file", "what the file set says so")
    t.eq(Config.source.allow_injection, "default",
         "and what it did not is still a default - a file existing is not a decision")
end

do
    reset_data()
    -- No file at all. The first run of every install.
    with_io(fake_io({ file = nil }), function()
        local data = Config.load()
        t.eq(data, Config.data, "load with no file returns the live table")
    end)
    t.eq(Config.data.enabled, Config.DEFAULTS.enabled, "and every value is still its default")
    t.eq(Config.source.enabled, "default", "recorded as such")

    -- A file that decoded to something that is not a table - a hand-edited
    -- file with a stray character - is the same case, not a crash.
    with_io(fake_io({ file = "garbage" }), function() Config.load() end)
    t.eq(Config.data.enabled, Config.DEFAULTS.enabled, "and so is one that is not a table")
end

-- --- the artifact header -----------------------------------------------------

t.group("every artifact can be attributed")

do
    reset_data()
    local h = Config.header({
        version = "0.1", game_patch = "24176760", calibration_id = "cal-1",
        frame = 99, p1 = "Zangief", catalog = { ac_sha256 = "abc" },
    })
    t.eq(h.game_patch, "24176760", "the patch travels with the artifact")
    t.eq(h.calibration_id, "cal-1", "and the calibration it was measured under")
    t.ok(type(h.catalog) == "table" and h.catalog.ac_sha256 == "abc",
         "and the catalog checksum, which is what a later build is invalidated against")
    t.ok(type(h.written_at) == "string", "with a timestamp")

    -- The config block is not decoration. A probe's numbers mean one thing at
    -- 20 idle ticks and another at 5, and the reader is on a different machine
    -- and cannot ask.
    t.eq(h.config.probe_a_idle_ticks, Config.data.probe_a_idle_ticks,
         "the settings the probes ran under are carried")
    t.ok(type(h.config.sources) == "table", "along with where each came from")
    t.eq(h.config.sources.enabled, Config.source.enabled, "by reference to the live map")
end

do
    -- Called with nothing at all, because a panel that has not resolved a
    -- battle yet still writes diagnostics.
    local h = Config.header()
    t.ok(type(h) == "table", "a header with no context is still a header")
    t.is_nil(h.game_patch, "with the fields it does not know left absent")
    t.ok(type(h.config) == "table", "and the parts it does know still present")
end

-- --- writing an artifact -----------------------------------------------------

t.group("a path is only reported when something was written")

do
    reset_data()
    local io_, seen = fake_io()
    with_io(io_, function()
        local path = Config.write_diag("probe_a", { hello = true }, { version = "0.1" })
        t.ok(path ~= nil, "a successful write returns a path")
        t.ok(tostring(path):find("probe%-a") ~= nil or tostring(path):find("probe_a") ~= nil,
             "naming the artifact: " .. tostring(path))
    end)
    t.eq(#seen.dumped, 2, "two copies are written")

    local stamped, latest = seen.dumped[1].path, seen.dumped[2].path
    t.ok(latest:find("latest", 1, true) ~= nil, "one of them is the stable name")
    t.ok(stamped ~= latest, "and the other is not")
    -- The timestamped copy is the record: a re-run after a patch must not
    -- silently destroy the sample that led to a decision.
    t.ok(stamped:find("%d%d%d%d%d%d%d%dT") ~= nil or stamped:find("unstamped") ~= nil,
         "the record copy carries a timestamp: " .. stamped)

    t.ok(type(seen.dumped[1].tbl.header) == "table", "each carries the header")
    t.eq(seen.dumped[1].tbl.body.hello, true, "and the payload")
end

do
    reset_data()
    local io_, seen = fake_io({ fail_all = true })
    with_io(io_, function()
        local path, why = Config.write_diag("probe_a", {}, {})
        -- The comment this pins: "Reporting a path when nothing was written is
        -- worse than reporting the failure: the operator would go looking for a
        -- file that is not there."
        t.is_nil(path, "when both writes fail, no path is returned")
        t.ok(tostring(why):find("disk") ~= nil, "and the reason comes back: " .. tostring(why))
    end)
    t.eq(#seen.dumped, 2, "both were still attempted")
end

do
    reset_data()
    local io_ = fake_io({ fail_stamped = true })
    with_io(io_, function()
        local path = Config.write_diag("probe_a", {}, {})
        t.ok(path ~= nil, "when only one copy lands, that one is reported")
        t.ok(tostring(path):find("latest", 1, true) ~= nil,
             "and it is the one that actually exists: " .. tostring(path))
    end)
end

do
    reset_data()
    Config.data.write_diag_files = false
    local io_, seen = fake_io()
    with_io(io_, function()
        local path, why = Config.write_diag("probe_a", {}, {})
        t.is_nil(path, "with diagnostics off nothing is written")
        t.ok(tostring(why):find("off") ~= nil, "and it says why: " .. tostring(why))
    end)
    t.eq(#seen.dumped, 0, "the disk was not touched at all")
    reset_data()
end

-- --- the debounce ------------------------------------------------------------

t.group("saving is debounced, and does eventually happen")

do
    reset_data()
    local io_, seen = fake_io()
    with_io(io_, function()
        Config.tick_save()
        t.eq(#seen.dumped, 0, "a clean config writes nothing")

        Config.mark_dirty()
        Config.tick_save()
        t.eq(#seen.dumped, 0, "and a dirty one does not write on the same tick")

        for _ = 1, 61 do Config.tick_save() end
        t.eq(#seen.dumped, 1, "it writes once the timer runs out")

        for _ = 1, 61 do Config.tick_save() end
        t.eq(#seen.dumped, 1, "and not again until something else changes")
    end)
end

return t.finish()
