-- =========================================================
-- ComboExplorer/core/DamageScaling.lua - a MODEL of Street Fighter 6 combo
-- damage scaling, taken from public write-ups. Pure: moves in, factors out.
-- =========================================================
--
-- WHY THIS EXISTS WHEN THE PLAN SAYS IT SHOULD NOT
--
-- docs/ComboExplorer/plan-v3-implementation.md says damage scaling is not
-- predicted and has to be measured. That is still true of DAMAGE. What this
-- module produces is an ordering aid: the unscaled frame-table sum Scoring
-- carries ranks a five-move route far above a three-move one that does the
-- same real damage, and the user decided that a clearly labelled model is a
-- better ordering than no model. So:
--
--   * nothing here is a damage figure, and nothing here may be exported as one
--     (KnowledgeDb takes measured damage only, and is not touched by this);
--   * every rule is a parameter in M.PARAMS, with where it came from;
--   * the model says what it leaves out (M.NOT_MODELLED) and that nobody has
--     checked it against this build (verified = false).
--
-- THE RULES (see M.SOURCES)
--
-- Scaling is per MOVE, not per hit: a multi-hit move is one stage. For the
-- k-th move of a combo the total reduction, in percent, is
--
--   combo scaling     +10 per move from the 3rd move on
--   starter scaling   normal starter: +10 from the 3rd move on
--                     light normal as move 1: +20 from the 2nd move on, and
--                     then the normal starter +10 is NOT added
--   cap               the total never exceeds 90
--
-- which gives 100, 100, 80, 70, 60 ... 10, 10 for most starters and 100, 80,
-- 70, 60 ... for a light one. Then, per move:
--
--   Drive Rush        x0.85 for every move after the first Drive Rush Cancel
--                     in the route; a second rush does not stack
--   Modern SP         x0.8 for a move done with the SP button (input_method
--                     "simple") - that move only
--   SA minimum        a Super Art's factor is never below 30% / 40% / 50% for
--                     level 1 / 2 / 3
--
-- ORDER OF OPERATIONS
--
-- The note defines 最終ダメージ補正値 (the final correction) as
-- (100 - total combo reduction) * PP * DR * attack power * Modern, and says the
-- SA minimum replaces THAT final correction when it is lower. So the minimum
-- is applied last, after Drive Rush and Modern, not to the combo term alone:
--
--   factor = max( (1 - reduction/100) * dr_mult * modern_mult , sa_minimum )
--
-- No rounding anywhere. The game truncates decimals; this does not, because
-- the point is an ordering and a truncation would only add ties.

local InputMask = require("func/ComboExplorer/core/InputMask")

local M = { name = "ComboExplorer.DamageScaling" }

M.MODEL_ID = "sf6-public-scaling-v1"

M.SOURCES = {
    "https://note.com/libitina_dgh/n/n6dd052c3f434",
    "https://diamondlobby.com/street-fighter-6/how-scaling-works-sf6/",
}

-- Every number the model uses. Overridable per call (see M.scale_route's
-- params argument) so a measurement that disagrees can be tried without
-- editing the rules. Values from the note above unless said otherwise.
M.PARAMS = {
    -- コンボ補正: +10 for each move from the 3rd one.
    combo_reduction_per_stage = 10,
    combo_reduction_from_stage = 3,
    -- 通常始動補正: +10 from the 3rd move, when no special starter applies.
    normal_starter_reduction = 10,
    normal_starter_from_stage = 3,
    -- 特殊始動補正 for a light normal as move 1: added from the 2nd move, and it
    -- replaces the normal starter scaling. The note says special starter
    -- values are set per move and gives no light figure; 20 is the value the
    -- user chose. diamondlobby's light table reads 100 > 90 > 80 > 70, which
    -- does not agree with it - one more reason this is a parameter.
    light_starter_reduction = 20,
    light_starter_from_stage = 2,
    -- 合計コンボ補正値 above 90 is replaced with 90: a floor of 10%.
    max_total_reduction = 90,
    -- DR補正: 85% from the moment a Drive Rush happens in the combo. Once.
    drive_rush_multiplier = 0.85,
    -- モダン補正: 80% on a move performed with the SP button only.
    modern_simple_multiplier = 0.8,
    -- 最低保証値: the final correction of an SA hit is never below these.
    sa_minimum = { [1] = 0.30, [2] = 0.40, [3] = 0.50 },
    -- SA level from the frame source's super cost (super_gain_on_hit). A
    -- Critical Art is -30000 as well, and takes level 3's minimum.
    sa_level_by_super_gain = { [-10000] = 1, [-20000] = 2, [-30000] = 3 },
}

M.NOT_MODELLED = {
    "per-move immediate scaling (即時補正)",
    "special starter scaling for anything but a light normal as move 1 (values are per move and in no data here)",
    "counter hit and punish counter starts",
    "Drive Impact and perfect parry starts (PP補正 50%)",
    "attack power modifiers (攻撃力補正)",
    "hit-count interactions within one move (a multi-hit move is one stage here)",
    "Modern assist (AUTO) input - the source's 80% rule covers the SP button only",
    "rounding: the game truncates decimals, this model does not",
    "a Super Art with no known level gets no minimum guarantee",
}

-- The descriptor Scoring attaches next to the figure.
function M.model()
    local src, nm = {}, {}
    for i, v in ipairs(M.SOURCES) do src[i] = v end
    for i, v in ipairs(M.NOT_MODELLED) do nm[i] = v end
    return {
        id = M.MODEL_ID,
        verified = false,
        use = "ordering only; not a damage figure and never exported as one",
        order_of_operations = "max((1 - reduction/100) * drive_rush * modern_simple, sa_minimum)",
        source = src,
        not_modelled = nm,
    }
end

local function merged(params)
    if params == nil then return M.PARAMS end
    local p = {}
    for k, v in pairs(M.PARAMS) do p[k] = v end
    for k, v in pairs(params) do p[k] = v end
    return p
end

-- --- pure pieces -------------------------------------------------------------

-- Total reduction, in percent, for the stage-th move of a combo.
function M.reduction(stage, light_starter, params)
    local p = merged(params)
    local r = 0
    if stage >= p.combo_reduction_from_stage then
        r = r + p.combo_reduction_per_stage * (stage - p.combo_reduction_from_stage + 1)
    end
    if light_starter then
        if stage >= p.light_starter_from_stage then r = r + p.light_starter_reduction end
    elseif stage >= p.normal_starter_from_stage then
        r = r + p.normal_starter_reduction
    end
    return math.min(r, p.max_total_reduction)
end

-- The factor one move's damage is multiplied by. Every input explicit, so the
-- order of operations is the only thing this function decides.
--   reduction      percent, from M.reduction
--   drive_rush     true once a Drive Rush Cancel has happened earlier in the route
--   simple_input   true when the move is done with the SP button
--   sa_level       1, 2, 3 or nil
function M.factor(reduction, drive_rush, simple_input, sa_level, params)
    local p = merged(params)
    local f = (1 - reduction / 100)
    if drive_rush then f = f * p.drive_rush_multiplier end
    if simple_input then f = f * p.modern_simple_multiplier end
    local floor = sa_level and p.sa_minimum[sa_level] or nil
    local guaranteed = false
    if floor and f < floor then f, guaranteed = floor, true end
    return f, guaranteed
end

-- A light NORMAL: category normal or command_normal, and the one button in it
-- is the light one - 弱 in Modern notation, LP or LK in classic.
function M.is_light_normal(step)
    if type(step) ~= "table" then return false end
    if step.category ~= "normal" and step.category ~= "command_normal" then return false end
    local parsed = type(step.notation) == "string" and InputMask.parse(step.notation) or nil
    if parsed then
        local buttons = {}
        for _, b in ipairs(parsed.buttons) do
            if b ~= "AUTO" then buttons[#buttons + 1] = b end
        end
        return #buttons == 1 and buttons[1] == "L"
    end
    if type(step.classic) == "string" then
        local b = step.classic:upper():gsub("[%d%+%s>%[%]]", "")
        return b == "LP" or b == "LK"
    end
    return false
end

function M.sa_level(super_gain, params)
    if super_gain == nil then return nil end
    return merged(params).sa_level_by_super_gain[super_gain]
end

-- --- a whole route -----------------------------------------------------------

-- steps : a route's steps. A step with a `kind` is not a move; today only
--         "drive_rush_cancel", which turns the Drive Rush multiplier on for
--         every move after it.
-- facts : one entry per MOVE, in move order: { predicted_damage, super_gain }
--         (RouteSearch writes these as basis.move_frame_facts).
--
-- Returns {
--   total  = sum of damage * factor, or nil when any move has no damage figure,
--   steps  = per move { step_index, stage, damage, reduction, drive_rush,
--            simple_input, sa_level, sa_minimum_applied, factor, scaled },
--   light_starter, drive_rush_from_stage, sa_level_unknown_steps,
--   missing_damage_steps,
-- }
function M.scale_route(steps, facts, params)
    local p = merged(params)
    facts = facts or {}
    local out = { steps = {}, sa_level_unknown_steps = 0, missing_damage_steps = 0 }

    local first_move
    for _, s in ipairs(steps or {}) do
        if s.kind == nil then first_move = s break end
    end
    out.light_starter = M.is_light_normal(first_move)

    local stage, rushed, total = 0, false, 0
    for i, s in ipairs(steps or {}) do
        if s.kind == "drive_rush_cancel" then
            if not rushed then out.drive_rush_from_stage = stage + 1 end
            rushed = true
        elseif s.kind == nil then
            stage = stage + 1
            local fact = facts[stage] or {}
            local damage = fact.predicted_damage
            local level = M.sa_level(fact.super_gain, p)
            if s.category == "super" and level == nil then
                out.sa_level_unknown_steps = out.sa_level_unknown_steps + 1
            end
            local reduction = M.reduction(stage, out.light_starter, p)
            local simple = (s.input_method == "simple")
            local f, guaranteed = M.factor(reduction, rushed, simple, level, p)
            local scaled = damage and damage * f or nil
            out.steps[#out.steps + 1] = {
                step_index = s.index or i,
                stage = stage,
                damage = damage,
                reduction = reduction,
                drive_rush = rushed,
                simple_input = simple,
                sa_level = level,
                sa_minimum_applied = guaranteed,
                factor = f,
                scaled = scaled,
            }
            if scaled == nil then
                out.missing_damage_steps = out.missing_damage_steps + 1
                total = nil
            elseif total ~= nil then
                total = total + scaled
            end
        end
    end
    out.total = (stage > 0) and total or nil
    return out
end

return M
