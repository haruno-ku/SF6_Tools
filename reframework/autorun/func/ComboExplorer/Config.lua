-- =========================================================
-- ComboExplorer/Config.lua - persisted settings for the Explorer.
-- Load-once at file scope, one-level merge into defaults, debounced save.
-- Receives nothing; every other module reads Config.data.
-- =========================================================
--
-- Follows the suite's convention: paths are relative to reframework/data/,
-- fs.create_dir before dumping, and _G.safe_load_json rather than
-- json.load_file so a hand-broken config shows up in the REFramework error
-- list instead of silently reverting to defaults.

local json = json
local fs = fs

local M = { name = "ComboExplorer.Config" }

M.DIR       = "ComboExplorer_data"
M.FILE      = "ComboExplorer_data/Config.json"
M.DIAG_DIR  = "ComboExplorer_data/diagnostics"

-- Every value the Explorer can be told to do differently. Kept flat: a
-- one-level merge is enough and keeps a partial user file from dropping
-- fields added in a later version.
local DEFAULTS = {
    -- Master switch, independent of the training mode. Both must be on.
    enabled = true,

    -- Nothing writes an input mask unless this is true AND a session is
    -- explicitly started from the panel. The read-only diagnostics build does
    -- not need it at all.
    allow_injection = false,

    -- Sequence shape, in Explorer TICKS (see Clock.lua - not necessarily
    -- game frames until Phase 1 calibration says so).
    lead_ticks = 3,
    hold_ticks = 3,
    tail_ticks = 5,

    -- Reset settle gate. Upstream's own numbers: 10 position-correction
    -- retries and a 15-frame grace before the combo counter can be trusted.
    settle_ticks = 25,
    position_retries = 15,
    position_tolerance = 0.5,
    reset_grace_ticks = 15,

    -- Midscreen start, in the training menu's centimetre units.
    manual_pos_p1 = -150,
    manual_pos_p2 = 150,

    -- Diagnostics
    diag_sample_frames = 600,
    write_diag_files = true,
}

M.data = {}
for k, v in pairs(DEFAULTS) do M.data[k] = v end
M.DEFAULTS = DEFAULTS

local dirty = false
local save_timer = 0

function M.load()
    local loaded
    if type(_G.safe_load_json) == "function" then
        local ok, r = pcall(_G.safe_load_json, M.FILE)
        loaded = ok and r or nil
    elseif json and json.load_file then
        local ok, r = pcall(json.load_file, M.FILE)
        loaded = ok and r or nil
    end
    if type(loaded) == "table" then
        -- Only keys we know about: an unknown key in the file is either a typo
        -- or a leftover from a newer build, and neither should reach the rest
        -- of the code as if it meant something.
        for k, _ in pairs(DEFAULTS) do
            if loaded[k] ~= nil then M.data[k] = loaded[k] end
        end
    end
    return M.data
end

function M.save()
    if fs and fs.create_dir then pcall(fs.create_dir, M.DIR) end
    pcall(json.dump_file, M.FILE, M.data)
    dirty = false
end

-- UI edits call this; the actual write is debounced so dragging a slider does
-- not write the file once per frame.
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

-- Diagnostic reports are the whole feedback loop for the two-machine setup:
-- written on the machine running SF6, committed, and read back on the dev
-- machine. Timestamped by frame rather than wall clock so the filename stays
-- stable when the same probe is re-run.
function M.write_diag(name, payload)
    if not M.data.write_diag_files then return nil end
    if fs and fs.create_dir then
        pcall(fs.create_dir, M.DIR)
        pcall(fs.create_dir, M.DIAG_DIR)
    end
    local path = M.DIAG_DIR .. "/" .. tostring(name) .. ".json"
    local ok = pcall(json.dump_file, path, payload)
    return ok and path or nil
end

M.load()

return M
