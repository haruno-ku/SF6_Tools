-- =========================================================
-- ComboExplorer/core/ClockStats.lua - accumulates per-frame clock samples and
-- reports what was measured. Pure: takes frame records, returns a report.
-- =========================================================
--
-- WHAT THIS IS COUNTING, AND WHY IT IS FUSSY ABOUT IT
--
-- The question is whether one pl_input_sub call equals one battle frame. The
-- naive instrument - count calls, count frames, divide - produces a confident
-- wrong answer, because the two are not observed under the same conditions:
--
--   * Calls are seen through _G._shared_input_post, and SharedHooks dispatches
--     that array only while RuntimeSafety.can_inject_input() is true
--     (SharedHooks.lua:332). That gate closes during round transitions, menus,
--     and any frame where the training manager's data is not fully resolved.
--   * Frames are counted from the app.BattleFlow::UpdateFrameMain hook, which
--     has no such gate.
--
-- So a gate-closed frame contributes a frame with zero calls. A perfectly clean
-- build - exactly one call per player per frame - then shows two histogram
-- buckets, and a verdict written as "more than one bucket means more than one
-- call" reports the opposite of the truth. That answer would be written to a
-- file, shipped to the other machine, and used to pick the delay unit for the
-- whole project.
--
-- The fix is to record the conditions alongside the counts and exclude the
-- frames that cannot answer the question: gate closed, paused, or the partial
-- frame the probe started in the middle of.
--
-- This module also deliberately does NOT conclude. It reports measured
-- quantities and whether the sample is fit to draw a conclusion from. Setting
-- Provenance.input_hook_calls_per_frame is a human reading a histogram, not a
-- Lua boolean.

local M = { name = "ComboExplorer.ClockStats" }

-- A frame record, one per battle frame:
--   calls      : { [player_index] = number of pl_input_sub calls seen }
--   gate_open  : was RuntimeSafety.can_inject_input() true for this frame?
--   paused     : was the game in a pause/menu state?
--   hitstop    : was hit_stop non-zero on the observed player?
--   partial    : was the probe started part-way through this frame?
--
-- Anything missing is treated as unknown-and-therefore-excluded rather than as
-- a convenient default.

function M.new()
    return {
        frames = {},          -- included frames, aggregated
        total_frames = 0,
        included_frames = 0,
        gate_closed_frames = 0,
        paused_frames = 0,
        partial_frames = 0,
        hitstop_frames = 0,
        engine_frames = 0,    -- re.on_frame ticks over the same window
        engine_paused_frames = 0,
        hist = {},            -- [player] = { [calls] = frames }
        max_calls = {},
        total_calls = {},
    }
end

local function bump(t, k) t[k] = (t[k] or 0) + 1 end

-- Records one battle frame. Returns true when the frame was included in the
-- histogram, false when it was excluded (and why, as the second value).
function M.add_frame(s, rec)
    if type(rec) ~= "table" then return false, "not a record" end
    s.total_frames = s.total_frames + 1

    if rec.partial then
        s.partial_frames = s.partial_frames + 1
        return false, "partial"
    end
    if rec.paused then
        s.paused_frames = s.paused_frames + 1
        return false, "paused"
    end
    -- The decisive one: with the gate closed the callback never ran, so a zero
    -- here means "not observed", not "observed zero".
    if rec.gate_open == false then
        s.gate_closed_frames = s.gate_closed_frames + 1
        return false, "gate_closed"
    end
    if rec.gate_open == nil then
        s.gate_closed_frames = s.gate_closed_frames + 1
        return false, "gate_unknown"
    end

    s.included_frames = s.included_frames + 1
    if rec.hitstop then s.hitstop_frames = s.hitstop_frames + 1 end

    for player, n in pairs(rec.calls or {}) do
        s.hist[player] = s.hist[player] or {}
        bump(s.hist[player], n)
        if (s.max_calls[player] or -1) < n then s.max_calls[player] = n end
        s.total_calls[player] = (s.total_calls[player] or 0) + n
    end
    return true
end

-- The re.on_frame side of the comparison. Counted separately, and pause frames
-- are counted rather than dropped: upstream's engine_frame_count is explicitly
-- gated on pause (TrainingComboTrials_v1.0.lua:6004-6008), so an ungated render
-- counter would diverge for reasons that have nothing to do with hitstop.
function M.add_engine_frame(s, paused)
    if paused then
        s.engine_paused_frames = s.engine_paused_frames + 1
        return false
    end
    s.engine_frames = s.engine_frames + 1
    return true
end

local function histogram_rows(hist)
    local rows = {}
    for calls, frames in pairs(hist or {}) do
        rows[#rows + 1] = { calls = calls, frames = frames }
    end
    table.sort(rows, function(a, b) return a.calls < b.calls end)
    return rows
end

-- Is this sample fit to answer the question at all? Separated from the numbers
-- so a report can say "measured X, but do not act on it yet".
function M.assess(s, opts)
    opts = opts or {}
    local min_frames = opts.min_frames or 300
    local problems = {}

    if s.included_frames < min_frames then
        problems[#problems + 1] = ("only %d usable frames (want %d or more)")
            :format(s.included_frames, min_frames)
    end
    if s.hitstop_frames == 0 then
        -- Hitstop is the specific thing suspected of decoupling the two clocks,
        -- so a sample without any says nothing about the interesting case.
        problems[#problems + 1] = "no hitstop was observed - land some hits during the sample"
    end
    if s.gate_closed_frames > 0 and s.included_frames > 0
        and (s.gate_closed_frames / (s.gate_closed_frames + s.included_frames)) > 0.5 then
        problems[#problems + 1] = ("the injection gate was closed for %d of %d frames - "
            .. "most of the session was not observable")
            :format(s.gate_closed_frames, s.total_frames)
    end

    return {
        usable = (#problems == 0),
        problems = problems,
    }
end

-- Measured quantities only. No causal verdict: the numbers go to a person.
function M.report(s, opts)
    local per_player = {}
    for player, hist in pairs(s.hist) do
        per_player[tostring(player)] = {
            calls_per_frame = histogram_rows(hist),
            max_calls = s.max_calls[player],
            total_calls = s.total_calls[player],
            mean_calls = s.included_frames > 0
                and ((s.total_calls[player] or 0) / s.included_frames) or nil,
        }
    end

    return {
        probe = "B.clock",
        -- Frame accounting, so a reader can see exactly what was thrown away.
        frames = {
            total = s.total_frames,
            included = s.included_frames,
            excluded_gate_closed = s.gate_closed_frames,
            excluded_paused = s.paused_frames,
            excluded_partial = s.partial_frames,
            with_hitstop = s.hitstop_frames,
        },
        engine_frames = {
            counted = s.engine_frames,
            skipped_while_paused = s.engine_paused_frames,
        },
        -- Both clocks over the same window. Reported as two numbers and their
        -- difference; what causes the difference is not asserted here.
        tick_vs_engine_gap = s.engine_frames - s.included_frames,
        players = per_player,
        assessment = M.assess(s, opts),
    }
end

-- Reduces a report to the one thing Provenance wants to know, WITHOUT deciding
-- it. Returns the observed calls-per-frame when the sample is unambiguous and
-- fit, plus the reasoning either way. A human still writes the calibration.
function M.calls_per_frame_finding(report, player_index)
    local p = report.players and report.players[tostring(player_index or 0)]
    if not p then
        return { conclusive = false, reason = "no samples for that player" }
    end
    if not report.assessment.usable then
        return { conclusive = false, reason = "sample not fit: "
            .. table.concat(report.assessment.problems, "; ") }
    end

    local rows = p.calls_per_frame or {}
    if #rows == 0 then
        return { conclusive = false, reason = "no frames observed" }
    end
    if #rows > 1 then
        local seen = {}
        for _, r in ipairs(rows) do seen[#seen + 1] = ("%dx%d"):format(r.calls, r.frames) end
        return {
            conclusive = false,
            reason = "call count varies across frames: " .. table.concat(seen, ", "),
            histogram = rows,
        }
    end

    return {
        conclusive = true,
        calls_per_frame = rows[1].calls,
        frames = rows[1].frames,
        reason = ("every one of %d usable frames saw exactly %d call(s)")
            :format(rows[1].frames, rows[1].calls),
    }
end

return M
