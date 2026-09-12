-- Unit tests for func/ComboExplorer/core/Canonical.lua
--
-- The defect these are written from was measured, not imagined. The first
-- sweep on build 24176760 wrote 15 rows and every one said "move A never came
-- out", because the worklist asked for 601 and this build's 弱 button produces
-- 611. The calibration had already measured that and written it down; nothing
-- read it.
--
-- So the assertions below are about the two halves of reading it: rewriting an
-- id to what the button produces, and folding the pairs that become each other
-- when you do - because 601, 602 and 611 all resolve to 611, and running all
-- three would record one button press as three separate findings.

local t = require("tests.lua.harness")
local C = require("func/ComboExplorer/core/Canonical")

-- The real map from build 24176760, trimmed to what these tests press.
local CANON = {
    ["manual|弱"]     = 611,
    ["manual|2 + 弱"] = 617,
    ["manual|DI"]     = 855,
}

local function pair(a_id, a_not, b_id, b_not)
    return { a_id = a_id, a_method = "manual", a_notation = a_not,
             b_id = b_id, b_method = "manual", b_notation = b_not,
             confidence = "high" }
end

local function worklist(pairs_)
    return { schema = "ce.worklist.v1", character = "Zangief",
             control_scheme = "modern", count = #pairs_, pairs = pairs_ }
end

-- --- the key -----------------------------------------------------------------

t.group("the group key is one spelling, shared with the calibration")

t.eq(C.group_key("manual", "弱"), "manual|弱", "method, a bar, notation")
t.is_nil(C.group_key(nil, "弱"), "no method, no key")
t.is_nil(C.group_key("manual", nil), "no notation, no key")
t.is_nil(C.group_key("manual", ""), "an empty notation is not a group")

t.eq(C.resolve(CANON, "manual", "弱"), 611, "a measured group resolves")
t.is_nil(C.resolve(CANON, "manual", "中"), "an unmeasured one does not")
t.is_nil(C.resolve(nil, "manual", "弱"), "and neither does anything without a map")

-- --- the rewrite -------------------------------------------------------------

t.group("an id is rewritten to the one the button produces")

do
    local wl, rep = C.apply(worklist({ pair(601, "弱", 678, "22 + 中") }), CANON)
    t.eq(wl.pairs[1].a_id, 611, "601 becomes the id this build's 弱 produces")
    t.eq(wl.pairs[1].b_id, 678, "an unmeasured group is left exactly as it was")
    t.eq(rep.remapped, 1, "and the rewrite is counted")
    t.eq(rep.untouched, 1, "as is the pair that named a group nobody measured")
    t.ok(wl.pairs[1].canonical_applied, "the pair says a measurement touched it")
    t.ok(wl.pairs[1].canonical_unmeasured,
         "and says part of it rested on no measurement - both are true here")
end

do
    -- The pair that was already right. It must not be counted as remapped:
    -- "61 of 209 already named the right id" is the number that says how bad
    -- the problem was, and inflating it hides that.
    local wl, rep = C.apply(worklist({ pair(611, "弱", 617, "2 + 弱") }), CANON)
    t.eq(rep.remapped, 0, "a pair that already named the produced id is not a rewrite")
    t.eq(rep.untouched, 0, "and nothing in it was unmeasured")
    t.is_nil(wl.pairs[1].canonical_applied, "so it carries no marker")
end

-- --- the fold ----------------------------------------------------------------

t.group("pairs that become each other are one trial, not three")

do
    -- The measured case. All three display 弱; the catalog lists them as
    -- separate moves; the button produces one of them.
    local wl, rep = C.apply(worklist({
        pair(601, "弱", 678, "22 + 中"),
        pair(602, "弱", 678, "22 + 中"),
        pair(611, "弱", 678, "22 + 中"),
    }), CANON)

    t.eq(#wl.pairs, 1, "three catalog rows are one button press")
    t.eq(wl.pairs[1].a_id, 611, "and it is the id that comes out")
    t.eq(rep.folded, 2, "two were folded away")
    t.eq(rep.kept, 1, "one is left to run")
    t.eq(wl.count, 1, "and the worklist's own count agrees with its pairs")
end

do
    -- The fold must not reach across methods. Same notation, different input
    -- method, is a different press and a different question.
    local ps = { pair(601, "弱", 678, "x"), pair(601, "弱", 678, "x") }
    ps[2].a_method = "simple"
    local wl = C.apply(worklist(ps), CANON)
    t.eq(#wl.pairs, 2, "manual and simple are not folded into each other")
end

do
    -- Order is the worklist's whole value: explore.lua sorts by confidence so
    -- a sweep cut short has spent its time where the frame data had something
    -- to say. The fold keeps the FIRST of a group, not the last.
    local wl = C.apply(worklist({
        pair(611, "弱", 700, "a"),
        pair(601, "弱", 701, "b"),
        pair(602, "弱", 700, "a"),
    }), CANON)
    t.eq(#wl.pairs, 2, "one of the three folded")
    t.eq(wl.pairs[1].b_id, 700, "and the survivor is the one that came first")
    t.eq(wl.pairs[2].b_id, 701, "with the rest of the order untouched")
end

-- --- what it refuses to do ---------------------------------------------------

t.group("a group nobody pressed is left alone, and said so")

do
    -- The tempting wrong fix: assume the lowest id in a group is the real one.
    -- It would be invisible afterwards - the rows would look like every other
    -- row - which is why the untouched count exists.
    local wl, rep = C.apply(worklist({
        pair(605, "中", 606, "中"),
        pair(606, "中", 605, "中"),
    }), CANON)
    t.eq(#wl.pairs, 2, "two unmeasured pairs stay two pairs")
    t.eq(wl.pairs[1].a_id, 605, "with their ids exactly as the catalog had them")
    t.eq(rep.remapped, 0, "nothing was rewritten")
    t.eq(rep.untouched, 2, "and the report says both rested on no measurement")
    t.ok(wl.pairs[1].canonical_unmeasured, "each row carries that too")
end

do
    -- No map at all. Every pair is untouched, and "no map existed" has to stay
    -- distinguishable from "a map existed and matched nothing" - one of those
    -- means the calibration has not been run.
    local wl, rep = C.apply(worklist({ pair(601, "弱", 678, "x") }), nil)
    t.eq(#wl.pairs, 1, "the list survives")
    t.eq(wl.pairs[1].a_id, 601, "unchanged")
    t.eq(rep.untouched, 0,
         "and nothing is reported as unmeasured, because nothing was looked up")
    t.is_nil(wl.canonical, "the worklist is not stamped as canonicalised")
end

do
    local wl = C.apply(worklist({ pair(601, "弱", 678, "x") }), CANON)
    t.ok(wl.canonical ~= nil, "a list a map was applied to IS stamped")
    t.eq(wl.canonical.remapped, 1, "carrying what happened to it")
end

-- --- it does not eat its input -----------------------------------------------

t.group("the document that was checksum-matched is not modified")

do
    -- Sweep.start compares the worklist's ac/bcm against the catalog before
    -- this runs. A run restarted from the same decoded document has to see the
    -- same thing the second time.
    local original = worklist({ pair(601, "弱", 678, "x"), pair(602, "弱", 678, "x") })
    local wl = C.apply(original, CANON)
    t.eq(#original.pairs, 2, "the original still has both pairs")
    t.eq(original.pairs[1].a_id, 601, "with their original ids")
    t.eq(original.count, 2, "and its original count")
    t.ok(wl ~= original, "the result is a different table")
    t.ok(wl.pairs ~= original.pairs, "and so is its pair list")
    t.eq(wl.character, "Zangief", "while everything else is carried across")
    t.eq(wl.schema, "ce.worklist.v1", "including the schema the loader checked")
end

-- --- refusals ----------------------------------------------------------------

t.group("it refuses what is not a worklist")

do
    local wl, why = C.apply(nil, CANON)
    t.is_nil(wl, "nil is not a worklist")
    t.eq(why, "not a worklist", "and it says so")
    local wl2 = C.apply({ schema = "ce.worklist.v1" }, CANON)
    t.is_nil(wl2, "neither is one with no pairs table")
end

-- --- the summary -------------------------------------------------------------

t.group("the one line an operator reads")

do
    local _, rep = C.apply(worklist({
        pair(601, "弱", 678, "x"),
        pair(602, "弱", 678, "x"),
        pair(605, "中", 606, "中"),
    }), CANON)
    local s = C.summary(rep)
    t.ok(s:find("remapped") ~= nil, "names the rewrites: " .. s)
    t.ok(s:find("folded") ~= nil, "and the fold")
    t.ok(s:find("nobody measured") ~= nil, "and what rested on no measurement")
    -- The number that must be in it: a list that went 3 -> 2 without a reason
    -- beside it reads as a truncated worklist.
    t.ok(s:find("2 pair") ~= nil, "and how many are left: " .. s)
end

return t.finish()
