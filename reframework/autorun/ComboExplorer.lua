-- =========================================================
-- ComboExplorer.lua - automated combo discovery for Street Fighter 6.
-- Training Script Manager mode 6. This build is READ-ONLY: it observes and
-- measures, it never writes an input.
-- Receives shared state via _G (GameState, CurrentTrainerMode); owns its own
-- frame anchor in func/ComboExplorer/runtime/Clock.lua.
-- =========================================================
--
-- WHAT THIS BUILD IS FOR
--
-- Three things decide how the rest of the project is built, and none of them
-- can be settled by reading source:
--
--   A. Can combo damage be read at all? If mpTeam.mComboDamage silently reads
--      zero and the Explorer believes it, every edge records damage 0 and the
--      scoring phase ranks by a constant while looking healthy.
--   B. Is one input-hook call one battle frame? Until that is measured, a
--      recorded "delay 5" has no unit.
--   C. What does one attempt cost in wall-clock time? That number decides how
--      large the brute-force matrix can be.
--
-- A and B are in this build. Both are answered by watching, so nothing here
-- presses a button. Injection arrives only after calibration, and
-- core/Provenance.lua refuses it until then - structurally, not by convention.

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

local Provenance  = require("func/ComboExplorer/core/Provenance")
local InputMask   = require("func/ComboExplorer/core/InputMask")
local ProbeA      = require("func/ComboExplorer/core/ProbeA")
local ClockStats  = require("func/ComboExplorer/core/ClockStats")

local Config      = require("func/ComboExplorer/runtime/Config")
local GameAdapter = require("func/ComboExplorer/runtime/GameAdapter")
local Clock       = require("func/ComboExplorer/runtime/Clock")

local VERSION = "0.2.0-diagnostics"
local MODE_ID = 6

local GEN = (_G._ce_gen or 0) + 1
_G._ce_gen = GEN
local function current() return _G._ce_gen == GEN end

-- =========================================================
-- PROVENANCE
-- =========================================================

-- The register of what has and has not been measured on a real machine. Every
-- unverified value in the project lives here; nothing else is allowed to spell
-- one out as a constant.
local reg = Provenance.new()

local CAL_DIR = "ComboExplorer_data/calibration"
local CAL_LATEST = CAL_DIR .. "/latest.json"

local calibration_status = "none found"

local function load_calibration()
    local loaded
    if type(_G.safe_load_json) == "function" then
        local ok, r = pcall(_G.safe_load_json, CAL_LATEST)
        loaded = ok and r or nil
    end
    if type(loaded) ~= "table" then
        calibration_status = "none found - every value is unverified"
        return
    end
    local applied, rejected = reg:apply_calibration(loaded)
    calibration_status = ("%s: %d value(s) applied, %d rejected")
        :format(tostring(loaded.calibration_id or "unnamed"), #applied, #rejected)
end
load_calibration()

-- =========================================================
-- STRINGS
-- =========================================================

i18n.register("combo_explorer", {
    en = {
        title        = "SF6 COMBO EXPLORER",
        hdr_state    = "--- WHAT IS KNOWN ---",
        hdr_live     = "--- LIVE READOUT ---",
        hdr_probe_a  = "--- PROBE A: CAN DAMAGE BE READ ---",
        hdr_probe_b  = "--- PROBE B: IS A TICK A FRAME ---",
        mode_off     = "Select training mode 6 (COMBO EXPLORER) to use this panel.",
        readonly     = "READ-ONLY BUILD - this build never writes an input.",
        no_battle    = "Waiting for a battle (no players resolved).",
        anchor_dead  = "FRAME ANCHOR DEAD: app.BattleFlow::UpdateFrameMain not found. "
                    .. "Every timing measurement on this build is invalid - report this.",
        probe_a_help = "Land combos on the dummy yourself. Vary the length, and include at least one "
                    .. "that does NOT kill. Both damage measurements are compared per combo.",
        probe_b_help = "Play normally for a while, INCLUDING some hits - hitstop is the thing being "
                    .. "tested for, so a sample without it proves nothing.",
        start        = "START",
        stop         = "STOP",
        clear        = "CLEAR",
        write        = "WRITE REPORT",
        wrote        = "wrote",
        write_failed = "write failed",
        calibration  = "Calibration",
        unverified   = "unverified",
    },
    zh = {
        title        = "SF6 连段探索器",
        hdr_state    = "--- 已知情况 ---",
        hdr_live     = "--- 实时读数 ---",
        hdr_probe_a  = "--- 探针 A：伤害能否读取 ---",
        hdr_probe_b  = "--- 探针 B：一个 tick 是否等于一帧 ---",
        mode_off     = "请选择训练模式 6（连段探索器）以使用此面板。",
        readonly     = "只读版本 —— 此版本不会写入任何输入。",
        no_battle    = "等待对战开始（尚未获取到角色）。",
        anchor_dead  = "帧锚点失效：未找到 app.BattleFlow::UpdateFrameMain，本版本所有计时均无效。",
        probe_a_help = "请自行对假人打出连段。长度要有变化，并且至少包含一次不会击杀的连段。",
        probe_b_help = "正常游玩一段时间，并且要包含命中 —— 命中停顿正是待测对象。",
        start        = "开始",
        stop         = "停止",
        clear        = "清除",
        write        = "写入报告",
        wrote        = "已写入",
        write_failed = "写入失败",
        calibration  = "校准",
        unverified   = "未验证",
    },
})
local T = i18n.scope("combo_explorer")

local THEME = {
    hdr     = UIKit.THEME.hdr_skyblue,
    go      = UIKit.THEME.btn_green,
    stop    = UIKit.THEME.btn_red,
    neutral = UIKit.THEME.btn_neutral,
}

-- =========================================================
-- LIVE STATE
-- =========================================================

local live = {
    snap = nil,
    p1_control = nil,
    p1_control_polls = 0,
    p1_char = nil,
    p2_char = nil,
}

local probe_a = {
    on = false,
    probe = ProbeA.new({ idle_ticks_to_close = Config.data.probe_a_idle_ticks }),
    last_status = nil,
}

local probe_b = { last_status = nil }

-- Control scheme is polled on its own counter rather than on Clock.frame: the
-- anchor can fail to install, in which case Clock.frame stays at zero forever
-- and a value cached against it would never be re-read. Re-polled while nil for
-- the same reason - the first read can land before SelectMenu resolves.
local poll_counter = 0
re.on_frame(function()
    if not current() then return end
    Config.tick_save()

    poll_counter = poll_counter + 1
    if live.p1_control == nil or (poll_counter % 120) == 0 then
        live.p1_control = GameAdapter.control_scheme(0)
        live.p1_control_polls = live.p1_control_polls + 1
    end
    live.p1_char = GameAdapter.character(0)
    live.p2_char = GameAdapter.character(1)
end)

-- =========================================================
-- THE FRAME TICK
-- =========================================================

-- Driven from the frame anchor, NOT from the input callback: SharedHooks
-- dispatches that array only while injection is permitted, and a read-only
-- build must not go blind on the frames where it is not.
Clock.on_frame(function(frame)
    if not current() then return end
    if not Config.data.enabled then return end
    if _G.CurrentTrainerMode ~= MODE_ID then return end

    local snap = GameAdapter.snapshot(0)
    live.snap = snap

    if probe_a.on then
        probe_a.probe:tick(snap, frame)
    end
end)

-- The input callback does exactly one thing: count calls. It cannot write,
-- because this build has nothing that writes.
if _G._shared_input_post then
    table.insert(_G._shared_input_post, function(p_id, retval)
        if not current() then return end
        if not Config.data.enabled then return end
        Clock.count_call(p_id)
    end)
else
    if _G._mod_errors then
        _G._mod_errors.count = _G._mod_errors.count + 1
        _G._mod_errors.list[#_G._mod_errors.list + 1] = {
            ctx = "ComboExplorer", t = os.clock(),
            err = "_G._shared_input_post missing - SharedHooks did not load, the call histogram is dead",
        }
    end
end

-- =========================================================
-- ARTIFACT CONTEXT
-- =========================================================

local function artifact_ctx()
    return {
        version = VERSION,
        game_patch = reg.game_patch,
        calibration_id = reg.calibration_id,
        frame = Clock.frame,
        anchor_hooked = Clock.hooked,
        p1 = live.p1_char,
        p2 = live.p2_char,
        p1_control_scheme = live.p1_control,
        provenance = reg:snapshot(),
    }
end

-- =========================================================
-- UI
-- =========================================================

local function fmt(v)
    if v == nil then return "--" end
    if type(v) == "boolean" then return v and "true" or "false" end
    if type(v) == "number" then
        if v == math.floor(v) then return tostring(math.floor(v)) end
        return string.format("%.3f", v)
    end
    return tostring(v)
end

local function kv(label, value, color)
    imgui.text(label .. ": ")
    imgui.same_line()
    imgui.text_colored(value, color or UIKit.COLORS.White)
end

local function draw_state()
    kv(T("calibration"), calibration_status,
       reg.calibration_id and UIKit.COLORS.Green or UIKit.COLORS.Orange)

    local n = reg:summary()
    kv("values", ("%d verified / %d refuted / %d %s")
        :format(n.verified, n.refuted, n.unverified, T("unverified")),
       n.unverified > 0 and UIKit.COLORS.Orange or UIKit.COLORS.Green)

    -- The capability list is the honest statement of what this install can do.
    -- Injection appearing as blocked is not a fault; it is the design.
    for _, cap in ipairs({ Provenance.CAPABILITY.INJECTION, Provenance.CAPABILITY.TIMING,
                           Provenance.CAPABILITY.DAMAGE, Provenance.CAPABILITY.STAGE_RESET,
                           Provenance.CAPABILITY.PROBING }) do
        local ok, blocked = reg:can(cap)
        kv("  " .. cap, ok and "available" or ("blocked by " .. #blocked),
           ok and UIKit.COLORS.Green or UIKit.COLORS.DarkGrey)
    end
end

local function draw_live()
    local s = live.snap
    if not s then
        imgui.text_colored(T("no_battle"), UIKit.COLORS.DarkGrey)
        return
    end

    kv("P1 control", fmt(live.p1_control),
       live.p1_control == "modern" and UIKit.COLORS.Green or UIKit.COLORS.Orange)
    kv("P1 / P2", (live.p1_char and live.p1_char.name or "--") .. " / "
        .. (live.p2_char and live.p2_char.name or "--"))

    kv("P1 action id", fmt(s.attacker_action_id) .. " @f" .. fmt(s.attacker_action_frame),
       s.attacker_action_frame and UIKit.COLORS.Cyan or UIKit.COLORS.Red)
    kv("P1 act_st", fmt(s.attacker_act_st))
    kv("P1 combo_cnt", fmt(s.combo_count),
       (s.combo_count or 0) > 0 and UIKit.COLORS.Green or UIKit.COLORS.White)
    kv("P2 gard_combo_cnt", fmt(s.guard_count),
       (s.guard_count or 0) > 0 and UIKit.COLORS.Orange or UIKit.COLORS.White)

    -- The two damage reads side by side: this is what probe A exists to settle,
    -- and upstream takes max() of them because it never established which side
    -- carries the value.
    kv("mComboDamage P1 / P2", fmt(s.combo_damage_attacker) .. " / " .. fmt(s.combo_damage_victim),
       (s.combo_damage_attacker or s.combo_damage_victim) and UIKit.COLORS.Yellow or UIKit.COLORS.Red)

    kv("P1 hp / P2 hp", fmt(s.attacker_hp) .. " / " .. fmt(s.victim_hp)
        .. " (max " .. fmt(s.victim_hp_max) .. ")")
    kv("P1 drive / super", fmt(s.attacker_drive) .. " / " .. fmt(s.attacker_super))
    kv("P1 hit_stop", fmt(s.attacker_hitstop),
       (s.attacker_hitstop or 0) > 0 and UIKit.COLORS.Orange or UIKit.COLORS.White)
    kv("pos P1 / P2", fmt(s.attacker_pos) .. " / " .. fmt(s.victim_pos)
        .. "   dist " .. fmt(s.attacker_pos and s.victim_pos
                             and math.abs(s.attacker_pos - s.victim_pos)))

    -- RAW, plus its Lua type. Which truth value means "mirror" is unverified,
    -- and so is whether this field is even a boolean - in Lua an integer 0 is
    -- truthy, so an interpreted "right"/"left" would destroy the one datum
    -- needed to settle it.
    kv("P1 rl_dir raw", fmt(s.attacker_rl_dir_raw) .. "  (" .. fmt(s.attacker_rl_dir_type) .. ")",
       UIKit.COLORS.Cyan)

    kv("explorer tick", fmt(Clock.frame) .. (Clock.hooked and "" or "  [ANCHOR DEAD]"))
end

local function draw_probe_a()
    imgui.text_colored(T("probe_a_help"), UIKit.COLORS.Grey)

    if probe_a.on then
        if UIKit.styled_button(T("stop") .. "##ce_a", THEME.stop, UIKit.COLORS.White) then
            probe_a.on = false
            probe_a.probe:flush(Clock.frame)
        end
    else
        if UIKit.styled_button(T("start") .. "##ce_a", THEME.go, UIKit.COLORS.White) then
            probe_a.on = true
        end
    end
    imgui.same_line()
    if UIKit.styled_button(T("clear") .. "##ce_a_clear", THEME.neutral, UIKit.COLORS.White) then
        probe_a.probe:reset()
        probe_a.last_status = nil
    end
    imgui.same_line()
    if UIKit.styled_button(T("write") .. "##ce_a_write", THEME.neutral, UIKit.COLORS.White) then
        local report = probe_a.probe:report({ min_comparable = Config.data.probe_a_min_samples })
        local path, err = Config.write_diag("probe_a_damage", report, artifact_ctx())
        probe_a.last_status = path and (T("wrote") .. " " .. path)
            or (T("write_failed") .. ": " .. tostring(err))
    end

    local rep = probe_a.probe:report({ min_comparable = Config.data.probe_a_min_samples })
    kv("combos sampled", tostring(#rep.samples),
       #rep.samples > 0 and UIKit.COLORS.Green or UIKit.COLORS.DarkGrey)
    imgui.text_colored(rep.verdict, rep.sufficient and UIKit.COLORS.Green or UIKit.COLORS.Yellow)

    local n = #rep.samples
    for i = n, math.max(1, n - 4), -1 do
        local s = rep.samples[i]
        local note = s.agree_reason and ("  [" .. s.agree_reason .. "]") or ""
        imgui.text_colored(
            ("  #%d  hits %s  field %s  hpDelta %s  %s%s")
                :format(i, fmt(s.hits), fmt(s.combo_damage), fmt(s.hp_delta),
                        (s.agree == nil) and "n/a" or (s.agree and "agree" or "DISAGREE"), note),
            (s.agree == false) and UIKit.COLORS.Red or UIKit.COLORS.White)
    end

    if probe_a.last_status then
        imgui.text_colored(probe_a.last_status, UIKit.COLORS.Cyan)
    end
end

local function draw_probe_b()
    imgui.text_colored(T("probe_b_help"), UIKit.COLORS.Grey)

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
        local rep = Clock.diag_report({ min_frames = Config.data.probe_b_min_frames })
        local path, err = Config.write_diag("probe_b_clock", rep, artifact_ctx())
        probe_b.last_status = path and (T("wrote") .. " " .. path)
            or (T("write_failed") .. ": " .. tostring(err))
    end

    local r = Clock.diag_report({ min_frames = Config.data.probe_b_min_frames })
    kv("frames usable / total", fmt(r.frames.included) .. " / " .. fmt(r.frames.total))
    kv("excluded", ("gate %s, paused %s, partial %s")
        :format(fmt(r.frames.excluded_gate_closed), fmt(r.frames.excluded_paused),
                fmt(r.frames.excluded_partial)))
    kv("frames with hitstop", fmt(r.frames.with_hitstop),
       (r.frames.with_hitstop or 0) > 0 and UIKit.COLORS.Green or UIKit.COLORS.Orange)
    kv("engine frames", fmt(r.engine_frames.counted)
        .. "   gap " .. fmt(r.tick_vs_engine_gap))

    local p1 = r.players and r.players["0"]
    if p1 then
        for _, row in ipairs(p1.calls_per_frame or {}) do
            imgui.text(("  P1: %d call(s) on %d frame(s)"):format(row.calls, row.frames))
        end
    end

    if r.assessment and not r.assessment.usable then
        for _, prob in ipairs(r.assessment.problems) do
            imgui.text_colored("  ! " .. prob, UIKit.COLORS.Orange)
        end
    end
    if r.finding then
        imgui.text_colored(r.finding.reason or "",
            r.finding.conclusive and UIKit.COLORS.Green or UIKit.COLORS.Yellow)
    end

    if probe_b.last_status then
        imgui.text_colored(probe_b.last_status, UIKit.COLORS.Cyan)
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

    if UIKit.styled_header(T("hdr_state"), THEME.hdr) then draw_state() end
    if UIKit.styled_header(T("hdr_live"), THEME.hdr) then draw_live() end
    if UIKit.styled_header(T("hdr_probe_a"), THEME.hdr) then draw_probe_a() end
    if UIKit.styled_header(T("hdr_probe_b"), THEME.hdr) then draw_probe_b() end

    imgui.tree_pop()
end)

-- Exposed following the suite's flat _G convention, so later stages reach the
-- same register rather than building a second one that disagrees.
_G._ce_api = {
    version     = VERSION,
    mode_id     = MODE_ID,
    provenance  = reg,
    Provenance  = Provenance,
    InputMask   = InputMask,
    adapter     = GameAdapter,
    clock       = Clock,
    config      = Config,
    safety      = RuntimeSafety,
    input_profile = function() return InputMask.profile_from_provenance(Provenance, reg) end,
}
