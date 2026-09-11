-- =========================================================
-- ComboExplorer/runtime/CatalogLocator.lua - which shipped command_display
-- describes this player, and its contents.
-- =========================================================
--
-- WHY THIS IS NOT AS SIMPLE AS A FILENAME
--
-- The obvious answer - command_display/<character name>.json - is not enough.
-- _shared_player_info.name is the character enum's ToString() (SharedHooks.lua
-- :132), and on the 2026-08 build that returns the internal key "ESF_006"
-- rather than "Zangief". Measured on hardware: Probe D could load no catalog at
-- all and said "could not load .../ESF_006.json" - an error that reads like a
-- missing file rather than a name that was never a filename.
--
-- The fallback asks the catalogs who they describe rather than carrying another
-- copy of the id->name table. Three already exist in the suite (ComboTrials,
-- DistanceViewer, RSM), each local to a file this module has no business
-- importing from, and a fourth transcription is a fourth thing to update when a
-- character is added. Every shipped catalog carries _meta.fighter_id, and that
-- is the same numbering as _shared_player_info.id - so the data answers it.
--
-- WHY IT LIVES IN ONE FILE NOW
--
-- It was written twice: once in ComboExplorer.lua for Probe D and once in
-- CalibrationRunner for the sweep. Same sanitiser, same three rejected names,
-- same glob literal, same _meta match - and the directory written out four
-- times between them. They had already drifted: the sweep's copy collapsed two
-- different failures into one, less informative message, and it did so on the
-- "ESF_006" path, which is the case the whole header above is about.
--
-- The five failures below are five sentences on purpose. An operator reading
-- "there is no way to find its catalog" learns nothing about which way was
-- missing; "fs.glob is unavailable" and "carries no numeric id" send them to
-- different places.
--
-- WHY IT IS IN runtime/ AND STILL TESTED
--
-- It needs a JSON reader and a directory listing, so it cannot be pure and does
-- not belong in core/. But those are the ONLY two things it needs, and they
-- arrive as `io`. Everything else - the sanitiser, the three names that are not
-- filenames, the order of the fallback, the fighter_id match, and which of the
-- five sentences comes back - is a decision, and decisions are testable on a
-- machine with no game on it. See tests/lua/test_cataloglocator.lua.

local JsonIO = require("func/ComboExplorer/runtime/JsonIO")

local M = { name = "ComboExplorer.CatalogLocator" }

M.DIR = "TrainingComboTrials_data/command_display/"

-- REFramework's fs.glob takes a regex over a path with escaped separators, not
-- a shell glob. Written out once here rather than twice in two callers.
M.GLOB = "TrainingComboTrials_data\\command_display\\.*json"

-- Passed as `io` by a test. A partial table is honoured as given: a table with
-- a `load` and no `glob` is a machine that can read files and cannot list them,
-- which is one of the five cases.
local function reader(io_)
    if io_ == nil then
        -- nil, not JsonIO.glob, when the host has no fs. The two failures
        -- below - "nothing can list here" and "the listing failed" - are
        -- different sentences, and handing back a function that always
        -- returns nil would collapse them into the second one. That
        -- collapse is the defect this module was extracted to fix.
        return JsonIO.load, (JsonIO.can_glob() and JsonIO.glob or nil)
    end
    return io_.load, io_.glob
end

-- info : _shared_player_info, or anything with .name and .id
--
-- Returns path, decoded  or  nil, reason.
function M.resolve(info, io_)
    local load, glob = reader(io_)

    if not info then
        return nil, "P1's character is not resolved yet - start a battle first"
    end

    local name = info.name and tostring(info.name) or ""
    -- Sanitised the way the suite does it, since this becomes a filename.
    local key = (name:gsub("[^%w_]", ""))

    -- An "ESF_nnn" is recognised as the internal key rather than tried as a
    -- filename, so the failures below can say what actually went wrong instead
    -- of reporting a missing file that was never going to be there.
    local looks_like_a_name = key ~= "" and key ~= "Unknown" and not key:match("^ESF_%d+$")
    if looks_like_a_name and load then
        local path = M.DIR .. key .. ".json"
        -- Read RAW. Never through CommandDisplay's slim map, which falls back
        -- simple->motion and would credit ~50 moves with a one-button input
        -- they do not have.
        local decoded = load(path)
        if type(decoded) == "table" then return path, decoded end
    end

    local id = tonumber(info.id)
    if not id then
        return nil, ("P1 reports as %q, which is not a catalog name, and carries no "
            .. "numeric id to fall back on"):format(name)
    end
    if not glob then
        return nil, ("P1 reports as %q and fs.glob is unavailable, so the catalog cannot "
            .. "be found by fighter id"):format(name)
    end

    local ok, files = pcall(glob, M.GLOB)
    if not ok or type(files) ~= "table" then
        return nil, "could not list " .. M.DIR
    end

    for _, path in ipairs(files) do
        local decoded = load and load(path) or nil
        local meta = type(decoded) == "table" and decoded._meta
        if type(meta) == "table" and tonumber(meta.fighter_id) == id then
            return path, decoded
        end
    end

    return nil, ("no shipped catalog claims fighter_id %d (P1 reports as %q)"):format(id, name)
end

return M
