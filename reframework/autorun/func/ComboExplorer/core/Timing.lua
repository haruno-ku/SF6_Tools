-- =========================================================
-- ComboExplorer/core/Timing.lua - which gap a link needs, from the frame data.
-- =========================================================
--
-- WHY THIS EXISTS
--
-- The sweep ran every pair at delay 4 and found 8 links in 202 rows, all of
-- them Super Arts (#46). At gap 4 the second input lands inside the first
-- move's animation, which is a cancel window; a LINK needs the first move to
-- recover first. Nothing was carrying the number that says when that is.
--
-- The number was always computable. CandidateGenerator already reads startup
-- and on_hit out of the frame data; explore.lua then wrote only `confidence`
-- into the worklist and dropped the frames.
--
-- THE MODEL, AND WHY IT IS BELIEVED
--
-- Ticks here are counted from the tick move A's INPUT starts, because that is
-- what SequenceCompiler lays out. The gap is neutral ticks between the end of
-- A's input hold and the start of B's, so a gap of g puts B's press at
-- hold_ticks + g.
--
--   free_at   = startup + active + recovery + hitstop
--       when A's animation is over. hitstop is in there because
--       Provenance.hitstop_advances_tick came back REFUTED on this build: a
--       hitstop tick does not advance the move, so it is wall-clock the gap has
--       to cover.
--   gap_latest = free_at - hold_ticks
--       the last gap at which B is pressed no earlier than A being free.
--   gap_earliest = gap_latest - input_buffer_ticks
--       pressed inside the buffer, which the engine holds and applies on the
--       first actionable frame.
--   whiff_after = startup + hitstop + hitstun - b_startup - hold_ticks
--       past this, B comes out but the defender has left hitstun.
--
-- MEASURED ON HARDWARE, build 24176760, and this is why the model is here
-- rather than a guess in a comment. Zangief 6HP into 3MP:
--
--   6HP  startup 14  active 5  recovery 15  hitstop 13  hitstun 28  on_hit +8
--   3MP  startup 7
--
--   predicted gap_latest   = 14+5+15+13 - 3 = 44     measured: last link at 44
--   predicted whiff_after  = 14+13+28 - 7 - 3 = 45   measured: 44 hit, 48 whiffed
--   gap 40 linked and 36 did not                     so the buffer is 4..7
--
-- Two independent edges, both predicted. That is the evidence; the numbers are
-- still the frame data's and the buffer is still unmeasured, which is why it
-- goes through Provenance rather than being written here as a 4.
--
-- WHAT THIS DOES NOT CLAIM
--
-- A window, not an answer. The prediction says where to look, and the trial
-- says what happened - which is the whole arrangement this suite is built on.
-- A pair whose frame data is missing a field gets no window and says which
-- field was missing, rather than falling back to a number that would look like
-- a prediction.

local M = { name = "ComboExplorer.Timing" }

-- The first frame of `active` when it is a multi-hit string like "2(3)2(4)2".
--
-- Summed, not first: the move is not over until the last active frame, and
-- free_at is about when the move is over. A single number parses as itself.
function M.active_frames(active)
    if type(active) == "number" then return active end
    if type(active) ~= "string" then return nil end
    local total, found = 0, false
    -- Bracketed runs are the GAPS between hits and count as wall-clock too.
    for n in active:gmatch("%d+") do
        total = total + tonumber(n)
        found = true
    end
    if not found then return nil end
    return total
end

local function num(v)
    if type(v) == "number" then return v end
    if type(v) == "string" then return tonumber(v) end
    return nil
end

-- a : the frame-data record for move A
-- b : the frame-data record for move B
-- opts.hold_ticks   : how long each move's input is held (SequenceCompiler)
-- opts.buffer_ticks : the input buffer, from Provenance
--
-- Returns a window { earliest, latest, whiff_after, basis } or nil plus the
-- list of fields that were missing.
function M.window(a, b, opts)
    opts = opts or {}
    local hold = opts.hold_ticks or 3
    local buffer = opts.buffer_ticks

    local missing = {}
    local function need(v, name)
        local n = num(v)
        if n == nil then missing[#missing + 1] = name end
        return n
    end

    local startup  = need(a and a.startup, "a.startup")
    local active   = M.active_frames(a and a.active)
    if active == nil then missing[#missing + 1] = "a.active" end
    local recovery = need(a and a.recovery, "a.recovery")
    local hitstop  = need(a and a.hitstop, "a.hitstop")
    local hitstun  = need(a and a.hitstun, "a.hitstun")
    local b_start  = need(b and b.startup, "b.startup")
    if buffer == nil then missing[#missing + 1] = "input_buffer_ticks" end

    -- hitstun is only needed for the whiff edge, and a window without that edge
    -- is still a window. Everything else is load-bearing.
    local hard = {}
    for _, name in ipairs(missing) do
        if name ~= "a.hitstun" then hard[#hard + 1] = name end
    end
    if #hard > 0 then return nil, hard end

    local free_at = startup + active + recovery + hitstop
    local latest = free_at - hold
    local earliest = latest - buffer

    local whiff_after = nil
    if hitstun ~= nil and b_start ~= nil then
        whiff_after = startup + hitstop + hitstun - b_start - hold
    end

    -- The window is what to PRESS at. Clamped at zero because a gap cannot be
    -- negative, and a move whose recovery is shorter than the hold is a cancel
    -- rather than a link - which this does not pretend to predict.
    if earliest < 0 then earliest = 0 end
    if latest < earliest then latest = earliest end

    return {
        earliest = earliest,
        latest = latest,
        whiff_after = whiff_after,
        basis = {
            startup = startup, active = active, recovery = recovery,
            hitstop = hitstop, hitstun = hitstun, b_startup = b_start,
            free_at = free_at, hold_ticks = hold, buffer_ticks = buffer,
        },
    }
end

-- The gaps to actually try, from a window.
--
-- Every tick in it, not a sample: the window is a handful of ticks wide and the
-- edges are the interesting part. Measured, the whole thing was five values -
-- and a sweep that samples a five-wide window at every fourth tick can miss it
-- entirely.
--
-- `pad` widens it on both sides, because the model is a prediction and the
-- point of running is that it might be wrong. A pad of zero is a caller saying
-- it trusts the numbers exactly, which nothing here does.
function M.gaps(window, pad)
    if type(window) ~= "table" then return {} end
    pad = pad or 2
    local lo = math.max(0, window.earliest - pad)
    local hi = window.latest + pad
    local out = {}
    for g = lo, hi do out[#out + 1] = g end
    return out
end

return M
