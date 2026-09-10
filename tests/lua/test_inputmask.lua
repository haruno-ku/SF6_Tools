-- Unit tests for func/ComboExplorer/InputMask.lua
-- Run:  lua tests/lua/run.lua        (from the repo root)
--
-- The notation fixtures are not invented: they are the 66 distinct
-- simple_command / motion_command display strings that actually appear in
-- reframework/data/TrainingComboTrials_data/command_display/Zangief.json.
-- If the parser cannot handle one of these, the Move Catalog silently loses a
-- move, so every one of them is asserted here.

local t = require("tests.lua.harness")
local IM = require("reframework.autorun.func.ComboExplorer.InputMask")

-- --- direction bits ----------------------------------------------------------

t.group("direction bits")

t.eq(IM.NUMPAD["5"], 0, "neutral is 0")
t.eq(IM.NUMPAD["8"], 1, "up")
t.eq(IM.NUMPAD["2"], 2, "down")
t.eq(IM.NUMPAD["4"], 4, "back")
t.eq(IM.NUMPAD["6"], 8, "forward")
t.eq(IM.NUMPAD["1"], 6, "down-back = down|back")
t.eq(IM.NUMPAD["3"], 10, "down-forward = down|forward")
t.eq(IM.NUMPAD["7"], 5, "up-back")
t.eq(IM.NUMPAD["9"], 9, "up-forward")

-- The one table in the suite that disagrees is RSM's MASKS (RIGHT=4, LEFT=8),
-- used for record-slot timelines. Guard against anyone "fixing" ours to match.
t.ok(IM.DIR.LEFT == 4 and IM.DIR.RIGHT == 8,
     "LEFT=4/RIGHT=8, matching the two pl_input_new readers")

t.eq_list(IM.dirs_from_numpad("236"), { 2, 10, 8 }, "quarter-circle forward")
t.eq_list(IM.dirs_from_numpad("2"), { 2 }, "single direction is a one-element list")
t.eq_list(IM.dirs_from_numpad("63214"), { 8, 10, 2, 6, 4 }, "half-circle back")
t.is_nil(IM.dirs_from_numpad("xyz"), "no digits -> nil")

-- --- modern button bits ------------------------------------------------------

t.group("modern button bits")

-- Cross-check against routes[].raw_button_mask in Zangief.json: L=16, M=128,
-- H=256, SP=32, THROW=144. If these ever disagree, the catalog and the injector
-- have drifted apart.
t.eq(IM.MODERN.L, 16, "L on the classic LP bit")
t.eq(IM.MODERN.M, 128, "M on the classic LK bit")
t.eq(IM.MODERN.H, 256, "H on the classic MK bit")
t.eq(IM.MODERN.SP, 32, "SP on the classic MP bit")
t.eq(IM.MODERN.AUTO, 512, "Assist on the classic HK bit")

t.eq(IM.modern_button_mask({ "L", "M" }), 144, "L|M == THROW's raw_button_mask 144")
t.eq(IM.modern_button_mask({ "M", "H" }), 384, "M|H matches raw_button_mask 384")
t.eq(IM.modern_button_mask({ "L", "M", "H" }), 400, "L|M|H matches raw_button_mask 400")
t.eq(IM.modern_button_mask({ "SP", "H" }), 288, "SP|H matches raw_button_mask 288")
t.is_nil(IM.modern_button_mask({ "LP" }), "classic name rejected under modern")

-- --- notation parsing --------------------------------------------------------

t.group("notation parsing")

local p = IM.parse("2 + \228\184\173")           -- "2 + 中"
t.eq_list(p.dirs, { 2 }, "2+M dirs")
t.eq_list(p.buttons, { "M" }, "2+M buttons")
t.eq(p.air, false, "2+M is grounded")

p = IM.parse("3 + \229\188\186")                 -- "3 + 强"
t.eq_list(p.dirs, { 10 }, "3+H dirs")
t.eq_list(p.buttons, { "H" }, "3+H buttons")

p = IM.parse("SP")
t.eq_list(p.dirs, {}, "SP has no direction")
t.eq_list(p.buttons, { "SP" }, "SP button")

p = IM.parse("AUTO + \229\188\177")              -- "AUTO + 弱"
t.eq_list(p.buttons, { "AUTO", "L" }, "assist plus light, AUTO matched first")
t.ok(p.assist, "assist flagged")

p = IM.parse("\231\169\186\228\184\173 360 + \229\188\186")  -- "空中 360 + 强"
t.ok(p.air, "air flagged")
t.eq_list(p.dirs, { 8, 10, 2, 6, 4, 5, 1 }, "360 expands to seven directions")
t.eq_list(p.buttons, { "H" }, "360+H button")

p = IM.parse("360 + \228\187\187\230\132\143\233\148\174 + \228\187\187\230\132\143\233\148\174")
t.ok(p.any_button, "any-button flagged")
t.eq_list(p.buttons, {}, "any-button contributes no concrete button")

p = IM.parse("> \228\184\173")                   -- "> 中"
t.ok(p.followup, "leading > marks a follow-up derivation")
t.eq_list(p.buttons, { "M" }, "follow-up still parses its button")

p = IM.parse("\229\188\177 + \228\184\173 + \229\188\186")  -- "弱 + 中 + 强"
t.eq_list(p.buttons, { "L", "M", "H" }, "three strengths in table order")

p = IM.parse("2 + SP + \229\188\186")            -- "2 + SP + 强"
t.eq_list(p.dirs, { 2 }, "2+SP+H direction")
t.eq_list(p.buttons, { "SP", "H" }, "2+SP+H buttons")

p = IM.parse("66")
t.eq_list(p.dirs, { 8, 8 }, "dash is two forwards")
t.eq_list(p.buttons, {}, "dash has no button")

-- Pure labels carry no input at all.
for _, label in ipairs({ "N", "DP", "DRC", "RAW DR" }) do
    t.is_nil(IM.parse(label), "label with no input: " .. label)
end

-- --- every real Zangief notation must parse or be a known label --------------

t.group("all 66 Zangief catalog notations")

local LABELS = { N = true, DP = true, DRC = true, ["RAW DR"] = true }
local FIXTURES = dofile("tests/lua/fixtures/zangief_notations.lua")

t.eq(#FIXTURES, 66, "fixture count matches the catalog")

local parsed_ok, label_ok = 0, 0
for _, s in ipairs(FIXTURES) do
    local r, err = IM.parse(s)
    if r then
        parsed_ok = parsed_ok + 1
        -- Anything that parsed must also compile, unless it is an any-button
        -- notation (which deliberately refuses) or a pure movement string.
        if not r.any_button then
            local seq, cerr = IM.compile(r, { modern = true })
            t.ok(seq ~= nil, "compiles: " .. s .. (cerr and (" -- " .. cerr) or ""))
        end
    elseif LABELS[s] then
        label_ok = label_ok + 1
    else
        t.fail("unparsed and not a known label: " .. s .. " (" .. tostring(err) .. ")")
    end
end
t.eq(parsed_ok + label_ok, 66, "every notation either parsed or is a known label")
t.eq(label_ok, 4, "exactly four pure labels")

-- --- facing mirror -----------------------------------------------------------

t.group("facing mirror")

t.eq(IM.mirror(8, true), 8, "facing right: forward stays bit 8")
t.eq(IM.mirror(8, false), 4, "facing left: forward becomes screen-left")
t.eq(IM.mirror(4, false), 8, "facing left: back becomes screen-right")
t.eq(IM.mirror(10, false), 6, "down-forward mirrors to down-back, down preserved")
t.eq(IM.mirror(2, false), 2, "vertical is unaffected")
t.eq(IM.mirror(0x100, false), 0x100, "buttons are unaffected")
t.eq(IM.mirror(IM.mirror(10, false), false), 10, "mirroring twice is identity")

-- --- compile / expand --------------------------------------------------------

t.group("compile and expand")

local seq = IM.compile(IM.parse("2 + \228\184\173"), { lead_ticks = 3, hold_ticks = 3, tail_ticks = 5 })
t.eq(#seq, 3, "no-motion move is lead, hold, tail")
t.eq(seq[1].mask, 0, "lead is neutral")
t.eq(seq[2].mask, 2 | 128, "hold is direction|button")
t.eq(seq[2].frames, 3, "hold length honoured")
t.eq(seq[3].mask, 0, "tail is neutral")

local ticks = IM.expand(seq)
t.eq(#ticks, 11, "3 + 3 + 5 ticks")
t.eq(ticks[1], 0, "first tick neutral")
t.eq(ticks[4], 130, "fourth tick is the input")
t.eq(ticks[11], 0, "last tick neutral")

-- A motion plays one direction per tick, buttons only on the last.
local mseq = IM.compile(IM.parse("236 + \229\188\186"), { lead_ticks = 1, hold_ticks = 2, tail_ticks = 1 })
local mt = IM.expand(mseq)
t.eq_list(mt, { 0, 2, 10, 8 | 256, 8 | 256, 0 }, "236+H plays digit-per-tick, button on the last")

t.is_nil(IM.compile(IM.parse("360 + \228\187\187\230\132\143\233\148\174 + \228\187\187\230\132\143\233\148\174")),
         "any-button notation refuses to compile")

-- --- describe ----------------------------------------------------------------

t.group("describe")

t.eq(IM.describe(2 | 128, true), "2+M", "modern readback")
t.eq(IM.describe(2 | 128, false), "2+LK", "same bits read as classic")
t.eq(IM.describe(0, true), "5", "neutral")
t.eq(IM.describe(0x20 | 0x100, true), "5+H+SP", "buttons listed in table order")

return t.finish()
