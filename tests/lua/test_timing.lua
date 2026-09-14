-- Unit tests for func/ComboExplorer/core/Timing.lua
--
-- The model in this module is not a guess dressed up. It was written after a
-- run that measured both edges of one link window, and the numbers below are
-- that run: Zangief 6HP into 3MP on build 24176760, from
-- reframework/data/ComboExplorer_data/trials/zangief-assist-ab.jsonl.
--
--   6HP  startup 14  active 5  recovery 15  hitstop 13  hitstun 28  on_hit +8
--   3MP  startup 7
--
--   measured: 4..36 the second input never appeared, 40 and 44 linked,
--             48 whiffed, 52..72 the combo counter had already reset.
--
-- So the assertions that matter are the two edges. Anything that still passes
-- when the model is wrong about those is not testing the model.

local t = require("tests.lua.harness")
local Timing = require("func/ComboExplorer/core/Timing")

local A = { startup = 14, active = "5", recovery = 15, hitstop = 13, hitstun = 28, on_hit = 8 }
local B = { startup = 7 }

-- --- the measured case --------------------------------------------------------

t.group("the window the hardware produced")

do
    local w, missing = Timing.window(A, B, { hold_ticks = 3, buffer_ticks = 4 })
    t.ok(w ~= nil, "a window comes back: " .. tostring(missing and missing[1]))

    -- 14+5+15+13 = 47, minus the 3 ticks the input is held.
    t.eq(w.latest, 44, "the last gap at which A is still recovering is 44 - measured, 44 linked")
    t.eq(w.earliest, 40, "and the buffer opens it at 40 - measured, 40 linked")
    -- 14+13+28 - 7 - 3
    t.eq(w.whiff_after, 45, "past 45 the defender has left hitstun - measured, 48 whiffed")
    t.eq(w.basis.free_at, 47, "the basis carries the working, not just the answer")
end

do
    -- The assertion that would fail if hitstop were left out, which is the one
    -- thing about this model that is specific to THIS build:
    -- Provenance.hitstop_advances_tick came back refuted, so a hitstop tick is
    -- wall-clock the gap has to cover.
    local no_hitstop = { startup = 14, active = "5", recovery = 15, hitstop = 0,
                         hitstun = 28 }
    local w = Timing.window(no_hitstop, B, { hold_ticks = 3, buffer_ticks = 4 })
    t.eq(w.latest, 31, "without hitstop the model says 31, and 31 did NOT link")
end

-- --- multi-hit active ---------------------------------------------------------

t.group("active frames that are a string")

t.eq(Timing.active_frames(5), 5, "a number is itself")
t.eq(Timing.active_frames("3"), 3, "and so is a one-number string")
-- "2(3)2(4)2" is hit, gap, hit, gap, hit. The move is not over until the last
-- active frame, and the gaps are wall-clock too.
t.eq(Timing.active_frames("2(3)2(4)2"), 13, "a multi-hit string is the whole span")
t.is_nil(Timing.active_frames(nil), "nothing is not zero")
t.is_nil(Timing.active_frames("n/a"), "and neither is unparseable text")

-- --- what it refuses ----------------------------------------------------------

t.group("a pair whose frame data is short gets no window")

do
    local w, missing = Timing.window({ startup = 14, active = "5" }, B,
                                     { hold_ticks = 3, buffer_ticks = 4 })
    t.is_nil(w, "a record missing recovery produces nothing")
    local named = {}
    for _, m in ipairs(missing) do named[m] = true end
    t.ok(named["a.recovery"], "and the missing field is named")
    t.ok(named["a.hitstop"], "every one of them, not just the first")
end

do
    -- The one that must not fall back to a number. A default gap that looks
    -- like a prediction is worse than no prediction: delay 4 was exactly that
    -- and it cost 202 rows.
    local w, missing = Timing.window(A, B, { hold_ticks = 3 })
    t.is_nil(w, "no buffer, no window")
    t.eq(missing[1], "input_buffer_ticks", "and it says which number is missing")
end

do
    -- hitstun is only needed for the whiff edge, so its absence costs that edge
    -- and not the window.
    local a = { startup = 14, active = "5", recovery = 15, hitstop = 13 }
    local w = Timing.window(a, B, { hold_ticks = 3, buffer_ticks = 4 })
    t.ok(w ~= nil, "a window without hitstun still builds")
    t.eq(w.latest, 44, "with the same edges")
    t.is_nil(w.whiff_after, "and no whiff edge, rather than a made-up one")
end

do
    local w = Timing.window(nil, nil, { buffer_ticks = 4 })
    t.is_nil(w, "no records at all, no window")
end

-- --- a cancel is not a link ---------------------------------------------------

t.group("a move that recovers inside its own input")

do
    -- Nothing here pretends to predict a cancel window. What it must not do is
    -- return a negative gap, which SequenceCompiler would lay out as a program
    -- that presses B before A.
    local quick = { startup = 1, active = "1", recovery = 0, hitstop = 0, hitstun = 10 }
    local w = Timing.window(quick, B, { hold_ticks = 3, buffer_ticks = 4 })
    t.ok(w.earliest >= 0, "the earliest gap is never negative")
    t.ok(w.latest >= w.earliest, "and the window is never inside out")
end

-- --- the gaps to try ----------------------------------------------------------

t.group("every tick in the window, not a sample of it")

do
    local w = Timing.window(A, B, { hold_ticks = 3, buffer_ticks = 4 })
    local gaps = Timing.gaps(w, 0)
    t.eq(#gaps, 5, "40..44 is five gaps")
    t.eq(gaps[1], 40, "starting at the earliest")
    t.eq(gaps[#gaps], 44, "and ending at the latest")
end

do
    -- The measured window was five ticks wide. A sweep that samples every
    -- fourth tick can step over it entirely - which is what the first route run
    -- did with its 4, 8, 12 list, and why it saw nothing between 36 and 40.
    local w = Timing.window(A, B, { hold_ticks = 3, buffer_ticks = 4 })
    local gaps = Timing.gaps(w, 0)
    for i = 2, #gaps do
        t.eq(gaps[i] - gaps[i - 1], 1, "consecutive ticks, no stride")
    end
end

do
    -- Padded, because the model is a prediction and the point of running is
    -- that it might be wrong.
    local w = Timing.window(A, B, { hold_ticks = 3, buffer_ticks = 4 })
    local gaps = Timing.gaps(w, 2)
    t.eq(gaps[1], 38, "the pad widens it below")
    t.eq(gaps[#gaps], 46, "and above")
    t.eq(#gaps, 9, "nine gaps instead of five")
end

do
    local w = { earliest = 1, latest = 3 }
    local gaps = Timing.gaps(w, 5)
    t.eq(gaps[1], 0, "the pad never takes it below zero")
end

t.eq(#Timing.gaps(nil), 0, "no window, no gaps")

-- --- B's motion before its button ---------------------------------------------

t.group("a motion puts B's button after the start of B's input")

-- SequenceCompiler: one tick per direction, the last held with the button.
t.eq(Timing.motion_ticks("720 + \229\188\186"), 10, "720 is eleven directions, ten before the button")
t.eq(Timing.motion_ticks("360 + \229\188\177"), 6, "360 is seven")
t.eq(Timing.motion_ticks("236236 + \228\184\173"), 5, "236236 is six")
t.eq(Timing.motion_ticks("63214 + \229\188\186"), 4, "63214 is five")
t.eq(Timing.motion_ticks("2 + SP + \229\188\186"), 0, "one direction is pressed with the button")
t.eq(Timing.motion_ticks("\228\184\173"), 0, "and so is no direction")
t.is_nil(Timing.motion_ticks(nil), "no notation is not zero")

do
    -- zangief-modern-framedata.jsonl, 621 (2MP) -> 1206 at gap 35: the simple
    -- input linked and the 236236 input came out five ticks later with the
    -- combo counter reset. The window was 35 for both. It is not the same gap.
    local mp2 = { startup = 8, active = "3", recovery = 16, hitstop = 11, hitstun = 22 }
    local b = { startup = 7 }
    local simple = Timing.window(mp2, b, { hold_ticks = 3, buffer_ticks = 4 })
    local motion = Timing.window(mp2, b, { hold_ticks = 3, buffer_ticks = 4, b_motion_ticks = 5 })
    t.eq(simple.latest, 35, "a one-direction B presses at the gap the committed row used")
    t.eq(motion.latest, 30, "236236 starts five ticks earlier so its button lands in the same place")
    t.eq(simple.whiff_after - motion.whiff_after, 5, "and the whiff edge moves with it")
    t.eq(motion.basis.b_motion_ticks, 5, "the basis says it was counted")
end

do
    -- 662 -> 1218 "720 + 强": pressed at 95 where the simple input pressed at
    -- 85, the ten ticks the model did not count.
    local hk6 = { startup = 22, active = "7(5)", recovery = 25, hitstop = 13 }
    local w = Timing.window(hk6, { startup = 6 }, { hold_ticks = 3, buffer_ticks = 4,
                                                    b_motion_ticks = 10 })
    t.eq(w.latest, 59, "72 - 3 - 10: the 720 starts during A's recovery")
    local long = Timing.window({ startup = 3, active = "1", recovery = 2, hitstop = 0 },
                               { startup = 6 }, { hold_ticks = 3, buffer_ticks = 4,
                                                  b_motion_ticks = 10 })
    t.eq(long.latest, 0, "a motion longer than the wait clamps at gap 0, never below")
end

-- --- cancels ------------------------------------------------------------------

t.group("a cancel is pressed during A's hit, and its end is searched")

do
    -- 617 2LP (startup 6, hitstop 9) into "720 + 强". In zangief-modern-delay4
    -- that 720 was pressed at offset 17 and never came out; a 360 pressed at 13
    -- came out at +15, the end of A's hitstop.
    local lp2 = { startup = 6, hitstop = 9 }
    local w, missing = Timing.cancel_window(lp2, nil, { hold_ticks = 3, b_motion_ticks = 10 })
    t.ok(w ~= nil, "a window: " .. tostring(missing and missing[1]))
    t.eq(w.basis.appears_at, 15, "B comes out where A's hitstop ends: 6 + 9")
    t.eq(w.basis.in_hitstop, 14, "the last press inside it")
    t.eq_list(w.gaps, { 0, 1, 3, 5 }, "gap 0 and 1 in hitstop, 3 and 5 searching past it")
    t.eq(w.late_at_zero, false, "13 at gap 0 is still inside the hitstop")
    t.eq(w.earliest, 0, "the grid starts at the first gap the compiler can make")
end

do
    -- 611 5LK (startup 7, hitstop 9): the 720 pressed at 17 - one past where B
    -- appears - DID come out. The grid has to reach it.
    local w = Timing.cancel_window({ startup = 7, hitstop = 9 }, nil,
                                   { hold_ticks = 3, b_motion_ticks = 10 })
    t.eq_list(w.gaps, { 0, 2, 4, 6 }, "0 and 2 in hitstop, 4 is the press that came out, 6")
end

do
    -- 621 2MP (startup 8, hitstop 11) into a one-direction B: pressed at offset
    -- 7 in the delay-4 rows, which is A's first active frame, and it came out.
    local w = Timing.cancel_window({ startup = 8, hitstop = 11 }, { startup = 7 },
                                   { hold_ticks = 3, b_motion_ticks = 0 })
    t.eq(w.gaps[1], 4, "the first gap presses on A's first active frame - gap 4, as ran")
    t.eq_list(w.gaps, { 4, 15, 17, 19 }, "then the end of hitstop and two strides past it")
    t.eq(w.basis.bound_at, 22, "bounded three ticks past where B appears")
end

do
    local w = Timing.cancel_window({ startup = 3, hitstop = 2 }, nil,
                                   { hold_ticks = 3, b_motion_ticks = 10 })
    t.eq_list(w.gaps, { 0 }, "a motion longer than the whole search gets gap 0 alone")
    t.eq(w.late_at_zero, true, "saying it is already past A's hitstop there")
    t.eq(w.past_bound_at_zero, true, "and past the searched bound")
end

do
    local w, missing = Timing.cancel_window({ startup = 7 }, nil, { hold_ticks = 3 })
    t.is_nil(w, "no hitstop, no cancel window")
    t.eq(missing[1], "a.hitstop", "and it says so")
    local x, xm = Timing.cancel_window(nil, nil, {})
    t.is_nil(x, "no record at all")
    t.eq(#xm, 2, "both fields named")
end

do
    -- The end of a cancel window is not in any frame table. What bounds the
    -- search has to say it is a bound.
    t.eq(Timing.CANCEL_SEARCH.status, "search_bound", "the search is labelled a bound")
    t.ok(tostring(Timing.CANCEL_SEARCH.provisional_source):find("NOT MEASURED") ~= nil,
         "and not a measurement")
    local w = Timing.cancel_window({ startup = 7, hitstop = 9 }, nil, { hold_ticks = 3 })
    t.eq(w.basis.bound_status, "search_bound", "which every window carries")
    for i = 2, #w.gaps do
        t.ok(w.gaps[i] > w.gaps[i - 1], "the grid is sorted and has no repeats")
    end
    local wide = Timing.cancel_window({ startup = 7, hitstop = 9 }, nil,
                                      { hold_ticks = 3, past_hitstop_ticks = 6, stride_ticks = 3 })
    t.eq(wide.gaps[#wide.gaps], 7 + 9 + 6 - 3, "a caller can widen the bound")
end

return t.finish()
