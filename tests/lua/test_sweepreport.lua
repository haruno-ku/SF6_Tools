-- Unit tests for tools/lua/sweepreport.lua
--
-- The page draws what this model says, and people will read the page to decide
-- what to run next on the game. So the two things it must not get wrong are
-- tested here: an unanswered trial is not drawn as a failure, and a pair the
-- compiler cannot press is marked (#49).

local t = require("tests.lua.harness")
dofile("tools/lua/cli.lua")
local R = dofile("tools/lua/sweepreport.lua")

-- --- what one step can press ---------------------------------------------------

t.group("press_kind names what one step cannot press (#49)")

t.eq(R.press_kind("2 + 中"), "single", "a direction with a button is one mask")
t.eq(R.press_kind("中"), "single", "a button alone is one mask")
t.eq(R.press_kind("4 + SP + 强"), "single", "a direction with two buttons is still one mask")
t.eq(R.press_kind("22 + 中"), "repeat", "22 is DOWN held for two ticks, not two presses")
t.eq(R.press_kind("236236 + 中"), "single", "a motion whose directions change every tick plays")
t.eq(R.press_kind("63214 + 强"), "single", "and so does a half circle")
t.eq(R.press_kind("360 + 弱"), "single", "a 360 is read through its shorthand, which never repeats")
t.eq(R.press_kind("720 + 强"), "single", "nor does a 720")
t.eq(R.press_kind("> 中"), "followup", "> is a derivation, whatever follows it")
t.eq(R.press_kind(""), "unreadable", "an empty notation is named, not guessed")

-- --- keys ----------------------------------------------------------------------

t.group("keys")

t.eq(R.pair_key({ a_id = 601, a_method = "manual", b_id = 940, b_method = "simple" }),
    "601:manual->940:simple", "the key is the one the sweep writes as edge_id")

local id, gaps = R.route_subject("zangief-assist-ground-truth@40/2")
t.eq(id, "zangief-assist-ground-truth", "a route row names its route before the @")
t.eq_list(gaps, { 40, 2 }, "and its gaps after it")
id, gaps = R.route_subject("zangief-assist-ab@4")
t.eq_list(gaps, { 4 }, "one gap is a list of one")
t.is_nil(R.route_subject("601:manual->940:simple"), "a pair key is not a route")

-- --- the model -----------------------------------------------------------------

local WORKLIST = {
    character = "Zangief", control_scheme = "modern",
    pairs = {
        { a_id = 621, a_method = "manual", a_notation = "2 + 中",
          b_id = 678, b_method = "manual", b_notation = "22 + 中", confidence = "high", margin_frames = 2 },
        { a_id = 621, a_method = "manual", a_notation = "2 + 中",
          b_id = 1206, b_method = "simple", b_notation = "4 + SP + 强", confidence = "medium" },
        { a_id = 621, a_method = "manual", a_notation = "2 + 中",
          b_id = 605, b_method = "manual", b_notation = "> 中", confidence = "low" },
        { a_id = 617, a_method = "manual", a_notation = "2 + 弱",
          b_id = 1206, b_method = "simple", b_notation = "4 + SP + 强", confidence = "high" },
    },
}

local function trial(edge_id, verdict, extra)
    local r = { edge_id = edge_id, verdict = verdict, recorded_at = "2026-09-12T12:00:00Z",
                provenance = { calibration_id = "cal-1" } }
    for k, v in pairs(extra or {}) do r[k] = v end
    return r
end

t.group("the axes")

local m = R.build(WORKLIST, {}, {})
t.eq(#m.starters, 2, "one row per starter")
t.eq(#m.targets, 3, "one column per target")
t.eq_list({ m.targets[1].press, m.targets[2].press, m.targets[3].press },
    { "single", "repeat", "followup" },
    "columns a reader should not trust are grouped, pressable ones first")
t.eq(m.press.single, 2, "pairs whose both steps are one mask")
t.eq(m.press["repeat"], 1, "a pair takes its worst step")
t.eq(m.press.followup, 1, "and a follow-up is its own kind")

t.group("a pair log")

m = R.build(WORKLIST, {
    { name = "zangief-modern-a", path = "a.jsonl", bad_lines = 1, records = {
        trial("621:manual->1206:simple", "wrong_move", { delay = 4, reason = "saw 1" }),
        trial("621:manual->1206:simple", "link", { delay = 8,
            evidence = { actions_seen = { { action_id = 621 }, { action_id = 1206 } } } }),
        trial("617:manual->1206:simple", "wrong_move", { delay = 4 }),
        trial("617:manual->1206:simple", "a_failed", { delay = 6 }),
        trial("621:manual->678:manual", "combo_broke", { delay = 6 }),
        trial("999:manual->1:manual", "whiff"),
    } },
}, {})

local log = m.pair_logs[1]
t.ok(log ~= nil, "a log of pairs is a pair log")
t.eq(log.counts.rows, 6, "every row is counted")
t.eq(log.counts.verdicts.wrong_move, 2, "by verdict")
t.eq(log.counts.answers.unanswered, 3, "and by what it answered")
t.eq(log.counts.elsewhere, 1, "a row outside the worklist is counted, not dropped")
t.eq_list(log.elsewhere, { "999:manual->1:manual" }, "and named")
t.eq(log.unreadable_lines, 1, "lines that did not decode ride along")

local c = log.cells["621:manual->1206:simple"]
t.eq(c.verdict, "link", "a link anywhere in the cell is its headline")
t.eq(c.answer, "positive", "classified by ResultCollector")
t.eq(c.rows, 2, "both attempts are in the cell")
t.eq_list({ c.delays[1].delay, c.delays[2].delay }, { 4, 8 }, "delays are sorted")
t.eq_list(c.actions_seen, { 621, 1206 }, "what the game showed is kept")

c = log.cells["617:manual->1206:simple"]
t.eq(c.answer, "unanswered", "a cell with no answer is drawn as unanswered, not as a failure")

c = log.cells["621:manual->678:manual"]
t.eq(c.answer, "negative", "a real negative stays negative")
t.is_nil(log.cells["621:manual->605:manual"], "a pair not tried has no cell")

t.group("an unknown verdict")

m = R.build(WORKLIST, { { name = "x", records = {
    trial("621:manual->1206:simple", "teleported"),
} } }, {})
t.eq(m.pair_logs[1].cells["621:manual->1206:simple"].answer, "unknown",
    "a verdict ResultCollector does not know is not given a colour")

t.group("a route log")

m = R.build(WORKLIST, { { name = "gt", records = {
    trial("gt@40/2", "link", { delays = { 40, 2 } }),
    trial("gt@40/4", "combo_broke", { delays = { 40, 4 } }),
    trial("gt@44/2", "wrong_move", { delays = { 44, 2 } }),
} } }, { gt = { id = "gt", steps = { { notation = "AUTO + 强" } }, note = "known" } })

t.eq(#m.pair_logs, 0, "a log of route rows is not a pair log")
local r = m.route_logs[1]
t.eq(r.route_id, "gt", "it is filed under its route")
t.eq_list(r.gap_axes[1], { 40, 44 }, "the first gap's axis")
t.eq_list(r.gap_axes[2], { 2, 4 }, "the second gap's axis")
t.eq(r.cells["40/2"].verdict, "link", "cells are keyed by their gaps")
t.eq(r.note, "known", "and the route definition names it")

t.group("logs in order")

m = R.build(WORKLIST, {
    { name = "later", records = { trial("621:manual->678:manual", "whiff", { recorded_at = "2026-09-12T12:00:00Z" }) } },
    { name = "earlier", records = { trial("621:manual->678:manual", "whiff", { recorded_at = "2026-09-11T12:00:00Z" }) } },
}, {})
t.eq_list({ m.pair_logs[1].name, m.pair_logs[2].name }, { "earlier", "later" },
    "oldest first - each experiment exists because of the one before")

-- --- the combo list ----------------------------------------------------------------

t.group("the combo list")

local GT = { id = "gt", steps = {
    { action_id = 660, notation = "AUTO + 强" },
    { action_id = 655, notation = "3 + 中" },
    { action_id = 900, notation = "2 + SP" },
} }

local WL2 = {
    pairs = {
        { a_id = 617, a_method = "manual", a_notation = "2 + 弱",
          b_id = 1206, b_method = "manual", b_notation = "236236 + 中" },
        { a_id = 617, a_method = "manual", a_notation = "2 + 弱",
          b_id = 1206, b_method = "simple", b_notation = "4 + SP + 强" },
        { a_id = 621, a_method = "manual", a_notation = "2 + 中",
          b_id = 1206, b_method = "simple", b_notation = "4 + SP + 强" },
        { a_id = 601, a_method = "manual", a_notation = "弱",
          b_id = 930, b_method = "manual", b_notation = "360 + 弱" },
    },
}

m = R.build(WL2, {
    { name = "sweep-1", records = {
        trial("617:manual->1206:manual", "link", { delay = 22 }),
        trial("621:manual->1206:simple", "link", { delay = 35 }),
        trial("601:manual->930:manual", "whiff", { delay = 4 }),
    } },
    { name = "sweep-2", records = {
        trial("617:manual->1206:simple", "link", { delay = 4 }),
        trial("621:manual->1206:simple", "wrong_move", { delay = 35 }),
    } },
    { name = "route", records = {
        trial("gt@40/2", "link", { delays = { 40, 2 } }),
        trial("gt@44/2", "link", { delays = { 44, 2 } }),
        trial("gt@40/32", "combo_broke", { delays = { 40, 32 } }),
        trial("gt@2/2", "wrong_move", { delays = { 2, 2 } }),
    } },
}, { gt = GT }, { [617] = "2+LP", [1206] = "236236+P" })

local by_key = {}
for _, c in ipairs(m.combos) do by_key[c.key] = c end

t.eq(#m.combos, 3, "only combos that linked at least once are listed")
t.is_nil(by_key["601>930"], "a pair that only whiffed is not a combo")

local sa = by_key["617>1206"]
t.ok(sa ~= nil, "a combo is keyed by its moves")
t.eq(sa.links, 2, "two input spellings of the same moves are one combo")
t.eq(#sa.inputs, 2, "and both spellings are listed under it")
t.eq(sa.status, "confirmed", "two links confirm it, across logs")
t.eq_list(sa.linked_gaps, { "4", "22" }, "gaps sort as numbers, not as strings")
t.eq_list(sa.logs, { "sweep-1", "sweep-2" }, "the logs it linked in are named")
t.eq(sa.steps[1].classic, "2+LP", "classic notation is attached where the catalog has it")
t.eq(sa.damage_measured, false, "and damage is said to be unmeasured, not left out")

do
    local dm = R.build(WL2, { { name = "d", records = {
        trial("617:manual->1206:manual", "link", { delay = 22,
            evidence = { damage = { combo_damage = 3200, agree = true } } }),
        trial("617:manual->1206:simple", "link", { delay = 22,
            evidence = { damage = { combo_damage = 3300, agree = false } } }),
        trial("617:manual->1206:simple", "whiff", { delay = 30,
            evidence = { damage = { combo_damage = 900 } } }),
    } } }, {})
    local c = dm.combos[1]
    t.eq(c.damage_measured, true, "a linked trial that measured damage makes it measured")
    t.eq(c.damage_min, 3200, "the lowest linked figure")
    t.eq(c.damage_max, 3300, "the highest - a whiff's damage is not this combo's")
    t.eq(c.damage_disagreements, 1, "and a disagreement with the health delta is counted")
end

local once = by_key["621>1206"]
t.eq(once.status, "once", "one link is listed, but not called confirmed")
t.eq(once.unanswered, 1, "a trial that answered nothing is counted as unanswered")
t.eq(once.negatives, 0, "not as a negative")
t.is_nil(once.steps[1].classic, "a move the catalog does not name has no classic label")

local route = by_key["660>655>900"]
t.ok(route ~= nil, "a route is listed under the moves its definition names")
t.eq(route.links, 2, "every linked gap counts")
t.eq(route.status, "confirmed", "two links at different gaps confirm that the combo connects")
t.eq_list(route.linked_gaps, { "40/2", "44/2" }, "and the gaps that worked are kept")
t.eq(route.attempts, 4, "the attempts include the ones that did not link")
t.eq(route.negatives, 1, "a gap outside the window is a negative")

t.eq_list({ m.combos[1].key, m.combos[2].key, m.combos[3].key },
    { "660>655>900", "617>1206", "621>1206" },
    "confirmed first, longer combos first within it, seen-once last")

m = R.build(WL2, { { name = "x", records = { trial("nodef@4", "link", { delays = { 4 } }) } } }, {})
t.eq(m.combos[1].key, "nodef", "a route with no definition is listed under its id, not guessed")

return t.finish()
