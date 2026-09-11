-- =========================================================
-- ComboExplorer/core/InputMask.lua - notation <-> pl_input_new bitmask.
-- Pure. No sdk, no re, no imgui, no json. Unit-tested under Lua 5.4.
-- =========================================================
--
-- THE BIT TABLES ARE NOT IN THIS FILE
--
-- Which bit is "Modern Medium", which bit is "left", and which truth value of
-- rl_dir means "mirror" are all things nobody has measured on this build. They
-- live in core/Provenance.lua as unverified entries, and reach this module as a
-- PROFILE argument.
--
-- That indirection is the whole point. If the bits were constants here, every
-- function would silently produce masks from a guess, and a wrong guess does
-- not raise an error - it presses a button that does not exist, the move never
-- comes out, and the trial is recorded as "these moves do not link". A
-- confident negative, indistinguishable from a real one. So compile() refuses a
-- profile that has not been verified unless the caller explicitly says it is
-- doing something read-only.
--
-- Provisional values and their provenance: see core/Provenance.lua. The short
-- version is that the Modern bit table exists only in upstream DISPLAY code
-- (ComboTrials_D2D.lua:299-321) and has never been used to inject anything.

local M = { name = "ComboExplorer.InputMask" }

M.DIR_BITS = 0x0F
M.BTN_BITS = 0xFFF0

-- --- profiles ----------------------------------------------------------------

-- The numpad layout is derived from the four direction bits rather than listed,
-- so there is exactly one place a direction bit is written down.
--
-- Masks built here are PLAYER-RELATIVE and oriented as if facing right: numpad
-- 4 is "back" and maps to the LEFT bit. mirror() converts to the
-- screen-absolute form pl_input_new wants.
local function build_numpad(dir)
    return {
        ["5"] = 0,
        ["8"] = dir.UP,
        ["2"] = dir.DOWN,
        ["4"] = dir.LEFT,
        ["6"] = dir.RIGHT,
        ["7"] = dir.UP | dir.LEFT,
        ["9"] = dir.UP | dir.RIGHT,
        ["1"] = dir.DOWN | dir.LEFT,
        ["3"] = dir.DOWN | dir.RIGHT,
    }
end

-- Circle shorthands are written as numpad sequences, not as literal masks, so
-- they too derive from the profile. Expansions match upstream's execution-drill
-- MOTIONS table (TrainingMoveExecution.lua:245-255) exactly, which is the input
-- the suite already drives a Zangief SPD with.
M.MOTION_SHORTHAND = {
    ["360"] = "6321478",
    ["720"] = "63214789624",
}

-- Builds the profile every other function in this module takes.
--
--   buttons  : name -> bit, for the active control scheme
--   dir      : { UP, DOWN, LEFT, RIGHT } bits
--   mirror_when : "falsy" | "truthy" - which rl_dir value means mirror
--   status   : carried through from Provenance so compile() can refuse
local function is_single_bit(n)
    return type(n) == "number" and n > 0 and math.floor(n) == n and (n & (n - 1)) == 0
end

local function measured_from(opts)
    if opts.measured ~= nil then return opts.measured end
    return opts.status == "verified"
end

function M.profile(opts)
    opts = opts or {}
    local dir = opts.dir
    if type(dir) ~= "table" or not (dir.UP and dir.DOWN and dir.LEFT and dir.RIGHT) then
        return nil, "profile needs dir = { UP, DOWN, LEFT, RIGHT }"
    end
    -- A calibration file is hand-writable, and a direction that is not a single
    -- distinct bit produces masks that look plausible and behave wrongly: two
    -- directions sharing a bit means one of them can never be expressed.
    local seen = {}
    for _, name in ipairs({ "UP", "DOWN", "LEFT", "RIGHT" }) do
        local bit = dir[name]
        if not is_single_bit(bit) then
            return nil, ("direction %s is %s, expected a single bit"):format(name, tostring(bit))
        end
        if seen[bit] then
            return nil, ("directions %s and %s share bit %d"):format(seen[bit], name, bit)
        end
        seen[bit] = name
    end

    if type(opts.buttons) ~= "table" then
        return nil, "profile needs a buttons table"
    end
    for name, bit in pairs(opts.buttons) do
        if type(bit) ~= "number" or bit <= 0 or math.floor(bit) ~= bit then
            return nil, ("button %s is %s, expected a positive integer bitmask")
                :format(tostring(name), tostring(bit))
        end
    end

    local mirror_when = opts.mirror_when or "falsy"
    if mirror_when ~= "falsy" and mirror_when ~= "truthy" then
        return nil, "mirror_when must be 'falsy' or 'truthy'"
    end
    return {
        buttons = opts.buttons,
        dir = dir,
        numpad = build_numpad(dir),
        mirror_when = mirror_when,
        status = opts.status or "unverified",
        buttons_underivable = opts.buttons_underivable,
        -- Whether anybody has LOOKED at the three values behind this profile,
        -- as opposed to whether their guesses survived. The gates want this
        -- one. A profile built by hand says so explicitly; one built from a
        -- register has it computed in profile_from_provenance.
        --
        -- Written as a branch, not `(opts.measured ~= nil) and opts.measured or
        -- ...`: an explicit `false` would fall straight through that `or` to the
        -- status test, so a caller saying "this was not measured" would be
        -- overruled by a status that happened to read "verified".
        measured = measured_from(opts),
        scheme = opts.scheme or "modern",
        source = opts.source,
    }
end

-- Assembles a profile out of a Provenance register. Uses provisional values
-- when they are not verified yet, and carries the WORST status through, so a
-- caller cannot end up with a profile that looks trustworthy because two of its
-- three inputs happened to be measured.
--
-- "Worst" used to be whichever non-verified status came LAST in the loop. There
-- was no rank and no comparison, so the answer depended on argument position:
--
--     refuted, unverified, verified  ->  unverified   (a measurement lost to a guess)
--     unverified, refuted, verified  ->  refuted      (same pair, opposite answer)
--
-- It is a comparison now, over Provenance.STATUS_RANK.
--
-- The profile also carries `measured`, which is the question every gate
-- downstream is actually asking. "Did the guess survive" and "has anyone
-- looked" are different, and three gates were asking the first while meaning
-- the second - so a fully measured register whose guess had been corrected
-- opened the injection capability and then refused to compile a single input.
function M.profile_from_provenance(P, reg, scheme)
    scheme = scheme or "modern"
    local buttons, bstatus = P.provisional(reg, "modern_button_bits")
    local dir, dstatus     = P.provisional(reg, "direction_bits")
    local pol, pstatus     = P.provisional(reg, "rl_dir_polarity")

    local bits_entry = P.get(reg, "modern_button_bits")
    local underivable = bits_entry and bits_entry.unwitnessed or nil

    local status, worst = nil, math.huge
    local measured = true
    for _, st in ipairs({ bstatus, dstatus, pstatus }) do
        local rank = P.rank(st)
        -- A status the register does not know is the least settled thing there
        -- is. Ranking it below unverified rather than ignoring it keeps an
        -- unrecognised string from being quietly treated as good news.
        if rank == nil then rank = -1 end
        if rank < worst then worst, status = rank, st end
        if rank < P.rank(P.STATUS.REFUTED) then measured = false end
    end

    -- Named explicitly rather than defaulted. A polarity string nobody
    -- recognises would otherwise silently become "falsy", which is the one
    -- error that produces a dataset half of which is mirrored - and that reads
    -- as flaky links rather than as a bug.
    local mirror_when
    if pol == "mirror_when_falsy" then mirror_when = "falsy"
    elseif pol == "mirror_when_truthy" then mirror_when = "truthy"
    else
        return nil, ("rl_dir_polarity is %q, expected mirror_when_falsy or mirror_when_truthy")
            :format(tostring(pol))
    end

    return M.profile({
        buttons = buttons,
        dir = dir,
        mirror_when = mirror_when,
        status = status,
        measured = measured,
        -- Buttons the sweep could not witness, so the map genuinely has no bit
        -- for them. button_mask already refuses an unknown name; this is what
        -- lets the refusal say WHY instead of just that the name is unknown.
        buttons_underivable = underivable,
        scheme = scheme,
        source = "provenance:" .. tostring(reg.calibration_id or "none"),
    })
end

-- --- notation tokens ---------------------------------------------------------

-- Display tokens used by command_display / ModernDisplay. The Chinese byte
-- sequences carry no Lua-pattern magic characters, so plain literal matching on
-- them is safe (same reasoning as ModernDisplay.lua:56-58).
M.TOKENS = {
    ["\229\188\177"] = "L",       -- 弱 light
    ["\228\184\173"] = "M",       -- 中 medium
    ["\229\188\186"] = "H",       -- 强 heavy
    ["SP"]           = "SP",
    ["AUTO"]         = "AUTO",
    ["THROW"]        = "THROW",
    ["DI"]           = "DI",
}
M.AIR_TOKEN = "\231\169\186\228\184\173"                -- 空中  "in the air"
M.ANY_TOKEN = "\228\187\187\230\132\143\233\148\174"    -- 任意键 "any button"

-- Longest-first so AUTO is not shadowed by a shorter token.
local TOKEN_ORDER = { "AUTO", "THROW", "SP", "DI",
                      "\229\188\177", "\228\184\173", "\229\188\186" }

-- --- direction ---------------------------------------------------------------

-- "2" -> {2}, "236" -> {2, 10, 8}, "360" -> the circle. Returns a LIST because a
-- motion is played one direction per tick; a single direction is a list of one.
function M.dirs_from_numpad(s, profile)
    if type(s) ~= "string" then return nil, "not a string" end
    if type(profile) ~= "table" or not profile.numpad then return nil, "no profile" end

    local expanded = M.MOTION_SHORTHAND[s] or s

    local out = {}
    for d in expanded:gmatch("%d") do
        local m = profile.numpad[d]
        if m == nil then return nil, "unknown numpad digit: " .. d end
        out[#out + 1] = m
    end
    if #out == 0 then return nil, "no digits" end
    return out
end

-- --- notation parsing --------------------------------------------------------

-- Parsing is profile-independent: it says WHAT was asked for, in names, without
-- committing to any bit values. That is what makes the Catalog buildable before
-- a single value has been measured.
--
--   "2 + 中"        -> { dirs = "2",   buttons = {"M"} }
--   "SP"            -> { dirs = "",    buttons = {"SP"} }
--   "AUTO + 弱"     -> { buttons = {"AUTO","L"}, assist = true }
--   "空中 360 + 强" -> { air = true, dirs = "360", buttons = {"H"} }
--   "> 中"          -> { followup = true, buttons = {"M"} }
--
-- Returns nil, reason for a string carrying no input at all (a pure label like
-- "RAW DR").
function M.parse(display)
    if type(display) ~= "string" or display == "" then
        return nil, "empty"
    end

    local s = display
    local out = { air = false, any_button = false, assist = false,
                  followup = false, dirs = "", buttons = {}, raw = display }

    -- A leading ">" marks a target-combo / follow-up derivation: it only comes
    -- out after a specific preceding action, so a standalone probe can never
    -- produce it. Flagged so the catalog can exclude it explicitly rather than
    -- silently recording it as a move that "does not work".
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

    for _, tok in ipairs(TOKEN_ORDER) do
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
    out.dirs = s:gsub("[^%d]", "")

    if #out.buttons == 0 and out.dirs == "" and not out.any_button then
        return nil, "no input tokens in: " .. display
    end
    return out
end

-- --- mask building -----------------------------------------------------------

-- Unknown names are reported rather than silently dropped: a dropped button is
-- a whiffed trial that reads as "this link does not work".
function M.button_mask(names, profile)
    if type(profile) ~= "table" or type(profile.buttons) ~= "table" then
        return nil, "no profile"
    end
    local mask = 0
    for _, n in ipairs(names or {}) do
        local bit = profile.buttons[n]
        if bit == nil then
            for _, u in ipairs(profile.buttons_underivable or {}) do
                if u == n then
                    return nil, ("button %q has no bit in this profile: the sweep could "
                        .. "not witness one, because no notation in this catalog names it "
                        .. "on its own"):format(tostring(n))
                end
            end
        end
        if bit == nil then
            return nil, ("button %q is not in the %s profile"):format(tostring(n), profile.scheme)
        end
        mask = mask | bit
    end
    return mask
end

-- --- facing ------------------------------------------------------------------

-- Masks are authored player-relative (bit LEFT is "back"); pl_input_new wants
-- screen-absolute, so when the player faces the other way the two swap.
--
-- WHICH way is the unverified part. Three P1 writers in upstream mirror when
-- rl_dir is falsy and one P2 writer mirrors on truthy, so the profile carries
-- the choice instead of this function assuming it.
function M.mirror(mask, rl_dir, profile)
    if type(profile) ~= "table" or not profile.dir then return nil, "no profile" end
    local should = (profile.mirror_when == "falsy") and (not rl_dir) or
                   (profile.mirror_when == "truthy") and (rl_dir and true or false)
    if not should then return mask end

    local L, R = profile.dir.LEFT, profile.dir.RIGHT
    local has_l = (mask & L) ~= 0
    local has_r = (mask & R) ~= 0
    mask = mask & ~(L | R)
    if has_l then mask = mask | R end
    if has_r then mask = mask | L end
    return mask
end

-- --- readback ----------------------------------------------------------------

function M.numpad_of(mask, profile)
    if type(profile) ~= "table" or not profile.numpad then return "?" end
    local d = mask & M.DIR_BITS
    for digit, m in pairs(profile.numpad) do
        if m == d and digit ~= "5" then return digit end
    end
    return (d == 0) and "5" or "?"
end

-- Human-readable form of a raw mask, for logs and the diagnostics panel.
function M.describe(mask, profile)
    mask = mask or 0
    if type(profile) ~= "table" then return ("0x%X"):format(mask) end

    local parts = { M.numpad_of(mask, profile) }

    -- Sorted by bit value so the output is stable regardless of table order:
    -- these strings end up in committed diagnostics files and get diffed.
    local named = {}
    for name, bit in pairs(profile.buttons) do
        if (mask & bit) ~= 0 then named[#named + 1] = { name = name, bit = bit } end
    end
    table.sort(named, function(a, b) return a.bit < b.bit end)
    for _, e in ipairs(named) do parts[#parts + 1] = e.name end

    return table.concat(parts, "+")
end

-- --- sequence compilation ----------------------------------------------------

-- Turns a parsed notation into { frames = n, mask = m } steps, in the shape
-- upstream's execution drill uses (TrainingMoveExecution.lua:274-284): a
-- neutral lead-in, one tick per motion direction, the final direction held with
-- the buttons, then a neutral tail.
--
-- `frames` counts Explorer TICKS. Whether a tick is a game frame is itself
-- unverified - see Provenance.tick_equals_frame.
--
-- REFUSES an unverified profile unless opts.allow_unverified is set. Read-only
-- callers (the panel showing what a move would compile to) pass it; anything
-- that will actually press a button must not.
function M.compile(parsed, opts)
    if type(parsed) ~= "table" then return nil, "not a parsed notation" end
    opts = opts or {}

    local profile = opts.profile
    if type(profile) ~= "table" then return nil, "compile needs opts.profile" end
    -- "Has anyone looked", not "did the guess survive". Those are different
    -- questions and this gate was asking the wrong one: a register whose sweep
    -- corrected a bad guess opened the injection capability and then refused to
    -- compile anything, telling the operator to run the calibration that had
    -- just succeeded.
    --
    -- A profile with a partial button map still compiles. The buttons it does
    -- have were measured, and one it does not will fail loudly at button_mask
    -- rather than silently pressing nothing - which is the behaviour that gate
    -- exists to prevent, and it is already there.
    if not profile.measured and not opts.allow_unverified then
        return nil, ("refusing to compile with an %s input profile - "
            .. "run calibration first, or pass allow_unverified for a read-only preview")
            :format(tostring(profile.status))
    end

    if parsed.followup then
        return nil, "follow-up derivations cannot be produced standalone: " .. tostring(parsed.raw)
    end

    -- "任意键" (any button) is a display convenience for a move that accepts
    -- more than one strength. There is no such thing as pressing "any", so
    -- refuse rather than emit a direction-only sequence that silently whiffs.
    if parsed.any_button and #parsed.buttons == 0 then
        return nil, "any-button notation needs an explicit button: " .. tostring(parsed.raw)
    end

    local btn, err = M.button_mask(parsed.buttons, profile)
    if btn == nil then return nil, err end

    local dirs = {}
    if parsed.dirs ~= "" then
        local d, derr = M.dirs_from_numpad(parsed.dirs, profile)
        if not d then return nil, derr end
        dirs = d
    end

    local lead = opts.lead_ticks or 3
    local hold = opts.hold_ticks or 3
    local tail = opts.tail_ticks or 5

    local seq = {}
    if lead > 0 then seq[#seq + 1] = { frames = lead, mask = 0 } end

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
