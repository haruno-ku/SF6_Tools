-- Minimal assertion harness for the ComboExplorer Lua unit tests.
-- No dependencies: the point is that `lua tests/lua/run.lua` works on a stock
-- Lua 5.4 install with nothing else present.

local H = { passed = 0, failed = 0, failures = {}, current = "(ungrouped)" }

local function record_pass() H.passed = H.passed + 1 end

local function record_fail(msg, detail)
    H.failed = H.failed + 1
    H.failures[#H.failures + 1] = {
        group = H.current,
        msg = msg or "(no message)",
        detail = detail,
    }
end

function H.group(name)
    H.current = name
    print("")
    print("-- " .. name)
end

function H.ok(cond, msg)
    if cond then
        record_pass()
        print("   ok   " .. tostring(msg))
    else
        record_fail(msg)
        print("   FAIL " .. tostring(msg))
    end
    return cond
end

function H.fail(msg)
    record_fail(msg)
    print("   FAIL " .. tostring(msg))
end

function H.eq(actual, expected, msg)
    if actual == expected then
        record_pass()
        print("   ok   " .. tostring(msg))
        return true
    end
    local detail = ("expected %s, got %s"):format(tostring(expected), tostring(actual))
    record_fail(msg, detail)
    print("   FAIL " .. tostring(msg) .. "  [" .. detail .. "]")
    return false
end

function H.is_nil(actual, msg)
    return H.eq(actual, nil, msg)
end

local function list_str(t)
    if type(t) ~= "table" then return tostring(t) end
    local parts = {}
    for i = 1, #t do parts[i] = tostring(t[i]) end
    return "{" .. table.concat(parts, ",") .. "}"
end

function H.eq_list(actual, expected, msg)
    if type(actual) ~= "table" then
        local detail = "expected a table, got " .. tostring(actual)
        record_fail(msg, detail)
        print("   FAIL " .. tostring(msg) .. "  [" .. detail .. "]")
        return false
    end
    local same = #actual == #expected
    if same then
        for i = 1, #expected do
            if actual[i] ~= expected[i] then same = false break end
        end
    end
    if same then
        record_pass()
        print("   ok   " .. tostring(msg))
        return true
    end
    local detail = ("expected %s, got %s"):format(list_str(expected), list_str(actual))
    record_fail(msg, detail)
    print("   FAIL " .. tostring(msg) .. "  [" .. detail .. "]")
    return false
end

function H.finish()
    print("")
    print(("%d passed, %d failed"):format(H.passed, H.failed))
    if H.failed > 0 then
        print("")
        print("failures:")
        for _, f in ipairs(H.failures) do
            print(("  [%s] %s%s"):format(f.group, f.msg, f.detail and ("  -- " .. f.detail) or ""))
        end
    end
    return H.failed == 0
end

return H
