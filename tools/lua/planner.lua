-- =========================================================
-- tools/lua/planner.lua - conditions first, then only the pairs those
-- conditions need. Dev-machine only, like the rest of tools/. Pure: routes and
-- folded trial results in, a plan out. No file access.
-- =========================================================
--
-- WHY THIS EXISTS
--
-- The sweep so far has been brute force: every candidate pair the generator
-- produced, 324 of them for Zangief Modern, pressed in confidence order. That is
-- the right shape for "what connects at all", and the wrong one for the
-- question a player actually asks, which starts from a condition: the most
-- damage, nothing spent from the gauges, something that starts from 中.
--
-- Most of those 324 pairs are irrelevant to any one such question. A route
-- satisfying the condition is a short chain of pairs, and the top twenty routes
-- share most of theirs, so confirming them needs a small fraction of the sweep.
-- This module decides which fraction, and says why each pair is in it.
--
-- WHAT IT IS CAREFUL ABOUT
--
-- A missing value never excludes. The same rule RouteSearch and Scoring hold:
-- a route whose Drive spend the source cannot total is not a route over the
-- budget, it is a route nobody can judge on that condition. It is KEPT, and
-- flagged with the reason, so the report can say how many of the survivors rest
-- on a gap.
--
-- A rejected pair never deletes a route. The committed logs hold rejections
-- from experiments that were later found broken - a fixed delay of 4 that
-- pressed B inside A's cancel window (#46), and follow-ups pressed after a move
-- they cannot come out of (#49). A route through such a pair is flagged and
-- ranked after the clean ones when demotion is on, and whenever it is in a plan
-- its pairs are asked again rather than skipped. A planner that quietly
-- trusted every old "no" would inherit every old bug.
--
-- AND NOW IT DOES NOT HAVE TO GUESS WHICH "NO" TO BELIEVE
--
-- tools/lua/labeval.lua (policy ce-eval-v1, the one the lab database applies)
-- decides that per run rather than per experiment: a negative is a conclusive
-- failure only when the run carried none of fixed_delay_4, unplayable_input,
-- link_timing_on_cancel_pair or motion_button_late; a superseded re-run is left
-- out unless it linked; a link always counts. M.known_from takes the
-- evaluations that policy produces and reads a pair's status off the EVALUATION
-- RESULT, so `rejected` here now means "the question was asked properly and the
-- answer was no" - which is what makes demoting a route through one fair. A
-- pair whose only negatives were thrown out is `asked_badly`, and a route
-- through it is not demoted: nobody has asked yet.
--
-- Every filter counts what it removed. A plan that says "20 routes" without
-- saying it started from 917 and which condition cut how many cannot be
-- checked by anyone reading it.

local InputMask = require("func/ComboExplorer/core/InputMask")
local Schema = require("func/ComboExplorer/core/Schema")

local M = { name = "tools.planner" }

-- The combo-scaled damage prediction Scoring is gaining (offline_score field,
-- Scoring.AXES.SCALED_DAMAGE). Named here rather than read off Scoring.AXES,
-- because the planner has to work on a Scoring that does not have it yet - and
-- on one that does, the name is the contract.
M.SCALED_FIELD = "predicted_damage_scaled"

-- One Drive bar in the gauge's own units. RouteSearch.DEFAULTS.max_drive_spend
-- explains the scale: the whole gauge is 60000, OD specials cost 20000, a Drive
-- Rush Cancel 30000, as the frame source prices them.
M.DRIVE_BAR = 10000

M.DRC = "drive_rush_cancel"

-- --- keys ----------------------------------------------------------------------

-- Action ids arrive as integers from the pipeline and possibly as floats from a
-- JSON decode. "%d" refuses a float with a fraction and tostring spells 604.0 as
-- "604.0", so both are normalised to the integer spelling the sweep writes.
local function id_str(v)
    local n = math.tointeger(v)
    if n then return tostring(n) end
    return tostring(v)
end

local function side(id, method)
    return ("%s:%s"):format(id_str(id), tostring(method))
end

-- The spelling runtime/Sweep.lua's pair_key writes into every trial's edge_id:
-- "601:manual->603:manual", and "601:manual->drc->603:manual" for A, a Drive
-- Rush Cancel, then B. Spelled identically on purpose - a plan whose keys did
-- not match the logs would find every pair untested.
function M.pair_key(a_id, a_method, b_id, b_method, via)
    if via ~= nil and via ~= false then
        return ("%s->%s->%s"):format(side(a_id, a_method),
            via == M.DRC and "drc" or tostring(via), side(b_id, b_method))
    end
    return side(a_id, a_method) .. "->" .. side(b_id, b_method)
end

-- The key sweepreport.lua files a combo under: the moves' action ids, joined by
-- ">", with how each was pressed left out. nil for a route through a Drive Rush
-- Cancel, because that list has no rush in it - A > DRC > B keyed as "A>B" would
-- claim the direct combo's confirmation for a different thing.
function M.combo_key(route)
    local ids = {}
    for _, s in ipairs(route.steps or {}) do
        if s.kind ~= nil then return nil end
        ids[#ids + 1] = id_str(s.action_id)
    end
    return table.concat(ids, ">")
end

-- The moves of a route, without the steps that are not moves.
function M.moves(route)
    local out = {}
    for _, s in ipairs(route.steps or {}) do
        if s.kind == nil then out[#out + 1] = s end
    end
    return out
end

-- The consecutive pairs a route is made of, in order. A step with a `kind`
-- between two moves - today only a Drive Rush Cancel - makes that pair a pair
-- through it, spelled with the kind in its key.
function M.route_pairs(route)
    local out, prev, via = {}, nil, nil
    for _, s in ipairs(route.steps or {}) do
        if s.kind ~= nil then
            via = s.kind
        else
            if prev then
                out[#out + 1] = {
                    key = M.pair_key(prev.action_id, prev.input_method,
                                     s.action_id, s.input_method, via),
                    drc = (via == M.DRC),
                    via = via,
                    a = { id = prev.action_id, method = prev.input_method,
                          notation = prev.notation, classic = prev.classic },
                    b = { id = s.action_id, method = s.input_method,
                          notation = s.notation, classic = s.classic },
                    edge_id = s.via_edge,
                }
            end
            prev, via = s, nil
        end
    end
    return out
end

-- --- conditions ------------------------------------------------------------------

M.INPUT_METHODS = {
    -- What each setting ALLOWS. Cumulative, in the order the Modern scheme adds
    -- help: the manual input, then the one-button special (simple), then the
    -- auto-combo button (assist).
    manual = { manual = true },
    simple = { manual = true, simple = true },
    assist = { manual = true, simple = true, assist = true },
}

-- Resolves a button as given on the command line to InputMask's name for it.
-- "中" and "M" both mean the medium button, and the Japanese 強 means the heavy
-- one, which the catalog spells with the simplified 强. Anything else is taken
-- as a name.
local ALIASES = {
    ["\229\188\183"] = "H",   -- 強, the Japanese form of 强
    light = "L", medium = "M", heavy = "H",
}
local function button_name(token)
    token = tostring(token)
    return InputMask.TOKENS[token] or ALIASES[token:lower()] or token
end
M.button_name = button_name

-- Command-line text in the ANSI code page, turned back into UTF-8.
--
-- The stock lua.exe on Windows receives its arguments through the ANSI code
-- page, so on a Japanese Windows `--starter-button 中` arrives as the two
-- Shift_JIS bytes 92 86, not the UTF-8 E4 B8 AD every catalog notation uses,
-- and matches nothing: the first run of the 中 preset removed all 917 routes.
--
-- Only the three button characters are converted, and only in text that is not
-- already valid UTF-8 - those byte pairs can occur inside real UTF-8, so a
-- string that decodes is left alone. The simplified 强 has no Shift_JIS form at
-- all and arrives as "?"; use H for it. Returns text, converted.
local SJIS = {
    ["\146\134"] = "\228\184\173",   -- 中
    ["\142\227"] = "\229\188\177",   -- 弱
    ["\139\173"] = "\229\188\186",   -- 強 -> 强, the catalog's spelling
}
function M.from_ansi(text)
    if type(text) ~= "string" or utf8.len(text) then return text, false end
    local out = text
    for sjis, u in pairs(SJIS) do
        out = out:gsub(sjis, function() return u end)
    end
    return out, out ~= text
end

local function first_move(route)
    for _, s in ipairs(route.steps or {}) do
        if s.kind == nil then return s end
    end
    return nil
end

local KEEP, REMOVE, FLAG = "keep", "remove", "flag"

-- Each returns KEEP, REMOVE, or FLAG plus a reason. FLAG keeps the route: it is
-- the verdict for "this condition could not be judged on what the source has".
local FILTERS = {}

FILTERS.starter_id = function(route, want)
    local s = first_move(route)
    if not s then return FLAG, "the route has no first move to compare" end
    return (id_str(s.action_id) == id_str(want)) and KEEP or REMOVE
end

-- Exact, character for character, including the spaces the catalog writes
-- ("2 + 中"). A looser match belongs to starter_button.
FILTERS.starter_notation = function(route, want)
    local s = first_move(route)
    if not s then return FLAG, "the route has no first move to compare" end
    return (s.notation == want) and KEEP or REMOVE
end

-- The button is among the first move's buttons, with ANY direction: "中" keeps
-- 中, 2 + 中, 3 + 中 and 6 + 中. starter_neutral narrows that to no direction.
-- A notation InputMask cannot read is not a move without that button - it is a
-- move nobody can say anything about - so it is kept and flagged.
FILTERS.starter_button = function(route, want)
    local s = first_move(route)
    if not s then return FLAG, "the route has no first move to compare" end
    local parsed = InputMask.parse(s.notation or "")
    if not parsed then
        return FLAG, ("the first move's notation %q could not be read"):format(tostring(s.notation))
    end
    local name = button_name(want)
    for _, b in ipairs(parsed.buttons) do
        if b == name then return KEEP end
    end
    return REMOVE
end

FILTERS.starter_neutral = function(route, want)
    if not want then return KEEP end
    local s = first_move(route)
    if not s then return FLAG, "the route has no first move to compare" end
    local parsed = InputMask.parse(s.notation or "")
    if not parsed then
        return FLAG, ("the first move's notation %q could not be read"):format(tostring(s.notation))
    end
    return (parsed.dirs == "") and KEEP or REMOVE
end

-- Every move pressed in a way the setting allows. A move with no input_method
-- is flagged rather than assumed manual: Scoring does assume that, for a cost
-- estimate, but a filter that assumed it would be excluding on a guess.
FILTERS.input_method = function(route, want)
    local allowed = M.INPUT_METHODS[want]
    local unknown = false
    for _, s in ipairs(M.moves(route)) do
        if s.input_method == nil then
            unknown = true
        elseif not allowed[s.input_method] then
            return REMOVE
        end
    end
    if unknown then return FLAG, "a move in the route does not say how it is pressed" end
    return KEEP
end

local function length_of(route)
    local s = route.offline_score
    if s and type(s.route_length) == "number" then return s.route_length end
    return #M.moves(route)
end

FILTERS.min_steps = function(route, want)
    return (length_of(route) >= want) and KEEP or REMOVE
end

FILTERS.max_steps = function(route, want)
    return (length_of(route) <= want) and KEEP or REMOVE
end

FILTERS.min_confidence = function(route, want)
    local s = route.offline_score or {}
    local have = Schema.confidence_rank(s.theoretical_confidence or route.min_confidence)
    if not have then return FLAG, "the route carries no confidence" end
    return (have >= Schema.confidence_rank(want)) and KEEP or REMOVE
end

local function count(route, field)
    local s = route.offline_score or {}
    return tonumber(s[field]) or 0
end

FILTERS.no_super = function(route, want)
    if not want then return KEEP end
    return (count(route, "super_steps") == 0) and KEEP or REMOVE
end

FILTERS.no_drive_rush = function(route, want)
    if not want then return KEEP end
    return (count(route, "drive_rush_cancel_steps") == 0) and KEEP or REMOVE
end

-- The known part of what a route spends from the Drive gauge: Scoring's total
-- when it is a total, and otherwise RouteSearch's floor - the sum over the moves
-- and rushes that did carry a figure. Returns spend, is_total.
local function drive_spend(route)
    local s = route.offline_score or {}
    if s.drive_spend_known and type(s.predicted_drive_spend) == "number" then
        return s.predicted_drive_spend, true
    end
    local floor = route.basis and tonumber(route.basis.predicted_drive_spend) or 0
    return floor, false
end

-- No gauge: nothing in the route is KNOWN to spend Drive or Super.
--
-- Removed on any of: an OD move, a super, a Drive Rush Cancel, a known negative
-- super gain, or a known Drive spend above zero (a floor above zero counts - it
-- is spending that is known, not a gap). Kept and flagged when none of those
-- apply but some move carried no Drive figure: the route may be free, and
-- nothing in the source can say it is not.
FILTERS.no_gauge = function(route, want)
    if not want then return KEEP end
    local s = route.offline_score or {}
    if count(route, "od_steps") > 0 then return REMOVE end
    if count(route, "super_steps") > 0 then return REMOVE end
    if count(route, "drive_rush_cancel_steps") > 0 then return REMOVE end
    if count(route, "predicted_super_spend") > 0 then return REMOVE end
    local spend, total = drive_spend(route)
    if spend > 0 then return REMOVE end
    if not total then
        return FLAG, ("%s move(s) carry no Drive figure, so the route is not known to be free")
            :format(tostring(s.drive_spend_unknown_steps or "some"))
    end
    return KEEP
end

-- A Drive budget in bars. A known total over it removes; a known FLOOR over it
-- removes too, because the route already spends that much on what is known.
-- A floor under it with gaps is kept and flagged.
FILTERS.max_drive_bars = function(route, want)
    local limit = want * M.DRIVE_BAR
    local spend, total = drive_spend(route)
    if spend > limit then return REMOVE end
    if not total then
        return FLAG, ("known Drive spend %d is within %s bar(s), but part of the route has "
            .. "no figure"):format(spend, tostring(want))
    end
    return KEEP
end

-- Applied in this order, so the report reads from the most specific cut to the
-- broadest and the counts are reproducible.
M.FILTER_ORDER = {
    "starter_id", "starter_notation", "starter_button", "starter_neutral",
    "input_method", "min_steps", "max_steps", "min_confidence",
    "no_super", "no_drive_rush", "no_gauge", "max_drive_bars",
}

-- Refused rather than ignored: a mistyped condition that is silently dropped
-- runs the plan without it and the report does not say so.
local function validate(cond)
    local known = {}
    for _, k in ipairs(M.FILTER_ORDER) do known[k] = true end
    for k, v in pairs(cond) do
        if not known[k] then return nil, ("unknown condition %q"):format(tostring(k)) end
        if k == "input_method" and not M.INPUT_METHODS[v] then
            return nil, ("input_method must be manual, simple or assist, not %q"):format(tostring(v))
        end
        if k == "min_confidence" and not Schema.confidence_rank(v) then
            return nil, ("min_confidence must be low, medium or high, not %q"):format(tostring(v))
        end
        if (k == "max_drive_bars" or k == "min_steps" or k == "max_steps" or k == "starter_id")
            and type(v) ~= "number" then
            return nil, ("%s must be a number, not %q"):format(k, tostring(v))
        end
    end
    return true
end

-- routes : scored ce.route.v1 records (offline_score attached)
-- cond   : any of FILTER_ORDER. nil or false leaves a condition off.
--
-- Returns kept, report - or nil, err for a condition that is not one.
--   report.input    how many routes came in
--   report.kept     how many survived every filter
--   report.steps    { name, value, before, removed, after, flagged } per filter applied
--   report.flags    { [route_id] = { { filter, reason }, ... } } for routes kept on a gap
function M.filter(routes, cond)
    cond = cond or {}
    local ok, err = validate(cond)
    if not ok then return nil, err end

    local current = {}
    for i, r in ipairs(routes or {}) do current[i] = r end
    local report = { input = #current, steps = {}, flags = {} }

    for _, name in ipairs(M.FILTER_ORDER) do
        local want = cond[name]
        if want ~= nil and want ~= false then
            local fn = FILTERS[name]
            local kept, flagged = {}, 0
            for _, r in ipairs(current) do
                local verdict, why = fn(r, want)
                if verdict ~= REMOVE then
                    kept[#kept + 1] = r
                    if verdict == FLAG then
                        flagged = flagged + 1
                        local id = tostring(r.id)
                        report.flags[id] = report.flags[id] or {}
                        table.insert(report.flags[id], { filter = name, reason = why })
                    end
                end
            end
            report.steps[#report.steps + 1] = {
                name = name, value = want, before = #current,
                removed = #current - #kept, after = #kept, flagged = flagged,
            }
            current = kept
        end
    end

    -- Flags on a route a later filter removed are not about anything in the
    -- plan, so they are dropped with it.
    local alive = {}
    for _, r in ipairs(current) do alive[tostring(r.id)] = true end
    for id in pairs(report.flags) do
        if not alive[id] then report.flags[id] = nil end
    end

    report.kept = #current
    return current, report
end

-- --- ranking ---------------------------------------------------------------------

M.SORTS = { scaled_damage = true, damage = true, simple = true, confidence = true }

local function any_scaled(routes)
    for _, r in ipairs(routes) do
        local s = r.offline_score
        if s and type(s[M.SCALED_FIELD]) == "number" then return true end
    end
    return false
end

-- routes : scored routes
-- sort   : scaled_damage | damage | simple | confidence
--
-- Returns a sorted copy and info:
--   info.sort       what was asked for
--   info.field      the offline_score field actually ordered on
--   info.fallback   true when scaled_damage fell back to predicted_damage
--   info.missing    routes with no value on that field, sorted after the rest
--
-- scaled_damage falls back as a WHOLE SET: if no route carries the scaled
-- figure, every route is ordered on the unscaled sum and info says so. It never
-- mixes the two within one list - a scaled 2400 against an unscaled 3000 is not
-- a comparison. When some routes carry it and others do not, the ones without
-- sort after the ones with, and are counted.
--
-- A route with no value is never removed by the ordering; it goes last. Ties,
-- and the order among routes with no value, are broken on the route id, so a
-- rerun of the same routes gives the same plan.
function M.rank(routes, sort)
    sort = sort or "scaled_damage"
    if not M.SORTS[sort] then
        return nil, ("sort must be scaled_damage, damage, simple or confidence, not %q")
            :format(tostring(sort))
    end
    local list = {}
    for i, r in ipairs(routes or {}) do list[i] = r end

    local info = { sort = sort, fallback = false, missing = 0 }
    local value
    if sort == "scaled_damage" or sort == "damage" then
        local field = "predicted_damage"
        if sort == "scaled_damage" then
            if any_scaled(list) then
                field = M.SCALED_FIELD
            else
                info.fallback = true
                info.fallback_reason = ("no route carries offline_score.%s, so the routes are "
                    .. "ordered on the unscaled predicted_damage instead"):format(M.SCALED_FIELD)
            end
        end
        info.field = field
        value = function(r)
            local v = r.offline_score and r.offline_score[field]
            return type(v) == "number" and v or nil
        end
    elseif sort == "simple" then
        info.field = "execution_cost"
        -- Lower cost is better; negated so one comparator serves every sort.
        value = function(r)
            local v = r.offline_score and r.offline_score.execution_cost
            return type(v) == "number" and -v or nil
        end
    else
        info.field = "theoretical_confidence"
        value = function(r)
            local s = r.offline_score or {}
            return Schema.confidence_rank(s.theoretical_confidence or r.min_confidence)
        end
    end

    local vals = {}
    for _, r in ipairs(list) do
        local v = value(r)
        vals[r] = v
        if v == nil then info.missing = info.missing + 1 end
    end
    table.sort(list, function(a, b)
        local va, vb = vals[a], vals[b]
        if va ~= nil and vb == nil then return true end
        if va == nil and vb ~= nil then return false end
        if va ~= nil and va ~= vb then return va > vb end
        return tostring(a.id) < tostring(b.id)
    end)
    return list, info
end

-- --- what has to be swept ------------------------------------------------------------

-- routes : in plan order. top_n : how many of them (default all).
--
-- Returns the unique pairs those routes are made of, in the order they are
-- first needed: every pair of route 1, then route 2's new ones, and so on. Each
-- carries needed_by_ranks, the positions (1-based, in the list given) of every
-- route that contains it. The order is the plan's point: a sweep cut short has
-- confirmed the best routes' pairs, not the most confident pairs of any route.
function M.pairs_needed(routes, top_n)
    local n = math.min(top_n or #(routes or {}), #(routes or {}))
    local out, by_key = {}, {}
    for rank = 1, n do
        for _, p in ipairs(M.route_pairs(routes[rank])) do
            local entry = by_key[p.key]
            if not entry then
                entry = { key = p.key, drc = p.drc, via = p.via, a = p.a, b = p.b,
                          edge_id = p.edge_id, needed_by_ranks = {} }
                by_key[p.key] = entry
                out[#out + 1] = entry
            end
            local ranks = entry.needed_by_ranks
            if ranks[#ranks] ~= rank then ranks[#ranks + 1] = rank end
        end
    end
    return out
end

-- --- what the game has already said -----------------------------------------------

M.KNOWN = {
    -- Reproduced: ConfirmedEdge says stable on the runs the policy counted.
    VERIFIED = "verified",
    -- It linked, and it was never reproduced at one delay. A real observation
    -- and not a confirmation - so the plan still asks it again.
    LINKED_ONCE = "linked_once",
    -- Counted failures and no link: the question was asked properly and the
    -- answer was no. The only status that demotes a route.
    REJECTED = "rejected",
    -- Negatives exist and the policy threw every one of them out. Not
    -- "rejected", not "pending": the difference is that trials were spent
    -- asking the wrong question, which is worth seeing.
    ASKED_BADLY = "asked_badly",
    PENDING = "pending",
    UNTESTED = "untested",
}

-- A status that has to be asked again even when every route needing it is
-- already a confirmed combo. A conclusive "no" beside a confirmed route is a
-- question about that pair's experiment; a pair nobody asked properly is a
-- question nobody asked.
M.RE_ASK = { [M.KNOWN.REJECTED] = true, [M.KNOWN.ASKED_BADLY] = true }

-- --- one pair's tally, over cohorts and over ids -------------------------------------
--
-- Folding several cohorts - or several action ids with the same buttons - adds
-- the counts and settles once, which takes the strongest answer: a link
-- somewhere is an observation a whiff elsewhere cannot undo.

local function new_tally()
    return { cohorts = 0, reproduced = 0, linked = 0, failed = 0,
             successes = 0, failures = 0, unanswered = 0,
             excluded = 0, excluded_negatives = 0 }
end

local function add_tally(t, other)
    for _, f in ipairs({ "cohorts", "reproduced", "linked", "failed", "successes",
                         "failures", "unanswered", "excluded", "excluded_negatives" }) do
        t[f] = (t[f] or 0) + (other[f] or 0)
    end
end

-- The status and the result the tally comes to. Checked in this order, which is
-- the order of what the plan does about each: stop asking, ask once more, stop
-- believing the route, ask properly for the first time, ask.
local function settle_policy(t)
    if t.reproduced > 0 then
        t.status, t.result = M.KNOWN.VERIFIED, "reproduced"
    elseif t.linked > 0 then
        t.status = M.KNOWN.LINKED_ONCE
        t.result = (t.failures > 0) and "mixed" or "observed_success"
    elseif t.failed > 0 then
        t.status, t.result = M.KNOWN.REJECTED, "no_success_observed"
    elseif t.excluded_negatives > 0 then
        t.status, t.result = M.KNOWN.ASKED_BADLY, "pending"
    else
        t.status, t.result = M.KNOWN.PENDING, "pending"
    end
    t.mixed = (t.successes > 0 and t.failures > 0)
    return t
end
M.settle_policy = settle_policy

-- --- what the whole set says -----------------------------------------------------------

-- edges  : ce.confirmed_edge.v1 records from ConfirmedEdge.from_trials - one per
--          pair PER COHORT, over every log for the character
-- combos : sweepreport's model.combos
-- notation_of : optional, "id:method" -> notation (a table, or a function of
--          id, method), so an answer can be found under the buttons as well as
--          the id - see "the same buttons under another action id" below
-- evaluations : optional, tools/lua/labeval.lua's evaluations over the same
--          logs (tools/lua/labknown.lua builds them). WITH them, a pair's
--          status is read off the evaluation result and the quality policy
--          decides which runs counted. WITHOUT them the old rule applies - any
--          cohort's raw "no" makes the pair rejected - and `policy` is nil, so
--          a caller can tell which of the two it is looking at.
--
-- Returns known = { pairs = { [key] = entry }, groups = { [group key] = entry },
--                   combos = { [combo_key] = combo },
--                   combos_by_inputs = { [notations joined by ">"] = combo },
--                   combo_policy = { [moves key] = tally },
--                   combo_policy_by_inputs = { [notations joined by ">"] = tally },
--                   route_policy = { [route id] = tally },
--                   uses_policy = whether evaluations were given,
--                   reclassified = { total, pairs, moves = { ["a -> b"] = n } } }.
--
-- Every pair entry carries BOTH answers: `status` (the policy's, or the raw one
-- when no evaluations were given) and `raw_status` (always the old rule), so a
-- report can say how many pairs the policy moved. Each cohort's own numbers
-- stay in `cohorts`, and the policy's per-cohort results in `evaluations`.
function M.known_from(edges, combos, notation_of, evaluations)
    local known = { pairs = {}, combos = {}, combo_policy = {},
                    combo_policy_by_inputs = {}, route_policy = {} }

    local function entry(key)
        local k = known.pairs[key]
        if not k then
            k = { cohorts = {}, evaluations = {},
                  verified = 0, rejected = 0, pending = 0, stable = false,
                  policy = new_tally() }
            known.pairs[key] = k
        end
        return k
    end

    for _, e in ipairs(edges or {}) do
        local key = e.edge_id
        if type(key) == "string" then
            local k = entry(key)
            local st = e.status
            if st == Schema.STATUS.VERIFIED then
                k.verified = k.verified + 1
                if e.stable then k.stable = true end
            elseif st == Schema.STATUS.REJECTED then
                k.rejected = k.rejected + 1
            else
                k.pending = k.pending + 1
            end
            k.cohorts[#k.cohorts + 1] = {
                status = st, stable = e.stable, attempts = e.attempts,
                successes = e.successes, negatives = e.negatives, unanswered = e.unanswered,
                calibration_id = e.cohort and e.cohort.calibration_id or nil,
                game_patch = e.cohort and e.cohort.game_patch or nil,
            }
        end
    end

    -- --- the policy's own reading of the same runs -----------------------------------
    --
    -- One evaluation per subject per cohort. A pair's tally is over its cohorts;
    -- a combo's is over every subject whose moves spell it, so the two-move
    -- combo "660>655" is answered by the pair evaluation and the three-move
    -- "660>655>900" by the route's.
    local function combo_tally(map, key)
        local t = map[key]
        if not t then t = new_tally() map[key] = t end
        return t
    end

    for _, ev in ipairs(evaluations or {}) do
        local one = new_tally()
        one.cohorts = 1
        one.successes = ev.successful_runs or 0
        one.failures = ev.conclusive_failures or 0
        one.unanswered = ev.unanswered_runs or 0
        one.excluded = ev.excluded_runs or 0
        for _, r in ipairs(ev.runs or {}) do
            if r.inclusion == "excluded" and r.answer == "negative" then
                one.excluded_negatives = one.excluded_negatives + 1
            end
        end
        if ev.result == "reproduced" then one.reproduced = 1 end
        if one.successes > 0 then one.linked = 1 end
        if ev.result == "no_success_observed" then one.failed = 1 end

        if ev.subject_kind == "edge" then
            local k = entry(ev.subject_id)
            add_tally(k.policy, one)
            local ms = ev.measured_summary or {}
            k.evaluations[#k.evaluations + 1] = {
                result = ev.result, cohort_key = ev.cohort_key,
                successes = one.successes, failures = one.failures,
                unanswered = one.unanswered, excluded = one.excluded,
                excluded_negatives = one.excluded_negatives,
                excluded_by_reason = ms.excluded_by_reason,
                window = ms.window, linked_gaps = ms.linked_gaps,
                stable = ms.stable, damage = ms.damage,
            }
        else
            add_tally(combo_tally(known.route_policy, ev.subject_id), one)
        end

        local c = ev.combo
        if c and type(c.moves_key) == "string" and c.moves_key ~= "" then
            add_tally(combo_tally(known.combo_policy, c.moves_key), one)
            local names, all = {}, true
            for i, s in ipairs(c.steps or {}) do
                names[i] = s.notation
                if type(s.notation) ~= "string" then all = false end
            end
            if all and #names > 0 then
                add_tally(combo_tally(known.combo_policy_by_inputs,
                                      table.concat(names, ">")), one)
            end
        end
    end

    for _, t in pairs(known.combo_policy) do settle_policy(t) end
    for _, t in pairs(known.combo_policy_by_inputs) do settle_policy(t) end
    for _, t in pairs(known.route_policy) do settle_policy(t) end

    local use_policy = evaluations ~= nil

    -- The old rule, kept on every entry under `raw_*` whether or not it is the
    -- one being used: the report says how many pairs the policy moved, and it
    -- cannot say that from one answer.
    local function settle(k)
        if k.verified > 0 then k.raw_status = M.KNOWN.VERIFIED
        elseif k.rejected > 0 then k.raw_status = M.KNOWN.REJECTED
        else k.raw_status = M.KNOWN.PENDING end
        k.raw_mixed = (k.verified > 0 and k.rejected > 0)
        settle_policy(k.policy)
        if use_policy then
            k.status = k.policy.status
            k.result = k.policy.result
            k.mixed = k.policy.mixed
        else
            k.status = k.raw_status
            k.mixed = k.raw_mixed
        end
    end
    for _, k in pairs(known.pairs) do settle(k) end

    -- The same buttons under another action id.
    --
    -- Modern's 弱 is shown under 601, 602 and 611, and the catalog cannot say
    -- which one the button produces. The route search folds such variants into
    -- one route under one of the ids (collapse_canonical_variants), and the
    -- sweep folds the worklist onto the id the calibration measured
    -- (core/Canonical.lua) and writes THAT id into every trial. So a route kept
    -- as 601 > 1218 was answered, if at all, as 611 > 1218 - and looked up by id
    -- alone the plan called it untested and asked the game again. On the
    -- committed Zangief logs that was 11 of the max-damage plan's 16 pairs.
    --
    -- notation_of maps "id:method" to the notation pressed, so each answered
    -- pair can also be filed under its buttons. Without it nothing is grouped.
    known.groups = {}
    if notation_of then
        local function lookup(id, method)
            if type(notation_of) == "function" then return notation_of(id, method) end
            return notation_of[("%s:%s"):format(id, method)]
        end
        for key, k in pairs(known.pairs) do
            local a, am, rest = key:match("^(%d+):([%w_]+)%->(.+)$")
            local via, b, bm = nil, nil, nil
            if rest then
                b, bm = rest:match("^(%d+):([%w_]+)$")
                if not b then
                    via, b, bm = rest:match("^(%a+)%->(%d+):([%w_]+)$")
                    if via == "drc" then via = M.DRC end
                end
            end
            local an = a and lookup(a, am)
            local bn = b and lookup(b, bm)
            if an and bn then
                local gkey = M.group_pair_key(am, an, bm, bn, via)
                local g = known.groups[gkey]
                if not g then
                    g = { keys = {}, verified = 0, rejected = 0, pending = 0,
                          stable = false, cohorts = {}, evaluations = {},
                          policy = new_tally() }
                    known.groups[gkey] = g
                end
                g.keys[#g.keys + 1] = key
                g.verified = g.verified + k.verified
                g.rejected = g.rejected + k.rejected
                g.pending = g.pending + k.pending
                if k.stable then g.stable = true end
                add_tally(g.policy, k.policy)
                for _, e in ipairs(k.evaluations) do g.evaluations[#g.evaluations + 1] = e end
            end
        end
        for _, g in pairs(known.groups) do
            table.sort(g.keys)
            settle(g)
        end
    end

    -- Combos by their moves, and by the notations they linked with, for the
    -- same reason: sweepreport keys a combo by the ids the trials recorded.
    known.combos_by_inputs = {}
    for _, c in ipairs(combos or {}) do
        if type(c.key) == "string" then known.combos[c.key] = c end
        for _, names in ipairs(c.inputs or {}) do
            known.combos_by_inputs[table.concat(names, ">")] = c
        end
    end

    -- How far the policy moved the answers, pair by pair.
    local moved = { total = 0, moves = {}, pairs = 0 }
    for _, k in pairs(known.pairs) do
        moved.pairs = moved.pairs + 1
        if use_policy and k.status ~= k.raw_status then
            moved.total = moved.total + 1
            local m = ("%s -> %s"):format(k.raw_status, k.status)
            moved.moves[m] = (moved.moves[m] or 0) + 1
        end
    end
    known.reclassified = moved
    known.uses_policy = use_policy
    return known
end

-- The policy's verdict on a combo, by its moves and by the notations it was
-- pressed with - the two spellings sweepreport files a combo under.
function M.combo_policy_of(known, moves_key, notation_chain)
    if not known then return nil end
    local t = moves_key and known.combo_policy and known.combo_policy[moves_key]
    if not t and notation_chain and known.combo_policy_by_inputs then
        t = known.combo_policy_by_inputs[notation_chain]
    end
    return t
end

-- A pair keyed by what is pressed rather than by action id:
-- "manual|弱->manual|2 + 中", and "->drc->" through a rush.
function M.group_pair_key(a_method, a_notation, b_method, b_notation, via)
    local mid = (via ~= nil and via ~= false)
        and ("->%s->"):format(via == M.DRC and "drc" or tostring(via)) or "->"
    return ("%s|%s%s%s|%s"):format(tostring(a_method), tostring(a_notation), mid,
                                   tostring(b_method), tostring(b_notation))
end

-- Status, the folded entry, and - when the answer came from another id with
-- the same buttons - the keys it was answered under.
local function pair_status(known, p)
    local k = known and known.pairs and known.pairs[p.key]
    if k then return k.status, k, nil end
    if known and known.groups and p.a and p.b and p.a.notation and p.b.notation then
        local g = known.groups[M.group_pair_key(p.a.method, p.a.notation,
                                                p.b.method, p.b.notation, p.via)]
        if g then return g.status, g, g.keys end
    end
    return M.KNOWN.UNTESTED, nil, nil
end

local function notation_chain(route)
    local names = {}
    for _, s in ipairs(route.steps or {}) do
        if s.kind ~= nil then return nil end
        names[#names + 1] = tostring(s.notation)
    end
    return table.concat(names, ">")
end

-- pairs  : from pairs_needed
-- routes : the same routes, in the same order
-- known  : from known_from (or nil: everything untested)
-- opts.include_verified : keep verified pairs in the sweep (default false)
--
-- Marks, and returns { pairs, routes }:
--
--   pair.known_status   verified | linked_once | rejected | asked_badly |
--                       pending | untested
--   pair.known          the folded entry, when there is one
--   pair.known_as       when the answer was found under another action id with
--                       the same buttons, the keys it was recorded under
--   pair.skip          nil, or why the pair is left out of the sweep:
--                       "verified" - the game has said it connects, twice at
--                       one delay
--                       "route_confirmed" - every route needing it is already a
--                       confirmed combo, so nothing waits on it
--
--   route annotation    { rank, id, route, pair_keys, pair_statuses,
--                         pairs_total, pairs_verified, all_pairs_verified,
--                         rejected_pairs, has_rejected_pair,
--                         asked_badly_pairs, linked_once_pairs,
--                         combo_key, combo_status, combo_policy, confirmed }
--
-- Rejected pairs are never skipped. See the header: they are the ones the
-- policy says were asked properly, and asking one again is how a "no" stops
-- being the last word. A pair whose negatives were all thrown out is not
-- skipped either, for the opposite reason: it has not been asked yet.
--
-- `confirmed` is the lab database's rule (lab.confirmed_combos) when the known
-- set carries evaluations: a pair reproduced under ConfirmedEdge, a route with
-- at least SweepReport.CONFIRM_LINKS counted links. Without them it falls back
-- to sweepreport's looser count, which counts links across input methods,
-- cohorts and gaps, and includes runs the policy would have left out.
function M.annotate(pairs_list, routes, known, opts)
    opts = opts or {}
    local anns = {}
    for rank, r in ipairs(routes or {}) do
        local a = { rank = rank, id = r.id, route = r, pair_keys = {}, pair_statuses = {},
                    pairs_total = 0, pairs_verified = 0, rejected_pairs = {},
                    asked_badly_pairs = {}, linked_once_pairs = {} }
        for _, p in ipairs(M.route_pairs(r)) do
            local st = pair_status(known, p)
            a.pair_keys[#a.pair_keys + 1] = p.key
            a.pair_statuses[#a.pair_statuses + 1] = st
            a.pairs_total = a.pairs_total + 1
            if st == M.KNOWN.VERIFIED then a.pairs_verified = a.pairs_verified + 1 end
            if st == M.KNOWN.REJECTED then a.rejected_pairs[#a.rejected_pairs + 1] = p.key end
            if st == M.KNOWN.ASKED_BADLY then
                a.asked_badly_pairs[#a.asked_badly_pairs + 1] = p.key
            end
            if st == M.KNOWN.LINKED_ONCE then
                a.linked_once_pairs[#a.linked_once_pairs + 1] = p.key
            end
        end
        a.all_pairs_verified = a.pairs_total > 0 and a.pairs_verified == a.pairs_total
        a.has_rejected_pair = #a.rejected_pairs > 0
        a.combo_key = M.combo_key(r)
        local chain = notation_chain(r)
        local combo = a.combo_key and known and known.combos and known.combos[a.combo_key]
        if not combo and known and known.combos_by_inputs then
            combo = chain and known.combos_by_inputs[chain] or nil
        end
        a.combo_status = combo and combo.status or nil
        local pol = M.combo_policy_of(known, a.combo_key, chain)
        a.combo_policy = pol and pol.result or nil
        if known and known.uses_policy then
            a.confirmed = (pol ~= nil and pol.status == M.KNOWN.VERIFIED)
        else
            a.confirmed = (a.combo_status == "confirmed")
        end
        anns[rank] = a
    end

    for _, p in ipairs(pairs_list or {}) do
        local st, entry, as = pair_status(known, p)
        p.known_status = st
        p.known = entry
        p.known_as = as
        p.skip = nil
        if st == M.KNOWN.VERIFIED and not opts.include_verified then
            p.skip = "verified"
        elseif not M.RE_ASK[st] then
            local open = false
            for _, rank in ipairs(p.needed_by_ranks or {}) do
                if not (anns[rank] and anns[rank].confirmed) then open = true break end
            end
            if not open and #(p.needed_by_ranks or {}) > 0 then p.skip = "route_confirmed" end
        end
    end
    return { pairs = pairs_list, routes = anns }
end

-- A stable partition: routes with no rejected pair first, in their order, then
-- the ones with one, in theirs. Takes and returns route annotations.
--
-- A route the logs list as a confirmed combo is not demoted, whatever one of
-- its pairs was answered on its own: the whole combo linking, twice, is the
-- stronger observation, and a pair rejected beside it is a question about that
-- pair's experiment rather than about the route.
--
-- `has_rejected_pair` is CONCLUSIVE failures only (annotate, above). A route
-- through a pair whose every negative the policy threw out is not demoted:
-- before ce-eval-v1 it was, and on the committed Zangief logs that was most of
-- the plan - twenty routes demoted for answers that never asked the question.
function M.demote(anns)
    local clean, flagged = {}, {}
    for _, a in ipairs(anns) do
        if a.has_rejected_pair and not a.confirmed then
            flagged[#flagged + 1] = a
        else
            clean[#clean + 1] = a
        end
    end
    for _, a in ipairs(flagged) do clean[#clean + 1] = a end
    return clean
end

-- --- the whole plan ---------------------------------------------------------------------

-- routes : every scored route the pipeline produced
-- args   : { cond, sort, top, known, demote_rejected (default true),
--            include_verified (default false) }
--
-- Filter, rank, mark every surviving route with what the logs say, move the
-- routes through a rejected pair behind the clean ones, cut to the top N, and
-- list the pairs those N need in that order.
--
-- WHY DEMOTION HAPPENS BEFORE THE CUT
--
-- It was first written inside the top N, so that a route through a rejected
-- pair could never fall out of the plan. Run on the committed Zangief logs, that
-- produced a max-damage plan whose twenty routes ALL ran through a pair the
-- frame-data cohort had answered no to: twenty pairs to sweep, every one a
-- re-ask, and not one new question. Demoting within a list where everything is
-- demoted moves nothing.
--
-- So a route through a rejected pair ranks after every clean route that
-- satisfies the conditions. It is not deleted: it keeps its order among the
-- demoted ones, fills the plan when the clean routes run out, and its pairs are
-- asked again rather than skipped whenever it is in a plan. The routes the sort
-- alone would have put in the top N come back in `demoted_out`, so the report
-- lists them. demote_rejected = false puts them back in sort order.
--
-- Returns plan, or nil, err:
--   plan.filter   the filter report
--   plan.rank     the rank info
--   plan.routes   route annotations in plan order; each has plan_rank and sort_rank
--   plan.pairs    every pair the top routes need, in plan order, marked
--   plan.sweep    plan.pairs minus the skipped ones - what the worklist holds
--   plan.skipped  the skipped ones
--   plan.available         routes satisfying the conditions
--   plan.through_rejected  how many of those run through a rejected pair
--   plan.demoted_out       annotations of the routes the sort put in the top N
--                          and demotion moved below it, in sort order
function M.plan(routes, args)
    args = args or {}
    local kept, freport = M.filter(routes, args.cond)
    if not kept then return nil, freport end
    local ranked, rinfo = M.rank(kept, args.sort)
    if not ranked then return nil, rinfo end
    local top = args.top or #ranked

    local all = M.annotate(nil, ranked, args.known, args).routes
    local through_rejected = 0
    for _, a in ipairs(all) do
        if a.has_rejected_pair then through_rejected = through_rejected + 1 end
    end
    local order = (args.demote_rejected ~= false) and M.demote(all) or all

    local cut, sort_rank, in_cut = {}, {}, {}
    for i = 1, math.min(top, #order) do
        cut[i] = order[i].route
        sort_rank[i] = order[i].rank
        in_cut[order[i].rank] = true
    end
    local demoted_out = {}
    for i = 1, math.min(top, #all) do
        if not in_cut[i] then demoted_out[#demoted_out + 1] = all[i] end
    end

    -- Annotated again over the cut, because a pair's skip reason depends on
    -- which routes in THIS plan need it.
    local final = M.annotate(M.pairs_needed(cut), cut, args.known, args)
    for i, a in ipairs(final.routes) do
        a.sort_rank = sort_rank[i]
        a.plan_rank = i
    end

    local sweep, skipped = {}, {}
    for _, p in ipairs(final.pairs) do
        if p.skip then skipped[#skipped + 1] = p else sweep[#sweep + 1] = p end
    end

    return {
        filter = freport, rank = rinfo, routes = final.routes,
        pairs = final.pairs, sweep = sweep, skipped = skipped,
        available = #ranked, through_rejected = through_rejected,
        demoted_out = demoted_out,
    }
end

-- --- the command line's shape -------------------------------------------------------------

-- tools/lua/cli.lua reads `--no-x` as x = false and wants a value after every
-- other key. The planner's switches do not fit either rule: `--no-gauge` is a
-- condition being turned ON, not `gauge` being turned off, and `--no-drive-rush`
-- (the condition) and `--drive-rush` (search through rushes) would both land on
-- opt.drive_rush. So the switches are rewritten into keys of their own, with an
-- explicit value, before Cli.parse sees them. A switch already followed by
-- true/false keeps that value.
M.SWITCHES = {
    ["--no-gauge"] = "--cond-no-gauge",
    ["--no-super"] = "--cond-no-super",
    ["--no-drive-rush"] = "--cond-no-drive-rush",
    ["--drive-rush"] = "--drive-rush",
    ["--include-verified"] = "--include-verified",
    ["--starter-neutral"] = "--starter-neutral",
}

function M.normalize_argv(argv)
    local out = {}
    local i = 1
    while i <= #(argv or {}) do
        local a = argv[i]
        local to = M.SWITCHES[a]
        if to then
            out[#out + 1] = to
            local nxt = argv[i + 1]
            if nxt == "true" or nxt == "false" then
                out[#out + 1] = nxt
                i = i + 2
            else
                out[#out + 1] = "true"
                i = i + 1
            end
        else
            out[#out + 1] = a
            i = i + 1
        end
    end
    return out
end

-- The condition table from parsed options.
function M.conditions_from(opt)
    local cond = {
        starter_id = opt.starter_id,
        starter_notation = opt.starter_notation ~= nil
            and (M.from_ansi(tostring(opt.starter_notation))) or nil,
        starter_button = opt.starter_button ~= nil
            and (M.from_ansi(tostring(opt.starter_button))) or nil,
        starter_neutral = opt.starter_neutral == true or nil,
        input_method = opt.input_method,
        min_steps = opt.min_steps,
        max_steps = opt.max_steps,
        min_confidence = opt.min_confidence,
        no_super = opt.cond_no_super == true or nil,
        no_drive_rush = opt.cond_no_drive_rush == true or nil,
        no_gauge = opt.cond_no_gauge == true or nil,
        max_drive_bars = opt.max_drive_bars,
    }
    return cond
end

-- A name for a plan nobody named, built from what it asks for.
--
-- ASCII only, because it becomes a file name and the stock Lua interpreter on
-- Windows opens files through the ANSI code page: "中" in a path is written as
-- whatever that page makes of three UTF-8 bytes. So a button is spelled by
-- InputMask's name for it - 中 becomes M - and anything else outside
-- [A-Za-z0-9._-] becomes "_".
function M.slug(s)
    return (tostring(s):gsub("[^%w%._%-]", "_"))
end

function M.default_name(cond, sort, top)
    local parts = {}
    if cond.starter_id then parts[#parts + 1] = "starter-" .. id_str(cond.starter_id) end
    if cond.starter_notation then
        local p = InputMask.parse(cond.starter_notation)
        local spelled = cond.starter_notation
        if p then
            local b = {}
            for i, n in ipairs(p.buttons) do b[i] = n end
            spelled = p.dirs .. table.concat(b, "")
        end
        parts[#parts + 1] = "starter-" .. spelled
    end
    if cond.starter_button then parts[#parts + 1] = "starter-" .. button_name(cond.starter_button) end
    if cond.starter_neutral then parts[#parts + 1] = "neutral" end
    if cond.input_method then parts[#parts + 1] = cond.input_method end
    if cond.min_steps then parts[#parts + 1] = "min" .. cond.min_steps end
    if cond.max_steps then parts[#parts + 1] = "max" .. cond.max_steps end
    if cond.min_confidence then parts[#parts + 1] = cond.min_confidence end
    if cond.no_gauge then parts[#parts + 1] = "nogauge" end
    if cond.no_super then parts[#parts + 1] = "nosuper" end
    if cond.no_drive_rush then parts[#parts + 1] = "nodrc" end
    if cond.max_drive_bars then parts[#parts + 1] = "drive" .. cond.max_drive_bars end
    parts[#parts + 1] = tostring(sort)
    parts[#parts + 1] = "top" .. tostring(top)
    return M.slug(table.concat(parts, "-"))
end

return M
