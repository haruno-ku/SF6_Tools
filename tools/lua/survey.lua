-- =========================================================
-- tools/lua/survey.lua - runs the offline pipeline over every character and
-- prints one table.
--
--   lua tools/lua/survey.lua [--character all|<Name>] [--out <dir>]
--
-- Needs Lua 5.4, the shipped catalogs, and data/frame-data. No game, no network.
-- =========================================================
--
-- THE QUESTION THIS ANSWERS
--
-- tools/lua/audit.lua measured the classifier across 31 characters and found it
-- was Zangief-shaped. This measures the OTHER half: the join between a catalog
-- notation and the external frame table, which was never measured across
-- characters at all - and, until today, was not even measured across a whole
-- character. The committed Zangief report said "14 of 14 (100%)" because
-- coverage was being taken over the fourteen starting moves while the run aimed
-- at thirty-three targets.
--
-- A join that fails is not like a classifier that fails. The rows do not
-- disappear; they arrive with no numbers, which the generator correctly treats
-- as unknown. So the character still produces candidates, all of them low
-- confidence, and the output looks like a character whose moves happen not to
-- be well understood. The only way to tell that apart from a broken join is to
-- count.
--
-- WHAT IT DELIBERATELY DOES NOT DO
--
-- It does not write candidate documents. Thirty-one characters of those run to
-- hundreds of megabytes and say nothing this table does not. It also does not
-- repair a single notation: the same reason audit.lua does not. A tool that
-- quietly fixed the joins it was measuring would report a clean sheet for a
-- pipeline that is not clean.

local Cli = dofile("tools/lua/cli.lua")

local json       = dofile("tools/lua/json.lua")
local Characters = dofile("tools/lua/characters.lua")
local Catalog    = require("func/ComboExplorer/core/Catalog")
local FrameData  = require("func/ComboExplorer/core/FrameData")
local CG         = require("func/ComboExplorer/core/CandidateGenerator")
local GraphStore = require("func/ComboExplorer/core/GraphStore")
local RouteSearch = require("func/ComboExplorer/core/RouteSearch")
local Schema     = require("func/ComboExplorer/core/Schema")

-- --- arguments ---------------------------------------------------------------

local opt = {
    character = "all",
    out = "docs/ComboExplorer",
    max_steps = 2,      -- routes are here to prove the pipeline runs, not to be kept
    beam = 400,
    max_routes = 2000,
}

opt = Cli.args("survey", arg, opt)

local function die(msg) Cli.die("survey", msg) end

local targets = {}
if opt.character == "all" then
    targets = Characters.all() or die("could not read the character bridge")
else
    local e, err = Characters.resolve(opt.character)
    if not e then die(tostring(err)) end
    targets = { e }
end

-- --- the scope every character is measured under -----------------------------
--
-- The same scope the Zangief run uses, so the numbers are comparable. It is a
-- scope, not a claim: a character whose interesting moves fall outside it will
-- look thin here and that is a fact about this scope.
local FROM = { categories = { "normal", "command_normal" }, input_methods = { "manual" } }
local TO   = { categories = { "normal", "command_normal", "special", "od_special", "super" },
               input_methods = { "manual", "simple" } }

-- --- measuring one character -------------------------------------------------

local function measure(entry)
    local raw, jerr = json.load_file(Characters.catalog_path(entry))
    if not raw then return nil, ("no catalog: %s"):format(tostring(jerr)) end

    local cat = Catalog.build(raw)
    if not cat then return nil, "Catalog.build refused it" end

    local frames_path = Characters.frame_data_path(entry)
    local ok, frames_raw = pcall(dofile, frames_path)
    local idx = (ok and frames_raw) and FrameData.index(frames_raw) or nil

    local m = {
        character = entry.catalog,
        fighter_id = entry.fighter_id,
        frame_data = idx and frames_path or nil,
        frame_commit = idx and idx.meta.commit or nil,
        rows = #cat.rows,
        moves = idx and #idx.keys or 0,
    }

    local starters = Catalog.probeable(cat, FROM)
    local tgts = Catalog.probeable(cat, TO)
    local fups = {}
    for _, row in ipairs(cat.rows) do
        if row.exclusion == "followup" then fups[#fups + 1] = row end
    end
    m.starters, m.targets, m.followups = #starters, #tgts, #fups

    -- Rows that never reach the pairing stage, counted by reason. The headline
    -- below answers a question about PAIRS, and a reader who only has that
    -- number cannot tell whether anything was lost before pairs existed.
    --
    -- Two of the reasons are about this project's own vocabulary rather than
    -- about the move: `unclassified` is the classifier having no word for the
    -- notation, and `any_button` is the notation naming no strength. Both are
    -- counted apart from the reasons that describe the move itself - a throw is
    -- a throw whatever we know.
    m.rows_lost = { unclassified = 0, any_button = 0 }
    for _, row in ipairs(cat.rows) do
        if m.rows_lost[row.exclusion] ~= nil then
            m.rows_lost[row.exclusion] = m.rows_lost[row.exclusion] + 1
        end
    end

    -- Coverage, per set. One number over a mixed set hides the case worth
    -- seeing: starters joining and targets not.
    if idx then
        local function cov(list, parents)
            if #list == 0 then return { rows = 0, matched = 0, ratio = 1, ambiguous = 0,
                                        unmatched_detail = {} } end
            return FrameData.coverage(idx, list, { parents = parents })
        end
        -- The parent set: every probeable move this character has, which is the
        -- same set the edge builder pairs them with.
        local could_precede = {}
        for _, r in ipairs(starters) do could_precede[#could_precede + 1] = r end
        for _, r in ipairs(tgts) do could_precede[#could_precede + 1] = r end

        m.cov_starters = cov(starters)

        -- Targets get the parent set too, and not only the rows marked as
        -- derivations. A rekka's later hits are spelled "6+P" in the catalog
        -- with no ">" on them at all - Jamie has thirteen such rows, A.K.I. two,
        -- C.Viper four - so they arrive here as ordinary targets and join to
        -- nothing, while the source has had them all along as "236LP~6P".
        -- Tried only after the row's own spelling fails, so nothing that
        -- matches today changes.
        m.cov_targets = cov(tgts, could_precede)

        -- Derivations are measured against the moves they could come out of.
        -- Asked on its own a derivation row joins to nothing on any character,
        -- because the source never spells one on its own - it spells the chain.
        -- The parent list is every probeable move this character has, which is
        -- the same set the edge builder would pair them with.
        m.cov_followups = cov(fups, could_precede)
        m.ambiguous_joins = (m.cov_starters.ambiguous or 0) + (m.cov_targets.ambiguous or 0)
        m.band_conflicts = (m.cov_starters.band_conflict or 0)
            + (m.cov_targets.band_conflict or 0)
        m.unmatched = {}
        for _, part in ipairs({ m.cov_starters, m.cov_targets }) do
            for _, u in ipairs(part.unmatched_detail or {}) do
                m.unmatched[#m.unmatched + 1] = { action_id = u.action_id, classic = u.classic }
            end
        end
    end

    local gen = CG.generate(cat, idx, { from = FROM, to = TO, include_followups = true,
                                        provenance = Schema.provenance({}) })
    if not gen then return nil, "candidate generation refused it" end
    m.edges = #gen.candidates
    m.excluded = #gen.excluded
    m.by_confidence = gen.stats.by_confidence
    m.by_reason = gen.stats.by_reason
    -- The rule the whole project runs on, measured rather than asserted.
    --
    -- This used to compare each exclusion reason against "frame_data_incomplete"
    -- and count the matches. That string is a REASON - why a pair IS a candidate
    -- - and can never appear in by_exclusion, whose whole vocabulary is
    -- frame_margin_negative / no_mechanism_found / self_pair_without_chain. So
    -- the count was zero by construction and would have stayed zero however
    -- badly the rule was broken. A metric that cannot fail reports success, which
    -- is worse than no metric.
    --
    -- What actually distinguishes a legitimate exclusion from one made on
    -- absence is whether it CARRIES THE THING THAT DECIDED IT: a negative margin
    -- has the number, a non-chaining self-pair has the source's own statement.
    -- An exclusion with neither was decided by something nobody wrote down, and
    -- the only candidate for that is missing information.
    m.excluded_missing_data = 0
    m.excluded_without_evidence = {}
    for _, x in ipairs(gen.excluded) do
        local justified
        if x.reason == "frame_margin_negative" then
            justified = type(x.margin_frames) == "number"
        elseif x.reason == "self_pair_without_chain" then
            -- The value, not the sentence. The record carries an `evidence`
            -- string whether or not the source actually said anything, so
            -- testing for its presence passed even with the bug re-introduced
            -- that excludes a self-pair on an UNKNOWN chain property. `false`
            -- means stated; nil means nobody knew.
            justified = (x.chain_property == false)
        else
            justified = false      -- no_mechanism_found carries no evidence by design
        end
        if not justified then
            m.excluded_missing_data = m.excluded_missing_data + 1
            if #m.excluded_without_evidence < 5 then
                m.excluded_without_evidence[#m.excluded_without_evidence + 1] = {
                    from = x.from, to = x.to, reason = x.reason,
                }
            end
        end
    end

    local g = GraphStore.build(gen.candidates, {
        character = entry.catalog:lower(), game_patch = "survey",
        ac_sha256 = cat.ac_sha256, bcm_sha256 = cat.bcm_sha256,
    })
    local found = RouteSearch.search(g, {
        frame_idx = idx, character = entry.catalog:lower(), control_scheme = "modern",
        max_steps = opt.max_steps, beam_width = opt.beam, max_routes = opt.max_routes,
        collapse_canonical_variants = true,
    })
    m.nodes = GraphStore.node_count(g)
    m.routes = found and #found.routes or 0
    m.search_complete = found and found.stats.complete or false
    return m
end

local rows, failures = {}, {}
for _, entry in ipairs(targets) do
    local m, err = measure(entry)
    if m then rows[#rows + 1] = m
    else failures[#failures + 1] = ("%s: %s"):format(entry.catalog, tostring(err)) end
end
if #rows == 0 then die("nothing could be measured\n  " .. table.concat(failures, "\n  ")) end

-- --- the report --------------------------------------------------------------

local report = Cli.report()
local function say(fmt, ...) report:say(fmt, ...) end

local function pct(c)
    if not c or c.rows == 0 then return "  -" end
    return ("%3.0f"):format(c.ratio * 100)
end

say("# Offline pipeline survey - %d character(s)", #rows)
say("")
say("Catalog -> frame-data join -> candidates -> routes, over every shipped")
say("character. No game, no network. Nothing here has been run on Street Fighter 6:")
say("every edge and every route is a candidate.")
say("")
say("## Per character")
say("")
say("```")
say("%-10s %5s %6s %6s %5s %5s %5s %5s %4s %6s %5s %5s %5s %7s",
    "char", "rows", "start", "targ", "fups", "cvS%", "cvT%", "cvF%", "amb",
    "edges", "high", "med", "low", "routes")
for _, m in ipairs(rows) do
    local c = m.by_confidence or {}
    say("%-10s %5d %6d %6d %5d %5s %5s %5s %4d %6d %5d %5d %5d %7d",
        m.character, m.rows, m.starters, m.targets, m.followups,
        pct(m.cov_starters), pct(m.cov_targets), pct(m.cov_followups),
        m.ambiguous_joins or 0, m.edges, c.high or 0, c.medium or 0, c.low or 0, m.routes)
end
say("```")
say("")
say("- `cvS/cvT/cvF` how many starting moves / target moves / derivations found")
say("  frame data. A miss is an unknown, never an exclusion - the move stays a")
say("  candidate with its gaps named")
say("- `amb`  joins that matched only by guessing between several source")
say("  spellings. Counted apart from a clean match because they are not one")
say("")

-- The rule the project is built on, checked rather than asserted.
local total_missing_data_exclusions = 0
for _, m in ipairs(rows) do
    total_missing_data_exclusions = total_missing_data_exclusions + (m.excluded_missing_data or 0)
end
local total_excluded = 0
for _, m in ipairs(rows) do total_excluded = total_excluded + (m.excluded or 0) end

local lost_unclassified, lost_any_button = 0, 0
for _, m in ipairs(rows) do
    lost_unclassified = lost_unclassified + ((m.rows_lost or {}).unclassified or 0)
    lost_any_button = lost_any_button + ((m.rows_lost or {}).any_button or 0)
end

say("## Was any PAIR dropped for missing data?")
say("")
say("**%d** of %d pair exclusions, across all %d characters.",
    total_missing_data_exclusions, total_excluded, #rows)
say("")
say("Measured by asking each excluded pair whether it carries the thing that")
say("decided it - the margin, or the source's own statement that the move does")
say("not chain. An exclusion with neither was decided by something nobody wrote")
say("down, and missing information is the only candidate for that.")
say("")
if total_missing_data_exclusions == 0 then
    say("Which is the answer it has to be. A gap in the frame source is recorded as")
    say("an unknown and the pair stays a candidate; only a KNOWN negative margin")
    say("excludes, and it excludes with the number attached.")
else
    say("Which is wrong. Information the source does not carry has become a")
    say("negative answer somewhere, and that is the one failure this project is")
    say("built to prevent.")
    say("")
    for _, m in ipairs(rows) do
        for _, x in ipairs(m.excluded_without_evidence or {}) do
            say("  %-10s %s -> %s  (%s)", m.character, tostring(x.from), tostring(x.to),
                tostring(x.reason))
        end
    end
end
say("")

say("### What the number above does not cover")
say("")
say("Pairs, and only pairs. A row that never became half of one is not in the")
say("%d, and two of the reasons a row is dropped are about this project's", total_excluded)
say("vocabulary rather than about the move:")
say("")
say("```")
say("unclassified   %4d rows   the classifier has no word for the notation", lost_unclassified)
say("any_button     %4d rows   the notation names no strength", lost_any_button)
say("```")
say("")
say("Neither is a statement that the move does not work, and both are listed")
say("per character in catalog-audit.md. They are named here because the")
say("heading above reads wider than the thing it measures, and a reader with")
say("only that number would conclude nothing was lost anywhere.")
say("")

say("## Where the join is worst")
say("")
say("Sorted by how many target moves arrived with no numbers. These characters")
say("produce candidates that are all low confidence for a reason that is about")
say("the join, not about the character.")
say("")
local worst = {}
for _, m in ipairs(rows) do worst[#worst + 1] = m end
table.sort(worst, function(a, b)
    local am = a.cov_targets and (a.cov_targets.rows - a.cov_targets.matched) or 0
    local bm = b.cov_targets and (b.cov_targets.rows - b.cov_targets.matched) or 0
    if am ~= bm then return am > bm end
    return a.character < b.character
end)
say("```")
say("%-10s %8s %8s   %s", "char", "unmatched", "of", "examples")
for n = 1, math.min(10, #worst) do
    local m = worst[n]
    local miss = m.cov_targets and (m.cov_targets.rows - m.cov_targets.matched) or 0
    local ex = {}
    for j = 1, math.min(4, #(m.unmatched or {})) do
        ex[#ex + 1] = tostring(m.unmatched[j].classic)
    end
    say("%-10s %8d %8d   %s", m.character, miss,
        m.cov_targets and m.cov_targets.rows or 0, table.concat(ex, "  "))
end
say("```")
say("")

if #failures > 0 then
    say("## Characters that could not be measured")
    say("")
    for _, f in ipairs(failures) do say("- %s", f) end
    say("")
end

say("## Scope")
say("")
say("From: %s / %s", table.concat(FROM.categories, ","),
    table.concat(FROM.input_methods, ","))
say("To:   %s / %s", table.concat(TO.categories, ","), table.concat(TO.input_methods, ","))
say("Routes: max %d steps, beam %d, cap %d - present to prove the pipeline runs",
    opt.max_steps, opt.beam, opt.max_routes)
say("")
say("A character whose interesting moves fall outside this scope looks thin here,")
say("and that is a fact about the scope rather than about the character.")

-- --- write -------------------------------------------------------------------

Cli.mkdir(opt.out)
report:write(opt.out .. "/character-survey.md")

local doc = { schema = "ce.character_survey.v1", characters = rows, failures = failures,
              scope = { from = FROM, to = TO, max_steps = opt.max_steps,
                        beam = opt.beam, max_routes = opt.max_routes } }
local n = json.save_file(opt.out .. "/character-survey.json", doc, { indent = "  " })
print("")
print("written: " .. opt.out .. "/character-survey.md")
print("written: " .. opt.out .. "/character-survey.json  (" .. tostring(n) .. " bytes)")
