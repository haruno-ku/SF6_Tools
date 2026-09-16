-- =========================================================
-- tools/lua/publish.lua - the dry run of the publication chain. Folds the
-- committed logs with the lab policy, builds ce.verified_combo.v1 records from
-- the reproduced subjects, offers them to KnowledgeDb.export, and writes down
-- exactly what was refused and why.
--
--   lua tools/lua/publish.lua [--character Zangief] [--scheme modern]
--       [--policy ce-eval-v1] [--slugs <path.json>]
--       [--out docs/ComboExplorer/publish-<char>-<scheme>.md]
--       [--patch <id>] [--calibration <id>] [--game-version <code>]
--       [--slug-table <path.json>] [--no-slug-table] [--data <dir>]
--
-- Run from the repo root. Needs Lua 5.4; no game, no network, no database.
-- =========================================================
--
-- WHY A TOOL WHOSE ANSWER IS "NOTHING"
--
-- On today's logs this exports zero combos, and that is the reason it exists.
-- The chain from a trial to a page on sf6-knowledge-db (#51) had two unbuilt
-- links: nothing produced ce.verified_combo.v1 and nothing called
-- KnowledgeDb.export. With both built, the export's REFUSAL LIST is the work
-- list - it names, in one pass, every measurement that has to be taken and
-- every move that has to be registered before a single row can cross. That is
-- worth more than a partial export would be, and it is the only output this
-- repository can honestly produce before somebody runs the game again.
--
-- WHAT IT WILL NOT DO
--
-- It will not write a combo it cannot support. `evidence.damage` arrived in
-- 6d67e7c, after every committed trial, so every reproduced subject today is
-- refused for the measurement - and a zero, a predicted damage, or a "to be
-- confirmed" row would each be a lie that looks like data. The report says 0
-- publishable and means it.
--
-- TWO READINGS OF THE SLUG GAP, AND WHY BOTH ARE PRINTED
--
-- KnowledgeDb.combo checks the measurement BEFORE it looks at the steps, so
-- while the damage is missing its own `missing_moves` list is empty - the gate
-- never reaches the question. The slug table (#17) has to be built anyway, and
-- waiting for the measurement to find out which moves it needs would waste the
-- session. So the report carries two lists: the export's own missing_moves, and
-- the same question asked here of the routes that WOULD be published, using
-- KnowledgeDb's own is_slug rather than a second idea of what a slug is. When
-- the measurement lands the two become the same list, and the report says so.
--
-- LICENCE
--
-- The report names action ids, notations and measured counts. Every one of them
-- was measured on the game or read from command_display; none is computed from
-- the frame data, so this document carries no CC-BY-SA obligation - the split
-- confirm.lua's licence_note states. The slug table is a different matter and
-- says so in its own header: it carries the frame source's English move names
-- so a human can recognise what they are mapping, which makes THAT file a
-- derived work, and it ships the attribution block.

local Cli        = dofile("tools/lua/cli.lua")
local json       = dofile("tools/lua/json.lua")
local Characters = dofile("tools/lua/characters.lua")
local Pipeline   = dofile("tools/lua/pipeline.lua")
local LabKnown   = dofile("tools/lua/labknown.lua")
local LabRows    = dofile("tools/lua/labrows.lua")
local LabEval    = dofile("tools/lua/labeval.lua")
local VC         = dofile("tools/lua/verifiedcombo.lua")
local KDB        = require("func/ComboExplorer/core/KnowledgeDb")
local FrameData  = require("func/ComboExplorer/core/FrameData")
local Exporter   = require("func/ComboExplorer/core/Exporter")

local TOOL = "publish"

-- The version code combos.yaml carries has to name a row in the target's
-- game_versions.yaml, and this repository has no copy of that file. Rather than
-- refuse to judge a single record for want of it - which would collapse the
-- whole report into one line about a field nobody has supplied yet - the dry
-- run uses this stand-in and says so everywhere it appears. It is not a code,
-- it does not look like one, and it never reaches anything that is published.
local STANDIN_VERSION = "dry-run-no-version-code"

local opt = Cli.args(TOOL, arg, {
    character = "Zangief",
    scheme = "modern",
    policy = LabEval.DEFAULT_POLICY,
    data = Pipeline.DATA_DIR,
})

local entry, cerr = Characters.resolve(opt.character)
if not entry then Cli.die(TOOL, cerr) end
local char_lc = entry.catalog:lower()

local out_path = opt.out or ("docs/ComboExplorer/publish-%s-%s.md"):format(char_lc, opt.scheme)
local slug_table_path = opt.slug_table
    or ("%s/slugs/%s-%s.json"):format(opt.data, char_lc, opt.scheme)

-- --- the catalog, the logs and the evaluations -------------------------------

local ctx, lerr = Pipeline.load({ character = entry.catalog, scheme = opt.scheme })
if not ctx then Cli.die(TOOL, tostring(lerr)) end
local gen, gerr = Pipeline.generate(ctx, { drive_rush = false })
if not gen then Cli.die(TOOL, tostring(gerr)) end

local notation_of = {}
for _, row in ipairs(ctx.cat.rows) do
    notation_of[("%s:%s"):format(row.action_id, row.input_method)] = row.notation
end
local classic_by_id = Pipeline.classic_by_id(ctx.raw)

local routes = Pipeline.load_route_defs(opt.data, Cli.list_dir)
local files = LabKnown.load_trials(opt.data, char_lc, Cli.list_dir)
local lookup = LabKnown.lookup(entry.catalog, opt.scheme,
    LabRows.pair_index(ctx.plain_edges, gen.excluded, Pipeline.edge_pair_key),
    notation_of, routes)

local evaluations, problems, policy, fold_counts = LabKnown.from_files(files, lookup, {
    policy = opt.policy,
    keep = function(rec)
        return rec.control_scheme == nil or rec.control_scheme == opt.scheme
    end,
})
if not evaluations then
    Cli.die(TOOL, ("the logs could not be evaluated: %s")
        :format(table.concat(problems or {}, "; ")))
end

-- --- which cohort is being exported for --------------------------------------

-- One export is for one patch and one calibration: a record measured under
-- another is not evidence about this one, and KnowledgeDb's gate says so. The
-- cohort is chosen from the REPRODUCED subjects, because those are the only
-- ones that could ever cross, and the report names the runners-up.
local function pick_cohort()
    local tally, order = {}, {}
    for _, ev in ipairs(evaluations) do
        if ev.result == LabEval.RESULT.REPRODUCED and ev.game_patch and ev.calibration_id then
            local key = ("%s\n%s"):format(ev.game_patch, ev.calibration_id)
            local t = tally[key]
            if not t then
                t = { game_patch = ev.game_patch, calibration_id = ev.calibration_id, n = 0 }
                tally[key] = t
                order[#order + 1] = t
            end
            t.n = t.n + 1
        end
    end
    table.sort(order, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return tostring(a.calibration_id) < tostring(b.calibration_id)
    end)
    return order
end

local cohorts = pick_cohort()
local chosen = cohorts[1]
local game_patch = opt.patch or (chosen and chosen.game_patch)
local calibration_id = opt.calibration or (chosen and chosen.calibration_id)

-- --- the records --------------------------------------------------------------

local records, refused, vc_counts = VC.build(evaluations, {
    character = entry.catalog,
    classic_of = function(id) return classic_by_id[id] or classic_by_id[tostring(id)] end,
    explorer_version = ctx.provenance.explorer_version,
})

-- A record this repository built that its own schema refuses is a defect, not a
-- finding. It is reported and the run fails; it is never published around.
local bugs = {}
for _, r in ipairs(refused) do
    if r.bug then bugs[#bugs + 1] = r end
end

-- --- the slug table ------------------------------------------------------------

-- Accepts the table this tool writes (`moves`, one entry per action id, `slug`
-- null until a human fills it) and a flat { "<action id>": "<slug>" } map, so a
-- mapping kept somewhere else can be pointed at with --slugs without reshaping.
local function read_slugs(path)
    if path == nil then return {}, 0, nil end
    local doc, err = json.load_file(path)
    if not doc then return {}, 0, ("could not read %s: %s"):format(path, tostring(err)) end
    local out, n = {}, 0
    local src = (type(doc.moves) == "table") and doc.moves or doc
    for id, v in pairs(src) do
        local slug = (type(v) == "table") and v.slug or v
        if type(slug) == "string" and KDB.is_slug(slug) then
            out[tonumber(id) or id] = slug
            out[tostring(id)] = slug
            n = n + 1
        end
    end
    return out, n, nil
end

local action_slugs, slugs_filled, slug_error = read_slugs(opt.slugs)
if slug_error then Cli.die(TOOL, slug_error) end

-- --- the dry run ----------------------------------------------------------------

local export_opts = {
    character = char_lc,
    game_patch = game_patch,
    calibration_id = calibration_id,
    game_version = opt.game_version or STANDIN_VERSION,
    action_slugs = action_slugs,
    routes = routes,
    move_names = notation_of,
}

local result, context_problem = KDB.export(records, export_opts)

-- --- the slug gap the gate cannot reach yet ---------------------------------------

-- The same question KnowledgeDb.combo asks of a record's steps, asked of the
-- subjects that WOULD be published, because the gate refuses them earlier for
-- the missing measurement and never gets there. KDB.is_slug and
-- KDB.display_name do the judging, so this cannot drift from the real check.
local function pending_slug_gap()
    local want, order = {}, {}
    local subjects = 0
    for _, ev in ipairs(evaluations) do
        if ev.result == LabEval.RESULT.REPRODUCED
            and ev.game_patch == game_patch and ev.calibration_id == calibration_id
            and type(ev.combo) == "table" then
            subjects = subjects + 1
            for _, s in ipairs(ev.combo.steps or {}) do
                local slug = action_slugs[s.action_id] or action_slugs[tostring(s.action_id)]
                if type(slug) ~= "string" or not KDB.is_slug(slug) then
                    local e = want[s.action_id]
                    if not e then
                        e = { action_id = s.action_id, input_method = s.input_method,
                              notation = s.notation,
                              classic = classic_by_id[s.action_id],
                              display = KDB.display_name(s.notation),
                              wanted_by = {} }
                        want[s.action_id] = e
                        order[#order + 1] = e
                    end
                    e.wanted_by[#e.wanted_by + 1] = ev.subject_id
                end
            end
        end
    end
    table.sort(order, function(a, b)
        if #a.wanted_by ~= #b.wanted_by then return #a.wanted_by > #b.wanted_by end
        return tostring(a.action_id) < tostring(b.action_id)
    end)
    return order, subjects
end

local slug_gap, cohort_subjects = pending_slug_gap()

-- --- the slug table file ----------------------------------------------------------

-- Written EMPTY: every entry's slug is null and its source is "unfilled". The
-- action id, the notation the trial pressed and the frame source's English name
-- are there so that a human can recognise the move; inventing the slug itself
-- would be inventing the one thing the target checks.
--
-- An existing file is merged, never overwritten: a slug somebody filled in by
-- hand is the only thing in this chain that cannot be regenerated.
local function write_slug_table(path, gap)
    local existing = json.load_file(path)
    local prior = (type(existing) == "table" and type(existing.moves) == "table")
        and existing.moves or {}

    local moves = {}
    local kept, added = 0, 0
    for id, v in pairs(prior) do
        moves[tostring(id)] = v
        kept = kept + 1
    end
    for _, e in ipairs(gap) do
        local key = tostring(e.action_id)
        -- The English name is a hint for the human filling the row in, not a
        -- fact about the action id, so HOW it was matched travels with it. A
        -- name reached through a prefix or a strength expansion is one reading
        -- of several, and a reader who cannot see that would take it for the
        -- move's name.
        local name, matched_by, ambiguous = nil, nil, nil
        if ctx.idx and e.classic then
            local rec, info = FrameData.lookup(ctx.idx, e.classic)
            if rec then
                name = rec.name_en
                matched_by = info.match
                ambiguous = info.ambiguous or nil
            end
        end
        local was = moves[key]
        if type(was) == "table" then
            -- Keep the human column; refresh only what this tool knows.
            was.notation = e.notation
            was.classic = e.classic
            was.name_en = name or was.name_en
            was.name_en_matched_by = matched_by or was.name_en_matched_by
            was.name_en_ambiguous = ambiguous
            was.blocks = #e.wanted_by
            was.input_method = e.input_method
        else
            added = added + 1
            moves[key] = {
                -- An explicit null, not an absent key: the column has to be
                -- visible to whoever fills it in.
                slug = json.NULL,
                source = "unfilled",
                action_id = e.action_id,
                input_method = e.input_method,
                notation = e.notation,
                classic = e.classic,
                name_en = name,
                name_en_matched_by = matched_by,
                name_en_ambiguous = ambiguous,
                blocks = #e.wanted_by,
            }
        end
    end

    -- A null decodes to an absent key, so an unfilled column read back from an
    -- existing file has to be written out as a null again or it would quietly
    -- disappear from the form a human is filling in.
    for _, e in pairs(moves) do
        if type(e) == "table" and e.slug == nil then e.slug = json.NULL end
    end

    -- The English names come from data/frame-data/<char>.lua, which is
    -- CC-BY-SA-4.0 (docs/NOTICE.md), so this file is a derived work and carries
    -- the attribution the licence requires. The attribution block is built by
    -- the one builder every derived document in this repository uses, with the
    -- two sentences about what THIS document took from the source replaced.
    local attribution = Exporter.attribution_for(ctx.provenance.frame_data)
    if attribution then
        attribution.applies_to = "the name_en column, and nothing else in this file"
        attribution.modifications = "One English move name per action id, joined "
            .. "through the command_display classic command. No source value was altered."
    end

    local doc = {
        schema = "ce.action_slugs.v1",
        character = entry.catalog,
        control_scheme = opt.scheme,
        generated_by = "tools/lua/publish.lua",
        generated_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        note = "action_id -> the move's slug in sf6-knowledge-db's "
            .. "data/characters/<slug>/moves.yaml. THIS TOOL NEVER FILLS THE SLUG "
            .. "COLUMN: a slug is a name in the other project and guessing one "
            .. "would put a dangling reference through validate.ts. Fill `slug` by "
            .. "hand and set `source` to how it was decided (\"hand\", \"matched by "
            .. "name\", \"from moves.yaml\"). What filling it enables: "
            .. "KnowledgeDb.export can then name every step of a combo, which is "
            .. "the last thing standing between a measured combo and a row in "
            .. "combos.yaml - the other is the measured damage, which only a "
            .. "session on the game can supply. An entry left unfilled is not a "
            .. "failure; it is the export's missing_moves list, written down. "
            .. "`blocks` is how many reproduced combos this move currently holds up. "
            .. "`name_en` is the frame source's English name, reached through the "
            .. "classic command, and `name_en_matched_by` says how - a prefix or "
            .. "strength match is one reading of several and `name_en_ambiguous` "
            .. "says when there were several. It is a hint for the person filling "
            .. "the row in, never the answer.",
        moves = moves,
        attribution = attribution,
    }

    Cli.mkdir((path:gsub("/[^/]+$", "")))
    local n, werr = json.save_file(path, doc, { indent = "  " })
    if not n then return nil, werr end
    return { kept = kept, added = added, total = added + kept }
end

local slug_written, slug_write_error
if opt.slug_table ~= false and #slug_gap > 0 then
    slug_written, slug_write_error = write_slug_table(slug_table_path, slug_gap)
end

-- --- the report --------------------------------------------------------------------

local rep = Cli.report()
local function say(fmt, ...) return rep:say(fmt, ...) end

local function sorted_pairs(t)
    local keys = {}
    for k in pairs(t or {}) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

say("# Publishing %s / %s - the dry run", entry.catalog, opt.scheme)
say("")
say("Generated %s by `tools/lua/publish.lua`.", os.date("!%Y-%m-%dT%H:%M:%SZ"))
say("")
say("This is the last link of the chain in #51 run end to end with nothing")
say("invented: the committed trials are folded by policy `%s`, every", policy.key)
say("subject the policy calls `reproduced` is offered as a `ce.verified_combo.v1`,")
say("and `KnowledgeDb.export` is asked to take it. **Nothing below is published.**")
say("The value of the document is the refusal list: it is the work list.")
say("")

-- --- what it ran on ---
say("## What this ran on")
say("")
say("| | |")
say("|---|---|")
say("| character | %s (`%s`) |", entry.catalog, char_lc)
say("| control scheme | %s |", opt.scheme)
say("| policy | `%s` v%s |", policy.key, tostring(policy.version))
say("| trial files | %d |", #files)
say("| lines / distinct observations | %d / %d |", fold_counts.lines, fold_counts.rows)
say("| evaluations | %d |", #evaluations)
say("| exporting for patch | `%s` |", tostring(game_patch))
say("| exporting for calibration | `%s` |", tostring(calibration_id))
say("| slug table given | %s |", opt.slugs and ("`" .. tostring(opt.slugs) .. "` (" .. slugs_filled .. " filled)")
    or "none - the mapping is empty")
say("| game_version code | %s |", opt.game_version and ("`" .. tostring(opt.game_version) .. "`")
    or ("`" .. STANDIN_VERSION .. "` - **a stand-in**"))
say("")
if not opt.game_version then
    say("`combos.yaml` carries a version code that has to name a row in the target's")
    say("`game_versions.yaml`, and this repository has no copy of that file. The dry run")
    say("used a stand-in so that every record could still be judged one by one; it")
    say("appears nowhere except the line above. Pass `--game-version` with the real code")
    say("before anything is written for real.")
    say("")
end
if #cohorts > 1 then
    say("The logs hold %d cohorts with a reproduced subject in them. The export is for", #cohorts)
    say("the one with the most, and records from the others are refused by the gate with")
    say("`game_patch_mismatch` or `calibration_id_mismatch` - which is correct: they are")
    say("measurements of a different build.")
    say("")
    for _, c in ipairs(cohorts) do
        say("- `%s` / `%s`: %d reproduced%s", tostring(c.game_patch), tostring(c.calibration_id),
            c.n, (c == chosen) and " **(exporting for this one)**" or "")
    end
    say("")
end

-- --- the headline ---
local exported = result and result.counts.exported or 0
say("## Publishable now: %d", exported)
say("")
if exported == 0 then
    say("Nothing crosses. Every reason is below, and each one names what would clear it.")
else
    say("%d combo(s) would be written to `data/characters/%s/combos.yaml`.", exported, char_lc)
end
say("")

-- --- what the policy found ---
say("## What the logs say, before anything is published")
say("")
say("| result | evaluations | what it means |")
say("|---|---:|---|")
local MEANING = {
    reproduced = "the policy's bar: a pair stable at one delay, or a route linked twice",
    observed_success = "linked, but never twice at one delay - one coin toss",
    mixed = "linked at some delays and not others; that is the window",
    no_success_observed = "only conclusive failures, over the delays that were tried",
    pending = "no counted run answered either way",
}
for _, r in ipairs(sorted_pairs(vc_counts.by_result)) do
    say("| `%s` | %d | %s |", r, vc_counts.by_result[r], MEANING[r] or "")
end
say("")

-- --- refusals before the export ---
say("## Refused before the export, by `tools/lua/verifiedcombo.lua`")
say("")
say("These never became a record, so `KnowledgeDb.export` never saw them.")
say("")
say("| reason | subjects |")
say("|---|---:|")
for _, reason in ipairs(sorted_pairs(vc_counts.by_reason)) do
    say("| `%s` | %d |", reason, vc_counts.by_reason[reason])
end
say("")

local blocked = VC.blocked_by_measurement(refused)
if #blocked > 0 then
    say("### The %d reproduced subject(s) held up only by the measurement", #blocked)
    say("")
    say("Each of these is a combo the game has already shown connects, in this cohort,")
    say("under this policy. The only thing missing is the number.")
    say("")
    say("| subject | kind | the combo | links | gaps | why not |")
    say("|---|---|---|---:|---|---|")
    for _, r in ipairs(blocked) do
        say("| `%s` | %s | %s | %s | %s | `%s` |",
            tostring(r.subject_id), tostring(r.subject_kind),
            tostring(r.notation_chain or "?"),
            tostring(r.successful_runs or "?"),
            table.concat(r.linked_gaps or {}, " "),
            r.reason)
    end
    say("")
end

-- --- the export's own refusals ---
say("## The export's own answer")
say("")
if not result then
    say("`KnowledgeDb.export` refused to judge anything: `%s`.", tostring(context_problem.reason))
    say("")
    for _, p in ipairs(context_problem.problems or {}) do
        say("- `%s`: %s", tostring(p.field), tostring(p.problem))
    end
    say("")
else
    say("%d record(s) were offered; %d crossed and %d were rejected.",
        #records, result.counts.exported, result.counts.rejected)
    say("")
    if result.counts.rejected > 0 then
        say("| reason | records |")
        say("|---|---:|")
        for _, reason in ipairs(sorted_pairs(result.counts.by_reason)) do
            say("| `%s` | %d |", reason, result.counts.by_reason[reason])
        end
        say("")
        for _, r in ipairs(result.rejected) do
            say("- `%s` (`%s`): %s", tostring(r.id), r.reason, tostring(r.detail))
        end
        say("")
    end
    if #records == 0 then
        say("No record reached the export at all, so its `missing_moves` list is empty -")
        say("`KnowledgeDb.combo` checks the measurement before it looks at the steps, and")
        say("never gets as far as asking about a slug. The next section asks that question")
        say("on its behalf.")
        say("")
    end
end

-- --- missing moves ---
say("## `missing_moves`: the slug table this needs (#17)")
say("")
say("Every action id below appears in a route that would be published for this cohort")
say("and has no slug in `data/characters/%s/moves.yaml`. This is the input for the", char_lc)
say("mapping table; nothing here guesses a slug.")
say("")
if #slug_gap == 0 then
    say("Nothing is missing: every move in every reproduced route already has a slug.")
else
    say("%d move(s), over %d reproduced subject(s) in this cohort.", #slug_gap, cohort_subjects)
    say("")
    say("| action id | how it was pressed | notation | display | combos blocked |")
    say("|---:|---|---|---|---:|")
    for _, e in ipairs(slug_gap) do
        say("| %s | %s | %s | %s | %d |", tostring(e.action_id), tostring(e.input_method),
            tostring(e.notation), tostring(e.display or "-"), #e.wanted_by)
    end
    say("")
    for _, e in ipairs(slug_gap) do
        say("- `%s` blocks: %s", tostring(e.action_id), table.concat(e.wanted_by, ", "))
    end
    say("")
end
if result and #result.missing_moves ~= #slug_gap then
    say("The export's own `missing_moves` holds %d entr(ies) rather than %d, because the",
        #result.missing_moves, #slug_gap)
    say("records it refused earlier never reached its step check. When the measurement")
    say("lands, the two lists become one.")
    say("")
end
if slug_written then
    say("A table to fill in has been written to `%s`", slug_table_path)
    say("(%d new entr(ies), %d kept from the existing file). Every `slug` in it is null",
        slug_written.added, slug_written.kept)
    say("and every `source` is `unfilled`: the file's own header says what filling it")
    say("enables. It carries the frame source's English move names, so it is a derived")
    say("work and ships the CC-BY-SA attribution; this report does not.")
    say("")
elseif slug_write_error then
    say("The slug table could not be written to `%s`: %s", slug_table_path,
        tostring(slug_write_error))
    say("")
end

-- --- unknowns ---
if result and #result.unknowns > 0 then
    say("## What the target has room for and nobody measured")
    say("")
    say("| field | records |")
    say("|---|---:|")
    for _, k in ipairs(sorted_pairs(result.counts.unknown_by_key)) do
        say("| `%s` | %d |", k, result.counts.unknown_by_key[k])
    end
    say("")
end

-- --- what a session would change ---
say("## What one session on the game would change")
say("")
if #blocked > 0 then
    say("**%d reproduced combo(s) have no measured damage.** `evidence.damage` was wired", #blocked)
    say("in 6d67e7c and `evidence.gauges` in f986074, both after every committed trial,")
    say("so every row in the logs is from before the runtime recorded either. Running")
    say("these routes with `RouteRun` records the damage, the hit count and both gauges")
    say("on each trial, and the same fold then produces %d record(s) with a", #blocked)
    say("`measured.damage` the schema accepts.")
    say("")
    say("Concretely, for this cohort:")
    say("")
    for _, r in ipairs(blocked) do
        say("- **%s** - %s (linked at gap %s)", tostring(r.notation_chain or r.subject_id),
            tostring(r.subject_id), table.concat(r.linked_gaps or {}, ", "))
    end
    say("")
end
say("After that session, what is still missing is not a measurement:")
say("")
say("1. the %d slug(s) above, in the other project's `moves.yaml` (#17)", #slug_gap)
say("2. the real `game_version` code from `game_versions.yaml`")
say("3. the release shape (#38 section 9): `public.combos` cannot hold conditions,")
say("   calibration or evidence, and #38 has already decided that what cannot be")
say("   represented is not exported automatically")
say("")
say("Everything in this list is a decision or a mapping. Only the first paragraph")
say("needs the game.")
say("")

-- --- licence ---
say("## Licence")
say("")
say("Measured on Street Fighter 6. No value in this document is derived from the frame")
say("data, so it carries no CC-BY-SA obligation - the same split `tools/lua/confirm.lua`")
say("states in its `licence_note`. Joining these rows to startup / on-hit figures, as a")
say("published page showing frame numbers would, does inherit one; see `docs/NOTICE.md`.")
say("")

-- --- defects ---
if #bugs > 0 then
    say("## DEFECTS")
    say("")
    say("%d record(s) that `tools/lua/verifiedcombo.lua` built were refused by", #bugs)
    say("`ce.verified_combo.v1` itself. That is a defect in this repository, not a fact")
    say("about the game, and this run is a failure.")
    say("")
    for _, b in ipairs(bugs) do
        for _, p in ipairs(b.problems or {}) do
            say("- `%s`: %s - %s", tostring(b.subject_id), tostring(p.field), tostring(p.problem))
        end
    end
    say("")
end

Cli.mkdir((out_path:gsub("/[^/]+$", "")))
local written, werr = rep:write(out_path)
if not written then Cli.die(TOOL, ("could not write %s: %s"):format(out_path, tostring(werr))) end
io.stderr:write(("%s: wrote %s (%d lines)\n"):format(TOOL, out_path, written))

os.exit(#bugs == 0 and 0 or 1)
