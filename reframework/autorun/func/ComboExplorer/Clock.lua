-- =========================================================
-- ComboExplorer/Clock.lua - the Explorer's frame anchor.
-- Owns one hook on app.BattleFlow::UpdateFrameMain and a once-per-frame
-- latch, so scheduling never counts raw pl_input_sub calls.
-- Receives nothing; require it at file scope before anything that schedules.
-- =========================================================
--
-- WHY THIS EXISTS
--
-- pl_input_sub fires more than once per battle frame -- once per player at
-- minimum, and the suite's own DEMO pre-callback does not filter on p_id,
-- which is exactly why upstream added a `tick_done_this_frame` latch reset
-- from a separate hook on app.BattleFlow::UpdateFrameMain
-- (TrainingComboTrials_v1.0.lua:6731-6740). A free-running counter of hook
-- calls is therefore NOT a frame counter.
--
-- There is a second, subtler problem. Upstream's own comment says hitstop
-- frames are "missed between engine ticks" and it ships
-- catch_up_missed_engine_frames() to compensate -- but that catch-up is gated
-- to piyo/burnout combos, so the drift is left uncorrected in the normal path.
-- So there are two clocks in this codebase: engine_frame_count (re.on_frame,
-- stops while paused) and the input-hook tick. They diverge, and hitstop sits
-- between move A and move B in every link test the Explorer will ever run.
--
-- The Explorer therefore anchors on UpdateFrameMain, calls that unit a TICK,
-- and treats "ticks == frames" as a hypothesis to be measured on the real
-- game rather than an assumption to build on. Clock.diag() collects exactly
-- the evidence that measurement needs.

local sdk = sdk
local re = re

local M = { name = "ComboExplorer.Clock" }

-- A reload leaves the previous generation's hooks installed and firing. Same
-- trick SharedHooks uses (SharedHooks.lua:100-105): bump a shared counter, and
-- have every callback bail unless it belongs to the newest generation.
local GEN = (_G._ce_clock_gen or 0) + 1
_G._ce_clock_gen = GEN
local function current() return _G._ce_clock_gen == GEN end

-- --- state -------------------------------------------------------------------

M.frame = 0          -- ticks since load; the Explorer's only time unit
M.valid = false      -- true once UpdateFrameMain has actually fired
M.hooked = false     -- false means the frame anchor is DEAD (see errors below)

local tick_claimed = {}   -- [p_id] = frame number the tick was claimed on

-- Diagnostics for spike B. Off by default: it allocates per frame and this
-- module runs inside a battle-sim hook.
local diag = {
    on = false,
    frames = 0,
    -- calls-per-frame histogram, per player: hist[p_id][n] = how many frames
    -- saw exactly n pl_input_sub calls for that player.
    hist = { [0] = {}, [1] = {}, [-1] = {} },
    calls_this_frame = { [0] = 0, [1] = 0, [-1] = 0 },
    -- hitstop divergence: engine_frames counts re.on_frame, so comparing it
    -- against M.frame measures the gap upstream warns about.
    engine_frames = 0,
    hitstop_frames = 0,
    max_calls = { [0] = 0, [1] = 0, [-1] = 0 },
}
M.diag_state = diag

local function note_error(msg)
    if _G._mod_errors then
        _G._mod_errors.count = _G._mod_errors.count + 1
        _G._mod_errors.list[#_G._mod_errors.list + 1] =
            { ctx = "ComboExplorer.Clock", err = msg, t = os.clock() }
    end
end

-- --- the frame anchor --------------------------------------------------------

local function on_frame_begin()
    if not current() then return end
    M.frame = M.frame + 1
    M.valid = true

    for p = -1, 1 do
        if diag.on then
            local n = diag.calls_this_frame[p]
            local h = diag.hist[p]
            h[n] = (h[n] or 0) + 1
            if n > diag.max_calls[p] then diag.max_calls[p] = n end
        end
        diag.calls_this_frame[p] = 0
    end
    if diag.on then diag.frames = diag.frames + 1 end
end

do
    local td = sdk.find_type_definition("app.BattleFlow")
    local method = td and td:get_method("UpdateFrameMain")
    if method then
        -- Pre-callback only, and it returns nothing: this hook observes the
        -- frame boundary, it must never influence UpdateFrameMain's control
        -- flow. The post-callback is the identity so we do not perturb the
        -- return value that other hooks on this method also see.
        sdk.hook(method,
            function(args) pcall(on_frame_begin) end,
            function(retval) return retval end)
        M.hooked = true
    else
        note_error("app.BattleFlow::UpdateFrameMain not found - frame anchor DEAD, "
            .. "all Explorer timing is invalid on this game build")
    end
end

-- --- the per-player once-per-frame latch -------------------------------------

-- Call from inside a _G._shared_input_post callback. Returns true at most once
-- per player per frame. Everything that writes an input mask or advances a
-- schedule goes through this; nothing counts hook calls directly.
function M.claim_tick(p_id)
    if not M.valid then return false end
    if tick_claimed[p_id] == M.frame then return false end
    tick_claimed[p_id] = M.frame
    return true
end

-- True when this player's tick for the current frame has already been taken.
function M.tick_claimed(p_id)
    return tick_claimed[p_id] == M.frame
end

-- --- diagnostics -------------------------------------------------------------

-- Counts a raw pl_input_sub call. Registered below; also safe to call from
-- another Explorer callback that runs before this one.
function M.count_call(p_id)
    if not diag.on then return end
    local slot = diag.calls_this_frame[p_id]
    if slot == nil then p_id = -1 end
    diag.calls_this_frame[p_id] = (diag.calls_this_frame[p_id] or 0) + 1
end

function M.diag_start()
    diag.frames = 0
    diag.engine_frames = 0
    diag.hitstop_frames = 0
    for p = -1, 1 do
        diag.hist[p] = {}
        diag.calls_this_frame[p] = 0
        diag.max_calls[p] = 0
    end
    diag.on = true
end

function M.diag_stop() diag.on = false end
function M.diag_running() return diag.on end

-- Flattened, JSON-friendly snapshot. `expected` is the answer spike B is
-- looking for: exactly 1 call per player per frame. Anything else means the
-- latch above is load-bearing rather than merely defensive.
function M.diag_report()
    local function flat(p)
        local out, total = {}, 0
        for n, c in pairs(diag.hist[p]) do
            out[#out + 1] = { calls = n, frames = c }
            total = total + n * c
        end
        table.sort(out, function(a, b) return a.calls < b.calls end)
        return out, total
    end
    local p0, t0 = flat(0)
    local p1, t1 = flat(1)
    local pu, tu = flat(-1)
    return {
        anchor_hooked   = M.hooked,
        frames_sampled  = diag.frames,
        engine_frames   = diag.engine_frames,   -- re.on_frame ticks over the same window
        frame_gap       = diag.engine_frames - diag.frames,
        hitstop_frames  = diag.hitstop_frames,
        calls_per_frame = { p1 = p0, p2 = p1, unknown = pu },
        total_calls     = { p1 = t0, p2 = t1, unknown = tu },
        max_calls       = { p1 = diag.max_calls[0], p2 = diag.max_calls[1], unknown = diag.max_calls[-1] },
    }
end

-- The re.on_frame side of the divergence measurement. Registered here rather
-- than in the UI so the sample window is the same one the hook counts.
re.on_frame(function()
    if not current() or not diag.on then return end
    diag.engine_frames = diag.engine_frames + 1
    local GS = _G.GameState
    local p1 = GS and GS.p1
    if p1 then
        local ok, hs = pcall(function() return p1:get_field("hit_stop") end)
        if ok and hs and tonumber(tostring(hs)) and tonumber(tostring(hs)) > 0 then
            diag.hitstop_frames = diag.hitstop_frames + 1
        end
    end
end)

return M
