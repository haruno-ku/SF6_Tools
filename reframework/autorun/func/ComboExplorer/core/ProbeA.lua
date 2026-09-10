-- =========================================================
-- ComboExplorer/core/ProbeA.lua - segments a stream of per-tick snapshots into
-- combos and measures each one. Pure: takes tables of numbers.
-- =========================================================
--
-- WHAT PROBE A IS FOR
--
-- One question: can cPlayer.mpTeam.mComboDamage be trusted on this build? It is
-- read at exactly one site in all of upstream, inside a pcall, and its author
-- wrote an HP-delta fallback for the case where it reads zero. If it silently
-- reads zero and the Explorer believes it, every edge in the graph records
-- damage 0 and the whole ranking phase sorts by a constant, looking healthy.
--
-- THE BASELINE PROBLEM
--
-- The obvious implementation starts measuring when the combo counter goes
-- above zero. By then the first hit has already landed and its damage has
-- already come off the victim's health - so the HP delta is short by one hit
-- while mComboDamage is not, and the two disagree on every single sample. The
-- probe would then report "mComboDamage is untrustworthy" when the only thing
-- wrong was where the tape measure was held. Upstream snapshots victim HP
-- before the combo starts; so does this.
--
-- THE HITSTOP PROBLEM
--
-- Deciding a combo has ended by counting idle ticks assumes ticks pass at a
-- steady rate. Whether they advance at all during hitstop is item 3 on the
-- unverified list. So idle ticks are only counted while hitstop is zero, and
-- how many were needed is recorded on the sample - which lets the threshold be
-- re-derived from the data instead of being guessed up front.

local DamageTracker = require("func/ComboExplorer/core/DamageTracker")

local M = { name = "ComboExplorer.ProbeA" }

local Probe = {}
Probe.__index = Probe
M.Probe = Probe

-- idle_ticks_to_close is provisional and lives on the instance so a report can
-- state what it used. It is not a measured constant, and the per-sample
-- idle_ticks_at_close field exists so a different value can be tried against
-- already-collected data.
M.DEFAULT_IDLE_TICKS = 20

function M.new(opts)
    opts = opts or {}
    local p = setmetatable({}, Probe)
    p.idle_ticks_to_close = opts.idle_ticks_to_close or M.DEFAULT_IDLE_TICKS
    p.max_transitions = opts.max_transitions or 64
    p:reset()
    return p
end

function Probe:reset()
    self.samples = {}
    self.in_combo = false
    self.tracker = nil
    self.idle_ticks = 0
    self.hitstop_ticks = 0
    self.ticks = 0
    self.skipped_ticks = 0

    -- The last health seen while NOT in a combo. This is the baseline the next
    -- combo will be measured from, captured before its first hit lands.
    self.pre_combo_hp = nil
    self.last_victim_hp = nil

    self.last_action_id = nil
    self.transitions = nil
    self.open_sample = nil
end

-- Feeds one snapshot. Returns the finished sample when this tick closed a
-- combo, otherwise nil.
--
-- A nil snapshot means the players could not be resolved this tick (a round
-- transition, a menu). Those ticks are counted and skipped rather than treated
-- as an idle tick, so a scene change cannot silently close a combo that is
-- still running.
function Probe:tick(snap, tick_index)
    if type(snap) ~= "table" then
        self.skipped_ticks = self.skipped_ticks + 1
        return nil
    end
    self.ticks = self.ticks + 1

    local hits = snap.combo_count
    if hits == nil then
        self.skipped_ticks = self.skipped_ticks + 1
        return nil
    end

    local in_hitstop = (snap.attacker_hitstop or 0) > 0
    if in_hitstop then self.hitstop_ticks = self.hitstop_ticks + 1 end

    -- Tracked on every tick, in or out of a combo, because it becomes the
    -- baseline for the NEXT combo the moment this one closes. Without it the
    -- second combo in a session is measured from health that predates the
    -- first, and its delta comes out as the sum of both.
    if snap.victim_hp ~= nil then self.last_victim_hp = snap.victim_hp end

    -- Action transitions are recorded whether or not a combo is running: the
    -- ids seen while landing combos are exactly the evidence the canonical /
    -- variant question needs (601 vs 602, 617/618/619), and collecting them
    -- costs one comparison per tick.
    local aid = snap.attacker_action_id
    if aid ~= nil and aid ~= self.last_action_id then
        if self.transitions and #self.transitions < self.max_transitions then
            self.transitions[#self.transitions + 1] = {
                tick = tick_index,
                action_id = aid,
                action_frame = snap.attacker_action_frame,
                combo_count = hits,
            }
        end
        self.last_action_id = aid
    end

    if not self.in_combo then
        -- ORDER MATTERS. On the tick where the counter first goes above zero,
        -- the first hit has already landed and its damage is already off the
        -- victim's health. Refreshing the baseline before checking for that
        -- would overwrite the pre-combo value with a post-first-hit one, and
        -- every sample would then be short by exactly one hit - which reads as
        -- "mComboDamage disagrees with HP" on every single combo.
        if hits > 0 then
            self.in_combo = true
            self.idle_ticks = 0
            self.hitstop_ticks = in_hitstop and 1 or 0
            self.transitions = {}
            if aid ~= nil then
                self.transitions[1] = { tick = tick_index, action_id = aid,
                                        action_frame = snap.attacker_action_frame,
                                        combo_count = hits }
            end

            self.tracker = DamageTracker.new()
            -- Seed with the pre-combo health so the delta spans the first hit.
            self.tracker:begin({ victim_hp = self.pre_combo_hp })

            self.open_sample = {
                start_tick = tick_index,
                victim_hp_at_start = self.pre_combo_hp,
                victim_hp_max = snap.victim_hp_max,
                attacker_rl_dir_raw = snap.attacker_rl_dir_raw,
                attacker_rl_dir_type = snap.attacker_rl_dir_type,
                attacker_pos_at_start = snap.attacker_pos,
                victim_pos_at_start = snap.victim_pos,
                counter_hit = snap.counter_hit,
                punish_counter = snap.punish_counter,
            }
        else
            -- Idle: this is the value the next combo will be measured from.
            if snap.victim_hp ~= nil then self.pre_combo_hp = snap.victim_hp end
            return nil
        end
    end

    self.tracker:tick(snap)

    if hits == 0 then
        -- Only count idleness while the game is actually running. During
        -- hitstop nothing is happening, and if ticks stall there too, counting
        -- them would either merge two combos or split one.
        if not in_hitstop then self.idle_ticks = self.idle_ticks + 1 end
    else
        self.idle_ticks = 0
    end

    if self.idle_ticks >= self.idle_ticks_to_close then
        return self:close(tick_index)
    end
    return nil
end

function Probe:close(tick_index)
    if not self.in_combo then return nil end

    local s = self.tracker:result()
    local open = self.open_sample or {}
    for k, v in pairs(open) do s[k] = v end
    s.end_tick = tick_index
    s.idle_ticks_at_close = self.idle_ticks
    s.idle_ticks_threshold = self.idle_ticks_to_close
    s.hitstop_ticks = self.hitstop_ticks
    s.action_transitions = self.transitions or {}

    self.samples[#self.samples + 1] = s

    self.in_combo = false
    self.tracker = nil
    self.idle_ticks = 0
    self.hitstop_ticks = 0
    self.transitions = nil
    self.open_sample = nil

    -- The health the combo ended on is where the next one starts.
    if self.last_victim_hp ~= nil then self.pre_combo_hp = self.last_victim_hp end
    return s
end

-- Ends an in-flight combo without a full idle window. Used when the operator
-- stops the probe: without it the last combo is silently discarded, which is
-- the one most likely to be the interesting one.
function Probe:flush(tick_index)
    if not self.in_combo then return nil end
    local s = self:close(tick_index)
    if s then s.closed_by = "flush" end
    return s
end

-- Every distinct action id seen, with how often each was the newly-entered
-- action. Direct input to the canonical/variant question: an id that never
-- appears cannot be what an input produces.
function Probe:action_id_histogram()
    local counts = {}
    for _, s in ipairs(self.samples) do
        for _, tr in ipairs(s.action_transitions or {}) do
            counts[tr.action_id] = (counts[tr.action_id] or 0) + 1
        end
    end
    local rows = {}
    for id, n in pairs(counts) do rows[#rows + 1] = { action_id = id, entries = n } end
    table.sort(rows, function(a, b)
        if a.entries ~= b.entries then return a.entries > b.entries end
        return a.action_id < b.action_id
    end)
    return rows
end

-- The report probe A exists to produce. The damage conclusion comes from
-- DamageTracker.conclude, which is where the sample-count and scale-factor
-- rules live; everything else here is context so the file can be attributed.
function Probe:report(opts)
    local conclusion = DamageTracker.conclude(self.samples, opts)
    return {
        probe = "A.damage_readability",
        verdict = conclusion.verdict,
        recommended_source = conclusion.recommended_source,
        carrying_side = conclusion.carrying_side,
        scale_factor = conclusion.scale_factor,
        sufficient = conclusion.sufficient,
        counts = conclusion.counts,
        idle_ticks_to_close = self.idle_ticks_to_close,
        ticks_observed = self.ticks,
        ticks_skipped = self.skipped_ticks,
        action_id_histogram = self:action_id_histogram(),
        samples = self.samples,
    }
end

return M
