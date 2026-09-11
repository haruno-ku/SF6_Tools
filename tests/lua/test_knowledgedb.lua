-- Unit tests for func/ComboExplorer/core/KnowledgeDb.lua
--
-- This is the one place Explorer data leaves the project, so what these tests
-- defend is the boundary rather than the transformation.
--
-- The target abolished its `placeholder` source kind. There is no longer any
-- receptacle over there for provisional data, which means a record that crosses
-- while half-measured cannot be corrected later by moving it somewhere weaker -
-- it just becomes a wrong fact in somebody's database. So every gate gets two
-- tests: one that a good record passes it, and one that a record failing it is
-- turned away WITH the reason, because a silently dropped record is a result
-- nobody knows was lost.
--
-- The second thing defended is the difference between a prediction and a
-- measurement. predicted_damage is an unscaled frame-table sum used to order
-- candidates; outcomes.damage is documented in the target as a training-mode
-- measurement. If those two ever meet, the target fills up with numbers that
-- look measured and are not, and nothing downstream can tell them apart.
--
-- The third is that missing information stays missing: an action id with no
-- moves.yaml slug becomes work to do, not a deleted combo, and an end-state flag
-- nobody measured is absent while one measured as false is exported as false.

local t = require("tests.lua.harness")
local K = require("func/ComboExplorer/core/KnowledgeDb")
local Schema = require("func/ComboExplorer/core/Schema")

-- --- fixtures ----------------------------------------------------------------

local PATCH = "command_display@2026-08-03"
local CALIB = "calib-2026-09-10-001"

-- The catalog's own tokens, as byte sequences, so the tests exercise the real
-- strings rather than a Latin stand-in.
local LIGHT = "\229\188\177"
local MEDIUM = "\228\184\173"
local HEAVY = "\229\188\186"
local AIR = "\231\169\186\228\184\173"
local ANY = "\228\187\187\230\132\143\233\148\174"
-- A Japanese move name whose second character is not a separator, so the medium
-- token inside it is part of a word rather than a button.
local JAPANESE_NAME = MEDIUM .. "\232\182\179"

-- A sentinel for "remove this field", since a nil in a merge table is invisible.
local NONE = {}

local function merge(base, over)
    local out = {}
    for k, v in pairs(base) do out[k] = v end
    for k, v in pairs(over or {}) do
        if v == NONE then out[k] = nil else out[k] = v end
    end
    return out
end

local function provenance()
    return Schema.provenance({
        game_patch = PATCH,
        calibration_id = CALIB,
        command_display = { character = "Zangief", fighter_id = 6,
                            generated_at = "2026-08-03T00:00:00.000Z",
                            ac_sha256 = "753d02", bcm_sha256 = "09e933" },
        explorer_version = "test",
    })
end

local function step(action_id, method, notation, classic, category)
    return { action_id = action_id, input_method = method, notation = notation,
             classic = classic, category = category }
end

local ROUTE_ID = "601:manual>1201:manual"

local function route(over)
    return merge({
        id = ROUTE_ID,
        character = "zangief",
        control_scheme = "modern",
        position = "midscreen",
        counter = "none",
        steps = {
            step(601, "manual", LIGHT, "LP", "normal"),
            step(1201, "manual", "360 + " .. HEAVY, "360P", "special"),
        },
        -- Present on every route out of the offline pipeline, and never read by
        -- the adapter. Deliberately absurd so that a leak would be obvious.
        offline_score = { predicted_damage = 99999, execution_cost = 41.5,
                          execution_cost_is_prediction = true },
    }, over)
end

local function rec(over)
    return merge({
        schema = Schema.KIND.COMBO,
        id = "vc-601-1201",
        route_id = ROUTE_ID,
        status = Schema.STATUS.VERIFIED,
        runtime_verified = true,
        evidence = { trial_ids = { "t1", "t2", "t3" }, attempts = 3, successes = 3 },
        stable = true,
        measured = { damage = 2450 },
        provenance = provenance(),
    }, over)
end

local ACTION_SLUGS = {
    [601] = "lp",
    [605] = "mp",
    [1201] = "screw-piledriver",
}

local function opts(over)
    return merge({
        character = "zangief",
        game_patch = PATCH,
        calibration_id = CALIB,
        game_version = "2026-08-03",
        action_slugs = ACTION_SLUGS,
        source = "self-tested-2026-09",
        routes = { route() },
    }, over)
end

-- Returns the rejection, or a stand-in whose reason names the fact that the
-- record was exported - so a gate that stops working fails loudly instead of
-- indexing nil.
local function refusal(over_rec, over_opts)
    local combo, why = K.combo(rec(over_rec), opts(over_opts))
    if combo ~= nil then return { reason = "(the record was exported)" } end
    return why
end

-- --- 1. nothing unverified crosses -------------------------------------------

t.group("nothing unverified crosses")

local good, good_why = K.combo(rec(), opts())
t.ok(good ~= nil, "a verified, measured, in-patch record is exported")
t.is_nil(good_why, "and is not also reported as a rejection")

t.eq(refusal({ status = Schema.STATUS.THEORETICAL, runtime_verified = false,
               evidence = NONE }).reason,
     K.REASON.NOT_VERIFIED,
     "a theoretical record is refused: the target has no home for provisional data")
t.eq(refusal({ status = Schema.STATUS.RUNTIME_PENDING, runtime_verified = false,
               evidence = NONE }).reason,
     K.REASON.NOT_VERIFIED,
     "a record still queued for a trial is refused")
t.eq(refusal({ status = Schema.STATUS.REJECTED }).reason,
     K.REASON.NOT_VERIFIED,
     "a record the game refused is refused here too")
t.eq(refusal({ runtime_verified = false }).reason,
     K.REASON.NOT_RUN,
     "a record that never ran on the game is refused however it is labelled")
t.eq(refusal({ evidence = NONE }).reason,
     K.REASON.NO_EVIDENCE,
     "a verified record with no evidence is refused")
t.eq(refusal({ evidence = {} }).reason,
     K.REASON.NO_EVIDENCE,
     "an empty evidence block is not evidence")

local patch_why = refusal({ provenance = Schema.provenance({
    game_patch = "command_display@2025-02-05", calibration_id = CALIB }) })
t.eq(patch_why.reason, K.REASON.PATCH_MISMATCH,
     "a record measured on another patch is refused")
t.ok(patch_why.detail:find("2025%-02%-05") ~= nil,
     "and the patch it was actually measured on is named")

t.eq(refusal({ provenance = Schema.provenance({
        game_patch = PATCH, calibration_id = "calib-old" }) }).reason,
     K.REASON.CALIBRATION_MISMATCH,
     "a record measured under another calibration is refused")

t.eq(refusal({ stable = false }).reason,
     K.REASON.NOT_REPRODUCED,
     "a trial that is known not to have reproduced is refused")

-- The distinction the project runs on: false is a measurement, nil is a gap.
local unknown_stable, unknown_why, unknown_aux = K.combo(rec({ stable = NONE }), opts())
t.ok(unknown_stable ~= nil, "a record that does not say whether it reproduced is not refused")
t.is_nil(unknown_why, "because missing information is not a negative answer")
local carried = false
for _, u in ipairs(unknown_aux.unknowns) do
    if u.key == "stable" then carried = true end
end
t.ok(carried, "the unrecorded reproduction is carried as an unknown instead")

t.eq(refusal({ schema = "ce.route.v1" }).reason,
     K.REASON.INVALID_RECORD,
     "a record of another kind is refused")
t.eq(refusal({ provenance = NONE }).reason,
     K.REASON.INVALID_RECORD,
     "a record with no provenance cannot be checked and so cannot cross")

local id_kept = refusal({ status = Schema.STATUS.THEORETICAL, runtime_verified = false,
                          evidence = NONE })
t.eq(id_kept.id, "vc-601-1201",
     "every rejection names the record, so nothing is lost silently")
t.ok(type(id_kept.detail) == "string" and #id_kept.detail > 0,
     "and says in words why it did not cross")

-- --- 2. a prediction never becomes a measurement ------------------------------

t.group("a prediction is not a measurement")

local no_damage = refusal({ measured = { hits = 4, ticks = 120 } })
t.eq(no_damage.reason, K.REASON.DAMAGE_NOT_MEASURED,
     "a record with no measured damage is refused even though the route predicts one")
t.ok(no_damage.detail:find("training mode") ~= nil,
     "and the refusal quotes what the target says outcomes.damage means")

t.eq(refusal({ measured = { predicted_damage = 9999 } }).reason,
     K.REASON.PREDICTION,
     "a prediction parked in the measured block is refused, not renamed")
t.eq(refusal({ measured = { damage = 2450, predicted_drive_gain = 800 } }).reason,
     K.REASON.PREDICTION,
     "any predicted_* field in the measured block is refused")

t.eq(good.outcomes.damage, 2450,
     "the exported damage is the measured figure, not the frame-table sum")
t.ok(good.outcomes.damage ~= 99999, "the route's predicted damage never reaches outcomes")

t.is_nil(good.difficulty,
     "difficulty is not derived from execution_cost: it needs a window nobody has measured")

local leaked = 0
for _, block in ipairs({ good.outcomes, good.requirements or {} }) do
    for key in pairs(block) do
        if key:find("predict") then leaked = leaked + 1 end
    end
end
t.eq(leaked, 0, "no exported block carries a field named for a prediction")

t.eq(refusal({ measured = { damage = -10 } }).reason,
     K.REASON.OUT_OF_RANGE,
     "a negative damage figure is not a measurement anything could have produced")

local zero = K.combo(rec({ measured = { damage = 0 } }), opts())
t.eq(zero.outcomes.damage, 0,
     "a measured zero is exported: it is a known result, not an absent one")

-- --- 3. the target vocabulary ------------------------------------------------

t.group("the target vocabulary, exactly as the target defines it")

local placeholder_present = false
for _, kind in ipairs(K.SOURCE_KINDS) do
    if kind == "placeholder" then placeholder_present = true end
end
t.ok(not placeholder_present, "the abolished placeholder source kind is not in the vocabulary")
t.eq(K.EXPLORER_SOURCE_KIND, "self_tested",
     "an Explorer result can only ever claim to be self-tested")

local src = K.source_entry({ slug = "self-tested-2026-09", name = "training mode" })
t.eq(src.kind, "self_tested", "the source entry it writes says self_tested")
t.is_nil(src.url, "and carries no url, because a training-mode measurement has no page")
t.is_nil(K.source_entry({ slug = "x", name = "y", kind = "placeholder" }),
         "asking for a placeholder source is refused; the kind no longer exists")
t.is_nil(K.source_entry({ slug = "x", name = "y", kind = "wiki" }),
         "and so is claiming the numbers came from a wiki")
t.is_nil(K.source_entry({ slug = "Not A Slug", name = "y" }),
         "a source slug that is not kebab-case is refused")

t.eq(good.control_scheme, "modern", "control_scheme passes through the target's vocabulary")
local scheme_why = refusal({}, { routes = { route({ control_scheme = "Modern" }) } })
t.eq(scheme_why.reason, K.REASON.UNKNOWN_VALUE,
     "a control scheme spelled any other way is refused")
t.eq(scheme_why.field, "control_scheme", "and the field is named")
t.eq(refusal({}, { routes = { route({ control_scheme = "classic_modern" }) } }).reason,
     K.REASON.UNKNOWN_VALUE,
     "the catalog's control_support vocabulary is not the target's control_scheme")

t.eq(refusal({}, { routes = { route({ steps = {
        step(601, "easy", LIGHT, "LP", "normal"),
        step(1201, "manual", "360 + " .. HEAVY, "360P", "special") } }) } }).reason,
     K.REASON.UNKNOWN_VALUE,
     "a step input method outside manual | simple | assist is refused")

local function style_of(m1, m2)
    local r = route({ id = "styled", steps = {
        step(601, m1, LIGHT, "LP", "normal"),
        step(1201, m2, "SP", "360P", "special"),
    } })
    local c = K.combo(rec({ route_id = "styled" }), opts({ routes = { r } }))
    return c and c.input_style
end
t.eq(style_of("manual", "manual"), "manual", "a combo performed entirely by motion is manual")
t.eq(style_of("simple", "simple"), "simple",
     "one performed entirely on the special button is simple")
t.eq(style_of("manual", "simple"), "hybrid",
     "one that mixes them is hybrid, which is the target's word for it")
t.eq(style_of("assist", "manual"), "hybrid", "and so is an assist mixed with anything else")

t.eq(good.requirements.position, "midscreen", "position comes through as the target spells it")
t.eq(good.requirements.counter, "none", "and so does the counter condition")
local pos_why = refusal({}, { routes = { route({ position = "screen_edge" }) } })
t.eq(pos_why.reason, K.REASON.UNKNOWN_VALUE, "a position outside the vocabulary is refused")
t.eq(pos_why.field, "requirements.position", "naming the field the target would reject")
t.eq(refusal({}, { routes = { route({ counter = "punish" }) } }).reason,
     K.REASON.UNKNOWN_VALUE,
     "an abbreviated counter condition is refused rather than guessed at")

local unknown_req = refusal({ requirements = { drive_bar_min = 3 } })
t.eq(unknown_req.reason, K.REASON.UNKNOWN_KEY,
     "a requirement key the target does not have is refused, not quietly dropped")
t.ok(unknown_req.detail:find("drive_bar_min") ~= nil, "and the offending key is named")

local unknown_es = refusal({ measured = { damage = 1, end_state = { juggle_state = 2 } } })
t.eq(unknown_es.reason, K.REASON.UNKNOWN_KEY,
     "an end-state field the target does not have is refused")
t.eq(refusal({ measured = { damage = 1,
        end_state = { knockdown_type = "knockdown" } } }).reason,
     K.REASON.UNKNOWN_VALUE,
     "a knockdown type outside the target's six is refused")
t.eq(refusal({ measured = { damage = 1,
        end_state = { distance_class = "close" } } }).reason,
     K.REASON.UNKNOWN_VALUE,
     "and a distance class outside near | mid | far")

-- validate.ts rejects unknown keys under requirements and outcomes, so the
-- emitted blocks are checked as a whole rather than field by field.
local allowed_req, allowed_out = {}, {}
for _, k in ipairs(K.REQUIREMENT_KEYS) do allowed_req[k] = true end
for _, k in ipairs(K.OUTCOME_KEYS) do allowed_out[k] = true end

t.eq(refusal({ difficulty = 9 }).reason, K.REASON.OUT_OF_RANGE,
     "a difficulty outside 1..5 is refused, since the target caps it there")

-- --- 4. moves moves.yaml does not have yet -----------------------------------

t.group("an action id with no slug is work to do, not a deleted combo")

local unmapped = route({ id = "unmapped", steps = {
    step(601, "manual", LIGHT, "LP", "normal"),
    step(9101, "manual", "236 + " .. MEDIUM, "236K", "special"),
    step(9102, "manual", "SP", "236PP", "od_special"),
} })
local um_combo, um_why, um_aux = K.combo(rec({ id = "vc-unmapped", route_id = "unmapped" }),
                                         opts({ routes = { unmapped } }))
t.is_nil(um_combo, "a combo whose move has no moves.yaml slug is not exported")
t.eq(um_why.reason, K.REASON.MOVE_SLUG_MISSING, "and says exactly why")
t.ok(um_why.detail:find("9101") ~= nil, "naming the unregistered action id")
t.ok(um_why.detail:find("9102") ~= nil,
     "and every other one in the same combo, not just the first")
t.eq(#um_aux.missing, 2, "both unregistered ids are handed back as moves to add")
t.eq(um_aux.missing[1].action_id, 9101, "with the action id")
t.eq(um_aux.missing[1].notation, "236 + " .. MEDIUM,
     "and the raw notation, which is what whoever writes moves.yaml has to read")
t.eq(um_aux.missing[1].display, "236 + M", "alongside a rendering fit for a human")

local mixed = K.export({
    rec(),
    rec({ id = "vc-unmapped", route_id = "unmapped" }),
    rec({ id = "vc-unmapped-2", route_id = "unmapped" }),
}, opts({ routes = { route(), unmapped } }))
t.eq(mixed.counts.exported, 1, "an unregistered move does not block the rest of the export")
t.eq(mixed.counts.rejected, 2, "the combos that need it are rejected, with their reasons")
t.eq(#mixed.missing_moves, 2, "and each unregistered id is listed once, not once per combo")
t.eq(#mixed.missing_moves[1].wanted_by, 2, "with every combo that wanted it named")

-- --- 5. display names carry no catalog tokens --------------------------------

t.group("display names carry no catalog tokens")

t.eq(K.display_name("2 + " .. MEDIUM), "2 + M", "the medium token becomes M")
t.eq(K.display_name(LIGHT), "L", "the light token becomes L")
t.eq(K.display_name("360 + " .. HEAVY), "360 + H", "the heavy token becomes H")
t.eq(K.display_name(AIR .. " 360 + " .. HEAVY), "j. 360 + H",
     "the air token becomes j. and takes its trailing medium character with it")
t.eq(K.display_name("AUTO + " .. LIGHT), "Assist + L", "AUTO is spelled out")
t.eq(K.display_name("SP"), "Special", "so is SP")
t.eq(K.display_name("THROW"), "Throw", "and THROW")
t.eq(K.display_name(ANY), "any", "and the any-button token")

t.eq(K.display_name("SPD > " .. LIGHT), "SPD > L",
     "a token inside a longer word is left alone, so SPD does not become SpecialD")
t.eq(K.display_name(JAPANESE_NAME), JAPANESE_NAME,
     "a Japanese move name containing the medium character is not mangled into an M")

local _, token_problem = K.display_name("SP > " .. LIGHT, { SP = false })
t.ok(token_problem ~= nil, "a token the caller refuses to render is not emitted anyway")
t.eq(token_problem.token, "SP", "and the refusal names the token")

local token_why = refusal({}, { display_tokens = { SP = false },
                                routes = { route({ steps = {
                                    step(601, "manual", "SP", "LP", "normal"),
                                    step(1201, "manual", "360 + " .. HEAVY, "360P", "special"),
                                } }) } })
t.eq(token_why.reason, K.REASON.NOTATION_TOKEN,
     "a combo whose name cannot be rendered is rejected rather than exported with the token")
t.eq(token_why.field, "name_ja", "naming the field that could not be built")

local named = K.combo(rec(), opts({ move_names = { [601] = JAPANESE_NAME } }))
t.ok(named.name_ja:find(JAPANESE_NAME, 1, true) ~= nil,
     "an injected Japanese name survives conversion intact")

t.eq(refusal({ notes = "SP only", route_group = "x" },
             { display_tokens = { SP = false } }).reason,
     K.REASON.NOTATION_TOKEN,
     "notes are display text too and are refused on the same rule")

local token_leaks = 0
for _, combo in ipairs(mixed.combos) do
    for _, tok in ipairs(K.TOKEN_ORDER) do
        if combo.name_ja:find(tok, 1, true) then token_leaks = token_leaks + 1 end
    end
end
t.eq(token_leaks, 0,
     "no name built from a catalog notation reaches the target with a token in it")

-- --- 6. a fully verified combo, field by field --------------------------------

t.group("a fully verified combo crosses complete")

local full = rec({
    id = "vc-full",
    route_group = "midscreen-punish",
    difficulty = 3,
    notes = LIGHT .. " starter, drive rush cancel not required",
    requirements = { drive_min = 2000 },
    measured = {
        damage = 2450,
        drive_spent = 2000,
        drive_gain = 1750,
        -- The frame source's spelling. The target calls it sa_gain and that is
        -- the only name that may be written.
        super_gain = 800,
        hits = 4,
        ticks = 137,
        end_state = {
            advantage_frames = 34,
            knockdown_type = "hard",
            back_rise_allowed = true,
            -- Measured, and measured as no. This is the value that a careless
            -- `v and v or nil` would delete.
            ends_in_corner = false,
            side_switch = false,
            distance_class = "near",
        },
    },
})
local c = K.combo(full, opts())
t.ok(c ~= nil, "the whole record crosses")

t.eq(c.slug, "zangief-modern-manual-lp-screw-piledriver",
     "the slug is kebab-case and says which character, scheme and style it belongs to")
t.ok(K.is_slug(c.slug), "and passes the target's own slug rule")
t.eq(c.name_ja, "L > 360 + H", "the display name is the inputs, in tokens anyone can read")
t.eq(c.control_scheme, "modern", "the control scheme is carried")
t.eq(c.input_style, "manual", "the input style is derived from what was actually performed")
t.eq(c.route_group, "midscreen-punish", "the route group is carried")
t.eq(c.difficulty, 3, "a difficulty a person set is carried")

t.eq(#c.steps, 2, "every step is present")
t.eq(c.steps[1].move, "lp", "each step names its moves.yaml slug")
t.eq(c.steps[2].move, "screw-piledriver", "including the special")
t.eq(c.steps[1].input_method, "manual", "and how that step was input")

t.eq(c.requirements.drive_min, 2000, "a measured requirement is carried")
t.eq(c.requirements.position, "midscreen", "along with the position the trial ran at")
t.eq(c.requirements.counter, "none", "and the counter condition")

t.eq(c.outcomes.damage, 2450, "the measured damage is the exported damage")
t.eq(c.outcomes.drive_spent, 2000, "drive spent is carried")
t.eq(c.outcomes.drive_gain, 1750, "drive gained is carried")
t.eq(c.outcomes.sa_gain, 800, "and super gain is written under the target's name for it")
t.is_nil(c.outcomes.super_gain, "the Explorer's own spelling does not travel")
t.is_nil(c.outcomes.hits, "and neither does measurement detail the target has no key for")

t.eq(c.end_state.advantage_frames, 34, "a measured advantage is carried")
t.eq(c.end_state.knockdown_type, "hard", "as is the knockdown type")
t.eq(c.end_state.back_rise_allowed, true, "a measured true is carried")
t.eq(c.end_state.ends_in_corner, false,
     "and a measured false is carried as false, because it is a result, not an absence")
t.eq(c.end_state.side_switch, false, "the same for side switch")
t.eq(c.end_state.distance_class, "near", "and the distance class")

t.ok(c.notes:find("starter") ~= nil, "the record's own notes survive")
t.ok(c.notes:find(CALIB, 1, true) ~= nil,
     "and the calibration is written down, so the number can be re-checked")
t.eq(c.source, "self-tested-2026-09", "the combo points at the self-tested source entry")
t.is_nil(c.result_node, "no knowledge-graph reference is invented here")
t.is_nil(c.published, "and no publication decision is made on the target's behalf")

local combo_keys = {}
for _, k in ipairs(K.COMBO_KEYS) do combo_keys[k] = true end
local extra_combo, extra_req, extra_out, extra_step = 0, 0, 0, 0
for k in pairs(c) do if not combo_keys[k] then extra_combo = extra_combo + 1 end end
for k in pairs(c.requirements) do if not allowed_req[k] then extra_req = extra_req + 1 end end
for k in pairs(c.outcomes) do if not allowed_out[k] then extra_out = extra_out + 1 end end
local step_keys = {}
for _, k in ipairs(K.STEP_KEYS) do step_keys[k] = true end
for _, s in ipairs(c.steps) do
    for k in pairs(s) do if not step_keys[k] then extra_step = extra_step + 1 end end
end
t.eq(extra_combo, 0, "the combo carries no key ComboYaml does not define")
t.eq(extra_req, 0, "requirements carries no key validate.ts would reject")
t.eq(extra_out, 0, "outcomes carries no key validate.ts would reject")
t.eq(extra_step, 0, "and neither does any step")

-- The route may travel inline instead of being looked up, and must produce the
-- same thing either way - one route shape, not two.
local inline = K.combo(rec({ route = route() }), opts({ routes = NONE }))
t.eq(inline.slug, c.slug,
     "a route carried on the record produces the same combo as one looked up")

local res = K.export({ full }, opts())
t.eq(res.counts.exported, 1, "the export carries it through")
t.eq(res.file.version, "2026-08-03",
     "the combos file names the target's game version, not the Explorer's patch string")
t.eq(type(res.file.combos), "table",
     "and hands back tables; serialising is somebody else's job")
t.eq(type(res.file.combos[1].steps), "table", "all the way down")
t.eq(res.character, "zangief", "the export says which character's file it is for")

-- --- 7. degenerate input ------------------------------------------------------

t.group("degenerate input")

local none_at_all = K.export(nil, opts())
t.ok(none_at_all ~= nil, "an export of nothing is not an error")
t.eq(none_at_all.counts.exported, 0, "it just has nothing in it")
t.eq(#K.export({}, opts()).combos, 0, "and neither does an export of an empty list")

local no_slugs, no_slugs_err = K.export({ rec() }, opts({ action_slugs = NONE }))
t.is_nil(no_slugs, "an export without the injected slug table is refused outright")
local named_field = false
for _, p in ipairs(no_slugs_err.problems) do
    if p.field == "action_slugs" then named_field = true end
end
t.ok(named_field,
     "because reporting every move as unregistered would answer a question nobody asked")

t.is_nil(K.export({ rec() }, opts({ game_version = NONE })),
         "an export with no game version code is refused: nothing could validate it")
t.is_nil(K.export({ rec() }, opts({ calibration_id = NONE })),
         "and so is one that cannot say which calibration it is exporting for")
t.is_nil(K.export({ rec() }, opts({ character = NONE })),
         "an export that does not say whose file it is for is refused")
t.is_nil(K.export({ rec() }, opts({ character = "!!!" })),
         "and so is one whose character name cannot become a directory slug")
t.eq(K.export({ rec() }, opts({ character = "Zangief" })).character, "zangief",
     "a character name that can be is normalised to the slug the target uses")

t.eq(refusal({ route_id = "no-such-route" }).reason, K.REASON.NO_STEPS,
     "a combo whose route cannot be found is refused rather than exported empty")
t.eq(refusal({}, { routes = { route({ steps = {} }) } }).reason,
     K.REASON.NO_STEPS,
     "and so is one whose route has no steps")
t.eq(refusal({}, { routes = { route({ steps = { { input_method = "manual" } } }) } }).reason,
     K.REASON.INVALID_STEP,
     "a step naming no action id is refused")
t.eq(refusal({ character = "ryu" }).reason, K.REASON.CHARACTER_MISMATCH,
     "a record about another character is refused; it would land in the wrong file")

local not_a_record = K.export({ "nope", 7 }, opts())
t.eq(not_a_record.counts.exported, 0, "junk in the record list exports nothing")
t.eq(not_a_record.counts.rejected, 2, "and every piece of it is reported")

-- Two routes of the same moves under the same scheme and style collide, and a
-- duplicate slug fails the target's validator.
local twins = K.export({ rec({ id = "a" }), rec({ id = "b" }) }, opts())
t.eq(twins.counts.exported, 2, "both members of a slug collision are still exported")
t.ok(twins.combos[1].slug ~= twins.combos[2].slug, "with distinct slugs")
t.eq(#twins.slug_collisions, 1, "and the rename is reported rather than done quietly")

local route_b = route({ id = "b-route", steps = {
    step(605, "manual", MEDIUM, "MP", "normal"),
    step(1201, "manual", "360 + " .. HEAVY, "360P", "special"),
} })
local grouped = K.export({
    rec({ id = "g1", route_group = "midscreen-punish" }),
    rec({ id = "g2", route_id = "b-route", route_group = "midscreen-punish" }),
}, opts({ routes = { route(), route_b } }))
t.eq(grouped.counts.exported, 1,
     "two combos cannot claim one route group for one scheme and style")
t.eq(grouped.rejected[1].reason, K.REASON.ROUTE_GROUP_CONFLICT,
     "the second is refused where its id can still be named")

t.eq(refusal({ requirements = { drive_min = "lots" } }).reason,
     K.REASON.NOT_A_NUMBER,
     "a requirement that is not a number is refused rather than coerced")
t.eq(refusal({ measured = { damage = 100, drive_gain = "some" } }).reason,
     K.REASON.NOT_A_NUMBER,
     "and so is an outcome that is not a number")
t.eq(refusal({ measured = { damage = 100, end_state = { side_switch = "yes" } } }).reason,
     K.REASON.NOT_A_BOOLEAN,
     "an end-state flag that is not a boolean is refused: only true and false "
     .. "are observations")
t.eq(refusal({ measured = { damage = 100, resources = { flame_stock = -1 } } },
             { resource_codes = { spd_stock = true } }).reason,
     K.REASON.RESOURCE,
     "a resource the character never declared is refused, with the code named")

return t.finish()
