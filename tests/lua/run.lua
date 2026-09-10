-- ComboExplorer Lua test runner.
--
--   lua tests/lua/run.lua        (from the repo root)
--
-- Only the pure modules are testable this way: anything touching sdk / re /
-- imgui needs the game. That split is deliberate -- InputMask, Catalog and the
-- scoring logic are written as pure functions precisely so they can be checked
-- here, on the dev machine, instead of on the machine running SF6.

package.path = table.concat({
    "./?.lua",
    "./?/init.lua",
    package.path,
}, ";")

local SUITES = {
    "tests.lua.test_inputmask",
}

local all_ok = true
for _, suite in ipairs(SUITES) do
    print("========================================")
    print("  " .. suite)
    print("========================================")
    local ok = require(suite)
    if ok == false then all_ok = false end
end

print("")
print("========================================")
if all_ok then
    print("  ALL SUITES PASSED")
    os.exit(0)
else
    print("  FAILURES PRESENT")
    os.exit(1)
end
