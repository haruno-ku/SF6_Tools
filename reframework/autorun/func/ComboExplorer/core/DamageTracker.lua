-- =========================================================
-- ComboExplorer/core/DamageTracker.lua - turns per-tick readings into a damage
-- figure, two ways, and says whether they agree.
-- Pure: takes numbers, returns numbers. No sdk, no player objects.
-- =========================================================
--
-- WHY TWO MEASUREMENTS
--
-- cPlayer.mpTeam.mComboDamage is read at exactly one site in all of upstream,
-- inside a pcall, and its author wrote an HP-delta fallback for the case where
-- it reads zero (TrainingComboTrials_v1.0.lua:4226, :6126-6134). Whether it
-- resolves on this build is unverified - see Provenance.combo_damage_readable.
--
-- If it silently reads zero, and the Explorer trusts it, every edge in the
-- graph records damage 0 and the entire ranking phase sorts by a constant while
-- looking perfectly healthy. So every trial measures both ways and stores both,
-- and a disagreement is recorded rather than resolved. The decision about which
-- one to trust is made once, from real samples, not per-trial by a heuristic.
--
-- WHY IT IS A TRACKER AND NOT A FUNCTION
--
-- The field is not cumulative. It resets to zero between combos, so the running
-- total is manufactured by banking each segment's peak - which needs a tick.
--
-- The HP side has its own trap: the training dummy can regain health, and chip
-- damage lands outside a combo. So the tracker watches for HP going UP and
-- marks the delta unreliable rather than reporting a smaller number.

local M = { name = "ComboExplorer.DamageTracker" }

local Tracker = {}
Tracker.__index = Tracker
M.Tracker = Tracker

-- A reading is whatever the runtime managed to read this tick. Every field is
-- optional, and nil means "could not read", which is different from 0:
--
--   combo_damage_attacker : mpTeam.mComboDamage on the attacking player
--   combo_damage_victim   : the same field on the victim
--   victim_hp             : vital_new on the victim
--   combo_count           : combo_cnt on the attacker
--
-- Upstream takes max() of the two damage sides because it does not know which
-- one carries the value. We keep that, and record which side answered so the
-- question can actually be settled from the samples.
function M.new()
    return setmetatable({}, Tracker):begin(nil)
end

function Tracker:begin(reading)
    self.peak = 0
    self.banked = 0
    self.ticks = 0

    self.field_resolved = false   -- did either side ever read non-nil?
    self.field_nonzero = false    -- did either side ever read > 0?
    self.attacker_side_max = nil
    self.victim_side_max = nil

    self.hp_base = nil
    self.hp_min = nil
    self.hp_last = nil
    self.hp_recovered = false     -- HP went UP: the delta is no longer a damage figure

    self.max_combo_count = 0

    if reading then self:tick(reading) end
    return self
end

function Tracker:tick(reading)
    if type(reading) ~= "table" then return self end
    self.ticks = self.ticks + 1

    local a = reading.combo_damage_attacker
    local v = reading.combo_damage_victim
    if a ~= nil or v ~= nil then
        self.field_resolved = true
        if a ~= nil and (self.attacker_side_max == nil or a > self.attacker_side_max) then
            self.attacker_side_max = a
        end
        if v ~= nil and (self.victim_side_max == nil or v > self.victim_side_max) then
            self.victim_side_max = v
        end

        local cur = math.max(a or 0, v or 0)
        if cur > 0 then self.field_nonzero = true end
        if cur > self.peak then
            self.peak = cur
        elseif cur == 0 and self.peak > 0 then
            -- Segment ended. Banking its peak is what makes the total
            -- cumulative; the field itself never is.
            self.banked = self.banked + self.peak
            self.peak = 0
        end
    end

    local hp = reading.victim_hp
    if hp ~= nil then
        if self.hp_base == nil then
            self.hp_base = hp
            self.hp_min = hp
        end
        if hp < self.hp_min then self.hp_min = hp end
        -- Training-mode health restore, or a dummy setting that refills. Either
        -- way the min-delta stops being "damage this combo dealt".
        if self.hp_last ~= nil and hp > self.hp_last then self.hp_recovered = true end
        self.hp_last = hp
    end

    local c = reading.combo_count
    if c ~= nil and c > self.max_combo_count then self.max_combo_count = c end

    return self
end

-- Both figures, plus an explicit judgement about whether they can be compared
-- at all. `agree` is deliberately three-valued:
--
--   true  : both available, comparable, and within tolerance
--   false : both available, comparable, and different
--   nil   : not comparable - and `agree_reason` says why
function Tracker:result(opts)
    opts = opts or {}
    local tolerance = opts.tolerance or 1

    -- nil, not 0, when the field never resolved. A measured zero and an
    -- unreadable field are different facts, and collapsing them means a
    -- downstream consumer that sorts by damage ranks the whole dataset by a
    -- constant while everything looks healthy.
    local combo_damage = nil
    if self.field_resolved then
        combo_damage = self.banked + self.peak
    end

    local hp_delta = nil
    if self.hp_base ~= nil and self.hp_min ~= nil then
        hp_delta = math.max(0, self.hp_base - self.hp_min)
    end

    -- Kept alongside the difference because the two might be the same quantity
    -- at different scales - focus_new is already known to be raw/10000 in this
    -- codebase. A pure scale factor reads as a disagreement unless the ratio is
    -- recorded and someone can look at it.
    local ratio = nil
    if combo_damage ~= nil and hp_delta ~= nil and hp_delta > 0 then
        ratio = combo_damage / hp_delta
    end

    local agree, reason = nil, nil
    if opts.hp_arm_usable == false then
        -- The victim's health is not a damage measurement under these training
        -- settings. Comparing against it would manufacture a disagreement and
        -- blame the damage field for a menu option.
        reason = opts.hp_arm_reason or "the HP arm is invalid under the current training settings"
    elseif opts.hp_arm_usable == nil and opts.require_hp_arm_check then
        reason = "the training health settings could not be read, so the HP arm cannot be trusted"
    elseif not self.field_resolved then
        reason = "mComboDamage never resolved"
    elseif not self.field_nonzero then
        reason = "mComboDamage resolved but never read above zero"
    elseif hp_delta == nil then
        reason = "victim HP was never read"
    elseif self.hp_recovered then
        reason = "victim HP increased during the sample - the delta is not a damage figure"
    elseif self.hp_min ~= nil and self.hp_min <= 0 then
        -- The HP delta is capped at lethal while mComboDamage is not, so they
        -- legitimately diverge on a killing blow. Comparing them there would
        -- manufacture a disagreement.
        reason = "victim reached zero HP - the delta is capped and the two are not comparable"
    else
        agree = math.abs(combo_damage - hp_delta) <= tolerance
    end

    return {
        combo_damage = combo_damage,
        hp_delta = hp_delta,
        ratio = ratio,
        agree = agree,
        agree_reason = reason,
        field_resolved = self.field_resolved,
        field_nonzero = self.field_nonzero,
        attacker_side_max = self.attacker_side_max,
        victim_side_max = self.victim_side_max,
        hp_recovered = self.hp_recovered,
        hp_base = self.hp_base,
        hp_min = self.hp_min,
        hits = self.max_combo_count,
        ticks = self.ticks,
    }
end

-- --- fleet-level conclusion --------------------------------------------------

-- Given every sample from a probe run, state what the project should do about
-- damage. This is the answer probe A exists to produce, and it is computed here
-- rather than in the UI so it can be unit-tested against samples that would be
-- tedious to reproduce by hand on a real machine.
-- MIN_COMPARABLE is not a statistical claim, it is a guard against one lucky
-- sample. Two numbers matching once says almost nothing; three combos of
-- different lengths, at least one of them non-lethal, is the smallest sample
-- where a scale factor or a per-hit offset would have shown itself.
M.MIN_COMPARABLE = 3

function M.conclude(samples, opts)
    opts = opts or {}
    local min_comparable = opts.min_comparable or M.MIN_COMPARABLE

    local n = { total = 0, resolved = 0, nonzero = 0, comparable = 0, agreed = 0, recovered = 0 }
    local attacker_answers, victim_answers = 0, 0
    local ratios = {}

    for _, s in ipairs(samples or {}) do
        n.total = n.total + 1
        if s.field_resolved then n.resolved = n.resolved + 1 end
        if s.field_nonzero then n.nonzero = n.nonzero + 1 end
        if s.hp_recovered then n.recovered = n.recovered + 1 end
        if s.agree ~= nil then
            n.comparable = n.comparable + 1
            if s.agree then n.agreed = n.agreed + 1 end
        end
        if (s.attacker_side_max or 0) > 0 then attacker_answers = attacker_answers + 1 end
        if (s.victim_side_max or 0) > 0 then victim_answers = victim_answers + 1 end
        if s.ratio then
            ratios[#ratios + 1] = { ratio = s.ratio, size = s.hp_delta or s.combo_damage or 0 }
        end
    end

    -- A consistent ratio that is not 1 is the interesting third answer: same
    -- quantity, different scale. Without checking for it, that case reports as
    -- a flat disagreement and the real relationship is never noticed.
    --
    -- But a constant ratio across identical combos proves nothing - a per-hit
    -- offset produces exactly that. It is only evidence of a SCALE if it holds
    -- across combos of visibly different size, so the sample has to span a
    -- range before this is claimed.
    local scale, scale_note = nil, nil
    if #ratios >= min_comparable then
        local lo, hi, sum = ratios[1].ratio, ratios[1].ratio, 0
        local size_lo, size_hi = ratios[1].size, ratios[1].size
        for _, r in ipairs(ratios) do
            if r.ratio < lo then lo = r.ratio end
            if r.ratio > hi then hi = r.ratio end
            if r.size < size_lo then size_lo = r.size end
            if r.size > size_hi then size_hi = r.size end
            sum = sum + r.ratio
        end
        local mean = sum / #ratios
        local tight = (mean > 0) and ((hi - lo) / mean < 0.02)
        local not_unity = math.abs(mean - 1) > 0.02
        local spans_sizes = (size_lo > 0) and (size_hi / size_lo >= 1.5)

        if tight and not_unity and spans_sizes then
            scale = mean
        elseif tight and not_unity then
            scale_note = ("ratio is a consistent %.4gx, but every sample was about the same size - "
                .. "land combos of different lengths to tell a scale factor from a fixed offset")
                :format(mean)
        end
    end

    local side = "unknown"
    if attacker_answers > 0 and victim_answers == 0 then side = "attacker"
    elseif victim_answers > 0 and attacker_answers == 0 then side = "victim"
    elseif attacker_answers > 0 and victim_answers > 0 then side = "both" end

    local sufficient = (n.comparable >= min_comparable)

    -- Every verdict states n. A recommendation is only ever offered once the
    -- sample is large enough to have been able to disprove it - one matching
    -- pair of numbers is not evidence that a field is safe to build on.
    local verdict, use
    if n.total == 0 then
        verdict = "no samples yet - land some combos with the probe running"
        use = "undecided"
    elseif n.resolved == 0 then
        verdict = ("mComboDamage never resolved across %d samples - the HP delta is the only source")
            :format(n.total)
        use = "hp_delta"
    elseif n.nonzero == 0 then
        verdict = ("mComboDamage resolved but never read above zero across %d samples - "
            .. "the HP delta is the only source"):format(n.total)
        use = "hp_delta"
    elseif n.comparable == 0 then
        verdict = ("mComboDamage reads non-zero, but none of %d samples was comparable "
            .. "(lethal combos, or HP never read) - land a non-lethal combo"):format(n.total)
        use = "undecided"
    elseif scale then
        verdict = ("mComboDamage is a consistent %.4gx of the HP delta across %d comparable "
            .. "samples - same quantity, different scale, not a disagreement")
            :format(scale, n.comparable)
        use = sufficient and "combo_damage_scaled" or "undecided"
    elseif n.agreed == n.comparable and not sufficient then
        verdict = ("n=%d comparable samples, consistent so far - need %d before this is worth acting on")
            :format(n.comparable, min_comparable)
        use = "undecided"
    elseif n.agreed == n.comparable then
        verdict = ("mComboDamage agrees with the HP delta on all %d comparable samples")
            :format(n.comparable)
        use = "combo_damage"
    else
        verdict = ("mComboDamage and the HP delta disagree on %d of %d comparable samples - "
            .. "record both and do not trust either alone")
            :format(n.comparable - n.agreed, n.comparable)
        if scale_note then verdict = verdict .. " (" .. scale_note .. ")" end
        use = "both"
    end

    return {
        verdict = verdict,
        recommended_source = use,
        carrying_side = side,
        counts = n,
        scale_factor = scale,
        scale_note = scale_note,
        min_comparable = min_comparable,
        sufficient = sufficient,
    }
end

return M
