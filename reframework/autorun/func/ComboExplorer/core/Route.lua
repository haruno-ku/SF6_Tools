-- =========================================================
-- ComboExplorer/core/Route.lua - a named route of N moves, written by hand.
-- =========================================================
--
-- WHY A FILE AND NOT A UI
--
-- The panel's TRIAL picks two moves out of the catalog by index, which is right
-- for what it is: a spot check with no typing. It cannot express three moves,
-- and inventing widgets for an arbitrary N is a lot of imgui for something that
-- is asked for by name.
--
-- What is asked for by name is #48: an operator says "アシスト強 > 3中 > 2必殺技
-- is a combo I know connects - run it". That is a ground truth, and a ground
-- truth has to be written down somewhere a human can read and a later run can
-- repeat. A file is that.
--
-- WHY IT MATTERS MORE THAN A CONVENIENCE
--
-- #12's first 202 rows found 8 links and every one of them was a Super Art,
-- because at gap 4 the second input lands inside the first move's animation -
-- a cancel window, not a link window (#46). Nothing in that run demonstrates
-- that the pipeline can see a LINK at all. A route a human knows connects is
-- the only thing that can, and if it comes back refused then every negative in
-- that file is "we could not measure it" rather than "these do not link".
--
-- WHAT THIS FILE REFUSES
--
-- Everything it cannot check is checked, because a hand-written file is exactly
-- where a typo lives and the cost of a wrong action id is a trial that runs,
-- looks fine, and answers about a different move. The action ids are matched
-- against the catalog the game actually loaded - not merely parsed - so a route
-- written for another character or another build is a refusal with a name in
-- it rather than a run.

local M = { name = "ComboExplorer.Route" }

M.SCHEMA = "ce.route.v1"

-- The gaps a route is run at, when it does not name its own.
--
-- NOT a single number. #46: one gap answers one question, and which gap a link
-- needs is the thing nobody here has measured - the frame data computed it per
-- pair and the worklist dropped it. Until that is carried, a ground truth run
-- has to ask "is there ANY gap at which this connects", and that is a list.
--
-- The range is the operator's, not a measurement: a light attack recovers in
-- roughly ten frames and a heavy in roughly twenty, so a link window lives
-- somewhere in between, and 2 covers the cancel case the sweep already sees.
M.DEFAULT_DELAYS = { 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 24, 28 }

local function is_list(v) return type(v) == "table" end

-- doc     : a decoded ce.route.v1
-- catalog : the catalog the game loaded, or nil to skip the identity checks
--
-- Returns a route usable as Injector's `route`, plus a report of what was
-- checked. Or nil plus a reason naming the first thing that was wrong.
function M.build(doc, catalog)
    if type(doc) ~= "table" then return nil, "not a route document" end
    if doc.schema ~= M.SCHEMA then
        return nil, ("not a route (schema %s, wanted %s)")
            :format(tostring(doc.schema), M.SCHEMA)
    end
    if not is_list(doc.steps) or #doc.steps < 2 then
        return nil, "a route needs at least two steps - one move is not a combo"
    end

    -- Checked against the catalog the GAME loaded, not against the name in the
    -- file. A route written for Zangief and run on Ryu would otherwise press
    -- Ryu's action ids and record them under Zangief's name.
    if catalog and type(doc.character) == "string"
        and type(catalog.character) == "string"
        and doc.character ~= catalog.character then
        return nil, ("this route is for %s and the game has %s loaded")
            :format(doc.character, catalog.character)
    end

    local steps, problems = {}, {}
    for i, s in ipairs(doc.steps) do
        local id = tonumber(s.action_id)
        if not id then
            return nil, ("step %d has no numeric action_id"):format(i)
        end
        local method = s.input_method
        if method ~= "manual" and method ~= "simple" and method ~= "assist" then
            return nil, ("step %d: input_method is %q, which is not manual, "
                .. "simple or assist"):format(i, tostring(method))
        end
        if type(s.notation) ~= "string" or s.notation == "" then
            return nil, ("step %d has no notation, and without one the route "
                .. "cannot be compiled into inputs"):format(i)
        end

        -- The catalog is asked whether this id exists and whether it is the
        -- move the file says it is. A mismatch is reported rather than
        -- corrected: the file is the operator's statement of intent, and
        -- silently pressing something else is the failure this whole module is
        -- written against.
        if catalog then
            local row = M.find(catalog, id)
            if not row then
                return nil, ("step %d: this catalog has no action id %d")
                    :format(i, id)
            end
            if row.notation ~= s.notation then
                problems[#problems + 1] = {
                    step = i, action_id = id,
                    reason = ("the file calls %d %q and the catalog calls it %q")
                        :format(id, s.notation, tostring(row.notation)),
                }
            end
        end

        steps[#steps + 1] = {
            index = i,
            action_id = id,
            input_method = method,
            notation = s.notation,
        }
    end

    local delays = doc.delays
    if delays ~= nil and not is_list(delays) then
        return nil, "delays is not a list"
    end

    return {
        id = tostring(doc.id or doc.name or "route"),
        character = doc.character,
        control_scheme = doc.control_scheme or "modern",
        steps = steps,
        -- What the file asked to be run at, if anything. The caller decides
        -- what to do with an absent one; this module does not default it,
        -- because a default gap is exactly the guess #46 is about.
        delays = delays,
        note = doc.note,
    }, { problems = problems, steps = #steps }
end

-- The catalog row for an action id, or nil. Kept here rather than reached for
-- through Catalog's own shape at three call sites.
function M.find(catalog, action_id)
    for _, g in pairs(catalog.groups or {}) do
        for _, id in ipairs(g.action_ids or {}) do
            if id == action_id then return g end
        end
    end
end

-- Every combination of gaps for a route with N-1 of them.
--
-- A three-move route has two gaps and they are not the same question: the gap
-- into a special is not the gap into a normal. Asking them together is what
-- "does this connect at all" means, and it is why this returns a grid rather
-- than one list walked in step.
--
-- Bounded, because the grid is exponential in the number of gaps and a route
-- with four moves would otherwise be a night on its own. The cap is reported,
-- not silently applied - a truncated grid that says nothing reads as a
-- completed search.
function M.delay_grid(n_gaps, delays, max)
    delays = delays or M.DEFAULT_DELAYS
    max = max or 400
    if type(n_gaps) ~= "number" or n_gaps < 1 then return {}, "no gaps" end

    local out = {}
    local truncated = false

    local function recurse(depth, acc)
        if truncated then return end
        if depth > n_gaps then
            if #out >= max then truncated = true return end
            local row = {}
            for i = 1, n_gaps do row[i] = acc[i] end
            out[#out + 1] = row
            return
        end
        for _, d in ipairs(delays) do
            acc[depth] = d
            recurse(depth + 1, acc)
            if truncated then return end
        end
    end
    recurse(1, {})

    local total = 1
    for _ = 1, n_gaps do total = total * #delays end
    if truncated then
        return out, ("%d combination(s) of %d were not tried - the grid is %d "
            .. "gaps of %d values and the cap is %d")
            :format(total - #out, total, n_gaps, #delays, max)
    end
    return out
end

return M
