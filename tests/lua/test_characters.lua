-- Unit tests for tools/lua/characters.lua and data/characters.json
--
-- The bridge exists because there is no transform. Every test here is really
-- one assertion said several ways: do not replace this table with a string
-- operation, because the string operation is wrong for three characters and
-- wrong silently - the frame data is absent, every candidate comes out low
-- confidence, and the report says "frame data: NONE" as though that were a
-- property of the character rather than a typo in a path.
--
-- Checked against the real shipped catalogs, not a fixture. A bridge that
-- agrees with a fixture and disagrees with the filesystem is the failure.

local t = require("tests.lua.harness")
local Characters = dofile("tools/lua/characters.lua")
local json = dofile("tools/lua/json.lua")

local CATALOG_DIR = "reframework/data/TrainingComboTrials_data/command_display"

-- --- the table itself --------------------------------------------------------

t.group("the bridge")

local all = Characters.all()
t.ok(all ~= nil, "data/characters.json loads")
t.eq(#all, 31, "all 31 shipped characters are bridged")

local ids, catalogs, senseis = {}, {}, {}
local dup_id, dup_catalog, dup_sensei = 0, 0, 0
for _, c in ipairs(all) do
    if ids[c.fighter_id] then dup_id = dup_id + 1 end
    if catalogs[c.catalog] then dup_catalog = dup_catalog + 1 end
    if senseis[c.sensei] then dup_sensei = dup_sensei + 1 end
    ids[c.fighter_id], catalogs[c.catalog], senseis[c.sensei] = true, true, true
end
t.eq(dup_id, 0, "fighter ids are unique")
t.eq(dup_catalog, 0, "catalog names are unique")
t.eq(dup_sensei, 0, "and so are the sensei slugs - this is a bijection or it is nothing")

local ordered = true
for i = 2, #all do
    if all[i - 1].fighter_id > all[i].fighter_id then ordered = false end
end
t.ok(ordered, "listed in fighter_id order, so two runs agree")

-- --- it matches the filesystem ----------------------------------------------

t.group("every bridged name is a real file")

-- The whole point is that the name is a filename. A bridge that names a file
-- nobody shipped is worse than no bridge, because it looks authoritative.
local missing, mismatched_meta = 0, 0
for _, c in ipairs(all) do
    local path = Characters.catalog_path(c)
    local raw = json.load_file(path)
    if not raw then
        missing = missing + 1
    else
        -- _meta.character is the in-band key. If it ever disagrees with the
        -- filename, one of the two is lying and the bridge cannot arbitrate.
        if raw._meta.character ~= c.catalog then mismatched_meta = mismatched_meta + 1 end
        if raw._meta.fighter_id ~= c.fighter_id then mismatched_meta = mismatched_meta + 1 end
    end
end
t.eq(missing, 0, "every catalog name in the bridge is a file that exists")
t.eq(mismatched_meta, 0, "and its _meta agrees with the bridge on name and fighter id")

-- --- the reason the table exists --------------------------------------------

t.group("no string operation can replace this")

-- If this ever passes with zero, somebody has replaced the table with
-- catalog:lower() and it is wrong for these three.
local not_derivable = {}
for _, c in ipairs(all) do
    if c.catalog:lower() ~= c.sensei then
        not_derivable[#not_derivable + 1] = c.catalog
    end
end
table.sort(not_derivable)
t.eq_list(not_derivable, { "DeeJay", "EHonda", "MBison" },
          "three characters are not reachable by lowercasing the catalog name")

-- And the reason a smarter rule does not save it either: the two conventions
-- disagree with each other about the same shape.
local by_catalog = {}
for _, c in ipairs(all) do by_catalog[c.catalog] = c end
t.eq(by_catalog.ChunLi.sensei, "chunli", "ChunLi loses the separator")
t.eq(by_catalog.DeeJay.sensei, "dee_jay", "DeeJay keeps it, in the same source")
t.eq(by_catalog.CViper.sensei, "cviper", "CViper loses it")
t.eq(by_catalog.EHonda.sensei, "e_honda", "E.Honda keeps it")

-- --- resolution --------------------------------------------------------------

t.group("resolve")

t.eq(Characters.resolve("Zangief").catalog, "Zangief", "the canonical name resolves")
t.eq(Characters.resolve("zangief").catalog, "Zangief", "so does any casing of it")
t.eq(Characters.resolve("ZANGIEF").catalog, "Zangief", "including shouting")
t.eq(Characters.resolve(6).catalog, "Zangief", "and the fighter id")
t.eq(Characters.resolve("6").catalog, "Zangief", "as a string too")

-- An unknown name is an error. Falling back to lowercasing is what makes the
-- failure silent, which is the thing this module exists to prevent.
local nope, why = Characters.resolve("ChunLee")
t.is_nil(nope, "a name nobody ships is refused")
t.ok(why:find("ChunLi") ~= nil, "and the message shows the spelling that works")
t.is_nil(Characters.resolve(nil), "nil is refused")
t.is_nil(Characters.resolve("chun-li"), "a plausible-but-wrong spelling is refused, not guessed")

-- --- paths -------------------------------------------------------------------

t.group("paths")

local dj = by_catalog.DeeJay
t.eq(Characters.catalog_path(dj),
     CATALOG_DIR .. "/DeeJay.json", "the catalog path uses the catalog name")
t.eq(Characters.frame_data_path(dj),
     "data/frame-data/deejay.lua",
     "the frame-data path is the catalog name lowercased, NOT the sensei slug")
t.eq(Characters.sensei_path(dj),
     "packages/data/src/generated/dee_jay.json", "and the sensei path is the slug")

-- Said explicitly because getting it backwards is invisible: the generator
-- would write dee_jay.lua and every reader would look for deejay.lua.
t.ok(Characters.frame_data_path(dj) ~= ("data/frame-data/" .. dj.sensei .. ".lua"),
     "the two would disagree if the frame file were named after the slug")

local pin = Characters.pin()
t.ok(pin ~= nil, "the bridge records what it was verified against")
t.ok(pin.sensei_commit ~= nil, "including the sensei commit, so a rename is detectable")

return t.finish()
