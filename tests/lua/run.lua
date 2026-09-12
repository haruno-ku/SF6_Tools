-- ComboExplorer Lua test runner.
--
--   lua tests/lua/run.lua        (from the repo root)
--
-- Only the pure modules are testable this way: anything touching sdk / re /
-- imgui needs the game. That split is deliberate - InputMask, Catalog, the
-- state machines and the scoring logic are written as pure functions precisely
-- so they can be checked here, on the dev machine, instead of on the machine
-- running SF6.

package.path = table.concat({
    "./?.lua",
    "./?/init.lua",
    package.path,
}, ";")

-- REFramework resolves require("func/X/Y") relative to reframework/autorun,
-- with forward slashes and no extension. Teaching the stock interpreter the
-- same rule means the shipped modules can use the paths they will actually run
-- under, rather than carrying a second set of require strings that only exist
-- to satisfy the tests - and that would then be the untested spelling.
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

local H = require("tests.lua.harness")

local SUITES = {
    "tests.lua.test_cli",
    "tests.lua.test_characters",
    "tests.lua.test_json",
    "tests.lua.test_schema",
    "tests.lua.test_provenance",
    "tests.lua.test_inputmask",
    "tests.lua.test_damagetracker",
    "tests.lua.test_clockstats",
    "tests.lua.test_probea",
    "tests.lua.test_catalog",
    "tests.lua.test_framedata",
    "tests.lua.test_candidategenerator",
    "tests.lua.test_graphstore",
    "tests.lua.test_routesearch",
    "tests.lua.test_scoring",
    "tests.lua.test_sequencecompiler",
    "tests.lua.test_exporter",
    "tests.lua.test_resultcollector",
    "tests.lua.test_confirmededge",
    "tests.lua.test_testcontext",
    "tests.lua.test_knowledgedb",
    "tests.lua.test_stagecontrolfsm",
    "tests.lua.test_runnerfsm",
    "tests.lua.test_linkverdict",
    "tests.lua.test_probec",
    "tests.lua.test_catalogaudit",
    "tests.lua.test_calibration",
    "tests.lua.test_canonical",
    "tests.lua.test_route",
    "tests.lua.test_padwatch",
    "tests.lua.test_calibrationfsm",
    -- runtime/, and the first of them. The header above says the pure modules
    -- are what is testable here; CatalogLocator sits in runtime/ because it
    -- needs a file reader and a directory listing, and it takes both as an
    -- argument. Every decision in it is still a decision.
    "tests.lua.test_cataloglocator",
    "tests.lua.test_config",
    "tests.lua.test_jsonio",
    "tests.lua.test_calibrationrunner",
    "tests.lua.test_stagecontrol",
    "tests.lua.test_injector",
    "tests.lua.test_sweep",
}

local total_passed, total_failed = 0, 0
local all_ok = true

for _, suite in ipairs(SUITES) do
    print("========================================")
    print("  " .. suite)
    print("========================================")
    H.reset()
    local ok = require(suite)
    total_passed = total_passed + H.passed
    total_failed = total_failed + H.failed
    if ok == false then all_ok = false end
end

print("")
print("========================================")
print(("  TOTAL: %d passed, %d failed"):format(total_passed, total_failed))
if all_ok and total_failed == 0 then
    print("  ALL SUITES PASSED")
    os.exit(0)
else
    print("  FAILURES PRESENT")
    os.exit(1)
end
