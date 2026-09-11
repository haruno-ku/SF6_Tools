-- Unit tests for func/ComboExplorer/core/Catalog.lua
--
-- Run against the REAL Zangief command_display entries, not invented ones. The
-- failure this code exists to prevent is data-shaped: a move that quietly drops
-- out, or one credited with a one-button input it does not have. Neither shows
-- up against a fixture written to match the author's own assumptions.

local t = require("tests.lua.harness")
local Catalog = require("func/ComboExplorer/core/Catalog")
local Schema = require("func/ComboExplorer/core/Schema")

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

-- Modern cannot reach these at all, and the way they are absent matters.
--
-- They produce no ROW - the source gives them no Modern input, so there is
-- nothing to build a row from and nothing to exclude. The loop that used to
-- stand here looked them up in by_id, found nil every time, and executed zero
-- assertions while reading as though it had checked nine moves. Nine real moves
-- were leaving the catalog with no trace at all, which from the outside is
-- indistinguishable from the source never having mentioned them.
t.eq(cat.counts.classic_only, 9, "nine entries are classic_only, as the catalog says")
t.eq(cat.counts.unreachable, 9, "and all nine are recorded as having no Modern form")

local unreachable_by_id = {}
for _, u in ipairs(cat.unreachable) do unreachable_by_id[u.action_id] = u end
for _, id in ipairs({ 600, 613, 615, 631, 685, 34, 852, 1015, 1020 }) do
    local u = unreachable_by_id[id]
    t.ok(u ~= nil, ("%d is named as unreachable rather than silently missing"):format(id))
    if u then
        t.eq(u.reason, "classic_only", ("%d says why"):format(id))
        t.ok(u.classic ~= nil, ("%d keeps its classic notation, so a reader knows what it is")
             :format(id))
    end
    t.is_nil(by_id[id], ("%d produces no probeable row, because there is no input to press")
             :format(id))
end

-- Stable between runs: pairs() over the source keys is in per-process hash
-- order, and this list is printed in a report somebody diffs.
local ordered = true
for i = 2, #cat.unreachable do
    if cat.unreachable[i - 1].action_id > cat.unreachable[i].action_id then ordered = false end
end
t.ok(ordered, "and the list is in a stable order")

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
    t.eq(g.canonical_status, Schema.CANONICAL.UNRESOLVED,
         "group " .. g.display_group .. " is unresolved until something is observed")
    t.is_nil(g.canonical_action_id, "and names no canonical id")
end

-- The word, and the reason it is that word. This file used to write
-- "unverified", which Schema's validator rejected - so a move record built from
-- a row here could not be validated at all, and nothing had noticed because
-- nothing had taken that path. It is also the wrong word: "unverified" is
-- Provenance's, and it means nobody measured a value. What is unresolved here
-- is which of several ids one notation produces.
t.eq(Schema.CANONICAL.UNRESOLVED, "unresolved", "the starting value is the schema's word")
t.eq(Schema.is_canonical_status("unverified"), false,
     "and \"unverified\" is not in this vocabulary - it belongs to Provenance")

do
    -- End to end: a row straight out of the catalog validates as a move.
    local row = cat.rows[1]
    local ok, problems = Schema.validate(Schema.KIND.MOVE, {
        schema = Schema.KIND.MOVE,
        action_id = row.action_id, input_method = row.input_method,
        notation = row.notation, standalone = row.standalone,
        exclusion = row.exclusion, canonical_status = row.canonical_status,
        status = Schema.STATUS.THEORETICAL,
    })
    local why = {}
    for _, pr in ipairs(problems or {}) do
        why[#why + 1] = tostring(pr.field) .. ": " .. tostring(pr.problem)
    end
    t.eq(ok, true, "a catalog row validates as a move record: " .. table.concat(why, "; "))
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

local inherited, wrong_flag = 0, 0
for _, row in ipairs(cat.rows) do
    if row.display_group == crouch_light.display_group then
        inherited = inherited + 1
        t.eq(row.canonical_status, "verified", ("row %d inherits the verdict"):format(row.action_id))
        t.eq(row.is_canonical, row.action_id == 617,
             ("row %d knows whether it is the canonical one"):format(row.action_id))
    end
end
t.ok(inherited > 1, "the resolved group really has more than one row in it")

-- The rows NOBODY observed are the ones that matter here, and the old test
-- never looked at them: it was fenced inside the resolved group.
--
-- is_canonical is a measured claim - "this input does not produce this action
-- id" - and an unobserved row has no business making it. The spelling
-- `(x == nil) and nil or (...)` cannot yield nil in Lua, so every unobserved
-- row was carrying a hard false: 85 of 88 rows on this catalog, manufactured
-- out of an absence of measurement.
local unobserved, false_claims = 0, 0
for _, row in ipairs(cat.rows) do
    if row.display_group ~= crouch_light.display_group then
        unobserved = unobserved + 1
        if row.is_canonical == false then false_claims = false_claims + 1 end
    end
end
t.ok(unobserved > 50, "most of the catalog is still unobserved (" .. unobserved .. " rows)")
t.eq(false_claims, 0,
     "and not one of them claims to be known NOT to be canonical - unknown stays nil")

-- A recorded conflict is not undone by the next observation that agrees with
-- the first. Two ids from one input is what that input does; a run of matching
-- samples afterwards is a sample, not a retraction. Letting it flip back made
-- the group's verdict depend on the order the sweep happened to run in, and
-- dropped the hitbox unknown off every edge built from those rows.
local group2 = crouch_light
local other_id
for _, id in ipairs(group2.action_ids) do
    if id ~= 617 then other_id = id break end
end
t.ok(other_id ~= nil, "the crouching-light group holds more than one id")

Catalog.apply_observations(cat, {
    { notation = group2.notation, input_method = group2.input_method, action_id = other_id },
})
t.eq(group2.canonical_status, "conflicting", "a second, different id makes the group conflict")

local _, again = Catalog.apply_observations(cat, {
    { notation = group2.notation, input_method = group2.input_method, action_id = 617 },
})
t.eq(group2.canonical_status, "conflicting",
     "and observing the first id again does NOT restore the verdict")
t.ok(#again > 0, "the agreeing observation is reported as a conflict of its own")
t.ok(#group2.conflicting_action_ids >= 2, "with both ids kept")

for _, row in ipairs(cat.rows) do
    if row.display_group == group2.display_group then
        t.eq(row.canonical_status, "conflicting",
             ("row %d still carries the conflict"):format(row.action_id))
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

-- --- a derivation the Modern side does not mark --------------------------------

t.group("a \">\" on the classic side alone still means derivation")

-- Zangief cannot show this: every one of his derivations carries the marker on
-- both sides. JP's do not, and that asymmetry is the bug - so this reads his
-- real catalog rather than a fixture shaped to the author's assumptions, which
-- is the same reason the rest of this file uses the shipped Zangief data.
local jp_json = dofile("tools/lua/json.lua")
local jp_raw = jp_json.load_file(
    "reframework/data/TrainingComboTrials_data/command_display/JP.json")
t.ok(jp_raw ~= nil, "JP's real catalog loads")

local jp = Catalog.build(jp_raw)
t.ok(jp ~= nil, "and builds")

-- 960 is ">22+LP+HP" in classic and "22 + light + heavy" in Modern. Reading
-- only the Modern side left it with no marker, no category, and an
-- `unclassified` exclusion - dropped for having a notation nobody had a word
-- for, when the source had said plainly what it was.
local derived, wrongly_dropped = 0, 0
for _, row in ipairs(jp.rows) do
    if row.action_id == 960 or row.action_id == 961 then
        derived = derived + 1
        t.eq(row.followup, true,
             ("%d is a derivation, because the classic display says so"):format(row.action_id))
        t.eq(row.exclusion, "followup",
             ("%d is excluded for needing a preceding action, not for being unplaceable")
             :format(row.action_id))
        -- The category matters as much as the exclusion: CandidateGenerator
        -- re-collects follow-ups as edge TARGETS, and a target with no category
        -- cannot be told from a special, a normal or a super.
        t.eq(row.category, "special",
             ("%d is classified on what it is, with the marker removed"):format(row.action_id))
        if row.exclusion == "unclassified" then wrongly_dropped = wrongly_dropped + 1 end
    end
end
t.ok(derived >= 6, "both action ids produced rows for every input method (" .. derived .. ")")
t.eq(wrongly_dropped, 0, "and not one of them was dropped as unplaceable")

-- The marker decides reachability, never category. Stripping it must not turn a
-- derivation into something probeable from neutral.
for _, row in ipairs(jp.rows) do
    if row.followup then
        t.ok(not row.standalone,
             ("derivation %d is still not standalone"):format(row.action_id))
    end
end

-- --- degenerate input --------------------------------------------------------

t.is_nil(Catalog.build(nil), "nil is refused")
t.is_nil(Catalog.build({}), "a table with no _meta is refused")
local _, why = Catalog.build({})
t.ok(why[1].reason:find("_meta", 1, true) ~= nil, "and the reason says what was missing")

return t.finish()
