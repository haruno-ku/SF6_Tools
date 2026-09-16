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
        -- Why those buttons have no bit, in this profile's own words. The
        -- Modern answer ("no notation names it on its own") is not the classic
        -- answer ("no sweep has ever run in this scheme"), and button_mask has
        -- to be able to say which one it is.
        buttons_unmeasured_reason = opts.buttons_unmeasured_reason,
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
--
-- The button entry is chosen by SCHEME. Classic's is a separate register entry
-- with no bit in it at all (Provenance.classic_button_bits), so a classic
-- profile is a profile with an empty button map: everything it is asked to
-- press is refused by name, and nothing anywhere had to invent a bit to get
-- there.
M.BITS_KEY = { modern = "modern_button_bits", classic = "classic_button_bits" }

function M.profile_from_provenance(P, reg, scheme)
    scheme = scheme or "modern"
    local key = M.BITS_KEY[scheme]
    if key == nil then
        return nil, ("no button-bit register entry for control scheme %q"):format(tostring(scheme))
    end
    local buttons, bstatus = P.provisional(reg, key)
    local dir, dstatus     = P.provisional(reg, "direction_bits")
    local pol, pstatus     = P.provisional(reg, "rl_dir_polarity")

    local bits_entry = P.get(reg, key)
    local underivable = bits_entry and bits_entry.unwitnessed or nil
    local unmeasured_reason = bits_entry and bits_entry.unwitnessed_reason or nil

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
        buttons_unmeasured_reason = unmeasured_reason,
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

-- --- the classic vocabulary --------------------------------------------------
--
-- A different scheme is a different set of buttons, and the two token sets are
-- kept apart rather than merged. "SP" contains a P; a single table that matched
-- the classic generic-punch token would read the Modern Special button as "any
-- punch" and the failure would be a mask, not an error.
--
-- These are NAMES, exactly as the Modern ones are. No bit for any of them
-- exists anywhere in this project - see Provenance.classic_button_bits - and
-- nothing here invents one.
M.CLASSIC_BUTTONS = { "LP", "MP", "HP", "LK", "MK", "HK" }

-- Every piece a classic display can put between its "+" signs, other than the
-- directions and the generic punch/kick forms. THROW and DI are the two names
-- the two schemes share; they are the same word in the source for both.
M.CLASSIC_TOKENS = {
    LP = "LP", MP = "MP", HP = "HP",
    LK = "LK", MK = "MK", HK = "HK",
    THROW = "THROW",
    DI = "DI",
}

-- "j." is the source's air prefix on the classic side, where Modern writes 空中.
M.CLASSIC_AIR_PREFIX = "j."

-- --- direction ---------------------------------------------------------------

-- The digit a motion presses twice in a row, or nil. "22" -> "2".
--
-- A motion is played one direction per tick, and two ticks of DOWN are one
-- held DOWN - the game sees a single press. So "22 + 中" compiles, plays, and
-- produces nothing, and the trial is recorded as "move B never appeared" (#49).
-- Every other motion changes direction every tick and does come out: the logs
-- show 360, 63214 and 236236 all producing their move.
--
-- Read through MOTION_SHORTHAND, because the circles are spelled "360" and
-- played as "6321478". Neither expansion repeats.
--
-- What would fix it is a neutral between the two presses - the catalog's own
-- raw_direction_inputs for 678 are neutral, down, neutral, down - but how long
-- that neutral has to be is not measured, so the compiler refuses instead of
-- guessing.
function M.repeated_direction(dirs)
    if type(dirs) ~= "string" then return nil end
    local expanded = M.MOTION_SHORTHAND[dirs] or dirs
    return expanded:match("(%d)%1")
end

-- The direction a charge motion says to HOLD, or nil. "[4]6" -> "4".
--
-- Both schemes spell it the same way and both lose it the same way: `dirs` is
-- the digits of the notation with everything else stripped, so "[4]6" arrives
-- at the compiler as "46" - forward-then-back played one tick each, which is
-- not a charge and produces nothing. 112 Modern displays and 116 classic ones
-- are written this way (#34).
--
-- How long the hold has to be is not measured anywhere in this project, which
-- is why this is a flag and not an expansion: the compiler refuses a charge by
-- name, the same way it refuses "22".
function M.charge_direction(s)
    if type(s) ~= "string" then return nil end
    return s:match("%[([1-9])%]")
end

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
--
-- opts.scheme = "classic" parses the OTHER display the source carries. Passing
-- nothing is the Modern reading, byte for byte what it always was.
--
-- WHY A SCHEME ARGUMENT AND NOT ONE TABLE OF TOKENS
--
-- The two vocabularies overlap in a way that a merged table reads wrongly
-- rather than loudly. "SP" is the Modern Special button and ends in a P, which
-- is the classic generic-punch token; "DI" is a shared name; "LP" never appears
-- in a Modern display and 弱 never appears in a classic one. A single tokeniser
-- would have to be ordered exactly right to keep "SP" from being read as
-- "S" + "any punch", and getting that ordering wrong produces a mask, not an
-- error - which is the failure this module exists to prevent.
function M.parse(display, opts)
    if type(display) ~= "string" or display == "" then
        return nil, "empty"
    end
    if opts and opts.scheme == "classic" then return M.parse_classic(display) end

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

    -- Read before the digits are stripped, because stripping is what loses it:
    -- "[4]6" and "46" are the same string afterwards and only one of them is a
    -- charge. See M.charge_direction.
    out.charge = M.charge_direction(s)

    -- Whatever digits remain are the motion. Done last so button tokens cannot
    -- contribute stray digits.
    out.dirs = s:gsub("[^%d]", "")

    if #out.buttons == 0 and out.dirs == "" and not out.any_button then
        return nil, "no input tokens in: " .. display
    end
    return out
end

-- The classic display, in the same shape M.parse returns.
--
--   "LP"              -> { buttons = {"LP"} }
--   "2+MP"            -> { dirs = "2",   buttons = {"MP"} }
--   "236+HP"          -> { dirs = "236", buttons = {"HP"} }
--   "236+PP"          -> { dirs = "236", any_button = true, button_count = 2 }
--   "j.HK"            -> { air = true,   buttons = {"HK"} }
--   ">j.MK"           -> { followup = true, air = true, buttons = {"MK"} }
--   "[4]6+LP"         -> { charge = "4", dirs = "46", buttons = {"LP"} }
--   "4+THROW"         -> { dirs = "4",   buttons = {"THROW"} }
--
-- A classic display is "+"-separated: an optional direction piece first, then
-- one button piece per press. That is a reading of the data rather than a
-- guess - 127 distinct shapes over the 31 shipped characters and every one of
-- them fits it - and it is why this is not a token soup like the Modern side.
-- Splitting on "+" is also what keeps "DP" (the parry label) from being read as
-- a punch: "DP" is one piece, it is not a button name, and the whole display is
-- refused rather than half-understood.
--
-- The generic forms - "P", "PP", "PPP", "K", "KK", "KKK" - name a strength-less
-- press, which is what 任意键 is on the Modern side, and they come back the same
-- way: any_button, with no button name. There is no such thing as pressing "any
-- punch", so this is a refusal downstream, not a choice made here.
function M.parse_classic(display)
    if type(display) ~= "string" or display == "" then return nil, "empty" end

    local out = { air = false, any_button = false, assist = false,
                  followup = false, dirs = "", buttons = {}, raw = display,
                  scheme = "classic" }

    local s = display
    local stripped = s:match("^%s*>%s*(.*)$")
    if stripped then
        out.followup = true
        s = stripped
    end

    -- ">j.HK" is a derivation in the air, so the air prefix is read after the
    -- ">" and not instead of it.
    local airless = s:match("^%s*[jJ]%.%s*(.*)$")
    if airless then
        out.air = true
        s = airless
    end

    local parts = {}
    for piece in (s .. "+"):gmatch("(.-)%+") do
        parts[#parts + 1] = piece:match("^%s*(.-)%s*$")
    end

    for i, piece in ipairs(parts) do
        if piece ~= "" then
            local u = piece:upper()
            if i == 1 and u:match("^[%d%[%]]+$") then
                out.charge = M.charge_direction(u)
                out.dirs = u:gsub("[^%d]", "")
            elseif M.CLASSIC_TOKENS[u] then
                out.buttons[#out.buttons + 1] = M.CLASSIC_TOKENS[u]
            elseif u:match("^P+$") or u:match("^K+$") then
                out.any_button = true
                out.button_count = (out.button_count or 0) + #u
            else
                -- Named rather than ignored. A piece nobody recognises is a
                -- display this parser does not understand, and understanding
                -- half of it would press half a move.
                return nil, ("unrecognised classic token %q in: %s"):format(piece, display)
            end
        end
    end

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
                    if profile.buttons_unmeasured_reason then
                        return nil, ("button %q has no bit in this profile: %s")
                            :format(tostring(n), tostring(profile.buttons_unmeasured_reason))
                    end
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

    -- A charge, for the same reason and with the same consequence as the
    -- repeat below: `dirs` has already lost the brackets, so compiling one
    -- plays "[4]6" as back-then-forward one tick each. That is not a charge,
    -- the move does not come out, and the trial reads as a link that failed.
    -- How long the hold has to be is not measured, so this is a refusal (#34).
    if parsed.charge then
        return nil, ("%s is a charge motion - the notation says to hold %s first, and how "
            .. "long that hold has to be is not measured on this build")
            :format(tostring(parsed.raw), tostring(parsed.charge))
    end

    -- See M.repeated_direction. Refused by name for the same reason as the two
    -- above: compiled, it presses something that silently produces nothing.
    local twice = M.repeated_direction(parsed.dirs)
    if twice then
        return nil, ("%s presses %s twice in a row, and one tick per direction plays that "
            .. "as a single held %s - the neutral between the presses is not measured")
            :format(tostring(parsed.raw), twice, twice)
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
