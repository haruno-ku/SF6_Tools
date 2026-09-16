-- Unit tests for tools/lua/routefile.lua
--
-- A route file is a night on the game machine. The two ways it could waste one
-- are pinned here:
--
--   a gap given ONE number nobody measured, which reads as a measurement and
--   asks a single question that #46 says is usually the wrong one
--   a file core/Route.build refuses, which loads and then looks like something
--   to run
--
-- So: measured delays beat predicted, predicted beat the default range, and
-- every document this builds is handed to the real core/Route.build.

local t = require("tests.lua.harness")
dofile("tools/lua/cli.lua")
local RF = dofile("tools/lua/routefile.lua")
local Route = require("func/ComboExplorer/core/Route")
local Sweep = require("func/ComboExplorer/runtime/Sweep")

local function mv(id, notation, method)
    return { action_id = id, notation = notation, input_method = method or "manual" }
end

-- --- what Route.build will take -----------------------------------------------------

t.group("refusal: the same refusals core/Route.build makes")

t.is_nil(RF.refusal({ steps = { mv(1, "a"), mv(2, "b") } }), "two named moves are fine")
t.ok(RF.refusal({ steps = { mv(1, "a") } }):find("two steps") ~= nil,
    "one move is not a combo")
t.ok(RF.refusal({ steps = { mv(1, "a"), { kind = "drive_rush_cancel" }, mv(2, "b") } })
        :find("drive_rush_cancel") ~= nil,
    "a Drive Rush Cancel step has no action id core/Route.build can name")
t.ok(RF.refusal({ steps = { mv(1, "a"), { action_id = 2, input_method = "manual" } } })
        :find("notation") ~= nil,
    "a step with no notation cannot be compiled into inputs")
t.ok(RF.refusal({ steps = { mv(1, "a"), { action_id = 2, input_method = "auto", notation = "b" } } })
        :find("input_method") ~= nil,
    "an input method that is not manual, simple or assist is refused")
t.ok(RF.refusal({ steps = { mv(1, "a"), { input_method = "manual", notation = "b" } } })
        :find("action_id") ~= nil,
    "a step with no action id is refused")

-- The refusals are not this file's opinion: the same routes go to Route.build.
local drc_doc = { schema = Route.SCHEMA, steps = {
    { action_id = 1, input_method = "manual", notation = "a" },
    { kind = "drive_rush_cancel" },
    { action_id = 2, input_method = "manual", notation = "b" } } }
t.is_nil((Route.build(drc_doc)), "core/Route.build refuses the DRC document too")

-- --- where a gap's delays come from --------------------------------------------------

t.group("measured beats predicted")

-- A planner known entry: one evaluation per cohort, each with the gaps the
-- policy's counted runs linked at.
local entry = { evaluations = {
    { result = "reproduced", linked_gaps = { "44", "40" } },
    { result = "observed_success", linked_gaps = { "40" } },
} }

local d, why = RF.measured_delays(entry, "ce-eval-v1")
t.eq_list(d, { 40, 44 }, "every gap that linked, sorted, once each")
-- Plain find: "-" is a pattern quantifier, and the policy key has two of them.
t.ok(why:find("ce-eval-v1", 1, true) ~= nil, "and the why names the policy that counted them")

t.is_nil((RF.measured_delays({ evaluations = {
    { result = "no_success_observed", linked_gaps = {} } } })),
    "a pair that never linked has nothing measured")
t.is_nil((RF.measured_delays(nil)), "and neither has a pair with no entry")

-- A route's delay key is a vector ("40/2"), not one pair's gap.
t.is_nil((RF.measured_delays({ evaluations = { { linked_gaps = { "40/2" } } } })),
    "a route's gap vector is not read as a pair's gap")

t.group("predicted: the grid the sweep would try")

-- A link pair: the frame data states one gap, and core/Timing widens it by the
-- input buffer. Numbers as runtime/Sweep hands them over.
local link_pair = { a_startup = 22, a_active = "7(5)", a_recovery = 25, a_hitstop = 13,
                    a_hitstun = 30, b_startup = 6, b_notation = "720 + H",
                    mechanism = "link" }
local pd, pwhy = RF.predicted_delays(link_pair, Sweep.plan_for,
                                     { hold_ticks = 3, buffer_ticks = 4 })
t.eq(#pd, 5, "the link window is the buffer's width, not one number")
t.eq(pd[#pd], 59, "ending at the gap A becomes free (22+12+25+13 - 3 hold)")
t.eq(pd[1], 55, "and opening four ticks earlier, which is what the buffer covers")
t.ok(pwhy:find("link window") ~= nil, "the why says which window it was")

-- Without the buffer there is no link window at all, and the file must not
-- pretend there is one.
t.is_nil((RF.predicted_delays(link_pair, Sweep.plan_for, { hold_ticks = 3 })),
    "no input buffer, no predicted link window")

local cancel_pair = { a_startup = 7, a_active = "3", a_recovery = 9, a_hitstop = 9,
                      a_hitstun = 12, b_startup = 22, b_notation = "6 + H",
                      mechanism = "cancel" }
local cd, cwhy = RF.predicted_delays(cancel_pair, Sweep.plan_for,
                                     { hold_ticks = 3, buffer_ticks = 4 })
t.ok(#cd >= 2, "a cancel pair is a grid, because nobody has measured where the window ends")
t.ok(cwhy:find("cancel") ~= nil, "and says so")

t.is_nil((RF.predicted_delays({ mechanism = "link" }, Sweep.plan_for,
                              { hold_ticks = 3, buffer_ticks = 4 })),
    "a pair with no frame data predicts nothing")
t.is_nil((RF.predicted_delays(nil, Sweep.plan_for)), "and neither does no pair")

t.group("delays_for: measured, else predicted, else the sweep's own range")

local got = RF.delays_for({ entry = entry, item = link_pair, plan_for = Sweep.plan_for,
                            sweep_opts = { hold_ticks = 3, buffer_ticks = 4 },
                            policy_key = "ce-eval-v1" })
t.eq(got.source, "measured", "a measurement wins over a prediction")
t.eq_list(got.delays, { 40, 44 }, "and is what goes in the file")

got = RF.delays_for({ item = link_pair, plan_for = Sweep.plan_for,
                      sweep_opts = { hold_ticks = 3, buffer_ticks = 4 } })
t.eq(got.source, "predicted", "with nothing measured, the frame data's window")

got = RF.delays_for({ no_window_reason = "no candidate edge carries this pair" })
t.eq(got.source, "default", "with neither, the default range")
t.eq(#got.delays, #Route.DEFAULT_DELAYS, "which is core/Route.DEFAULT_DELAYS, whole")
t.ok(#got.delays > 1, "never one invented number")
t.ok(got.why:find("no candidate edge") ~= nil, "and the file says why it had to")

-- --- the document ---------------------------------------------------------------------

t.group("build: a document core/Route.build takes")

local r3 = { id = "r3", steps = { mv(660, "AUTO + H", "simple"), mv(655, "3 + M"),
                                  mv(900, "2 + SP", "simple") } }
local doc, info = RF.build(r3, {
    id = "zangief-modern-max-damage-1", character = "Zangief", control_scheme = "modern",
    plan = { name = "max-damage", rank = 1, sort = "scaled_damage" },
    status = "0/2 pairs reproduced",
    gaps = {
        { pair = "660:simple->655:manual", delays = { 40, 44 }, source = "measured",
          why = "the gaps this pair actually linked at" },
        { pair = "655:manual->900:simple", delays = { 2, 4, 6 }, source = "predicted",
          why = "the predicted cancel gap" },
    },
})
t.ok(doc ~= nil, "a three-move route builds")
t.eq(doc.schema, "ce.route.v1", "as a ce.route.v1")
t.eq(#doc.delays, 2, "with one delay list per gap")
t.eq_list(doc.delays[1], { 40, 44 }, "the first gap's")
t.eq(info.combinations, 6, "and the grid is the product, reported")
t.eq(info.by_source.measured, 1, "the sources are counted")
t.ok(doc.note:find("measured") ~= nil, "the note says where gap 1 came from")
t.ok(doc.note:find("predicted") ~= nil, "and gap 2")
t.ok(doc.note:find("0/2 pairs reproduced") ~= nil, "and what the logs already say")
t.eq(doc.gaps[1].source, "measured", "the sources are fields too, not only prose")
t.eq(doc.plan.name, "max-damage", "and the plan that asked for the file is named")

local built, rep = Route.build(doc)
t.ok(built ~= nil, "core/Route.build takes it: " .. tostring(rep))
t.eq(#built.steps, 3, "with all three steps")
local grid = Route.delay_grid(#built.steps - 1, built.delays)
t.eq(#grid, 6, "and core/Route.delay_grid makes the six combinations from its own lists")

t.group("build: what it refuses")

local bad, badwhy = RF.build({ steps = { mv(1, "a"), { kind = "drive_rush_cancel" }, mv(2, "b") } },
    { id = "x", gaps = { { delays = { 2 } }, { delays = { 2 } } } })
t.is_nil(bad, "a route with a Drive Rush Cancel step is not written")
t.ok(tostring(badwhy):find("drive_rush_cancel") ~= nil, "naming the step")

bad, badwhy = RF.build(r3, { id = "x", gaps = { { delays = { 2 }, source = "measured" } } })
t.is_nil(bad, "a document whose gaps do not match the route is not written")
t.ok(tostring(badwhy):find("2 gap") ~= nil, "saying how many it wanted")

bad, badwhy = RF.build(r3, { id = "x", gaps = {
    { delays = { 2 }, source = "measured" }, { delays = {}, source = "measured" } } })
t.is_nil(bad, "an empty delay list is not written")
t.ok(tostring(badwhy):find("empty") ~= nil, "saying which gap")

t.group("file_name")

t.eq(RF.file_name("zangief", "modern", "max-damage", 3), "zangief-modern-max-damage-3",
    "<char>-<scheme>-<plan>-<rank>, the name the panel's route list parses")

return t.finish()
