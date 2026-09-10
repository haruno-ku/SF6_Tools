-- =========================================================
-- tools/lua/characters.lua - reads data/characters.json, the bridge between the
-- three names every character has. Dev-machine only, like the rest of tools/.
-- =========================================================
--
-- WHY A LOOKUP AND NOT A TRANSFORM
--
-- There is no transform. sf6-sensei writes ChunLi as "chunli" and DeeJay as
-- "dee_jay" - removing the separator is right for one and wrong for the other -
-- so a plain lowercase of the catalog name asks for a file that does not exist
-- for 3 of the 31. It does not error in an interesting way either: the frame
-- data is simply absent, every candidate for that character comes out low
-- confidence, and the report says "frame data: NONE" as though that were a
-- property of the character rather than a typo in a path.
--
-- WHY IT REFUSES
--
-- An unknown name is an error, not a reason to fall back to lowercasing. The
-- fallback is what makes the failure silent, and this project has already spent
-- an evening on one silent name failure (a runtime lookup used an enum's
-- ToString, "ESF_006", as a filename).

local json = dofile("tools/lua/json.lua")

local M = { name = "tools.characters", PATH = "data/characters.json" }

local cache

local function load()
    if cache then return cache end
    local doc, err = json.load_file(M.PATH)
    if not doc or type(doc.characters) ~= "table" then
        return nil, ("could not read %s: %s"):format(M.PATH, tostring(err or "no characters"))
    end
    local by_catalog, by_lower, by_id, order = {}, {}, {}, {}
    for _, c in ipairs(doc.characters) do
        by_catalog[c.catalog] = c
        by_lower[tostring(c.catalog):lower()] = c
        by_id[c.fighter_id] = c
        order[#order + 1] = c
    end
    cache = { doc = doc, by_catalog = by_catalog, by_lower = by_lower,
              by_id = by_id, list = order }
    return cache
end

-- Accepts the catalog name in any case, or a fighter id. Returns the entry, or
-- nil plus a message naming what IS known - a caller that cannot spell a
-- character should be shown the spelling, not left to guess again.
function M.resolve(name)
    local db, err = load()
    if not db then return nil, err end
    if name == nil then return nil, "no character given" end

    local hit = db.by_catalog[name]
        or db.by_lower[tostring(name):lower()]
        or db.by_id[tonumber(name) or -1]
    if hit then return hit end

    local known = {}
    for _, c in ipairs(db.list) do known[#known + 1] = c.catalog end
    table.sort(known)
    return nil, ("%q is not in %s.\n  Known: %s"):format(
        tostring(name), M.PATH, table.concat(known, ", "))
end

-- Every character, in fighter_id order.
function M.all()
    local db, err = load()
    if not db then return nil, err end
    local out = {}
    for i, c in ipairs(db.list) do out[i] = c end
    table.sort(out, function(a, b) return a.fighter_id < b.fighter_id end)
    return out
end

-- The paths a character's data lives at. One place builds these, so the three
-- naming conventions cannot drift apart in three different callers.
function M.catalog_path(entry, dir)
    return ("%s/%s.json"):format(
        dir or "reframework/data/TrainingComboTrials_data/command_display", entry.catalog)
end

function M.frame_data_path(entry)
    -- Named for the catalog, lowercased - NOT for the sensei slug. Naming it
    -- after the slug would put DeeJay's numbers in dee_jay.lua while every
    -- reader looks for deejay.lua.
    return ("data/frame-data/%s.lua"):format(entry.catalog:lower())
end

function M.sensei_path(entry, dir)
    return ("%s/%s.json"):format(dir or "packages/data/src/generated", entry.sensei)
end

function M.pin()
    local db = load()
    return db and db.doc.verified_against or nil
end

return M
