-- =========================================================
-- ComboExplorer/Telemetry.lua - every game-state read the Explorer makes.
-- Pure reads plus one stateful damage tracker; no hooks, no writes.
-- Receives player objects from the caller (GameState.p1 / .p2).
-- =========================================================
--
-- WHY THIS IS A COPY AND NOT A CALL
--
-- The suite reads all of this already, but every one of those readers is
-- `local` to its own script -- get_combo_count and _ct_read_combo_cnt are
-- file-locals in TrainingComboTrials_v1.0.lua, absent from _G and absent from
-- the ctx table it hands its submodules. There is no accessor to call, only a
-- pattern to copy. Worse, upstream's damage banking is hard-gated on
-- trial_state.is_recording (:4762), so it does not even run outside ComboTrials
-- record mode. The Explorer owns its own copy, driven from its own tick.
--
-- DAMAGE IS MEASURED TWICE, DELIBERATELY
--
-- cPlayer.mpTeam.mComboDamage is read at exactly ONE site in the entire
-- upstream repo (:4226), inside a pcall, and the author wrote an HP-delta
-- fallback for it ("Fall back to HP when mComboDamage wasn't readable (0)",
-- :6126-6134). That is not a field to trust blind: if it silently reads 0 on
-- the current build, every brute-forced edge records damage 0 and the whole
-- scoring phase produces plausible-looking garbage. So each trial measures
-- both ways and stores both, and a disagreement is data, not an error.
--
-- The field is also not cumulative. It resets to 0 between combos, so the
-- cumulative number is manufactured by banking each segment's peak -- which is
-- why this is a tracker with a tick, not a getter.

local sdk = sdk

local M = { name = "ComboExplorer.Telemetry" }

-- Field descriptors are resolved once and reused. GameState (:45,59) and
-- ComboTrials (:1068) both hoist theirs; these run inside an input hook, so
-- re-resolving per frame is real cost.
local _td_gBattle = sdk.find_type_definition("gBattle")
local _f_combo_cnt = nil
local _f_gard_cnt  = nil

-- --- raw reads ---------------------------------------------------------------

local function read_combo_cnt(p)
    if not _f_combo_cnt then
        _f_combo_cnt = p:get_type_definition():get_field("combo_cnt")
    end
    return _f_combo_cnt and _f_combo_cnt:get_data(p) or 0
end

-- Hit count, read on the ATTACKER. Corroborated at three call sites across two
-- upstream scripts, so this one is safe.
function M.combo_count(p)
    if not p then return 0 end
    local ok, v = pcall(read_combo_cnt, p)
    return (ok and tonumber(tostring(v))) or 0
end

-- Guard/block count, read on the VICTIM. A rise here during a step means the
-- move was BLOCKED rather than whiffed -- the discrimination a link prober
-- needs, and the only one available (there is no per-hitbox collision event).
function M.guard_count(p)
    if not p then return 0 end
    local ok, v = pcall(function()
        if not _f_gard_cnt then
            _f_gard_cnt = p:get_type_definition():get_field("gard_combo_cnt")
        end
        if _f_gard_cnt then return _f_gard_cnt:get_data(p) end
        return p:get_field("dgard_combo_cnt")
    end)
    return (ok and tonumber(tostring(v))) or 0
end

-- The move that actually came out. act_st (GameState.p1_act_st) is a different
-- enum -- an action STATE, not an action id -- so it cannot substitute here.
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

-- Frames elapsed inside the current action. Used to measure injection latency:
-- write a mask on tick F, watch for the first tick where action_id changes.
function M.action_frame(p)
    if not p then return nil end
    local ok, v = pcall(function()
        local ap = p.mpActParam
        local part = ap and ap.ActionPart
        local eng = part and part._Engine
        return eng and eng:call("get_ActionFrame")
    end)
    if not ok or v == nil then return nil end
    return tonumber(tostring(v))
end

local function num_field(p, name)
    if not p then return nil end
    local ok, v = pcall(function() return p:get_field(name) end)
    if not ok or v == nil then return nil end
    return tonumber(tostring(v))
end

function M.hp(p)        return num_field(p, "vital_new") end
function M.hp_max(p)    return num_field(p, "vital_max") end
function M.drive(p)     return num_field(p, "focus_new") end
function M.hitstop(p)   return num_field(p, "hit_stop") end

-- true = facing right. Upstream comments warn NOT to derive side from comparing
-- X positions: they cross during juggles and crossups (ComboTrials:4132-4139).
function M.facing_right(p)
    if not p then return nil end
    local ok, v = pcall(function() return p:get_field("rl_dir") end)
    if not ok then return nil end
    return v and true or false
end

function M.counter_hit(p)  return (num_field(p, "counter_dm_flag") or 0) ~= 0 end
function M.punish_counter(p) return (num_field(p, "counter_fw_flag") or 0) ~= 0 end

-- Position in metres. pos.x.v is raw sfix; the suite divides by 6553600 for
-- metres and by 65536 for the "units" the teleporter and menu work in.
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
function M.super_gauge(player_idx)
    if not _td_gBattle then return nil end
    local ok, v = pcall(function()
        local team = _td_gBattle:get_field("Team"):get_data(nil)
        if not team or not team.mcTeam then return nil end
        local t = team.mcTeam[player_idx]
        return t and t.mSuperGauge
    end)
    if not ok or v == nil then return nil end
    return tonumber(tostring(v))
end

-- The single-site, author-hedged read. Returns nil when it cannot be resolved
-- at all, which is different from 0 and the tracker below cares about that.
function M.combo_damage_raw(p)
    if not p then return nil end
    local ok, v = pcall(function()
        local t = p.mpTeam
        return t and t.mComboDamage
    end)
    if not ok or v == nil then return nil end
    return tonumber(tostring(v))
end

-- --- damage tracker ----------------------------------------------------------

local Tracker = {}
Tracker.__index = Tracker

-- attacker_idx: 0 for P1, 1 for P2. Call begin() once the stage has settled and
-- BEFORE the first input, then tick() every claimed frame.
function M.new_damage_tracker()
    return setmetatable({}, Tracker):begin(nil, nil)
end

function Tracker:begin(attacker, victim)
    self.peak = 0
    self.banked = 0
    self.field_resolved = false   -- did mComboDamage ever read non-nil?
    self.field_nonzero = false    -- did it ever read > 0?
    self.hp_base = victim and M.hp(victim) or nil
    self.hp_min = self.hp_base
    self.ticks = 0
    return self
end

function Tracker:tick(attacker, victim)
    self.ticks = self.ticks + 1

    -- Upstream takes max(attacker, victim) because it did not know which side
    -- carries the value. Keep that until spike A settles it, and record which
    -- side answered so the spike has something to conclude from.
    local a = M.combo_damage_raw(attacker)
    local v = M.combo_damage_raw(victim)
    if a ~= nil or v ~= nil then
        self.field_resolved = true
        if a ~= nil and (self.side_a == nil or a > 0) then self.side_a = a end
        if v ~= nil and (self.side_v == nil or v > 0) then self.side_v = v end
        local cur = math.max(a or 0, v or 0)
        if cur > 0 then self.field_nonzero = true end
        if cur > self.peak then
            self.peak = cur
        elseif cur == 0 and self.peak > 0 then
            -- Segment ended: bank its peak. This is what makes the number
            -- cumulative; the field itself is not.
            self.banked = self.banked + self.peak
            self.peak = 0
        end
    end

    local hp = M.hp(victim)
    if hp ~= nil then
        if self.hp_base == nil then self.hp_base = hp end
        if self.hp_min == nil or hp < self.hp_min then self.hp_min = hp end
    end
end

-- Both measurements, plus whether they agree. `agree` is nil when there is
-- nothing to compare (the field never resolved).
function Tracker:result()
    local combo_damage = self.banked + self.peak
    local hp_delta = nil
    if self.hp_base ~= nil and self.hp_min ~= nil then
        hp_delta = math.max(0, self.hp_base - self.hp_min)
    end

    local agree = nil
    if self.field_nonzero and hp_delta ~= nil then
        -- HP delta is capped at lethal while mComboDamage is not, so they
        -- legitimately diverge on a killing blow. Only flag a disagreement
        -- when the victim did not bottom out.
        if self.hp_min ~= nil and self.hp_min <= 0 then
            agree = nil
        else
            agree = math.abs(combo_damage - hp_delta) <= 1
        end
    end

    return {
        combo_damage   = combo_damage,
        hp_delta       = hp_delta,
        agree          = agree,
        field_resolved = self.field_resolved,
        field_nonzero  = self.field_nonzero,
        attacker_side_value = self.side_a,
        victim_side_value   = self.side_v,
        ticks          = self.ticks,
    }
end

M.Tracker = Tracker

return M
