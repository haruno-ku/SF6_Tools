-- =========================================================
-- ComboExplorer/core/PadWatch.lua - what the operator's pad actually sets.
-- =========================================================
--
-- WHY THIS EXISTS
--
-- modern_button_bits was derived the long way round: press a bit, see what
-- action comes out, look that action up in a SINGLE-BUTTON notation, take the
-- button's name from there. Everything about that is inference, and it fails in
-- both directions.
--
-- It fails on notations with two tokens. Measured on build 24176760: bit 0x40
-- was pressed alone and produced an action whose notation is "AUTO + 强" - two
-- tokens - so single_button_groups matched nothing and the bit was reported
-- unwitnessed. The press happened, the action was observed, and the MATCHING
-- RULE threw the evidence away.
--
-- It also fails on the assist rows in the other direction. The catalog says
-- 660 is raw_button_mask 64 with required_button_count 1, which reads as "one
-- button" - while the operator says the assist button on their pad is L3, which
-- would make "AUTO + 强" two of them. Those cannot both be descriptions of the
-- same input in the same bit space, and nothing here can tell which space the
-- catalog's `norm_identity` masks are in.
--
-- So stop inferring. The operator has a pad. Ask them to press the button and
-- READ THE MASK - in the same field this suite writes to, which is the only
-- space that matters for injection. A button's bit measured this way needs no
-- catalog, no notation, and no profile.
--
-- WHY IT KEEPS MASKS AND NOT BITS
--
-- A bit-union answers "was 0x40 ever set" and nothing else: hold two buttons
-- and both bits go into the union with no record that they arrived together.
-- What the operator is asked to do is press ONE thing, so the useful record is
-- the distinct mask VALUES seen and how long each was held. A mask with two
-- bits in it is then visible as what it is - two buttons - rather than
-- dissolving into the same evidence as two separate presses.
--
-- The action id that followed is kept beside it because that is what makes a
-- mask nameable against the catalog afterwards. It is kept as EVIDENCE, not as
-- a derivation: this module names nothing.

local M = { name = "ComboExplorer.PadWatch" }

-- The button half of the field. Directions change constantly while the
-- operator holds the stick and would make every press a new mask value.
M.BTN_BITS = 0xFFF0

-- A mask seen for fewer ticks than this is not offered as evidence.
--
-- Not a filter on what is recorded - everything is recorded - but on what the
-- panel leads with. A pad passes through transient combinations on the way
-- into and out of a press, and those are real masks that nobody pressed on
-- purpose.
M.SETTLED_TICKS = 3

function M.new()
    return { masks = {}, order = {}, ticks = 0, current = nil, current_ticks = 0,
             idle = {} }
end

-- The action id of a character with no button held, by how often it was seen.
--
-- Measured rather than assumed, for the same reason the calibration sweep
-- measures it: which id "standing still" is, is a fact about the build and the
-- state, and it came back 1 on one run and 2 on another.
local function idle_id(w)
    local top, top_n = nil, 0
    for id, n in pairs(w.idle) do
        if n > top_n then top, top_n = id, n end
    end
    return top
end
M.idle_id = idle_id

-- mask      : pl_input_new as read this tick, or nil for "could not be read"
-- action_id : the action id this tick, or nil
--
-- nil mask is counted separately rather than treated as zero: "the pad was not
-- readable" and "nothing was pressed" are different facts, and this module is
-- the one place that would quietly turn the first into the second.
function M.observe(w, mask, action_id)
    if type(w) ~= "table" then return end
    w.ticks = w.ticks + 1
    -- w.prev_action is LAST tick's action and stays that way until advance()
    -- at the bottom. The question a press asks is "was the character idle when
    -- I pressed", and that is last tick's answer, not this one's.
    w.idle_known = idle_id(w)
    local function advance()
        if type(action_id) == "number" then w.prev_action = action_id end
    end

    if type(mask) ~= "number" then
        w.unreadable = (w.unreadable or 0) + 1
        advance()
        return
    end

    local btn = mask & M.BTN_BITS
    if btn == 0 then
        -- No button held: whatever the character reads as now is what idle
        -- looks like, and that is the only way to know which id to discount.
        if type(action_id) == "number" then
            w.idle[action_id] = (w.idle[action_id] or 0) + 1
        end
        w.current = nil
        w.current_ticks = 0
        advance()
        return
    end

    local e = w.masks[btn]
    if not e then
        e = { mask = btn, ticks = 0, presses = 0, action_ids = {}, first_tick = w.ticks }
        w.masks[btn] = e
        w.order[#w.order + 1] = btn
    end
    e.ticks = e.ticks + 1

    -- A press, not a tick: holding a button for a second is one thing the
    -- operator did, and counting ticks as presses would make a long hold look
    -- like strong evidence when it is one data point.
    if w.current ~= btn then
        e.presses = e.presses + 1
        w.current_ticks = 0
        -- ARMED only if the character was standing still when this press
        -- began.
        --
        -- Measured on build 24176760, and it shifted a whole column by one row:
        -- the operator pressed 弱, then 中 before 弱's move had finished, and
        -- the first non-idle id seen during the 中 press was 弱's move still
        -- playing. 0x0080 reported 611 and 0x0100 reported 604 - each mask
        -- wearing the action of the button pressed before it. Every one of
        -- those readings is a bit attributed to the wrong button.
        e.armed = (w.idle_known == nil) or (w.prev_action == w.idle_known)
    end
    w.current = btn
    w.current_ticks = w.current_ticks + 1

    if type(action_id) == "number" then
        e.action_ids[action_id] = (e.action_ids[action_id] or 0) + 1
        -- The FIRST id that is not idle, kept in order of arrival.
        --
        -- The most-seen id is the wrong answer for a held button and it was
        -- measured being wrong: 0x0010 held for 134 ticks reported action 1,
        -- because the move it produced lasts a dozen frames and the idle the
        -- character returns to fills the rest. A held button is mostly a
        -- character standing still.
        --
        -- Same rule the calibration FSM uses - "the action it produced" is the
        -- first non-idle id in the window - so the two cannot disagree about
        -- what a press produced.
        local idle = idle_id(w)
        if e.first_non_idle == nil and e.armed then
            if idle == nil or action_id ~= idle then
                e.first_non_idle = action_id
                e.from_idle = true
            end
        elseif e.first_non_idle == nil and e.dirty_action == nil then
            -- Kept separately so the panel can say the row exists and is not
            -- usable, rather than the row vanishing and the operator wondering
            -- whether the press registered at all.
            if idle == nil or action_id ~= idle then e.dirty_action = action_id end
        end
    end
    advance()
end

local function bit_list(mask)
    local out = {}
    local bit = 1
    while bit <= 0x8000 do
        if (mask & bit) ~= 0 then out[#out + 1] = bit end
        bit = bit << 1
    end
    return out
end

-- Ordered by first appearance, not by value: the operator pressed them in an
-- order and a list that matches it is readable against what they did.
function M.report(w)
    if type(w) ~= "table" then return nil end
    local rows = {}
    for _, m in ipairs(w.order) do
        local e = w.masks[m]
        local ids, top, top_n = {}, nil, 0
        for id, n in pairs(e.action_ids) do
            ids[#ids + 1] = { action_id = id, ticks = n }
            if n > top_n then top, top_n = id, n end
        end
        table.sort(ids, function(a, b)
            if a.ticks ~= b.ticks then return a.ticks > b.ticks end
            return a.action_id < b.action_id
        end)
        rows[#rows + 1] = {
            mask = m,
            bits = bit_list(m),
            -- Single-bit masks are the ones that name a button. A two-bit mask
            -- is evidence about a COMBINATION and must not be read as either
            -- of its bits.
            single_bit = (#bit_list(m) == 1),
            ticks = e.ticks,
            presses = e.presses,
            settled = e.ticks >= M.SETTLED_TICKS,
            action_ids = ids,
            top_action_id = top,
            first_non_idle = e.first_non_idle,
            -- Whether ANY press of this mask began from a standing character.
            -- A row without it is evidence about whatever was already playing.
            from_idle = e.from_idle or false,
            dirty_action = e.dirty_action,
            -- What "this mask produced". Prefers the first non-idle id seen on
            -- a press that started from idle; see observe().
            action_id = e.first_non_idle or top,
        }
    end
    return {
        rows = rows,
        idle_action_id = idle_id(w),
        ticks = w.ticks,
        unreadable = w.unreadable or 0,
        current = w.current,
    }
end

-- The single-bit masks, which are the ones that answer "which bit is this
-- button". Returned separately because it is the question being asked, and
-- burying it in a list the operator has to filter by eye is how a measurement
-- gets misread.
function M.single_bits(w)
    local rep = M.report(w)
    if not rep then return {} end
    local out = {}
    for _, r in ipairs(rep.rows) do
        if r.single_bit and r.settled then out[#out + 1] = r end
    end
    return out
end

return M
