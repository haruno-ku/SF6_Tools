-- =========================================================
-- ComboExplorer/runtime/Clock.lua - the Explorer's frame anchor and the only
-- per-battle-frame callback registry it uses.
-- Owns one hook on app.BattleFlow::UpdateFrameMain. Statistics live in
-- core/ClockStats.lua; this file only observes and dispatches.
-- =========================================================
--
-- WHY NOT JUST COUNT INPUT-HOOK CALLS
--
-- pl_input_sub fires at least once per player per frame, which is exactly why
-- upstream added a once-per-frame latch reset from a separate hook on
-- app.BattleFlow::UpdateFrameMain (TrainingComboTrials_v1.0.lua:6731-6740). A
-- free-running count of hook calls is not a frame count.
--
-- WHY THE PROBES DO NOT RUN IN THE INPUT CALLBACK
--
-- SharedHooks dispatches _G._shared_input_pre/post only while
-- RuntimeSafety.can_inject_input() is true (SharedHooks.lua:321,332). That gate
-- shuts during round transitions, menus, and any frame where the training
-- manager's data does not fully resolve. A read-only diagnostics build that
-- observed through that callback would be blind on exactly those frames - and,
-- worse, would count them as frames where the engine called nothing.
--
-- So the frame anchor and everything driven from it are ungated: they run in
-- the UpdateFrameMain hook. The input callback is used for one thing only,
-- counting calls, and the gate state is recorded per frame so that gated frames
-- can be excluded from the arithmetic instead of quietly poisoning it.

local sdk = sdk
local re = re

local ClockStats = require("func/ComboExplorer/core/ClockStats")
local GameAdapter = require("func/ComboExplorer/runtime/GameAdapter")

local M = { name = "ComboExplorer.Clock" }

-- A reload leaves the previous generation's hooks installed and firing. Same
-- mechanism SharedHooks uses (SharedHooks.lua:100-105).
local GEN = (_G._ce_clock_gen or 0) + 1
_G._ce_clock_gen = GEN
local function current() return _G._ce_clock_gen == GEN end

-- --- state -------------------------------------------------------------------

M.frame = 0        -- battle frames since load; the Explorer's only time unit
M.valid = false    -- true once UpdateFrameMain has actually fired
M.hooked = false   -- false means the anchor is DEAD and all timing is invalid

local tick_claimed = {}
local subscribers = {}

-- Per-frame accumulators, flushed on the next frame boundary.
local calls_this_frame = {}
local gate_open_this_frame = nil

-- Diagnostics, off by default: this runs inside a battle-sim hook.
local diag = { on = false, stats = nil, started_frame = nil }

local function note_error(msg)
    if _G._mod_errors then
        _G._mod_errors.count = _G._mod_errors.count + 1
        _G._mod_errors.list[#_G._mod_errors.list + 1] =
            { ctx = "ComboExplorer.Clock", err = msg, t = os.clock() }
    end
end

-- --- the frame boundary ------------------------------------------------------

local function flush_previous_frame()
    if not diag.on or not diag.stats then return end
    -- The frame the probe was started part-way through has an incomplete call
    -- count by construction, so it is marked rather than counted.
    local partial = (diag.started_frame ~= nil and M.frame == diag.started_frame)
    ClockStats.add_frame(diag.stats, {
        calls = calls_this_frame,
        gate_open = gate_open_this_frame,
        paused = GameAdapter.in_pause_menu(),
        hitstop = ((GameAdapter.hitstop(GameAdapter.player(0)) or 0) > 0),
        partial = partial,
    })
end

local function on_frame_begin()
    if not current() then return end

    flush_previous_frame()

    M.frame = M.frame + 1
    M.valid = true

    calls_this_frame = {}
    tick_claimed = {}

    -- Sampled once per frame, here, where it is reachable. Without this a frame
    -- on which the callback never ran is indistinguishable from a frame on
    -- which the engine made no call.
    gate_open_this_frame = GameAdapter.can_inject()

    for i = 1, #subscribers do
        pcall(subscribers[i], M.frame)
    end
end

do
    local td = sdk.find_type_definition("app.BattleFlow")
    local method = td and td:get_method("UpdateFrameMain")
    if method then
        -- Pre-callback observes the frame boundary; the post-callback is the
        -- identity so this hook cannot perturb a return value that upstream's
        -- own hook on the same method also sees.
        sdk.hook(method,
            function(args) pcall(on_frame_begin) end,
            function(retval) return retval end)
        M.hooked = true
    else
        note_error("app.BattleFlow::UpdateFrameMain not found - frame anchor DEAD, "
            .. "every Explorer timing measurement on this build is invalid")
    end
end

-- --- subscription ------------------------------------------------------------

-- Runs once per battle frame, ungated. Callbacks are pcall'd so one throwing
-- cannot stop the others or escape into the game.
function M.on_frame(fn)
    if type(fn) ~= "function" then return false end
    subscribers[#subscribers + 1] = fn
    return true
end

-- --- the per-player once-per-frame latch -------------------------------------

-- Call from inside a _G._shared_input_post callback. True at most once per
-- player per frame. Everything that writes an input mask goes through this.
function M.claim_tick(p_id)
    if not M.valid then return false end
    if tick_claimed[p_id] then return false end
    tick_claimed[p_id] = true
    return true
end

-- Counts a raw pl_input_sub call. Cheap by design: this is the hottest path in
-- the module and it runs whether or not diagnostics are on.
function M.count_call(p_id)
    calls_this_frame[p_id] = (calls_this_frame[p_id] or 0) + 1
end

-- --- diagnostics -------------------------------------------------------------

function M.diag_start()
    diag.stats = ClockStats.new()
    diag.started_frame = M.frame
    diag.on = true
end

function M.diag_stop() diag.on = false end
function M.diag_running() return diag.on end

function M.diag_report(opts)
    if not diag.stats then
        local empty = ClockStats.new()
        local r = ClockStats.report(empty, opts)
        r.anchor_hooked = M.hooked
        return r
    end
    local r = ClockStats.report(diag.stats, opts)
    r.anchor_hooked = M.hooked
    r.finding = ClockStats.calls_per_frame_finding(r, 0)
    return r
end

-- The re.on_frame side of the two-clock comparison.
--
-- Gated on the pause state the way upstream's engine_frame_count is
-- (TrainingComboTrials_v1.0.lua:6004-6008). An ungated render counter would
-- diverge from the battle-frame counter whenever the overlay or the pause menu
-- is open - and that gap would then be reported in the same breath as hitstop,
-- inviting the conclusion that the two clocks drift when all that happened was
-- somebody opened a menu to click STOP.
re.on_frame(function()
    if not current() or not diag.on or not diag.stats then return end
    ClockStats.add_engine_frame(diag.stats, GameAdapter.in_pause_menu())
end)

return M
