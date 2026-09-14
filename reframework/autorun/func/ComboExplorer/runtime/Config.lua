-- =========================================================
-- ComboExplorer/runtime/Config.lua - user preferences and artifact writing.
-- Load-once at file scope, one-level merge into defaults, debounced save.
-- =========================================================
--
-- WHAT DOES *NOT* LIVE HERE
--
-- Anything nobody has measured. Settle times, retry counts, button bits and the
-- rest are in core/Provenance.lua, where they carry a status and a provenance
-- string and can be promoted by a calibration result. Keeping them out of the
-- config file matters: after a merge, a value read from JSON is indistinguishable
-- from a default and from a measured result, so a config file is the one place
-- an unverified number must never be able to hide.
--
-- What is left here is genuine preference: what the operator wants the tool to
-- do, not what the game does.

local JsonIO = require("func/ComboExplorer/runtime/JsonIO")

local M = { name = "ComboExplorer.Config" }

-- The only two things in this file that need a game under them. Swapped by the
-- tests, which is the whole reason they are named rather than called directly:
-- nothing else here touches sdk, re, imgui, json or fs, so everything else is
-- checkable on a machine with no Street Fighter on it.
M.io = JsonIO

M.DIR      = "ComboExplorer_data"
M.FILE     = "ComboExplorer_data/Config.json"
M.DIAG_DIR = "ComboExplorer_data/diagnostics"

local DEFAULTS = {
    -- Master switch, independent of the training mode. Both must be on.
    enabled = true,

    -- Nothing writes an input mask unless this is true AND the Provenance
    -- register says the injection capability is available. Belt and braces: the
    -- register is the real gate, this is the operator's own off switch.
    allow_injection = false,

    -- Diagnostics
    write_diag_files = true,
    probe_a_idle_ticks = 20,   -- provisional; every sample records what was used

    -- How many combos probe A wants before it is willing to recommend anything.
    probe_a_min_samples = 3,
    -- How many usable frames probe B wants before its histogram means anything.
    probe_b_min_frames = 300,
}

M.DEFAULTS = DEFAULTS
M.data = {}
for k, v in pairs(DEFAULTS) do M.data[k] = v end

-- Where each live value came from, so the panel and the artifacts can say so.
M.source = {}
for k in pairs(DEFAULTS) do M.source[k] = "default" end

local dirty = false
local save_timer = 0

-- `loaded` : the already-decoded contents, for a caller that has them. Omitted,
-- the file is read. The merge below is the part worth checking and it does not
-- care where the table came from.
function M.load(loaded)
    if loaded == nil then loaded = M.io.load(M.FILE) end
    if type(loaded) ~= "table" then return M.data end

    for k, default in pairs(DEFAULTS) do
        local v = loaded[k]
        -- Type-checked, not just present: a hand-edited config that turns a
        -- number into a string would otherwise reach arithmetic and throw
        -- inside a hook, where the error is swallowed.
        if v ~= nil and type(v) == type(default) then
            M.data[k] = v
            M.source[k] = "config file"
        elseif v ~= nil then
            M.source[k] = ("ignored: %s in file, %s expected"):format(type(v), type(default))
        end
    end
    return M.data
end

function M.save()
    M.io.dump(M.FILE, M.data, { M.DIR })
    dirty = false
end

function M.mark_dirty()
    dirty = true
    save_timer = 60
end

function M.tick_save()
    if not dirty then return end
    if save_timer > 0 then
        save_timer = save_timer - 1
        return
    end
    M.save()
end

-- --- artifacts ---------------------------------------------------------------

-- os.date through pcall, because a host that does not hand this Lua state an os
-- table must lose the ordering, not the write. The lookup of `os.date` is inside
-- the protected call too: `pcall(os.date, ...)` evaluates os.date BEFORE pcall
-- is entered, so with no os table at all it threw instead of degrading, which
-- is the one host this was written for. Returns nil rather than a placeholder
-- so the caller decides what an absent clock means for the field it is filling.
function M.utc(fmt)
    local ok, s = pcall(function() return os.date(fmt) end)
    if ok and type(s) == "string" then return s end
    return nil
end

local function stamp()
    return M.utc("!%Y%m%dT%H%M%SZ") or "unstamped"
end

-- Record names already handed out in this session, as a set of full paths
-- without the extension.
--
-- A stamp on its own does not make a name unique. It has one-second
-- resolution, and on a host with no os.date every stamp is the same word - so
-- two writes land on one file, and the record the older one was written to
-- keep is gone. That is #39 for the calibration profile and #42 for the
-- diagnostics; this is the one answer to both.
--
-- THE LIMIT: session state cannot see files written before this load. A record
-- written in the previous session under the same second - or, on a host with
-- no clock, under "unstamped" at any time at all - is still replaced by the
-- first write of this one. Closing that needs a directory listing, and fs.glob
-- is not something every host has (see JsonIO.can_glob). What this does cover
-- is the case within one session: press WRITE, keep going, press it again.
local handed_out = {}

-- A record path of the form <dir>/<base>-<stamp>.json that nothing earlier in
-- this session was given. The first use of a name takes it as-is so the common
-- case reads cleanly; a repeat gets -2, -3, and so on.
--
-- The loop, rather than a counter per stamped name, is because a suffixed name
-- is itself a name: base "x" at stamp S with -2 appended must not be handed out
-- again to anything else that happens to spell "x-S-2".
function M.record_path(dir, base)
    local stem = ("%s/%s-%s"):format(tostring(dir), tostring(base), stamp())
    local name, n = stem, 1
    while handed_out[name] do
        n = n + 1
        name = ("%s-%d"):format(stem, n)
    end
    handed_out[name] = true
    return name .. ".json"
end

-- Every artifact carries the context needed to attribute it, because the person
-- who reads it is on a different machine and cannot ask.
--
-- Without this a verdict measured on last month's patch is indistinguishable
-- from today's, and when action ids shift there is no field to invalidate
-- against.
function M.header(ctx)
    ctx = ctx or {}
    return {
        mod_version   = ctx.version,
        written_at    = stamp(),
        game_patch    = ctx.game_patch,
        calibration_id = ctx.calibration_id,
        frame         = ctx.frame,
        anchor_hooked = ctx.anchor_hooked,
        p1 = ctx.p1,
        p2 = ctx.p2,
        p1_control_scheme = ctx.p1_control_scheme,
        -- Which command_display the session was reading, by checksum. An action
        -- id is only meaningful against one AC/BCM pair, so this is the field a
        -- later build is invalidated against.
        catalog = ctx.catalog,
        provenance = ctx.provenance,
        config = {
            probe_a_idle_ticks  = M.data.probe_a_idle_ticks,
            probe_a_min_samples = M.data.probe_a_min_samples,
            probe_b_min_frames  = M.data.probe_b_min_frames,
            sources = M.source,
        },
    }
end

-- Writes an artifact under a timestamped name AND under a stable "latest" name.
--
-- The timestamped copy is the record: a re-run after a patch must not silently
-- destroy the sample that led to a decision. The latest copy is the convenience,
-- so the path in a README stays true.
--
-- The record name comes from M.record_path and not from the stamp alone. The
-- stamp is to the second, so two WRITE presses inside one second - or every
-- press, on a host with no clock - took the same name and the second replaced
-- the first: exactly the silent loss the record copy exists to prevent (#42).
function M.write_diag(name, payload, ctx)
    if not M.data.write_diag_files then return nil, "diagnostic writing is off" end

    local doc = { header = M.header(ctx), body = payload }
    local dirs = { M.DIR, M.DIAG_DIR }

    local stamped = M.record_path(M.DIAG_DIR, tostring(name))
    local latest  = ("%s/%s-latest.json"):format(M.DIAG_DIR, tostring(name))

    local ok_stamped, err_stamped = M.io.dump(stamped, doc, dirs)
    local ok_latest = M.io.dump(latest, doc, dirs)

    -- Reporting a path when nothing was written is worse than reporting the
    -- failure: the operator would go looking for a file that is not there.
    if not ok_stamped and not ok_latest then
        return nil, tostring(err_stamped or "write failed")
    end
    return (ok_stamped and stamped or latest)
end

M.load()

return M
