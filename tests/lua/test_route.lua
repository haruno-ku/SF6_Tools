-- Unit tests for func/ComboExplorer/core/Route.lua
--
-- A route is written BY HAND, which is where typos live, and the cost of a
-- wrong action id is a trial that runs, looks fine, and answers about a
-- different move. So most of what is asserted here is refusals.
--
-- The reason the module exists is #48: the first 202 rows of #12 found 8 links
-- and every one was a Super Art, so nothing in that file shows the pipeline can
-- see a LINK. A route a human knows connects is what can show it.

local t = require("tests.lua.harness")
local Route = require("func/ComboExplorer/core/Route")
local Catalog = require("func/ComboExplorer/core/Catalog")

local RAW = dofile("tests/lua/fixtures/zangief_catalog.lua")
local CAT = (Catalog.build(RAW))

-- Built from the catalog rather than typed, so this cannot drift from what the
-- module is asked to check against.
local function two_real_steps()
    local out = {}
    for _, g in pairs(CAT.groups or {}) do
        local id = (g.action_ids or {})[1]
        if id and g.notation and #out < 2 then
            out[#out + 1] = { action_id = id, input_method = "manual",
                              notation = g.notation }
        end
    end
    return out
end

local function doc(over)
    local d = {
        schema = "ce.route.v1",
        id = "ground-truth",
        character = CAT.character,
        control_scheme = "modern",
        steps = two_real_steps(),
    }
    for k, v in pairs(over or {}) do d[k] = v end
    return d
end

-- --- the happy path ----------------------------------------------------------

t.group("a route the catalog agrees with")

do
    local r, rep = Route.build(doc(), CAT)
    t.ok(r ~= nil, "builds: " .. tostring(rep))
    t.eq(#r.steps, 2, "carrying both steps")
    t.eq(r.steps[1].index, 1, "indexed for the compiler")
    t.eq(r.steps[2].index, 2, "in order")
    t.eq(r.control_scheme, "modern", "with the scheme")
    t.eq(#rep.problems, 0, "and nothing to report")
end

do
    -- No catalog: usable, because a caller may be building a route before a
    -- battle exists. The identity checks are what is lost, not the route.
    local r = Route.build(doc())
    t.ok(r ~= nil, "a route builds with no catalog to check against")
end

-- --- the refusals ------------------------------------------------------------

t.group("what it will not build")

local function why(over, cat)
    local r, reason = Route.build(doc(over), cat)
    t.is_nil(r, "refused")
    return tostring(reason)
end

t.ok(why({ schema = "ce.worklist.v1" }):find("not a route") ~= nil,
     "a worklist is not a route")
t.ok(tostring(select(2, Route.build(nil))):find("not a route document") ~= nil,
     "and neither is nil")

do
    local w = why({ steps = { two_real_steps()[1] } })
    t.ok(w:find("at least two") ~= nil, "one move is not a combo: " .. w)
end

do
    local s = two_real_steps()
    s[2].action_id = nil
    local w = why({ steps = s })
    t.ok(w:find("step 2") ~= nil, "the failing step is named: " .. w)
    t.ok(w:find("action_id") ~= nil, "and what was wrong with it")
end

do
    local s = two_real_steps()
    s[1].input_method = "classic"
    local w = why({ steps = s })
    t.ok(w:find("manual") ~= nil and w:find("simple") ~= nil,
         "an input method the compiler cannot use is refused by name: " .. w)
end

do
    local s = two_real_steps()
    s[1].notation = nil
    local w = why({ steps = s })
    t.ok(w:find("notation") ~= nil,
         "a step with no notation cannot become inputs: " .. w)
end

do
    -- The one that would otherwise run and answer about somebody else's move.
    local s = two_real_steps()
    s[2].action_id = 999999
    local w = why({ steps = s }, CAT)
    t.ok(w:find("999999") ~= nil, "an id this catalog does not have is named: " .. w)
    t.ok(w:find("step 2") ~= nil, "with the step it is in")
end

do
    local w = why({ character = "Ryu" }, CAT)
    t.ok(w:find("Ryu") ~= nil and w:find(CAT.character) ~= nil,
         "a route for another character says both names: " .. w)
end

-- --- the disagreement that is reported, not refused ---------------------------

t.group("a notation that does not match is a problem, not a correction")

do
    -- Refusing here would make a route unusable over a catalog whose display
    -- text changed; correcting it silently would press what the operator did
    -- not ask for. It reports.
    local s = two_real_steps()
    s[1].notation = "something the catalog does not call it"
    local r, rep = Route.build(doc({ steps = s }), CAT)
    t.ok(r ~= nil, "it still builds")
    t.eq(#rep.problems, 1, "with one problem")
    t.eq(rep.problems[1].step, 1, "naming the step")
    t.ok(tostring(rep.problems[1].reason):find("catalog calls it") ~= nil,
         "and both readings: " .. tostring(rep.problems[1].reason))
    t.eq(r.steps[1].notation, s[1].notation,
         "and the file's own text survives - it is what gets compiled")
end

-- --- the delay grid -----------------------------------------------------------

t.group("the gaps are a grid, not a list walked in step")

-- #46: one gap answers one question. A three-move route has TWO gaps and they
-- are not the same question - the gap into a special is not the gap into a
-- normal - so "does this connect at all" means trying them against each other.

do
    local g = Route.delay_grid(1, { 2, 4, 6 })
    t.eq(#g, 3, "one gap is just the list")
    t.eq(g[1][1], 2, "in order")
end

do
    local g = Route.delay_grid(2, { 2, 4, 6 })
    t.eq(#g, 9, "two gaps is every pair, not three")
    -- The assertion that would catch a zip: a zipped list gives 3 rows and
    -- never tries gap1=2 with gap2=6.
    local found = false
    for _, row in ipairs(g) do
        if row[1] == 2 and row[2] == 6 then found = true end
    end
    t.ok(found, "including the combinations a zipped walk would never reach")
end

do
    -- The cap is REPORTED. A truncated grid that says nothing reads as a
    -- completed search, which is the same failure as a sweep that skips
    -- silently.
    local g, note = Route.delay_grid(3, { 2, 4, 6, 8 }, 10)
    t.eq(#g, 10, "the cap holds")
    t.ok(note ~= nil, "and it is not silent")
    t.ok(tostring(note):find("54") ~= nil,
         "saying how many were not tried: " .. tostring(note))
end

do
    local g = Route.delay_grid(2)
    t.eq(#g, #Route.DEFAULT_DELAYS * #Route.DEFAULT_DELAYS,
         "with no list it uses the default range")
    -- The default has to include a gap wide enough for a link. #12's whole
    -- problem was that 4 only ever reaches a cancel window.
    local widest = 0
    for _, d in ipairs(Route.DEFAULT_DELAYS) do
        if d > widest then widest = d end
    end
    t.ok(widest >= 20, "which reaches past a cancel window: widest is " .. widest)
end

return t.finish()
