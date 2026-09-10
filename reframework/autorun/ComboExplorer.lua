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
local ProbeC      = require("func/ComboExplorer/core/ProbeC")
local ClockStats  = require("func/ComboExplorer/core/ClockStats")
local Catalog     = require("func/ComboExplorer/core/Catalog")
local CatalogAudit = require("func/ComboExplorer/core/CatalogAudit")

local Config      = require("func/ComboExplorer/runtime/Config")
local GameAdapter = require("func/ComboExplorer/runtime/GameAdapter")
local Clock       = require("func/ComboExplorer/runtime/Clock")
local JsonIO      = require("func/ComboExplorer/runtime/JsonIO")

local VERSION = "0.3.0-diagnostics"
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
        hdr_probe_c  = "--- PROBE C: WHAT A RESET COSTS ---",
        hdr_probe_d  = "--- PROBE D: DOES THE CATALOG MATCH THIS GAME ---",
        probe_c_help = "Leave this running and reset the stage from the training menu a dozen "
                    .. "times. It times how long a reset actually takes to settle - which is "
                    .. "what decides how big the brute-force sweep can be.",
        probe_d_help = "Loads the shipped move catalog for P1's character and checks it against "
                    .. "the action ids the game has actually produced. Play for a while with "
                    .. "PROBE A running first, so there is something to compare against.",
        load_catalog = "LOAD CATALOG",
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
        hdr_probe_c  = "--- 探针 C：一次重置的代价 ---",
        hdr_probe_d  = "--- 探针 D：目录是否与本作匹配 ---",
        probe_c_help = "保持运行，并从训练菜单重置场景十余次。它会测量一次重置真正稳定下来所需的时间。",
        probe_d_help = "加载 1P 角色的招式目录，并与游戏实际产生的 action id 比对。请先运行探针 A 一段时间。",
        load_catalog = "加载目录",
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
    -- The last frame the panel was drawn on. Used to decide whether anyone is
    -- looking at the live readout.
    panel_frame = nil,
    hp_arm_usable = nil,
    hp_arm_reason = nil,
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

local probe_c = { on = false, probe = ProbeC.new(), last_status = nil }

local probe_d = {
    catalog = nil,
    problems = nil,
    load_error = nil,
    last_status = nil,
}

-- The catalog is loaded on demand rather than at file scope: the character is
-- not known until a battle exists, and loading the wrong one would be worse
-- than loading none.
local CATALOG_DIR = "TrainingComboTrials_data/command_display/"

-- Which shipped catalog describes P1, and its contents.
-- Returns path, decoded  or  nil, reason.
--
-- The obvious answer - command_display/<character name>.json - is not enough.
-- _shared_player_info.name is the character enum's ToString() (SharedHooks.lua
-- :132), and on the 2026-08 build that returns the internal key "ESF_006"
-- rather than "Zangief". Measured on hardware: Probe D could load no catalog at
-- all, and said "could not load .../ESF_006.json" - an error that reads like a
-- missing file rather than a name that was never a filename.
--
-- The fallback asks the catalogs who they describe rather than carrying another
-- copy of the id->name table. Three already exist in the suite (ComboTrials,
-- DistanceViewer, RSM), each local to a file this module has no business
-- importing from, and a fourth transcription is a fourth thing to update when a
-- character is added. Every shipped catalog carries _meta.fighter_id, and that
-- is the same numbering as _shared_player_info.id - so the data answers it.
local function resolve_catalog(info)
    if not info then
        return nil, "P1's character is not resolved yet - start a battle first"
    end

    local name = info.name and tostring(info.name) or ""
    -- Sanitised the way the suite does it, since this becomes a filename.
    local key = (name:gsub("[^%w_]", ""))

    -- An "ESF_nnn" is recognised as the internal key rather than tried as a
    -- filename, so the failure below can say what actually went wrong.
    local looks_like_a_name = key ~= "" and key ~= "Unknown" and not key:match("^ESF_%d+$")
    if looks_like_a_name then
        local path = CATALOG_DIR .. key .. ".json"
        -- Read RAW. Never through CommandDisplay's slim map, which falls back
        -- simple->motion and would credit ~50 moves with a one-button input
        -- they do not have.
        local decoded = JsonIO.load(path)
        if type(decoded) == "table" then return path, decoded end
    end

    local id = tonumber(info.id)
    if not id then
        return nil, ("P1 reports as %q, which is not a catalog name, and carries no numeric id to fall back on")
            :format(name)
    end
    if not (fs and fs.glob) then
        return nil, ("P1 reports as %q and fs.glob is unavailable, so the catalog cannot be found by fighter id")
            :format(name)
    end

    local ok, files = pcall(fs.glob, "TrainingComboTrials_data\\\\command_display\\\\.*json")
    if not ok or type(files) ~= "table" then
        return nil, "could not list " .. CATALOG_DIR
    end

    for _, path in ipairs(files) do
        local decoded = JsonIO.load(path)
        local meta = type(decoded) == "table" and decoded._meta
        if type(meta) == "table" and tonumber(meta.fighter_id) == id then
            return path, decoded
        end
    end

    return nil, ("no shipped catalog claims fighter_id %d (P1 reports as %q)"):format(id, name)
end

local function load_catalog()
    local path, decoded = resolve_catalog(live.p1_char)
    if not path then
        probe_d.load_error = tostring(decoded)
        probe_d.catalog = nil
        return
    end

    local cat, problems = Catalog.build(decoded)
    probe_d.catalog = cat
    probe_d.problems = problems
    probe_d.catalog_path = path
    probe_d.load_error = cat and nil or (problems and problems[1] and problems[1].reason)
end

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

    -- Probe A's control arm is a victim-HP delta, and the training menu can
    -- make that arm identically zero: infinite health never moves, recovery
    -- moves it back. Without this the probe would report a disagreement on
    -- every sample and blame mComboDamage for a menu setting.
    local usable, why = GameAdapter.hp_arm_usable(1)
    live.hp_arm_usable, live.hp_arm_reason = usable, why
    probe_a.probe:set_hp_arm(usable, why)
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

    -- A snapshot is around twenty reflection reads, each in its own pcall, and
    -- this runs inside a battle-sim hook. Taking one every frame when nothing
    -- is looking at it is pure cost, so it is only taken when a probe is
    -- running or the panel was drawn recently enough to still be on screen.
    local wanted = probe_a.on or probe_c.on
        or (live.panel_frame ~= nil and (frame - live.panel_frame) < 30)
    if not wanted then
        live.snap = nil
        return
    end

    local snap = GameAdapter.snapshot(0)
    live.snap = snap

    if probe_a.on then
        probe_a.probe:tick(snap, frame)
    end

    if probe_c.on then
        probe_c.probe:tick({
            refreshing = GameAdapter.is_refreshing(),
            combo_count = snap and snap.combo_count,
            attacker_act_st = snap and snap.attacker_act_st,
            victim_act_st = snap and snap.victim_act_st,
            attacker_pos = snap and snap.attacker_pos,
            victim_pos = snap and snap.victim_pos,
            wall_clock = os.clock(),
        }, frame)
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
    kv("dummy HP usable as a measure",
       (live.hp_arm_usable == true and "yes")
        or (live.hp_arm_usable == false and ("NO - " .. tostring(live.hp_arm_reason)))
        or "unknown - settings could not be read",
       live.hp_arm_usable == true and UIKit.COLORS.Green or UIKit.COLORS.Red)
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


local function draw_probe_c()
    imgui.text_colored(T("probe_c_help"), UIKit.COLORS.Grey)

    if probe_c.on then
        if UIKit.styled_button(T("stop") .. "##ce_c", THEME.stop, UIKit.COLORS.White) then
            probe_c.on = false
        end
    else
        if UIKit.styled_button(T("start") .. "##ce_c", THEME.go, UIKit.COLORS.White) then
            probe_c.on = true
        end
    end
    imgui.same_line()
    if UIKit.styled_button(T("clear") .. "##ce_c_clear", THEME.neutral, UIKit.COLORS.White) then
        probe_c.probe:reset()
        probe_c.last_status = nil
    end
    imgui.same_line()
    if UIKit.styled_button(T("write") .. "##ce_c_write", THEME.neutral, UIKit.COLORS.White) then
        local rep = ProbeC.conclude(probe_c.probe.episodes)
        rep.probe = "C.reset_cost"
        rep.episodes_detail = probe_c.probe.episodes
        local path, err = Config.write_diag("probe_c_reset", rep, artifact_ctx())
        probe_c.last_status = path and (T("wrote") .. " " .. path)
            or (T("write_failed") .. ": " .. tostring(err))
    end

    local rep = ProbeC.conclude(probe_c.probe.episodes)
    kv("resets observed", tostring(rep.episodes),
       rep.sufficient and UIKit.COLORS.Green or UIKit.COLORS.DarkGrey)
    imgui.text_colored(rep.verdict, rep.sufficient and UIKit.COLORS.Green or UIKit.COLORS.Yellow)
    if rep.total_ticks then
        kv("total ticks", ("min %d  median %d  max %d")
            :format(rep.total_ticks.min, rep.total_ticks.median, rep.total_ticks.max))
        kv("of which refresh", ("min %d  median %d  max %d")
            :format(rep.refresh_ticks.min, rep.refresh_ticks.median, rep.refresh_ticks.max))
    end
    if rep.suggested_settle_ticks then
        kv("suggested reset_settle_ticks", tostring(rep.suggested_settle_ticks), UIKit.COLORS.Cyan)
    end
    if probe_c.last_status then
        imgui.text_colored(probe_c.last_status, UIKit.COLORS.Cyan)
    end
end

local function draw_probe_d()
    imgui.text_colored(T("probe_d_help"), UIKit.COLORS.Grey)

    if UIKit.styled_button(T("load_catalog") .. "##ce_d_load", THEME.go, UIKit.COLORS.White) then
        load_catalog()
    end
    imgui.same_line()
    if UIKit.styled_button(T("write") .. "##ce_d_write", THEME.neutral, UIKit.COLORS.White) then
        if probe_d.catalog then
            local observed = {}
            for _, row in ipairs(probe_a.probe:action_id_histogram()) do
                observed[row.action_id] = row.entries
            end
            local rep = CatalogAudit.audit(probe_d.catalog, observed)
            local path, err = Config.write_diag("probe_d_catalog", rep, artifact_ctx())
            probe_d.last_status = path and (T("wrote") .. " " .. path)
                or (T("write_failed") .. ": " .. tostring(err))
        else
            probe_d.last_status = "load the catalog first"
        end
    end

    if probe_d.load_error then
        imgui.text_colored(probe_d.load_error, UIKit.COLORS.Red)
    end

    local cat = probe_d.catalog
    if not cat then
        imgui.text_colored("no catalog loaded", UIKit.COLORS.DarkGrey)
        return
    end

    kv("catalog", ("%s (fighter %s), generated %s")
        :format(tostring(cat.character), tostring(cat.fighter_id), tostring(cat.generated_at)),
       UIKit.COLORS.Cyan)
    kv("entries / rows", ("%d / %d"):format(cat.counts.entries, cat.counts.rows))
    kv("standalone / excluded", ("%d / %d"):format(cat.counts.standalone, cat.counts.excluded))
    kv("ambiguous notation groups", tostring(cat.counts.ambiguous_groups),
       cat.counts.ambiguous_groups > 0 and UIKit.COLORS.Orange or UIKit.COLORS.Green)

    if probe_d.problems and #probe_d.problems > 0 then
        imgui.text_colored(("%d entries the classifier could not place:")
            :format(#probe_d.problems), UIKit.COLORS.Orange)
        for i = 1, math.min(3, #probe_d.problems) do
            local p = probe_d.problems[i]
            imgui.text(("   %s: %s"):format(tostring(p.action_id), tostring(p.reason)))
        end
    end

    local observed = {}
    for _, row in ipairs(probe_a.probe:action_id_histogram()) do
        observed[row.action_id] = row.entries
    end
    local audit = CatalogAudit.audit(cat, observed)
    if audit then
        kv("observed ids matched", ("%d of %d"):format(audit.matched, audit.observed_action_ids))
        imgui.text_colored(audit.verdict,
            audit.conclusive and UIKit.COLORS.Green or UIKit.COLORS.Yellow)
    end

    if probe_d.last_status then
        imgui.text_colored(probe_d.last_status, UIKit.COLORS.Cyan)
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

    -- Marks the panel as being on screen, which is what keeps the per-frame
    -- snapshot alive.
    live.panel_frame = Clock.frame

    local changed, v = imgui.checkbox("enabled##ce_enabled", Config.data.enabled)
    if changed then
        Config.data.enabled = v
        Config.mark_dirty()
    end

    if UIKit.styled_header(T("hdr_state"), THEME.hdr) then draw_state() end
    if UIKit.styled_header(T("hdr_live"), THEME.hdr) then draw_live() end
    if UIKit.styled_header(T("hdr_probe_a"), THEME.hdr) then draw_probe_a() end
    if UIKit.styled_header(T("hdr_probe_b"), THEME.hdr) then draw_probe_b() end
    if UIKit.styled_header(T("hdr_probe_c"), THEME.hdr) then draw_probe_c() end
    if UIKit.styled_header(T("hdr_probe_d"), THEME.hdr) then draw_probe_d() end

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
