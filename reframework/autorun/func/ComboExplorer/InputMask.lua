-- =========================================================
-- ComboExplorer/InputMask.lua - notation <-> pl_input_new bitmask.
-- Pure functions only: no sdk, no hooks, no state. Unit-tested under a real
-- Lua 5.4 interpreter (tests/lua/test_inputmask.lua).
-- =========================================================
--
-- DIRECTION BITS
--
-- UP=1, DOWN=2, LEFT=4, RIGHT=8. Two independent readers in the suite agree on
-- this: ComboTrials_D2D.lua:288-297 decodes `l = val & 4` / `r = val & 8`, and
-- SF6_RecordingSlotManager.lua:106-110 maps numpad "4"->4 and "6"->8.
--
-- One table disagrees: RSM's own MASKS (:450), used by encode_from_numpad /
-- decode_to_numpad for record-SLOT timelines, has RIGHT=4 / LEFT=8. That path
-- is the dummy's slot buffer, not pl_input_new, and the Explorer never touches
-- it -- but reusing that table here would produce mirrored inputs that look
-- almost right and fail intermittently depending on side. Do not.
--
-- MODERN BUTTON BITS
--
-- Modern's five buttons sit on classic bit positions with different meanings.
-- From ComboTrials_D2D.lua:299-321, whose comment says "probed in-game":
--
--   bit    classic   modern
--   0x10   LP        L (light)
--   0x20   MP        SP (special)
--   0x40   HP        Drive Parry   (0x40|0x04 = Drive Rush)
--   0x80   LK        M (medium)
--   0x100  MK        H (heavy)
--   0x200  HK        Assist (AUTO)
--   0x1000 -         Drive Impact
--   0x2000 -         Throw
--
-- That table exists only in display code -- nothing in the suite has ever
-- INJECTED with it. It is corroborated by command_display's routes[].
-- raw_button_mask (L=16, M=128, H=256, SP=32, THROW=144=L|M), which is why it
-- is trusted enough to build on, but Phase 1 calibration confirms it on the
-- real game before any dataset is recorded against it.

local M = { name = "ComboExplorer.InputMask" }

-- --- bit tables --------------------------------------------------------------

M.DIR = {
    UP = 1, DOWN = 2, LEFT = 4, RIGHT = 8,
}

-- numpad digit -> direction mask
M.NUMPAD = {
    ["5"] = 0,
    ["8"] = 1,          -- up
    ["2"] = 2,          -- down
    ["4"] = 4,          -- back
    ["6"] = 8,          -- forward
    ["7"] = 1 | 4,      -- 5
    ["9"] = 1 | 8,      -- 9
    ["1"] = 2 | 4,      -- 6
    ["3"] = 2 | 8,      -- 10
}

M.MODERN = {
    L      = 0x10,
    M      = 0x80,
    H      = 0x100,
    SP     = 0x20,
    AUTO   = 0x200,   -- Assist
    PARRY  = 0x40,
    DI     = 0x1000,
    THROW  = 0x2000,
}

M.CLASSIC = {
    LP = 0x10, MP = 0x20, HP = 0x40,
    LK = 0x80, MK = 0x100, HK = 0x200,
}

M.DIR_BITS = 0x0F
M.BTN_BITS = 0xFFF0

-- Display tokens used by command_display / ModernDisplay. The Chinese byte
-- sequences contain no Lua-pattern magic characters, so plain string matching
-- on them is safe (same reasoning as ModernDisplay.lua:56-58).
M.TOKENS = {
    ["\229\188\177"] = "L",       -- 弱 light
    ["\228\184\173"] = "M",       -- 中 medium
    ["\229\188\186"] = "H",       -- 强 heavy
    ["SP"]           = "SP",
    ["AUTO"]         = "AUTO",
    ["THROW"]        = "THROW",
    ["DI"]           = "DI",
}
M.AIR_TOKEN = "\231\169\186\228\184\173"   -- 空中 "in the air"
M.ANY_TOKEN = "\228\187\187\230\132\143\233\148\174"  -- 任意键 "any button"

-- --- direction ---------------------------------------------------------------

-- "360" and "720" are circle shorthands, not numpad sequences -- taken
-- literally they contain a "0", which is not a direction at all. Expansions are
-- upstream's, from the execution drill's MOTIONS table
-- (TrainingMoveExecution.lua:245-255), so a Zangief SPD is driven with exactly
-- the input the suite already knows works.
M.MOTIONS = {
    ["360"] = { 8, 10, 2, 6, 4, 5, 1 },
    ["720"] = { 8, 10, 2, 6, 4, 5, 1, 9, 8, 2, 4 },
}

-- "2" -> {2}, "236" -> {2, 10, 8}, "360" -> the circle above. Returns a LIST
-- because a motion is played one direction per tick; a single direction is
-- just a list of one.
function M.dirs_from_numpad(s)
    if type(s) ~= "string" then return nil, "not a string" end

    local shorthand = M.MOTIONS[s]
    if shorthand then
        local copy = {}
        for i, v in ipairs(shorthand) do copy[i] = v end
        return copy
    end

    local out = {}
    for d in s:gmatch("%d") do
        local m = M.NUMPAD[d]
        if m == nil then return nil, "unknown numpad digit: " .. d end
        out[#out + 1] = m
    end
    if #out == 0 then return nil, "no digits" end
    return out
end

-- --- notation parsing --------------------------------------------------------

-- Parses a command_display motion/simple string into its parts. Handles the
-- Chinese strength tokens and the air / any-button markers.
--
--   "2 + 中"        -> { dirs = {2},  buttons = {"M"} }
--   "3 + 强"        -> { dirs = {10}, buttons = {"H"} }
--   "SP"            -> { dirs = {},   buttons = {"SP"} }
--   "AUTO + 弱"     -> { dirs = {},   buttons = {"AUTO","L"}, assist = true }
--   "空中 360 + 强" -> { air = true, dirs = {8,10,2,6,4,5,1}, buttons = {"H"} }
--   "236236 + 中"   -> { dirs = {2,10,8,2,10,8}, buttons = {"M"} }
--
-- Returns nil, reason when the string carries no usable input (e.g. it is a
-- pure label like "RAW DR").
function M.parse(display)
    if type(display) ~= "string" or display == "" then
        return nil, "empty"
    end

    local s = display
    local out = { air = false, any_button = false, assist = false,
                  followup = false, dirs = {}, buttons = {}, raw = display }

    -- A leading ">" marks a target-combo / follow-up derivation: it only comes
    -- out after a specific preceding action, so it can never be produced by a
    -- standalone probe. Flagged here so the catalog can exclude it explicitly
    -- rather than silently recording it as a move that "does not work".
    local stripped = s:match("^%s*>%s*(.*)$")
    if stripped then
        out.followup = true
        s = stripped
    end

    if s:find(M.AIR_TOKEN, 1, true) then
        out.air = true
        s = s:gsub(M.AIR_TOKEN, " ")
    end
    if s:find(M.ANY_TOKEN, 1, true) then
        out.any_button = true
        s = s:gsub(M.ANY_TOKEN, " ")
    end

    -- Longest-first so AUTO is not shadowed by a shorter token.
    local order = { "AUTO", "THROW", "SP", "DI",
                    "\229\188\177", "\228\184\173", "\229\188\186" }
    for _, tok in ipairs(order) do
        -- A token can legitimately appear more than once ("任意键 + 任意键").
        while s:find(tok, 1, true) do
            local name = M.TOKENS[tok]
            out.buttons[#out.buttons + 1] = name
            if name == "AUTO" then out.assist = true end
            s = s:gsub(tok, " ", 1)
        end
    end

    -- Whatever digits remain are the motion. Done last so button tokens cannot
    -- contribute stray digits.
    local digits = s:gsub("[^%d]", "")
    if digits ~= "" then
        local dirs, err = M.dirs_from_numpad(digits)
        if not dirs then return nil, err end
        out.dirs = dirs
    end

    if #out.buttons == 0 and #out.dirs == 0 and not out.any_button then
        return nil, "no input tokens in: " .. display
    end
    return out
end

-- --- mask building -----------------------------------------------------------

-- Button names -> mask, under the Modern layout. Unknown names are reported
-- rather than silently dropped: a silently-dropped button is a whiffed trial
-- that looks like "this link does not work".
function M.modern_button_mask(names)
    local mask = 0
    for _, n in ipairs(names or {}) do
        local bit = M.MODERN[n]
        if bit == nil then return nil, "unknown modern button: " .. tostring(n) end
        mask = mask | bit
    end
    return mask
end

function M.classic_button_mask(names)
    local mask = 0
    for _, n in ipairs(names or {}) do
        local bit = M.CLASSIC[n]
        if bit == nil then return nil, "unknown classic button: " .. tostring(n) end
        mask = mask | bit
    end
    return mask
end

-- --- facing ------------------------------------------------------------------

-- Masks are authored in NUMPAD (player-relative) terms: bit 4 is "back", bit 8
-- is "forward". pl_input_new wants screen-absolute bits, so when the player
-- faces left the two swap.
--
-- Polarity note: three P1 writers agree on `if not rl_dir then swap`
-- (RSM:1993, TrainingMoveExecution:299, ComboTrials:6843) and only
-- SharedHooks.write_p2_input_mask (:179-186) swaps on truthy -- and that one is
-- the P2 path. We follow the P1 majority, and Phase 1 confirms it on both
-- sides before any dataset is recorded.
function M.mirror(mask, facing_right)
    if facing_right then return mask end
    local left  = (mask & M.DIR.LEFT)  ~= 0
    local right = (mask & M.DIR.RIGHT) ~= 0
    mask = mask & ~(M.DIR.LEFT | M.DIR.RIGHT)
    if left  then mask = mask | M.DIR.RIGHT end
    if right then mask = mask | M.DIR.LEFT end
    return mask
end

-- --- readback ----------------------------------------------------------------

local NUMPAD_OF = {}
for digit, m in pairs(M.NUMPAD) do
    if m ~= 0 then NUMPAD_OF[m] = digit end
end
NUMPAD_OF[0] = "5"

function M.numpad_of(mask)
    return NUMPAD_OF[mask & M.DIR_BITS] or "?"
end

-- Human-readable form of a raw mask, for logs and the diagnostics panel.
-- is_modern picks which button vocabulary to name the bits with.
function M.describe(mask, is_modern)
    mask = mask or 0
    local parts = { M.numpad_of(mask) }
    local order = is_modern
        and { { "L", 0x10 }, { "M", 0x80 }, { "H", 0x100 }, { "SP", 0x20 },
              { "AUTO", 0x200 }, { "PARRY", 0x40 }, { "DI", 0x1000 }, { "THROW", 0x2000 } }
        or  { { "LP", 0x10 }, { "MP", 0x20 }, { "HP", 0x40 },
              { "LK", 0x80 }, { "MK", 0x100 }, { "HK", 0x200 } }
    for _, e in ipairs(order) do
        if (mask & e[2]) ~= 0 then parts[#parts + 1] = e[1] end
    end
    return table.concat(parts, "+")
end

-- --- sequence compilation ----------------------------------------------------

-- Turns a parsed notation into a list of { frames = n, mask = m } steps, using
-- the shape upstream's execution drill uses (TrainingMoveExecution:274-284):
-- a neutral lead-in, one tick per motion digit, the final digit held with the
-- buttons, and a neutral tail.
--
-- `frames` is in Explorer TICKS, not necessarily game frames -- see Clock.lua.
function M.compile(parsed, opts)
    if type(parsed) ~= "table" then return nil, "not a parsed notation" end
    opts = opts or {}
    local lead  = opts.lead_ticks  or 3
    local hold  = opts.hold_ticks  or 3
    local tail  = opts.tail_ticks  or 5
    local is_modern = opts.modern ~= false

    -- "任意键" (any button) is a display convenience for moves that accept more
    -- than one strength -- an OD or super where the notation cannot name one.
    -- There is no such thing as pressing "any", so refuse rather than emit a
    -- direction-only sequence that silently whiffs. The caller picks a concrete
    -- strength and re-parses.
    if parsed.any_button and #parsed.buttons == 0 then
        return nil, "any-button notation needs an explicit button: " .. tostring(parsed.raw)
    end

    local btn, err = is_modern and M.modern_button_mask(parsed.buttons)
                                or M.classic_button_mask(parsed.buttons)
    if btn == nil then return nil, err end

    local seq = {}
    if lead > 0 then seq[#seq + 1] = { frames = lead, mask = 0 } end

    local dirs = parsed.dirs or {}
    if #dirs == 0 then
        seq[#seq + 1] = { frames = hold, mask = btn }
    else
        for i = 1, #dirs do
            if i < #dirs then
                seq[#seq + 1] = { frames = 1, mask = dirs[i] }
            else
                seq[#seq + 1] = { frames = hold, mask = dirs[i] | btn }
            end
        end
    end

    if tail > 0 then seq[#seq + 1] = { frames = tail, mask = 0 } end
    return seq
end

-- Flattens a step list into one mask per tick, which is what the injector
-- consumes (mirroring upstream's raw_inputs array).
function M.expand(seq)
    local out = {}
    for _, step in ipairs(seq or {}) do
        for _ = 1, (step.frames or 0) do
            out[#out + 1] = step.mask or 0
        end
    end
    return out
end

return M
