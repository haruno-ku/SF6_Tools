-- =========================================================
-- ComboExplorer/core/LinkVerdict.lua - decides whether move A linked into
-- move B from one trial's observations. Pure: takes snapshots, returns a
-- verdict.
-- =========================================================
--
-- WHY NOT "combo_cnt WENT 1 -> 2"
--
-- Because plenty of moves hit more than once. Zangief's 2HP, target-combo
-- pieces, OD specials and every super put the counter above one on their own,
-- so a fixed 1 -> 2 test reports a successful link as a failure and, worse,
-- reports some failures as successes. The question is not what the counter
-- reads, it is whether B'S ACTION caused it to go up.
--
-- ATTRIBUTION IS THE WHOLE PROBLEM
--
-- The counter is shared. If A is still connecting when the trial looks at it,
-- a rise proves nothing about B. So the rise is only counted from the tick
-- where B's action id is actually observed - by then A's action has ended,
-- since a character is in exactly one action at a time.
--
-- That leaves projectiles, where A can still be hitting from across the screen
-- while B comes out. They are out of scope for the first sweep for exactly this
-- reason, and a trial whose observations look like that is reported as
-- inconclusive rather than guessed at.
--
-- ACTIONS COMMIT LATE
--
-- Upstream runs a four-frame debounce before it believes an action id
-- (ghost_filter_frames), because a real action can be superseded within a few
-- frames by the one the player actually meant. So "B's action id first seen"
-- is not the same tick as "B was injected", and the trial records both.

local M = { name = "ComboExplorer.LinkVerdict" }

M.VERDICT = {
    LINK        = "link",         -- B's action raised the counter, combo unbroken
    BLOCKED     = "blocked",      -- B connected, but the victim guarded it
    WHIFF       = "whiff",        -- B came out and touched nothing
    WRONG_MOVE  = "wrong_move",   -- something other than B came out
    A_FAILED    = "a_failed",     -- A never hit, so B was never a fair test
    COMBO_BROKE = "combo_broke",  -- the counter reset between A and B
    INCONCLUSIVE = "inconclusive",
}

local Trial = {}
Trial.__index = Trial
M.Trial = Trial

local function id_set(list)
    local s = {}
    for _, v in ipairs(list or {}) do s[v] = true end
    return s
end

-- spec:
--   expected_a, expected_b : lists of acceptable action ids for each move.
--                            Lists, not single ids, because which id an input
--                            produces is itself unverified - the catalog groups
--                            617/618/619 rather than choosing.
--   grace_ticks            : ticks after a reset during which the counter is
--                            not believed (upstream's _reset_grace is 15).
function M.new(spec)
    spec = spec or {}
    local t = setmetatable({}, Trial)
    t.expected_a = id_set(spec.expected_a)
    t.expected_b = id_set(spec.expected_b)
    t.grace_ticks = spec.grace_ticks or 0
    t:reset()
    return t
end

function Trial:reset()
    self.ticks = 0
    self.observations = 0

    self.a_injected_tick = nil
    self.b_injected_tick = nil

    self.a_action_id = nil
    self.a_first_tick = nil
    self.b_action_id = nil
    self.b_first_tick = nil

    -- Every action id seen, in order. A wrong-move verdict has to be able to
    -- say what came out instead.
    self.actions_seen = {}
    self.last_action_id = nil

    self.combo_peak_a = 0
    self.combo_before_b = nil
    self.combo_peak_b = 0
    self.combo_dropped_after_a = false
    self.a_hit = false

    self.guard_before_b = nil
    self.guard_peak_b = 0
    self.guard_rose_before_b = false

    self.hitstop_ticks = 0
    self.unresolved_ticks = 0
end

-- Called when the injector has written the last tick of A's (or B's) input.
-- Recorded for the report; attribution does not depend on it, because an action
-- commits several ticks after the button is pressed.
function Trial:mark_injected(which, tick)
    if which == "a" then self.a_injected_tick = tick
    elseif which == "b" then self.b_injected_tick = tick end
end

function Trial:tick(snap, tick_index)
    if type(snap) ~= "table" then
        self.unresolved_ticks = self.unresolved_ticks + 1
        return
    end
    self.ticks = self.ticks + 1

    local combo = snap.combo_count
    local guard = snap.guard_count
    if combo == nil then
        self.unresolved_ticks = self.unresolved_ticks + 1
        return
    end
    self.observations = self.observations + 1

    if (snap.attacker_hitstop or 0) > 0 then
        self.hitstop_ticks = self.hitstop_ticks + 1
    end

    -- Within the post-reset grace the counter can still be reading the previous
    -- trial. Believing it there is how phantom links get recorded.
    local believable = (self.grace_ticks == 0) or (self.ticks > self.grace_ticks)

    local aid = snap.attacker_action_id
    if aid ~= nil and aid ~= self.last_action_id then
        self.actions_seen[#self.actions_seen + 1] = { tick = tick_index, action_id = aid }
        self.last_action_id = aid

        if self.a_first_tick == nil and self.expected_a[aid] then
            self.a_action_id = aid
            self.a_first_tick = tick_index
        elseif self.a_first_tick ~= nil and self.b_first_tick == nil and self.expected_b[aid] then
            self.b_action_id = aid
            self.b_first_tick = tick_index
            -- The counter as it stood the instant before B's action began.
            -- Everything after this is attributable to B.
            self.combo_before_b = self.combo_peak_a
            self.guard_before_b = self.guard_peak_before_b or guard or 0
        end
    end

    if not believable then return end

    if self.b_first_tick == nil then
        -- Still in A's half of the trial.
        if combo > self.combo_peak_a then self.combo_peak_a = combo end
        if combo > 0 then self.a_hit = true end
        if self.a_hit and combo == 0 then self.combo_dropped_after_a = true end
        if guard ~= nil then
            self.guard_peak_before_b = math.max(self.guard_peak_before_b or 0, guard)
        end
    else
        if combo > self.combo_peak_b then self.combo_peak_b = combo end
        if guard ~= nil and guard > self.guard_peak_b then self.guard_peak_b = guard end
    end
end

-- The verdict, plus everything needed to argue with it.
function Trial:result()
    local r = {
        a_hit = self.a_hit,
        a_action_id = self.a_action_id,
        a_first_tick = self.a_first_tick,
        a_injected_tick = self.a_injected_tick,
        b_action_id = self.b_action_id,
        b_first_tick = self.b_first_tick,
        b_injected_tick = self.b_injected_tick,
        combo_peak_a = self.combo_peak_a,
        combo_before_b = self.combo_before_b,
        combo_peak_b = self.combo_peak_b,
        guard_before_b = self.guard_before_b,
        guard_peak_b = self.guard_peak_b,
        hitstop_ticks = self.hitstop_ticks,
        unresolved_ticks = self.unresolved_ticks,
        observations = self.observations,
        actions_seen = self.actions_seen,
    }

    -- Latency, in ticks, between pressing and the action appearing. Collected
    -- on every trial because it is the same quantity calibration needs and
    -- costs nothing to record.
    if self.a_first_tick and self.a_injected_tick then
        r.a_latency_ticks = self.a_first_tick - self.a_injected_tick
    end
    if self.b_first_tick and self.b_injected_tick then
        r.b_latency_ticks = self.b_first_tick - self.b_injected_tick
    end

    if self.observations == 0 then
        r.verdict = M.VERDICT.INCONCLUSIVE
        r.reason = "nothing was observed"
        return r
    end

    if not self.a_hit then
        r.verdict = M.VERDICT.A_FAILED
        r.reason = self.a_first_tick
            and "move A came out but never hit"
            or "move A never came out"
        return r
    end

    if self.b_first_tick == nil then
        r.verdict = M.VERDICT.WRONG_MOVE
        -- Name what did come out instead; a bare "wrong move" is not
        -- actionable, and an unexpected action id is itself a finding.
        local after = {}
        for _, a in ipairs(self.actions_seen) do
            if self.a_first_tick and a.tick > self.a_first_tick then
                after[#after + 1] = a.action_id
            end
        end
        r.unexpected_action_ids = after
        r.reason = (#after > 0)
            and ("move B never appeared; saw action id(s) " .. table.concat(after, ", ") .. " instead")
            or "move B never appeared and no other action followed A"
        return r
    end

    if self.combo_dropped_after_a then
        r.verdict = M.VERDICT.COMBO_BROKE
        r.reason = "the combo counter reset between A and B, so B started a new combo"
        return r
    end

    -- The actual test: did B's action raise the counter?
    local before = self.combo_before_b or 0
    local hits_added = self.combo_peak_b - before
    r.hits_added = hits_added

    if hits_added > 0 then
        r.verdict = M.VERDICT.LINK
        r.reason = ("B raised the counter from %d to %d"):format(before, self.combo_peak_b)
        return r
    end

    local guard_rise = (self.guard_peak_b or 0) - (self.guard_before_b or 0)
    r.guard_rise = guard_rise
    if guard_rise > 0 then
        r.verdict = M.VERDICT.BLOCKED
        r.reason = "B was guarded rather than linked"
        return r
    end

    r.verdict = M.VERDICT.WHIFF
    r.reason = "B came out and touched nothing"
    return r
end

-- --- aggregating repeats -----------------------------------------------------

-- Several attempts at one (pair, delay). The distinction that matters is
-- between a link that reproduces and one that happened once.
function M.aggregate(results)
    local n = { total = 0, link = 0, blocked = 0, whiff = 0, wrong_move = 0,
                a_failed = 0, combo_broke = 0, inconclusive = 0 }
    local hits_added, latencies = nil, {}

    for _, r in ipairs(results or {}) do
        n.total = n.total + 1
        n[r.verdict] = (n[r.verdict] or 0) + 1
        if r.verdict == M.VERDICT.LINK then
            if hits_added == nil then hits_added = r.hits_added
            elseif hits_added ~= r.hits_added then hits_added = "varies" end
        end
        if r.b_latency_ticks then latencies[#latencies + 1] = r.b_latency_ticks end
    end

    local verdict, reason
    if n.total == 0 then
        verdict, reason = M.VERDICT.INCONCLUSIVE, "no attempts"
    elseif n.link == n.total then
        verdict, reason = M.VERDICT.LINK, ("linked on all %d attempts"):format(n.total)
    elseif n.link > 0 then
        verdict = M.VERDICT.LINK
        reason = ("linked on %d of %d attempts - unstable"):format(n.link, n.total)
    elseif n.a_failed == n.total then
        verdict, reason = M.VERDICT.A_FAILED, "move A never hit on any attempt"
    else
        -- The most common non-link outcome, so the report says something
        -- specific rather than just "no".
        local top, top_n = M.VERDICT.INCONCLUSIVE, 0
        for k, v in pairs(n) do
            if k ~= "total" and v > top_n then top, top_n = k, v end
        end
        verdict = top
        reason = ("%d of %d attempts: %s"):format(top_n, n.total, top)
    end

    return {
        verdict = verdict,
        reason = reason,
        stable = (n.total > 0 and n.link == n.total),
        counts = n,
        hits_added = hits_added,
        b_latency_ticks = latencies,
    }
end

return M
