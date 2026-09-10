-- Unit tests for func/ComboExplorer/core/DamageTracker.lua
--
-- These are the cases that would otherwise only be discovered by running the
-- game and getting a wrong number: the field reading zero, the field never
-- resolving, a lethal combo capping the HP delta, and the training dummy
-- healing itself mid-sample. All of them produce a plausible-looking damage
-- figure if nobody checks for them.

local t = require("tests.lua.harness")
local DT = require("func/ComboExplorer/core/DamageTracker")

local function run(readings)
    local tr = DT.new()
    tr:begin(nil)
    for _, r in ipairs(readings) do tr:tick(r) end
    return tr:result()
end

-- --- the happy path ----------------------------------------------------------

t.group("both measurements agree")

local r = run({
    { combo_damage_attacker = 0,    victim_hp = 10000, combo_count = 0 },
    { combo_damage_attacker = 800,  victim_hp = 9200,  combo_count = 1 },
    { combo_damage_attacker = 1500, victim_hp = 8500,  combo_count = 2 },
    { combo_damage_attacker = 0,    victim_hp = 8500,  combo_count = 0 },
})
t.eq(r.combo_damage, 1500, "the peak is banked when the field drops to zero")
t.eq(r.hp_delta, 1500, "the HP delta matches")
t.eq(r.agree, true, "and they agree")
t.eq(r.hits, 2, "hit count is the maximum seen")
t.ok(r.field_resolved, "field resolved")
t.ok(r.field_nonzero, "field read non-zero")

-- --- the field is not cumulative --------------------------------------------

t.group("banking across segments")

-- Two combos in one sample window: the field resets between them, so the total
-- only comes out right if each peak is banked.
r = run({
    { combo_damage_attacker = 0 },
    { combo_damage_attacker = 900 },
    { combo_damage_attacker = 0 },
    { combo_damage_attacker = 1200 },
    { combo_damage_attacker = 0 },
})
t.eq(r.combo_damage, 2100, "two segments bank to their sum")

-- A sample that ends while the combo is still running must still count.
r = run({
    { combo_damage_attacker = 0 },
    { combo_damage_attacker = 700 },
})
t.eq(r.combo_damage, 700, "an unbanked peak is still included in the total")

-- --- the field silently reading zero ----------------------------------------

t.group("field reads zero")

-- This is the failure the whole two-measurement design exists for: without the
-- HP delta this would look like a real combo that dealt no damage.
r = run({
    { combo_damage_attacker = 0, victim_hp = 10000 },
    { combo_damage_attacker = 0, victim_hp = 8800 },
    { combo_damage_attacker = 0, victim_hp = 8800 },
})
t.eq(r.combo_damage, 0, "a resolved field that read zero is a measured 0, not nil")
t.eq(r.hp_delta, 1200, "but the HP delta caught the damage")
t.is_nil(r.agree, "no comparison is attempted")
t.ok(r.agree_reason:find("never read above zero", 1, true) ~= nil, "and the reason says so")
t.ok(r.field_resolved, "the field did resolve")
t.eq(r.field_nonzero, false, "it just never read above zero")

t.group("field never resolves")

r = run({
    { victim_hp = 10000 },
    { victim_hp = 9100 },
})
t.eq(r.field_resolved, false, "field never resolved")
t.is_nil(r.combo_damage, "an unresolved field reports nil, NOT 0 - the two are different facts")
t.eq(r.hp_delta, 900, "HP delta still works")
t.is_nil(r.agree, "nothing to compare")
t.ok(r.agree_reason:find("never resolved", 1, true) ~= nil, "reason given")

-- --- the traps ---------------------------------------------------------------

t.group("lethal combo")

-- The HP delta is capped at zero HP while mComboDamage is not, so comparing
-- them on a kill would manufacture a disagreement that is not real.
r = run({
    { combo_damage_attacker = 0,    victim_hp = 1000 },
    { combo_damage_attacker = 2500, victim_hp = 0 },
})
t.eq(r.combo_damage, 2500, "the field reports the real damage")
t.eq(r.hp_delta, 1000, "the HP delta is capped at the health that existed")
t.is_nil(r.agree, "the two are not compared")
t.ok(r.agree_reason:find("capped", 1, true) ~= nil, "and the reason names the cap")

t.group("dummy heals mid-sample")

-- Training mode can restore the dummy's health. The min-delta would then be
-- measured from a baseline that no longer means anything.
r = run({
    { combo_damage_attacker = 0,    victim_hp = 10000 },
    { combo_damage_attacker = 1100, victim_hp = 8900 },
    { combo_damage_attacker = 0,    victim_hp = 10000 },
})
t.ok(r.hp_recovered, "the recovery is detected")
t.is_nil(r.agree, "so the HP delta is not compared")
t.ok(r.agree_reason:find("increased", 1, true) ~= nil, "and the reason says why")
t.eq(r.combo_damage, 1100, "the field measurement is unaffected")

t.group("real disagreement")

r = run({
    { combo_damage_attacker = 0,    victim_hp = 10000 },
    { combo_damage_attacker = 1500, victim_hp = 9000 },
    { combo_damage_attacker = 0,    victim_hp = 9000 },
})
t.eq(r.agree, false, "1500 vs 1000 is a genuine disagreement")
t.is_nil(r.agree_reason, "and it is reported as a comparison, not a non-comparison")

-- Tolerance exists because the two are sampled on the same tick but updated by
-- the engine at slightly different moments.
local tr = DT.new()
tr:begin(nil)
tr:tick({ combo_damage_attacker = 0, victim_hp = 10000 })
tr:tick({ combo_damage_attacker = 1001, victim_hp = 9000 })
tr:tick({ combo_damage_attacker = 0, victim_hp = 9000 })
t.eq(tr:result({ tolerance = 1 }).agree, true, "an off-by-one is within tolerance")
t.eq(tr:result({ tolerance = 0 }).agree, false, "and outside a zero tolerance")

-- --- which side carries the value -------------------------------------------

t.group("which side answers")

r = run({
    { combo_damage_attacker = 0,   combo_damage_victim = 0 },
    { combo_damage_attacker = 0,   combo_damage_victim = 1800 },
})
t.eq(r.combo_damage, 1800, "max() of the two sides, as upstream does")
t.eq(r.attacker_side_max, 0, "attacker side recorded")
t.eq(r.victim_side_max, 1800, "victim side recorded")

-- --- the conclusion the probe exists to produce -----------------------------

t.group("conclude")

-- `{ agree = nil }` in a table constructor does not create the key, so an
-- override table cannot express "set this back to nil". NONE is that sentinel;
-- without it these tests would silently keep the default and pass for the wrong
-- reason.
local NONE = {}

local function sample(over)
    local s = { field_resolved = true, field_nonzero = true, agree = true,
                attacker_side_max = 1000, victim_side_max = 0 }
    for k, v in pairs(over or {}) do
        -- Not `(v == NONE) and nil or v`: in Lua that expression can never
        -- yield nil, because `and nil` is falsy and control falls through to
        -- `or v`. It would set the field to the sentinel itself and the test
        -- would pass for the wrong reason.
        if v == NONE then s[k] = nil else s[k] = v end
    end
    return s
end

local c = DT.conclude({})
t.eq(c.recommended_source, "undecided", "no samples decides nothing")
t.eq(c.sufficient, false, "and is not sufficient")

c = DT.conclude({ sample(), sample() })
t.eq(c.recommended_source, "undecided", "two agreeing samples is not yet a recommendation")
t.ok(c.verdict:find("n=2", 1, true) ~= nil, "and the verdict states n")

c = DT.conclude({ sample(), sample(), sample() })
t.eq(c.recommended_source, "combo_damage", "three clean agreeing samples endorse the field")
t.eq(c.carrying_side, "attacker", "and identify which side carries it")
t.ok(c.sufficient, "three comparable samples is enough to act on")

c = DT.conclude({ sample({ field_resolved = false, agree = NONE }),
                  sample({ field_resolved = false, agree = NONE }) })
t.eq(c.recommended_source, "hp_delta", "a field that never resolves sends us to HP")

c = DT.conclude({ sample({ field_nonzero = false, agree = NONE }),
                  sample({ field_nonzero = false, agree = NONE }) })
t.eq(c.recommended_source, "hp_delta", "a field that always reads zero sends us to HP")

c = DT.conclude({ sample(), sample({ agree = false }), sample() })
t.eq(c.recommended_source, "both", "any disagreement means keep recording both")

-- The third answer: the two are the same quantity at different scales. Without
-- looking for it, that reads as a flat disagreement and the real relationship
-- is never noticed. focus_new is already known to be raw/10000 in this
-- codebase, so a scaled field is not a hypothetical.
t.group("a scale factor is not a disagreement")

local function scaled(ratio, hp_delta)
    return { field_resolved = true, field_nonzero = true, agree = false,
             ratio = ratio, hp_delta = hp_delta,
             attacker_side_max = (hp_delta or 0) * ratio, victim_side_max = 0 }
end

-- Combos of visibly different length, all showing the same ratio: that is a
-- scale, and it is a usable answer rather than a failure.
c = DT.conclude({ scaled(10.0, 800), scaled(10.001, 1600), scaled(9.999, 2400) })
t.ok(c.scale_factor ~= nil, "a consistent ratio across different combo sizes is detected")
t.ok(math.abs(c.scale_factor - 10) < 0.01, "and reported as roughly 10x")
t.eq(c.recommended_source, "combo_damage_scaled", "which is usable, not a failure")
t.ok(c.verdict:find("scale", 1, true) ~= nil, "and the verdict names it")

-- The same ratio across combos that were all the same size proves nothing: a
-- fixed per-hit offset produces exactly that pattern. This was a real bug in
-- this project's own probe, and the tests caught the ratio detector agreeing
-- with it.
c = DT.conclude({ scaled(1.875, 800), scaled(1.875, 800), scaled(1.875, 800) })
t.is_nil(c.scale_factor, "a constant ratio across identical combos is NOT called a scale")
t.ok(c.scale_note ~= nil, "instead the report says what to do about it")
t.ok(c.scale_note:find("different lengths", 1, true) ~= nil, "namely vary the combo length")
t.ok(c.verdict:find("same size", 1, true) ~= nil, "and the verdict carries that note")

-- Noise must not be mistaken for a scale.
c = DT.conclude({ scaled(1.4, 800), scaled(0.7, 1600), scaled(2.9, 2400) })
t.is_nil(c.scale_factor, "a scattered ratio is not a scale factor")
t.is_nil(c.scale_note, "and it is not the same-size case either")
t.eq(c.recommended_source, "both", "so it stays a disagreement")

-- A ratio of 1 is agreement, not a scale.
c = DT.conclude({ scaled(1.0, 800), scaled(1.0, 1600), scaled(1.0, 2400) })
t.is_nil(c.scale_factor, "a ratio of 1 is not reported as a scale")

c = DT.conclude({ sample({ agree = NONE }), sample({ agree = NONE }) })
t.eq(c.recommended_source, "undecided", "non-comparable samples decide nothing")

c = DT.conclude({ sample(), sample() })
t.eq(c.sufficient, false, "two samples is not yet enough")

c = DT.conclude({ sample({ victim_side_max = 900, attacker_side_max = 0 }),
                  sample({ victim_side_max = 900, attacker_side_max = 0 }),
                  sample({ victim_side_max = 900, attacker_side_max = 0 }) })
t.eq(c.carrying_side, "victim", "a victim-side-only field is identified")

-- --- degenerate input --------------------------------------------------------

t.group("degenerate input")

local empty = DT.new():result()
t.is_nil(empty.combo_damage, "an untouched tracker reports nil, not a measured zero")
t.is_nil(empty.hp_delta, "and no HP delta")
t.eq(empty.field_resolved, false, "and nothing resolved")

local ignore = DT.new()
ignore:tick(nil)
ignore:tick("not a table")
t.eq(ignore:result().ticks, 0, "non-table readings are ignored, not counted")

return t.finish()
