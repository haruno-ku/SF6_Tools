-- Unit tests for tools/lua/batch.lua
--
-- The index page is built from what these functions read out of each
-- character's run. The failure worth a test is the quiet one: a report line
-- that changed shape and parsed as nothing, so 31 characters show no routes and
-- the page still looks finished.

local t = require("tests.lua.harness")
local B = dofile("tools/lua/batch.lua")

-- --- choosing characters --------------------------------------------------------

t.group("select")

local ALL = {
    { catalog = "Ryu", fighter_id = 1 }, { catalog = "Luke", fighter_id = 2 },
    { catalog = "Zangief", fighter_id = 6 },
}
local function resolve(name)
    for _, e in ipairs(ALL) do
        if e.catalog:lower() == name:lower() then return e end
    end
    return nil, ("%q is not known"):format(name)
end

t.eq(#B.select(nil, ALL, resolve), 3, "no --only is every character")
local some = B.select(" zangief ,Ryu,ryu", ALL, resolve)
t.eq(#some, 2, "names are resolved, trimmed and folded")
t.eq(some[1].catalog, "Ryu", "and come back in fighter order, not argument order")
local none, err = B.select("Ryu,Nobody", ALL, resolve)
t.is_nil(none, "an unknown name refuses the run")
t.ok(err and err:find("Nobody", 1, true), "and names what was not found")

t.group("lanes")

local lanes = B.lanes({ 1, 2, 3, 4, 5 }, 2)
t.eq(#lanes, 2, "two lanes")
t.eq_list(lanes[1], { 1, 3, 5 }, "round-robin")
t.eq_list(lanes[2], { 2, 4 }, "so neighbours are split")
t.eq(#B.lanes({ 1, 2 }, 8), 2, "never more lanes than characters")
t.eq(#B.lanes({ 1, 2 }, 0), 1, "never fewer than one")
t.eq(#B.lanes({}, 4), 0, "and no lanes for no characters - an empty lane would read as everyone")

-- --- command lines ------------------------------------------------------------------

t.group("command")

t.eq(B.command("lua", { "tools/lua/plan.lua", "--character", "Ryu" }, "x/log.txt", false),
    "lua tools/lua/plan.lua --character Ryu > x/log.txt 2>&1", "plain words are not quoted")
t.eq(B.command("lua", { "--starter-notation", "2 + 中" }, nil, false),
    'lua --starter-notation "2 + 中"', "an argument with spaces is")
t.eq(B.command("C:/Program Files/Lua/lua.exe", { "a" }, "l.log", true),
    '""C:/Program Files/Lua/lua.exe" a > l.log 2>&1"',
    "on Windows a line that starts with a quote is wrapped once more for cmd /c")
t.eq(B.command("C:/Lua/lua.exe", { "a" }, nil, true), "C:/Lua/lua.exe a",
    "and one that does not is left alone")

-- --- explore's report --------------------------------------------------------------

t.group("parse_explore_report")

local REPORT = table.concat({
    "# Offline candidate report - Ryu / modern / midscreen / none",
    "",
    "- frame data: RyoSogawa/sf6-sensei @ abc (CC-BY-SA)",
    "",
    "## Moves searched",
    "",
    "- catalog rows            102",
    "- starting moves          14  (normal,command_normal / manual)",
    "- target moves            52  (normal,command_normal,special,od_special,super / manual,simple)",
    "- frame data coverage     60 of 69 (87%)  over every row this run uses",
    "    starters      14 of  14 (100%)",
    "    targets       50 of  52 ( 96%)",
    "    follow-ups     0 of   3 (  0%)",
    "",
    "## Theoretical edges",
    "",
    "- pairs considered        900",
    "- candidate edges         551",
    "- excluded                349",
    "",
    "## Drive Rush Cancel candidates",
    "",
    "- DRC edges               234",
    "- excluded                12",
    "",
    "## Route candidates",
    "",
    "- routes                  1092",
    "- graph nodes             60",
    "- search complete         false",
    "",
}, "\n")

local r = B.parse_explore_report(REPORT)
t.eq(r.catalog_rows, 102, "catalog rows")
t.eq(r.starters, 14, "starting moves")
t.eq(r.targets, 52, "target moves")
t.eq(r.candidates, 551, "candidate edges")
t.eq(r.excluded, 349, "the plain excluded count, not the DRC one after it")
t.eq(r.drc_edges, 234, "DRC edges")
t.eq(r.routes, 1092, "routes")
t.eq(r.search_complete, false, "search complete is a boolean")
t.eq(r.frame_data, true, "frame data present")
t.eq(r.coverage.matched, 64, "coverage is starters plus targets")
t.eq(r.coverage.rows, 66, "over their rows, leaving out parentless derivations")
t.eq(r.coverage_all.rows, 69, "the overall figure is kept beside it")

local bare = B.parse_explore_report("# report\n- frame data: NONE. Every candidate is low confidence.\n")
t.eq(bare.frame_data, false, "no frame data is read as such")
t.is_nil(bare.routes, "a missing line is nil, never 0")
t.is_nil(B.parse_explore_report(""), "an empty report is no report")
t.is_nil(B.parse_explore_report(nil), "and so is none")

-- --- a row and its notes ----------------------------------------------------------------

t.group("row and notes")

local WL = { count = 4, pairs = { { confidence = "high" }, { confidence = "low" },
                                  { confidence = "low" }, { confidence = "low" } } }
local c = B.confidence_counts(WL)
t.eq(c.high, 1, "high counted")
t.eq(c.low, 3, "low counted")

local SUMMARY = { routes = 900, routes_complete = true, routes_drc = 300, trials = 0, logs = 0,
                  combos_confirmed = 0, combos_once = 0, page_bytes = 200000,
                  press = { single = 3, ["repeat"] = 1, followup = 0, unreadable = 0 } }
local row = B.row({ catalog = "Ryu", fighter_id = 1 }, "modern", r, WL, { count = 7 },
    { ["max-damage"] = { count = 12 }, ["no-gauge"] = { count = 0 } }, SUMMARY, {})
t.eq(row.lc, "ryu", "lowercase name")
t.eq(row.worklist_pairs, 4, "worklist pairs")
t.eq(row.drc_pairs, 7, "DRC pairs")
t.eq(row.routes, 900, "routes from the report run, which is what the page shows")
t.eq(row.routes_drc, 300, "DRC routes")
t.eq(row.plans["max-damage"], 12, "plan pairs")
t.is_nil(row.plans["starter-chu"], "a plan that was not written is nil")
t.eq(row.unpressable, 1, "unpressable pairs")
t.eq(row.page, "sweep-report-ryu-modern.html", "the page link")
t.is_nil(row.errors, "no errors is nil, not an empty list")

local function has(list, text)
    for _, n in ipairs(list) do if n:find(text, 1, true) then return true end end
    return false
end
t.ok(has(row.notes, "75%"), "a mostly-low worklist is noted")
t.ok(has(row.notes, "no-gauge"), "a plan with nothing to sweep is noted")
t.ok(not has(row.notes, "結合"), "a 97% join is not")

local failed = B.row({ catalog = "Guile", fighter_id = 18 }, "modern", nil, nil, nil, {}, nil,
    { { step = "report", message = "boom" } })
t.eq(#failed.errors, 1, "a failed step is kept")
t.ok(has(failed.notes, "report"), "and noted")
t.is_nil(failed.page, "a character whose report failed links nowhere")

local nofd = B.row({ catalog = "X", fighter_id = 99 }, "modern", bare, nil, nil, {}, nil, {})
t.ok(has(nofd.notes, "フレームデータなし"), "a character with no frame data is noted")

t.group("merge_rows and totals")

local merged = B.merge_rows(
    { { character = "Zangief", fighter_id = 6, worklist_pairs = 1 }, { character = "Ryu", fighter_id = 1 } },
    { { character = "Zangief", fighter_id = 6, worklist_pairs = 324 } })
t.eq(#merged, 2, "this run's rows replace the last run's for the same character")
t.eq(merged[1].character, "Ryu", "fighter order")
t.eq(merged[2].worklist_pairs, 324, "the new row wins")

local tot = B.totals({ row, failed })
t.eq(tot.characters, 2, "characters")
t.eq(tot.worklist_pairs, 4, "a failed row adds nothing")
t.eq(tot.failed, 1, "failures counted")
t.eq(tot.routes_drc, 300, "DRC routes summed")

-- --- formatting ------------------------------------------------------------------------

t.group("formatting")

t.eq(B.pass_time(324), "約16分", "Zangief, as the runbook had it")
t.eq(B.pass_time(590), "約30分", "Ryu")
t.eq(B.pass_time(2400), "約2時間", "a whole hour drops its .0")
t.eq(B.pass_time(2466), "約2.1時間", "Juri")
t.eq(B.pass_time(2888), "約2.4時間", "Guile")
t.eq(B.pass_time(nil), "-", "no worklist")
t.eq(B.thousands(1234567), "1,234,567", "thousands")
t.eq(B.thousands(999), "999", "under a thousand")
t.eq(B.bytes(2048), "2 KB", "KB")
t.eq(B.bytes(3 * 1024 * 1024), "3.0 MB", "MB")
t.eq(B.html([[<a href="x">&'</a>]]), "&lt;a href=&quot;x&quot;&gt;&amp;&#39;&lt;/a&gt;", "HTML escaping")

-- --- the pages ---------------------------------------------------------------------------

t.group("render_index")

local page = B.render_index("<t><!--__TOTALS__--></t><r><!--__ROWS__--></r>", { row, failed })
t.ok(page:find('href="sweep-report-ryu-modern.html"', 1, true), "a character links to its report")
t.ok(page:find("失敗", 1, true), "a failed character is marked")
t.ok(page:find("75%", 1, true), "a note with a percent sign survives substitution")
t.ok(not page:find("<!--__ROWS__-->", 1, true), "the markers are replaced")
local nope, perr = B.render_index("<no markers>", {})
t.is_nil(nope, "a template without markers is refused")
t.ok(perr and perr:find("TOTALS", 1, true), "naming the marker")

local evil = B.row({ catalog = "<script>", fighter_id = 1 }, "modern", nil, nil, nil, {}, nil, {})
t.ok(not B.index_rows_html({ evil }):find("<script>", 1, true), "names are escaped")

t.group("characters.md")

local md = B.render_characters_md({ row, failed }, "modern")
t.ok(md:find("[Ryu](sweep-report-ryu-modern.html)", 1, true), "links the page")
t.ok(md:find("[12](plans/ryu-modern-max-damage.md)", 1, true), "links a plan with its pair count")
t.ok(md:find("**Guile**", 1, true), "lists a character with notes")

t.group("runbook table")

local tbl = B.runbook_table({ row })
t.ok(tbl:find("| Ryu | 4 | 約0分 | 7 |", 1, true), "a row per character")
local doc = "intro\r\n" .. B.RUNBOOK_OPEN .. "\r\nold\r\n" .. B.RUNBOOK_CLOSE .. "\r\nafter\r\n"
local out = B.replace_between(doc, B.RUNBOOK_OPEN, B.RUNBOOK_CLOSE, "a\nb")
t.eq(out, "intro\r\n" .. B.RUNBOOK_OPEN .. "\r\na\r\nb\r\n" .. B.RUNBOOK_CLOSE .. "\r\nafter\r\n",
    "the body between the markers is replaced, in the file's own line endings")
t.eq(B.replace_between(out, B.RUNBOOK_OPEN, B.RUNBOOK_CLOSE, "a\nb"), out, "and replacing it again changes nothing")
t.is_nil(B.replace_between("no markers", B.RUNBOOK_OPEN, B.RUNBOOK_CLOSE, "x"),
    "a runbook without the markers is refused, not appended to")
t.is_nil(B.replace_between(B.RUNBOOK_CLOSE .. B.RUNBOOK_OPEN, B.RUNBOOK_OPEN, B.RUNBOOK_CLOSE, "x"),
    "and so are markers out of order")

return t.finish()
