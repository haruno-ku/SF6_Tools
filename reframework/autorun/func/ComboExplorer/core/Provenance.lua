-- =========================================================
-- ComboExplorer/core/Provenance.lua - the register of things we do not know yet.
-- Pure data + pure logic. No sdk, no re, no imgui, no json.
-- =========================================================
--
-- WHY THIS MODULE EXISTS
--
-- Nine values decide whether this project produces data or garbage, and not one
-- of them can be settled by reading source. They can only be measured on a
-- machine running Street Fighter 6, which we do not have yet.
--
-- The tempting move is to pick the most likely value for each and carry on.
-- That fails in the worst possible way: the Explorer would run, produce
-- thousands of rows, and every row would be quietly wrong. A brute-forcer that
-- presses a button that does not exist records "these moves do not link" - a
-- confident negative, indistinguishable from a real one, with no error anywhere.
--
-- So unknown values live here instead of being spelled into the code that uses
-- them. Each carries its provisional value, where that guess came from, what it
-- gates, and a status. Nothing reads one by accident: Provenance.value()
-- returns nil until the entry is verified, and code that deliberately wants the
-- guess has to say so by calling provisional().
--
-- Calibration on the real machine writes a profile; apply_calibration() folds it
-- in and flips entries to verified. Until then, capability("injection") is false
-- and the Injector refuses to start - the safety is structural, not a note in a
-- README that someone has to remember.

local M = { name = "ComboExplorer.Provenance" }

M.STATUS = {
    UNVERIFIED = "unverified",  -- provisional value, never measured here
    VERIFIED   = "verified",    -- measured on the real game, and the guess held
    REFUTED    = "refuted",     -- measured, and the guess was wrong; value replaced
    -- Measured as far as it went. Part of the value was confirmed and part of
    -- it was never witnessed, so neither of the two above is true of it.
    --
    -- Not a corner case. A button map derived from a catalog can never contain
    -- AUTO or PARRY - no shipped character has a single-button notation for
    -- either, so nothing can witness which bit they are - and the sweep
    -- deliberately leaves them out rather than guessing. Under a two-value
    -- vocabulary that came out REFUTED, which says the guess was wrong when it
    -- was not, and made a flawless sweep indistinguishable from one that got
    -- two buttons backwards. Calling it VERIFIED would have been the other lie:
    -- that the missing bits were measured.
    PARTIAL    = "partial",
}

-- VERIFIED and REFUTED are both measurements. The only difference between them
-- is whether the guess survived, and that is a fact about the guess rather than
-- about the value now stored - which was measured either way.
--
-- Treating refuted as still-unknown looks careful and is not. The first real
-- dataset refuted two entries: hitstop_advances_tick (guessed false, the tick
-- does advance, 475 hitstop frames) and reset_settle_ticks (guessed 25,
-- measured 9 over 11 resets). Under the stricter reading, TIMING and
-- STAGE_RESET would each have stayed shut because the measurement gating them
-- disagreed with a guess nobody had ever checked - the project blocked by being
-- right.
local function is_measured(status)
    return status == M.STATUS.VERIFIED
        or status == M.STATUS.REFUTED
        or status == M.STATUS.PARTIAL
end

-- How much is known, as a number, so "the worst of these" is a comparison
-- rather than whichever happened to be last in a loop.
M.STATUS_RANK = {
    [M.STATUS.UNVERIFIED] = 0,
    [M.STATUS.REFUTED]    = 1,
    [M.STATUS.PARTIAL]    = 2,
    [M.STATUS.VERIFIED]   = 3,
}

-- Refuted ranks BELOW partial on purpose. Both are measurements, but a refuted
-- entry means the value in hand replaced a guess that was wrong, so anything
-- built on the old reasoning has to be re-examined; a partial one means what is
-- there was confirmed. Neither is a reason to refuse to act - see is_measured -
-- and the rank exists only to answer "which of these is least settled".
function M.rank(status)
    return M.STATUS_RANK[status]
end

-- Exposed because a caller asking "has anyone looked at this" is asking about
-- both, and is_verified() answers a narrower question: did the guess hold.
function M.is_measured(reg, key)
    local e = reg.entries[key]
    return e ~= nil and is_measured(e.status)
end

-- Capabilities are what entries gate. A capability is available only when every
-- entry that gates it - directly or through another capability it requires - is
-- verified.
--
-- INJECTION and PROBING are deliberately separate. Pressing a button and seeing
-- the right move come out needs only the button map; it does not need to know
-- how many ticks there are in a frame. Running a timed A->B trial does. Keeping
-- them apart is what lets the smoke test run the moment the button map is
-- measured, instead of waiting for every other unknown as well.
M.CAPABILITY = {
    TIMING      = "timing",       -- can a delay be expressed in a known unit?
    INJECTION   = "injection",    -- can we press a button and mean it?
    DAMAGE      = "damage",       -- can a damage number be trusted?
    CATALOG     = "catalog",      -- is the action-id catalog pinned to reality?
    STAGE_RESET = "stage_reset",  -- is a reset reproducible?
    FRAME_DATA  = "frame_data",   -- are measured frame values meaningful?
    PROBING     = "probing",      -- can a timed A->B trial produce real data?
}

local C = M.CAPABILITY

-- Composite capabilities. A brute-force probe is only meaningful when it can
-- press the right button, at a known delay, from a reproducible starting state.
M.REQUIRES = {
    [C.PROBING] = { C.INJECTION, C.TIMING, C.STAGE_RESET },
}

-- --- the register ------------------------------------------------------------
--
-- `value` is the PROVISIONAL value while status is unverified. It exists so the
-- read-only diagnostics can show something and so tests have a shape to work
-- with - never so that production logic can quietly consume it.

local function entry(t) return t end

M.DEFAULTS = {
    input_hook_calls_per_frame = entry {
        value = 1,
        status = M.STATUS.UNVERIFIED,
        gates = { C.TIMING },
        question = "How many times does nBattle.cPlayer::pl_input_sub fire per battle frame, per player?",
        provisional_source = "Inferred, not observed: upstream added a once-per-frame latch reset from a "
            .. "separate hook on app.BattleFlow::UpdateFrameMain (TrainingComboTrials_v1.0.lua:6731-6740), "
            .. "which only makes sense if raw call counts are not frame counts.",
        if_wrong = "Every recorded delay is off by the multiplier. At 2 calls/frame the whole first "
            .. "dataset is silently half the delay it claims.",
        measured_by = "probe_b_clock",
    },

    tick_equals_frame = entry {
        value = nil,
        status = M.STATUS.UNVERIFIED,
        gates = { C.TIMING, C.FRAME_DATA },
        question = "Is one Explorer tick one game frame, and if not, what is the mapping?",
        provisional_source = "No basis for a guess. Upstream keeps two clocks (engine_frame_count from "
            .. "re.on_frame, and the input-hook tick) and reconciles them only for piyo/burnout combos.",
        if_wrong = "Delays have no unit. Recorded link windows cannot be compared against any external "
            .. "frame data, and difficulty is computed in the wrong currency.",
        measured_by = "probe_b_clock",
    },

    hitstop_advances_tick = entry {
        value = false,
        status = M.STATUS.UNVERIFIED,
        gates = { C.TIMING },
        question = "Does the input-hook tick advance during hitstop?",
        provisional_source = "Upstream comment: hitstop frames are 'missed between engine ticks' "
            .. "(TrainingComboTrials_v1.0.lua:2041-2042), and HANDOVER_cdjay.md 2.2 says the hook simply "
            .. "does not fire during hitstop.",
        if_wrong = "Hitstop sits between move A and move B in every link test, so every window shifts.",
        measured_by = "probe_b_clock",
    },

    combo_damage_readable = entry {
        value = nil,
        status = M.STATUS.UNVERIFIED,
        gates = { C.DAMAGE },
        question = "Does cPlayer.mpTeam.mComboDamage resolve and read non-zero, and on which side?",
        provisional_source = "Read at exactly one site in all of upstream, inside a pcall, with an "
            .. "HP-delta fallback its author wrote because it may read zero "
            .. "(TrainingComboTrials_v1.0.lua:4226, :6126-6134).",
        if_wrong = "Every edge records damage 0 and the scoring phase ranks combos by a constant.",
        measured_by = "probe_a_damage",
    },

    modern_button_bits = entry {
        value = { L = 0x10, M = 0x80, H = 0x100, SP = 0x20, AUTO = 0x200,
                  PARRY = 0x40, DI = 0x1000, THROW = 0x2000 },
        status = M.STATUS.UNVERIFIED,
        gates = { C.INJECTION },
        question = "Which pl_input_new bit does each Modern button occupy?",
        provisional_source = "ComboTrials_D2D.lua:299-321, whose comment says 'probed in-game' - but that "
            .. "table is only ever READ, never used to inject. Corroborated by routes[].raw_button_mask in "
            .. "command_display (L=16, M=128, H=256, SP=32, THROW=144), which is agreement, not proof. "
            .. "DI (576) and AUTO+SP (8192) do NOT agree between the two sources.",
        if_wrong = "The Explorer presses buttons that do not exist. Every trial whiffs and is recorded as "
            .. "'these moves do not link' - a confident negative with no error.",
        measured_by = "calibration_button_bits",
    },

    direction_bits = entry {
        value = { UP = 1, DOWN = 2, LEFT = 4, RIGHT = 8 },
        status = M.STATUS.UNVERIFIED,
        gates = { C.INJECTION },
        question = "Which pl_input_new bit is which direction?",
        provisional_source = "Two independent readers agree: ComboTrials_D2D.lua:288-297 decodes left=4 / "
            .. "right=8, and SF6_RecordingSlotManager.lua:106-110 maps numpad 4->4 and 6->8. RSM's own "
            .. "MASKS table (:450) has them reversed, but that drives record-slot timelines, a different "
            .. "buffer. Higher confidence than the button bits, still not measured here.",
        if_wrong = "Left and right are swapped. Direction-sensitive normals and every motion break.",
        measured_by = "calibration_button_bits",
    },

    rl_dir_polarity = entry {
        value = "mirror_when_falsy",
        status = M.STATUS.UNVERIFIED,
        gates = { C.INJECTION },
        question = "Which truth value of cPlayer.rl_dir means the direction bits must be mirrored?",
        provisional_source = "Three P1 writers mirror when rl_dir is FALSY (RSM:1993, "
            .. "TrainingMoveExecution:299, TrainingComboTrials:6843); SharedHooks.write_p2_input_mask "
            .. "(:179-186) mirrors on TRUTHY, but that is the P2 path. Majority, not proof.",
        if_wrong = "Forward and back invert on one side only, so half the dataset is mirrored and the "
            .. "other half is not - which looks like flaky links rather than a bug.",
        measured_by = "calibration_button_bits",
    },

    action_id_canonical = entry {
        value = nil,
        status = M.STATUS.UNVERIFIED,
        gates = { C.CATALOG },
        question = "When several action ids share one notation (601/602, 617/618/619, 605/606, 679/680), "
            .. "which one does the input actually produce?",
        provisional_source = "Nothing in command_display explains the difference; there is no field for "
            .. "it and _meta says nothing.",
        if_wrong = "Either the probe matrix inflates threefold, or two genuinely different moves get "
            .. "recorded as one.",
        measured_by = "calibration_action_sweep",
    },

    reset_settle_ticks = entry {
        value = 25,
        status = M.STATUS.UNVERIFIED,
        gates = { C.STAGE_RESET },
        question = "How many ticks after a reset request is the stage genuinely reproducible?",
        provisional_source = "Sum of upstream's own numbers: 10 position-correction retries "
            .. "(pending_exact_pos) plus a 15-frame combo-counter grace (_reset_grace). The refresh "
            .. "itself is unbounded - upstream polls for it rather than predicting it.",
        if_wrong = "Trials start before the stage settles: phantom links from a stale counter, and false "
            .. "negatives from spacing that had not converged.",
        measured_by = "calibration_reset_cost",
    },

    frame_meter_semantics = entry {
        value = { STARTUP = 7, RECOVERY = 8, HITSTUN = 9, BLOCKSTUN = 10 },
        status = M.STATUS.UNVERIFIED,
        gates = { C.FRAME_DATA },
        question = "What do FrameNumDatas FrameType values mean, and does StunFrame match a directly "
            .. "measured actionable-frame difference?",
        provisional_source = "Inferred from how TrainingHitConfirm_v1.0.lua:502-560 uses the ring buffer. "
            .. "No upstream comment states the enum.",
        if_wrong = "Measured startup and frame advantage are wrong, and so is every delay window derived "
            .. "from them.",
        measured_by = "calibration_frame_meter",
    },
}

-- --- live state --------------------------------------------------------------

local function deep_copy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, val in pairs(v) do out[k] = deep_copy(val) end
    return out
end
M.deep_copy = deep_copy

-- A fresh register. Tests build their own rather than mutating a shared one.
function M.new()
    local reg = {
        entries = {},
        calibration_id = nil,
        game_patch = nil,
    }
    for k, v in pairs(M.DEFAULTS) do
        reg.entries[k] = deep_copy(v)
        reg.entries[k].key = k
    end
    return setmetatable(reg, { __index = M })
end

function M.get(reg, key)
    return reg.entries[key]
end

-- The MEASURED value, or nil. Deliberately withholds the provisional value:
-- code that has not thought about the unverified case gets nil and fails loudly
-- rather than running on a guess.
--
-- Refuted counts. See is_measured above: the value behind a refuted entry is
-- the one that came off the machine, and withholding it would mean the only
-- values this function ever hands out are the ones that happened to match a
-- guess.
function M.value(reg, key)
    local e = reg.entries[key]
    if not e then return nil, "unknown key: " .. tostring(key) end
    if not is_measured(e.status) then
        return nil, e.status
    end
    return deep_copy(e.value)
end

-- The guess, with its status attached, for callers that legitimately want it:
-- the diagnostics readout, and tests. The second return value is there so a
-- caller cannot use this without the status passing through its hands.
function M.provisional(reg, key)
    local e = reg.entries[key]
    if not e then return nil, "unknown key: " .. tostring(key) end
    return deep_copy(e.value), e.status
end

function M.is_verified(reg, key)
    local e = reg.entries[key]
    return e ~= nil and e.status == M.STATUS.VERIFIED
end

-- --- capabilities ------------------------------------------------------------

local function gates_capability(e, capability)
    for _, g in ipairs(e.gates or {}) do
        if g == capability then return true end
    end
    return false
end

-- Every entry gating this capability that is not yet verified, following
-- required capabilities transitively so a composite reports the underlying
-- values rather than the name of another capability.
function M.blockers(reg, capability, _seen)
    _seen = _seen or {}
    if _seen[capability] then return {} end
    _seen[capability] = true

    local found = {}
    for key, e in pairs(reg.entries) do
        if gates_capability(e, capability) and not is_measured(e.status) then
            found[key] = true
        end
    end
    for _, required in ipairs(M.REQUIRES[capability] or {}) do
        for _, key in ipairs(M.blockers(reg, required, _seen)) do
            found[key] = true
        end
    end

    local out = {}
    for key in pairs(found) do out[#out + 1] = key end
    table.sort(out)
    return out
end

-- The gate the Injector asks before it will start.
function M.can(reg, capability)
    local blocked = M.blockers(reg, capability)
    if #blocked == 0 then return true, {} end
    return false, blocked
end

-- Human-readable refusal, for the panel and for logs. Says what is missing and
-- how to obtain it, because the person reading it is usually about to go and
-- run the thing that would fix it.
function M.explain(reg, capability)
    local ok, blocked = M.can(reg, capability)
    if ok then
        return ("%s: available (all gating values verified)"):format(capability)
    end
    local parts = {}
    for _, key in ipairs(blocked) do
        local e = reg.entries[key]
        parts[#parts + 1] = ("  %s [%s] - measured by: %s"):format(key, e.status, tostring(e.measured_by))
    end
    return ("%s: BLOCKED by %d unverified value(s)\n%s")
        :format(capability, #blocked, table.concat(parts, "\n"))
end

-- --- calibration -------------------------------------------------------------

-- Folds a calibration result into the register. `profile` is the parsed contents
-- of a calibration JSON:
--
--   { calibration_id = "...", game_patch = "2026-08-03",
--     values = { modern_button_bits = { status = "verified", value = {...} }, ... } }
--
-- Returns the applied keys and a list of rejections, so a partial or malformed
-- calibration is visible rather than half-absorbed.
function M.apply_calibration(reg, profile)
    local applied, rejected = {}, {}

    if type(profile) ~= "table" then
        return applied, { { key = "(profile)", reason = "not a table" } }
    end

    reg.calibration_id = profile.calibration_id or reg.calibration_id
    reg.game_patch = profile.game_patch or reg.game_patch

    local values = profile.values
    if type(values) ~= "table" then
        return applied, { { key = "values", reason = "missing or not a table" } }
    end

    for key, incoming in pairs(values) do
        local e = reg.entries[key]
        if not e then
            rejected[#rejected + 1] = { key = key, reason = "unknown key" }
        elseif type(incoming) ~= "table" then
            rejected[#rejected + 1] = { key = key, reason = "entry is not a table" }
        elseif not is_measured(incoming.status) then
            rejected[#rejected + 1] = { key = key,
                reason = "status must be a measurement: verified, refuted or partial" }
        elseif incoming.value == nil then
            rejected[#rejected + 1] = { key = key, reason = "no value" }
        else
            -- A refuted or partial entry still becomes usable. Refuted means
            -- "we measured it and the guess was wrong", partial means "we
            -- measured what could be witnessed"; both are knowledge. The three
            -- are kept apart so a report can say which happened, and so that a
            -- consumer needing the UNWITNESSED part of a partial value can tell
            -- it is missing rather than finding a guess sitting there.
            e.value = deep_copy(incoming.value)
            e.status = incoming.status
            -- Carried through rather than left in the document. A consumer that
            -- needs one of these has to learn it is missing from the register it
            -- is already holding, not by going back to find the profile.
            e.unwitnessed = incoming.unwitnessed and deep_copy(incoming.unwitnessed) or nil
            e.verified_by = profile.calibration_id
            e.verified_at_patch = profile.game_patch
            e.measurement_note = incoming.note
            applied[#applied + 1] = key
        end
    end

    table.sort(applied)
    return applied, rejected
end

-- Marks everything unverified again. Used when the game patch or the catalog
-- checksum no longer matches what the calibration was taken against: an action
-- id measured on another patch is not evidence about this one.
function M.invalidate(reg, reason)
    for _, e in pairs(reg.entries) do
        if e.status ~= M.STATUS.UNVERIFIED then
            e.status = M.STATUS.UNVERIFIED
            e.invalidated_reason = reason
            e.verified_by = nil
        end
    end
    reg.calibration_id = nil
end

-- --- reporting ---------------------------------------------------------------

-- JSON-serializable, and stable enough to diff between runs.
function M.snapshot(reg)
    local out = {
        calibration_id = reg.calibration_id,
        game_patch = reg.game_patch,
        entries = {},
        capabilities = {},
    }
    for key, e in pairs(reg.entries) do
        out.entries[key] = {
            status = e.status,
            value = deep_copy(e.value),
            unwitnessed = deep_copy(e.unwitnessed),
            gates = deep_copy(e.gates),
            measured_by = e.measured_by,
            verified_by = e.verified_by,
        }
    end
    for _, cap in pairs(M.CAPABILITY) do
        local ok, blocked = M.can(reg, cap)
        out.capabilities[cap] = { available = ok, blocked_by = blocked }
    end
    return out
end

-- Counts by status, for a one-line panel summary.
function M.summary(reg)
    local n = { unverified = 0, verified = 0, refuted = 0, partial = 0, total = 0 }
    for _, e in pairs(reg.entries) do
        n.total = n.total + 1
        n[e.status] = (n[e.status] or 0) + 1
    end
    return n
end

return M
