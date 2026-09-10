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

local GameAdapter = require("func/ComboExplorer/runtime/GameAdapter")
local JsonIO      = require("func/ComboExplorer/runtime/JsonIO")

local M = { name = "ComboExplorer.CalibrationRunner" }

local run = nil          -- the live run, or nil
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
            local p1 = GameAdapter.player(0)
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
function M.start(reg, opts)
    opts = opts or {}
    if run then return nil, "a calibration is already running" end

    local info = GameAdapter.character(0)
    if not info then return nil, "P1 is not resolved yet - start a battle first" end

    local raw, err = M.load_catalog(info)
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

function M.stop()
    pending_mask, pending_mirror = nil, nil
    run = nil
end

function M.running() return run ~= nil end

-- Resolved the same way Probe D does it, and for the same reason: on this build
-- the character enum's ToString() returns the internal key, so the display name
-- is not a filename. See ComboExplorer.lua's resolve_catalog.
function M.load_catalog(info)
    local DIR = "TrainingComboTrials_data/command_display/"
    local name = info.name and tostring(info.name) or ""
    local key = (name:gsub("[^%w_]", ""))
    if key ~= "" and key ~= "Unknown" and not key:match("^ESF_%d+$") then
        local decoded = JsonIO.load(DIR .. key .. ".json")
        if type(decoded) == "table" then return decoded end
    end

    local id = tonumber(info.id)
    if not id or not (fs and fs.glob) then
        return nil, ("P1 reports as %q and there is no way to find its catalog"):format(name)
    end
    local ok, files = pcall(fs.glob, "TrainingComboTrials_data\\\\command_display\\\\.*json")
    if not ok or type(files) ~= "table" then return nil, "could not list " .. DIR end
    for _, path in ipairs(files) do
        local decoded = JsonIO.load(path)
        local meta = type(decoded) == "table" and decoded._meta
        if type(meta) == "table" and tonumber(meta.fighter_id) == id then return decoded end
    end
    return nil, ("no shipped catalog claims fighter_id %d"):format(id)
end

-- One battle frame. Driven from Clock.on_frame, which is the anchor Probe B
-- validated - NOT from the input callback, which is a different clock and the
-- one this build is not allowed to assume things about.
function M.tick()
    if not run then return end
    local snap = GameAdapter.snapshot(0)
    if not snap then return end

    run.ticks = run.ticks + 1
    local cmd = Fsm.tick(run.fsm, {
        action_id = snap.attacker_action_id,
        own_pos = snap.attacker_pos,
        opponent_pos = snap.victim_pos,
        -- The raw field, not an interpretation of it. Which truth value means
        -- "mirrored" is rl_dir_polarity, which is what the sweep is measuring.
        rl_dir = snap.attacker_rl_dir_raw,
        can_inject = GameAdapter.can_inject(),
    })

    pending_mask = cmd.write_mask
    pending_mirror = cmd.mirror
    run.last_note = cmd.note
    run.last_state = cmd.state
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

-- Writes calibration/<Character>/<scheme>-<patch>.json, the file
-- Provenance.apply_calibration reads back.
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
    identity.generated_at = identity.generated_at or os.date("!%Y-%m-%dT%H:%M:%SZ")

    local blocks = {}
    if probe_values then blocks[#blocks + 1] = probe_values end
    blocks[#blocks + 1] = rep.values

    local doc, err = Calibration.document(identity, blocks)
    if not doc then return nil, err end

    local dir = "ComboExplorer_data/calibration"
    local char = tostring(identity.character):gsub("[^%w_]", "")
    local path = ("%s/%s-%s-%s.json"):format(dir, char,
        tostring(identity.control_scheme or "modern"), tostring(identity.game_patch))

    local ok, werr = JsonIO.dump(path, doc, { "ComboExplorer_data", dir })
    if not ok then return nil, werr end

    -- latest.json is what ComboExplorer.lua loads at startup. Written second so
    -- a failure above leaves the previous one intact rather than truncated.
    JsonIO.dump(dir .. "/latest.json", doc, { "ComboExplorer_data", dir })
    return path, rep
end

return M
