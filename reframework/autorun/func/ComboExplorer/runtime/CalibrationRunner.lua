-- =========================================================
-- ComboExplorer/runtime/CalibrationRunner.lua - the wire between
-- core/CalibrationFsm.lua and Street Fighter 6. Deliberately thin: it reads a
-- snapshot, ticks the machine, and writes the one mask the machine asked for.
-- Every decision is upstream of here.
-- =========================================================
--
-- WHY THE WRITE IS NOT WHERE THE DECISION IS
--
-- pl_input_new is only live inside the pl_input_sub hook, and the machine is
-- ticked from the frame anchor. So the tick DECIDES a mask and parks it, and
-- the input callback SPENDS it. The callback clears it on the way out: a mask
-- left parked would be written again on the next call, and a three-frame tap
-- would quietly become a hold for as long as the watch window.
--
-- Probe B is what makes this simple. One pl_input_sub call per battle frame,
-- measured over 76,565 frames, means one parked mask is written exactly once -
-- so "held for three ticks" is three writes. At two calls per frame it would
-- have been six, and the hold would have been the right length in ticks and the
-- wrong length in frames.
--
-- WHY IT ORs RATHER THAN ASSIGNS
--
-- Every other P1 writer in the suite ORs into pl_input_new
-- (TrainingMoveExecution.lua:307), and a writer that assigned would stamp on
-- whatever else is running that frame. The cost is that an operator holding a
-- direction is ORed in too, which is why the panel says to let go of the pad -
-- and why the machine watches for the FIRST non-idle action rather than
-- trusting that the stage was clean.
--
-- THIS IS NOT runtime/Injector.lua
--
-- The Injector (#11) runs trials, and Provenance refuses to let it start until
-- the button map is verified. This runs the sweep that produces that map, from
-- the provisional values, and it is allowed to because it is testing the guess
-- rather than using it. See the header of core/Calibration.lua.

local Provenance  = require("func/ComboExplorer/core/Provenance")
local Catalog     = require("func/ComboExplorer/core/Catalog")
local InputMask   = require("func/ComboExplorer/core/InputMask")
local Calibration = require("func/ComboExplorer/core/Calibration")
local Fsm         = require("func/ComboExplorer/core/CalibrationFsm")

-- Declared above the adapter helper so that helper can see it: a run carries
-- its own adapter when a test gave it one.
local run = nil          -- the live run, or nil

-- Resolved on first use, not at load.
--
-- GameAdapter calls sdk.find_type_definition at file scope, so requiring it
-- here made this whole file unloadable on the machine it is written on - which
-- is where its decisions have to be tested. It was the only runtime module left
-- doing that; StageControl, Injector, Sweep and CatalogLocator all take the
-- adapter as an argument and fall back lazily.
--
-- The decisions that were untestable because of it are the ones added when the
-- sweep became unattended: which arrangement a side request writes, that a
-- RETRY re-writes the same one rather than flipping again, and that finishing
-- writes the profile by itself.
local _adapter = nil
local function adapter()
    if run and run.adapter then return run.adapter end
    if _adapter == nil then
        _adapter = require("func/ComboExplorer/runtime/GameAdapter")
    end
    return _adapter
end
local JsonIO      = require("func/ComboExplorer/runtime/JsonIO")
local CatalogLocator = require("func/ComboExplorer/runtime/CatalogLocator")

local M = { name = "ComboExplorer.CalibrationRunner" }

local pending_mask = nil   -- decided by the tick, spent by the input callback
local pending_mirror = nil -- and whether that mask may be flipped for facing
local hooked = false
local install_error = nil

-- --- the input callback ------------------------------------------------------

-- Registered once per script generation. The suite's convention is a table of
-- callbacks on _G._shared_input_post rather than a second sdk.hook, which is
-- what keeps this from being the double registration the runbook forbids.
function M.install(is_current)
    if hooked then return true end
    if type(_G._shared_input_post) ~= "table" then
        install_error = "_G._shared_input_post is missing - SharedHooks did not load, "
            .. "so the sweep cannot write anything"
        return false, install_error
    end

    table.insert(_G._shared_input_post, function(p_id, _retval)
        if not is_current() then return end
        if p_id ~= 0 then return end
        local mask, mirror = pending_mask, pending_mirror
        -- Spent. Not left for the next call to find.
        pending_mask, pending_mirror = nil, nil
        if not mask or mask == 0 then return end
        if not run then return end

        pcall(function()
            local p1 = adapter().player(0)
            if not p1 then return end

            -- Mirrored only when the STEP says so.
            --
            -- It used to be mirrored unconditionally, which silently broke the
            -- one phase that must not be: the direction steps measure what the
            -- raw bit does on each side, and mirroring them first applied the
            -- provisional polarity to the experiment measuring that polarity.
            -- Both worlds with a real answer then looked identical and were
            -- refused, and the world that should have been refused produced a
            -- confident VERIFIED polarity that would double-mirror half of
            -- every later dataset.
            local final = mask
            if mirror then
                -- mirror() returns nil for a malformed profile. Writing
                -- `now | nil` raises inside this pcall and vanishes, and the
                -- sweep would record every step as "nothing came out" - a full
                -- set of confident negatives about the button map.
                final = InputMask.mirror(mask, p1:get_field("rl_dir"), run.session.profile)
                if final == nil then
                    run.write_error = "InputMask.mirror refused the profile"
                    return
                end
            end
            local now = p1:get_field("pl_input_new") or 0
            p1:set_field("pl_input_new", now | final)
            p1:set_field("pl_sw_new", (p1:get_field("pl_sw_new") or 0) | final)
            run.writes = run.writes + 1
        end)
    end)

    hooked = true
    install_error = nil
    return true
end

-- Why the sweep cannot write, if it cannot. Kept on the module because the
-- callback is installed at file scope, well above the panel that reports it.
function M.install_error() return install_error end

-- --- the run -----------------------------------------------------------------

-- opts.character : catalog key, for the document identity
-- opts.game_patch / ac_sha256 / bcm_sha256 : required by Calibration.document
-- opts.adapter       : substituted by tests. Defaults to GameAdapter.
-- opts.identity      : the identity the finished profile is written under.
--                      Held from the start rather than collected at the end,
--                      because the run now writes itself when it finishes and
--                      there is nobody there to supply it.
-- opts.probe_values  : the Calibration.from_probes block, folded into the same
--                      document so one file carries everything measured on this
--                      build. Also needed up front, for the same reason.
function M.start(reg, opts)
    opts = opts or {}
    if run then return nil, "a calibration is already running" end

    -- Taken before `run` exists, because everything below reads through it.
    local ad = opts.adapter
    if ad == nil then
        local ok, mod = pcall(require, "func/ComboExplorer/runtime/GameAdapter")
        if not ok then return nil, "GameAdapter is unavailable: " .. tostring(mod) end
        ad = mod
    end
    local start_defaults = ad.DEFAULT_START_X or { p1 = -150, p2 = 150 }

    local info = ad.character(0)
    if not info then return nil, "P1 is not resolved yet - start a battle first" end

    -- opts.catalog_raw is the decoded command_display, for a caller that already
    -- has one. Only the tests use it: M.load_catalog goes through CatalogLocator
    -- and a JSON reader, neither of which exists on a machine with no game, and
    -- without this seam the whole run - the side requests, the auto-write, the
    -- budgets - could not be driven anywhere it can be checked.
    local raw, err = opts.catalog_raw, nil
    if raw == nil then raw, err = M.load_catalog(info) end
    if not raw then return nil, err end
    local cat, problems = Catalog.build(raw)
    if not cat then
        return nil, "could not build a catalog: "
            .. tostring(problems and problems[1] and problems[1].reason)
    end

    local session, serr = Calibration.new({
        provenance = reg,
        catalog = cat,
        hold_ticks = opts.hold_ticks,
    })
    if not session then return nil, serr end

    local fsm, ferr = Fsm.new({
        session = session,
        settle_ticks = opts.settle_ticks,
        watch_ticks = opts.watch_ticks,
    })
    if not fsm then return nil, ferr end

    run = {
        adapter = ad,

        -- The arrangement currently written. Upstream's default, and the one
        -- both of its copies agree on: P1 on the left.
        start_x = { p1 = start_defaults.p1, p2 = start_defaults.p2 },
        side_request_for = nil,
        side_flips = 0,
        side_writes = 0,
        side_error = nil,
        abandoned = 0,
        auto_written = false,
        auto_write_path = nil,
        auto_write_error = nil,

        identity = opts.identity,
        probe_values = opts.probe_values,

        session = session,
        fsm = fsm,
        catalog = cat,
        character = cat.character or info.name,
        started_at = os.clock(),
        writes = 0,
        ticks = 0,
        last_note = nil,
    }
    pending_mask, pending_mirror = nil, nil
    return run
end

-- Returns true, or false plus a reason when there is something to lose.
--
-- It used to discard `run` outright, and `run` is the only place the sweep's
-- observations live - so an operator who came back to a finished sweep and
-- pressed STOP before WRITE PROFILE destroyed the whole thing. That is exactly
-- the sequence an unattended run invites.
--
-- opts.force stops anyway, for someone who means it.
function M.stop(opts)
    opts = opts or {}
    if run and not opts.force then
        local wrote = run.auto_write_path ~= nil
        if not wrote and run.ticks > 0 then
            return false, ("this run has %d ticks of observations and no profile "
                .. "written yet - press WRITE PROFILE first, or stop again to discard")
                :format(run.ticks)
        end
    end
    pending_mask, pending_mirror = nil, nil
    run = nil
    return true
end

function M.running() return run ~= nil end

-- Resolved by runtime/CatalogLocator, which is also what Probe D uses. This was
-- a second copy of the same twenty lines, and it had already drifted: it
-- reported "there is no way to find its catalog" for both "no numeric id" and
-- "fs.glob is unavailable", which are different problems with different fixes -
-- and it did so on the "ESF_006" path, the one the locator's header is about.
function M.load_catalog(info)
    local _, decoded = CatalogLocator.resolve(info)
    if type(decoded) ~= "table" then return nil, decoded end
    return decoded
end

-- One battle frame. Driven from Clock.on_frame, which is the anchor Probe B
-- validated - NOT from the input callback, which is a different clock and the
-- one this build is not allowed to assume things about.
-- Ask the game to put P1 on the other side.
--
-- WHAT THIS DOES AND DOES NOT KNOW
--
-- It does not know which arrangement produces which rl_dir. That is the
-- polarity the sweep exists to measure, so choosing "the truthy arrangement"
-- here would be answering the question under test. All it does is write the
-- OPPOSITE of whatever it last wrote and let the FSM watch rl_dir.
--
-- WHY A RETRY RE-WRITES THE SAME THING
--
-- The FSM asks again every `side_retry_ticks` while it is still waiting.
-- Flipping again on each ask would walk the players back and forth forever and
-- never settle. So a request for a step that is already being served re-writes
-- the SAME arrangement - another chance for the engine to apply it - and only a
-- request for a DIFFERENT step flips.
local function serve_side_request(step_id)
    if run.side_request_for ~= step_id then
        -- A new step wants the other side: flip.
        run.start_x = { p1 = run.start_x.p2, p2 = run.start_x.p1 }
        run.side_request_for = step_id
        run.side_flips = run.side_flips + 1
    end

    local ok, why = adapter().set_start_positions(run.start_x.p1, run.start_x.p2)
    run.side_writes = run.side_writes + 1
    if not ok then
        run.side_error = why
    else
        run.side_error = nil
    end
end

function M.tick()
    if not run then return end
    local snap = adapter().snapshot(0)
    if not snap then return end

    run.ticks = run.ticks + 1
    local cmd = Fsm.tick(run.fsm, {
        action_id = snap.attacker_action_id,
        own_pos = snap.attacker_pos,
        opponent_pos = snap.victim_pos,
        -- The raw field, not an interpretation of it. Which truth value means
        -- "mirrored" is rl_dir_polarity, which is what the sweep is measuring.
        rl_dir = snap.attacker_rl_dir_raw,
        can_inject = adapter().can_inject(),
    })

    pending_mask = cmd.write_mask
    pending_mirror = cmd.mirror
    run.last_note = cmd.note
    run.last_state = cmd.state

    -- Only on the ticks the machine actually asked. The command carries
    -- request_side on entry to the wait and then once every retry interval -
    -- writing it every tick would ask the engine to refresh the stage on every
    -- frame, which is a stutter rather than a swap.
    if cmd.request_side ~= nil then serve_side_request(cmd.step_id) end

    if cmd.abandoned then
        run.abandoned = (run.abandoned or 0) + 1
    end

    -- The sweep is over. Write the profile HERE rather than waiting for someone
    -- to press a button: the whole point is that it can be left alone, and
    -- until now finishing did nothing and M.stop() threw the run away.
    if cmd.state == Fsm.STATE.DONE and not run.auto_written then
        run.auto_written = true
        if run.identity == nil then
            -- Refused rather than invented. Calibration.document needs a
            -- calibration_id and a game_patch, and a profile filed under a made
            -- up build is worse than one nobody wrote: it would be indexed,
            -- found, and believed.
            run.auto_write_error = "no identity was given at start, so the finished "
                .. "profile cannot say which build it describes - press WRITE PROFILE"
        else
            local path, werr = M.write_profile(run.identity, run.probe_values)
            run.auto_write_path = path
            run.auto_write_error = path and nil or tostring(werr)
        end
    end

    return cmd
end

-- --- results -----------------------------------------------------------------

function M.progress()
    if not run then return nil end
    local p = Fsm.progress(run.fsm)
    p.writes = run.writes
    p.ticks = run.ticks
    p.note = run.last_note
    p.character = run.character
    return p
end

function M.report()
    if not run then return nil, "nothing is running" end
    return Calibration.conclude(run.session)
end

-- os.date the way Config.stamp() takes it: through pcall, because a host that
-- does not hand this Lua state an os table must lose the ordering, not the
-- write. Returns nil rather than a placeholder so the caller decides what an
-- absent clock means for the field it is filling.
local function utc(fmt)
    local ok, s = pcall(os.date, fmt)
    if ok and type(s) == "string" then return s end
    return nil
end

-- Record copies already written in this session, keyed by the name they would
-- have taken.
--
-- A stamp on its own does not make the name unique. It has one-second
-- resolution, and on a host with no os.date every stamp is the same word - so
-- two writes would land on one file again, which is the whole of #39. Session
-- state cannot see files written before this load, but it does cover the case
-- within one session: press WRITE PROFILE, keep sweeping, press it again.
local record_names = {}

-- Builds the record path, disambiguating against what this session already
-- wrote. First use of a name takes it as-is so the common case reads cleanly;
-- a repeat gets -2, -3, and so on.
local function record_path(dir, base)
    local name = ("%s/%s-%s"):format(dir, base, utc("!%Y%m%dT%H%M%SZ") or "unstamped")
    local used = record_names[name]
    record_names[name] = (used or 0) + 1
    if used then name = ("%s-%d"):format(name, used + 1) end
    return name .. ".json"
end

-- Writes two copies under calibration/: a stamped record named
-- <Character>-<scheme>-<patch>-<stamp>.json, and latest.json, the file
-- ComboExplorer.lua loads at startup and Provenance.apply_calibration reads.
--
-- The split is Config.write_diag's, for its reason: the record must survive a
-- re-run, because a later sweep that measures fewer values must not be the only
-- thing left on disk. Both copies were named for the BUILD rather than for the
-- run, so they replaced each other: four sweeps on build 24176760 on 2026-09-11
-- left one file. Whether any of the three lost ones witnessed something the
-- survivor did not cannot now be answered, which is the point - a record you
-- can overwrite is not a record. That is the half of #39 this closes; the half
-- that silently emptied the values block is b5dd12f.
--
-- probe_values is the block from Calibration.from_probes, merged in so one file
-- carries everything measured on this build rather than the register having to
-- be fed from two places that can disagree about which build they describe.
function M.write_profile(identity, probe_values)
    if not run then return nil, "nothing is running" end
    local rep = Calibration.conclude(run.session)

    identity = identity or {}
    identity.character = identity.character or run.character
    identity.ac_sha256 = identity.ac_sha256 or run.catalog.ac_sha256
    identity.bcm_sha256 = identity.bcm_sha256 or run.catalog.bcm_sha256
    identity.generated_at = identity.generated_at or utc("!%Y-%m-%dT%H:%M:%SZ")

    local blocks = {}
    if probe_values then blocks[#blocks + 1] = probe_values end
    blocks[#blocks + 1] = rep.values

    local path, werr = M.write_values(identity, blocks)
    if not path then return nil, werr end
    return path, rep
end

-- The write itself, without a session.
--
-- Extracted because a profile can now be produced by something other than a
-- completed sweep: the pad measurement names bits the sweep is structurally
-- unable to witness (a button that does nothing on its own produces the idle
-- id, which conclude_button_bits reads as "produced no action"). That value has
-- to reach the same file by the same route, or there are two spellings of the
-- profile and they will disagree.
--
-- blocks : a list of values blocks, later ones winning, as Calibration.document
--          takes them.
function M.write_values(identity, blocks)
    identity = identity or {}
    identity.generated_at = identity.generated_at or utc("!%Y-%m-%dT%H:%M:%SZ")

    local doc, err = Calibration.document(identity, blocks)
    if not doc then return nil, err end

    local dir = "ComboExplorer_data/calibration"
    local dirs = { "ComboExplorer_data", dir }
    local char = tostring(identity.character):gsub("[^%w_]", "")
    local base = ("%s-%s-%s"):format(char,
        tostring(identity.control_scheme or "modern"), tostring(identity.game_patch))

    local path = record_path(dir, base)
    local ok, werr = JsonIO.dump(path, doc, dirs)
    -- Refusing to go on rather than write_diag's "try both". latest.json is live
    -- configuration, not a report: if the disk is turning writes away, the
    -- previous latest.json is the last profile that loads, and truncating it
    -- would cost the operator a working calibration on top of this sweep.
    if not ok then return nil, werr end

    -- Written second for that same reason. A path is returned only because the
    -- record above actually landed; reporting one for a file that is not there
    -- would send the operator looking for it.
    JsonIO.dump(dir .. "/latest.json", doc, dirs)
    return path
end

return M
