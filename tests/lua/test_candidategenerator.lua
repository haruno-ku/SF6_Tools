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

-- --- an exclusion carries the value that decided it -------------------------

t.group("every exclusion shows its working")

-- The rule is "missing data never excludes". Checking it needs each excluded
-- pair to carry the THING that decided it, not a sentence about it.
--
-- A sentence gets written whether or not it is true. tools/lua/survey.lua first
-- checked that a self-pair exclusion had an `evidence` string, and that check
-- passed even with the bug re-introduced that excludes on an UNKNOWN chain
-- property - because the string is written in both branches. The value cannot
-- lie the same way: `false` means the source stated it, nil means nobody knew,
-- and nil is not grounds to exclude anything.
local undecided = 0
for _, x in ipairs(result.excluded) do
    local justified
    if x.reason == "frame_margin_negative" then
        justified = type(x.margin_frames) == "number"
    elseif x.reason == "self_pair_without_chain" then
        justified = (x.chain_property == false)
    else
        justified = false
    end
    if not justified then undecided = undecided + 1 end
end
t.eq(undecided, 0, "no pair is excluded without the value that decided it")

local self_pair
for _, x in ipairs(result.excluded) do
    if x.reason == "self_pair_without_chain" then self_pair = x break end
end
t.ok(self_pair ~= nil, "a self-pair exclusion exists to inspect")
t.eq(self_pair.chain_property, false,
     "and it records that the source STATED the move does not chain")
t.ok(self_pair.chain_property ~= nil,
     "which is a different fact from nobody having said - the distinction the "
     .. "whole rule rests on")

-- With no frame data nothing is known, so nothing may be excluded at all.
local blind_excl = CG.generate(cat, nil, { from = GROUND, include_followups = false })
t.eq(#blind_excl.excluded, 0,
     "with no frame data there is nothing to decide on, so nothing is excluded")

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

-- --- move B is read against move A -------------------------------------------

t.group("a derivation edge carries the frames of the chain, not of nothing")

-- The source spells a derivation as a chain from the move before it - Zangief's
-- is "5MP~MP" - and the catalog spells it ">MP", which does not say what it
-- follows. Looked up a row at a time it joins to nothing, so every derivation
-- edge carried `frame_data_incomplete` and sat in `low` for want of a record
-- the source had all along.
--
-- The generator is the one place that knows the parent: in the edge (A -> B),
-- A is what B comes out of, by construction.

do
    local with_fups = CG.generate(cat, idx, { from = GROUND, include_followups = true })
    t.ok(with_fups ~= nil, "generation runs with derivations included")

    -- Split by whether move B's startup is known, which is the whole
    -- difference the parent makes.
    local knows, blind = {}, {}
    for _, e in ipairs(with_fups.candidates) do
        if e.context_dependent then
            if e.basis and e.basis.to_startup ~= nil then knows[#knows + 1] = e
            else blind[#blind + 1] = e end
        end
    end

    t.ok(#knows > 0, "some derivation edges know move B's startup (" .. #knows .. ")")
    -- There used to be a second half here: 54 derivation edges that did not
    -- know, all of them a follow-up after a move that is not its parent. Those
    -- are no longer edges (see the group below), so every derivation edge left
    -- is one whose parent the source names - and so knows its numbers.
    t.eq(#blind, 0, "and none is left blind, because the blind ones were not pairs")

    -- Not just "some": the ones that know are exactly the ones whose parent the
    -- source actually chains from. Zangief's source carries "5MP~MP" and no
    -- other chain into ">MP", so MP is the only A that can answer for it.
    for _, e in ipairs(knows) do
        t.eq(e.from.classic, "MP",
             ("%s knows to_startup, so its A must be the one the source chains from")
             :format(e.id))
        t.eq(e.to.classic, ">MP", ("%s ends on the derivation the chain names"):format(e.id))
    end

end

-- --- a follow-up only after its own parent ------------------------------------

t.group("a follow-up is paired only with the move the frame data names as its parent")

-- Zangief's four derivations are ">MP" (605, 606) and ">MK" (679, 680). The
-- source spells them "5MP~MP" and "22MK~MK", so their parents are MP and 22+MK,
-- and of the fourteen Modern ground normals only MP (604) is one - 22+MK is
-- not a starter. 14 starters x 4 follow-ups is 56 pairs; 2 are real.

do
    local r = CG.generate(cat, idx, { from = GROUND, include_followups = true })
    local fups = {}
    for _, e in ipairs(r.candidates) do
        if e.context_dependent then fups[#fups + 1] = e end
    end
    t.eq(#fups, 2, "two follow-up edges survive, out of 56 crossings")
    local ids = {}
    for _, e in ipairs(fups) do ids[e.id] = e end
    t.ok(ids["604:manual->605:manual"] ~= nil, "MP into >MP (605)")
    t.ok(ids["604:manual->606:manual"] ~= nil, "MP into >MP (606), which the data cannot tell apart")
    for _, e in ipairs(fups) do
        t.eq(e.context_known, true, e.id .. " says its context is known")
        t.eq(e.context_dependent, true, e.id .. " is still context-dependent")
        t.eq(e.basis.parent_record, "5MP~MP", e.id .. " names the record that vouches for it")
        t.ok(Schema.validate(Schema.KIND.EDGE, e), e.id .. " validates")
    end
    t.eq(r.stats.followup_edges, 2, "stats count the follow-up edges")
    t.eq(r.stats.followup_parent_named, 2, "and how many of them the source vouches for")

    -- Not dropped: excluded, by name, and counted.
    local reason = CG.EXCLUDED.FOLLOWUP_NOT_AFTER_PARENT
    t.eq(reason, "followup_after_a_move_not_its_parent", "the reason has a stable name")
    t.eq(r.stats.by_exclusion[reason], 54, "the other 54 are counted under it")
    local listed, sample = 0, nil
    for _, x in ipairs(r.excluded) do
        if x.reason == reason then
            listed = listed + 1
            sample = sample or x
        end
    end
    t.eq(listed, 54, "and each is in the excluded list, not silently gone")
    t.ok(sample and sample.from ~= 604, "none of them starts from the parent")
    t.ok(type(sample.parent_records) == "table" and #sample.parent_records > 0,
         "each carries the source records that name the real parent")

    -- Nothing else moved: the non-follow-up half is the run without follow-ups.
    local plain = CG.generate(cat, idx, { from = GROUND, include_followups = false })
    t.eq(#r.candidates - 2, #plain.candidates, "every other candidate is unchanged in number")
    t.eq(r.stats.by_exclusion.frame_margin_negative, plain.stats.by_exclusion.frame_margin_negative,
         "and the margin exclusions are the same ones")
    t.is_nil(plain.stats.by_exclusion[reason], "without follow-ups the reason never fires")
end

t.group("a follow-up whose parent nobody names is still a candidate")

-- The rule this module is built on, held at the edge of the new one. Silence
-- about a follow-up's parent is not a statement that A is not it.

do
    -- The same source with every chain removed: the follow-ups now have no
    -- parent named anywhere.
    local raw = dofile("data/frame-data/zangief.lua")
    local moves = {}
    for _, mv in ipairs(raw.moves) do
        if not tostring(mv.numpad):find("~", 1, true) then moves[#moves + 1] = mv end
    end
    local no_chains = FrameData.index({ _meta = raw._meta, moves = moves })
    local r = CG.generate(cat, no_chains, { from = GROUND, include_followups = true })
    local fups, vouched = 0, 0
    for _, e in ipairs(r.candidates) do
        if e.context_dependent then
            fups = fups + 1
            if e.context_known ~= nil then vouched = vouched + 1 end
        end
    end
    t.eq(fups, 56, "all 56 crossings stay candidates when the source names no parent")
    t.eq(vouched, 0, "and none of them claims a known context")
    t.is_nil(r.stats.by_exclusion[CG.EXCLUDED.FOLLOWUP_NOT_AFTER_PARENT],
             "nothing is excluded as not-the-parent on silence")

    -- And with no frame data at all, the same.
    local blind_fu = CG.generate(cat, nil, { from = GROUND, include_followups = true })
    local n = 0
    for _, e in ipairs(blind_fu.candidates) do
        if e.context_dependent then
            n = n + 1
            t.is_nil(e.context_known, e.id .. " vouches for nothing without frame data")
        end
    end
    t.eq(n, 56, "with no frame data every follow-up crossing is still a candidate")
    t.is_nil(blind_fu.stats.by_exclusion[CG.EXCLUDED.FOLLOWUP_NOT_AFTER_PARENT],
             "and none is excluded as not-the-parent")
end

do
    -- The same B row after two different As can be two different moves, so a
    -- per-row cache would produce a wrong answer rather than a missing one.
    -- Asserted through FrameData directly, because that is where they differ.
    local a1 = FrameData.lookup(idx, ">MP", { after = "MP" })
    local a2 = FrameData.lookup(idx, ">MP", { after = "HK" })
    t.ok(a1 ~= nil, "\">MP\" after MP is a real record")
    t.is_nil(a2, "the same row after HK is not, so one cache entry cannot serve both")
end

-- --- the two sources disagreeing travels onto the edge ------------------------

t.group("an edge built on a contradicted record says so")

-- Zangief's action 785 ("22+HK") is numbered among his throws and joins to
-- Tundra Storm, whose record calls itself a special. Whichever is right, the
-- numbers on that row are not known to be its own - and an edge that used them
-- has to carry that, or the uncertainty stops at the lookup and never reaches
-- anything a reader sees.

do
    local everything = {
        categories = { "normal", "command_normal", "special", "od_special", "super", "throw" },
        input_methods = { "manual" },
    }
    local r = CG.generate(cat, idx, { from = everything, to = everything })
    t.ok(r ~= nil, "generation runs over the wider set")

    local touching, flagged, sample = 0, 0, nil
    for _, e in ipairs(r.candidates) do
        if e.from.action_id == 785 or e.to.action_id == 785 then
            touching = touching + 1
            local why = (e.unknown_detail or {}).frame_data_variant_ambiguous
            if why and tostring(why):find("action id puts it among") then
                flagged = flagged + 1
                sample = sample or why
            end
        end
    end
    t.ok(touching > 0, ("the run produced edges touching 785 (%d)"):format(touching))
    t.eq(flagged, touching, "and every one of them carries the disagreement")
    t.ok(tostring(sample):find("throws") ~= nil and tostring(sample):find("special") ~= nil,
         "in words naming both sides: " .. tostring(sample))

    -- The edge is not excluded for it. An uncertain join is a reason to look
    -- harder, never a reason to decide the pair does not work.
    for _, e in ipairs(r.candidates) do
        if e.to.action_id == 785 then t.eq(e.status, "theoretical", e.id .. " survives") end
    end
end

-- --- Drive Rush Cancel ---------------------------------------------------------

local json = dofile("tools/lua/json.lua")

local function drc_split(r)
    local edges, by_id, excl = {}, {}, {}
    for _, e in ipairs(r.candidates) do
        if CG.is_drive_rush(e) then edges[#edges + 1] = e; by_id[e.id] = e end
    end
    for _, x in ipairs(r.excluded) do
        if CG.is_drive_rush(x) then excl[#excl + 1] = x end
    end
    return edges, by_id, excl
end

local function has(list, v)
    for _, x in ipairs(list or {}) do if x == v then return true end end
    return false
end

t.group("drive rush: off by default, and off changes nothing")

do
    local default = CG.generate(cat, idx, { from = GROUND, include_followups = true })
    local off = CG.generate(cat, idx, { from = GROUND, include_followups = true,
                                        include_drive_rush = false })
    local function fingerprint(r)
        local rows = {}
        for _, e in ipairs(r.candidates) do
            rows[#rows + 1] = { e.id, e.confidence, e.reasons, e.basis }
        end
        return json.encode({ rows, r.excluded, r.stats })
    end
    t.eq(fingerprint(off), fingerprint(default), "include_drive_rush = false is the default")
    local any_via, any_drc_stat = false, false
    for _, e in ipairs(default.candidates) do if e.via ~= nil then any_via = true end end
    for _, x in ipairs(default.excluded) do if x.via ~= nil then any_via = true end end
    for k in pairs(default.stats) do if tostring(k):find("^drc_") then any_drc_stat = true end end
    t.ok(not any_via, "no record carries `via` with the option off")
    t.ok(not any_drc_stat, "and no drc_ stat exists")
    t.ok(default.stats.by_reason.drive_rush_cancel == nil,
         "the reason that could never fire still does not, on a plain edge")

    -- With it on, the plain half is exactly the run with it off.
    local on = CG.generate(cat, idx, { from = GROUND, include_followups = true,
                                       include_drive_rush = true })
    local plain = { candidates = {}, excluded = {}, stats = {} }
    for _, e in ipairs(on.candidates) do
        if not CG.is_drive_rush(e) then plain.candidates[#plain.candidates + 1] = e end
    end
    for _, x in ipairs(on.excluded) do
        if not CG.is_drive_rush(x) then plain.excluded[#plain.excluded + 1] = x end
    end
    local rows_on, rows_off = {}, {}
    for _, e in ipairs(plain.candidates) do rows_on[#rows_on + 1] = { e.id, e.confidence, e.reasons, e.basis } end
    for _, e in ipairs(default.candidates) do rows_off[#rows_off + 1] = { e.id, e.confidence, e.reasons, e.basis } end
    t.eq(json.encode(rows_on), json.encode(rows_off),
         "with it on, the plain edges are the same edges in the same order")
    t.eq(json.encode(plain.excluded), json.encode(default.excluded),
         "and the plain exclusions are the same")
    for _, k in ipairs({ "pairs_considered", "candidates", "excluded", "followup_edges" }) do
        t.eq(on.stats[k], default.stats[k], "stats." .. k .. " still counts the plain edges")
    end
    t.eq(json.encode(on.stats.by_reason), json.encode(default.stats.by_reason),
         "by_reason is unchanged")
    t.eq(json.encode(on.stats.by_confidence), json.encode(default.stats.by_confidence),
         "by_confidence is unchanged")
end

t.group("drive rush: an edge built on drc_on_hit")

local drc_run = CG.generate(cat, idx, { from = GROUND, include_followups = true,
                                        include_drive_rush = true })
local drc_edges, drc_by_id, drc_excl = drc_split(drc_run)

do
    t.ok(#drc_edges > 0, "DRC edges are produced (" .. #drc_edges .. ")")

    -- 2MP (621) is +12 after a Drive Rush Cancel; 5LP (601) starts in 7.
    local e = drc_by_id["621:manual->drc->601:manual"]
    t.ok(e ~= nil, "2MP -> DRC -> 5LP is a candidate, under its own id")
    t.eq(e.via, "drive_rush_cancel", "via names the mechanism")
    t.eq_list(e.reasons, { "drive_rush_cancel" }, "with the one reason")
    t.eq(e.basis.from_drc_on_hit, 12, "from_drc_on_hit from the source")
    t.eq(e.basis.from_drc_on_block, 8, "and from_drc_on_block")
    t.eq(e.basis.to_startup, 7, "B's startup")
    t.eq(e.basis.drc_margin_frames, 5, "drc_margin = 12 - 7")
    t.is_nil(e.basis.margin_frames, "and no plain margin sits beside it to be misread")
    t.eq(e.basis.drive_cost, 30000, "the drive cost, read from the DRC record's gain")
    t.eq(e.basis.drc_record.startup, 9, "the DRC record's startup travels with the edge")
    t.eq(e.basis.drc_record.recovery, 15, "and its recovery")
    t.eq(e.confidence, "high", "a known margin of 5 is high")
    t.eq(e.context_dependent, false, "a DRC edge is not a follow-up edge")
    t.ok(Schema.validate(Schema.KIND.EDGE, e), "it validates as an edge")

    local u = {}
    for _, x in ipairs(e.requires_runtime_validation) do u[x] = true end
    t.ok(u.pushback_range and u.modern_specific_scaling and u.actual_input_timing,
         "it carries the three standing unknowns")
    t.ok(u[Schema.RUNTIME_UNKNOWNS.DRIVE_RUSH], "and the Drive Rush one")
    local why = e.unknown_detail[Schema.RUNTIME_UNKNOWNS.DRIVE_RUSH] or ""
    t.ok(why:find("500", 1, true) and why:find("+4", 1, true) and why:find("combo counter", 1, true)
         and why:find("66", 1, true),
         "whose detail names the input, the action id, the +4 and the counter")
    t.ok(u.cancel_window_conditions, "and the cancel window the source does not give")
    for _, x in ipairs(e.requires_runtime_validation) do
        t.ok(type(e.unknown_detail[x]) == "string" and #e.unknown_detail[x] > 0,
             ("unknown %s says why it applies"):format(x))
    end

    local bad = 0
    for _, d in ipairs(drc_edges) do
        if not Schema.validate(Schema.KIND.EDGE, d) then bad = bad + 1 end
        if not d.id:find("->drc->", 1, true) then bad = bad + 1 end
    end
    t.eq(bad, 0, "every DRC edge validates and is spelled A->drc->B")
    t.eq(drc_run.stats.drc_edges, #drc_edges, "stats.drc_edges counts them")
    local sum = 0
    for _, n in pairs(drc_run.stats.drc_by_confidence) do sum = sum + n end
    t.eq(sum, #drc_edges, "and drc_by_confidence adds up to them")

    -- A thin margin is medium, not high.
    local thin = drc_by_id["601:manual->drc->617:manual"]
    t.ok(thin ~= nil, "5LP -> DRC -> 2LP is a candidate")
    t.eq(thin.basis.drc_margin_frames, 0, "at a margin of 0 (6 - 6)")
    t.eq(thin.confidence, "medium", "which is medium")
end

t.group("drive rush: a known negative margin excludes, with the number")

do
    -- 5LP is +6 after a rush; 2MP starts in 8.
    t.is_nil(drc_by_id["601:manual->drc->621:manual"], "5LP -> DRC -> 2MP is not a candidate")
    local x
    for _, r in ipairs(drc_excl) do
        if r.from == 601 and r.to == 621 then x = r end
    end
    t.ok(x ~= nil, "it is in the excluded list")
    t.eq(x.reason, "drc_margin_negative", "under its own reason")
    t.eq(CG.EXCLUDED.DRC_MARGIN_NEGATIVE, "drc_margin_negative", "which has a stable name")
    t.eq(x.drc_margin_frames, -2, "carrying the number that decided it")
    t.eq(x.via, "drive_rush_cancel", "and marked as the rush's")
    t.ok(drc_run.stats.by_exclusion.drc_margin_negative > 0, "counted in by_exclusion")

    -- The cutoff moves it, as it moves the plain margin.
    local generous = CG.generate(cat, idx, { from = GROUND, include_followups = false,
                                             include_drive_rush = true, margin_cutoff = -2 })
    local _, g_by_id = drc_split(generous)
    t.ok(g_by_id["601:manual->drc->621:manual"] ~= nil, "a cutoff of -2 admits it")
end

t.group("drive rush: unknown numbers keep the pair, at low")

do
    -- 5HP (637) has no startup in the source.
    local e = drc_by_id["621:manual->drc->637:manual"]
    t.ok(e ~= nil, "2MP -> DRC -> 5HP survives an unknown startup")
    t.eq(e.confidence, "low", "at low confidence")
    t.ok(has(e.reasons, "frame_data_incomplete"), "naming the gap as a reason")
    t.is_nil(e.basis.drc_margin_frames, "with no margin invented")
    t.ok((e.unknown_detail.cancel_window_conditions or ""):find("to_startup", 1, true),
         "and the missing field named")
end

t.group("drive rush: a record without drc_on_hit is the source saying no")

do
    -- 5MP (604) has a record and no Drive Rush Cancel in it.
    local from_604, excl_604 = 0, 0
    for _, e in ipairs(drc_edges) do if e.from.action_id == 604 then from_604 = from_604 + 1 end end
    for _, x in ipairs(drc_excl) do if x.from == 604 then excl_604 = excl_604 + 1 end end
    t.eq(from_604, 0, "5MP starts no DRC edge")
    t.eq(excl_604, 0, "and is not excluded once per target either")
    t.ok(drc_run.stats.drc_not_cancelable >= 1, "it is counted once, as a move")
    local named = false
    for _, m in ipairs(drc_run.stats.drc_not_cancelable_moves) do
        if m:find("^604:manual") then named = true end
    end
    t.ok(named, "by name")
    t.eq(drc_run.stats.drc_starters_known + drc_run.stats.drc_starters_unknown
         + drc_run.stats.drc_not_cancelable, drc_run.stats.from_moves,
         "every starter is accounted for in exactly one of the three counts")
    -- 5MP is still a B.
    t.ok(drc_by_id["621:manual->drc->604:manual"] ~= nil, "5MP can still come out of a rush")
end

t.group("drive rush: no record for A is not a no")

do
    -- The same source without 5MP's record: now nothing is known about 5MP,
    -- and it has to be a DRC candidate again.
    local raw = dofile("data/frame-data/zangief.lua")
    local moves = {}
    for _, mv in ipairs(raw.moves) do
        if mv.numpad ~= "5MP" then moves[#moves + 1] = mv end
    end
    local no_5mp = FrameData.index({ _meta = raw._meta, moves = moves })
    t.is_nil(FrameData.lookup(no_5mp, "MP"), "5MP has no record in this index")
    local r = CG.generate(cat, no_5mp, { from = GROUND, include_followups = false,
                                         include_drive_rush = true })
    local edges = drc_split(r)
    local n, low, unknown_named = 0, 0, 0
    for _, e in ipairs(edges) do
        if e.from.action_id == 604 then
            n = n + 1
            if e.confidence == "low" then low = low + 1 end
            if (e.unknown_detail.cancel_window_conditions or ""):find("from_drc_on_hit", 1, true) then
                unknown_named = unknown_named + 1
            end
        end
    end
    t.ok(n > 0, "5MP starts DRC edges again (" .. n .. ")")
    t.eq(low, n, "every one of them low")
    t.eq(unknown_named, n, "each naming from_drc_on_hit as the gap")
    t.ok(r.stats.drc_starters_unknown >= 1, "and 5MP is counted as unknown, not as cannot")

    -- With no frame data at all, every starter is unknown and nothing is
    -- excluded on a number.
    local blind = CG.generate(cat, nil, { from = GROUND, include_followups = false,
                                          include_drive_rush = true })
    local b_edges, _, b_excl = drc_split(blind)
    t.eq(blind.stats.drc_not_cancelable, 0, "without frame data no starter is declared unable")
    t.eq(#b_excl, 0, "and no DRC pair is excluded")
    t.eq(#b_edges, blind.stats.from_moves * blind.stats.to_moves, "every crossing is a DRC edge")
    local not_low, cost = 0, 0
    for _, e in ipairs(b_edges) do
        if e.confidence ~= "low" then not_low = not_low + 1 end
        if e.basis.drive_cost ~= nil then cost = cost + 1 end
    end
    t.eq(not_low, 0, "all of them low")
    t.eq(cost, 0, "and no drive cost is invented without the DRC record")
    t.eq(blind.stats.drc_record_found, false, "the missing record is said")
end

t.group("drive rush: a move into itself through a rush")

do
    -- 2MP does not chain, so 2MP -> 2MP is excluded as a plain pair. Through a
    -- rush it is +12 into a startup of 8.
    t.is_nil(by_id["621:manual->621:manual"], "2MP -> 2MP is still not a plain candidate")
    local e = drc_by_id["621:manual->drc->621:manual"]
    t.ok(e ~= nil, "2MP -> DRC -> 2MP is a candidate")
    t.eq(e.basis.drc_margin_frames, 4, "at a margin of 4")
    t.eq(e.confidence, "high", "and nothing about being a self pair lowers it")
    local self_excl = 0
    for _, x in ipairs(drc_excl) do
        if x.reason == "self_pair_without_chain" then self_excl = self_excl + 1 end
    end
    t.eq(self_excl, 0, "no DRC exclusion uses the chain rule")
end

t.group("drive rush: no follow-up comes out of a rush")

do
    local reason = CG.EXCLUDED.FOLLOWUP_AFTER_DRIVE_RUSH
    t.eq(reason, "followup_after_drive_rush", "the reason has a stable name")
    local into_fu = 0
    for _, e in ipairs(drc_edges) do
        if e.to.action_id == 605 or e.to.action_id == 606
            or e.to.action_id == 679 or e.to.action_id == 680 then into_fu = into_fu + 1 end
    end
    t.eq(into_fu, 0, "no DRC edge ends on a follow-up")

    local listed, per_pair, bad = 0, {}, 0
    for _, x in ipairs(drc_excl) do
        if x.reason == reason then
            listed = listed + 1
            local k = x.from .. ">" .. x.to
            if per_pair[k] then bad = bad + 1 end
            per_pair[k] = true
            if x.to_exclusion ~= "followup" then bad = bad + 1 end
            if x.from == 604 then bad = bad + 1 end
        end
    end
    local capable = drc_run.stats.drc_starters_known + drc_run.stats.drc_starters_unknown
    t.eq(listed, capable * 4, ("each starter that could rush, times the 4 follow-ups (%d)"):format(listed))
    t.eq(drc_run.stats.by_exclusion[reason], listed, "counted in by_exclusion")
    t.eq(bad, 0, "once per pair, each carrying the catalog's mark, none from a starter that cannot rush")

    -- Every DRC exclusion carries the value that decided it.
    local undecided = 0
    for _, x in ipairs(drc_excl) do
        local justified
        if x.reason == "drc_margin_negative" then
            justified = type(x.drc_margin_frames) == "number" and x.drc_margin_frames < 0
        elseif x.reason == reason then
            justified = x.to_exclusion == "followup"
        end
        if not justified then undecided = undecided + 1 end
    end
    t.eq(undecided, 0, "no DRC pair is excluded without what decided it")
    t.eq(drc_run.stats.drc_excluded, #drc_excl, "stats.drc_excluded counts them")
    t.ok(CG.DRC_EXCLUSIONS[reason] and CG.DRC_EXCLUSIONS.drc_margin_negative,
         "and both reasons are named as the rush's")
end

t.group("drive rush: a guessed record's silence is not the move's")

do
    -- 785 ("22+HK") joins to a record the two sources disagree about. That
    -- record has no drc_on_hit - but it may not be this move's record, so its
    -- silence may not stand in for the move's.
    local r = CG.generate(cat, idx, {
        from = { categories = { "normal", "command_normal", "special", "throw" },
                 input_methods = { "manual" } },
        to = GROUND, include_followups = false, include_drive_rush = true })
    local edges = drc_split(r)
    local from785, low, flagged = 0, 0, 0
    for _, e in ipairs(edges) do
        if e.from.action_id == 785 then
            from785 = from785 + 1
            if e.confidence == "low" then low = low + 1 end
            if e.unknown_detail.frame_data_variant_ambiguous then flagged = flagged + 1 end
        end
    end
    local declared = false
    for _, m in ipairs(r.stats.drc_not_cancelable_moves) do
        if m:find("^785:") then declared = true end
    end
    t.ok(not declared, "785 is not declared unable to rush on a guessed record")
    if from785 > 0 then
        t.eq(low, from785, "its DRC edges are low")
        t.eq(flagged, from785, "and say the join was uncertain")
    else
        t.ok(true, "785 is not a starter in this scope")
    end
end

return t.finish()
