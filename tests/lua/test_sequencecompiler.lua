-- Unit tests for func/ComboExplorer/core/SequenceCompiler.lua
--
-- This is where the offline half hands over to the real machine, so the two
-- things worth defending are both refusals.
--
-- No delay may be invented. A route arrives with delay_ticks nil on every step
-- because that number is what the sweep measures; compiling without one has to
-- fail rather than pick a plausible default that produces a working-looking
-- program.
--
-- No unverified profile may compile. A wrong button bit raises nothing - it
-- presses a button that does not exist, the move never comes out, and the trial
-- reads as "these moves do not link". A confident negative indistinguishable
-- from a real one is the worst output this project can produce.

local t = require("tests.lua.harness")
local SC = require("func/ComboExplorer/core/SequenceCompiler")
local IM = require("func/ComboExplorer/core/InputMask")
local RS = require("func/ComboExplorer/core/RouteSearch")
local GraphStore = require("func/ComboExplorer/core/GraphStore")
local CG = require("func/ComboExplorer/core/CandidateGenerator")
local Catalog = require("func/ComboExplorer/core/Catalog")
local FrameData = require("func/ComboExplorer/core/FrameData")

-- Stands in for a completed calibration. The values match the current
-- provisional guesses, but "verified" here is a statement about the test, not
-- an endorsement of the guess.
local VERIFIED = IM.profile({
    buttons = { L = 0x10, M = 0x80, H = 0x100, SP = 0x20, AUTO = 0x200,
                PARRY = 0x40, DI = 0x1000, THROW = 0x2000 },
    dir = { UP = 1, DOWN = 2, LEFT = 4, RIGHT = 8 },
    mirror_when = "falsy",
    status = "verified",
})
local UNVERIFIED = IM.profile({
    buttons = { L = 0x10, M = 0x80, H = 0x100, SP = 0x20 },
    dir = { UP = 1, DOWN = 2, LEFT = 4, RIGHT = 8 },
    status = "unverified",
})

local cat = Catalog.build(dofile("tests/lua/fixtures/zangief_catalog.lua"))
local idx = FrameData.index(dofile("tests/lua/fixtures/zangief_framedata.lua"))
local gen = CG.generate(cat, idx, {
    from = { categories = { "normal", "command_normal" }, input_methods = { "manual" } },
    to = { categories = { "normal", "command_normal", "special", "super" },
           input_methods = { "manual" } },
    include_followups = true,
})
local g = GraphStore.build(gen.candidates, { character = "zangief", game_patch = "p",
                                             ac_sha256 = "a", bcm_sha256 = "b" })
local found = RS.search(g, { frame_idx = idx, character = "zangief", control_scheme = "modern",
                             max_steps = 3, beam_width = 4000, max_routes = 20000 })

local function route_of_length(n, want_context)
    for _, r in ipairs(found.routes) do
        if r.length == n and (want_context == nil or r.context_dependent == want_context) then
            return r
        end
    end
end

local two = route_of_length(2, false)
local three = route_of_length(3, false)

-- --- the delay is never invented ---------------------------------------------

t.group("a delay has to be supplied")

t.ok(two ~= nil, "a two-step route exists to compile")
local nodelay, why = SC.compile(two, { profile = VERIFIED })
t.is_nil(nodelay, "compiling with no delay is refused")
t.ok(why:find("sweep") ~= nil, "and the refusal says why: " .. tostring(why))

-- The route itself still carries no delay after compiling - the compiler is
-- given one, it does not write one back.
local prog = SC.compile(two, { profile = VERIFIED, delay = 4 })
t.ok(prog ~= nil, "with a delay it compiles")
for _, s in ipairs(two.steps) do
    t.is_nil(s.delay_ticks, "and the route's own steps are left without a delay")
end

t.is_nil(SC.compile(three, { profile = VERIFIED, delays = { 3 } }),
         "a three-step route will not take two-step delays")
t.ok(SC.compile(three, { profile = VERIFIED, delays = { 3, 5 } }) ~= nil,
     "but takes one per gap")
t.is_nil(SC.compile(two, { profile = VERIFIED, delay = -1 }), "a negative delay is refused")
t.is_nil(SC.compile(two, { profile = VERIFIED, delay = 2.5 }), "so is a fractional tick")
t.ok(SC.compile(two, { profile = VERIFIED, delay = 0 }) ~= nil,
     "zero is a real answer, though, and compiles")

-- --- an unverified profile does not compile ----------------------------------

t.group("an unverified profile is refused")

local blocked, breason = SC.compile(two, { profile = UNVERIFIED, delay = 4 })
t.is_nil(blocked, "an unverified profile does not produce a program")
t.ok(breason:find("unverified") ~= nil, "and the reason names it: " .. tostring(breason))

local preview = SC.compile(two, { profile = UNVERIFIED, delay = 4, allow_unverified = true })
t.ok(preview ~= nil, "a read-only preview can opt in explicitly")
t.eq(preview.profile_status, "unverified",
     "and the program carries the status, so it cannot be replayed as if measured")

t.is_nil(SC.compile(two, { delay = 4 }), "no profile at all is refused")

-- --- the program shape -------------------------------------------------------

t.group("the program")

local p = SC.compile(three, { profile = VERIFIED, delays = { 4, 6 },
                              lead_ticks = 10, hold_ticks = 3, tail_ticks = 30 })
t.ok(p ~= nil, "a three-step route compiles")
t.eq(#p.steps, 3, "with one entry per step")
t.eq(#p.boundaries, 2, "and one boundary per gap")
t.eq(#p.raw_inputs, p.total_ticks, "the expanded program is one mask per tick")

-- The tick counts have to add up exactly, because the runner uses them to
-- decide which move a combo-count increase belongs to.
local sum = 0
for _, s in ipairs(p.seq) do sum = sum + s.frames end
t.eq(sum, p.total_ticks, "the step list and the tick total agree")

t.eq(p.steps[1].input_starts_at_tick, 10, "the first move starts after the lead")
t.eq(p.boundaries[1].delay_ticks, 4, "the first gap is the delay it was given")
t.eq(p.boundaries[2].delay_ticks, 6, "and the second is its own")
t.eq(p.boundaries[1].input_starts_at_tick, p.steps[2].input_starts_at_tick,
     "a boundary points at the tick the next move's input begins")

local monotone = true
for i = 2, #p.steps do
    if p.steps[i].input_starts_at_tick < p.steps[i - 1].input_ends_at_tick then
        monotone = false
    end
end
t.ok(monotone, "no two moves' inputs overlap")

-- The gap really is neutral: the pad is released for exactly the delay.
local released = 0
for tick = p.steps[1].input_ends_at_tick + 1, p.steps[2].input_starts_at_tick do
    if p.raw_inputs[tick] == 0 then released = released + 1 end
end
t.eq(released, 4, "the gap is four ticks of neutral, and nothing else")

t.eq(p.observe_from_tick, p.steps[3].input_ends_at_tick,
     "observation starts when the last input ends")
t.eq(p.tick_basis, "explorer_tick",
     "and the unit is named, because whether a tick is a frame is unverified")

-- --- the masks are the ones InputMask would build ----------------------------

t.group("masks")

-- Not a re-derivation: the same profile through the same module has to give the
-- same numbers, or the compiler has quietly grown its own bit table.
local first = two.steps[1]
local parsed = IM.parse(first.notation)
local expect = IM.compile(parsed, { profile = VERIFIED, lead_ticks = 0,
                                    hold_ticks = 3, tail_ticks = 0 })
local expect_masks = IM.expand(expect)
local got = {}
local prog2 = SC.compile(two, { profile = VERIFIED, delay = 4, lead_ticks = 10, hold_ticks = 3 })
for i = 1, #expect_masks do got[i] = prog2.raw_inputs[10 + i] end
t.eq_list(got, expect_masks, "the first move's ticks are exactly what InputMask builds")

-- A 360 is seven directions plus the held button, so it occupies more ticks
-- than a crouching normal. If it did not, the motion would be being skipped.
local spd_route
for _, r in ipairs(found.routes) do
    for _, s in ipairs(r.steps) do
        if (s.classic or ""):find("360", 1, true) then spd_route = r break end
    end
    if spd_route then break end
end
if spd_route then
    local sp = SC.compile(spd_route, { profile = VERIFIED, delay = 4, hold_ticks = 3 })
    local longest = 0
    for _, s in ipairs(sp.steps) do longest = math.max(longest, s.input_ticks) end
    t.ok(longest >= 6 + 3, "a 360 occupies its seven directions plus the hold")
else
    t.ok(true, "no 360 in this route set")
end

-- --- follow-ups --------------------------------------------------------------

t.group("target-combo derivations")

local ctx = route_of_length(2, true)
t.ok(ctx ~= nil, "a route ending in a follow-up exists")
local cp = SC.compile(ctx, { profile = VERIFIED, delay = 4 })
t.ok(cp ~= nil, "and compiles, because the move before it is the context")
t.eq(cp.context_dependent, true,
     "with the program marked, since a miss may be the previous step not connecting")

-- The same derivation on its own must not compile: nothing has set it up.
local orphan = { id = "x", steps = {
    { index = 1, action_id = 605, input_method = "manual", notation = "> \228\184\173" },
    { index = 2, action_id = 621, input_method = "manual", notation = "2 + \228\184\173" },
} }
local orph, oreason = SC.compile(orphan, { profile = VERIFIED, delay = 4 })
t.is_nil(orph, "a derivation cannot open a route")
t.ok(oreason:find("cannot open") ~= nil, "and the refusal says so: " .. tostring(oreason))

-- --- sweeping ----------------------------------------------------------------

t.group("sweeping a gap")

local programs, problems = SC.sweep(two, { profile = VERIFIED,
                                           range = { from = 0, to = 12, step = 1 } })
t.eq(#programs, 13, "a zero-to-twelve sweep is thirteen programs")
t.eq(#problems, 0, "and none of them failed to compile")
for i, prog3 in ipairs(programs) do
    t.eq(prog3.swept_delay, i - 1, ("program %d is delay %d"):format(i, i - 1))
end
t.ok(programs[13].total_ticks > programs[1].total_ticks,
     "a longer delay is a longer program")

local coarse = SC.sweep(two, { profile = VERIFIED, range = { from = 0, to = 12, step = 3 } })
t.eq(#coarse, 5, "a coarse sweep takes fewer samples")

-- A route with more than one gap has to say what the other gaps are doing,
-- for the same reason a delay is required at all.
local missing, mreason = SC.sweep(three, { profile = VERIFIED })
t.is_nil(missing, "a multi-gap route will not sweep without the other delays fixed")
t.ok(mreason:find("fixed") ~= nil, "and says which option is missing")

local swept = SC.sweep(three, { profile = VERIFIED, gap = 2, fixed = 3,
                                range = { from = 0, to = 4, step = 1 } })
t.eq(#swept, 5, "with them fixed, the second gap sweeps")
for _, prog4 in ipairs(swept) do
    t.eq(prog4.delays[1], 3, "the untouched gap holds its fixed delay")
end

t.is_nil(SC.sweep(two, { profile = VERIFIED, gap = 2 }), "sweeping a gap that does not exist is refused")
t.is_nil(SC.sweep(two, { profile = VERIFIED, range = { from = 0, to = 4, step = 0 } }),
         "a zero step would not terminate, and is refused")

-- --- limits ------------------------------------------------------------------

t.group("limits")

local huge, hreason = SC.compile(two, { profile = VERIFIED, delay = 4, max_ticks = 5 })
t.is_nil(huge, "a program over the tick limit is refused")
t.ok(hreason:find("limit") ~= nil, "with the limit named")

-- --- degenerate input --------------------------------------------------------

t.group("degenerate input")

t.is_nil(SC.compile(nil, { profile = VERIFIED, delay = 4 }), "no route is refused")
t.is_nil(SC.compile({ steps = {} }, { profile = VERIFIED, delay = 4 }),
         "a route with no steps is refused")
t.is_nil(SC.compile({ steps = { { index = 1 } } }, { profile = VERIFIED, delay = 4 }),
         "a one-step route is not a route")

local nonotation = { id = "y", steps = {
    { index = 1, action_id = 1, input_method = "manual" },
    { index = 2, action_id = 2, input_method = "manual", notation = "SP" },
} }
local nn, nreason = SC.compile(nonotation, { profile = VERIFIED, delay = 4 })
t.is_nil(nn, "a step with no notation is refused")
t.ok(nreason:find("step 1") ~= nil, "and the failing step is named")

-- A label that is not an input at all ("RAW DR") must not silently become a
-- direction-free, button-free run of neutral ticks.
local label = { id = "z", steps = {
    { index = 1, action_id = 1, input_method = "manual", notation = "RAW DR" },
    { index = 2, action_id = 2, input_method = "manual", notation = "SP" },
} }
t.is_nil(SC.compile(label, { profile = VERIFIED, delay = 4 }),
         "a pure label does not compile to an empty press")

t.ok(#SC.describe(prog, VERIFIED) == prog.total_ticks, "describe covers every tick")

return t.finish()
