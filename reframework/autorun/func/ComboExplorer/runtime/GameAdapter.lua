-- =========================================================
-- ComboExplorer/runtime/GameAdapter.lua - the only file in the Explorer that
-- touches sdk. Everything else takes numbers.
-- Receives nothing; reads through _G.GameState, which must be required first.
-- =========================================================
--
-- WHY THE SEAM IS HERE
--
-- The machine this is written on has no Street Fighter 6 on it. Anything that
-- calls sdk cannot be run, let alone tested, until the game exists somewhere -
-- so the rule is that sdk appears in exactly one file, and every decision the
-- Explorer makes happens somewhere else, on plain numbers, under a unit test.
--
-- Tests substitute a table with the same functions. That is the entire point:
-- Probe, Injector and StageControl are written against this interface, and a
-- fake one lets their logic be exercised without a game.
--
-- WHAT IS A COPY AND WHY
--
-- Upstream reads all of this already, but every reader is `local` to its own
-- script - get_combo_count and the damage banking are file-locals in
-- TrainingComboTrials_v1.0.lua, absent from _G and from the ctx it hands its own
-- submodules. There is no accessor to call, only a pattern to copy.

local sdk = sdk

local M = { name = "ComboExplorer.GameAdapter" }

-- Field descriptors are resolved once and reused: GameState (:45,59) and
-- ComboTrials (:1068) both hoist theirs, and these functions run inside a
-- battle-sim hook where re-resolving per frame is real cost.
local _td_gBattle = sdk.find_type_definition("gBattle")
local _f_combo_cnt, _f_gard_cnt

-- --- players -----------------------------------------------------------------

-- GameState re-resolves these every frame and they can be nil. Never hold one
-- across a frame: a stale managed object survives a round reset as a pointer
-- into freed memory.
function M.player(index)
    local GS = _G.GameState
    if not GS or not GS.valid then return nil end
    return (index == 0) and GS.p1 or GS.p2
end

function M.players_valid()
    local GS = _G.GameState
    return (GS ~= nil) and GS.valid == true and GS.p1 ~= nil and GS.p2 ~= nil
end

function M.in_pause_menu()
    local GS = _G.GameState
    return (GS ~= nil) and GS.in_pause_menu == true
end

function M.act_st(index)
    local GS = _G.GameState
    if not GS then return nil end
    return (index == 0) and GS.p1_act_st or GS.p2_act_st
end

-- Character identity, published by SharedHooks from the mediator hook. Recorded
-- on every diagnostic so a sample can be attributed to a matchup.
function M.character(index)
    local info = _G._shared_player_info and _G._shared_player_info[index]
    if not info then return nil end
    return { id = info.id, key = info.key, name = info.name }
end

-- --- primitive reads ---------------------------------------------------------

local function num_field(p, name)
    if not p then return nil end
    local ok, v = pcall(function() return p:get_field(name) end)
    if not ok or v == nil then return nil end
    return tonumber(tostring(v))
end

-- Hit count, read on the ATTACKER. Corroborated at three call sites across two
-- upstream scripts, so this one is not in doubt.
function M.combo_count(p)
    if not p then return nil end
    local ok, v = pcall(function()
        if not _f_combo_cnt then
            _f_combo_cnt = p:get_type_definition():get_field("combo_cnt")
        end
        return _f_combo_cnt and _f_combo_cnt:get_data(p)
    end)
    if not ok or v == nil then return nil end
    return tonumber(tostring(v))
end

-- Guard count, read on the VICTIM. A rise during a step means the move was
-- BLOCKED rather than whiffed - the only discrimination available, since there
-- is no per-hitbox collision event anywhere in the suite.
function M.guard_count(p)
    if not p then return nil end
    local ok, v = pcall(function()
        if not _f_gard_cnt then
            _f_gard_cnt = p:get_type_definition():get_field("gard_combo_cnt")
        end
        if _f_gard_cnt then return _f_gard_cnt:get_data(p) end
        return p:get_field("dgard_combo_cnt")
    end)
    if not ok or v == nil then return nil end
    return tonumber(tostring(v))
end

-- The move that actually came out. act_st is a different enum - an action
-- STATE, not an action id - and cannot substitute here.
function M.action_id(p)
    if not p then return nil end
    local ok, v = pcall(function()
        local ap = p.mpActParam
        local part = ap and ap.ActionPart
        local eng = part and part._Engine
        return eng and eng:call("get_ActionID")
    end)
    if not ok or v == nil then return nil end
    return tonumber(tostring(v))
end

-- Frames elapsed inside the current action.
--
-- get_ActionFrame returns a via.sfix VALUE OBJECT, not a primitive, so
-- tostring() on it yields a type-and-address string and tonumber() of that is
-- nil. Both upstream readers unwrap it with an explicit ToString() method call
-- on the object (SF6_DistanceViewer.lua:746-750, TrainingComboTrials:1083-1084).
-- Getting this wrong is silent: the field simply reads as "unavailable"
-- forever, and injection latency - which is measured by watching this - can
-- never be calibrated.
function M.action_frame(p)
    if not p then return nil end
    local ok, v = pcall(function()
        local ap = p.mpActParam
        local part = ap and ap.ActionPart
        local eng = part and part._Engine
        local sf = eng and eng:call("get_ActionFrame")
        if not sf then return nil end
        if type(sf) == "number" then return sf end
        return tonumber(sf:call("ToString()"))
    end)
    if not ok or v == nil then return nil end
    return tonumber(v)
end

function M.hp(p)      return num_field(p, "vital_new") end
function M.hp_max(p)  return num_field(p, "vital_max") end
function M.drive(p)   return num_field(p, "focus_new") end
function M.hitstop(p) return num_field(p, "hit_stop") end

function M.counter_hit(p)      return (num_field(p, "counter_dm_flag") or 0) ~= 0 end
function M.punish_counter(p)   return (num_field(p, "counter_fw_flag") or 0) ~= 0 end

-- The RAW rl_dir value and its Lua type, untouched.
--
-- Which truth value means "mirror the direction bits" is unverified, and so is
-- whether the field is even a boolean. In Lua every number including 0 is
-- truthy, so coercing with `v and true or false` would return true for an
-- integer 0 and quietly destroy the one datum needed to settle the polarity.
-- The interpretation happens in InputMask, from a Provenance value; this
-- function's job is to report what is actually there.
function M.rl_dir_raw(p)
    if not p then return nil, nil end
    local ok, v = pcall(function() return p:get_field("rl_dir") end)
    if not ok then return nil, nil end
    return v, type(v)
end

-- Position. pos.x.v is raw sfix; the suite divides by 6553600 for metres and by
-- 65536 for the units the teleporter and the training menu work in.
function M.pos_x_raw(p)
    if not p then return nil end
    local ok, v = pcall(function() return p.pos.x.v end)
    if not ok or v == nil then return nil end
    return tonumber(tostring(v))
end

function M.pos_x_units(p)
    local raw = M.pos_x_raw(p)
    return raw and (raw / 65536.0) or nil
end

-- SA gauge lives on the TEAM, not the player.
function M.super_gauge(player_index)
    if not _td_gBattle then return nil end
    local ok, v = pcall(function()
        local team = _td_gBattle:get_field("Team"):get_data(nil)
        if not team or not team.mcTeam then return nil end
        local tm = team.mcTeam[player_index]
        return tm and tm.mSuperGauge
    end)
    if not ok or v == nil then return nil end
    return tonumber(tostring(v))
end

-- The single-site, author-hedged read. nil means "did not resolve", which is a
-- different fact from 0 and must stay distinguishable all the way out.
function M.combo_damage(p)
    if not p then return nil end
    local ok, v = pcall(function()
        local team = p.mpTeam
        return team and team.mComboDamage
    end)
    if not ok or v == nil then return nil end
    return tonumber(tostring(v))
end

-- --- training state ----------------------------------------------------------

-- Control scheme, from the training SelectMenu (ComboTrials_D2D.lua:339-352).
-- Returns "modern" | "classic" | nil, where nil means it could not be read.
function M.control_scheme(player_index)
    local v = nil
    pcall(function()
        local tm = sdk.get_managed_singleton("app.training.TrainingManager")
        local td = tm and tm:get_field("_tData")
        local sm = td and td:get_field("SelectMenu")
        local pd = sm and sm.PlayerDatas and sm.PlayerDatas[player_index]
        if pd and pd.InputType ~= nil then
            v = (tonumber(tostring(pd.InputType)) == 1) and "modern" or "classic"
        end
    end)
    return v
end

-- The training menu's health settings for one side.
--
-- Probe A's whole control arm is a victim-HP delta, and the training defaults
-- can make that arm identically zero: with infinite health the number never
-- moves, and with recovery on it moves back. Either way the probe would blame
-- mComboDamage for a menu setting and report a disagreement that is not one.
--
-- Field names and the ParameterSetting path are upstream's
-- (TrainingComboTrials_v1.0.lua:1281-1303).
function M.vital_settings(player_index)
    local out = nil
    pcall(function()
        local tm = sdk.get_managed_singleton("app.training.TrainingManager")
        local td = tm and tm:get_field("_tData")
        local ps = td and td:get_field("ParameterSetting")
        local pd = ps and ps.PlayerDatas and ps.PlayerDatas[player_index]
        if not pd then return end
        local function b(name)
            local v = pd[name]
            if v == nil then return nil end
            return v == true
        end
        local vt = pd.Vital_Type
        out = {
            vital_type = vt ~= nil and tonumber(tostring(vt)) or nil,
            infinity = b("Is_Vital_Infinity"),
            no_recovery = b("Is_Vital_No_Recovery"),
            recovery_timer = b("Is_Vital_Recovery_Timer"),
        }
    end)
    return out
end

-- Is the victim's health usable as a damage measurement right now?
--
-- Returns usable(bool|nil), reason. nil means the settings could not be read,
-- which is not the same as "fine" and must not be treated as such.
function M.hp_arm_usable(victim_index)
    local s = M.vital_settings(victim_index)
    if not s then return nil, "training health settings could not be read" end
    if s.infinity then
        return false, "the dummy is on infinite health - the HP delta cannot move"
    end
    if s.recovery_timer then
        return false, "the dummy recovers health on a timer - the HP delta is not damage"
    end
    if s.no_recovery == false then
        return false, "the dummy recovers health - the HP delta is not damage"
    end
    return true, nil
end

function M.is_refreshing()
    local v = false
    pcall(function()
        local tm = sdk.get_managed_singleton("app.training.TrainingManager")
        if tm and tm:get_field("_IsReqRefresh") == true then v = true end
    end)
    return v
end

-- The injection gate. Sampled once per frame by Clock so that frames where the
-- gate was shut can be excluded from measurements rather than counted as
-- frames where nothing happened.
function M.can_inject()
    local RS = package.loaded["func/RuntimeSafety"]
    if not RS then
        local ok, mod = pcall(require, "func/RuntimeSafety")
        RS = ok and mod or nil
    end
    if not RS or type(RS.can_inject_input) ~= "function" then return nil end
    local ok, v = pcall(RS.can_inject_input)
    if not ok then return nil end
    return v == true
end

-- --- writing ------------------------------------------------------------------
--
-- Everything above this line reads. These four write, and they exist because
-- core/StageControlFsm.lua emits exactly four commands and this file could
-- perform none of them: it had no set_field call of any kind. The reset the
-- Explorer has had a tested state machine for since day one could not actually
-- be carried out.
--
-- Every one is a copy of a pattern already in the suite, named here so the next
-- person can check it against the original rather than against this:
--
--   request_refresh   TrainingComboTrials_v1.0.lua:1387, 2126
--   set_position      SF6_Teleport.lua:108, SF6_DistanceViewer.lua:548
--   pin_resources     TrainingComboTrials_v1.0.lua:1189, 1201-1204
--
-- ALL OF THEM RETURN ok, reason. A write that fails silently is the worst
-- outcome available here: the stage is not where the caller thinks it is, the
-- trial runs anyway, and the pair is recorded as not linking. Every caller is
-- expected to keep the reason.

-- Raise the training manager's refresh request. It is a REQUEST - the engine
-- notices it some frames later and clears it when it is done - so this returns
-- as soon as the flag is set, and the state machine polls for the clear.
function M.request_refresh()
    local wrote = false
    local ok, err = pcall(function()
        local tm = sdk.get_managed_singleton("app.training.TrainingManager")
        if not tm then return end
        tm._IsReqRefresh = true
        wrote = true
    end)
    if not ok then return false, tostring(err) end
    if not wrote then return false, "the training manager did not resolve" end
    return true
end

-- x is in the units the training menu and the teleporter use: raw sfix / 65536,
-- which is what M.pos_x_units returns. The conversion back is via.sfix.From,
-- exactly as SF6_Teleport does it.
function M.set_position(index, x)
    if type(x) ~= "number" then return false, "position is not a number" end
    local p = M.player(index)
    if not p then return false, "player did not resolve" end

    local wrote = false
    local ok, err = pcall(function()
        local sfix = sdk.find_type_definition("via.sfix")
        if not sfix then return end
        local from_double = sfix:get_method("From(System.Double)")
        if not from_double or not p.POS_SETx then return end
        p:POS_SETx(from_double:call(nil, x))
        wrote = true
    end)
    if not ok then return false, tostring(err) end
    if not wrote then return false, "via.sfix.From or POS_SETx is unavailable" end
    return true
end

-- pin : { attacker_hp = n, victim_hp = n, attacker_drive = n, attacker_super = n }
-- Any subset. Absent keys are not written rather than written as zero.
--
-- Called EVERY TICK while a reset holds, because the engine servos these back:
-- writing them once is writing them to be overwritten. That is the state
-- machine decision, not this one - it re-emits the command for as long as it
-- wants the values held.
--
-- Returns ok, reason, written - `written` being the keys that actually reached
-- the game, so a caller can tell "nothing to do" from "nothing worked".
function M.pin_resources(attacker_index, pin)
    if pin == false or pin == nil then return true, nil, {} end
    if type(pin) ~= "table" then return false, "pin is not a table", {} end

    local a = M.player(attacker_index)
    local v = M.player(1 - attacker_index)
    local written = {}

    local function hp(player, value, key)
        if type(value) ~= "number" or not player then return end
        local ok = pcall(function()
            -- vital_old and heal_new alongside vital_new, the way upstream does
            -- it: writing vital_new alone leaves the other two describing the
            -- previous value, and the engine reconciles them back.
            player.vital_new = value
            player.vital_old = value
            player.heal_new = value
        end)
        if ok then written[#written + 1] = key end
    end

    hp(a, pin.attacker_hp, "attacker_hp")
    hp(v, pin.victim_hp, "victim_hp")

    if type(pin.attacker_drive) == "number" and a then
        local ok = pcall(function() a.focus_new = pin.attacker_drive end)
        if ok then written[#written + 1] = "attacker_drive" end
    end

    if type(pin.attacker_super) == "number" and _td_gBattle then
        local ok = pcall(function()
            local team = _td_gBattle:get_field("Team"):get_data(nil)
            if team and team.mcTeam and team.mcTeam[attacker_index] then
                team.mcTeam[attacker_index].mSuperGauge = pin.attacker_super
            end
        end)
        if ok then written[#written + 1] = "attacker_super" end
    end

    return true, nil, written
end

-- setup : a list of { index = <player>, field = "...", value = ... } written on
-- the training menu per-player parameter block - the same block
-- M.vital_settings reads.
--
-- The state machine hands this through without looking at it (what fields a
-- reset writes is the caller business), so this does the same: it writes what
-- it is given and reports what landed. An absent or empty setup is not an
-- error, it is a reset that configures nothing.
function M.write_setup(setup)
    if setup == nil then return true, nil, {} end
    if type(setup) ~= "table" then return false, "setup is not a list", {} end

    local written, failed = {}, {}
    for _, entry in ipairs(setup) do
        local applied = false
        pcall(function()
            local tm = sdk.get_managed_singleton("app.training.TrainingManager")
            local td = tm and tm:get_field("_tData")
            local ps = td and td:get_field("ParameterSetting")
            local pd = ps and ps.PlayerDatas and ps.PlayerDatas[entry.index]
            if not pd or type(entry.field) ~= "string" then return end
            pd[entry.field] = entry.value
            applied = true
        end)
        local name = ("%s[%s]"):format(tostring(entry.field), tostring(entry.index))
        if applied then written[#written + 1] = name else failed[#failed + 1] = name end
    end

    if #failed > 0 then
        return false, "could not write " .. table.concat(failed, ", "), written
    end
    return true, nil, written
end

-- --- one-shot snapshot -------------------------------------------------------

-- Everything Probe needs for one tick, in one call, so the probe logic never
-- holds a managed object and can be handed a plain table by a test.
--
-- attacker_index is the side performing the combo (0 for P1 in every current
-- scenario); the victim is the other one.
function M.snapshot(attacker_index)
    local a = M.player(attacker_index)
    local v = M.player(1 - attacker_index)
    if not a or not v then return nil end

    local rl_raw, rl_type = M.rl_dir_raw(a)

    return {
        combo_count            = M.combo_count(a),
        guard_count            = M.guard_count(v),
        combo_damage_attacker  = M.combo_damage(a),
        combo_damage_victim    = M.combo_damage(v),
        victim_hp              = M.hp(v),
        victim_hp_max          = M.hp_max(v),
        attacker_hp            = M.hp(a),
        attacker_action_id     = M.action_id(a),
        attacker_action_frame  = M.action_frame(a),
        attacker_act_st        = M.act_st(attacker_index),
        victim_act_st          = M.act_st(1 - attacker_index),
        attacker_hitstop       = M.hitstop(a),
        attacker_drive         = M.drive(a),
        attacker_super         = M.super_gauge(attacker_index),
        attacker_pos           = M.pos_x_units(a),
        victim_pos             = M.pos_x_units(v),
        attacker_rl_dir_raw    = rl_raw,
        attacker_rl_dir_type   = rl_type,
        counter_hit            = M.counter_hit(v),
        punish_counter         = M.punish_counter(v),
    }
end

-- The snapshot the state machines actually take, which is not the one above.
--
-- StageControlFsm reads `refreshing` and RunnerFsm reads `can_inject`, and
-- neither is in M.snapshot: one is a training-manager flag and the other is a
-- RuntimeSafety question, so neither belongs to the player read. The FSM header
-- says "the runtime layer puts the two together" - this is that layer, and
-- until now it did not exist. Without `refreshing` the reset machine can never
-- leave WAIT_REFRESH, so nothing downstream of it could ever have run.
function M.tick_snapshot(attacker_index)
    local snap = M.snapshot(attacker_index)
    if not snap then return nil end
    snap.refreshing = M.is_refreshing()
    -- nil when RuntimeSafety cannot be asked, and left as nil on purpose:
    -- RunnerFsm abandons on a KNOWN-shut gate and passes on an unknown one, so
    -- coercing to false here would turn "nobody could say" into "the gate is
    -- shut" and abandon every trial on a build where the module is absent.
    snap.can_inject = M.can_inject()
    return snap
end

return M
