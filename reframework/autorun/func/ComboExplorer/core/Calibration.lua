-- =========================================================
-- ComboExplorer/core/Calibration.lua - turning measurements into a profile the
-- Provenance register will accept. Pure: no sdk, no re, no imgui, no json.
-- =========================================================
--
-- WHAT THIS IS FOR
--
-- core/Provenance.lua holds ten values nobody has measured, and refuses to let
-- the injector start until the ones gating INJECTION are verified. The way a
-- value stops being unverified is Provenance.apply_calibration(profile). This
-- module is what produces that profile.
--
-- Two halves, because the measurements arrive by two different routes:
--
--   from_probes()  folds the read-only probe reports (A/B/C) in. Nothing
--                  presses a button to obtain these; the operator plays and the
--                  probes watch. Five of the ten entries are settled this way.
--
--   new/plan/observe/conclude  is the sweep: a scripted sequence of inputs, and
--                  the action ids they produced. This is the only part that
--                  needs an input written, and it is what #7-#9 are.
--
-- THE BOOTSTRAP, STATED PLAINLY
--
-- The sweep has to write an input in order to find out which bit is which
-- button - and which bit is which button is exactly what gates injection. That
-- is circular, and the circle is broken here rather than by weakening the gate.
--
-- Calibration is the one caller that may legitimately write from a PROVISIONAL
-- value, because it is not using the guess, it is testing it. The failure mode
-- the gate exists to prevent - pressing a button that does not exist, watching
-- nothing come out, and recording "these moves do not link" - cannot happen
-- here: nothing in a sweep step is recorded as a fact about a move. A step that
-- produces no action is a measurement that the bit is not what we thought, and
-- that is the result, not a corrupted row.
--
-- So every step carries `tests`, naming the provisional entry it exercises, and
-- the caller writing the mask can see what it is putting its trust in.
--
-- WHAT THIS MODULE WILL NOT DO
--
-- It will not fill in a value it did not see. If a bit produced an action that
-- belongs to no single-button notation, or to more than one, the derivation
-- stops and the entry stays unverified with the reason attached. A calibration
-- that guesses at one bit is worse than no calibration at all, because the
-- register would then report INJECTION as available.

local Provenance = require("func/ComboExplorer/core/Provenance")
local InputMask  = require("func/ComboExplorer/core/InputMask")
local Catalog    = require("func/ComboExplorer/core/Catalog")

local M = { name = "ComboExplorer.Calibration" }

M.SCHEMA = "ce.calibration.v1"

M.PHASE = {
    NEUTRAL      = "neutral",       -- what the character reads as when nothing is pressed
    BUTTON_BITS  = "button_bits",   -- #7
    DIRECTION    = "direction",     -- #8
    ACTION_SWEEP = "action_sweep",  -- #9
}

-- The plan says three frames, single bit, from neutral. Kept here rather than
-- inline so the runtime shim and the tests cannot disagree about it.
M.DEFAULT_HOLD_TICKS = 3

-- --- helpers -----------------------------------------------------------------

local function copy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, val in pairs(v) do out[k] = copy(val) end
    return out
end

local function sorted_keys(t)
    local out = {}
    for k in pairs(t or {}) do out[#out + 1] = k end
    table.sort(out)
    return out
end

-- verified when the measurement matched the guess, refuted when it did not.
-- An entry whose provisional value was nil has nothing to be wrong about, so a
-- measurement of it is verified rather than refuted - "refuted" is a statement
-- about a guess, and there was none.
-- Returns status, unwitnessed. `unwitnessed` lists the keys the guess has that
-- the measurement never saw, and is nil when there are none.
--
-- The three outcomes are different facts and used to be two:
--
--   REFUTED   something the guess said turned out otherwise
--   PARTIAL   nothing disagreed, but part of the guess was never witnessed
--   VERIFIED  every key was witnessed and every key agreed
--
-- Collapsing the middle one into REFUTED made a flawless button sweep and a
-- sweep that got two buttons backwards produce byte-identical verdicts, because
-- the derived map can never contain AUTO or PARRY - no shipped catalog has a
-- single-button notation for either - so a subset is the NORMAL outcome rather
-- than a failure. A status that cannot tell success from failure is not a
-- status.
--
-- A key the measurement has and the guess does not is still REFUTED: the guess
-- said the value had a certain shape and it did not.
local function verdict_status(provisional, measured)
    if provisional == nil then return Provenance.STATUS.VERIFIED end
    if type(provisional) ~= type(measured) then return Provenance.STATUS.REFUTED end
    if type(provisional) ~= "table" then
        return provisional == measured and Provenance.STATUS.VERIFIED or Provenance.STATUS.REFUTED
    end

    local unwitnessed = {}
    for k, v in pairs(provisional) do
        if measured[k] == nil then
            unwitnessed[#unwitnessed + 1] = tostring(k)
        elseif measured[k] ~= v then
            return Provenance.STATUS.REFUTED
        end
    end
    for k, v in pairs(measured) do
        if provisional[k] ~= v then return Provenance.STATUS.REFUTED end
    end

    if #unwitnessed > 0 then
        table.sort(unwitnessed)
        return Provenance.STATUS.PARTIAL, unwitnessed
    end
    return Provenance.STATUS.VERIFIED
end

-- =========================================================
-- HALF ONE: the read-only probes
-- =========================================================
--
-- reports : { probe_a = <body>, probe_b = <body>, probe_c = <body> }
-- as written by Config.write_diag - the `body` of each document, not the whole
-- file.
--
-- Returns values, notes. `values` is the `values` block of a calibration
-- profile; `notes` lists every entry that was NOT settled and why, so a caller
-- can say what is still missing instead of silently shipping a short profile.
function M.from_probes(reports, opts)
    reports = reports or {}
    opts = opts or {}
    local reg = opts.provenance or Provenance.new()

    local values, notes = {}, {}

    local function skip(key, why)
        notes[#notes + 1] = { key = key, reason = why }
    end

    local function settle(key, measured, note)
        local provisional = Provenance.provisional(reg, key)
        local status, unwitnessed = verdict_status(provisional, measured)
        values[key] = {
            status = status,
            value = copy(measured),
            note = note,
            -- Structured, not only in the prose. A consumer that needs one of
            -- these has to be able to find out it is missing without parsing a
            -- sentence.
            unwitnessed = unwitnessed,
        }
    end

    -- --- probe B: the clock ---------------------------------------------------
    local b = reports.probe_b
    if type(b) ~= "table" then
        skip("input_hook_calls_per_frame", "no probe B report")
        skip("tick_equals_frame", "no probe B report")
        skip("hitstop_advances_tick", "no probe B report")
    else
        local finding = type(b.finding) == "table" and b.finding or {}
        if not finding.conclusive then
            local why = "probe B did not reach a conclusion: " .. tostring(finding.reason or "no finding")
            skip("input_hook_calls_per_frame", why)
            skip("tick_equals_frame", why)
        else
            settle("input_hook_calls_per_frame", finding.calls_per_frame, finding.reason)

            -- The register asks for "one Explorer tick is one game frame, and
            -- if not, what is the mapping" - so the value is the ratio, not a
            -- boolean. One call per frame IS the mapping, and recording it as
            -- `true` would throw away the only number a later delay can be
            -- converted with.
            settle("tick_equals_frame", { ticks_per_frame = finding.calls_per_frame,
                                          frames = finding.frames },
                   finding.reason)
        end

        -- Hitstop is settled separately: it has its own conclusiveness, and a
        -- clock that is conclusive overall can still have seen no hitstop at
        -- all - which is the case this must not read as "it does not advance".
        local hs = type(b.hitstop) == "table" and b.hitstop or {}
        local hitstop_frames = tonumber(b.frames and b.frames.with_hitstop) or 0
        if not hs.conclusive or hitstop_frames <= 0 then
            skip("hitstop_advances_tick",
                 ("only %d frame(s) of hitstop were sampled - no hits during the sample proves nothing")
                     :format(hitstop_frames))
        else
            -- The hook firing once per frame WHILE hitstop is running is the
            -- tick advancing during hitstop. The provisional value is false,
            -- from an upstream comment saying the hook does not fire then.
            local advances = (tonumber(hs.calls_per_frame_in_hitstop) or 0) > 0
            settle("hitstop_advances_tick", advances,
                   ("%d hitstop frame(s), %.3f call(s) per frame")
                       :format(hitstop_frames, tonumber(hs.calls_per_frame_in_hitstop) or 0))
        end
    end

    -- --- probe A: damage ------------------------------------------------------
    local a = reports.probe_a
    if type(a) ~= "table" then
        skip("combo_damage_readable", "no probe A report")
    elseif not a.sufficient then
        skip("combo_damage_readable", "probe A has too few comparable samples: " .. tostring(a.verdict))
    elseif a.hp_arm_usable ~= true then
        -- Without the control measurement there is nothing to cross-check the
        -- field against, and "it read a number" is not the same as "the number
        -- is damage".
        skip("combo_damage_readable",
             "probe A ran without a usable HP arm, so the field was never cross-checked")
    else
        local counts = type(a.counts) == "table" and a.counts or {}
        settle("combo_damage_readable", {
            readable = (tonumber(counts.nonzero) or 0) > 0,
            side = a.carrying_side,
            recommended_source = a.recommended_source,
            agreed = counts.agreed,
            comparable = counts.comparable,
        }, a.verdict)
    end

    -- --- probe C: reset cost --------------------------------------------------
    local c = reports.probe_c
    if type(c) ~= "table" then
        skip("reset_settle_ticks", "no probe C report")
    elseif not c.sufficient then
        skip("reset_settle_ticks", "probe C saw too few resets: " .. tostring(c.verdict))
    elseif tonumber(c.suggested_settle_ticks) == nil then
        skip("reset_settle_ticks", "probe C reported no suggested_settle_ticks")
    else
        settle("reset_settle_ticks", tonumber(c.suggested_settle_ticks), c.verdict)
    end

    table.sort(notes, function(x, y) return x.key < y.key end)
    return values, notes
end

-- =========================================================
-- HALF TWO: the sweep
-- =========================================================

-- opts.provenance : the register, for the provisional values being tested
-- opts.catalog    : a built catalog, for deriving what an observed id means
-- opts.hold_ticks : how long each single input is held (default 3)
--
-- Returns session, reason.
function M.new(opts)
    opts = opts or {}
    if type(opts.catalog) ~= "table" or type(opts.catalog.groups) ~= "table" then
        return nil, "calibration needs a built catalog"
    end
    local reg = opts.provenance or Provenance.new()

    local profile, perr = InputMask.profile_from_provenance(Provenance, reg, opts.scheme)
    if not profile then return nil, "could not build an input profile: " .. tostring(perr) end

    return {
        schema = M.SCHEMA,
        provenance = reg,
        catalog = opts.catalog,
        profile = profile,
        hold_ticks = tonumber(opts.hold_ticks) or M.DEFAULT_HOLD_TICKS,
        steps = nil,
        observations = {},
        neutral_action_id = nil,
    }
end

-- Every notation in the catalog that names exactly one button and no direction,
-- keyed by button name. This is what turns "bit 0x10 produced action 611" into
-- "bit 0x10 is the light button": 611 is in the group for the notation that
-- names only the light button, and in no other.
local function single_button_groups(catalog)
    local by_button = {}
    for _, g in pairs(catalog.groups or {}) do
        local parsed = InputMask.parse(g.notation)
        if parsed and not parsed.followup and not parsed.air and not parsed.any_button
            and parsed.dirs == "" and #parsed.buttons == 1 then
            local name = parsed.buttons[1]
            by_button[name] = by_button[name] or { ids = {}, notations = {} }
            for _, id in ipairs(g.action_ids or {}) do
                by_button[name].ids[id] = true
            end
            by_button[name].notations[#by_button[name].notations + 1] = g.notation
        end
    end
    return by_button
end

-- The ordered list of inputs to write. Each step is a plain record; the runtime
-- shim reads `mask`, holds it for `hold_ticks`, releases, and reports back.
function M.plan(session)
    if session.steps then return session.steps end

    local steps = {}
    local function add(s)
        s.id = ("%s#%d"):format(s.phase, #steps + 1)
        steps[#steps + 1] = s
        return s
    end

    -- The baseline. Which action id "standing still" is, is not assumed - a
    -- later step producing that id means the input did nothing, and that
    -- comparison needs a measured value on both sides of it.
    add {
        phase = M.PHASE.NEUTRAL,
        mask = 0,
        mirror = false,
        hold_ticks = session.hold_ticks,
        purpose = "record the action id of a character that was asked to do nothing",
        tests = {},
    }

    -- #7 - one bit at a time, from the provisional map. The BITS are swept, not
    -- the button names: the point is to find out which bit is which button, and
    -- sweeping by name would assume the answer.
    local bits = {}
    do
        local buttons = Provenance.provisional(session.provenance, "modern_button_bits") or {}
        local seen = {}
        for _, bit in pairs(buttons) do
            if type(bit) == "number" and not seen[bit] then
                seen[bit] = true
                bits[#bits + 1] = bit
            end
        end
        table.sort(bits)
    end
    for _, bit in ipairs(bits) do
        add {
            phase = M.PHASE.BUTTON_BITS,
            mask = bit,
            bit = bit,
            -- A single button bit carries no left or right, so there is nothing
            -- to mirror. Stated rather than left to the writer's default,
            -- because the writer's default is what broke the direction phase.
            mirror = false,
            hold_ticks = session.hold_ticks,
            purpose = ("hold bit 0x%X alone and record what came out"):format(bit),
            tests = { "modern_button_bits" },
        }
    end

    -- #8 - each direction bit alone, on BOTH sides. One side cannot answer the
    -- polarity question: a mask that walks forward on the left is consistent
    -- both with "no mirror needed" and with "mirror needed on the other side",
    -- and those two differ only in what the other side does.
    local dirs = Provenance.provisional(session.provenance, "direction_bits") or {}
    for _, name in ipairs({ "LEFT", "RIGHT" }) do
        local bit = dirs[name]
        if type(bit) == "number" then
            for _, side in ipairs({ "rl_dir_truthy", "rl_dir_falsy" }) do
                add {
                    phase = M.PHASE.DIRECTION,
                    mask = bit,
                    bit = bit,
                    direction = name,
                    side = side,
                    -- NEVER mirrored, and this is the whole correctness of #8.
                    -- What the step measures is what the RAW bit does on each
                    -- side. Mirroring it first would apply the provisional
                    -- polarity to the experiment that exists to measure that
                    -- polarity: the two worlds with a real answer would then
                    -- look identical to each other and be refused, and the one
                    -- world that should be refused would come out VERIFIED with
                    -- a polarity that double-mirrors half of every later
                    -- dataset - "flaky links rather than a bug".
                    mirror = false,
                    hold_ticks = session.hold_ticks,
                    purpose = ("hold %s (0x%X) with %s and record which way the character went")
                        :format(name, bit, side),
                    tests = { "direction_bits", "rl_dir_polarity" },
                }
            end
        end
    end

    -- #9 - one step per group the catalog cannot resolve on its own. Driven off
    -- the catalog rather than off a written-out {5,2,4,6,1,3}x{L,M,H,SP} grid,
    -- so the sweep asks exactly the questions the data still has open and
    -- carries the catalog's own notation string into the answer.
    -- Unlike the phases above, these steps have to PRESS a notation rather than
    -- hold a named bit, so a mask has to be built. A step with no mask presses
    -- nothing, completes normally, and records the IDLE action id against the
    -- group - nine confident, wrong observations and not one error.
    --
    -- Everything the plan cannot build a single-tick mask for is recorded in
    -- `groups_unaddressed` rather than dropped, because conclude() judges
    -- completeness against what was actually attempted: a group nobody could
    -- press must not read the same as a group that was pressed and did nothing.
    session.groups_addressed = {}
    session.groups_unaddressed = {}

    local function cannot(g, why)
        session.groups_unaddressed[#session.groups_unaddressed + 1] =
            { display_group = g.display_group, notation = g.notation, reason = why }
    end

    for _, g in ipairs(Catalog.ambiguous_groups(session.catalog)) do
        local parsed = InputMask.parse(g.notation)
        if not parsed then
            cannot(g, "the notation carries no input")
        elseif parsed.followup then
            cannot(g, "a follow-up only comes out after a preceding action, "
                   .. "so it cannot be produced from neutral")
        elseif parsed.air then
            cannot(g, "an air move cannot be produced from a standing neutral")
        else
            local btn, berr = InputMask.button_mask(parsed.buttons, session.profile)
            local dirs, derr
            if parsed.dirs ~= "" then
                dirs, derr = InputMask.dirs_from_numpad(parsed.dirs, session.profile)
            end

            if not btn then
                cannot(g, tostring(berr))
            elseif parsed.dirs ~= "" and not dirs then
                cannot(g, tostring(derr))
            elseif dirs and #dirs > 1 then
                -- A motion is one direction per tick and this sweep writes a
                -- single mask for the whole hold. Playing 720 needs a compiled
                -- tick program: SequenceCompiler builds those and the Injector
                -- runs them, and neither is this.
                cannot(g, ("the motion %q needs %d direction ticks, and this sweep "
                       .. "writes one mask"):format(parsed.dirs, #dirs))
            else
                local mask = btn | (dirs and dirs[1] or 0)
                session.groups_addressed[g.display_group] = true
                add {
                    phase = M.PHASE.ACTION_SWEEP,
                    notation = g.notation,
                    input_method = g.input_method,
                    display_group = g.display_group,
                    candidates = copy(g.action_ids),
                    mask = mask,
                    -- Player-relative: "6" means forward, and which screen
                    -- direction that is depends on the side. Nothing here is
                    -- measuring the polarity, so the profile's value is used
                    -- rather than tested.
                    mirror = true,
                    hold_ticks = session.hold_ticks,
                    purpose = ("%s (mask 0x%X) produces one of %d ids; find out which")
                        :format(g.notation, mask, #(g.action_ids or {})),
                    tests = { "action_id_canonical" },
                }
            end
        end
    end

    session.steps = steps
    return steps
end

-- obs for a NEUTRAL or BUTTON_BITS or ACTION_SWEEP step : { action_id = n }
-- obs for a DIRECTION step : { own_pos_before, own_pos_after, opponent_pos, rl_dir }
function M.observe(session, step_id, obs)
    if type(obs) ~= "table" then return false, "observation is not a table" end
    local steps = M.plan(session)
    local step
    for _, s in ipairs(steps) do
        if s.id == step_id then step = s break end
    end
    if not step then return false, "no such step: " .. tostring(step_id) end

    session.observations[step_id] = copy(obs)
    if step.phase == M.PHASE.NEUTRAL then
        session.neutral_action_id = obs.action_id
    end
    return true
end

-- --- deriving the button map -------------------------------------------------

local function conclude_button_bits(session, steps)
    local reg = session.provenance
    local by_button = single_button_groups(session.catalog)

    local derived, problems = {}, {}
    local saw_any = false

    for _, s in ipairs(steps) do
        if s.phase == M.PHASE.BUTTON_BITS then
            local obs = session.observations[s.id]
            if not obs then
                problems[#problems + 1] = { bit = s.bit, reason = "not run" }
            elseif session.neutral_action_id == nil then
                problems[#problems + 1] = { bit = s.bit, reason = "the neutral step was never run" }
            elseif obs.action_id == session.neutral_action_id then
                -- Not a failure to record: a bit that produces nothing is a
                -- measured fact about that bit, and it is the fact that would
                -- have poisoned every trial had it gone unnoticed.
                problems[#problems + 1] = { bit = s.bit, reason = "produced no action",
                                            action_id = obs.action_id }
            else
                saw_any = true
                local matches = {}
                for name, info in pairs(by_button) do
                    if info.ids[obs.action_id] then matches[#matches + 1] = name end
                end
                table.sort(matches)
                if #matches == 1 then
                    if derived[matches[1]] then
                        problems[#problems + 1] = {
                            bit = s.bit, reason = "two bits produced the same button",
                            button = matches[1], other_bit = derived[matches[1]],
                        }
                    else
                        derived[matches[1]] = s.bit
                    end
                elseif #matches == 0 then
                    problems[#problems + 1] = {
                        bit = s.bit, action_id = obs.action_id,
                        reason = "the action it produced belongs to no single-button notation",
                    }
                else
                    problems[#problems + 1] = {
                        bit = s.bit, action_id = obs.action_id, candidates = matches,
                        reason = "the action it produced belongs to more than one single-button notation",
                    }
                end
            end
        end
    end

    if not saw_any then
        return nil, problems, "no button bit produced an action"
    end

    -- Completeness is judged against what this catalog can WITNESS, not against
    -- the guess's key list.
    --
    -- The derivation reads a bit's identity off the single-button notation that
    -- contains the action it produced, so a button with no single-button
    -- notation anywhere in the catalog can never be derived however perfectly
    -- the sweep runs. On every shipped character that is at least AUTO, which
    -- only ever appears as "AUTO + <strength>", and PARRY, which InputMask has
    -- no token for at all. Judging against the guess's eight keys therefore
    -- meant `missing` was never empty and the entry that gates INJECTION was
    -- skipped on every possible run - the sweep could not succeed.
    --
    -- So: every button the catalog COULD have witnessed must have a bit, and
    -- the ones it could not are named. They stay out of the map. A map without
    -- AUTO cannot express AUTO, and InputMask.button_mask reports an unknown
    -- name rather than quietly pressing nothing - which is the loud failure,
    -- and the right one.
    local provisional = Provenance.provisional(reg, "modern_button_bits") or {}
    local missing, underivable = {}, {}
    for _, name in ipairs(sorted_keys(provisional)) do
        if derived[name] == nil then
            if by_button[name] then
                missing[#missing + 1] = name
            else
                underivable[#underivable + 1] = name
            end
        end
    end
    if #missing > 0 then
        return nil, problems,
            ("no bit was found for %s, which this catalog does name"):format(
                table.concat(missing, ", "))
    end

    return derived, problems, nil, underivable
end

-- --- deriving the directions and the polarity --------------------------------

local function conclude_direction(session, steps)
    local reg = session.provenance
    local provisional = Provenance.provisional(reg, "direction_bits") or {}

    -- side -> direction name -> which way the world position went
    local went = {}
    local problems = {}

    for _, s in ipairs(steps) do
        if s.phase == M.PHASE.DIRECTION then
            local obs = session.observations[s.id]
            if not obs then
                problems[#problems + 1] = { step = s.id, reason = "not run" }
            else
                local before = tonumber(obs.own_pos_before)
                local after  = tonumber(obs.own_pos_after)
                local opp    = tonumber(obs.opponent_pos)
                if before == nil or after == nil or opp == nil then
                    problems[#problems + 1] = { step = s.id, reason = "observation has no positions" }
                elseif after == before then
                    problems[#problems + 1] = { step = s.id, direction = s.direction,
                                                side = s.side, reason = "the character did not move" }
                else
                    -- Toward the opponent is the only frame of reference that
                    -- means the same thing on both sides. World sign does not:
                    -- +x is forward on one side and backward on the other,
                    -- which is the whole question.
                    local toward = ((after - before) > 0) == ((opp - before) > 0)
                    went[s.side] = went[s.side] or {}
                    if went[s.side][s.direction] ~= nil and went[s.side][s.direction] ~= toward then
                        problems[#problems + 1] = { step = s.id, direction = s.direction,
                            side = s.side, reason = "the same input went both ways" }
                    end
                    went[s.side][s.direction] = toward
                end
            end
        end
    end

    local truthy, falsy = went.rl_dir_truthy, went.rl_dir_falsy
    if not truthy or not falsy or truthy.RIGHT == nil or falsy.RIGHT == nil then
        return nil, nil, problems, "both sides must be sampled before polarity can be decided"
    end
    if truthy.RIGHT == falsy.RIGHT then
        -- The same written bit went the same way relative to the opponent on
        -- both sides, so the game is already mirroring for us and mirroring
        -- again would undo it. That is not one of the two values the register
        -- accepts, so it is reported rather than rounded to the nearer one.
        return nil, nil, problems,
            "RIGHT went the same way on both sides - the game mirrors the written mask itself, "
            .. "which neither mirror_when_falsy nor mirror_when_truthy describes"
    end

    -- Mirroring is needed on the side where writing RIGHT did NOT go forward.
    local polarity = truthy.RIGHT and "mirror_when_falsy" or "mirror_when_truthy"

    -- The direction bits themselves are confirmed rather than derived: a
    -- position delta says a bit is horizontal and which way it points, and
    -- that is what the sweep can see. UP and DOWN are not exercised by it, so
    -- the map is only reported as measured when LEFT and RIGHT both behaved as
    -- the guess said they would.
    local left_ok = went.rl_dir_truthy.LEFT ~= nil and went.rl_dir_truthy.LEFT ~= truthy.RIGHT
    if not left_ok then
        return nil, polarity, problems,
            "LEFT and RIGHT did not come out opposite, so the direction bits are not confirmed"
    end

    -- Only what was pressed. This used to return `copy(provisional)` - the
    -- whole four-key guess, UP and DOWN included - so verdict_status compared
    -- the guess against a copy of itself and could return nothing but VERIFIED.
    -- The entry gating INJECTION was therefore stamped "measured" with UP and
    -- DOWN never once held, and those two bits build six of the nine numpad
    -- digits: every crouching normal, and the down leg of every 236, 214 and
    -- 623.
    --
    -- The comment a few lines up has always said UP and DOWN are not exercised.
    -- Now the status says it too, because a subset comes back PARTIAL.
    return { LEFT = provisional.LEFT, RIGHT = provisional.RIGHT }, polarity, problems, nil
end

-- --- the whole verdict -------------------------------------------------------

-- Returns a report: what each entry came out as, and every reason an entry did
-- not. Nothing here writes to the register; that is apply_calibration's job,
-- and keeping it separate means a half-finished sweep can be looked at without
-- being absorbed.
function M.conclude(session)
    local steps = M.plan(session)
    local reg = session.provenance
    local values, notes = {}, {}

    local function skip(key, why) notes[#notes + 1] = { key = key, reason = why } end
    local function settle(key, measured, note)
        local status, unwitnessed = verdict_status(Provenance.provisional(reg, key), measured)
        values[key] = {
            status = status,
            value = copy(measured),
            note = note,
            unwitnessed = unwitnessed,
        }
    end

    local bits, bit_problems, bit_err, underivable = conclude_button_bits(session, steps)
    if bits then
        local note = ("derived from %d single-bit step(s)"):format(#steps)
        -- Named in the note rather than left to be noticed by whoever later
        -- asks the profile to press one of them. The map genuinely does not
        -- contain these, and it must be obvious why.
        if underivable and #underivable > 0 then
            note = note .. ("; no bit for %s - this catalog has no single-button "
                .. "notation for them, so the sweep could not witness one")
                :format(table.concat(underivable, ", "))
        end
        settle("modern_button_bits", bits, note)
    else
        skip("modern_button_bits", bit_err or "not measured")
    end

    local dirs, polarity, dir_problems, dir_err = conclude_direction(session, steps)
    if dirs then
        settle("direction_bits", dirs, "LEFT and RIGHT confirmed by position delta on both sides")
    else
        skip("direction_bits", dir_err or "not measured")
    end
    if polarity then
        settle("rl_dir_polarity", polarity, "decided by which side needed the mask flipped")
    else
        skip("rl_dir_polarity", dir_err or "not measured")
    end

    -- #9 goes through the catalog rather than being decided here: the rule that
    -- a group seen to conflict never returns to verified lives in
    -- Catalog.apply_observations, and a second implementation of it here would
    -- be a second chance to get it wrong.
    -- A step that pressed something and saw nothing come out arrives here
    -- carrying the NEUTRAL action id, because CalibrationFsm.finish_step
    -- substitutes it (deliberately - conclude_button_bits needs that shape to
    -- report "produced no action", and does the comparison at the top of this
    -- file).
    --
    -- Submitted here it becomes an observation that this notation produces the
    -- idle action, which is not what happened. Catalog.apply_observations then
    -- reports "observed action id is not in the group for that notation", and a
    -- silent sweep manufactures one such conflict per ambiguous group - eight of
    -- them for Zangief.
    --
    -- That is worse than noise. A group seen to conflict never returns to
    -- verified, on purpose, so a fabricated conflict is permanent: no later
    -- sweep, however clean, can undo it.
    local observations, produced_nothing = {}, {}
    for _, s in ipairs(steps) do
        if s.phase == M.PHASE.ACTION_SWEEP then
            local obs = session.observations[s.id]
            local nothing = (obs == nil)
                or (obs.action_id == nil)
                or (session.neutral_action_id ~= nil
                    and obs.action_id == session.neutral_action_id)
            if nothing then
                if obs ~= nil then
                    produced_nothing[#produced_nothing + 1] = s.notation
                end
            else
                observations[#observations + 1] = {
                    notation = s.notation,
                    input_method = s.input_method,
                    action_id = obs.action_id,
                }
            end
        end
    end

    local applied, conflicts = {}, {}
    if #observations > 0 then
        applied, conflicts = Catalog.apply_observations(session.catalog, observations)
    end

    -- Completeness is judged against the groups the plan ATTEMPTED, not against
    -- every ambiguous group in the catalog.
    --
    -- plan() emits no step for a group that is an air move, a follow-up, or a
    -- motion this sweep cannot press in one tick, so those can never be
    -- observed. Counting them as unresolved made the total permanently non-zero
    -- - every character has at least one - and action_id_canonical could never
    -- settle on any run. A group nobody could press is a limit of the sweep,
    -- not an outstanding question about the run.
    local addressed = session.groups_addressed or {}
    local unresolved = {}
    for _, g in ipairs(Catalog.ambiguous_groups(session.catalog)) do
        if addressed[g.display_group] and g.canonical_status ~= "verified" then
            unresolved[#unresolved + 1] = g.display_group
        end
    end

    local attempted = 0
    for _ in pairs(addressed) do attempted = attempted + 1 end

    local nothing_note = ""
    if #produced_nothing > 0 then
        nothing_note = ("; %d group(s) were pressed and produced no action: %s")
            :format(#produced_nothing, table.concat(produced_nothing, ", "))
    end

    if attempted == 0 then
        skip("action_id_canonical",
             "the plan could press none of the ambiguous groups" .. nothing_note)
    elseif #unresolved > 0 then
        skip("action_id_canonical",
             ("%d of the %d group(s) the sweep pressed are still unresolved: %s%s")
                 :format(#unresolved, attempted, table.concat(unresolved, ", "), nothing_note))
    else
        local canonical = {}
        for _, g in ipairs(Catalog.ambiguous_groups(session.catalog)) do
            if addressed[g.display_group] then
                canonical[g.display_group] = g.canonical_action_id
            end
        end
        local note = ("%d group(s) resolved by observation"):format(#applied)
        local out_of_reach = session.groups_unaddressed or {}
        if #out_of_reach > 0 then
            note = note .. ("; %d group(s) were out of this sweep's reach and remain open")
                :format(#out_of_reach)
        end
        settle("action_id_canonical", canonical, note)
    end

    table.sort(notes, function(a, b) return a.key < b.key end)

    return {
        values = values,
        notes = notes,
        problems = {
            button_bits = bit_problems or {},
            direction = dir_problems or {},
            action_sweep = conflicts or {},
        },
        steps_total = #steps,
        steps_observed = (function()
            local n = 0
            for _ in pairs(session.observations) do n = n + 1 end
            return n
        end)(),
    }
end

-- =========================================================
-- THE DOCUMENT
-- =========================================================

-- Assembles what Provenance.apply_calibration takes. `blocks` is a list of
-- `values` tables - from from_probes, from conclude, or both - merged in order,
-- so a machine that ran the probes on Monday and the sweep on Tuesday produces
-- one profile.
--
-- identity (game_patch, ac_sha256, bcm_sha256) is REQUIRED, not defaulted. An
-- action id measured against one AC/BCM pair is not evidence about another, and
-- a profile that cannot say which build it was taken on cannot be invalidated
-- when the build changes - it just goes on being believed.
function M.document(identity, blocks)
    identity = identity or {}
    local missing = {}
    for _, k in ipairs({ "calibration_id", "game_patch", "ac_sha256", "bcm_sha256" }) do
        if type(identity[k]) ~= "string" or identity[k] == "" then missing[#missing + 1] = k end
    end
    if #missing > 0 then
        return nil, "calibration identity is missing " .. table.concat(missing, ", ")
    end

    local values = {}
    local overwritten = {}
    for _, block in ipairs(blocks or {}) do
        for key, v in pairs(block or {}) do
            if values[key] then overwritten[#overwritten + 1] = key end
            values[key] = copy(v)
        end
    end

    local n = 0
    for _ in pairs(values) do n = n + 1 end
    if n == 0 then return nil, "a calibration profile with no measured values is not a calibration" end

    return {
        schema = M.SCHEMA,
        calibration_id = identity.calibration_id,
        game_patch = identity.game_patch,
        ac_sha256 = identity.ac_sha256,
        bcm_sha256 = identity.bcm_sha256,
        character = identity.character,
        control_scheme = identity.control_scheme or "modern",
        generated_at = identity.generated_at,
        values = values,
        -- Reported rather than refused: merging a fresh sweep over an older one
        -- is the normal way to extend a profile, and the caller should be able
        -- to see that it happened.
        overwritten = overwritten,
    }
end

return M
