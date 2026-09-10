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

return t.finish()
