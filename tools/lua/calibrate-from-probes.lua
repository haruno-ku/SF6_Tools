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
-- patch does not - nothing a REFramework process can read reports the build
-- number - so it is a required argument here rather than a default, because the
-- one thing this must not do is invent the identity of a measurement.
--
-- The checksums are taken from the report's own header when it has them.
-- Reading them out of this repository's copy of the catalog instead assumes the
-- two files are the same, which is the assumption a checksum exists to prevent;
-- reports written before the header carried the field fall back to it and say so.
--
-- WHAT IT DOES NOT DO
--
-- It does not conclude anything the probes did not, and it reports the two
-- different kinds of "not settled" separately: an entry a probe covers but could
-- not decide, and an entry no read-only probe can reach at all. Collapsing them
-- would make a five-of-ten profile read as complete, which is the failure this
-- whole register exists to prevent.

local Cli = dofile("tools/lua/cli.lua")

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

opt = Cli.args("calibrate-from-probes", arg, opt)

local function die(msg) Cli.die("calibrate-from-probes", msg) end

-- A build number is an identifier that happens to look like a number, and the
-- shared parser coerces anything numeric. Calibration.document wants a string
-- and is right to: "24176760" and 24176760 are the same build, but a patch
-- label with a leading zero or a dot would not survive the round trip.
if opt.game_patch ~= nil then opt.game_patch = tostring(opt.game_patch) end

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
local header_catalog     -- the catalog the reports say they were measured against
for _, name in ipairs(Cli.list_dir(opt.diagnostics)) do
    if name:match("%-latest%.json$") then
        local doc = json.load_file(opt.diagnostics .. "/" .. name)
        local body = doc and doc.body
        local key = body and WANTED[tostring(body.probe)]
        if key then
            reports[key] = body
            found[#found + 1] = ("%s -> %s"):format(name, key)
            local h = doc.header
            if type(h) == "table" and type(h.catalog) == "table" and h.catalog.ac_sha256 then
                header_catalog = header_catalog or h.catalog
            end
        end
    end
end

if not next(reports) then
    die(("no probe reports under %s. Expected *-latest.json documents whose body.probe "
         .. "is one of A.damage_readability / B.clock / C.reset_cost."):format(opt.diagnostics))
end

-- --- derive ------------------------------------------------------------------

local reg = Provenance.new()
local values, notes = Calibration.from_probes(reports, { provenance = reg })

-- Prefer what the REPORT says it was measured against. Falling back to this
-- repository's copy of the catalog assumes the two are the same file, which is
-- exactly the thing a checksum exists to stop anybody assuming - Probe D
-- confirmed it for this run, but that is a finding, not a guarantee.
local ident_source, ac, bcm
if header_catalog then
    ident_source = "the probe report header"
    ac, bcm = header_catalog.ac_sha256, header_catalog.bcm_sha256
else
    local catalog = json.load_file(Characters.catalog_path(entry))
    if not catalog or type(catalog._meta) ~= "table" then
        die("could not read " .. Characters.catalog_path(entry))
    end
    ident_source = "this repository's catalog (the reports predate the header field)"
    ac, bcm = catalog._meta.ac_sha256, catalog._meta.bcm_sha256
end

local identity = {
    calibration_id = ("probes-%s-%s"):format(entry.catalog:lower(), opt.game_patch),
    game_patch = opt.game_patch,
    ac_sha256 = ac,
    bcm_sha256 = bcm,
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
print("## Identity")
print("  checksums from " .. ident_source)
print("  game patch     " .. opt.game_patch .. "  (given on the command line)")
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

Cli.mkdir(opt.out)

local path = opt.out .. "/latest.json"
local n = json.save_file(path, doc, { indent = "  " })
print("written: " .. path .. "  (" .. tostring(n) .. " bytes)")
print("")
print("Note: install-dev.ps1 excludes the calibration directory from repo -> game")
print("sync on purpose, so committing this does NOT put it on the gaming machine.")
print("Run this tool there as well - the probe reports it reads are the ones that")
print("machine produced.")
