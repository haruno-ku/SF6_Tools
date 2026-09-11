-- =========================================================
-- ComboExplorer/core/FrameData.lua - external frame data, indexed so a move in
-- the catalog can find its numbers. Pure: takes a decoded table.
-- =========================================================
--
-- WHAT THIS IS AND IS NOT FOR
--
-- Candidate generation only. A frame table saying A recovers before B starts is
-- a reason to try the pair on the real game, never evidence that it works.
-- Nothing here may promote a record past `theoretical`.
--
-- The data also has no idea Modern controls exist - a search of the Zangief
-- file for "modern", "simple" or "assist" finds nothing - so which moves are
-- reachable, and by which button, comes from command_display and only from
-- there. This module supplies startup, recovery and cancel properties for
-- moves that command_display has already decided are reachable.
--
-- THE JOIN IS THE HARD PART
--
-- command_display names a move by its classic display ("2+MP", "LP", "360+HP").
-- The frame source names it by numpad ("2MP", "5LP", "360+HP"). The two agree
-- often enough to be tempting and differ often enough to be dangerous: a bare
-- "LP" is "5LP" there, the "+" is dropped for normals but kept for motions, and
-- some entries carry a distance suffix ("63214KK (Close)").
--
-- So the lookup tries a list of candidate keys and RECORDS WHICH ONE MATCHED
-- and how. A silently fuzzy join would attach the wrong numbers to a move, and
-- wrong numbers are worse than none: no numbers produces an honest unknown,
-- while wrong ones produce a confident candidate that cannot work.
--
-- A move that finds nothing is not dropped. It gets no frame record, and the
-- candidate generator treats that as unknown rather than as "cannot link".

local M = { name = "ComboExplorer.FrameData" }

M.MATCH = {
    EXACT      = "exact",        -- the classic display is already the key
    NO_PLUS    = "no_plus",      -- "2+MP" -> "2MP"
    NEUTRAL_5  = "neutral_5",    -- "LP" -> "5LP"
    -- "214+LP" -> "214P". The source writes a special with a generic button
    -- letter when the strengths do NOT differ, and splits it into 214LP/214MP/
    -- 214HP when they do - Ryu's Hadoken is three records with startups 16, 14
    -- and 12. So this is a FALLBACK, tried only after the strength-specific
    -- spellings have failed: if the source drew the distinction, its own
    -- spelling wins, and if it did not, the three catalog rows genuinely share
    -- one move's numbers because the source says they are one move.
    GENERIC    = "generic_button",
    -- The other direction. "623+K" names no strength, and the source splits
    -- Dragonlash Kick into 623LK / 623MK / 623HK - so the catalog is the
    -- generic side and the source is the specific one. Always ambiguous when
    -- more than one strength exists, and says so.
    STRENGTH   = "generic_expanded",
    PREFIX     = "prefix",       -- "63214KK" -> "63214KK (Close)"
    -- "5MK~MK" - the move BEFORE it, then this one. The source spells a
    -- derivation as a chain from its parent and never on its own, so this key
    -- can only be built by a caller who knows what came first. See
    -- M.candidate_keys' `after`.
    DERIVATION = "derivation",
    NONE       = "none",
}

-- Candidate keys for one classic display, in order of confidence. Order
-- matters: an exact hit is never overridden by a fuzzier one.
--
-- opts.after : the classic display of the move this one comes out of, when the
-- caller knows it. Omitted, the result is byte-identical to what it always was.
function M.candidate_keys(classic, opts)
    if type(classic) ~= "string" or classic == "" then return {} end
    local keys = {}
    local seen = {}

    local function add(k, kind)
        if k == nil or k == "" or seen[k] then return end
        seen[k] = true
        keys[#keys + 1] = { key = k, match = kind }
    end

    add(classic, M.MATCH.EXACT)

    local no_plus = classic:gsub("%+", "")
    add(no_plus, M.MATCH.NO_PLUS)

    -- A display that starts with a button rather than a direction is the
    -- neutral version, which the frame source spells with a leading 5.
    local function needs_neutral(s)
        return s:match("^[LMH][PK]") ~= nil or s:match("^[PK][PK]") ~= nil
    end
    if needs_neutral(classic) then
        add("5" .. classic, M.MATCH.NEUTRAL_5)
        add("5" .. no_plus, M.MATCH.NEUTRAL_5)
    end

    -- Last, and only for a notation that names a motion: the generic-button
    -- form. Added after everything above so a strength-specific key in the
    -- source always wins; see M.MATCH.GENERIC.
    local generic, kind, n, motion = M.generic_button_key(classic)
    if generic then add(generic, M.MATCH.GENERIC) end

    -- One letter for a doubled button. The source does not always repeat it:
    -- Guile's Sonic Hurricane is "[4]646P" and C.Viper's Mission Complete is
    -- "214214P", while the catalog spells both with two buttons. Tried after
    -- the repeated form, so a source that DID draw the distinction keeps it.
    if generic and kind and n and n > 1 then
        add(motion .. kind, M.MATCH.GENERIC)
    end

    -- And the reverse: a catalog notation that names no strength at all, where
    -- the source split the move into three. Motion-gated exactly as
    -- generic_button_key is, and for the same reason - "6+P" must never expand
    -- to "6LP"/"6MP"/"6HP", because Guile's 6MP is a command normal and that
    -- would hand a normal's numbers to a special. A rekka spelled "6+P" is
    -- answered by reading it against its parent instead.
    local exp_motion, exp_kind = M.generic_expansion(classic)
    if exp_motion then
        for _, strength in ipairs({ "L", "M", "H" }) do
            add(exp_motion .. strength .. exp_kind, M.MATCH.STRENGTH)
        end
    end

    -- LAST, and the ordering is the whole safety of it.
    --
    -- The source spells a derivation as a chain from the move before it -
    -- "5MK~MK", "236LP~6P" - and never on its own. The catalog spells the same
    -- move either ">MK", which does not say what it follows, or as a bare
    -- "6+P" that is indistinguishable from a standalone move. Neither can be
    -- turned into the source's key by looking at one row.
    --
    -- The caller can, though. CandidateGenerator builds an edge (A -> B) and
    -- has A in hand; in that edge A IS B's parent, by construction. So "what
    -- are B's frames if it comes out of A" is answered by asking for A~B, and
    -- that is a reading rather than a guess.
    --
    -- These come after every key above so nothing that matches today stops
    -- matching: a row whose own spelling is in the source keeps its own record,
    -- and only a row that finds nothing at all can reach this far.
    --
    -- The child is looked up WITHOUT its ">" but never on its own - a bare
    -- "MK" key here would hand a standalone move's numbers to a derivation,
    -- which is the failure this module's header is about.
    local after = opts and opts.after
    if type(after) == "string" and after ~= "" then
        local child = classic:gsub("^%s*>%s*", "")
        for _, parent_key in ipairs(M.candidate_keys(after)) do
            for _, child_key in ipairs(M.candidate_keys(child)) do
                add(parent_key.key .. "~" .. child_key.key, M.MATCH.DERIVATION)
            end
        end
    end

    return keys
end

-- "214+LP" -> "214P", "214+LP+MP" -> "214PP", "236+LK+MK" -> "236KK".
--
-- Only for a notation whose buttons are ALL punches or ALL kicks: a mixed pair
-- has no generic spelling in the source, and inventing one would be a guess
-- rather than a reading. Returns nil when there is nothing to generalise.
function M.generic_button_key(classic)
    if type(classic) ~= "string" then return nil end
    local motion, buttons = classic:match("^([%d%[%]~]+)%+?([LMH%+PK]+)$")
    if not motion or not buttons then return nil end

    -- Only for a real motion. The source uses the generic letter for specials
    -- and never for normals - Ryu's normals are 5LP, 2MP, 5HK, every one of them
    -- strength-specific - so letting "2+MP" generalise to "2P" could only ever
    -- attach some special's numbers to a crouching medium punch. A motion is two
    -- or more directions, or a charge.
    local digits = select(2, motion:gsub("%d", ""))
    if digits < 2 and not motion:find("[", 1, true) then return nil end

    local kind, n = nil, 0
    for strength, btn in buttons:gmatch("([LMH])([PK])") do
        if strength == nil then return nil end
        if kind ~= nil and kind ~= btn then return nil end   -- mixed punch/kick
        kind = btn
        n = n + 1
    end
    if not kind or n == 0 then return nil end

    -- The buttons have to account for the whole tail, or something in it was
    -- not a strength+button pair and this is not the notation we think it is.
    if #buttons ~= (n * 2) + (n - 1) and #buttons ~= n * 2 then
        local plus = select(2, buttons:gsub("%+", ""))
        if #buttons ~= (n * 2) + plus then return nil end
    end

    return motion .. string.rep(kind, n), kind, n, motion
end

-- The mirror of generic_button_key: a notation whose buttons are ONE generic
-- letter, for a real motion. "623+K" -> "623", "K". Returns nil for anything
-- that names a strength, and nil for a single-digit motion.
--
-- The motion gate is not a formality. Without it "6+P" would expand to "6LP",
-- "6MP" and "6HP" - and Guile's "6MP" is Full Bullet Magnum, a command normal.
-- The rows spelled that way are rekka follow-ups; their answer is the chain
-- their parent names, not a strength guess.
function M.generic_expansion(classic)
    if type(classic) ~= "string" then return nil end
    local motion, button = classic:match("^([%d%[%]~]+)%+?([PK])$")
    if not motion or not button then return nil end
    local digits = select(2, motion:gsub("%d", ""))
    if digits < 2 and not motion:find("[", 1, true) then return nil end
    return motion, button
end

-- Every input one source record answers to.
--
-- The source writes alternatives with " or ": Dhalsim's record is "2KK or 3KK"
-- and Guile's is "4MK or 6MK", one move reachable two ways. The catalog has a
-- separate row for each, so indexing the literal string matched neither of
-- them - which is why Dhalsim joined 69% of his targets and Guile 83%.
--
-- This is not a guess about what the source meant. It is the source listing
-- both inputs itself.
-- The source writes two more alternations besides " or ", and both were being
-- indexed as literal strings nobody could generate:
--
--   "4/6MP"          -- 4MP or 6MP. Also "5/6KK", "5/6KK~6P", "5/6KK~dl.6P"
--   "214236HP/HK"    -- 214236HP or 214236HK. Also "214P~214LP/MP"
--
-- A "/" alternates one piece of the key and everything around it is shared.
-- Which piece is decided by what is on each side, and the two shapes above are
-- the only two in the data: digits on both sides of the slash, or buttons.
local function slash_parts(k)
    -- <head><d>/<d><tail> : a direction alternation. The digit before the slash
    -- is the alternative to the one after it, and the tail belongs to both.
    local head, a, b, tail = k:match("^(.-)(%d)/(%d)(.*)$")
    if head then return { head .. a .. tail, head .. b .. tail } end

    -- <head><buttons>/<buttons> : a button alternation, always at the end.
    -- The optional "j." is the air prefix, which the source keeps on both sides
    -- of the slash: "j.PPP/j.KKK".
    local h, x, y = k:match("^(.-)(j?%.?[LMH]?[PK]+)/(j?%.?[LMH]?[PK]+)$")
    if h then return { h .. x, h .. y } end

    return nil
end

-- Every input one source record answers to.
--
-- The source writes alternatives with " or ": Dhalsim's record is "2KK or 3KK"
-- and Guile's is "4MK or 6MK", one move reachable two ways. The catalog has a
-- separate row for each, so indexing the literal string matched neither of
-- them - which is why Dhalsim joined 69% of his targets and Guile 83%.
--
-- This is not a guess about what the source meant. It is the source listing
-- both inputs itself.
function M.spellings(numpad)
    if type(numpad) ~= "string" or numpad == "" then return {} end
    local out, seen = {}, {}
    local function add(k)
        k = k:match("^%s*(.-)%s*$")
        if k == "" or seen[k] then return end
        seen[k] = true
        out[#out + 1] = k
    end

    -- "4 or 6 + PPP/KKK" and "6 or 4 + PPP/KKK", plus their j. forms. Four keys
    -- in the whole dataset - Dhalsim's and M.Bison's teleports - and the only
    -- ones where an " or " part carries no buttons of its own.
    --
    -- Split on " or " alone, the first part is the bare string "4": not an
    -- input, and not something any catalog row can ask for. The buttons after
    -- the "+" belong to both directions, which is the only reading under which
    -- the record describes a move at all.
    local dirs, buttons = numpad:match("^%s*(%d[%s%w]-)%s*%+%s*(.+)$")
    if dirs and dirs:find(" or ", 1, true) and buttons:find("/", 1, true) then
        for d in (dirs .. " or "):gmatch("(.-) or ") do
            d = d:match("^%s*(.-)%s*$")
            for _, b in ipairs(slash_parts(buttons) or { buttons }) do
                -- The join is written without the "+" the prose put spaces
                -- around, because that is how the source spells every other
                -- key: "4PPP", not "4 + PPP". The "+" is NOT stripped from
                -- keys generally - "360+HP" keeps its own, and a catalog row
                -- spelled "360+HP" has to go on matching it exactly.
                if d ~= "" then add(d .. b) end
            end
        end
        return out
    end

    local parts = {}
    if numpad:find(" or ", 1, true) then
        for part in (numpad .. " or "):gmatch("(.-) or ") do parts[#parts + 1] = part end
    else
        parts[1] = numpad
    end

    for _, part in ipairs(parts) do
        part = part:match("^%s*(.-)%s*$")
        local alts = slash_parts(part)
        if alts then
            for _, a in ipairs(alts) do add(a) end
        else
            add(part)
        end
    end
    return out
end

-- decoded: { _meta = {...}, moves = { { numpad = "2MP", startup = 8, ... }, ... } }
--
-- Accepts the trimmed shape the fixture generator emits. A different source
-- gets its own adapter producing the same shape; nothing downstream knows
-- which source it came from beyond the provenance block.
function M.index(decoded)
    if type(decoded) ~= "table" or type(decoded.moves) ~= "table" then
        return nil, "not a frame-data table"
    end

    local idx = {
        meta = decoded._meta or {},
        by_key = {},
        keys = {},
        duplicates = {},
        duplicate_names = {},
    }

    for _, mv in ipairs(decoded.moves) do
        for _, k in ipairs(M.spellings(mv.numpad)) do
            if idx.by_key[k] then
                -- Real in this data, and worth naming rather than counting.
                -- Mai has 27 duplicated keys: every one is a move and its Flame
                -- Stock version sharing an input - "Kachousen" and "Kachousen
                -- (Flame)", 500 damage against 300. Which one comes out depends
                -- on a resource the frame table does not model, so the names are
                -- kept and reported: "listed twice" sends a reader digging,
                -- while "a base and an enhanced version" is the answer.
                idx.duplicates[k] = (idx.duplicates[k] or 1) + 1
                local names = idx.duplicate_names[k]
                if not names then
                    local first = idx.by_key[k]
                    names = { first.name_en or first.numpad }
                    idx.duplicate_names[k] = names
                end
                names[#names + 1] = mv.name_en or mv.numpad
            else
                idx.by_key[k] = mv
                idx.keys[#idx.keys + 1] = k
            end
        end
    end
    table.sort(idx.keys)
    return idx
end

-- Looks up one classic display. Returns record, match_info - where match_info
-- always exists and says what was tried, so an unmatched move is a documented
-- unknown rather than a silent gap.
function M.lookup(idx, classic, opts)
    local tried = {}
    if type(idx) ~= "table" or type(idx.by_key) ~= "table" then
        return nil, { matched = false, match = M.MATCH.NONE, tried = tried,
                      reason = "no frame-data index" }
    end

    local cands = M.candidate_keys(classic, opts)
    for _, cand in ipairs(cands) do
        tried[#tried + 1] = cand.key
        local hit = idx.by_key[cand.key]
        if hit then
            -- A key the source lists twice - "720+P" appears with damage 4800
            -- and 5300 - resolves to whichever row came first, which is a
            -- choice, not a fact. Reported here because index() recording it in
            -- idx.duplicates is no use to a caller that never looks: without
            -- this the losing row's numbers are simply gone and the winner is
            -- consumed as if the source agreed with itself.
            local dupes = idx.duplicates and idx.duplicates[cand.key]
            -- Recorded here rather than by the caller, because a record reached
            -- through a chain is only that move's record IN THAT CHAIN. An
            -- info table that carried the key but not the parent would let a
            -- reader take "5MP~MP" for a property of ">MP" itself.
            local after = nil
            if cand.match == M.MATCH.DERIVATION then after = opts and opts.after end

            -- An expanded strength is a choice between records the source drew
            -- a distinction between, and the catalog notation does not say
            -- which. Reported as ambiguous with every strength that exists, the
            -- same way a distance variant is - picking the first quietly would
            -- be exactly the confident wrong number this module is against.
            -- Set here rather than by the caller for the same reason `after`
            -- is: an info table carrying the key but not the contradiction lets
            -- a reader take the numbers for this row's own.
            local conflict = M.band_conflict(opts and opts.band, hit.category)

            local alternatives, ambiguous = nil, nil
            if cand.match == M.MATCH.STRENGTH then
                alternatives = {}
                for _, other in ipairs(cands) do
                    if other.match == M.MATCH.STRENGTH and idx.by_key[other.key] then
                        alternatives[#alternatives + 1] = other.key
                    end
                end
                ambiguous = #alternatives > 1
            end

            return hit, { matched = true, match = cand.match, key = cand.key, tried = tried,
                          after = after, band_conflict = conflict,
                          ambiguous = ambiguous, alternatives = alternatives,
                          duplicate = dupes and true or nil, duplicate_count = dupes,
                          duplicate_names = dupes and idx.duplicate_names
                              and idx.duplicate_names[cand.key] or nil }
        end
    end

    -- Last resort, and deliberately last: a key that begins with one of the
    -- candidates followed by a space and a bracket, which is how the source
    -- spells distance variants. Ambiguous by nature, so it says so.
    for _, cand in ipairs(M.candidate_keys(classic, opts)) do
        local matches = {}
        for _, k in ipairs(idx.keys) do
            if k:sub(1, #cand.key + 2) == cand.key .. " (" then
                matches[#matches + 1] = k
            end
        end
        if #matches > 0 then
            return idx.by_key[matches[1]], {
                matched = true, match = M.MATCH.PREFIX, key = matches[1],
                tried = tried, ambiguous = (#matches > 1), alternatives = matches,
            }
        end
    end

    return nil, { matched = false, match = M.MATCH.NONE, tried = tried,
                  reason = "no frame data for this notation" }
end

-- --- normalised access -------------------------------------------------------

-- The frame source records a value it does not have as null rather than
-- guessing, which is the behaviour this whole project is built around. These
-- helpers preserve that: nil out means unknown, and no caller may read it as a
-- number.
local function num(v)
    if type(v) == "number" then return v end
    if type(v) == "string" then return tonumber(v) end
    return nil
end

function M.startup(rec)  return rec and num(rec.startup) or nil end
function M.on_hit(rec)   return rec and num(rec.on_hit) or nil end
function M.on_block(rec) return rec and num(rec.on_block) or nil end
function M.damage(rec)   return rec and num(rec.damage) or nil end

-- Drive and super are recorded as GAIN in this source, and a negative gain is a
-- spend: the super arts carry `super_gain_on_hit = -10000`, which is the cost of
-- using them. There is no separate spend field, and the drive cost of an OD move
-- appears nowhere at all - so `drive_spend` deliberately does not exist here.
-- Route search counts OD steps instead of inventing a gauge figure for them.
function M.drive_gain(rec) return rec and num(rec.drive_gain) or nil end
function M.super_gain(rec) return rec and num(rec.super_gain_on_hit) or nil end

function M.can_cancel_into(rec, kind)
    if not rec or type(rec.cancel) ~= "table" then return nil end   -- unknown, not false
    for _, c in ipairs(rec.cancel) do
        if c == kind then return true end
    end
    return false
end

function M.has_property(rec, prop)
    if not rec or type(rec.properties) ~= "table" then return nil end
    for _, p in ipairs(rec.properties) do
        if p == prop then return true end
    end
    return false
end

-- Did the join have to guess? True when the key matched only by prefix over
-- several distance variants, or when the source lists the key more than once.
--
-- Both are the same failure from a consumer's point of view: the numbers that
-- came back are one of several readings, and using them as fact turns a coin
-- flip into a frame margin. A caller that ignores this gets a confident edge
-- built on an arbitrary choice.
-- `contested` joins the other two: all three mean the record is not known to
-- be this row's, for three different reasons.
function M.uncertain(info)
    if type(info) ~= "table" or not info.matched then return false end
    return (info.ambiguous == true) or (info.duplicate == true)
        or (info.band_conflict ~= nil)
end

-- Why the join was uncertain, in words, or nil when it was not.
function M.uncertainty_reason(info)
    if not M.uncertain(info) then return nil end
    if info.ambiguous then
        local alts = table.concat(info.alternatives or {}, ", ")
        -- Two different ambiguities reach here and they are not the same
        -- sentence. This used to say "distance variants" for both, which was
        -- the right words for the prefix match and the wrong ones for a
        -- strength expansion - a reader chasing "623LK, 623MK, 623HK" would be
        -- looking for a Close and a Far version that do not exist.
        if info.match == M.MATCH.STRENGTH then
            return ("the catalog names no strength and the frame source splits this move "
                .. "into %s; the join took %s, and which one the notation means is not "
                .. "in either source"):format(alts, tostring(info.key))
        end
        return ("the frame source spells this move as several distance variants (%s) and "
            .. "the join picked %s by sort order, not by knowing which one applies")
            :format(alts, tostring(info.key))
    end

    if info.band_conflict then
        return ("the join took %q, whose frame record describes a %s, but this row's "
            .. "action id puts it among the %s. The two sources disagree about what "
            .. "move this is, so the numbers may belong to a different one")
            :format(tostring(info.key), tostring(info.band_conflict.category),
                    tostring(info.band_conflict.band))
    end
    local names = info.duplicate_names
    if type(names) == "table" and #names > 0 then
        return ("the frame source lists %q %d times - %s - and the join took whichever "
            .. "came first; which one the input produces depends on something the frame "
            .. "table does not model"):format(
            tostring(info.key), info.duplicate_count or #names,
            table.concat(names, " / "))
    end
    return ("the frame source lists %q %d times with different values, and the join took "
        .. "whichever came first"):format(tostring(info.key), info.duplicate_count or 2)
end

-- What is missing from a record, named. Goes straight onto the candidate so a
-- reader can see which of its reasoning rested on data that was not there.
function M.missing(rec)
    local out = {}
    if not rec then
        out[#out + 1] = "no_frame_record"
        return out
    end
    if num(rec.startup) == nil then out[#out + 1] = "startup" end
    if num(rec.on_hit) == nil then out[#out + 1] = "on_hit" end
    if num(rec.damage) == nil then out[#out + 1] = "damage" end
    if type(rec.cancel) ~= "table" then out[#out + 1] = "cancel" end
    if rec.pushback == nil then out[#out + 1] = "pushback" end
    return out
end

-- Does the record the join found contradict where the catalog's own numbering
-- puts the move?
--
-- The case this exists for, measured on the shipped data. Guile's catalog has
-- three rows displaying "6+MP": 665, which is Full Bullet Magnum, and 941 and
-- 949, which sit in the Sonic Boom block between the "56+MP" rows. The source
-- has one "6MP" record - Full Bullet Magnum, startup 20, damage 800. All three
-- rows take it. Sonic Boom is startup 10 and damage 550.
--
-- That does not become `frame_data_incomplete`. A margin computes, the
-- confidence comes out high, and the edge enters route search looking better
-- founded than an edge with no numbers at all - which is the one failure this
-- module's header calls worse than none.
--
-- Two independent statements are available and they disagree. The frame record
-- says what KIND of move it describes (`category`), and the catalog's action id
-- says where in its own numbering the row sits (`action_id_band`). Neither is
-- derived from the other, and the band is given no vote in classification
-- precisely so it can serve as a check - it is the instrument that found the
-- 623 misclassification across 18 characters.
--
-- 96 matches across the 31 shipped characters disagree, 72 of them a special's
-- row holding a normal's numbers. This changes none of them. It makes them say
-- so, the same way a duplicated key or a distance variant already does.
--
-- A band with nothing to say about a category returns nil: "system_or_movement"
-- holds moves of every kind, and silence is not a contradiction.
local BAND_EXPECTS = {
    normals  = { normal = true },
    throws   = { throw = true },
    specials = { special = true, drive = true },
    supers   = { super_art = true, special = true },
}

function M.band_conflict(band, category)
    if type(band) ~= "string" or type(category) ~= "string" then return nil end
    local expected = BAND_EXPECTS[band]
    if not expected then return nil end
    if expected[category] then return nil end
    -- A taunt can be anywhere and is never a combo move; flagging it would be
    -- noise against a row nothing will ever probe.
    if category == "taunt" then return nil end
    return { band = band, category = category }
end

-- Coverage across a whole catalog, for the report. A join that quietly matched
-- a third of the moves would otherwise look like a thin edge graph rather than
-- a broken lookup.
--
-- opts.parents : rows this set's moves could come out of. Only derivations need
-- it, and they need it because "does this row join" is not a question about the
-- row: the source spells a derivation as a chain from its parent, so the honest
-- form is "does it join after ANY move this character has". Tried only after
-- the row's own spelling has failed, and the parent that answered is recorded -
-- a coverage figure that could not say which parent it used would be a number
-- nobody can check.
function M.coverage(idx, rows, opts)
    local parents = opts and opts.parents or nil
    local n = { rows = 0, matched = 0, exact = 0, fuzzy = 0, unmatched = 0, ambiguous = 0 }
    local unmatched = {}
    for _, row in ipairs(rows or {}) do
        n.rows = n.rows + 1
        -- The row's own band travels with the lookup, so a record that
        -- describes a different kind of move than the row's numbering implies
        -- comes back saying so.
        local rec, info = M.lookup(idx, row.classic, { band = row.action_id_band })
        if not rec and parents then
            for _, parent in ipairs(parents) do
                local prec, pinfo = M.lookup(idx, row.classic,
                    { after = parent.classic, band = row.action_id_band })
                if prec then
                    rec, info = prec, pinfo
                    -- `after` comes back from the lookup itself. Only the id is
                    -- added here, because the lookup takes a display string and
                    -- has no row to read an action id from.
                    info.after_action_id = parent.action_id
                    n.after_parent = (n.after_parent or 0) + 1
                    break
                end
            end
        end
        if rec then
            n.matched = n.matched + 1
            if info.match == M.MATCH.EXACT then n.exact = n.exact + 1 else n.fuzzy = n.fuzzy + 1 end
            if info.band_conflict then n.band_conflict = (n.band_conflict or 0) + 1 end
            if M.uncertain(info) then
                n.ambiguous = n.ambiguous + 1
                n.uncertain_detail = n.uncertain_detail or {}
                n.uncertain_detail[#n.uncertain_detail + 1] = {
                    action_id = row.action_id, classic = row.classic,
                    key = info.key, after = info.after, why = M.uncertainty_reason(info),
                }
            end
        else
            n.unmatched = n.unmatched + 1
            unmatched[#unmatched + 1] = { action_id = row.action_id, classic = row.classic,
                                          tried = info.tried }
        end
    end
    n.unmatched_detail = unmatched
    n.ratio = (n.rows > 0) and (n.matched / n.rows) or 0
    return n
end

return M
