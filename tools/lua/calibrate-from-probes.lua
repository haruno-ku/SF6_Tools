-- =========================================================
-- tools/lua/calibrate-from-probes.lua - turns committed probe reports into a
-- calibration profile.
--
--   lua tools/lua/calibrate-from-probes.lua --game-patch <build> [--character Zangief]
--
-- Needs Lua 5.4 and the committed diagnostics. No game, no network.
-- =========================================================
--
-- WHY THIS EXISTS
--
-- The probes concluded. Five of the ten entries in core/Provenance.lua can be
-- settled from their reports, and two of those five turned out to REFUTE the
-- guess they replaced - reset_settle_ticks is 9 where the guess was 25, and
-- hitstop does advance the tick where the guess said it would not.
--
-- None of that was reaching anything. Calibration.from_probes only ran inside
-- the ImGui panel, its output was never written down, and the register's
-- committed state is still ten unverified entries. So every session started
-- from the guesses, and the offline tools - which never load a register at all -
-- had no way to see a measurement even in principle.
--
-- A measurement nobody can read is not much better than one nobody took.
--
-- WHAT IT REFUSES
--
-- Calibration.document demands calibration_id, game_patch, ac_sha256 and
-- bcm_sha256, and refuses without them: a profile that cannot say which build it
-- was taken on cannot be invalidated when the build changes, it just goes on
-- being believed. The checksums come from the character's catalog. The game
-- patch does not - nothing in a probe report records it, which is a gap worth
-- closing at the writing end - so it is a required argument here rather than a
-- default, because the one thing this must not do is invent the identity of a
-- measurement.
--
-- WHAT IT DOES NOT DO
--
-- It does not conclude anything the probes did not, and it reports the two
-- different kinds of "not settled" separately: an entry a probe covers but could
-- not decide, and an entry no read-only probe can reach at all. Collapsing them
-- would make a five-of-ten profile read as complete, which is the failure this
-- whole register exists to prevent.

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

local json        = dofile("tools/lua/json.lua")
local Characters  = dofile("tools/lua/characters.lua")
local Calibration = require("func/ComboExplorer/core/Calibration")
local Provenance  = require("func/ComboExplorer/core/Provenance")

-- --- arguments ---------------------------------------------------------------

local opt = {
    character = "Zangief",
    diagnostics = "reframework/data/ComboExplorer_data/diagnostics",
    out = "reframework/data/ComboExplorer_data/calibration",
    control_scheme = "modern",
}

local i = 1
while i <= #arg do
    local key = arg[i]:match("^%-%-([%w%-]+)$")
    local v = arg[i + 1]
    if not key or v == nil then
        io.stderr:write("calibrate-from-probes: bad argument near " .. tostring(arg[i]) .. "\n")
        os.exit(2)
    end
    opt[(key:gsub("%-", "_"))] = v
    i = i + 2
end

local function die(msg)
    io.stderr:write("calibrate-from-probes: " .. msg .. "\n")
    os.exit(1)
end

if not opt.game_patch then
    die("--game-patch is required.\n"
        .. "  Nothing in a probe report records which game build it ran on, and a\n"
        .. "  profile that cannot name its build cannot be invalidated when the build\n"
        .. "  changes - it just goes on being believed.\n"
        .. "  The build is recorded by hand in "
        .. "reframework/data/ComboExplorer_data/diagnostics/README.md.")
end

local entry, cerr = Characters.resolve(opt.character)
if not entry then die(tostring(cerr)) end

-- --- the reports -------------------------------------------------------------

-- Matched on what each document says it IS, not on its filename. A report
-- renamed or copied under another name still declares its own probe in the body.
local WANTED = {
    ["A.damage_readability"] = "probe_a",
    ["B.clock"]              = "probe_b",
    ["C.reset_cost"]         = "probe_c",
    ["D.catalog_audit"]      = "probe_d",
}

local reports, found = {}, {}
local listing = io.popen(('ls -1 "%s" 2>/dev/null'):format(opt.diagnostics))
for name in (listing and listing:lines() or function() return nil end) do
    if name:match("%-latest%.json$") then
        local doc = json.load_file(opt.diagnostics .. "/" .. name)
        local body = doc and doc.body
        local key = body and WANTED[tostring(body.probe)]
        if key then
            reports[key] = body
            found[#found + 1] = ("%s -> %s"):format(name, key)
        end
    end
end
if listing then listing:close() end

if not next(reports) then
    die(("no probe reports under %s. Expected *-latest.json documents whose body.probe "
         .. "is one of A.damage_readability / B.clock / C.reset_cost."):format(opt.diagnostics))
end

-- --- derive ------------------------------------------------------------------

local reg = Provenance.new()
local values, notes = Calibration.from_probes(reports, { provenance = reg })

local catalog = json.load_file(Characters.catalog_path(entry))
if not catalog or type(catalog._meta) ~= "table" then
    die("could not read " .. Characters.catalog_path(entry))
end

local identity = {
    calibration_id = ("probes-%s-%s"):format(entry.catalog:lower(), opt.game_patch),
    game_patch = opt.game_patch,
    ac_sha256 = catalog._meta.ac_sha256,
    bcm_sha256 = catalog._meta.bcm_sha256,
    character = entry.catalog,
    control_scheme = opt.control_scheme,
    generated_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
}

local doc, derr = Calibration.document(identity, { values })
if not doc then die(tostring(derr)) end

-- What it is worth, said against a real register rather than assumed.
local applied, rejected = reg:apply_calibration(doc)

-- --- report ------------------------------------------------------------------

print("# Calibration from the committed probe reports")
print("")
print("Derived on the dev machine from reports the gaming PC produced. Nothing here")
print("was measured by this tool; it reads what the probes concluded and writes it")
print("down in the shape Provenance.apply_calibration takes.")
print("")
print("## Reports read")
for _, f in ipairs(found) do print("  " .. f) end
print("")

print("## Settled")
local keys = {}
for k in pairs(doc.values) do keys[#keys + 1] = k end
table.sort(keys)
for _, k in ipairs(keys) do
    local v = doc.values[k]
    local shown = type(v.value) == "table" and json.encode(v.value) or tostring(v.value)
    print(("  %-28s %-9s %s"):format(k, tostring(v.status), shown))
    if v.note then print(("  %-28s %s"):format("", v.note)) end
end
print("")

-- A REFUTED entry is the interesting one: the guess was wrong and the register
-- now holds the measurement instead. Said out loud because a profile that
-- corrects a guess is more valuable than one that confirms it, and easier to
-- miss.
local refuted = {}
for _, k in ipairs(keys) do
    if doc.values[k].status == Provenance.STATUS.REFUTED then refuted[#refuted + 1] = k end
end
if #refuted > 0 then
    print(("## Guesses the measurement overturned (%d)"):format(#refuted))
    for _, k in ipairs(refuted) do
        local was = Provenance.provisional(Provenance.new(), k)
        local now = doc.values[k].value
        print(("  %-28s guessed %-24s measured %s"):format(k,
            type(was) == "table" and json.encode(was) or tostring(was),
            type(now) == "table" and json.encode(now) or tostring(now)))
    end
    print("")
end

-- Two different "not settled"s, and collapsing them would be the lie this tool
-- is supposed to avoid. `notes` is "a probe covers this and could not conclude";
-- the register's remaining unverified entries include everything no probe
-- covers at all. Printing only the first makes a five-of-ten profile read as
-- complete.
print(("## A probe covers it but could not conclude (%d)"):format(#notes))
for _, n in ipairs(notes) do print(("  %-28s %s"):format(n.key, n.reason)) end
if #notes == 0 then print("  (none)") end
print("")

local still = {}
for key, e in pairs(Provenance.snapshot(reg).entries) do
    if e.status == Provenance.STATUS.UNVERIFIED then still[#still + 1] = key end
end
table.sort(still)
print(("## Still unmeasured after this profile (%d of %d)"):format(
    #still, Provenance.summary(reg).total))
for _, k in ipairs(still) do
    print(("  %-28s %s"):format(k, "no read-only probe can settle it - needs the sweep"))
end
print("")

print("## Against a fresh register")
print(("  applied  %d"):format(#applied))
print(("  rejected %d"):format(#rejected))
for _, r in ipairs(rejected) do
    print(("    %s: %s"):format(tostring(r.key), tostring(r.reason)))
end
print("")
local cap_names = { "timing", "damage", "injection", "stage_reset", "probing", "catalog" }
print("## Capabilities this opens")
for _, name in ipairs(cap_names) do
    local cap = Provenance.CAPABILITY[name:upper()]
    if cap then
        local ok, blockers = Provenance.can(reg, cap)
        print(("  %-12s %-6s %s"):format(name, ok and "OPEN" or "blocked",
            ok and "" or table.concat(blockers or {}, ", ")))
    end
end
print("")

-- --- write -------------------------------------------------------------------

os.execute((package.config:sub(1, 1) == "\\")
    and ('cmd /c if not exist "%s" mkdir "%s" >nul 2>&1')
        :format(opt.out:gsub("/", "\\"), opt.out:gsub("/", "\\"))
    or ('mkdir -p "%s"'):format(opt.out))

local path = opt.out .. "/latest.json"
local n = json.save_file(path, doc, { indent = "  " })
print("written: " .. path .. "  (" .. tostring(n) .. " bytes)")
print("")
print("Note: install-dev.ps1 excludes the calibration directory from repo -> game")
print("sync on purpose, so committing this does NOT put it on the gaming machine.")
print("Run this tool there as well - the probe reports it reads are the ones that")
print("machine produced.")
