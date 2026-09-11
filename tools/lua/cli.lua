-- =========================================================
-- tools/lua/cli.lua - the frame the dev-machine CLIs share.
-- Dev-machine only, like the rest of tools/. Never shipped into the game.
-- =========================================================
--
-- WHY THIS EXISTS
--
-- audit.lua, explore.lua, survey.lua and calibrate-from-probes.lua each carried
-- their own copy of the same five things: the require shim, the argument loop,
-- mkdir, say() and die(). Four copies of each, and they had already drifted -
-- explore.lua learned to parse "true"/"false" after `--collapse false` turned
-- collapsing ON, and the other three never did.
--
-- Repetition is not the defect. The defect is that the four copies are a
-- standing invitation to fix a bug in one of them.
--
-- AND IT MAKES THEM TESTABLE
--
-- The four CLIs run to about 1700 lines and had no tests at all, while every one
-- of the 23 core modules has one. They are not incidental scripts: the numbers
-- in catalog-audit.md and character-survey.md are what decisions get made from.
-- Nothing below is game-shaped or interactive, so extracting it is how the
-- shared half gets a test.
--
-- WHAT IS NOT HERE
--
-- Report bodies. The four tools report different things, and the only part that
-- is genuinely the same is the frame: collect lines, print them, write them to a
-- file. A shared "render a table" would make three different reports converge on
-- whichever one was written first.

local M = { name = "tools.cli" }

-- --- the require shim --------------------------------------------------------

-- REFramework resolves require("func/X/Y") relative to reframework/autorun, with
-- forward slashes and no extension. Teaching the stock interpreter the same rule
-- means the shipped modules keep the require paths they will actually run under,
-- rather than carrying a second spelling that exists only to satisfy tools - and
-- that would then be the untested one.
--
-- Installed on load, and only once. The guard has to be a global: dofile()
-- re-executes the whole chunk, so a local flag is freshly false every time and
-- a second dofile stacks a second identical searcher. The suite's own
-- convention for a global is the _ce_ prefix.
local function install_searcher()
    if _G._ce_cli_searcher_installed then return end
    _G._ce_cli_searcher_installed = true

    package.path = table.concat({ "./?.lua", "./?/init.lua", package.path }, ";")
    table.insert(package.searchers, 2, function(name)
        if not name:match("^func/") then return nil end
        local path = "reframework/autorun/" .. name .. ".lua"
        local f = io.open(path, "r")
        if not f then return ("\n\tno file '%s'"):format(path) end
        f:close()
        local chunk, err = loadfile(path)
        if not chunk then return "\n\t" .. tostring(err) end
        return chunk, path
    end)
end
install_searcher()

-- --- failure -----------------------------------------------------------------

-- Exposed so a test can capture instead of exiting. Production leaves it alone.
M.exit = os.exit
M.stderr = io.stderr

function M.die(tool, msg)
    M.stderr:write(("%s: %s\n"):format(tostring(tool), tostring(msg)))
    M.exit(1)
end

-- --- arguments ---------------------------------------------------------------

-- `--key value`, plus `--no-key` as a bare false.
--
-- Values are coerced: a number becomes a number, and "true"/"false" become
-- booleans. That last one is not cosmetic - a non-empty string is truthy in Lua,
-- so `--collapse false` used to turn collapsing ON and then record the string
-- "false" in the exported document's own account of the run.
--
-- Returns opt, err. An unknown shape is an error rather than a shrug: a
-- mistyped flag that is silently ignored runs the whole tool with the wrong
-- settings and reports nothing.
function M.parse(argv, defaults)
    local opt = {}
    for k, v in pairs(defaults or {}) do opt[k] = v end

    local i = 1
    while i <= #(argv or {}) do
        local raw = argv[i]
        local key = type(raw) == "string" and raw:match("^%-%-([%w%-_]+)$") or nil
        if not key then
            return nil, ("unrecognised argument %q - options look like --key value")
                :format(tostring(raw))
        end
        key = key:gsub("%-", "_")

        local negated = key:match("^no_(.+)$")
        if negated then
            opt[negated] = false
            i = i + 1
        else
            local v = argv[i + 1]
            if v == nil then
                return nil, ("--%s needs a value"):format((key:gsub("_", "-")))
            end
            if v == "true" or v == "false" then
                opt[key] = (v == "true")
            else
                opt[key] = tonumber(v) or v
            end
            i = i + 2
        end
    end
    return opt
end

-- Parses or dies, which is what every caller wants at the top of a script.
function M.args(tool, argv, defaults)
    local opt, err = M.parse(argv, defaults)
    if not opt then M.die(tool, err) end
    return opt
end

-- --- reports -----------------------------------------------------------------

-- Collects lines and prints them as it goes, so a long run shows progress and
-- still ends with one document to write. The two must not diverge: a report that
-- printed one thing and saved another would be the worst kind of artifact.
function M.report()
    local r = { lines = {} }

    function r:say(fmt, ...)
        local line = select("#", ...) > 0 and fmt:format(...) or fmt
        self.lines[#self.lines + 1] = line
        print(line)
        return line
    end

    function r:text()
        return table.concat(self.lines, "\n") .. "\n"
    end

    function r:write(path)
        local f = io.open(path, "wb")
        if not f then return nil, ("could not open %s"):format(path) end
        f:write(self:text())
        f:close()
        return #self.lines
    end

    return r
end

-- --- filesystem --------------------------------------------------------------

-- No lfs under the stock interpreter, so the platform's own tool does it.
function M.mkdir(path)
    if type(path) ~= "string" or path == "" then return false end
    local win = package.config:sub(1, 1) == "\\"
    local cmd = win
        and ('cmd /c if not exist "%s" mkdir "%s" >nul 2>&1')
            :format((path:gsub("/", "\\")), (path:gsub("/", "\\")))
        or ('mkdir -p "%s"'):format(path)
    os.execute(cmd)
    return true
end

-- Directory listing, which three of the four tools need and two spelled
-- differently. Returns names only, sorted - `ls` order is not guaranteed, and an
-- unsorted listing makes a report differ between runs for no reason.
function M.list_dir(path)
    local out = {}
    local p = io.popen(('ls -1 "%s" 2>/dev/null'):format(path))
    if not p then return out end
    for name in p:lines() do
        if name ~= "" then out[#out + 1] = name end
    end
    p:close()
    table.sort(out)
    return out
end

return M
