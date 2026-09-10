-- Unit tests for func/ComboExplorer/core/CandidateGenerator.lua
--
-- The rule this module exists to hold: missing data is not a negative answer.
-- If the frame source has no startup for a move - Zangief's 5HP genuinely has
-- none - the pair is still a candidate. Treating absent information as "cannot
-- link" would delete a large part of the interesting space, and it would do it
-- invisibly: the edge simply would not appear.
--
-- A KNOWN negative margin is different, and is excluded with the number
-- attached so the decision can be argued with later.

local t = require("tests.lua.harness")
local CG = require("func/ComboExplorer/core/CandidateGenerator")
local Catalog = require("func/ComboExplorer/core/Catalog")
local FrameData = require("func/ComboExplorer/core/FrameData")
local Schema = require("func/ComboExplorer/core/Schema")

local cat = Catalog.build(dofile("tests/lua/fixtures/zangief_catalog.lua"))
local idx = FrameData.index(dofile("data/frame-data/zangief.lua"))

local GROUND = { categories = { "normal", "command_normal" }, input_methods = { "manual" } }

local result = CG.generate(cat, idx, { from = GROUND, include_followups = false })

-- --- it produces something ---------------------------------------------------

t.group("generation over the real data")

t.ok(result ~= nil, "generation runs on the real catalog and frame data")
t.ok(#result.candidates > 0, "and produces candidates (" .. #result.candidates .. ")")
t.eq(result.stats.from_moves, 14, "from the fourteen Modern ground normals")
t.ok(result.stats.pairs_considered >= 14 * 14, "considering every ordered pair")

-- Every candidate is theoretical and says so in the record itself.
for _, e in ipairs(result.candidates) do
    t.eq(e.status, "theoretical", ("edge %s is theoretical"):format(e.id))
    t.eq(e.runtime_verified, false, ("edge %s is not runtime-verified"):format(e.id))
end

-- And every one of them validates against the schema, which is where the
-- "nothing is fully decidable offline" rule is enforced.
local bad = 0
for _, e in ipairs(result.candidates) do
    if not Schema.validate(Schema.KIND.EDGE, e) then bad = bad + 1 end
end
t.eq(bad, 0, "every candidate validates as an edge")

-- --- the reasoning is structured --------------------------------------------

t.group("reasons")

local by_id = {}
for _, e in ipairs(result.candidates) do by_id[e.id] = e end

-- 2LP is +6 on hit, 2MP starts in 8: a two-frame deficit, so no plain link -
-- but 2LP cancels into specials, and 2MP is a normal, so nothing carries it.
-- 5LP is +4, 2LP starts in 6: also short.
-- 2HK is +36 on hit (a hard knockdown), so it links into everything.
local hk_to_mp = by_id["633:manual->621:manual"]
t.ok(hk_to_mp ~= nil, "2HK -> 2MP is a candidate")
t.ok(hk_to_mp.basis.margin_frames and hk_to_mp.basis.margin_frames > 20,
     "with a large frame margin (" .. tostring(hk_to_mp.basis.margin_frames) .. ")")
local reasons = {}
for _, r in ipairs(hk_to_mp.reasons) do reasons[r] = true end
t.ok(reasons.frame_link, "and the reason is a frame link")

-- But a +36 advantage is a knockdown, and a knockdown's advantage is time
-- before the opponent stands up, not time to land another hit. Nothing in the
-- source says so - this character's data has no knockdown property at all - so
-- it is a suspicion that caps confidence rather than grounds to drop the pair.
t.eq(hk_to_mp.confidence, "medium",
     "a suspiciously large advantage is not high confidence, however clean the numbers")
t.ok(hk_to_mp.basis.from_on_hit_suspected_knockdown, "and the suspicion is recorded")
local u = {}
for _, x in ipairs(hk_to_mp.requires_runtime_validation) do u[x] = true end
t.ok(u.knockdown_vs_link_advantage, "with the question handed to the game")

-- Worth stating plainly, because it is a real finding rather than a gap in the
-- code: restricted to ground normals, Zangief has NO high-confidence
-- candidates. Every wide margin he has belongs to a knockdown, and his ordinary
-- normals are all slightly negative into each other. He is a grappler; his
-- combos run through cancels, not through normal-into-normal links.
local high_in_normals = 0
for _, e in ipairs(result.candidates) do
    if e.confidence == "high" then high_in_normals = high_in_normals + 1 end
end
t.eq(high_in_normals, 0,
     "no high-confidence candidate exists among ground normals alone - which is a "
     .. "fact about Zangief, not a bug")

-- Widen the target set to what his combos actually use, and the picture
-- changes: a normal that cancels into specials, aimed at a special, is a case
-- where both halves of the reasoning are present.
local with_specials = CG.generate(cat, idx, {
    from = GROUND,
    to = { input_methods = { "manual", "simple" } },
    include_followups = false,
})
local high_cancel
for _, e in ipairs(with_specials.candidates) do
    if e.confidence == "high" then high_cancel = e break end
end
t.ok(high_cancel ~= nil, "with specials as targets, high-confidence candidates appear")
local hr = {}
for _, r in ipairs(high_cancel.reasons) do hr[r] = true end
t.ok(hr.special_cancel or hr.super_cancel or hr.frame_link,
     "and they rest on a named mechanism")

-- A chain cancel is only half known: the source says the move chains, not what
-- it chains into. Claiming high confidence there would assert knowledge the
-- data does not contain.
local chain
for _, e in ipairs(result.candidates) do
    local rr = {}
    for _, r in ipairs(e.reasons) do rr[r] = true end
    if rr.chain_cancel and not rr.frame_link then chain = e break end
end
if chain then
    t.eq(chain.confidence, "medium", "a chain cancel alone is medium, not high")
else
    t.ok(true, "no chain-only candidate in this scope")
end

-- Chains are a separate mechanism and get their own reason.
local light_chain = by_id["617:manual->617:manual"] or by_id["601:manual->617:manual"]
t.ok(light_chain ~= nil, "a light into a light is a candidate")

-- --- missing data does not delete a candidate --------------------------------

t.group("missing data is not a negative answer")

-- Zangief's 5HP has a null startup in the source. Every pair INTO it therefore
-- cannot be judged on frames - and must still be a candidate.
local into_hp = {}
for _, e in ipairs(result.candidates) do
    if e.to.action_id == 637 then into_hp[#into_hp + 1] = e end
end
t.ok(#into_hp > 0, "pairs into 5HP survive despite its unknown startup (" .. #into_hp .. ")")

local sample = into_hp[1]
local sr = {}
for _, r in ipairs(sample.reasons) do sr[r] = true end
t.ok(sr.frame_data_incomplete, "and the reason names the gap rather than inventing a link")
t.eq(sample.confidence, "low", "with low confidence, because the case rests on absence")
t.is_nil(sample.basis.to_startup, "the missing value is nil, not a fabricated number")

-- Nothing was excluded for lacking data.
for _, x in ipairs(result.excluded) do
    t.ok(x.reason ~= "frame_data_incomplete",
         "nothing is excluded merely for missing data")
end

-- --- a known negative margin IS an answer -----------------------------------

t.group("a known negative margin excludes, with the number")

t.ok(#result.excluded > 0, "some pairs are excluded (" .. #result.excluded .. ")")
t.ok(result.stats.by_exclusion.frame_margin_negative ~= nil,
     "including for a negative frame margin")

local neg
for _, x in ipairs(result.excluded) do
    if x.reason == "frame_margin_negative" then neg = x break end
end
t.ok(neg ~= nil, "and one can be found")
t.ok(neg.margin_frames ~= nil and neg.margin_frames < 0,
     "carrying the margin that decided it (" .. tostring(neg.margin_frames) .. ")")
t.ok(neg.basis ~= nil, "and the numbers behind it, so the decision can be argued with")

-- The cutoff is configurable, because counter hit and drive rush move it.
local generous = CG.generate(cat, idx,
    { from = GROUND, include_followups = false, margin_cutoff = -4 })
t.ok(#generous.candidates > #result.candidates,
     "a more generous cutoff admits more pairs (" .. #generous.candidates .. ")")

-- --- every candidate names what only the game can settle ---------------------

t.group("requires_runtime_validation")

for _, e in ipairs(result.candidates) do
    local u = {}
    for _, x in ipairs(e.requires_runtime_validation) do u[x] = true end
    t.ok(u.pushback_range and u.modern_specific_scaling and u.actual_input_timing,
         ("edge %s carries the three standing unknowns"):format(e.id))
end

-- The list is not decoration: each entry has a stated reason.
local e1 = result.candidates[1]
for _, u in ipairs(e1.requires_runtime_validation) do
    t.ok(type(e1.unknown_detail[u]) == "string" and #e1.unknown_detail[u] > 0,
         ("unknown %s says why it applies"):format(u))
end

-- The canonical question reaches the edges: while the catalog cannot say which
-- action id an input produces, an edge about that move is about an uncertain
-- move.
local unresolved_noted = false
for _, e in ipairs(result.candidates) do
    if e.from.canonical_status ~= "verified" then
        for _, u in ipairs(e.requires_runtime_validation) do
            if u == "hitbox_hurtbox" then unresolved_noted = true end
        end
    end
end
t.ok(unresolved_noted, "an unresolved canonical id is recorded as a runtime unknown")

-- --- self pairs --------------------------------------------------------------

t.group("a move into itself")

-- The same move twice is only a link if it chains. 2MP does not chain, so
-- 2MP -> 2MP must not appear.
t.is_nil(by_id["621:manual->621:manual"], "2MP into itself is not a candidate")
t.ok(result.stats.by_exclusion.self_pair_without_chain ~= nil,
     "and the exclusion is recorded by name")

-- 2LP does chain, so 2LP into 2LP is legitimate.
t.ok(by_id["617:manual->617:manual"] ~= nil or by_id["618:manual->618:manual"] ~= nil,
     "a chaining light into itself is a candidate")

-- --- follow-ups are edges even though they are not moves ---------------------

t.group("target-combo derivations")

local with_followups = CG.generate(cat, idx, { from = GROUND, include_followups = true })
t.ok(with_followups.stats.followup_edges > 0,
     "edges into follow-ups are produced (" .. with_followups.stats.followup_edges .. ")")

local fu
for _, e in ipairs(with_followups.candidates) do
    if e.context_dependent then fu = e break end
end
t.ok(fu ~= nil, "a context-dependent edge exists")
t.eq(fu.context_dependent, true, "and is marked as such")

-- 5MP is the move whose frame data says target_combo; its derivation is 605/606.
local tc_found = false
for _, e in ipairs(with_followups.candidates) do
    if e.from.action_id == 604 and (e.to.action_id == 605 or e.to.action_id == 606) then
        for _, r in ipairs(e.reasons) do
            if r == "target_combo" then tc_found = true end
        end
    end
end
t.ok(tc_found, "5MP into its target-combo follow-up is found, with the target_combo reason")

-- --- no frame data at all ----------------------------------------------------

t.group("with no frame data")

-- The generator must still work, with everything low confidence and nothing
-- excluded for numbers it never had.
local blind = CG.generate(cat, nil, { from = GROUND, include_followups = false })
t.ok(#blind.candidates > #result.candidates,
     "without frame data every pair is a candidate (" .. #blind.candidates .. ")")
t.is_nil(blind.stats.by_exclusion.frame_margin_negative,
     "and nothing is excluded on a margin nobody knows")
for _, e in ipairs(blind.candidates) do
    t.eq(e.confidence, "low", ("edge %s is low confidence without numbers"):format(e.id))
end

-- --- degenerate input --------------------------------------------------------

t.group("degenerate input")

t.is_nil(CG.generate(nil, idx, {}), "no catalog is refused")
t.is_nil(CG.generate({}, idx, {}), "a table that is not a catalog is refused")

return t.finish()
