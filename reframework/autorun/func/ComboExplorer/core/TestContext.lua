-- =========================================================
-- ComboExplorer/core/TestContext.lua - what conditions a trial ran under.
-- Pure: takes the stage configuration that was actually applied, returns a
-- record. No sdk, no json, no paths.
-- =========================================================
--
-- THE FIELD THAT EXISTED AND WAS NEVER SET
--
-- runtime/Injector.lua has carried `opts.conditions` onto every record since it
-- was written, and nothing in this repository ever passed one. Sweep did not,
-- the panel did not, and ResultCollector.IDENTITY_FIELDS has listed
-- `conditions` as part of a trial's identity the whole time with nothing to put
-- there.
--
-- So a sweep run today would produce a few hundred lines that cannot say
-- whether the fighters were midscreen or in the corner, whether the hit was a
-- counter, or what the gauges held. None of that is recoverable afterwards. It
-- is the one piece of this project's data that a later pass cannot fill in,
-- because the conditions stopped existing when the trial ended.
--
-- WHAT IT REFUSES TO SAY
--
-- StageControl.DEFAULTS ships with `target_positions = false` and `pin = false`
-- - the first hardware run deliberately keeps to one moving part - so the truth
-- about a trial run today is "the positions were not controlled", not
-- "midscreen". Writing the second would be inventing a measurement, and it is
-- the sort of invention that is invisible later: every row would read like a
-- controlled experiment.
--
-- Hence `controlled = false` with the reason attached, rather than a position.
-- And `counter_state` starts at `unknown` rather than `normal`: nothing in the
-- runtime observes it yet, and `normal` is an answer.
--
-- WHY THERE IS A CANONICAL STRING AND A HASH, AND WHICH ONE IS THE TRUTH
--
-- The canonical string IS the identity. The hash is an index built from it, for
-- a database column that wants a fixed-width key.
--
-- They are not interchangeable and the order matters: two different sets of
-- conditions that happened to hash the same would be merged into one cohort,
-- and merging two cohorts is precisely the failure #38 warns about. So
-- everything that compares conditions compares the string, and the hash is
-- never the thing a decision rests on.

local M = { name = "ComboExplorer.TestContext" }

M.SCHEMA = "ce.conditions.v1"

-- Whether the hit was a counter. `unknown` is the starting value and a real
-- one: no part of the runtime reads counter state yet, so every trial run today
-- is honestly unknown rather than honestly normal.
M.COUNTER = {
    NORMAL  = "normal",
    COUNTER = "counter",
    PUNISH  = "punish",
    UNKNOWN = "unknown",
}

local COUNTER_SET = {}
for _, v in pairs(M.COUNTER) do COUNTER_SET[v] = true end

-- Where on the stage the trial happened. Even with the positions controlled
-- this stays `unknown` unless somebody measured the stage: an x of 150 is not
-- "midscreen" until the width of the stage is a number we have.
M.SCREEN = {
    MIDSCREEN = "midscreen",
    CORNER    = "corner",
    UNKNOWN   = "unknown",
}

local SCREEN_SET = {}
for _, v in pairs(M.SCREEN) do SCREEN_SET[v] = true end

-- --- the canonical form -------------------------------------------------------

-- Numbers render the same way every time, whatever produced them. %.6g rather
-- than tostring: tostring(150.0) is "150.0" on one build and "150" on another,
-- and a canonical string that depends on the build is not canonical.
local function num(v)
    if type(v) ~= "number" then return "?" end
    return ("%.6g"):format(v)
end

local function text(v)
    if type(v) ~= "string" or v == "" then return "?" end
    -- The separators this format uses. A character name containing one would
    -- otherwise shift every field after it.
    return (v:gsub("[;=,]", "_"))
end

-- FNV-1a, 64 bit. Lua 5.4 integers are 64 bit and wrap on overflow, which is
-- what this needs; the constants are written as hex literals for the same
-- reason - a decimal one that large would become a float.
local FNV_OFFSET <const> = 0xcbf29ce484222325
local FNV_PRIME  <const> = 0x00000100000001b3

function M.hash(s)
    if type(s) ~= "string" then return nil end
    local h = FNV_OFFSET
    for i = 1, #s do
        h = h ~ s:byte(i)
        h = h * FNV_PRIME
    end
    return ("fnv1a64:%016x"):format(h)
end

-- One line, fixed order, every field present. Fixed order rather than sorted
-- keys because the set of fields is closed and written out below: a field added
-- later has to be added here too, which is a decision somebody makes rather
-- than a silent change of identity for every existing row.
function M.canonical(ctx)
    if type(ctx) ~= "table" then return nil, "not a conditions record" end

    local parts = {}

    local pos = ctx.positions
    if type(pos) ~= "table" then return nil, "the conditions do not say whether positions were controlled" end
    if pos.controlled == true then
        parts[#parts + 1] = ("positions=controlled:p1=%s,p2=%s,tol=%s")
            :format(num(pos.p1_x), num(pos.p2_x), num(pos.tolerance))
    elseif pos.controlled == false then
        parts[#parts + 1] = "positions=uncontrolled"
    else
        return nil, "positions.controlled is neither true nor false"
    end

    local res = ctx.resources
    if type(res) ~= "table" then return nil, "the conditions do not say whether resources were pinned" end
    if res.pinned == true then
        parts[#parts + 1] = ("resources=pinned:ahp=%s,vhp=%s,drive=%s,super=%s")
            :format(num(res.attacker_hp), num(res.victim_hp),
                    num(res.attacker_drive), num(res.attacker_super))
    elseif res.pinned == false then
        parts[#parts + 1] = "resources=unpinned"
    else
        return nil, "resources.pinned is neither true nor false"
    end

    if not COUNTER_SET[ctx.counter_state] then
        return nil, ("counter_state %q is not one of normal, counter, punish, unknown")
            :format(tostring(ctx.counter_state))
    end
    parts[#parts + 1] = "counter=" .. ctx.counter_state

    if not SCREEN_SET[ctx.screen_position] then
        return nil, ("screen_position %q is not one of midscreen, corner, unknown")
            :format(tostring(ctx.screen_position))
    end
    parts[#parts + 1] = "screen=" .. ctx.screen_position

    local opp = ctx.opponent
    if type(opp) ~= "table" then return nil, "the conditions do not say who the opponent was" end
    parts[#parts + 1] = "opponent=" .. text(opp.character)

    return table.concat(parts, ";")
end

-- --- building one -------------------------------------------------------------

-- opts.stage    : the RESOLVED StageControl configuration - the one the trial
--                 actually ran with, not the defaults table. Required: whether
--                 the positions were controlled is a fact about the run, and
--                 there is no safe value to assume when nobody said.
-- opts.opponent : { character = "..." } when it is known
-- opts.counter_state / opts.screen_position : when somebody measured them
--
-- Returns the conditions record, or nil and a reason.
function M.of(opts)
    opts = opts or {}

    local stage = opts.stage
    if type(stage) ~= "table" then
        return nil, "no stage configuration - whether the positions were controlled "
            .. "and whether the gauges were pinned are facts about the run, and a "
            .. "default here would write an experiment nobody performed"
    end

    -- `false` is the shipped value and means "known: nothing is being
    -- controlled". nil means the config never said, which is a different thing
    -- and is refused rather than read as off.
    local targets = stage.target_positions
    local positions
    if targets == false then
        positions = { controlled = false,
                      reason = "target_positions is off, so the fighters started "
                            .. "wherever the reset left them" }
    elseif type(targets) == "table" then
        positions = { controlled = true,
                      p1_x = targets.p1 or targets[1],
                      p2_x = targets.p2 or targets[2],
                      tolerance = stage.position_tolerance }
    else
        return nil, ("stage.target_positions is %s; it has to be false or a table of "
            .. "target positions, because unknown is not the same as off")
            :format(tostring(targets))
    end

    local pin = stage.pin
    local resources
    if pin == false then
        resources = { pinned = false,
                      reason = "pin is off, so the gauges held whatever the reset left" }
    elseif type(pin) == "table" then
        resources = { pinned = true,
                      attacker_hp = pin.attacker_hp,
                      victim_hp = pin.victim_hp,
                      attacker_drive = pin.attacker_drive,
                      attacker_super = pin.attacker_super }
    else
        return nil, ("stage.pin is %s; it has to be false or a table of pinned values")
            :format(tostring(pin))
    end

    local counter = opts.counter_state or M.COUNTER.UNKNOWN
    if not COUNTER_SET[counter] then
        return nil, ("counter_state %q is not one of normal, counter, punish, unknown")
            :format(tostring(counter))
    end

    local screen = opts.screen_position or M.SCREEN.UNKNOWN
    if not SCREEN_SET[screen] then
        return nil, ("screen_position %q is not one of midscreen, corner, unknown")
            :format(tostring(screen))
    end

    local opponent = {}
    if type(opts.opponent) == "table" then
        opponent.character = opts.opponent.character
    end
    -- Spelled out rather than left to be inferred from a nil. A reader of the
    -- row should not have to know that absence means nobody looked.
    opponent.known = (type(opponent.character) == "string" and opponent.character ~= "")

    local ctx = {
        schema = M.SCHEMA,
        positions = positions,
        resources = resources,
        counter_state = counter,
        screen_position = screen,
        opponent = opponent,
    }

    local canon, why = M.canonical(ctx)
    if not canon then return nil, why end
    ctx.canonical = canon
    ctx.context_hash = M.hash(canon)
    return ctx
end

-- --- comparing ----------------------------------------------------------------

-- Two trials belong to the same cohort when their conditions are the same one.
--
-- Compares the canonical STRING, never the hash: a hash collision would merge
-- two cohorts, which is the exact mistake #38 asks this project not to make.
-- A record with no readable conditions does not match anything, including
-- another record with no readable conditions - unknown is not equal.
function M.same(a, b)
    local ca = (type(a) == "table") and (a.canonical or M.canonical(a)) or nil
    local cb = (type(b) == "table") and (b.canonical or M.canonical(b)) or nil
    if type(ca) ~= "string" or type(cb) ~= "string" then return false end
    return ca == cb
end

-- The cohort key for a record that may carry no conditions at all.
--
-- Records written before conditions existed have none. They get their own key -
-- "nobody recorded the conditions" - which keeps them out of every cohort that
-- does have them rather than quietly joining one.
M.UNRECORDED = "conditions=unrecorded"

function M.key(conditions)
    if type(conditions) ~= "table" then return M.UNRECORDED end
    local canon = conditions.canonical
    if type(canon) ~= "string" or canon == "" then
        canon = M.canonical(conditions)
    end
    if type(canon) ~= "string" or canon == "" then return M.UNRECORDED end
    return canon
end

return M
