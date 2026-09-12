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

local Calibration = require("func/ComboExplorer/core/Calibration")
local CalRunner   = require("func/ComboExplorer/runtime/CalibrationRunner")

local Config      = require("func/ComboExplorer/runtime/Config")
local GameAdapter = require("func/ComboExplorer/runtime/GameAdapter")
local Clock       = require("func/ComboExplorer/runtime/Clock")
local JsonIO      = require("func/ComboExplorer/runtime/JsonIO")
local CatalogLocator = require("func/ComboExplorer/runtime/CatalogLocator")
local StageControl = require("func/ComboExplorer/runtime/StageControl")
local Injector = require("func/ComboExplorer/runtime/Injector")
local Sweep = require("func/ComboExplorer/runtime/Sweep")
local ResultCollector = require("func/ComboExplorer/core/ResultCollector")

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
        hdr_calib    = "--- CALIBRATION: WHICH BIT IS WHICH BUTTON ---",
        calib_help   = "The only part of this build that writes an input, and it writes from the "
                    .. "GUESS on purpose - it is testing the button map, not using it. Put the pad "
                    .. "down: whatever you hold is ORed in on top. It will ask you to swap sides.",
        calib_start  = "START SWEEP",
        calib_write  = "WRITE PROFILE",
        probe_c_help = "Leave this running and reset the stage from the training menu a dozen "
                    .. "times. It times how long a reset actually takes to settle - which is "
                    .. "what decides how big the brute-force sweep can be.",
        probe_d_help = "Loads the shipped move catalog for P1's character and checks it against "
                    .. "the action ids the game has actually produced. Play for a while with "
                    .. "PROBE A running first, so there is something to compare against.",
        load_catalog = "LOAD CATALOG",
        mode_off     = "Select training mode 6 (COMBO EXPLORER) to use this panel.",
        -- This used to say "this build never writes an input", which stopped
        -- being true when the calibration sweep landed and is about to be less
        -- true again. What the operator needs is not a label but the two
        -- things that decide whether a write can surprise them.
        readonly     = "This build CAN write: the calibration sweep writes inputs, and a stage "
                    .. "reset writes the training menu. Neither runs unless you start it here.",
        hdr_stage    = "STAGE RESET",
        stage_help   = "Performs one training-stage reset and reports what it took. Writes NO "
                    .. "input - only the refresh request - so this is safe to run before the "
                    .. "calibration sweep. It measures the numbers the sweep does not produce.",
        stage_start  = "RESET ONCE",
        stage_write  = "WRITE REPORT",
        hdr_trial    = "TRIAL",
        trial_help   = "Runs ONE A-into-B attempt and records it. This is the first thing that "
                    .. "uses the measured button map rather than testing it, so it refuses to "
                    .. "start until the calibration sweep has settled all three input entries. "
                    .. "Load the catalog in PROBE D first.",
        trial_run    = "RUN ONE TRIAL",
        trial_next   = "NEXT PAIR",
        hdr_sweep    = "SWEEP",
        sweep_help   = "Runs the whole worklist for this character unattended. Start it and "
                    .. "leave it: it resumes where a previous run stopped, retries what came "
                    .. "back inconclusive, and stops if nothing is being measured. Run the "
                    .. "calibration first - it refuses until the input map is measured.",
        sweep_start  = "START SWEEP",
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
        hdr_calib    = "--- 校准：哪个位对应哪个按键 ---",
        calib_help   = "本版本中唯一会写入输入的部分，且刻意使用推测值——它是在检验按键表，"
                    .. "而不是在使用它。请放开手柄：你按住的任何键都会被叠加进去。中途会要求你换边。",
        calib_start  = "开始扫描",
        calib_write  = "写入配置",
        probe_c_help = "保持运行，并从训练菜单重置场景十余次。它会测量一次重置真正稳定下来所需的时间。",
        probe_d_help = "加载 1P 角色的招式目录，并与游戏实际产生的 action id 比对。请先运行探针 A 一段时间。",
        load_catalog = "加载目录",
        mode_off     = "请选择训练模式 6（连段探索器）以使用此面板。",
        readonly     = "此版本可以写入：校准扫描会写入输入，场地重置会写入训练菜单。"
                    .. "两者都必须在此面板中手动启动。",
        hdr_stage    = "场地重置",
        stage_help   = "执行一次训练场地重置并报告耗时。不写入任何输入，仅发送刷新请求，"
                    .. "因此可以在校准扫描之前安全运行。",
        stage_start  = "重置一次",
        stage_write  = "写入报告",
        hdr_trial    = "试行",
        trial_help   = "执行一次 A→B 连段尝试并记录结果。这是第一个真正使用已测按键映射的功能，"
                    .. "因此在校准扫描确定全部三项输入条目之前会拒绝启动。请先在 PROBE D 中加载目录。",
        trial_run    = "执行一次试行",
        trial_next   = "下一组",
        hdr_sweep    = "全量扫描",
        sweep_help   = "无人值守地跑完该角色的整个工作清单。可以启动后离开：会从上次中断处继续，"
                    .. "重试无结论的组合，并在没有任何测量发生时停止。请先完成校准。",
        sweep_start  = "开始扫描",
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
--
-- Which one describes P1 - and the "ESF_006" story behind why that is not just
-- a filename - lives in runtime/CatalogLocator.lua, because the calibration
-- sweep needs the same answer and used to carry its own copy of it.
local function resolve_catalog(info)
    return CatalogLocator.resolve(info)
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

-- The name the worklist and the trial log are FILED under.
--
-- NOT _shared_player_info.key. On this build that is the character enum's
-- internal key - "ESF_006" - so the sweep built
-- worklist/esf_006-modern.json, found nothing, and reported "no worklist for
-- ESF_006": a sentence about a missing file for a name that was never a
-- filename. Same fault CatalogLocator.lua was extracted to fix, on the other
-- path built from the same field.
--
-- The catalog answers it, because the catalog is the one that was matched to
-- THIS player by fighter_id, and its _meta.character is what the worklist
-- generator named its output after. Sweep.start then checks the two agree by
-- ac/bcm checksum, so a wrong name here cannot turn into a run against the
-- wrong character's pairs - it turns into a refusal.
--
-- nil when no catalog is loaded, which is not a fallback to the key: the sweep
-- needs the catalog anyway, and "load the catalog first" is the useful thing to
-- say. Guessing a filename from ESF_006 is what produced the misleading message.
local function character_file_key()
    local cat = probe_d.catalog
    local name = cat and cat.character
    if type(name) ~= "string" or name == "" then return nil end
    return (name:gsub("[^%w_]", ""))
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

local stage = { last_status = nil, last_result = nil }

-- Which pair the next trial will use. An index into the probeable rows rather
-- than a typed action id: the panel has no numeric input widget, and picking
-- from the catalog means the pair is always one the catalog says is reachable.
local trial = { pair = 1, delay = 4, last_status = nil, last_result = nil }
local sweep = { last_status = nil, last_result = nil }

-- WHERE THE FIGHTERS STAND FOR A TRIAL  (measured 2026-09-12, build 24176760)
--
-- StageControl ships target_positions = false, which means "wherever the reset
-- left them". That is -150 / +150, a separation of 300, and at 300 nothing
-- Zangief has reaches. Measured on hardware: the first canonicalised sweep
-- stopped saying "move A never came out" and started saying "move A came out
-- but never hit" - 29 rows of a light attack whiffing into open space.
--
-- The two numbers this is built from were read off the panel, not guessed:
--
--   reset leaves them at   pos -150 / 150   dist 300
--   walked into contact    pos 392.4 / 478.4  dist 86
--
-- 86 is where the pushboxes stop them, so it is the smallest separation the
-- game will hold. 90 is just outside that - close enough that a light attack
-- connects, far enough that the correction can converge instead of fighting
-- the pushbox for its ten retries.
--
-- Symmetric about 0 because the reset is, so a trial starts midscreen and the
-- screen_position in every row's conditions block stays honest.
--
-- This is a SETUP, not a measurement of the game, and it travels as one:
-- Injector.conditions_for turns it into the conditions block on every row, and
-- that block scopes the resume - a pair answered at 300 apart has not been
-- answered at 90 apart, and must not be skipped as done.
local STAGE_CFG = {
    target_positions = { attacker = -45, victim = 45 },
}

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
    -- A running machine is a reason to keep reading, and it was not one.
    --
    -- The panel-recency test below is a cost optimisation: a snapshot is about
    -- twenty reflection reads inside a battle-sim hook, so it is skipped when
    -- nothing is looking. But CalRunner.tick() is called AFTER this early
    -- return, so closing the panel - or just looking away for half a second -
    -- silently froze a calibration sweep mid-run. For something whose whole
    -- purpose is "start it and walk away", that was the opposite of the
    -- behaviour wanted.
    local machines_running = CalRunner.running() or StageControl.running()
        or Injector.running() or Sweep.running()
    local wanted = machines_running or probe_a.on or probe_c.on
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

    -- Ticked from the anchor, like the probes. The runner parks a mask here and
    -- the shared input callback spends it on the same frame.
    if CalRunner.running() then CalRunner.tick() end

    -- The stage reset takes its own snapshot rather than reusing `snap`: it
    -- needs `refreshing`, which GameAdapter.snapshot does not carry, and a
    -- reset that polled a stale flag would leave WAIT_REFRESH on the wrong
    -- frame. StageControl.tick calls tick_snapshot for exactly that reason.
    if StageControl.running() then
        local cmd = StageControl.tick()
        if cmd and cmd.outcome ~= nil then
            stage.last_result = StageControl.result()
            stage.last_status = ("reset %s in %d ticks"):format(
                tostring(cmd.outcome), stage.last_result.ticks)
            StageControl.stop()
        end
    end

    -- The sweep drives the injector itself, so it is ticked INSTEAD of the
    -- injector rather than beside it. Ticking both would advance one trial
    -- twice per frame.
    if Sweep.running() then
        Sweep.tick()
        local sp = Sweep.progress()
        if sp and sp.done then
            sweep.last_result = Sweep.result()
            sweep.last_status = tostring(sp.stopped_because)
            Sweep.stop()
        end
    elseif Injector.running() then
        local cmd = Injector.tick()
        if cmd and cmd.outcome ~= nil then
            trial.last_result = Injector.result()
            trial.last_status = ("trial %s after %d ticks"):format(
                tostring(cmd.outcome), trial.last_result.ticks)
            Injector.stop()
        end
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
-- Installed once per script generation, beside the counting callback below.
-- The error, if any, is kept on the module so the panel can show it: the local
-- the panel reads is not in scope this far up the file.
CalRunner.install(current)
Injector.install(current)

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
    -- The catalog this session is actually reading, named by its checksums.
    --
    -- Config.header has always had the fields; nothing was filling them, so
    -- every committed probe report says which mod version and which player
    -- produced it and nothing about which GAME DATA it was measured against.
    -- That is the field an action id has to be invalidated against when a patch
    -- moves it, and tools/lua/calibrate-from-probes.lua needs it before it can
    -- build a calibration profile at all - it currently reads the checksums back
    -- out of the repository's own copy of the catalog and takes the operator's
    -- word for the build.
    --
    -- game_patch stays whatever the register holds, which is usually nothing:
    -- the build number is not something this process can read, and writing a
    -- plausible stand-in would be inventing the identity of a measurement.
    local cat = probe_d.catalog
    return {
        version = VERSION,
        game_patch = reg.game_patch,
        calibration_id = reg.calibration_id,
        frame = Clock.frame,
        anchor_hooked = Clock.hooked,
        p1 = live.p1_char,
        p2 = live.p2_char,
        p1_control_scheme = live.p1_control,
        catalog = cat and {
            character = cat.character,
            fighter_id = cat.fighter_id,
            generated_at = cat.generated_at,
            ac_sha256 = cat.ac_sha256,
            bcm_sha256 = cat.bcm_sha256,
            path = probe_d.catalog_path,
        } or nil,
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

-- The sweep. Kept beside the probes rather than in its own tree so the panel
-- reads in the order the runbook does: measure, then calibrate.
local calib = { last_status = nil }

-- Both of these were inlined in the WRITE PROFILE button. They are named now
-- because the START button needs them too: a run that writes itself at the end
-- has to be told who it is at the beginning.
local function calibration_identity()
    return {
        calibration_id = ("%s-%s"):format(tostring(live.p1_char and live.p1_char.key),
                                          os.date("!%Y%m%dT%H%M%SZ")),
        game_patch = reg.game_patch or Config.data.game_patch or "unknown",
        control_scheme = live.p1_control or "modern",
    }
end

-- What a new profile should carry besides the sweep's own findings.
--
-- Two layers, and the order matters. The register is the base: it was loaded
-- from whatever profile this machine already had, so it is the only place the
-- measurements from previous sessions still exist. This session's probes go on
-- top, because a probe that has just run is newer than the value it replaces.
--
-- It used to be the probes alone. On a machine where the probes ran on another
-- day - which is every machine, the day after - finishing a sweep wrote a
-- profile containing only the sweep, and the five values behind timing, damage
-- and stage_reset were gone from latest.json. Nothing failed; the capabilities
-- simply went back to blocked on the next load.
local function probe_values_now()
    local live = Calibration.from_probes({
        probe_a = probe_a.probe:report({ min_comparable = Config.data.probe_a_min_samples }),
        probe_b = Clock.diag_report({ min_frames = Config.data.probe_b_min_frames }),
        -- ProbeC has no :report(); the verdict is a module function over the
        -- episode list, the same way draw_probe_c does it.
        probe_c = ProbeC.conclude(probe_c.probe.episodes),
    }, { provenance = reg })
    return Calibration.merge_values(Calibration.from_register(reg), live)
end

local function draw_calibration()
    imgui.text_colored(T("calib_help"), UIKit.COLORS.Grey)

    local ierr = CalRunner.install_error()
    if ierr then imgui.text_colored(ierr, UIKit.COLORS.Red) end

    if CalRunner.running() then
        if UIKit.styled_button(T("stop") .. "##ce_cal", THEME.stop, UIKit.COLORS.White) then
            -- Refuses once when there are observations and no profile written,
            -- because `run` is the only place they live. Pressing again forces
            -- it, for someone who means it.
            local ok, why = CalRunner.stop()
            if ok then
                calib.last_status = "stopped"
                calib.stop_armed = nil
            else
                calib.last_status = tostring(why)
                calib.stop_armed = true
            end
        end
        if calib.stop_armed then
            imgui.same_line()
            if UIKit.styled_button("DISCARD##ce_cal_force", THEME.stop, UIKit.COLORS.White) then
                CalRunner.stop({ force = true })
                calib.last_status = "discarded"
                calib.stop_armed = nil
            end
        end
    else
        if UIKit.styled_button(T("calib_start") .. "##ce_cal", THEME.go, UIKit.COLORS.White) then
            -- Identity and probe values handed over AT THE START, because the
            -- run writes itself when it finishes and there is nobody here to
            -- supply them then. The same two things the WRITE PROFILE button
            -- below assembles.
            local r, err = CalRunner.start(reg, {
                identity = calibration_identity(),
                probe_values = probe_values_now(),
            })
            calib.last_status = r and "sweep started" or ("could not start: " .. tostring(err))
        end
    end
    imgui.same_line()
    if UIKit.styled_button(T("calib_write") .. "##ce_cal_write", THEME.neutral, UIKit.COLORS.White) then
        local path, err = CalRunner.write_profile(calibration_identity(),
                                                  probe_values_now())
        calib.last_status = path and (T("wrote") .. " " .. path)
            or (T("write_failed") .. ": " .. tostring(err))
    end

    local p = CalRunner.progress()
    if p then
        kv("step", ("%d / %d  [%s]"):format(p.index, p.total, tostring(p.state)),
           p.done and UIKit.COLORS.Green or UIKit.COLORS.Cyan)
        if p.purpose then imgui.text_colored("  " .. p.purpose, UIKit.COLORS.White) end
        if p.note then imgui.text_colored("  " .. p.note, UIKit.COLORS.Yellow) end
        kv("idle action id", fmt(p.neutral_action_id))
        kv("masks written", tostring(p.writes))
    else
        imgui.text_colored("not running", UIKit.COLORS.DarkGrey)
    end

    -- The verdict so far, so a run that is going wrong is visible before it
    -- ends rather than after.
    local rep = CalRunner.running() and CalRunner.report() or nil
    if rep then
        local n = 0
        for _ in pairs(rep.values) do n = n + 1 end
        kv("entries settled", ("%d"):format(n), n > 0 and UIKit.COLORS.Green or UIKit.COLORS.DarkGrey)
        for _, note in ipairs(rep.notes) do
            imgui.text_colored(("  %s: %s"):format(note.key, note.reason), UIKit.COLORS.Orange)
        end
    end

    if calib.last_status then
        imgui.text_colored(calib.last_status, UIKit.COLORS.Cyan)
    end
end

-- One reset, and what it cost. This is the first thing to run on a machine
-- that has the game, because everything after it depends on the stage being
-- reproducible and because it writes no input at all.
local function draw_stage_reset()
    imgui.text_colored(T("stage_help"), UIKit.COLORS.Grey)

    if StageControl.running() then
        if UIKit.styled_button(T("stop") .. "##ce_stage", THEME.stop, UIKit.COLORS.White) then
            stage.last_result = StageControl.result()
            StageControl.stop()
            stage.last_status = "stopped by the operator"
        end
    else
        if UIKit.styled_button(T("stage_start") .. "##ce_stage", THEME.go, UIKit.COLORS.White) then
            stage.last_result = nil
            local ok, err = StageControl.start({})
            stage.last_status = ok and "reset started" or ("could not start: " .. tostring(err))
        end
    end

    imgui.same_line()
    if UIKit.styled_button(T("stage_write") .. "##ce_stage_write", THEME.neutral,
                           UIKit.COLORS.White) then
        local body = stage.last_result or StageControl.result()
        if body then
            local path, err = Config.write_diag("stage_reset", body, artifact_ctx())
            stage.last_status = path and (T("wrote") .. " " .. path)
                or (T("write_failed") .. ": " .. tostring(err))
        else
            stage.last_status = "nothing to write - run a reset first"
        end
    end

    local p = StageControl.progress()
    if p then
        kv("tick", ("%d  [%s]"):format(p.ticks, tostring(p.state)),
           p.outcome and UIKit.COLORS.Green or UIKit.COLORS.Cyan)
        if p.polling then imgui.text_colored("  waiting on " .. p.polling, UIKit.COLORS.Yellow) end
        -- The one line that says whether the request was ever raised. #40:
        -- polling can never see the rising edge of a request this suite raises
        -- (the engine consumes it between two of our ticks), so this readback -
        -- taken in the same call as the write - is the evidence. true means the
        -- request landed; false means it did not and the stage was NOT reset;
        -- absent means nobody looked.
        if p.refresh_ack ~= nil then
            kv("request read back", tostring(p.refresh_ack.after),
               p.refresh_ack.after == true and UIKit.COLORS.Green or UIKit.COLORS.Red)
            if p.refresh_ack.before == true then
                imgui.text_colored("  a refresh was already in flight when we asked",
                                   UIKit.COLORS.Orange)
            end
        end
        if p.reason then imgui.text_colored("  " .. p.reason, UIKit.COLORS.Yellow) end
        for _, c in ipairs(p.caveats or {}) do
            imgui.text_colored("  not observed: " .. tostring(c), UIKit.COLORS.Orange)
        end
        if p.attempt then kv("position attempt", tostring(p.attempt)) end
        if p.position_error then kv("position error", ("%.3f"):format(p.position_error)) end
        kv("inject allowed", tostring(p.inject_allowed))
        if p.unreadable > 0 then
            kv("unreadable ticks", tostring(p.unreadable), UIKit.COLORS.Orange)
        end
        if p.write_errors > 0 then
            kv("FAILED WRITES", tostring(p.write_errors), UIKit.COLORS.Red)
        end
    else
        imgui.text_colored("not running", UIKit.COLORS.DarkGrey)
    end

    -- The numbers this run exists to take. Shown after it finishes, because
    -- that is when they mean something.
    local res = stage.last_result
    if res then
        kv("outcome", tostring(res.outcome),
           res.outcome == "ready" and UIKit.COLORS.Green or UIKit.COLORS.Red)
        kv("ticks to ready", tostring(res.stage and res.stage.ticks_to_ready))
        -- Which evidence the verdict actually rested on. "write_readback" is
        -- our own request, observed; "poll" is a refresh somebody raised that
        -- cannot be attributed to us (#40). They are not the same claim and a
        -- reader of this panel must not have to guess which one a run got.
        kv("refresh seen high by", tostring(res.stage and res.stage.refresh_high_source),
           (res.stage and res.stage.refresh_high_source == "write_readback")
               and UIKit.COLORS.Green or UIKit.COLORS.Orange)
        for _, c in ipairs((res.stage and res.stage.caveats) or {}) do
            imgui.text_colored("  not observed: " .. tostring(c), UIKit.COLORS.Orange)
        end
        for _, w in ipairs(res.write_errors or {}) do
            imgui.text_colored(("  tick %s: %s failed - %s"):format(
                tostring(w.tick), tostring(w.write), tostring(w.reason)), UIKit.COLORS.Red)
        end
        -- Named as guesses on screen as well as in the file. A budget read
        -- back as a measurement is how an unverified number gets promoted.
        imgui.text_colored("  settings this ran under:", UIKit.COLORS.DarkGrey)
        for _, key in ipairs({ "settle_ticks", "grace_ticks", "refresh_timeout_ticks",
                               "settle_timeout_ticks" }) do
            local set = res.settings and res.settings[key]
            if set then
                imgui.text_colored(("    %s = %s  (%s)"):format(
                    key, tostring(set.value), tostring(set.provenance)),
                    tostring(set.provenance):find("measured") and UIKit.COLORS.Green
                        or UIKit.COLORS.Orange)
            end
        end
    end

    if stage.last_status then
        imgui.text_colored(stage.last_status, UIKit.COLORS.Cyan)
    end
end

-- The two moves the next trial will use, taken from the loaded catalog rather
-- than typed: the panel has no numeric input, and a pair chosen from the
-- catalog is always one the catalog says is reachable.
local function trial_pair()
    local cat = probe_d.catalog
    if not cat then return nil, nil, "load the catalog in PROBE D first" end
    local rows = Catalog.probeable(cat, {
        categories = { "normal", "command_normal" },
        input_methods = { "manual" },
    })
    if #rows < 2 then return nil, nil, "this catalog has fewer than two probeable moves" end

    -- Ordered pairs, A before B, skipping A into itself. The index walks them.
    local n = #rows
    local i = ((trial.pair - 1) % (n * (n - 1))) + 1
    local a_i = math.floor((i - 1) / (n - 1)) + 1
    local b_off = ((i - 1) % (n - 1)) + 1
    local b_i = (b_off >= a_i) and (b_off + 1) or b_off
    return rows[a_i], rows[b_i]
end

-- One A-into-B attempt. The first thing in the project that USES the button map
-- rather than testing it, which is why it is the first caller of the gate.
local function draw_trial()
    imgui.text_colored(T("trial_help"), UIKit.COLORS.Grey)

    local ierr = Injector.install_error()
    if ierr then imgui.text_colored(ierr, UIKit.COLORS.Red) end

    -- What injection is waiting on, said before the operator presses anything.
    -- Through can() rather than explain(): explain returns one formatted string
    -- with embedded newlines, and imgui.text_colored draws it as a single line.
    local open, blocked = Provenance.can(reg, Provenance.CAPABILITY.INJECTION)
    if open then
        imgui.text_colored("injection: available", UIKit.COLORS.Green)
    else
        imgui.text_colored("injection is blocked until these are measured:", UIKit.COLORS.Orange)
        for _, key in ipairs(blocked or {}) do
            local e = reg.entries[key]
            imgui.text_colored(("  %s [%s] - measured by: %s"):format(
                tostring(key), tostring(e and e.status), tostring(e and e.measured_by)),
                UIKit.COLORS.Orange)
        end
    end

    local a, b, why = trial_pair()
    if why then
        imgui.text_colored(why, UIKit.COLORS.Yellow)
    else
        kv("A", ("%s  (%d)"):format(tostring(a.notation), a.action_id))
        kv("B", ("%s  (%d)"):format(tostring(b.notation), b.action_id))
        kv("delay", ("%d ticks"):format(trial.delay))
    end

    if Injector.running() then
        if UIKit.styled_button(T("stop") .. "##ce_trial", THEME.stop, UIKit.COLORS.White) then
            trial.last_result = Injector.result()
            Injector.stop()
            trial.last_status = "stopped by the operator"
        end
    else
        if UIKit.styled_button(T("trial_run") .. "##ce_trial", THEME.go, UIKit.COLORS.White) then
            if not a then
                trial.last_status = tostring(why)
            else
                local route = {
                    id = ("t-%d-%d"):format(a.action_id, b.action_id),
                    -- The catalog's name, not the enum key, so a single trial's
                    -- row and a sweep's rows say the same word for the same
                    -- fighter. Reachable only with a catalog loaded - a and b
                    -- come out of it - so the fallback is for a shape nobody
                    -- has produced rather than for the ESF_006 case.
                    character = character_file_key() or "unknown",
                    control_scheme = live.p1_control or "modern",
                    steps = {
                        { index = 1, action_id = a.action_id,
                          input_method = a.input_method, notation = a.notation },
                        { index = 2, action_id = b.action_id,
                          input_method = b.input_method, notation = b.notation },
                    },
                }
                local ok, err = Injector.start({
                    provenance = reg,
                    allow_injection = Config.data.allow_injection,
                    route = route,
                    delay = trial.delay,
                    expected = { [1] = { a.action_id }, [2] = { b.action_id } },
                    edge_id = ("%d:%s->%d:%s"):format(a.action_id, a.input_method,
                                                      b.action_id, b.input_method),
                    attempt = 1,
                    frame = Clock.frame,
                    stage_cfg = STAGE_CFG,
                    sink = {
                        path = "ComboExplorer_data/trials/trials.jsonl",
                        dirs = { "ComboExplorer_data", "ComboExplorer_data/trials" },
                    },
                })
                trial.last_status = ok and "trial started"
                    or ("could not start: " .. tostring(err))
            end
        end
        imgui.same_line()
        if UIKit.styled_button(T("trial_next") .. "##ce_trial_next", THEME.neutral,
                               UIKit.COLORS.White) then
            trial.pair = trial.pair + 1
            trial.last_status = nil
        end
    end

    local p = Injector.progress()
    if p then
        kv("tick", ("%d  program %s/%s  [%s]"):format(
            p.ticks, tostring(p.program_tick), tostring(p.program_ticks), tostring(p.state)),
           p.outcome and UIKit.COLORS.Green or UIKit.COLORS.Cyan)
        if p.stage_state then kv("stage", tostring(p.stage_state)) end
        kv("masks written", tostring(p.writes))
        if p.reason then imgui.text_colored("  " .. p.reason, UIKit.COLORS.Yellow) end
        if p.write_error then imgui.text_colored("  " .. p.write_error, UIKit.COLORS.Red) end
        if p.write_errors > 0 then
            kv("FAILED WRITES", tostring(p.write_errors), UIKit.COLORS.Red)
        end
        if p.unreadable > 0 then kv("unreadable ticks", tostring(p.unreadable)) end
    else
        imgui.text_colored("not running", UIKit.COLORS.DarkGrey)
    end

    local res = trial.last_result
    if res then
        kv("outcome", tostring(res.outcome),
           res.outcome == "judged" and UIKit.COLORS.Green or UIKit.COLORS.Orange)
        kv("masks written", tostring(res.writes))
        -- Why it ended. The outcome alone is a category - "reset_failed" is
        -- true of a refresh that never landed, a correction that would not
        -- converge and a settle that timed out, and those send an operator to
        -- three different places. Measured 2026-09-12: a run of reset_failed
        -- trials was unreadable from this panel until this line existed.
        local tr = res.trial
        if tr and tr.reason then
            imgui.text_colored("  " .. tostring(tr.reason), UIKit.COLORS.Yellow)
        end
        if tr and tr.stage and tr.stage.reason then
            imgui.text_colored("  stage: " .. tostring(tr.stage.reason), UIKit.COLORS.Orange)
        end
        if tr and tr.stage and tr.stage.position_error then
            kv("position error", ("%.4f"):format(tr.stage.position_error),
               UIKit.COLORS.Orange)
        end
        local v = res.trial and res.trial.verdict
        if v then kv("verdict", tostring(type(v) == "table" and v.verdict or v)) end
    end

    if trial.last_status then
        imgui.text_colored(trial.last_status, UIKit.COLORS.Cyan)
    end
end

-- The whole worklist for this character, unattended.
local function draw_sweep()
    imgui.text_colored(T("sweep_help"), UIKit.COLORS.Grey)

    local char = character_file_key()
    local scheme = live.p1_control or "modern"
    local wl_path = char
        and ("ComboExplorer_data/worklist/%s-%s.json"):format(char:lower(), scheme)
        or nil
    local log_path = char
        and ("ComboExplorer_data/trials/%s-%s.jsonl"):format(char:lower(), scheme)
        or nil

    if wl_path then kv("worklist", wl_path) end

    if Sweep.running() then
        if UIKit.styled_button(T("stop") .. "##ce_sweep", THEME.stop, UIKit.COLORS.White) then
            sweep.last_result = Sweep.result()
            Sweep.stop()
            Injector.stop()
            sweep.last_status = "stopped by the operator"
        end
    else
        if UIKit.styled_button(T("sweep_start") .. "##ce_sweep", THEME.go, UIKit.COLORS.White) then
            sweep.last_status = nil
            sweep.last_result = nil
            -- Written out rather than as `wl_path and load(...) or nil, nil`,
            -- which parsed as one expression plus a literal nil: werr was
            -- ALWAYS nil, so load_worklist's specific reason - wrong schema, no
            -- pairs, or the path it actually looked at - was discarded and the
            -- operator got the generic sentence for all of them.
            local wl, werr
            if not wl_path then
                werr = "no catalog is loaded, so the worklist for this character "
                    .. "cannot be named - load it in PROBE D first"
            else
                wl, werr = Sweep.load_worklist(wl_path)
            end
            if not wl then
                sweep.last_status = tostring(werr or "the worklist could not be loaded")
            else
                -- Resume reads the previous file as TEXT, because a truncated
                -- last line is information the collector knows how to read.
                -- Resume reads the previous file as TEXT. If this build has
                -- no decoder the sweep still runs; it just repeats work, and
                -- saying so is the difference between that and a silent
                -- first-run-every-time.
                local prior = JsonIO.read_text(log_path)
                if prior and not JsonIO.can_decode() then
                    sweep.last_status = "WARNING: no json.load_string on this build, so "
                        .. "the previous run's results cannot be read back - trials "
                        .. "already answered will be run again"
                    prior = nil
                end
                local collector, cerr = ResultCollector.new({
                    append = function(line)
                        return JsonIO.append(log_path, line,
                                             { "ComboExplorer_data", "ComboExplorer_data/trials" })
                    end,
                    encode = JsonIO.encode_line,
                    decode = JsonIO.decode_line,
                    identity = {
                        calibration_id = reg.calibration_id,
                        game_patch = reg.game_patch or Config.data.game_patch or "unknown",
                        -- The conditions scope the resume as well as stamping the
                        -- rows. A pair answered with the gauges pinned has not
                        -- been answered with them loose, and without this the
                        -- second sweep would skip it as already done.
                        --
                        -- Injector.conditions_for is the same call start() makes,
                        -- so the block scoping the resume and the block on every
                        -- row cannot describe different setups.
                        conditions = Injector.conditions_for(STAGE_CFG),
                    },
                    resume = prior,
                })
                if not collector then
                    sweep.last_status = "collector refused: " .. tostring(cerr)
                else
                    local ok, err = Sweep.start({
                        worklist = wl,
                        catalog = probe_d.catalog,
                        collector = collector,
                        provenance = reg,
                        allow_injection = Config.data.allow_injection,
                        delay = trial.delay,
                        stage_cfg = STAGE_CFG,
                        sink = { path = log_path,
                                 dirs = { "ComboExplorer_data", "ComboExplorer_data/trials" } },
                    })
                    sweep.last_status = ok and "sweep started"
                        or ("could not start: " .. tostring(err))
                end
            end
        end
    end

    local p = Sweep.progress()
    if p then
        kv("pair", ("%d / %d"):format(p.index, p.total),
           p.done and UIKit.COLORS.Green or UIKit.COLORS.Cyan)
        -- Why the total is smaller than the file's. Without this line a
        -- canonicalised list reads as a truncated one.
        if p.canonical then
            imgui.text_colored("  " .. p.canonical, UIKit.COLORS.Cyan)
        elseif p.canonical_why then
            imgui.text_colored("  running against the catalog's ids - the measured "
                .. "one-id-per-notation map is not available (" .. p.canonical_why
                .. "), so a pair may wait for an id this build's button does not "
                .. "produce", UIKit.COLORS.Orange)
        end
        kv("finished", tostring(p.finished))
        kv("skipped (already answered)", tostring(p.skipped))
        if p.requeued > 0 then kv("waiting for another go", tostring(p.requeued)) end
        if p.start_failures > 0 then
            kv("would not start", tostring(p.start_failures), UIKit.COLORS.Orange)
        end
        if p.problems > 0 then kv("problems", tostring(p.problems), UIKit.COLORS.Orange) end
        if p.current then imgui.text_colored("  " .. tostring(p.current), UIKit.COLORS.White) end
    else
        imgui.text_colored("not running", UIKit.COLORS.DarkGrey)
    end

    local res = sweep.last_result
    if res and res.summary then
        kv("recorded", tostring(res.summary.written or 0))
        for verdict, n in pairs(res.summary.by_verdict or {}) do
            kv("  " .. tostring(verdict), tostring(n),
               verdict == "link" and UIKit.COLORS.Green or UIKit.COLORS.White)
        end
        for _, pr in ipairs(res.problem_detail or {}) do
            imgui.text_colored(("  %s: %s"):format(tostring(pr.pair), tostring(pr.reason)),
                               UIKit.COLORS.Orange)
        end
    end

    if sweep.last_status then
        imgui.text_colored(sweep.last_status, UIKit.COLORS.Cyan)
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
    if UIKit.styled_header(T("hdr_stage"), THEME.hdr) then draw_stage_reset() end
    if UIKit.styled_header(T("hdr_calib"), THEME.hdr) then draw_calibration() end
    if UIKit.styled_header(T("hdr_trial"), THEME.hdr) then draw_trial() end
    if UIKit.styled_header(T("hdr_sweep"), THEME.hdr) then draw_sweep() end

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
