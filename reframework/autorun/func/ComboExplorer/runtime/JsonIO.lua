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
