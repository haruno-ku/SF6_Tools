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

local RAW_FRAMES = dofile("tests/lua/fixtures/zangief_framedata.lua")
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
for _, u in ipairs(cov.unmatched_detail) do
    t.ok(u.classic ~= nil and #u.tried > 0,
         ("unmatched %s says what was tried"):format(tostring(u.classic)))
end

-- --- ambiguity is flagged, not hidden ---------------------------------------

t.group("distance variants")

-- The source spells some specials with a distance suffix: "63214K (Close)",
-- "(Mid)", "(Far)". Matching one of them is a guess, and it says so.
local _, ambig = lookup("63214+HK")
if ambig.matched then
    t.eq(ambig.match, "prefix", "a distance-variant key matches only by prefix")
    t.ok(ambig.ambiguous ~= nil, "and reports whether more than one variant existed")
else
    t.ok(true, "no prefix match for this notation, which is also an honest answer")
end

return t.finish()
