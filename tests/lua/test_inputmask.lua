-- Unit tests for func/ComboExplorer/core/InputMask.lua
--
-- Two things are being asserted here. The ordinary one: notation parses into
-- the right directions and buttons. The important one: the module cannot be
-- made to build an injectable mask out of values nobody has measured.
--
-- The notation fixtures are not invented. They are the 66 distinct
-- simple_command / motion_command display strings that actually appear in
-- reframework/data/TrainingComboTrials_data/command_display/Zangief.json. A
-- notation the parser cannot handle is a move that disappears from the Move
-- Catalog without an error, which surfaces much later as "these links do not
-- work" - so every one of them is asserted.

local t = require("tests.lua.harness")
local IM = require("func/ComboExplorer/core/InputMask")
local P  = require("func/ComboExplorer/core/Provenance")

-- A profile standing in for a completed calibration. The values happen to match
-- the current provisional guesses, but the test says "verified" explicitly:
-- these tests are about mechanism, not about endorsing the guess.
local VERIFIED = IM.profile({
    buttons = { L = 0x10, M = 0x80, H = 0x100, SP = 0x20, AUTO = 0x200,
                PARRY = 0x40, DI = 0x1000, THROW = 0x2000 },
    dir = { UP = 1, DOWN = 2, LEFT = 4, RIGHT = 8 },
    mirror_when = "falsy",
    status = "verified",
})

-- --- profiles ----------------------------------------------------------------

t.group("profiles")

t.ok(VERIFIED ~= nil, "a well-formed profile is accepted")
t.eq(VERIFIED.numpad["4"], 4, "numpad 4 (back) derives from the LEFT bit")
t.eq(VERIFIED.numpad["6"], 8, "numpad 6 (forward) derives from the RIGHT bit")
t.eq(VERIFIED.numpad["3"], 10, "numpad 3 derives from DOWN|RIGHT")
t.eq(VERIFIED.numpad["5"], 0, "neutral is 0")

t.is_nil(IM.profile({ buttons = {} }), "a profile without direction bits is rejected")
t.is_nil(IM.profile({ dir = { UP = 1, DOWN = 2, LEFT = 4, RIGHT = 8 } }), "without buttons, rejected")
t.is_nil(IM.profile({ buttons = {}, dir = { UP = 1, DOWN = 2, LEFT = 4, RIGHT = 8 },
                      mirror_when = "maybe" }), "an unknown mirror rule is rejected")

-- A calibration file is hand-writable, so its shape has to be checked. Two
-- directions sharing a bit means one of them can never be expressed, and the
-- masks it produces look perfectly plausible.
t.is_nil(IM.profile({ buttons = { L = 1 }, dir = { UP = 1, DOWN = 2, LEFT = 4, RIGHT = 4 } }),
         "two directions sharing a bit is rejected")
t.is_nil(IM.profile({ buttons = { L = 1 }, dir = { UP = 1, DOWN = 2, LEFT = 4, RIGHT = 12 } }),
         "a direction that is not a single bit is rejected")
t.is_nil(IM.profile({ buttons = { L = 0 }, dir = { UP = 1, DOWN = 2, LEFT = 4, RIGHT = 8 } }),
         "a zero button bit is rejected")
t.is_nil(IM.profile({ buttons = { L = "0x10" }, dir = { UP = 1, DOWN = 2, LEFT = 4, RIGHT = 8 } }),
         "a button bit that is a string is rejected")

-- The numpad layout must follow the direction bits, not be pinned to them. If
-- calibration says left and right are the other way round, everything derived
-- has to move with it.
local SWAPPED = IM.profile({
    buttons = { L = 0x10 },
    dir = { UP = 1, DOWN = 2, LEFT = 8, RIGHT = 4 },
    status = "verified",
})
t.eq(SWAPPED.numpad["4"], 8, "swapping the direction bits moves numpad 4 with them")
t.eq(SWAPPED.numpad["6"], 4, "and numpad 6")
t.eq(SWAPPED.numpad["1"], 10, "and the diagonals")

-- --- profiles built from the provenance register ----------------------------

t.group("profile_from_provenance")

local reg = P.new()
local prof = IM.profile_from_provenance(P, reg)
t.eq(prof.status, "unverified", "a fresh register yields an unverified profile")
t.eq(prof.buttons.SP, 0x20, "carrying the provisional values so a preview can render")

-- Partial calibration must not produce a profile that looks trustworthy.
reg:apply_calibration({ calibration_id = "partial", values = {
    modern_button_bits = { status = P.STATUS.VERIFIED,
        value = { L = 0x10, M = 0x80, H = 0x100, SP = 0x20, AUTO = 0x200 } },
} })
local partial = IM.profile_from_provenance(P, reg)
t.eq(partial.status, "unverified",
     "two of three verified is still unverified - the worst status wins")

reg:apply_calibration({ calibration_id = "full", values = {
    direction_bits  = { status = P.STATUS.VERIFIED, value = { UP = 1, DOWN = 2, LEFT = 4, RIGHT = 8 } },
    rl_dir_polarity = { status = P.STATUS.VERIFIED, value = "mirror_when_falsy" },
} })
local full = IM.profile_from_provenance(P, reg)
t.eq(full.status, "verified", "all three verified yields a verified profile")

-- The polarity is data, not an assumption baked into mirror().
local reg2 = P.new()
reg2:apply_calibration({ calibration_id = "flip", values = {
    modern_button_bits = { status = P.STATUS.VERIFIED, value = { L = 0x10 } },
    direction_bits     = { status = P.STATUS.VERIFIED, value = { UP = 1, DOWN = 2, LEFT = 4, RIGHT = 8 } },
    rl_dir_polarity    = { status = P.STATUS.VERIFIED, value = "mirror_when_truthy" },
} })
t.eq(IM.profile_from_provenance(P, reg2).mirror_when, "truthy",
     "a calibration that flips the polarity flips the profile")

-- An unrecognised polarity must refuse, not quietly become "falsy". That
-- default is the one error that mirrors half a dataset and reads as flaky links
-- rather than as a bug.
local reg3 = P.new()
reg3:apply_calibration({ calibration_id = "typo", values = {
    rl_dir_polarity = { status = P.STATUS.VERIFIED, value = "mirror_when_flasy" },
} })
local bad, why = IM.profile_from_provenance(P, reg3)
t.is_nil(bad, "an unrecognised polarity is refused")
t.ok(why and why:find("mirror_when_falsy", 1, true) ~= nil, "and the error names what was expected")

-- --- notation parsing is profile-independent --------------------------------

t.group("notation parsing")

-- parse() deliberately yields NAMES, never bits. That is what lets the Move
-- Catalog be built completely before a single value has been measured.
local p = IM.parse("2 + \228\184\173")           -- "2 + 中"
t.eq(p.dirs, "2", "2+M direction is kept as a numpad string")
t.eq_list(p.buttons, { "M" }, "2+M button is a name")
t.eq(p.air, false, "2+M is grounded")

p = IM.parse("3 + \229\188\186")                 -- "3 + 强"
t.eq(p.dirs, "3", "3+H direction")
t.eq_list(p.buttons, { "H" }, "3+H button")

p = IM.parse("SP")
t.eq(p.dirs, "", "SP has no direction")
t.eq_list(p.buttons, { "SP" }, "SP button")

p = IM.parse("AUTO + \229\188\177")              -- "AUTO + 弱"
t.eq_list(p.buttons, { "AUTO", "L" }, "assist plus light, AUTO matched first")
t.ok(p.assist, "assist flagged")

p = IM.parse("\231\169\186\228\184\173 360 + \229\188\186")  -- "空中 360 + 强"
t.ok(p.air, "air flagged")
t.eq(p.dirs, "360", "the circle shorthand is preserved, not expanded at parse time")
t.eq_list(p.buttons, { "H" }, "360+H button")

p = IM.parse("360 + \228\187\187\230\132\143\233\148\174 + \228\187\187\230\132\143\233\148\174")
t.ok(p.any_button, "any-button flagged")
t.eq_list(p.buttons, {}, "any-button contributes no concrete button")

p = IM.parse("> \228\184\173")                   -- "> 中"
t.ok(p.followup, "leading > marks a follow-up derivation")
t.eq_list(p.buttons, { "M" }, "follow-up still parses its button")

p = IM.parse("\229\188\177 + \228\184\173 + \229\188\186")  -- "弱 + 中 + 强"
t.eq_list(p.buttons, { "L", "M", "H" }, "three strengths in token order")

p = IM.parse("2 + SP + \229\188\186")            -- "2 + SP + 强"
t.eq(p.dirs, "2", "2+SP+H direction")
t.eq_list(p.buttons, { "SP", "H" }, "2+SP+H buttons")

p = IM.parse("66")
t.eq(p.dirs, "66", "dash is two forwards")
t.eq_list(p.buttons, {}, "dash has no button")

for _, label in ipairs({ "N", "DP", "DRC", "RAW DR" }) do
    t.is_nil(IM.parse(label), "label with no input: " .. label)
end

-- --- direction expansion needs a profile ------------------------------------

t.group("direction expansion")

t.eq_list(IM.dirs_from_numpad("236", VERIFIED), { 2, 10, 8 }, "quarter-circle forward")
t.eq_list(IM.dirs_from_numpad("2", VERIFIED), { 2 }, "single direction is a one-element list")
t.eq_list(IM.dirs_from_numpad("63214", VERIFIED), { 8, 10, 2, 6, 4 }, "half-circle back")

-- 360 and 720 are circle shorthands, not numpad sequences: taken literally they
-- contain a 0, which is not a direction at all.
t.eq_list(IM.dirs_from_numpad("360", VERIFIED), { 8, 10, 2, 6, 4, 5, 1 },
          "360 expands to upstream's seven-step circle")
t.eq_list(IM.dirs_from_numpad("720", VERIFIED), { 8, 10, 2, 6, 4, 5, 1, 9, 8, 2, 4 },
          "720 expands to upstream's eleven-step double circle")

t.is_nil(IM.dirs_from_numpad("xyz", VERIFIED), "no digits -> nil")
t.is_nil(IM.dirs_from_numpad("2", nil), "no profile -> nil")

-- --- button masks ------------------------------------------------------------

t.group("button masks")

-- Cross-check against routes[].raw_button_mask in Zangief.json: if these ever
-- disagree, the catalog and the injector have drifted apart.
t.eq(IM.button_mask({ "L", "M" }, VERIFIED), 144, "L|M == THROW's raw_button_mask 144")
t.eq(IM.button_mask({ "M", "H" }, VERIFIED), 384, "M|H matches raw_button_mask 384")
t.eq(IM.button_mask({ "L", "M", "H" }, VERIFIED), 400, "L|M|H matches raw_button_mask 400")
t.eq(IM.button_mask({ "SP", "H" }, VERIFIED), 288, "SP|H matches raw_button_mask 288")
t.is_nil(IM.button_mask({ "LP" }, VERIFIED), "a name absent from the profile is rejected")
t.is_nil(IM.button_mask({ "L" }, nil), "no profile -> nil")

-- --- compile refuses to guess ------------------------------------------------

t.group("compile refuses unverified input")

local UNVERIFIED = IM.profile({
    buttons = { L = 0x10, M = 0x80, H = 0x100, SP = 0x20, AUTO = 0x200, THROW = 0x2000, DI = 0x1000 },
    dir = { UP = 1, DOWN = 2, LEFT = 4, RIGHT = 8 },
    status = "unverified",
})

local seq, err = IM.compile(IM.parse("2 + \228\184\173"), { profile = UNVERIFIED })
t.is_nil(seq, "an unverified profile is refused")
t.ok(err and err:find("calibration", 1, true) ~= nil, "and the refusal says what would fix it")

t.ok(IM.compile(IM.parse("2 + \228\184\173"), { profile = UNVERIFIED, allow_unverified = true }) ~= nil,
     "a read-only preview can opt in explicitly")

t.is_nil(IM.compile(IM.parse("2 + \228\184\173"), {}), "no profile at all is refused")

-- A follow-up derivation cannot be produced from neutral, so compiling one is
-- always a mistake - it would be recorded as a move that does not work.
local fseq, ferr = IM.compile(IM.parse("> \228\184\173"), { profile = VERIFIED })
t.is_nil(fseq, "a follow-up derivation refuses to compile")
t.ok(ferr and ferr:find("standalone", 1, true) ~= nil, "and says why")

t.is_nil(IM.compile(IM.parse("360 + \228\187\187\230\132\143\233\148\174 + \228\187\187\230\132\143\233\148\174"),
                    { profile = VERIFIED }),
         "any-button notation refuses to compile")

-- --- every real Zangief notation -------------------------------------------

t.group("all 66 Zangief catalog notations")

local LABELS = { N = true, DP = true, DRC = true, ["RAW DR"] = true }
local FIXTURES = dofile("tests/lua/fixtures/zangief_notations.lua")

t.eq(#FIXTURES, 66, "fixture count matches the catalog")

local parsed_ok, label_ok, compiled, refused = 0, 0, 0, 0
local refusals = {}
for _, s in ipairs(FIXTURES) do
    local r, perr = IM.parse(s)
    if r then
        parsed_ok = parsed_ok + 1
        local cseq, cerr = IM.compile(r, { profile = VERIFIED })
        if cseq then
            compiled = compiled + 1
        else
            refused = refused + 1
            refusals[#refusals + 1] = s .. " -- " .. tostring(cerr)
        end
    elseif LABELS[s] then
        label_ok = label_ok + 1
    else
        t.fail("unparsed and not a known label: " .. s .. " (" .. tostring(perr) .. ")")
    end
end

t.eq(parsed_ok + label_ok, 66, "every notation either parsed or is a known label")
t.eq(label_ok, 4, "exactly four pure labels")

-- Every refusal must be a deliberate one: a follow-up, or an any-button
-- notation. Anything else is a parser gap wearing a refusal as a disguise.
for _, r in ipairs(refusals) do
    t.ok(r:find("standalone", 1, true) ~= nil or r:find("any%-button") ~= nil,
         "refusal is deliberate: " .. r)
end
t.ok(compiled >= 55, "the large majority compile (" .. compiled .. " of 66)")

-- --- facing mirror -----------------------------------------------------------

t.group("facing mirror")

-- rl_dir true means facing right, so with mirror_when = "falsy" a right-facing
-- player needs no change.
t.eq(IM.mirror(8, true, VERIFIED), 8, "facing right: forward stays on the RIGHT bit")
t.eq(IM.mirror(8, false, VERIFIED), 4, "facing left: forward becomes screen-left")
t.eq(IM.mirror(4, false, VERIFIED), 8, "facing left: back becomes screen-right")
t.eq(IM.mirror(10, false, VERIFIED), 6, "down-forward mirrors, down is preserved")
t.eq(IM.mirror(2, false, VERIFIED), 2, "vertical is unaffected")
t.eq(IM.mirror(0x100, false, VERIFIED), 0x100, "buttons are unaffected")
t.eq(IM.mirror(IM.mirror(10, false, VERIFIED), false, VERIFIED), 10, "mirroring twice is identity")

-- The opposite polarity must behave as the exact mirror image, because which
-- one is right has not been measured.
local TRUTHY = IM.profile({
    buttons = VERIFIED.buttons, dir = VERIFIED.dir,
    mirror_when = "truthy", status = "verified",
})
t.eq(IM.mirror(8, true, TRUTHY), 4, "opposite polarity: mirrors when facing right")
t.eq(IM.mirror(8, false, TRUTHY), 8, "opposite polarity: leaves it alone when facing left")

t.is_nil(IM.mirror(8, true, nil), "no profile -> nil")

-- --- compile / expand --------------------------------------------------------

t.group("compile and expand")

local cseq = IM.compile(IM.parse("2 + \228\184\173"),
    { profile = VERIFIED, lead_ticks = 3, hold_ticks = 3, tail_ticks = 5 })
t.eq(#cseq, 3, "a no-motion move is lead, hold, tail")
t.eq(cseq[1].mask, 0, "lead is neutral")
t.eq(cseq[2].mask, 2 | 128, "hold is direction|button")
t.eq(cseq[2].frames, 3, "hold length honoured")
t.eq(cseq[3].mask, 0, "tail is neutral")

local ticks = IM.expand(cseq)
t.eq(#ticks, 11, "3 + 3 + 5 ticks")
t.eq(ticks[1], 0, "first tick neutral")
t.eq(ticks[4], 130, "fourth tick is the input")
t.eq(ticks[11], 0, "last tick neutral")

-- A motion plays one direction per tick, buttons only on the last.
local mt = IM.expand(IM.compile(IM.parse("236 + \229\188\186"),
    { profile = VERIFIED, lead_ticks = 1, hold_ticks = 2, tail_ticks = 1 }))
t.eq_list(mt, { 0, 2, 10, 8 | 256, 8 | 256, 0 }, "236+H plays digit-per-tick, button on the last")

-- --- describe ----------------------------------------------------------------

t.group("describe")

t.eq(IM.describe(2 | 128, VERIFIED), "2+M", "modern readback")
t.eq(IM.describe(0, VERIFIED), "5", "neutral")
t.eq(IM.describe(0x20 | 0x100, VERIFIED), "5+SP+H", "buttons ordered by bit value, not table order")

-- The same bits under a different profile read as different buttons - which is
-- exactly the failure mode calibration exists to prevent.
local CLASSIC = IM.profile({
    buttons = { LP = 0x10, MP = 0x20, HP = 0x40, LK = 0x80, MK = 0x100, HK = 0x200 },
    dir = VERIFIED.dir, status = "verified", scheme = "classic",
})
t.eq(IM.describe(2 | 128, CLASSIC), "2+LK", "the same mask reads as LK under a classic profile")

-- --- a measurement is not a reason to refuse ---------------------------------

t.group("the gate asks whether anybody looked, not whether the guess held")

-- The failure this replaces: a successful calibration sweep settles
-- modern_button_bits as `refuted` or `partial` - refuted when it corrected a
-- guess, partial because AUTO and PARRY can never be witnessed - and
-- Provenance opens the injection capability on either. The compile gate tested
-- the STATUS STRING for "verified", so the panel reported injection available
-- and every trial was refused with "run calibration first". The operator would
-- have been told to run the calibration that had just succeeded.

local function register_with(statuses)
    local reg = P.new()
    for key, st in pairs(statuses) do
        if st ~= "unverified" then reg.entries[key].status = st end
    end
    return reg
end

local ALL = { "modern_button_bits", "direction_bits", "rl_dir_polarity" }

do
    local measured = {}
    for _, k in ipairs(ALL) do measured[k] = "refuted" end
    local prof = IM.profile_from_provenance(P, register_with(measured))
    t.ok(prof ~= nil, "a fully refuted register still makes a profile")
    t.eq(prof.status, "refuted", "carrying the refuted status")
    t.eq(prof.measured, true, "and saying it was measured, because it was")

    local seq = IM.compile(IM.parse("2 + \228\184\173"), { profile = prof })
    t.ok(seq ~= nil, "and it COMPILES - a corrected guess is knowledge, not a blocker")
end

do
    local mixed = { modern_button_bits = "partial", direction_bits = "verified",
                    rl_dir_polarity = "verified" }
    local prof = IM.profile_from_provenance(P, register_with(mixed))
    t.eq(prof.status, "partial", "a partial button map carries through")
    t.eq(prof.measured, true, "and still counts as measured")
    t.ok(IM.compile(IM.parse("2 + \228\184\173"), { profile = prof }) ~= nil,
         "so a move using the buttons it DOES have compiles")
end

do
    local prof = IM.profile_from_provenance(P, P.new())
    t.eq(prof.measured, false, "an untouched register is not measured")
    local nope, why = IM.compile(IM.parse("2 + \228\184\173"), { profile = prof })
    t.is_nil(nope, "and is still refused, which is the part that must not change")
    t.ok(why:find("unverified") ~= nil, "naming the status: " .. tostring(why))
end

-- --- the worst status is a comparison, not an argument position --------------

t.group("the worst of three statuses does not depend on their order")

-- It used to. There was no rank and no comparison - the loop kept whichever
-- non-verified status came last - so the same multiset gave opposite answers:
--     refuted, unverified, verified -> unverified   (a measurement lost to a guess)
--     unverified, refuted, verified -> refuted
do
    local a = IM.profile_from_provenance(P, register_with({
        modern_button_bits = "refuted", direction_bits = "unverified",
        rl_dir_polarity = "verified" }))
    local b = IM.profile_from_provenance(P, register_with({
        modern_button_bits = "unverified", direction_bits = "refuted",
        rl_dir_polarity = "verified" }))
    t.eq(a.status, b.status,
         "the same three statuses in a different order give the same answer")
    t.eq(a.status, "unverified", "and it is the least settled of them")
    t.eq(a.measured, false, "so the profile is not measured")

    local c = IM.profile_from_provenance(P, register_with({
        modern_button_bits = "refuted", direction_bits = "partial",
        rl_dir_polarity = "verified" }))
    t.eq(c.status, "refuted",
         "refuted ranks below partial: both were measured, but a refuted entry "
         .. "replaced a guess that was wrong")
    t.eq(c.measured, true, "and both are measurements, so the profile is measured")
end

-- --- a button nobody could witness ------------------------------------------

t.group("a button with no bit says why")

do
    local partial = IM.profile({
        buttons = { L = 0x10, M = 0x80, H = 0x100 },
        dir = { UP = 1, DOWN = 2, LEFT = 4, RIGHT = 8 },
        mirror_when = "falsy",
        status = "partial",
        measured = true,
        buttons_underivable = { "AUTO", "PARRY" },
    })
    t.eq(partial.measured, true, "an explicit measured = true survives")

    local nope, why = IM.button_mask({ "AUTO" }, partial)
    t.is_nil(nope, "pressing a button the sweep could not witness fails")
    t.ok(why:find("could not witness") ~= nil,
         "and says why rather than only that the name is unknown: " .. tostring(why))

    local ok = IM.button_mask({ "M" }, partial)
    t.eq(ok, 0x80, "while the buttons it does have still work")

    -- The trap this is written against: `(opts.measured ~= nil) and opts.measured
    -- or (opts.status == "verified")` sends an explicit false through the `or`.
    local denied = IM.profile({
        buttons = { L = 0x10 }, dir = { UP = 1, DOWN = 2, LEFT = 4, RIGHT = 8 },
        status = "verified", measured = false,
    })
    t.eq(denied.measured, false,
         "an explicit measured = false is not overruled by a verified status")
end

return t.finish()
