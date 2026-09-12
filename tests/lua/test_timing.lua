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

return t.finish()
