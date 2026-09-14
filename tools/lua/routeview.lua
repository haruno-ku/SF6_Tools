-- =========================================================
-- tools/lua/routeview.lua - the route finder's rows, packed for the page.
-- Dev-machine only, like the rest of tools/.
-- =========================================================
--
-- WHY THIS EXISTS
--
-- report.lua embeds every candidate route in the page it writes, so the finder
-- can narrow them without a server. Written out one object per route, a row
-- repeats its move names, its classic names and its pair keys in full, and the
-- same forty moves and few hundred pairs are spelled out again in every one of
-- a thousand routes: 430KB of Zangief's 740KB page was the finder alone. With a
-- page for each of 31 characters, and Drive Rush Cancel routes on top, that is
-- the difference between a docs folder people can clone and one they cannot.
--
-- So the moves and the pairs are written once each, in tables of their own, and
-- a row names them by index. The page expands the rows back to the shape it
-- draws before it draws anything (hydrateRoutes in report-template.html), and
-- M.expand below is the same expansion in Lua, so the round trip has a test.
--
-- WHAT IS LEFT OUT
--
-- Only what the page never read: the route id (the rows arrive ranked, so the
-- position is the tie-break), the per-move input methods, the route length,
-- the confidence, the drive spend and the starter's "no direction" flag. A
-- verdict or a status is never left out - the page filters on those, and they
-- are computed in Lua by planner.lua, not re-derived in the browser.
--
-- Defaults are omitted rather than written: a pair is "untested" and "single"
-- unless it says otherwise, a route has no Drive Rush Cancel and complete damage
-- unless it says otherwise. Every omission is undone by M.expand.

local M = { name = "tools.routeview" }

-- Verdicts, one letter each. planner.lua's filter says keep, flag or remove.
M.VERDICT = { keep = "k", flag = "f", remove = "r" }
M.VERDICT_NAME = { k = "keep", f = "flag", r = "remove" }

M.DEFAULT_STATUS = "untested"
M.DEFAULT_PRESS = "single"

local function nz(v) return (v ~= nil and v ~= 0) and v or nil end

-- Whole numbers, because the encoder writes a double to 17 significant digits:
-- an execution cost of 15.4 comes out as 15.4000000000000004, a thousand times.
-- The page shows scaled damage rounded and cost to one place, so this loses
-- nothing it draws. Cost is carried in tenths.
local function round(v)
    if type(v) ~= "number" then return nil end
    return math.tointeger(math.floor(v + 0.5)) or v
end
M.round = round

-- rows : report.lua's full rows, ranked. Each has
--   m, c                   move notations and classic names, in order
--   drc_after              indices (0-based move counts) a DRC follows
--   sd, d, dc, od, sa, drc, cost  (packed as sd and d rounded, cost as ct tenths)
--   starter = { n, b }     the first move and its buttons
--   no_gauge, no_super     "keep" | "flag" | "remove"
--   pairs = { { k, st, press, drc } }
--   rej, confirmed, combo
--
-- Returns { moves, pairs, rows }, indices 0-based for the page.
function M.compact(rows)
    local moves, move_at = {}, {}
    local pair_list, pair_at = {}, {}
    local out = {}

    local function move_index(n, c)
        local key = tostring(n) .. "\0" .. tostring(c)
        local i = move_at[key]
        if not i then
            moves[#moves + 1] = { n = n, c = c }
            i = #moves - 1
            move_at[key] = i
        end
        return i
    end

    local function pair_index(p)
        local st = p.st ~= M.DEFAULT_STATUS and p.st or nil
        local press = p.press ~= M.DEFAULT_PRESS and p.press or nil
        local drc = p.drc and true or nil
        local key = table.concat({ tostring(p.k), tostring(st), tostring(press), tostring(drc) }, "\0")
        local i = pair_at[key]
        if not i then
            pair_list[#pair_list + 1] = { k = p.k, st = st, press = press, drc = drc }
            i = #pair_list - 1
            pair_at[key] = i
        end
        return i
    end

    for ri, r in ipairs(rows or {}) do
        local mi = {}
        for j, n in ipairs(r.m or {}) do mi[j] = move_index(n, (r.c or {})[j]) end
        -- The buttons belong to the notation, so they ride on the move entry
        -- the first time a route starts with it.
        local first = moves[(mi[1] or -1) + 1]
        if first and r.starter and r.starter.b and #r.starter.b > 0 and not first.b then
            first.b = r.starter.b
        end
        local pi = {}
        for j, p in ipairs(r.pairs or {}) do pi[j] = pair_index(p) end
        local row = {
            m = mi,
            p = pi,
            da = (r.drc_after and #r.drc_after > 0) and r.drc_after or nil,
            sd = round(r.sd), d = round(r.d),
            od = nz(r.od), sa = nz(r.sa), drc = nz(r.drc),
            ct = r.cost and round(r.cost * 10) or nil,
            ng = M.VERDICT[r.no_gauge], ns = M.VERDICT[r.no_super],
            rej = r.rej and true or nil,
            cf = r.confirmed and true or nil,
            cb = r.combo,
        }
        -- Assigned apart: `x and false or nil` is always nil in Lua.
        if r.dc == false then row.dc = false end
        out[ri] = row
    end
    return { moves = moves, pairs = pair_list, rows = out }
end

-- The page's hydrateRoutes, in Lua. `i` is the row's position, which the page
-- uses to break sort ties.
function M.expand(packed)
    local rows = {}
    for ri, r in ipairs(packed.rows or {}) do
        local m, c = {}, {}
        for j, idx in ipairs(r.m) do
            local mv = packed.moves[idx + 1]
            m[j], c[j] = mv.n, mv.c
        end
        local first = packed.moves[(r.m[1] or -1) + 1] or {}
        local ps = {}
        for j, idx in ipairs(r.p) do
            local p = packed.pairs[idx + 1]
            ps[j] = { k = p.k, st = p.st or M.DEFAULT_STATUS, press = p.press or M.DEFAULT_PRESS,
                      drc = p.drc == true }
        end
        rows[ri] = {
            i = ri - 1, m = m, c = c, drc_after = r.da or {},
            sd = r.sd, d = r.d, dc = r.dc ~= false,
            od = r.od or 0, sa = r.sa or 0, drc = r.drc or 0,
            cost = r.ct and r.ct / 10 or nil,
            starter = { n = first.n, b = first.b or {} },
            no_gauge = M.VERDICT_NAME[r.ng], no_super = M.VERDICT_NAME[r.ns],
            pairs = ps, rej = r.rej == true, confirmed = r.cf == true, combo = r.cb,
        }
    end
    return rows
end

return M
