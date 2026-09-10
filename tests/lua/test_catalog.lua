-- Unit tests for func/ComboExplorer/core/Catalog.lua
--
-- Run against the REAL Zangief command_display entries, not invented ones. The
-- failure this code exists to prevent is data-shaped: a move that quietly drops
-- out, or one credited with a one-button input it does not have. Neither shows
-- up against a fixture written to match the author's own assumptions.

local t = require("tests.lua.harness")
local Catalog = require("func/ComboExplorer/core/Catalog")

local RAW = dofile("tests/lua/fixtures/zangief_catalog.lua")
local cat, problems = Catalog.build(RAW)

-- --- it builds ---------------------------------------------------------------

t.group("build")

t.ok(cat ~= nil, "the real catalog builds")
t.eq(cat.character, "Zangief", "character carried through")
t.eq(cat.fighter_id, 6, "fighter id carried through")
t.eq(cat.counts.entries, 80, "all 80 entries seen")

-- The AC/BCM checksums are what lets a recorded dataset be invalidated when the
-- game data behind it changes. An action id measured against one pair is not
-- evidence about another.
t.ok(cat.ac_sha256 ~= nil, "the AC checksum is carried")
t.ok(cat.bcm_sha256 ~= nil, "the BCM checksum is carried")

t.eq(#problems, 0, "no entry defeated the classifier (" ..
     (problems[1] and problems[1].reason or "") .. ")")

-- --- the slim-map regression -------------------------------------------------

t.group("the slim map would lie about simple inputs")

-- What func/ComboTrials/CommandDisplay.lua does when it builds its slim map:
--     item.commands = { simple = simple or manual, motion = manual or simple }
--     item.simple = nil ; item.motion = nil
-- Reproduced here so the difference is demonstrated on real data rather than
-- asserted from a comment.
local function slim_map_simple(entry)
    local simple = entry.simple_command and entry.simple_command.display
    local manual = entry.motion_command and entry.motion_command.display
    if not (simple or manual) then return nil end
    return simple or manual        -- <- the fallback
end

local motion_only, slim_would_claim = 0, 0
for key, entry in pairs(RAW) do
    if tostring(key):match("^%d+$") then
        local has_simple = entry.simple_command ~= nil
        local has_motion = entry.motion_command ~= nil
        if has_motion and not has_simple then
            motion_only = motion_only + 1
            if slim_map_simple(entry) then slim_would_claim = slim_would_claim + 1 end
        end
    end
end

t.ok(motion_only >= 40, "Zangief has a large motion-only population (" .. motion_only .. ")")
t.eq(slim_would_claim, motion_only,
     "the slim map would report a simple input for EVERY one of them")

-- And the catalog does not. This is the whole point: pressing SP for a move
-- that needs a full motion produces nothing, and the trial is then recorded as
-- "these moves do not link".
local simple_rows = {}
for _, row in ipairs(cat.rows) do
    if row.input_method == "simple" then simple_rows[row.action_id] = true end
end

local false_positives = 0
for key, entry in pairs(RAW) do
    if tostring(key):match("^%d+$") then
        if entry.motion_command and not entry.simple_command and simple_rows[tonumber(key)] then
            false_positives = false_positives + 1
        end
    end
end
t.eq(false_positives, 0, "the catalog credits none of them with a simple input")

-- --- input methods are flags, not an enum -----------------------------------

t.group("one row per action id and input method")

local by_id = {}
for _, row in ipairs(cat.rows) do
    by_id[row.action_id] = by_id[row.action_id] or {}
    by_id[row.action_id][row.input_method] = row
end

-- 940 is SPD: reachable by the one-button Special AND by the full 360 motion.
-- Those are two different inputs producing the same action, and each has to be
-- probed on its own.
t.ok(by_id[940] ~= nil, "SPD (940) is present")
t.ok(by_id[940].simple ~= nil, "with a simple row")
t.ok(by_id[940].manual ~= nil, "and a manual row")
t.eq(by_id[940].simple.notation, "SP", "the simple notation is the shortcut")
t.ok(by_id[940].manual.notation:find("360", 1, true) ~= nil, "the manual notation is the motion")

-- 945 is the OD version: "AUTO + SP" is both assist and special.
t.ok(by_id[945] ~= nil, "945 is present")
t.ok(by_id[945].assist ~= nil, "AUTO + SP produces an assist row")
t.ok(by_id[945].simple ~= nil, "and a simple row - the two are not exclusive")

-- A plain ground normal has exactly one way in.
t.ok(by_id[621] ~= nil, "2MP (621) is present")
t.ok(by_id[621].manual ~= nil, "as a manual row")
t.is_nil(by_id[621].simple, "with no simple row")

-- --- exclusions --------------------------------------------------------------

t.group("context-dependent actions are excluded, with a reason")

local function excluded_reason(action_id, method)
    local row = by_id[action_id] and by_id[action_id][method or "manual"]
    return row and row.exclusion
end

-- Modern cannot reach these at all.
t.eq(cat.counts.classic_only, 9, "nine entries are classic_only, as the catalog says")
for _, id in ipairs({ 600, 613, 615, 631, 685 }) do
    local rows = by_id[id]
    if rows then
        for _, row in pairs(rows) do
            t.eq(row.exclusion, "classic_only", ("%d is excluded as classic_only"):format(id))
        end
    end
end

-- Target-combo derivations: ">" means a preceding action is required, so a
-- standalone probe can never produce them.
t.eq(excluded_reason(605), "followup", "605 (>MP) is a follow-up")
t.eq(excluded_reason(606), "followup", "606 (>MP) is a follow-up")
t.eq(excluded_reason(679), "followup", "679 (>MK) is a follow-up")
t.eq(excluded_reason(680), "followup", "680 (>MK) is a follow-up")

-- Assist-combo steps: pressing AUTO+L fires a whole auto-combo string, not one
-- move, so probing it would corrupt the result rather than fail cleanly.
t.eq(excluded_reason(628, "assist"), "assist_combo", "628 is an assist-combo step")
t.eq(excluded_reason(629, "assist"), "assist_combo", "629 is an assist-combo step")

-- Air, throws, movement and system labels.
t.eq(excluded_reason(640), "air", "j.LP is air")
t.eq(excluded_reason(716), "throw", "716 is a throw")
t.eq(excluded_reason(17), "system", "66 (dash) is movement/system")

-- Drive Impact is written "6+DI", which reads as a command normal if the
-- notation shape is checked before the system vocabulary. It was in the ground
-- normals until this test existed.
t.eq(excluded_reason(850), "system", "6+DI is a system action, not a command normal")
t.eq(excluded_reason(855), "system", "DI is a system action")
t.eq(excluded_reason(501), "system", "RAW DR is a system action")
t.eq(excluded_reason(504), "system", "DRC is a system action")

-- Nothing excluded is silently dropped: every one is still in the catalog with
-- its reason, because MVP 1 will want exactly this list.
local total = 0
for _, n in pairs(cat.counts.by_exclusion) do total = total + n end
t.eq(total, cat.counts.excluded, "every exclusion is accounted for by a reason")
t.ok(cat.counts.excluded > 0, "and there are some")
t.ok(#Catalog.excluded(cat, "followup") >= 4, "the follow-ups can be listed back")

-- --- what survives -----------------------------------------------------------

t.group("the probeable set")

local probeable = Catalog.probeable(cat)
t.ok(#probeable > 0, "something survives (" .. #probeable .. " rows)")

for _, row in ipairs(probeable) do
    t.ok(row.control_support == "classic_modern",
         ("probeable row %d is Modern-usable"):format(row.action_id))
end

-- The first target: Modern ground normals, manual input only.
--
-- Scope is the caller's decision, not the catalog's. Assist rows are
-- performable from neutral as far as the data goes, but whether Assist+L
-- produces the single move named or starts the whole auto-combo string is not
-- established - so MVP 0 leaves them out and calibration settles it later.
local ground = Catalog.probeable(cat, {
    categories = { "normal", "command_normal" },
    input_methods = { "manual" },
})
for _, row in ipairs(ground) do
    t.eq(row.input_method, "manual", ("ground row %d is a manual input"):format(row.action_id))
end

-- The assist rows are still in the catalog, just not in this sweep.
local with_assist = Catalog.probeable(cat, { categories = { "normal", "command_normal" } })
t.ok(#with_assist > #ground, "assist rows exist and are reachable when asked for")
t.ok(#ground >= 8, "there are enough ground normals for MVP 0 (" .. #ground .. ")")
for _, row in ipairs(ground) do
    t.eq(row.air, false, ("ground row %d is not an air move"):format(row.action_id))
end

-- Spot-check the moves the plan names as the MVP 0 candidates.
local ground_ids = {}
for _, row in ipairs(ground) do ground_ids[row.action_id] = true end
for _, id in ipairs({ 604, 621, 623, 637 }) do
    t.ok(ground_ids[id], ("%d is in the ground-normal set"):format(id))
end

-- And nothing that is not a normal. A probe matrix built from this list is
-- what the first dataset comes from, so anything wrong here is wrong for the
-- rest of the project.
for _, id in ipairs({ 850, 855, 501, 504, 17, 18, 716, 940 }) do
    t.ok(not ground_ids[id], ("%d is NOT in the ground-normal set"):format(id))
end
for _, row in ipairs(ground) do
    t.ok(row.category == "normal" or row.category == "command_normal",
         ("ground row %d has a normal category, not %s"):format(row.action_id, row.category))
end

-- --- the ambiguity is preserved, not resolved -------------------------------

t.group("colliding action ids stay unresolved")

local groups = Catalog.ambiguous_groups(cat)
t.ok(#groups > 0, "there are notation collisions (" .. #groups .. " groups)")

for _, g in ipairs(groups) do
    t.eq(g.canonical_status, "unverified",
         "group " .. g.display_group .. " is unverified until something is observed")
    t.is_nil(g.canonical_action_id, "and names no canonical id")
end

-- 617/618/619 all display as crouching light: nothing in the data says which
-- one the input produces.
local crouch_light
for _, g in ipairs(groups) do
    local ids = {}
    for _, id in ipairs(g.action_ids) do ids[id] = true end
    if ids[617] and ids[618] and ids[619] then crouch_light = g end
end
t.ok(crouch_light ~= nil, "617/618/619 are grouped together")
t.eq(#crouch_light.action_ids, 3, "all three in one group")

-- --- resolving from observation ---------------------------------------------

t.group("apply_observations")

local applied, conflicts = Catalog.apply_observations(cat, {
    { notation = crouch_light.notation, input_method = crouch_light.input_method, action_id = 617 },
})
t.eq(#applied, 1, "one group resolved")
t.eq(#conflicts, 0, "no conflicts")
t.eq(crouch_light.canonical_action_id, 617, "the observed id becomes canonical")
t.eq(crouch_light.canonical_status, "verified", "and the group is verified")

for _, row in ipairs(cat.rows) do
    if row.display_group == crouch_light.display_group then
        t.eq(row.canonical_status, "verified", ("row %d inherits the verdict"):format(row.action_id))
        t.eq(row.is_canonical, row.action_id == 617,
             ("row %d knows whether it is the canonical one"):format(row.action_id))
    end
end

-- An input that produces an unexpected action is a FINDING, not a correction.
local _, c2 = Catalog.apply_observations(cat, {
    { notation = crouch_light.notation, input_method = crouch_light.input_method, action_id = 9999 },
})
t.eq(#c2, 1, "an id outside the group is a conflict")
t.ok(c2[1].reason:find("not in the group", 1, true) ~= nil, "and says so")

-- The same input producing two different ids is worse, and is recorded as such
-- rather than letting the last observation win.
local _, c3 = Catalog.apply_observations(cat, {
    { notation = crouch_light.notation, input_method = crouch_light.input_method, action_id = 618 },
})
t.eq(#c3, 1, "a second, different id is a conflict")
t.eq(crouch_light.canonical_status, "conflicting", "and the group is marked conflicting")

local _, c4 = Catalog.apply_observations(cat, {
    { notation = "nonsense", input_method = "manual", action_id = 1 },
})
t.ok(c4[1].reason:find("no such group", 1, true) ~= nil, "an unknown notation is reported")

-- --- degenerate input --------------------------------------------------------

t.group("degenerate input")

t.is_nil(Catalog.build(nil), "nil is refused")
t.is_nil(Catalog.build({}), "a table with no _meta is refused")
local _, why = Catalog.build({})
t.ok(why[1].reason:find("_meta", 1, true) ~= nil, "and the reason says what was missing")

return t.finish()
