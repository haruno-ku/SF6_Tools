-- Unit tests for func/ComboExplorer/runtime/CatalogLocator.lua
--
-- Issue #29 estimated that this code "cannot be unit tested on the dev machine,
-- so verification has to happen on the gaming PC - that is the real cost."
-- That was wrong, and the mistake is worth naming because it nearly bought a
-- hardware session for something a test file settles.
--
-- Of the sixty lines, exactly two touch the engine: reading a JSON file and
-- listing a directory. Both arrive as `io`. Everything else - the sanitiser,
-- the three names that are not filenames, the order of the fallback, the
-- fighter_id match, and which of the five sentences comes back - is a decision.
--
-- The decisions matter more than the IO does. The reason this module exists is
-- that the second copy of it collapsed two different failures into one less
-- informative message, and did it on the path the header is about.

local t = require("tests.lua.harness")
local CL = require("func/ComboExplorer/runtime/CatalogLocator")

-- --- a fake machine ----------------------------------------------------------

-- files : path -> decoded table. Anything else reads as absent.
-- opts.no_glob     : a host with no fs at all
-- opts.glob_throws : fs.glob exists and raises
-- opts.glob_junk   : fs.glob returns something that is not a list
local function machine(files, opts)
    opts = opts or {}
    local seen = { loaded = {}, globbed = 0 }
    local io_ = {
        load = function(path)
            seen.loaded[#seen.loaded + 1] = path
            return files[path]
        end,
    }
    if not opts.no_glob then
        io_.glob = function(pattern)
            seen.globbed = seen.globbed + 1
            seen.pattern = pattern
            if opts.glob_throws then error("boom") end
            if opts.glob_junk then return "not a table" end
            local out = {}
            for path in pairs(files) do out[#out + 1] = path end
            table.sort(out)
            return out
        end
    end
    return io_, seen
end

local DIR = CL.DIR
local ZANGIEF = { _meta = { fighter_id = 6 } }
local RYU     = { _meta = { fighter_id = 1 } }

-- --- the happy path ----------------------------------------------------------

t.group("the name is a filename, when it is one")

do
    local io_ = machine({ [DIR .. "Zangief.json"] = ZANGIEF })
    local path, decoded = CL.resolve({ name = "Zangief", id = 6 }, io_)
    t.eq(path, DIR .. "Zangief.json", "a real name resolves to its own file")
    t.eq(decoded, ZANGIEF, "and the contents come back with it")
end

do
    -- Non-alphanumerics are dropped, because this becomes a filename and the
    -- suite sanitises it the same way everywhere else.
    --
    -- Asserted on the path that was ASKED FOR, not on the one that came back.
    -- Written the other way this passed with the sanitiser removed: "Chun-Li"
    -- would miss, fall through to the fighter_id scan, and arrive at the same
    -- file by a different road.
    local io_, seen = machine({ [DIR .. "ChunLi.json"] = { _meta = { fighter_id = 4 } } })
    local path = CL.resolve({ name = "Chun-Li", id = 4 }, io_)
    t.eq(seen.loaded[1], DIR .. "ChunLi.json", "the first read is the sanitised name")
    t.eq(seen.globbed, 0, "and it was found without falling back to the id scan")
    t.eq(path, DIR .. "ChunLi.json", "Chun-Li is looked up as ChunLi")
end

-- --- the names that are not names --------------------------------------------

t.group("a name that was never a filename is not tried as one")

-- This is the whole reason the module exists. On the 2026-08 build the
-- character enum's ToString() returns "ESF_006", and Probe D reported "could
-- not load .../ESF_006.json" - which reads like a missing file rather than like
-- a name nobody should have built a path from.

for _, bad in ipairs({ "ESF_006", "ESF_1", "Unknown", "" }) do
    local io_, seen = machine({ [DIR .. "Zangief.json"] = ZANGIEF })
    local path, decoded = CL.resolve({ name = bad, id = 6 }, io_)
    t.ok(#seen.loaded > 0, ("%q still reaches the catalogs"):format(bad))
    t.eq(seen.loaded[1], DIR .. "Zangief.json",
         ("%q is never tried as a filename - the first read is a globbed one"):format(bad))
    t.eq(path, DIR .. "Zangief.json", ("%q resolves by fighter id instead"):format(bad))
    t.eq(decoded, ZANGIEF, "to the catalog that claims it")
end

do
    -- A name that IS a filename but whose file is absent falls through too. A
    -- character the build ships without is not an error here.
    local io_ = machine({ [DIR .. "Zangief.json"] = ZANGIEF })
    local path = CL.resolve({ name = "Akuma", id = 6 }, io_)
    t.eq(path, DIR .. "Zangief.json", "a name whose file is missing falls back to the id")
end

-- --- the fighter_id fallback -------------------------------------------------

t.group("the catalogs are asked who they describe")

do
    local io_, seen = machine({
        [DIR .. "Ryu.json"] = RYU,
        [DIR .. "Zangief.json"] = ZANGIEF,
    })
    local path, decoded = CL.resolve({ name = "ESF_006", id = 6 }, io_)
    t.eq(path, DIR .. "Zangief.json", "the scan does not stop at the first file")
    t.eq(decoded, ZANGIEF, "it stops at the one that claims the id")
    t.eq(seen.globbed, 1, "and lists the directory exactly once")
end

do
    -- A string id is accepted; _shared_player_info has been seen to carry one.
    local io_ = machine({ [DIR .. "Zangief.json"] = ZANGIEF })
    local path = CL.resolve({ name = "ESF_006", id = "6" }, io_)
    t.eq(path, DIR .. "Zangief.json", "an id that arrives as a string still matches")
end

do
    local io_ = machine({ [DIR .. "Ryu.json"] = RYU })
    local path, why = CL.resolve({ name = "ESF_099", id = 99 }, io_)
    t.is_nil(path, "an id no catalog claims resolves to nothing")
    t.ok(tostring(why):find("no shipped catalog claims fighter_id 99") ~= nil,
         "and says which id went unclaimed: " .. tostring(why))
    t.ok(tostring(why):find("ESF_099") ~= nil, "alongside what P1 called itself")
end

-- --- the five failures are five sentences ------------------------------------

t.group("each way of failing says which way it was")

-- The defect this module was extracted to fix: the calibration sweep's copy
-- answered "P1 reports as X and there is no way to find its catalog" for BOTH
-- "no numeric id" and "fs.glob is unavailable". An operator reading that learns
-- nothing about which way was missing, and the two send them to different
-- places - one is a build with no fs, the other is a player info that never
-- resolved.

local function reason_for(info, files, opts)
    local io_ = machine(files or {}, opts)
    local path, why = CL.resolve(info, io_)
    t.is_nil(path, "no path")
    return tostring(why)
end

do
    local path, why = CL.resolve(nil, machine({}))
    t.is_nil(path, "no info at all resolves to nothing")
    t.ok(tostring(why):find("not resolved yet") ~= nil,
         "and says to start a battle: " .. tostring(why))
end

local no_id  = reason_for({ name = "ESF_006" }, {})
local no_fs  = reason_for({ name = "ESF_006", id = 6 }, {}, { no_glob = true })
local threw  = reason_for({ name = "ESF_006", id = 6 }, {}, { glob_throws = true })
local junk   = reason_for({ name = "ESF_006", id = 6 }, {}, { glob_junk = true })
local absent = reason_for({ name = "ESF_099", id = 99 }, { [DIR .. "Ryu.json"] = RYU })

t.ok(no_id:find("no numeric id") ~= nil, "no id says so: " .. no_id)
t.ok(no_fs:find("fs.glob is unavailable") ~= nil, "no fs says so: " .. no_fs)
t.ok(threw:find("could not list") ~= nil, "a listing that raised says so: " .. threw)
t.ok(junk:find("could not list") ~= nil, "and so does one that returned nonsense")
t.ok(absent:find("no shipped catalog claims") ~= nil, "an unclaimed id says so")

-- The assertion that would have caught the drift. Four distinct situations,
-- four distinct sentences - not one message covering all of them.
local used = {}
for _, why in ipairs({ no_id, no_fs, threw, absent }) do
    t.is_nil(used[why], "this sentence has not already been used for another failure: " .. why)
    used[why] = true
end

-- --- what it asks the host for -----------------------------------------------

t.group("it asks for the directory the suite actually ships")

do
    local io_, seen = machine({ [DIR .. "Ryu.json"] = RYU })
    CL.resolve({ name = "ESF_099", id = 99 }, io_)
    t.eq(seen.pattern, CL.GLOB, "the glob pattern is the module's own constant")
    t.ok(CL.GLOB:find("command_display") ~= nil, "which names the shipped directory")
    t.eq(DIR, "TrainingComboTrials_data/command_display/", "and so does the path prefix")
end

do
    -- A host that can read but not list is one of the five cases, and it must
    -- not be confused with a host that can do neither.
    local io_ = machine({ [DIR .. "Zangief.json"] = ZANGIEF }, { no_glob = true })
    local path = CL.resolve({ name = "Zangief", id = 6 }, io_)
    t.eq(path, DIR .. "Zangief.json",
         "with no glob the name path still works - the fallback is what is lost")
end

-- --- the default host --------------------------------------------------------

t.group("with no io argument at all")

-- Every test above hands in a fake machine, which leaves the real default
-- untested - and the default is where the two failures could quietly collapse
-- again. `resolve` with no io reads through JsonIO, and JsonIO answers for a
-- host with no REFramework in it, which is every machine this suite runs on.
--
-- So this asserts the dev machine's own answer: there is no fs here, and the
-- module has to say THAT rather than "could not list", which would be a listing
-- that failed on a host where no listing was ever possible.

do
    local path, why = CL.resolve({ name = "ESF_006", id = 6 })
    t.is_nil(path, "nothing resolves without a game")
    t.ok(tostring(why):find("fs.glob is unavailable") ~= nil,
         "and it is the absence of fs that is reported, not a failed listing: "
         .. tostring(why))
    t.is_nil(tostring(why):find("could not list"), "which is a different sentence")
end

do
    -- The name path with no io either. JsonIO.load has no JSON reader here, so
    -- it returns nil and the fallback is reached - the same shape as a
    -- character whose file is missing.
    local path, why = CL.resolve({ name = "Zangief" })
    t.is_nil(path, "a name with no id and no reader resolves to nothing")
    t.ok(tostring(why):find("no numeric id") ~= nil,
         "reporting the missing id: " .. tostring(why))
end

-- =========================================================
t.group("the glob literal itself")

-- Every test above hands resolve() its own `glob`, so none of them ever
-- evaluates M.GLOB. It shipped with one backslash at runtime where fs.glob
-- wanted two, the listing came back empty, and the operator was told "no
-- shipped catalog claims fighter_id 6" - a sentence about the data, for a fault
-- in the pattern. Nothing failed loudly; an empty listing is not an error.
do
    -- At runtime the separators must be DOUBLE, because fs.glob takes a regex
    -- and a lone backslash there escapes the next character instead of matching
    -- a separator.
    t.ok(CL.GLOB:find("data\\\\command", 1, true) ~= nil,
         "the separator is escaped for a regex, not left bare: " .. CL.GLOB)
    -- Strip every doubled pair; a lone backslash surviving that is one that
    -- would escape the next letter instead of matching a separator.
    local stripped = CL.GLOB:gsub("\\\\", "")
    t.is_nil(stripped:find("\\", 1, true),
             "and no lone backslash survives, which would escape a letter instead")

    -- The one glob in the suite that is known to return files, for comparison.
    local known_good = "TrainingComboTrials_data\\\\CustomCombos\\\\.*json"
    t.eq(CL.GLOB:match("^[^\\]*(\\+)"), known_good:match("^[^\\]*(\\+)"),
         "the same separator spelling as ComboTrials_Files.lua:151")
end

return t.finish()
