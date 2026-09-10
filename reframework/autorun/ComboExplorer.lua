-- =========================================================
-- ComboExplorer.lua - automated combo discovery for Street Fighter 6.
-- Training Script Manager mode 6. This build is READ-ONLY: it observes and
-- measures, it does not inject input.
-- Receives shared state via _G (GameState, CurrentTrainerMode); owns its own
-- frame anchor in func/ComboExplorer/Clock.lua.
-- =========================================================
--
-- WHAT THIS BUILD IS FOR
--
-- Phase 1 of the plan (docs/ComboExplorer/plan-v3-implementation.md) says the
-- Explorer must not assume things that can only be settled on the real game.
-- Three of those gate everything downstream:
--
--   A. Can combo damage actually be read? mpTeam.mComboDamage is read at one
--      site in all of upstream, inside a pcall, with an HP-delta fallback the
--      author wrote because it may read zero. If it reads zero here, every
--      recorded edge gets damage 0 and the scoring phase produces garbage that
--      looks fine.
--   B. Is one input-hook call one frame? The hook fires at least once per
--      player per frame, and upstream says hitstop makes hook ticks and engine
--      frames drift. Until that is measured, "delay = 5" has no unit.
--   C. What does an attempt actually cost in wall-clock time? That single
--      number decides how large the brute-force matrix can be.
--
-- All three are answered by watching, not by driving, so this build injects
-- nothing at all. Input injection arrives only after the clock is understood.

local sdk = sdk
local re = re
local imgui = imgui

-- GameState first, at file scope: it registers its own re.on_frame at require
-- time and transitively pulls func/SharedHooks, so requiring it here means the
-- snapshot and the shared input arrays exist before anything below runs
-- (GameState.lua:15-18).
local GS            = require("func/GameState")
local RuntimeSafety = require("func/RuntimeSafety")
local UIKit         = require("func/UIKit")
local i18n          = require("func/i18n")

local Config    = require("func/ComboExplorer/Config")
local Clock     = require("func/ComboExplorer/Clock")
local Telemetry = require("func/ComboExplorer/Telemetry")
local InputMask = require("func/ComboExplorer/InputMask")

local MODE_ID = 6

-- Same generation guard the rest of the suite uses: after a REFramework script
-- reset the previous run's callbacks may still be reachable, and they must
-- no-op rather than fight the new ones.
local GEN = (_G._ce_gen or 0) + 1
_G._ce_gen = GEN
local function current() return _G._ce_gen == GEN end

-- =========================================================
-- STRINGS
-- =========================================================

i18n.register("combo_explorer", {
    en = {
        title        = "SF6 COMBO EXPLORER",
        hdr_status   = "--- STATUS ---",
        hdr_live     = "--- LIVE READOUT ---",
        hdr_spike_a  = "--- PROBE A: DAMAGE READABILITY ---",
        hdr_spike_b  = "--- PROBE B: CLOCK ---",
        mode_off     = "Select training mode 6 (COMBO EXPLORER) to use this panel.",
        readonly     = "READ-ONLY BUILD - this build never injects input.",
        no_battle    = "Waiting for a battle (no players resolved).",
        anchor_dead  = "FRAME ANCHOR DEAD: app.BattleFlow::UpdateFrameMain not found. "
                    .. "All timing on this build is invalid - report this.",
        p1_char      = "P1 character",
        p2_char      = "P2 character",
        control      = "P1 control",
        modern       = "MODERN",
        classic      = "CLASSIC",
        spike_a_help = "Land combos on the dummy yourself. Every combo is sampled and both "
                    .. "damage measurements are compared. 5+ combos of different lengths is enough.",
        spike_b_help = "Leave this running in a normal training situation, including some hits, "
                    .. "so hitstop is represented in the sample.",
        start        = "START",
        stop         = "STOP",
        clear        = "CLEAR",
        write        = "WRITE REPORT",
        samples      = "combos sampled",
        wrote        = "wrote",
        write_failed = "write failed",
    },
    zh = {
        title        = "SF6 连段探索器",
        hdr_status   = "--- 状态 ---",
        hdr_live     = "--- 实时读数 ---",
        hdr_spike_a  = "--- 探针 A：伤害可读性 ---",
        hdr_spike_b  = "--- 探针 B：时钟 ---",
        mode_off     = "请选择训练模式 6（连段探索器）以使用此面板。",
        readonly     = "只读版本 —— 此版本不会注入任何输入。",
        no_battle    = "等待对战开始（尚未获取到角色）。",
        anchor_dead  = "帧锚点失效：未找到 app.BattleFlow::UpdateFrameMain。此版本的所有计时均无效。",
        p1_char      = "1P 角色",
        p2_char      = "2P 角色",
        control      = "1P 操作方式",
        modern       = "现代",
        classic      = "经典",
        spike_a_help = "请自行对假人打出连段。每次连段都会被采样并比较两种伤害测量值。5 次以上不同长度的连段即可。",
        spike_b_help = "在包含命中的普通训练场景中保持运行，使采样包含命中停顿。",
        start        = "开始",
        stop         = "停止",
        clear        = "清除",
        write        = "写入报告",
        samples      = "已采样连段",
        wrote        = "已写入",
        write_failed = "写入失败",
    },
})
local T = i18n.scope("combo_explorer")

local THEME = {
    hdr = UIKit.THEME.hdr_skyblue,
    go  = UIKit.THEME.btn_green,
    stop = UIKit.THEME.btn_red,
    neutral = UIKit.THEME.btn_neutral,
}

-- =========================================================
-- LIVE READOUT
-- =========================================================

local live = {
    valid = false,
    p1_action = nil, p1_action_frame = nil, p1_act_st = 0,
    p1_combo = 0, p2_guard = 0,
    p1_hp = nil, p2_hp = nil, p2_hp_max = nil,
    p1_drive = nil, p1_super = nil,
    p1_pos = nil, p2_pos = nil, p1_facing = nil,
    p1_hitstop = nil,
    dmg_attacker = nil, dmg_victim = nil,
    p1_modern = nil,
}

-- InputType == 1 means Modern, read off the training SelectMenu
-- (ComboTrials_D2D.lua:339-352). Cached: the control type cannot change
-- mid-session, and this walks four managed fields.
local _modern_cache = { frame = -1, value = nil }
local function p1_is_modern()
    if _modern_cache.frame == Clock.frame then return _modern_cache.value end
    local v = nil
    pcall(function()
        local tm = sdk.get_managed_singleton("app.training.TrainingManager")
        local td = tm and tm:get_field("_tData")
        local sm = td and td:get_field("SelectMenu")
        local pd = sm and sm.PlayerDatas and sm.PlayerDatas[0]
        if pd and pd.InputType ~= nil then
            v = (tonumber(tostring(pd.InputType)) == 1)
        end
    end)
    _modern_cache.frame = Clock.frame
    _modern_cache.value = v
    return v
end

local function refresh_live()
    local p1, p2 = GS.p1, GS.p2
    live.valid = GS.valid and p1 ~= nil and p2 ~= nil
    if not live.valid then return end

    live.p1_action       = Telemetry.action_id(p1)
    live.p1_action_frame = Telemetry.action_frame(p1)
    live.p1_act_st       = GS.p1_act_st
    live.p1_combo        = Telemetry.combo_count(p1)
    live.p2_guard        = Telemetry.guard_count(p2)
    live.p1_hp           = Telemetry.hp(p1)
    live.p2_hp           = Telemetry.hp(p2)
    live.p2_hp_max       = Telemetry.hp_max(p2)
    live.p1_drive        = Telemetry.drive(p1)
    live.p1_super        = Telemetry.super_gauge(0)
    live.p1_pos          = Telemetry.pos_x_units(p1)
    live.p2_pos          = Telemetry.pos_x_units(p2)
    live.p1_facing       = Telemetry.facing_right(p1)
    live.p1_hitstop      = Telemetry.hitstop(p1)
    live.dmg_attacker    = Telemetry.combo_damage_raw(p1)
    live.dmg_victim      = Telemetry.combo_damage_raw(p2)
    live.p1_modern       = p1_is_modern()
end

-- =========================================================
-- PROBE A - is combo damage actually readable?
-- =========================================================

local spike_a = {
    on = false,
    tracker = nil,
    in_combo = false,
    idle_ticks = 0,
    peak_hits = 0,
    samples = {},
    last_status = nil,
}

-- A combo is over once the counter has been back at zero for a moment. The
-- grace exists because the counter is not trustworthy the instant it drops -
-- upstream distrusts it for 15 frames after a reset for the same reason.
local COMBO_END_TICKS = 20

local function spike_a_tick()
    local p1, p2 = GS.p1, GS.p2
    if not p1 or not p2 then return end

    local hits = Telemetry.combo_count(p1)

    if not spike_a.in_combo then
        if hits > 0 then
            spike_a.in_combo = true
            spike_a.idle_ticks = 0
            spike_a.peak_hits = hits
            spike_a.tracker = Telemetry.new_damage_tracker()
            spike_a.tracker:begin(p1, p2)
        end
    else
        if hits > spike_a.peak_hits then spike_a.peak_hits = hits end
        if hits == 0 then
            spike_a.idle_ticks = spike_a.idle_ticks + 1
        else
            spike_a.idle_ticks = 0
        end
    end

    if spike_a.tracker then spike_a.tracker:tick(p1, p2) end

    if spike_a.in_combo and spike_a.idle_ticks >= COMBO_END_TICKS then
        local r = spike_a.tracker:result()
        r.hits = spike_a.peak_hits
        r.tick_index = Clock.frame
        spike_a.samples[#spike_a.samples + 1] = r
        spike_a.in_combo = false
        spike_a.tracker = nil
        spike_a.peak_hits = 0
        spike_a.idle_ticks = 0
    end
end

local function spike_a_report()
    local resolved, nonzero, agreed, compared = 0, 0, 0, 0
    for _, s in ipairs(spike_a.samples) do
        if s.field_resolved then resolved = resolved + 1 end
        if s.field_nonzero then nonzero = nonzero + 1 end
        if s.agree ~= nil then
            compared = compared + 1
            if s.agree then agreed = agreed + 1 end
        end
    end

    -- The conclusion is stated in the file rather than left for someone to
    -- infer, because the person reading it is on the other machine.
    local verdict
    if #spike_a.samples == 0 then
        verdict = "NO SAMPLES - land some combos with the probe running"
    elseif nonzero == 0 then
        verdict = "mComboDamage NEVER READ NON-ZERO - the Explorer must use the HP delta"
    elseif compared > 0 and agreed == compared then
        verdict = "mComboDamage AGREES with the HP delta on every comparable sample - safe to use"
    elseif compared > 0 then
        verdict = "mComboDamage and the HP delta DISAGREE on some samples - keep recording both"
    else
        verdict = "mComboDamage reads non-zero but nothing was comparable (lethal combos only)"
    end

    return {
        probe = "A.damage_readability",
        verdict = verdict,
        samples_total = #spike_a.samples,
        field_resolved = resolved,
        field_nonzero = nonzero,
        comparable = compared,
        agreed = agreed,
        p1_modern = live.p1_modern,
        p2_hp_max = live.p2_hp_max,
        samples = spike_a.samples,
    }
end

-- =========================================================
-- PROBE B - clock
-- =========================================================

local spike_b = { last_report = nil, last_path = nil }

local function spike_b_report()
    local r = Clock.diag_report()
    r.probe = "B.clock"

    local per_frame = r.calls_per_frame.p1
    local single = (#per_frame == 1 and per_frame[1].calls == 1)
    if not r.anchor_hooked then
        r.verdict = "FRAME ANCHOR DEAD - UpdateFrameMain hook missing, timing invalid"
    elseif r.frames_sampled == 0 then
        r.verdict = "NO SAMPLES - start the probe during a battle"
    elseif single and r.frame_gap == 0 then
        r.verdict = "one input call per player per frame, and no gap vs re.on_frame - ticks are frames"
    elseif single then
        r.verdict = ("one input call per player per frame, but the tick clock and re.on_frame "
            .. "differ by %d over %d frames (%d with hitstop) - delays must stay in ticks")
            :format(r.frame_gap, r.frames_sampled, r.hitstop_frames)
    else
        r.verdict = "MORE THAN ONE input call per player per frame - the once-per-frame latch is load-bearing"
    end
    return r
end

-- =========================================================
-- THE TICK
-- =========================================================

-- Registered at file scope: SharedHooks clears both arrays when it loads and
-- again on script reset, so a late registration would simply never fire.
if _G._shared_input_post then
    table.insert(_G._shared_input_post, function(p_id, retval)
        if not current() then return end
        if not Config.data.enabled then return end

        Clock.count_call(p_id)

        -- One tick per player per frame. Everything below is P1's tick.
        if p_id ~= 0 then return end
        if not Clock.claim_tick(0) then return end
        if _G.CurrentTrainerMode ~= MODE_ID then return end

        pcall(refresh_live)
        if spike_a.on then pcall(spike_a_tick) end
    end)
else
    if _G._mod_errors then
        _G._mod_errors.count = _G._mod_errors.count + 1
        _G._mod_errors.list[#_G._mod_errors.list + 1] = {
            ctx = "ComboExplorer", t = os.clock(),
            err = "_G._shared_input_post missing - SharedHooks did not load, Explorer is inert",
        }
    end
end

re.on_frame(function()
    if not current() then return end
    Config.tick_save()
end)

-- =========================================================
-- UI
-- =========================================================

local function fmt(v, suffix)
    if v == nil then return "--" end
    if type(v) == "number" then
        if v == math.floor(v) then return tostring(math.floor(v)) .. (suffix or "") end
        return string.format("%.3f%s", v, suffix or "")
    end
    return tostring(v)
end

local function kv(label, value, color)
    imgui.text(label .. ": ")
    imgui.same_line()
    imgui.text_colored(value, color or UIKit.COLORS.White)
end

local function draw_live()
    if not live.valid then
        imgui.text_colored(T("no_battle"), UIKit.COLORS.DarkGrey)
        return
    end

    local mode_txt = (live.p1_modern == true) and T("modern")
        or (live.p1_modern == false) and T("classic") or "--"
    kv(T("control"), mode_txt, live.p1_modern and UIKit.COLORS.Green or UIKit.COLORS.Orange)

    kv("P1 action id", fmt(live.p1_action) .. " @f" .. fmt(live.p1_action_frame), UIKit.COLORS.Cyan)
    kv("P1 act_st", fmt(live.p1_act_st))
    kv("P1 combo_cnt", fmt(live.p1_combo),
       (live.p1_combo or 0) > 0 and UIKit.COLORS.Green or UIKit.COLORS.White)
    kv("P2 gard_combo_cnt", fmt(live.p2_guard),
       (live.p2_guard or 0) > 0 and UIKit.COLORS.Orange or UIKit.COLORS.White)

    -- The two damage reads side by side: this is the whole point of probe A,
    -- and upstream takes max() of them because it did not know which carries
    -- the value.
    kv("mComboDamage P1 / P2", fmt(live.dmg_attacker) .. " / " .. fmt(live.dmg_victim),
       (live.dmg_attacker or live.dmg_victim) and UIKit.COLORS.Yellow or UIKit.COLORS.Red)

    kv("P1 hp / P2 hp", fmt(live.p1_hp) .. " / " .. fmt(live.p2_hp)
        .. " (max " .. fmt(live.p2_hp_max) .. ")")
    kv("P1 drive / super", fmt(live.p1_drive) .. " / " .. fmt(live.p1_super))
    kv("P1 hit_stop", fmt(live.p1_hitstop),
       (live.p1_hitstop or 0) > 0 and UIKit.COLORS.Orange or UIKit.COLORS.White)
    kv("pos P1 / P2", fmt(live.p1_pos) .. " / " .. fmt(live.p2_pos)
        .. "   dist " .. fmt(live.p1_pos and live.p2_pos and math.abs(live.p1_pos - live.p2_pos)))
    kv("P1 rl_dir", live.p1_facing == nil and "--" or (live.p1_facing and "right" or "left"))
    kv("explorer tick", fmt(Clock.frame))
end

local function draw_spike_a()
    imgui.text_colored(T("spike_a_help"), UIKit.COLORS.Grey)

    if spike_a.on then
        if UIKit.styled_button(T("stop") .. "##ce_a", THEME.stop, UIKit.COLORS.White) then
            spike_a.on = false
        end
    else
        if UIKit.styled_button(T("start") .. "##ce_a", THEME.go, UIKit.COLORS.White) then
            spike_a.on = true
        end
    end
    imgui.same_line()
    if UIKit.styled_button(T("clear") .. "##ce_a_clear", THEME.neutral, UIKit.COLORS.White) then
        spike_a.samples = {}
        spike_a.in_combo = false
        spike_a.tracker = nil
        spike_a.last_status = nil
    end
    imgui.same_line()
    if UIKit.styled_button(T("write") .. "##ce_a_write", THEME.neutral, UIKit.COLORS.White) then
        local path = Config.write_diag("probe_a_damage", spike_a_report())
        spike_a.last_status = path and (T("wrote") .. " " .. path) or T("write_failed")
    end

    kv(T("samples"), tostring(#spike_a.samples),
       #spike_a.samples > 0 and UIKit.COLORS.Green or UIKit.COLORS.DarkGrey)

    local r = spike_a_report()
    imgui.text_colored(r.verdict, UIKit.COLORS.Yellow)

    -- Most recent few, newest first: enough to see it working without
    -- rendering a hundred rows every frame.
    local n = #spike_a.samples
    for i = n, math.max(1, n - 4), -1 do
        local s = spike_a.samples[i]
        local agree = (s.agree == nil) and "n/a" or (s.agree and "agree" or "DISAGREE")
        imgui.text_colored(
            ("  #%d  hits %s  mComboDamage %s  hpDelta %s  %s")
                :format(i, fmt(s.hits), fmt(s.combo_damage), fmt(s.hp_delta), agree),
            (s.agree == false) and UIKit.COLORS.Red or UIKit.COLORS.White)
    end

    if spike_a.last_status then
        imgui.text_colored(spike_a.last_status, UIKit.COLORS.Cyan)
    end
end

local function draw_spike_b()
    imgui.text_colored(T("spike_b_help"), UIKit.COLORS.Grey)

    if Clock.diag_running() then
        if UIKit.styled_button(T("stop") .. "##ce_b", THEME.stop, UIKit.COLORS.White) then
            Clock.diag_stop()
        end
    else
        if UIKit.styled_button(T("start") .. "##ce_b", THEME.go, UIKit.COLORS.White) then
            Clock.diag_start()
        end
    end
    imgui.same_line()
    if UIKit.styled_button(T("write") .. "##ce_b_write", THEME.neutral, UIKit.COLORS.White) then
        local r = spike_b_report()
        spike_b.last_report = r
        spike_b.last_path = Config.write_diag("probe_b_clock", r)
    end

    local r = spike_b_report()
    kv("frames sampled", fmt(r.frames_sampled))
    kv("re.on_frame ticks", fmt(r.engine_frames) .. "   gap " .. fmt(r.frame_gap))
    kv("frames with hitstop", fmt(r.hitstop_frames))
    kv("max calls/frame P1 / P2", fmt(r.max_calls.p1) .. " / " .. fmt(r.max_calls.p2))
    for _, row in ipairs(r.calls_per_frame.p1) do
        imgui.text(("  P1: %d call(s) on %d frame(s)"):format(row.calls, row.frames))
    end
    imgui.text_colored(r.verdict, UIKit.COLORS.Yellow)

    if spike_b.last_path then
        imgui.text_colored(T("wrote") .. " " .. spike_b.last_path, UIKit.COLORS.Cyan)
    end
end

re.on_draw_ui(function()
    if not current() then return end
    if not imgui.tree_node(T("title")) then return end

    imgui.text_colored(T("readonly"), UIKit.COLORS.Orange)

    if not Clock.hooked then
        imgui.text_colored(T("anchor_dead"), UIKit.COLORS.Red)
    end

    if _G.CurrentTrainerMode ~= MODE_ID then
        imgui.text_colored(T("mode_off"), UIKit.COLORS.DarkGrey)
        imgui.tree_pop()
        return
    end

    local changed, v = imgui.checkbox("enabled##ce_enabled", Config.data.enabled)
    if changed then
        Config.data.enabled = v
        Config.mark_dirty()
    end

    if UIKit.styled_header(T("hdr_live"), THEME.hdr) then draw_live() end
    if UIKit.styled_header(T("hdr_spike_a"), THEME.hdr) then draw_spike_a() end
    if UIKit.styled_header(T("hdr_spike_b"), THEME.hdr) then draw_spike_b() end

    imgui.tree_pop()
end)

-- Exposed so a later build (and the eventual Runner) can reach the same state
-- without re-deriving it, following the suite's flat _G convention.
_G._ce_api = {
    version   = "0.1.0-diagnostics",
    mode_id   = MODE_ID,
    live      = live,
    clock     = Clock,
    telemetry = Telemetry,
    inputmask = InputMask,
    config    = Config,
    safety    = RuntimeSafety,
}
