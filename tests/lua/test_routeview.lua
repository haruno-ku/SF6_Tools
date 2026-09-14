-- Unit tests for tools/lua/routeview.lua
--
-- The page filters on what these rows carry - the no-gauge verdict, the pair
-- statuses, whether a route goes through a Drive Rush Cancel - so packing them
-- must lose nothing the page reads. The test is the round trip: compact, then
-- expand (the Lua twin of the page's hydrateRoutes), and compare.

local t = require("tests.lua.harness")
local RV = dofile("tools/lua/routeview.lua")

local ROWS = {
    {
        m = { "3 + 强", "6 + 强", "720 + 强" }, c = { "2+HK", "6+HK", "720+P" }, drc_after = {},
        sd = 6140.4, d = 7100, dc = true, od = 0, sa = 1, drc = 0, cost = 15.4,
        starter = { n = "3 + 强", b = { "H" } },
        no_gauge = "remove", no_super = "remove",
        pairs = {
            { k = "633:manual->662:manual", st = "rejected", press = "single" },
            { k = "662:manual->1218:manual", st = "untested", press = "single" },
        },
        rej = true, confirmed = nil, combo = nil,
    },
    {
        m = { "3 + 强", "2 + 中" }, c = { "2+HK" }, drc_after = {},
        sd = 1200, d = 1300, dc = false, od = 0, sa = 0, drc = 0, cost = 7,
        starter = { n = "3 + 强", b = { "H" } },
        no_gauge = "flag", no_super = "keep",
        pairs = { { k = "633:manual->621:manual", st = "verified", press = "repeat" } },
        confirmed = true, combo = "confirmed",
    },
    {
        m = { "2 + 中", "236236 + 中" }, c = { "2+MP", "236236+P" }, drc_after = { 1 },
        sd = 3000, d = 3500, dc = true, od = 0, sa = 1, drc = 1, cost = 9.5,
        starter = { n = "2 + 中", b = { "M" } },
        no_gauge = "remove", no_super = "remove",
        pairs = { { k = "621:manual->drc->1206:manual", st = "untested", press = "single", drc = true } },
    },
}

t.group("compact writes each move and each pair once")

local packed = RV.compact(ROWS)
t.eq(#packed.rows, 3, "one packed row per route")
t.eq(#packed.moves, 6, "moves are interned by notation and classic name")
t.eq(#packed.pairs, 4, "pairs are interned")
t.eq_list(packed.rows[1].m, { 0, 1, 2 }, "a row names its moves by 0-based index")
t.eq(packed.rows[2].m[1], 0, "the same move in another route reuses its entry")
t.eq(packed.moves[1].b[1], "H", "a starter's buttons ride on its move entry")
t.is_nil(packed.rows[1].drc, "no Drive Rush Cancel is left out")
t.eq(packed.rows[3].drc, 1, "a Drive Rush Cancel is written")
t.is_nil(packed.pairs[2].st, "an untested pair writes no status")
t.is_nil(packed.pairs[1].press, "a pressable pair writes no press kind")
t.eq(packed.pairs[4].drc, true, "a pair through a rush says so")
t.eq(packed.rows[1].sd, 6140, "scaled damage is rounded to a whole number")
t.eq(math.type(packed.rows[1].sd), "integer", "and encodes as an integer")
t.eq(packed.rows[1].ct, 154, "cost is carried in tenths")
t.eq(packed.rows[1].ng, "r", "verdicts are one letter")
t.is_nil(packed.rows[1].dc, "complete damage is the default")
t.eq(packed.rows[2].dc, false, "incomplete damage is written")
t.is_nil(packed.rows[1].da, "an empty DRC position list is left out")

t.group("expand gives back what the page reads")

local rows = RV.expand(packed)
t.eq(#rows, 3, "every row comes back")
t.eq_list(rows[1].m, ROWS[1].m, "moves")
t.eq_list(rows[1].c, ROWS[1].c, "classic names")
t.eq(rows[2].c[1], "2+HK", "a classic name")
t.is_nil(rows[2].c[2], "and a missing one stays missing")
t.eq(rows[1].starter.n, "3 + 强", "the starter is the first move")
t.eq(rows[3].starter.b[1], "M", "with its buttons")
t.eq(rows[1].no_gauge, "remove", "no-gauge verdict")
t.eq(rows[2].no_gauge, "flag", "a flag survives")
t.eq(rows[2].no_super, "keep", "no-super verdict")
t.eq(rows[1].pairs[1].st, "rejected", "a pair status")
t.eq(rows[1].pairs[2].st, "untested", "the default status comes back")
t.eq(rows[2].pairs[1].press, "repeat", "a press kind")
t.eq(rows[1].pairs[1].press, "single", "the default press kind comes back")
t.eq(rows[3].pairs[1].k, "621:manual->drc->1206:manual", "a DRC pair keeps its ->drc-> key")
t.eq(rows[3].pairs[1].drc, true, "and its flag")
t.eq(rows[1].pairs[1].drc, false, "a plain pair is not a DRC pair")
t.eq(rows[3].drc, 1, "the route's DRC count")
t.eq(rows[1].drc, 0, "zero when it has none")
t.eq_list(rows[3].drc_after, { 1 }, "where the rush sits")
t.eq(rows[1].cost, 15.4, "cost back from tenths")
t.eq(rows[2].dc, false, "incomplete damage")
t.eq(rows[1].dc, true, "complete damage")
t.eq(rows[1].rej, true, "a rejected pair mark")
t.eq(rows[2].rej, false, "its absence")
t.eq(rows[2].confirmed, true, "a confirmed combo")
t.eq(rows[2].combo, "confirmed", "and its status")
t.eq(rows[3].i, 2, "the rank position, the sort's tie-break")

t.group("nothing in, nothing out")

local empty = RV.compact({})
t.eq(#empty.rows + #empty.moves + #empty.pairs, 0, "no routes pack to empty tables")
t.eq(#RV.expand(empty), 0, "and expand to none")

return t.finish()
