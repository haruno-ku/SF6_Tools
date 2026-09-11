-- Unit tests for func/ComboExplorer/core/FrameData.lua
--
-- Run against the real Zangief frame data, because the thing that goes wrong
-- here is a join that looks fine: command_display names a move "2+MP" and the
-- frame source names it "2MP", and a lookup that quietly matches the wrong
-- entry attaches the wrong numbers to a move. Wrong numbers are worse than
-- none - none produces an honest unknown, wrong ones produce a confident
-- candidate that cannot work.

local t = require("tests.lua.harness")
local FD = require("func/ComboExplorer/core/FrameData")
local Catalog = require("func/ComboExplorer/core/Catalog")

local RAW_FRAMES = dofile("data/frame-data/zangief.lua")
local RAW_CATALOG = dofile("tests/lua/fixtures/zangief_catalog.lua")

local idx = FD.index(RAW_FRAMES)
local cat = Catalog.build(RAW_CATALOG)

-- --- the index ---------------------------------------------------------------

t.group("index")

t.ok(idx ~= nil, "the real frame data indexes")
t.eq(idx.meta.character_id, "zangief", "character carried through")
t.eq(idx.meta.license, "CC-BY-SA", "and the licence, which has to travel with the numbers")
t.ok(#idx.keys >= 60, "most of the move list is present (" .. #idx.keys .. " keys)")

t.is_nil(FD.index(nil), "nil is refused")
t.is_nil(FD.index({}), "a table with no moves is refused")

-- Duplicate keys are real in this source - "720+P" appears twice with
-- different damage - and are recorded rather than silently overwritten.
t.ok(idx.duplicates ~= nil, "duplicates are tracked")

-- --- the join ----------------------------------------------------------------

t.group("classic display to numpad")

local function lookup(classic)
    local rec, info = FD.lookup(idx, classic)
    return rec, info
end

-- Exact: motions keep their "+" in both sources.
local rec, info = lookup("360+HP")
t.ok(rec ~= nil, "360+HP matches")
t.eq(info.match, "exact", "exactly")
t.eq(FD.startup(rec), 5, "and carries the right startup")

-- The "+" is dropped for normals.
rec, info = lookup("2+MP")
t.ok(rec ~= nil, "2+MP matches")
t.eq(info.match, "no_plus", "by dropping the plus")
t.eq(FD.startup(rec), 8, "startup 8")
t.eq(FD.on_hit(rec), 3, "on hit +3")
t.eq(FD.damage(rec), 700, "damage 700")

-- A bare button is the neutral version, spelled with a leading 5 there.
rec, info = lookup("LP")
t.ok(rec ~= nil, "a bare LP matches")
t.eq(info.match, "neutral_5", "by prefixing the neutral direction")
t.eq(FD.startup(rec), 7, "5LP starts in 7")
t.eq(FD.on_hit(rec), 4, "and is +4 on hit")

rec = lookup("j.HP")
t.ok(rec ~= nil, "an air normal matches as-is")
t.eq(FD.startup(rec), 9, "with its own startup")

rec = lookup("22+MK")
t.ok(rec ~= nil, "a two-digit motion matches")
t.eq(FD.startup(rec), 9, "startup 9")

-- Every key tried is reported, so an unmatched move is a documented unknown.
local _, miss = lookup("NOT_A_MOVE")
t.eq(miss.matched, false, "an unknown notation does not match")
t.ok(#miss.tried > 0, "and the report says what was tried")
t.eq(miss.match, "none", "with an explicit none")

-- --- unknown values stay unknown ---------------------------------------------

t.group("the source does not fake what it lacks")

-- 5HP has a null startup in the wiki data. That must arrive as nil, not zero:
-- a zero would make it the fastest move in the game.
rec = lookup("HP")
t.ok(rec ~= nil, "5HP is present")
t.is_nil(FD.startup(rec), "but its startup is unknown, and stays nil")
t.eq(FD.on_hit(rec), 3, "while the values it does have come through")

local missing = FD.missing(rec)
local has = {}
for _, m in ipairs(missing) do has[m] = true end
t.ok(has.startup, "and the gap is named")
t.ok(has.pushback, "pushback is null throughout this source, and is named too")

t.eq_list(FD.missing(nil), { "no_frame_record" }, "no record at all says so plainly")

-- --- cancel properties -------------------------------------------------------

t.group("cancel properties")

rec = lookup("2+MP")
t.eq(FD.can_cancel_into(rec, "special"), true, "2MP cancels into specials")
t.eq(FD.can_cancel_into(rec, "super"), true, "and supers")
t.eq(FD.can_cancel_into(rec, "chain"), false, "but not chains")

rec = lookup("2+HP")
t.eq(FD.can_cancel_into(rec, "special"), false, "2HP cancels into nothing")

-- Unknown is not false. A move with no cancel list at all has not told us it
-- cannot cancel; it has told us nothing.
t.is_nil(FD.can_cancel_into({ numpad = "x" }, "special"),
         "a record with no cancel list returns nil, not false")
t.is_nil(FD.can_cancel_into(nil, "special"), "and no record at all returns nil")

t.eq(FD.has_property(lookup("2+LP"), "low"), true, "properties read through")
t.is_nil(FD.has_property(nil, "low"), "and are unknown when the record is missing")

-- --- coverage over the real catalog -----------------------------------------

t.group("coverage across the catalog")

local ground = Catalog.probeable(cat, {
    categories = { "normal", "command_normal" },
    input_methods = { "manual" },
})
local cov = FD.coverage(idx, ground)

t.eq(cov.rows, #ground, "every ground normal was looked up")
t.ok(cov.matched >= #ground - 1,
     ("nearly all of them found frame data (%d of %d)"):format(cov.matched, cov.rows))
t.ok(cov.ratio > 0.9, "coverage is high enough to build candidates from")

-- A join that quietly matched a third of the moves would look like a thin edge
-- graph rather than a broken lookup, so the misses are listed by name.
--
-- Checked against a deliberate miss rather than against the real ground
-- normals, where coverage is 14 of 14 and the loop below runs zero times - a
-- test that would still pass if the miss-reporting path were deleted outright.
local miss_cov = FD.coverage(idx, {
    { action_id = 999999, classic = "NOT_A_MOVE" },
    { action_id = 621, classic = "2+MP" },
})
t.eq(miss_cov.unmatched, 1, "a move with no frame data is counted as a miss")
t.eq(miss_cov.matched, 1, "and its neighbour still matches")
t.eq(#miss_cov.unmatched_detail, 1, "the miss is listed")
t.eq(miss_cov.unmatched_detail[1].action_id, 999999, "by action id")
t.eq(miss_cov.unmatched_detail[1].classic, "NOT_A_MOVE", "and notation")
t.ok(#miss_cov.unmatched_detail[1].tried > 0,
     "with the keys that were tried, so the failure can be diagnosed")

for _, u in ipairs(cov.unmatched_detail) do
    t.ok(u.classic ~= nil and #u.tried > 0,
         ("unmatched %s says what was tried"):format(tostring(u.classic)))
end

-- --- the two spellings the source actually uses ------------------------------

t.group("a generic button letter is the source declining to split by strength")

-- The source writes a special with a generic letter - "214P" - when the
-- strengths do not differ, and splits it into 214LP / 214MP / 214HP when they
-- do. Ryu's Hadoken is three records with startups 16, 14 and 12; JP's
-- Departure is one record. The catalog always has a row per strength, so
-- without this JP joined 55% of his targets.
t.eq(FD.generic_button_key("214+LP"), "214P", "a strength becomes the generic letter")
t.eq(FD.generic_button_key("214+MP"), "214P", "whichever strength it was")
t.eq(FD.generic_button_key("236+HK"), "236K", "kicks too")
t.eq(FD.generic_button_key("214+LP+MP"), "214PP", "two punches are the OD spelling")
t.eq(FD.generic_button_key("236+LK+MK"), "236KK", "and two kicks")
t.eq(FD.generic_button_key("[4]6+LP"), "[4]6P", "a charge keeps its bracket")

-- Refusals, each for a reason.
t.is_nil(FD.generic_button_key("214+LP+HK"),
         "a mixed punch and kick has no generic spelling, so none is invented")
t.is_nil(FD.generic_button_key("LP"), "a bare button is not a motion")
t.is_nil(FD.generic_button_key("2+MP"),
         "and neither is one direction - the source spells every normal with its "
         .. "strength, so generalising 2+MP could only attach a special's numbers "
         .. "to a crouching medium punch")
t.is_nil(FD.generic_button_key("6+HK"), "the same for a command normal")

-- Order is the whole safety argument: the strength-specific key must win when
-- the source drew the distinction.
local ryu = FD.index(dofile("data/frame-data/ryu.lua"))
local rec, info = FD.lookup(ryu, "236+LP")
t.ok(rec ~= nil, "Ryu's light fireball joins")
t.eq(info.key, "236LP", "to the strength-specific record, not the generic one")
t.eq(FD.startup(rec), 16, "with the light startup")
local hrec = FD.lookup(ryu, "236+HP")
t.ok(FD.startup(hrec) ~= FD.startup(rec),
     "and the heavy one differs, which is why the source split them")

-- JP is the case that motivated it.
local jp = FD.index(dofile("data/frame-data/jp.lua"))
local jrec, jinfo = FD.lookup(jp, "214+LP")
t.ok(jrec ~= nil, "JP's 214+LP joins")
t.eq(jinfo.match, "generic_button", "by the generic fallback")
t.eq(jinfo.key, "214P", "because that is the only spelling the source has")
t.eq(FD.lookup(jp, "214+MP"), jrec,
     "and the other strengths reach the same record - the source says it is one move")

t.group("one record can answer to several inputs")

-- The source writes alternatives with " or ": Dhalsim's record is "2KK or 3KK",
-- one move reachable two ways, and the catalog has a row for each.
t.eq_list(FD.spellings("2KK or 3KK"), { "2KK", "3KK" }, "an \"or\" record is split")
t.eq_list(FD.spellings("4MK or 6MK"), { "4MK", "6MK" }, "on both sides")
t.eq_list(FD.spellings("214P"), { "214P" }, "an ordinary key is left alone")
t.eq_list(FD.spellings("63214KK (Close)"), { "63214KK (Close)" },
          "and a distance variant is not split on its own words")
t.eq_list(FD.spellings(nil), {}, "nothing spells nothing")

local dhal = FD.index(dofile("data/frame-data/dhalsim.lua"))
local d2 = FD.lookup(dhal, "2+KK")
local d3 = FD.lookup(dhal, "3+KK")
t.ok(d2 ~= nil, "Dhalsim's 2+KK joins")
t.ok(d3 ~= nil, "and so does 3+KK")
t.eq(d2, d3, "to the same record, because the source lists both inputs for it")

-- --- the instrument has to measure the whole run -----------------------------

t.group("coverage over the rows a run actually uses")

-- The committed report said "frame data coverage 14 of 14 (100%)" for a run
-- that aimed at thirty-three targets. Both halves were true and the sentence
-- was not: coverage was being taken over the starting moves alone, so a join
-- that collapsed to nothing on specials would have reported a clean sheet.
--
-- The property being pinned is that the two sets give different answers. A
-- future change that quietly narrows the measurement back to the starters makes
-- them equal again.
local starters = Catalog.probeable(cat, {
    categories = { "normal", "command_normal" }, input_methods = { "manual" },
})
local targets = Catalog.probeable(cat, {
    categories = { "normal", "command_normal", "special", "od_special", "super" },
    input_methods = { "manual", "simple" },
})
local derivations = {}
for _, row in ipairs(cat.rows) do
    if row.exclusion == "followup" then derivations[#derivations + 1] = row end
end

t.ok(#targets > #starters, "the target set is larger than the starting set")
t.ok(#derivations > 0, "and the run collects derivations on top of both")

local cov_start = FD.coverage(idx, starters)
local cov_all = FD.coverage(idx, targets)
t.eq(cov_start.ratio, 1.0, "every starter joins - which is the number that was being reported")

-- The property is that the two are DIFFERENT MEASUREMENTS, not that one of them
-- is failing. This first asserted that the targets did not all join, which was
-- true for Zangief at the time and stopped being true when the generic-button
-- fallback landed and took him from 91% to 100%. A test that pins today's gap
-- fails when the gap is fixed, which teaches nobody anything; a test that pins
-- the size of the set being measured keeps working either way.
t.ok(cov_all.rows > cov_start.rows,
     ("the target set is measured over more rows than the starters: %d against %d")
     :format(cov_all.rows, cov_start.rows))
t.ok(cov_all.rows >= #targets, "every target row was looked up, not sampled")

-- Asked on its own, a derivation joins to nothing - on any character. The
-- source spells one as a chain from the move before it ("5MP~MP") and never on
-- its own, and ">MP" does not say what it follows.
--
-- This used to assert `matched == 0` and stop there, as a known gap. It is the
-- shape the block above warns about: a test that pins today's gap fails the day
-- the gap is fixed and teaches nobody why. What is pinned now is the PROPERTY -
-- a derivation needs its parent, a parent is enough, and a wrong parent is not.
local cov_deriv = FD.coverage(idx, derivations)
t.eq(cov_deriv.matched, 0, "asked on its own, no derivation joins to frame data")
t.eq(cov_deriv.rows, #derivations, "and all of them were looked up, not skipped")
for _, u in ipairs(cov_deriv.unmatched_detail) do
    t.ok(#u.tried > 0, ("derivation %s records what was tried"):format(tostring(u.classic)))
end

t.group("a derivation read against the move it comes out of")

-- Zangief's source carries "5MP~MP" (Double Lariat 1 off 5MP) and "22MK~MK".
-- The catalog carries ">MP" and ">MK". Neither spelling can reach the other.
do
    local alone, info_alone = FD.lookup(idx, ">MP")
    t.is_nil(alone, "\">MP\" alone finds nothing")

    local rec, info = FD.lookup(idx, ">MP", { after = "MP" })
    t.ok(rec ~= nil, "the same row read after MP finds a record")
    t.eq(info.key, "5MP~MP", "and it is the chain the source actually spells")
    t.eq(info.match, "derivation", "reported under its own match kind, not as a fuzzy hit")

    -- The parent goes through the same candidate ladder as any other lookup,
    -- which is why a bare "MP" reaches the source's "5MP".
    t.ok(info.tried ~= nil and #info.tried > #info_alone.tried,
         "the contextual keys are additions to what was tried, not replacements")
end

do
    -- A parent the source does not chain this move from is not a match. The
    -- danger being tested for is a fallback loose enough to accept any parent,
    -- which would hand out numbers for chains that do not exist.
    local rec = FD.lookup(idx, ">MP", { after = "HK" })
    t.is_nil(rec, "a parent the source never chains this move from stays unmatched")
end

do
    -- Ordering. A row whose own spelling is in the source must keep its own
    -- record even when a parent is supplied, or every edge would rewrite the
    -- numbers of moves that were never derivations.
    local own = FD.lookup(idx, "2+MP")
    local with_parent, info = FD.lookup(idx, "2+MP", { after = "MP" })
    t.ok(own ~= nil, "an ordinary move joins on its own")
    t.eq(with_parent, own, "and joins to the SAME record when a parent is offered")
    t.ok(info.match ~= "derivation", "by its own key, not a chained one: " .. tostring(info.match))
end

do
    -- Omitting opts has to be byte-identical to the old behaviour, because
    -- every existing caller does exactly that.
    local a = FD.candidate_keys("2+MP")
    local b = FD.candidate_keys("2+MP", nil)
    local c = FD.candidate_keys("2+MP", {})
    t.eq(#a, #b, "candidate_keys(x) and candidate_keys(x, nil) agree in length")
    t.eq(#a, #c, "and so does an empty opts table")
    for i = 1, #a do
        t.eq(b[i].key, a[i].key, "same key at " .. i)
        t.eq(c[i].key, a[i].key, "empty opts too, at " .. i)
    end
end

do
    -- Coverage takes the parent set rather than one parent, because "does this
    -- row ever join" is the question a report is asking.
    local parents = {}
    for _, r in ipairs(targets) do parents[#parents + 1] = r end
    local with = FD.coverage(idx, derivations, { parents = parents })
    t.ok(with.matched > cov_deriv.matched,
         ("derivations join once the set they could follow is offered: %d against %d")
         :format(with.matched, cov_deriv.matched))
    t.ok((with.after_parent or 0) > 0, "and the count of those says so separately")

    -- Unconditionally, and that matters: written as `if d.after then ... end`
    -- this passed with the field deleted, because an empty loop body asserts
    -- nothing. Find a match made through a parent and require the field on it.
    local named = 0
    for _, d in ipairs(derivations) do
        local rec, info = nil, nil
        for _, parent in ipairs(parents) do
            rec, info = FD.lookup(idx, d.classic, { after = parent.classic })
            if rec then break end
        end
        if rec then
            t.eq(info.after ~= nil, true,
                 ("%s joined through a parent, so it has to say which"):format(tostring(d.classic)))
            named = named + 1
        end
    end
    t.ok(named > 0, "at least one derivation joined through a parent (" .. named .. ")")

    local without = FD.coverage(idx, derivations)
    t.eq(without.matched, 0, "and with no parents offered the answer is unchanged")
end

-- A guessed match is counted separately from a clean one, and the count is what
-- a report needs in order not to present a coin flip as a fact.
t.ok(cov_all.ambiguous ~= nil, "uncertain matches are counted")
if cov_all.ambiguous > 0 then
    t.ok(cov_all.uncertain_detail ~= nil and #cov_all.uncertain_detail > 0,
         "and each one says which key it settled on")
end

-- --- ambiguity is flagged, not hidden ---------------------------------------

t.group("distance variants")

-- The source spells some specials with a distance suffix: "63214KK (Close)",
-- "(Mid)", "(Far)". Matching one of them is a guess, and it has to say so.
--
-- Written against 63214+KK deliberately. The obvious probe, 63214+HK, does not
-- prefix-match at all - the source spells that one "63214HK or 63214K (Close)"
-- - so a test built on it takes the "no match" branch and asserts nothing,
-- which is what the previous version of this test did while the real ambiguity
-- went uncovered and fed the pipeline.
local rec2, ambig = lookup("63214+KK")
t.ok(ambig.matched, "63214+KK matches")
t.eq(ambig.match, "prefix", "only by prefix, because the exact key does not exist")
t.eq(ambig.ambiguous, true, "and it is ambiguous - several variants share the stem")
t.ok(#ambig.alternatives >= 3, "all of them reported (" .. #ambig.alternatives .. ")")

-- This is the part that matters: the variants disagree enough to flip a
-- candidate. (Close) starts in 10, (Far) in 54.
local startups = {}
for _, k in ipairs(ambig.alternatives) do
    startups[#startups + 1] = FD.startup(idx.by_key[k])
end
local lo, hi = math.huge, -math.huge
for _, v in ipairs(startups) do
    if v then lo = math.min(lo, v) hi = math.max(hi, v) end
end
t.ok(hi - lo > 20, ("the variants disagree by %d frames, which decides whether a pair "
     .. "links at all"):format(hi - lo))
t.eq(FD.startup(rec2), lo, "and the join returns one of them by sort order, not by knowing")

-- So the join has to be askable about it, or a consumer has no way to find out.
t.eq(FD.uncertain(ambig), true, "the join reports that it had to guess")
t.ok(FD.uncertainty_reason(ambig):find("sort order") ~= nil,
     "saying it picked by sort order rather than by knowing which applies")

local _, exact = lookup("2+MP")
t.eq(FD.uncertain(exact), false, "while an exact single match is not a guess")
t.is_nil(FD.uncertainty_reason(exact), "and has no reason to give")

-- A key the source lists twice is the same problem wearing different clothes:
-- 720+P appears with damage 4800 and 5300, and whichever came first wins.
local dup_key
for k, n in pairs(idx.duplicates) do if n and n > 1 then dup_key = k break end end
t.ok(dup_key ~= nil, "the source lists at least one key more than once (" ..
     tostring(dup_key) .. ")")
local _, dup = FD.lookup(idx, dup_key)
t.eq(dup.duplicate, true, "and the lookup says so")
t.eq(FD.uncertain(dup), true, "which counts as having guessed")
t.ok(FD.uncertainty_reason(dup):find("whichever came first") ~= nil, "and says why")

-- --- the two sides generalise in opposite directions --------------------------

-- These read other characters' frame data on purpose. The rules below exist
-- because the convention differs per character and per move - Ken splits
-- Dragonlash Kick into three strengths while the catalog writes "623+K", and
-- C.Viper writes "214214P" for a move the catalog spells with two buttons -
-- so a fixture built from one character cannot show either shape.
local KEN     = FD.index(dofile("data/frame-data/ken.lua"))
local GUILE   = FD.index(dofile("data/frame-data/guile.lua"))
local CVIPER  = FD.index(dofile("data/frame-data/cviper.lua"))

t.group("the catalog is generic and the source is specific")

do
    -- The rule already had specific -> generic ("214+LP" -> "214P"). This is
    -- the other direction, and it was missing entirely: "623+K" has no
    -- strength+button pair in it, so generic_button_key returned nil and not
    -- one of 623LK / 623MK / 623HK was ever tried.
    local rec, info = FD.lookup(KEN, "623+K")
    t.ok(rec ~= nil, "\"623+K\" finds Ken's Dragonlash Kick")
    t.eq(info.match, "generic_expanded", "under its own match kind")
    t.eq(info.ambiguous, true, "and it is ambiguous, because the source split the move")
    t.eq_list(info.alternatives, { "623LK", "623MK", "623HK" },
              "naming every strength that exists rather than picking one quietly")

    -- FD.uncertain is what the reports and the candidate generator read.
    t.eq(FD.uncertain(info), true, "so the join counts as uncertain downstream")
end

do
    -- THE GATE, and the reason it is not a formality. Guile's "6MP" is Full
    -- Bullet Magnum, a command normal. If a single-digit motion could expand,
    -- every rekka hit the catalog spells "6+P" would collect some normal's
    -- numbers - a confident wrong answer, which is worse than no answer.
    t.is_nil(FD.generic_expansion("6+P"), "a single-digit motion does not expand")
    t.is_nil(FD.generic_expansion("6+K"), "in either button family")
    t.is_nil(FD.generic_expansion("2+MP"), "and a notation that names a strength has nothing to expand")

    local motion, button = FD.generic_expansion("623+K")
    t.eq(motion, "623", "a real motion does expand")
    t.eq(button, "K", "carrying the button family")

    local m2 = FD.generic_expansion("[4]6+P")
    t.eq(m2, "[4]6", "a charge counts as a motion even with one digit")

    -- End to end: Guile's 6+MP keeps its own key and picks up no strength guess.
    local _, ginfo = FD.lookup(GUILE, "6+MP")
    t.ok(ginfo.match ~= "generic_expanded",
         "Guile's 6+MP is read as itself, not expanded: " .. tostring(ginfo.match))
end

t.group("the source generalises one level further than the catalog")

do
    -- "[4]646+LP+MP" generalises to "[4]646PP" by the existing rule, and the
    -- source spells it "[4]646P" - one letter for the pair.
    local rec, info = FD.lookup(GUILE, "[4]646+LP+MP")
    t.ok(rec ~= nil, "Guile's Sonic Hurricane joins")
    t.eq(info.key, "[4]646P", "through the collapsed single-letter form")

    local rec2, info2 = FD.lookup(CVIPER, "214214+LP+MP")
    t.ok(rec2 ~= nil, "and so does C.Viper's Mission Complete")
    t.eq(info2.key, "214214P", "the same way")

    -- Ordering: the repeated form is still tried first, so a source that DID
    -- draw the distinction keeps it.
    local keys = FD.candidate_keys("[4]646+LP+MP")
    local at_pp, at_p
    for i, k in ipairs(keys) do
        if k.key == "[4]646PP" then at_pp = i end
        if k.key == "[4]646P" then at_p = i end
    end
    t.ok(at_pp ~= nil and at_p ~= nil, "both forms are candidates")
    t.ok(at_pp < at_p, "and the two-letter form is tried first")
end

t.group("alternations the source writes with a slash")

do
    -- Indexed as literal strings before this, so the move was in by_key under a
    -- name no catalog row could ever generate.
    t.eq_list(FD.spellings("4/6MP"), { "4MP", "6MP" }, "a direction alternation")
    t.eq_list(FD.spellings("5/6KK~6P"), { "5KK~6P", "6KK~6P" }, "with a chain attached")
    t.eq_list(FD.spellings("214236HP/HK"), { "214236HP", "214236HK" }, "a button alternation")
    t.eq_list(FD.spellings("214P~214LP/MP"), { "214P~214LP", "214P~214MP" },
              "a button alternation inside a chain")

    -- The prose form. Split on " or " alone the first part is the bare string
    -- "4", which is not an input and which no row can ask for.
    t.eq_list(FD.spellings("4 or 6 + PPP/KKK"), { "4PPP", "4KKK", "6PPP", "6KKK" },
              "the teleport's two directions times its two button groups")
    t.eq_list(FD.spellings("6 or 4 + PPP/KKK"), { "6PPP", "6KKK", "4PPP", "4KKK" },
              "written the other way round too")
    t.eq_list(FD.spellings("4 or 6 + j.PPP/j.KKK"), { "4j.PPP", "4j.KKK", "6j.PPP", "6j.KKK" },
              "and the air version keeps its prefix on both sides")

    -- What must NOT change.
    t.eq_list(FD.spellings("2KK or 3KK"), { "2KK", "3KK" }, "a plain \" or \" is untouched")
    t.eq_list(FD.spellings("360+HP"), { "360+HP" },
              "and a key keeps its own \"+\" - only the prose form had spaces around one")
    t.eq_list(FD.spellings("63214HK or 63214K (Close)"),
              { "63214HK", "63214K (Close)" }, "a distance suffix survives the split")
end

return t.finish()
