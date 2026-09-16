-- Unit tests for CLASSIC controls: the second vocabulary, the second catalog,
-- and the reason nothing built from either can be pressed on this build.
--
-- Run against the real Zangief entries and the real Zangief frame data, for the
-- reason test_catalog.lua gives: the failures this code exists to prevent are
-- data-shaped, and a fixture written to match the author's assumptions cannot
-- show one.
--
-- WHAT THIS SUITE IS ACTUALLY GUARDING
--
-- Two things, and they pull in opposite directions.
--
-- The first is that a classic catalog is BUILDABLE offline and joins the frame
-- data - because it turns out the join was always classic. FrameData.lookup
-- takes row.classic and has since the beginning; Catalog's category comes from
-- category_from_classic. Both sides of the offline pipeline were already
-- reading the classic display, and only `notation` - what the row says it would
-- take to press - was Modern.
--
-- The second is that none of it can be pressed. Six buttons, not one of which
-- has a measured pl_input_new bit, and no way to get one without the game. So
-- every rule below that says "this compiles" is paired with one that says "and
-- it is still refused by name", and the second is the one that matters: a
-- classic worklist that quietly swept would record 3000 confident negatives
-- about links nobody tried.

local t = require("tests.lua.harness")
local InputMask = require("func/ComboExplorer/core/InputMask")
local Catalog   = require("func/ComboExplorer/core/Catalog")
local FD        = require("func/ComboExplorer/core/FrameData")
local SC        = require("func/ComboExplorer/core/SequenceCompiler")
local P         = require("func/ComboExplorer/core/Provenance")

local RAW = dofile("tests/lua/fixtures/zangief_catalog.lua")
local CLASSIC = { scheme = "classic" }

-- --- the classic vocabulary --------------------------------------------------

t.group("parse_classic reads the other display")

local function parse(s) return InputMask.parse(s, CLASSIC) end

local lp = parse("LP")
t.eq(lp and #lp.buttons, 1, "\"LP\" names one button")
t.eq(lp and lp.buttons[1], "LP", "and it is LP, not L")
t.eq(lp and lp.dirs, "", "with no direction")

local c2mp = parse("2+MP")
t.eq(c2mp and c2mp.dirs, "2", "\"2+MP\" is a crouching direction")
t.eq(c2mp and c2mp.buttons[1], "MP", "and a medium punch")

local hado = parse("236+HP")
t.eq(hado and hado.dirs, "236", "\"236+HP\" keeps the whole motion")
t.eq(hado and hado.buttons[1], "HP", "and the heavy punch")

local six = parse("LP+MP+HP+LK+MK+HK")
t.eq(six and #six.buttons, 6, "all six buttons at once is six buttons")

local jhk = parse("j.HK")
t.eq(jhk and jhk.air, true, "\"j.\" is the classic air prefix")
t.eq(jhk and jhk.buttons[1], "HK", "and the button survives it")

local deriv = parse(">j.MK")
t.eq(deriv and deriv.followup, true, "a derivation in the air is a derivation")
t.eq(deriv and deriv.air, true, "and it is in the air - the \">\" is read first")

local throw = parse("4+THROW")
t.eq(throw and throw.buttons[1], "THROW", "THROW is a name both schemes share")

t.group("the generic forms name no strength")

-- "236+PP" is the OD special. Two punches, and the source declines to say
-- which two - exactly what 任意键 is on the Modern side, and it comes back the
-- same way so that Catalog excludes it under the same name.
local od = parse("236+PP")
t.eq(od and od.any_button, true, "\"PP\" is a press with no strength named")
t.eq(od and #od.buttons, 0, "so no button name is invented for it")
t.eq(od and od.button_count, 2, "but the count is kept - it is two presses")
t.eq(parse("236236+P").any_button, true, "and a super written \"+P\" is the same case")

t.group("a label is refused whole, not read in half")

-- The trap a merged tokeniser falls into. "DP" is the parry label; a parser
-- that scanned for a bare "P" anywhere would call it a punch, Catalog would
-- call it a probeable move, and a trial would press something and record that
-- Drive Parry does not link.
t.is_nil(parse("DP"), "\"DP\" is not a punch with a D in front of it")
t.is_nil(parse("RAW DR"), "\"RAW DR\" carries no input")
t.is_nil(parse("Normal"), "neither does the neutral-state label")
t.is_nil(parse("N"), "nor its one-letter form")
t.is_nil(parse("Parry"), "nor the parry")

t.group("the two vocabularies stay apart")

-- The Modern reading is the default and is untouched: no opts, same answer as
-- before this file existed.
local modern = InputMask.parse("2 + \228\184\173")
t.eq(modern and modern.dirs, "2", "the Modern parse still reads its own display")
t.eq(modern and modern.buttons[1], "M", "with its own button names")
t.is_nil(InputMask.parse("LP"), "and it does not understand a classic one")
t.is_nil(parse("2 + \228\184\173"), "nor the classic parse a Modern one")

-- "SP" ends in a P. Under one merged table it would read as the Special button
-- plus a generic punch, or as a stray S plus a punch, depending on order.
local sp = InputMask.parse("SP")
t.eq(sp and sp.buttons[1], "SP", "SP is the Special button under Modern")
t.eq(sp and sp.any_button, false, "and not a generic punch")

-- --- charge ------------------------------------------------------------------

t.group("a charge is not a motion (#34)")

t.eq(InputMask.charge_direction("[4]6"), "4", "\"[4]6\" says to hold 4")
t.eq(InputMask.charge_direction("236"), nil, "an ordinary motion holds nothing")

-- Both schemes spell it the same way and both lose the brackets on the way to
-- `dirs`. That is the whole hazard: "[4]6" and "46" arrive identical.
local cch = parse("[4]6+LP")
t.eq(cch and cch.charge, "4", "the classic parse keeps the hold")
t.eq(cch and cch.dirs, "46", "even though dirs cannot express it")
local mch = InputMask.parse("[4]6 + \229\188\177")
t.eq(mch and mch.charge, "4", "and so does the Modern parse - 112 displays are written this way")

-- A profile good enough to compile with, so the refusal below is about the
-- charge and not about the button map.
local ok_profile = InputMask.profile({
    buttons = { L = 0x10, M = 0x80, H = 0x100 },
    dir = { UP = 1, DOWN = 2, LEFT = 4, RIGHT = 8 },
    measured = true, status = "verified",
})
t.ok(ok_profile ~= nil, "a test profile builds")

local seq, why = InputMask.compile(mch, { profile = ok_profile })
t.is_nil(seq, "a charge does not compile")
t.ok(type(why) == "string" and why:find("charge", 1, true) ~= nil,
     "and the refusal says so by name: " .. tostring(why))

-- --- the classic catalog -----------------------------------------------------

t.group("Catalog.build under classic")

local mcat = Catalog.build(RAW)
local ccat, cproblems = Catalog.build(RAW, CLASSIC)

t.ok(ccat ~= nil, "the real catalog builds under classic")
t.eq(ccat.scheme, "classic", "and says which display its notations came from")
t.eq(mcat.scheme, "modern", "as does the Modern one")
t.eq(#cproblems, 0, "no entry defeated the classifier (" ..
     (cproblems[1] and cproblems[1].reason or "") .. ")")

t.eq(#ccat.rows, 80, "one row per entry - classic has one way of pressing a move")
t.eq(#mcat.rows, 88, "Modern has more rows than entries: motion, simple and assist")

local all_classic = true
for _, r in ipairs(ccat.rows) do
    if r.input_method ~= "classic" then all_classic = false break end
end
t.ok(all_classic, "every classic row carries input_method = classic")

t.eq(#ccat.unreachable, 0,
     "nothing is unreachable under classic - every entry has a classic_command")
t.eq(#mcat.unreachable, 9, "against nine Modern cannot reach at all")

t.group("an unknown scheme is refused rather than defaulted")

local bad, berr = Catalog.build(RAW, { scheme = "hitbox" })
t.is_nil(bad, "a scheme nobody implemented builds nothing")
t.ok(berr and berr[1] and tostring(berr[1].reason):find("hitbox", 1, true) ~= nil,
     "and the reason names it")

t.group("what classic reaches that Modern does not")

local mids = {}
for _, r in ipairs(Catalog.probeable(mcat, { input_methods = { "manual", "simple" } })) do
    mids[r.action_id] = true
end
local gained = {}
for _, r in ipairs(Catalog.probeable(ccat, { input_methods = { "classic" } })) do
    if not mids[r.action_id] then gained[#gained + 1] = r.action_id end
end
table.sort(gained)
-- Six of these eight are control_support = "classic_only": moves the source
-- says Modern cannot reach, and which the Modern catalog therefore records in
-- `unreachable` rather than as rows. 600 is Zangief's standing LP; 1015 is the
-- OD Screw Piledriver spelled with two kicks.
t.eq_list(gained, { 600, 613, 615, 627, 631, 660, 685, 1015 },
          "eight action ids are probeable under classic and not under Modern")

t.group("a direction with no button is movement, not a move")

-- category_from_classic reads a leading digit as a command normal, which is
-- right for "2+MP" and wrong for "6". Kimberly has six rows displaying "6" in
-- the specials band; Zangief has two. None of them is an input anybody makes,
-- and the frame source lists none of them - so before this rule they were 74
-- probeable rows across the roster that could only ever miss.
t.eq(ccat.counts.by_exclusion[Catalog.EXCLUSION.MOVEMENT], 2,
     "two Zangief classic rows are set aside as movement")
t.is_nil(mcat.counts.by_exclusion[Catalog.EXCLUSION.MOVEMENT],
         "and none under Modern, where the same entries are already runtime_common system")

-- --- the join ----------------------------------------------------------------

t.group("the frame-data join was always the classic one")

local idx = FD.index(dofile("data/frame-data/zangief.lua"))
t.ok(idx ~= nil, "the real frame data indexes")

-- The same action id, built under the two schemes, carries the same `classic`
-- display - which is the only field FrameData.lookup reads. So the join cannot
-- differ per scheme; only the SET of rows being joined can.
local by_id_m, same = {}, 0
for _, r in ipairs(mcat.rows) do by_id_m[r.action_id] = r end
for _, r in ipairs(ccat.rows) do
    local m = by_id_m[r.action_id]
    if m and m.classic == r.classic then same = same + 1 end
end
t.ok(same >= 70, ("%d rows share their classic display across the two schemes"):format(same))

local mcov = FD.coverage(idx, Catalog.probeable(mcat, { input_methods = { "manual", "simple" } }))
local ccov = FD.coverage(idx, Catalog.probeable(ccat, { input_methods = { "classic" } }))
t.eq(mcov.matched, mcov.rows, ("Modern joins every probeable row (%d)"):format(mcov.rows))
t.eq(ccov.matched, ccov.rows, ("and so does classic (%d)"):format(ccov.rows))

-- --- nothing classic can be pressed on this build ----------------------------

t.group("the register has no classic button bit and does not pretend to")

local reg = P.new()
local bits, status = P.provisional(reg, "classic_button_bits")
t.eq(status, P.STATUS.UNVERIFIED, "classic_button_bits has never been measured")
local n = 0
for _ in pairs(bits) do n = n + 1 end
t.eq(n, 0, "and carries no provisional value at all - there is nowhere to take one from")
t.eq_list(P.get(reg, "classic_button_bits").unwitnessed,
          { "HK", "HP", "LK", "LP", "MK", "MP" },
          "all six are named as unwitnessed")

-- The Modern map is not touched by any of this. It has its own three attack
-- buttons and its own measurement, and adding the classic question must not
-- un-answer the Modern one.
local mbits = P.provisional(reg, "modern_button_bits")
t.eq(mbits.L, 0x10, "the Modern provisional map is unchanged")
t.eq(mbits.H, 0x100, "including its heavy")

t.group("the two injection capabilities are separate")

local cal = {
    calibration_id = "test", game_patch = "24176760",
    values = {
        modern_button_bits = { status = P.STATUS.VERIFIED,
                               value = { L = 0x10, M = 0x80, H = 0x100 } },
        direction_bits = { status = P.STATUS.VERIFIED,
                           value = { UP = 1, DOWN = 2, LEFT = 4, RIGHT = 8 } },
        rl_dir_polarity = { status = P.STATUS.VERIFIED, value = "mirror_when_falsy" },
    },
}
local applied = P.apply_calibration(reg, cal)
t.eq(#applied, 3, "a Modern calibration applies its three values")
t.eq(reg:can(P.CAPABILITY.INJECTION), true, "and opens Modern injection")
local can_classic, blocked = reg:can(P.CAPABILITY.INJECTION_CLASSIC)
t.eq(can_classic, false, "but not classic injection")
t.eq_list(blocked, { "classic_button_bits" },
          "blocked by the one value a Modern sweep cannot witness")

t.group("a classic profile refuses every button by name")

local cprof, cerr = InputMask.profile_from_provenance(P, reg, "classic")
t.ok(cprof ~= nil, "a classic profile still builds: " .. tostring(cerr))
t.eq(cprof and cprof.scheme, "classic", "and knows which scheme it is for")
t.eq(cprof and cprof.measured, false, "and that nobody has measured it")

local mask, merr = InputMask.button_mask({ "LP" }, cprof)
t.is_nil(mask, "pressing LP produces no mask")
t.ok(type(merr) == "string" and merr:find("Classic controls", 1, true) ~= nil,
     "and the refusal says why: " .. tostring(merr))

local mprof = InputMask.profile_from_provenance(P, reg, "modern")
t.eq(mprof and mprof.buttons.L, 0x10, "while the Modern profile still has its bits")
t.eq(mprof and mprof.measured, true, "and is measured")

t.is_nil(InputMask.profile_from_provenance(P, reg, "hitbox"),
         "a scheme with no register entry gets no profile")

-- --- the unplayable rule -----------------------------------------------------

t.group("every classic pair is set aside before the first trial")

local route = {
    id = "s-600-900", character = "Zangief", control_scheme = "classic",
    steps = {
        { index = 1, action_id = 600, input_method = "classic", notation = "LP" },
        { index = 2, action_id = 900, input_method = "classic", notation = "360+LP" },
    },
}
local found = SC.unplayable(route)
t.eq(#found, 2, "both steps are named")
t.eq(found[1].kind, SC.UNPLAYABLE.CLASSIC_BUTTONS, "under classic_buttons_unmeasured")
t.eq(found[1].notation, "LP", "with the notation that cannot be pressed")
t.ok(found[1].reason:find("LP", 1, true) ~= nil, "and the button named in the reason")
t.ok(found[1].reason:find("LK", 1, true) ~= nil,
     "including the measurement that would settle it")

-- The distinction that makes this a rule about steps and not a blanket refusal:
-- a classic step that presses nothing needs no button bit.
local walk = SC.unplayable({
    control_scheme = "classic",
    steps = {
        { index = 1, notation = "236" },
        { index = 2, notation = "214" },
    },
})
t.eq(#walk, 0, "a classic route of pure directions trips no button rule")

t.group("the same route under Modern is judged by the Modern rules")

local modern_route = {
    control_scheme = "modern",
    steps = {
        { index = 1, notation = "\229\188\177" },
        { index = 2, notation = "236 + \229\188\186" },
    },
}
t.eq(#SC.unplayable(modern_route), 0, "a playable Modern pair is still playable")

t.group("a charge is set aside too, in both schemes")

local charge_route = SC.unplayable({
    control_scheme = "modern",
    steps = {
        { index = 1, notation = "\229\188\177" },
        { index = 2, notation = "[4]6 + \229\188\186" },
    },
})
t.eq(#charge_route, 1, "one step of that pair cannot be played")
t.eq(charge_route[1].kind, SC.UNPLAYABLE.CHARGE, "and it is the charge")
t.eq(charge_route[1].index, 2, "the second one")

t.group("principal_unplayable names the reason no fix gets round")

-- A classic charge trips both rules. Reporting the charge would tell a reader
-- the smaller truth and imply the larger one was settled.
local both = SC.unplayable({
    control_scheme = "classic",
    steps = {
        { index = 1, notation = "LP" },
        { index = 2, notation = "[4]6+HP" },
    },
})
t.eq(SC.principal_unplayable(both).kind, SC.UNPLAYABLE.CLASSIC_BUTTONS,
     "the unwitnessed button map outranks the charge")
t.eq(SC.principal_unplayable(charge_route).kind, SC.UNPLAYABLE.CHARGE,
     "and with no classic step the charge is the answer")
t.is_nil(SC.principal_unplayable({}), "nothing wrong, nothing to name")

t.group("and the compiler refuses the same route")

local prog, perr = SC.compile(route, { profile = cprof, delay = 4,
                                       allow_unverified = true })
t.is_nil(prog, "a classic route does not compile even with allow_unverified")
t.ok(type(perr) == "string" and perr:find("Classic controls", 1, true) ~= nil,
     "because the button has no bit: " .. tostring(perr))

-- allow_unverified is the read-only preview escape hatch, and it must not be
-- one here. A missing bit is not an unverified bit: there is nothing to press.
local mprog = SC.compile({
    control_scheme = "modern",
    steps = {
        { notation = "\229\188\177" },
        { notation = "236 + \229\188\186" },
    },
}, { profile = mprof, delay = 4 })
t.ok(mprog ~= nil, "while the Modern route still compiles")

-- --- the offline pipeline ----------------------------------------------------

t.group("pipeline method defaults follow the scheme")

local Pipeline = dofile("tools/lua/pipeline.lua")

local o = { scheme = "classic", from_methods = "manual", to_methods = "manual,simple" }
Pipeline.apply_scheme_defaults(o, {})
t.eq(o.from_methods, "classic", "a classic run asks for classic starters")
t.eq(o.to_methods, "classic", "and classic targets")

-- Without this the Modern defaults would select no rows at all, and an empty
-- candidate set reads as a character with no links rather than as a filter
-- that names nothing.
local said = { from_methods = true }
local o2 = { scheme = "classic", from_methods = "manual", to_methods = "manual,simple" }
Pipeline.apply_scheme_defaults(o2, said)
t.eq(o2.from_methods, "manual", "an operator who named a filter keeps it")
t.eq(o2.to_methods, "classic", "and the one they did not is still defaulted")

local o3 = { scheme = "modern", from_methods = "manual", to_methods = "manual,simple" }
Pipeline.apply_scheme_defaults(o3, {})
t.eq(o3.from_methods, "manual", "a Modern run is untouched")

-- --- and what one Classic calibration changes --------------------------------

t.group("once the six bits are measured, the same route is no longer set aside")

do
    -- The refusal above is a fact about THIS BUILD, not about Classic, and the
    -- difference is a measured map. `button_bits` is what a caller holding one
    -- passes; with none - which is every caller before a classic run - the
    -- answer is exactly what it was.
    local measured = { LP = 0x10, MP = 0x80, HP = 0x100,
                       LK = 0x20, MK = 0x40, HK = 0x200 }
    local still = SC.unplayable(route, { button_bits = measured })
    local classic_kinds = 0
    for _, f in ipairs(still) do
        if f.kind == SC.UNPLAYABLE.CLASSIC_BUTTONS then classic_kinds = classic_kinds + 1 end
    end
    t.eq(classic_kinds, 0, "no step is set aside for an unwitnessed button any more")

    -- A map missing one button sets aside only the steps that press it, which
    -- is the difference between "this scheme cannot be pressed" and "this step
    -- cannot be pressed".
    local partial = { MP = 0x80, HP = 0x100, LK = 0x20, MK = 0x40, HK = 0x200 }
    local some = SC.unplayable(route, { button_bits = partial })
    t.eq(#some, 2, "both LP steps come back")
    t.eq(some[1].kind, SC.UNPLAYABLE.CLASSIC_BUTTONS, "still under the same name")

    t.eq(SC.classic_buttons_measured({ "LP" }, nil), false,
         "no map at all is not a measurement")
    t.eq(SC.classic_buttons_measured({ "LP" }, {}), false,
         "and neither is an empty one - which is what the register carries")
end

t.group("a classic profile from a register with only Modern bits still refuses")

do
    -- The register above has a verified Modern map and nothing classic. The
    -- profile built for classic from it must not borrow the Modern bits: L is
    -- 0x10 there, and LP and LK would both have to be 0x10 for that to work,
    -- which is exactly the confusion command_display's raw_button_mask already
    -- makes.
    local prof = InputMask.profile_from_provenance(P, reg, "classic")
    t.ok(prof ~= nil, "the profile builds")
    t.is_nil(prof and prof.buttons.LP, "with no bit for LP")
    t.is_nil(prof and prof.buttons.L, "and no Modern name smuggled in either")
    t.eq(prof and prof.measured, false, "and it says it is not measured")

    local mask, why = InputMask.button_mask({ "LK" }, prof)
    t.is_nil(mask, "so LK produces no mask")
    t.ok(tostring(why):find("LK", 1, true) ~= nil,
         "and the refusal names the button: " .. tostring(why))
end


return t.finish()
