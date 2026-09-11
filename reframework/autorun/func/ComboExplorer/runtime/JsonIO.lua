-- =========================================================
-- ComboExplorer/runtime/JsonIO.lua - the only Explorer module that names
-- `json` or `fs`. Everything above it takes decoded tables.
-- =========================================================
--
-- WHY A SEAM FOR SOMETHING THIS SMALL
--
-- json.load_file and fs.create_dir exist only inside REFramework. A pure module
-- that reads a path is therefore a pure module that cannot be tested on a
-- machine with no game on it - which is every machine this project is written
-- on. So core/Catalog.build takes a decoded table and never a path, and this
-- file is where the path becomes a table.
--
-- The distinction _G.safe_load_json draws is worth keeping: json.load_file
-- returns nil both for "file missing", which is normal on a first run, and for
-- "malformed JSON", which is a user who broke it by hand. safe_load_json
-- separates the two and records the second in the menu-visible error list.

local json = json
local fs = fs

local M = { name = "ComboExplorer.JsonIO" }

-- Returns table | nil, reason. Paths are relative to reframework/data/.
function M.load(path)
    if type(path) ~= "string" or path == "" then return nil, "no path" end

    if type(_G.safe_load_json) == "function" then
        local ok, data = pcall(_G.safe_load_json, path)
        if ok and type(data) == "table" then return data end
        if ok then return nil, "missing or malformed" end
        return nil, tostring(data)
    end

    if json and json.load_file then
        local ok, data = pcall(json.load_file, path)
        if ok and type(data) == "table" then return data end
        return nil, ok and "missing or malformed" or tostring(data)
    end

    return nil, "no JSON reader available"
end

-- One record to one line of text, for the trial log.
--
-- ResultCollector takes `encode` as an injected function and names no json
-- module itself. This is where the name lives, because this file is the only
-- one allowed to hold it.
--
-- tools/lua/json.lua is NOT an option here and its own header says so: it exists
-- for the offline machine, install-dev.ps1 never copies it, and a second encoder
-- inside reframework/autorun would be two implementations whose output could
-- drift.
--
-- json.dump_string is not used anywhere else in the suite - 38 calls to
-- dump_file and 30 to load_file, and none to this - so whether this build's
-- REFramework provides it is unverified. It is checked ONCE at the start of a
-- sweep rather than per record: a sweep that cannot encode must refuse before
-- the first trial, not discover it an hour in with the results gone.
function M.encode_line(tbl)
    if type(tbl) ~= "table" then return nil, "not a record" end
    if not (json and json.dump_string) then
        return nil, "this build's REFramework has no json.dump_string, so a trial "
            .. "record cannot be turned into a line"
    end
    local ok, text = pcall(json.dump_string, tbl)
    if not ok then return nil, tostring(text) end
    if type(text) ~= "string" then return nil, "the encoder returned no text" end
    -- A record that encoded to several lines would break the file it is being
    -- appended to: one document per line is the whole format.
    text = text:gsub("[\r\n]+", " ")
    return text
end

-- One line onto the end of a file, for the trial log.
--
-- ResultCollector takes `append` as an injected function and refuses to exist
-- without one: "a collector that cannot write is a sweep whose results do not
-- exist". It wants one line at a time and it wants to know whether the line
-- landed - a writer that returns nothing counts as having failed, because
-- believing a write that did not happen is worse than one spurious re-run.
--
-- json.dump_file cannot do this: it writes whole documents. So this is plain
-- Lua io, which several scripts in the suite already use
-- (SF6_DistanceViewer.lua:2780, SheldonsBoxes.lua:1146, SF6_RecordingSlotManager
-- .lua:1659) - it is available inside REFramework.
--
-- WHAT IS NOT KNOWN, AND WHY THIS FAILS LOUDLY INSTEAD OF GUESSING
--
-- json.dump_file resolves relative to reframework/data/. io.open resolves
-- relative to something this project has not measured: the suite's own callers
-- use both shapes - "reframework\\aa_debug_log.txt" in one and
-- "SF6_TrainingRemoteControl_data/..." in another - which is consistent with
-- either answer and proves neither.
--
-- Rather than pick one, the directory is created through fs.create_dir, which
-- IS data-relative, and then io.open is asked for the same path. If the two
-- bases disagree the directory will not be there from io.open's point of view,
-- the open fails, and this returns false with the reason. A sweep that cannot
-- write stops at the first trial with a message instead of running for an hour
-- into a file nobody can find.
--
-- The first hardware run settles it either way, and the answer belongs in
-- Provenance once it is known.
function M.append(path, line, dirs)
    if type(path) ~= "string" or path == "" then return false, "no path" end
    if type(line) ~= "string" then return false, "not a line of text" end

    if fs and fs.create_dir then
        for _, d in ipairs(dirs or {}) do pcall(fs.create_dir, d) end
    end

    local f, err = io.open(path, "a")
    if not f then
        return false, ("could not open %q for append: %s"):format(path, tostring(err))
    end

    local ok, werr = pcall(function()
        f:write(line)
        -- The newline is added here rather than expected from the caller: JSONL
        -- is one document per line, and a caller that forgot would produce a
        -- file that decodes as one enormous broken record.
        if line:sub(-1) ~= "\n" then f:write("\n") end
        -- Flushed per line on purpose. A buffer holding the last twenty results
        -- is exactly the twenty results a crash takes.
        f:flush()
    end)
    f:close()

    if not ok then return false, tostring(werr) end
    return true
end

-- Whether this host can list a directory at all, as opposed to whether a
-- particular listing worked. A caller that cannot tell those apart ends up
-- reporting "could not list" on a machine where nothing was ever going to list,
-- which is a different problem with a different fix.
function M.can_glob()
    return (fs ~= nil and fs.glob ~= nil)
end

-- Lists the files matching a REFramework path regex. Here rather than at the
-- call sites because this file's header says it is the only module that names
-- `json` or `fs`, and two callers were breaking that.
function M.glob(pattern)
    if not M.can_glob() then return nil end
    local ok, files = pcall(fs.glob, pattern)
    if not ok or type(files) ~= "table" then return nil end
    return files
end

-- Creates the directory chain first, because json.dump_file will not.
-- `dirs` is the list of directories to ensure, outermost first.
function M.dump(path, tbl, dirs)
    if type(path) ~= "string" or path == "" then return false, "no path" end
    if fs and fs.create_dir then
        for _, d in ipairs(dirs or {}) do pcall(fs.create_dir, d) end
    end
    local ok, err = pcall(json.dump_file, path, tbl)
    if not ok then return false, tostring(err) end
    return true
end

return M
