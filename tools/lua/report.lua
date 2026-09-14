-- =========================================================
-- tools/lua/report.lua - every trial the game has run for one character, drawn
-- on one page.
--
--   lua tools/lua/report.lua [--character Zangief] [--scheme modern]
--                            [--data reframework/data/ComboExplorer_data]
--                            [--out docs/ComboExplorer/sweep-report-<char>-<scheme>.html]
--
-- Needs Lua 5.4 and the logs the sweep wrote. No game, no network. The page it
-- writes is self-contained: open it in a browser, or publish it as it is.
-- =========================================================
--
-- WHAT IT READS
--
--   worklist/<char>-<scheme>.json   the pairs, and so the grid's two axes
--   trials/<char>-*.jsonl           every log for the character, one per experiment
--   route/*.json                    route definitions, to name a route log's steps
--   command_display/<Character>.json   classic notation, so a combo reads the way
--                                      players write it
--
-- WHAT IT WRITES
--
--   the page                        --out
--   docs/ComboExplorer/combos-<char>-<scheme>.md   the combo list on its own,
--                                      readable on GitHub without opening the page
--
-- Every log is read, not the latest one. The logs are a sequence of
-- experiments - delay 4, then the gap from the frame data, then the whole
-- notation group - and a later one exists because of what an earlier one
-- showed. The page lets a reader flip between them for the same reason.
--
-- Run it again after a session on the game and commit the page with the logs.

local Cli = dofile("tools/lua/cli.lua")

local json        = dofile("tools/lua/json.lua")
local Characters  = dofile("tools/lua/characters.lua")
local SweepReport = dofile("tools/lua/sweepreport.lua")

local opt = Cli.args("report", arg, {
    character = "Zangief",
    scheme = "modern",
    data = "reframework/data/ComboExplorer_data",
    template = "tools/lua/report-template.html",
})

local entry, cerr = Characters.resolve(opt.character)
if not entry then Cli.die("report", tostring(cerr)) end
local char_lc = entry.catalog:lower()
opt.out = opt.out or ("docs/ComboExplorer/sweep-report-%s-%s.html"):format(char_lc, opt.scheme)

local function read(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local text = f:read("a")
    f:close()
    return text
end

-- --- the worklist -------------------------------------------------------------

local wl_path = ("%s/worklist/%s-%s.json"):format(opt.data, char_lc, opt.scheme)
local worklist, werr = json.load_file(wl_path)
if not worklist then
    Cli.die("report", ("no worklist at %s (%s)\n\nThe grid's axes are the worklist's pairs, "
        .. "so there is nothing to draw without one."):format(wl_path, tostring(werr)))
end

-- --- the logs -----------------------------------------------------------------

-- Same rule as confirm.lua: a line that will not decode is counted, not dropped.
-- It is a trial that ran and whose result was lost.
local function read_log(path)
    local text = read(path)
    if not text then return nil end
    local records, bad = {}, 0
    for line in text:gmatch("[^\r\n]+") do
        local ok, rec = pcall(json.decode, line)
        if ok and type(rec) == "table" then
            records[#records + 1] = rec
        else
            bad = bad + 1
        end
    end
    return records, bad
end

local logs = {}
local prefix = char_lc .. "-"
for _, name in ipairs(Cli.list_dir(opt.data .. "/trials")) do
    if name:sub(1, #prefix) == prefix and name:match("%.jsonl$") then
        local path = ("%s/trials/%s"):format(opt.data, name)
        local records, bad = read_log(path)
        if records then
            logs[#logs + 1] = { name = name:gsub("%.jsonl$", ""), path = path,
                                records = records, bad_lines = bad }
        end
    end
end

local routes = {}
for _, name in ipairs(Cli.list_dir(opt.data .. "/route")) do
    if name:match("%.json$") then
        local doc = json.load_file(("%s/route/%s"):format(opt.data, name))
        if type(doc) == "table" and doc.id then routes[doc.id] = doc end
    end
end

-- --- build and write ---------------------------------------------------------

-- Classic notation is a label here, nothing more. A catalog that cannot be read
-- leaves the list in the notation the sweep pressed, which is still correct.
local classic = {}
do
    local catalog = json.load_file(Characters.catalog_path(entry))
    if type(catalog) == "table" then
        for id, row in pairs(catalog) do
            local cc = type(row) == "table" and row.classic_command
            if type(cc) == "table" and type(cc.display) == "string" then
                classic[tonumber(id) or id] = cc.display
            end
        end
    end
end

local model = SweepReport.build(worklist, logs, routes, classic)
model.generated_at = os.date("!%Y-%m-%dT%H:%M:%SZ")
model.sources = { worklist = wl_path, data = opt.data }

local template = read(opt.template)
if not template then Cli.die("report", "no page template at " .. opt.template) end

-- "</" is escaped so no string in the data - a reason, a note - can close the
-- script element it is embedded in.
local payload = json.encode(model):gsub("</", "<\\/")
local marker = "/*__MODEL__*/null"
local at = template:find(marker, 1, true)
if not at then Cli.die("report", "the template has no " .. marker .. " marker") end
local page = template:sub(1, at - 1) .. payload .. template:sub(at + #marker)
local title = ("%s %s 接続マップ"):format(entry.catalog,
    opt.scheme == "modern" and "Modern" or opt.scheme)
page = page:gsub("__TITLE__", function() return title end, 1)

local f = io.open(opt.out, "wb")
if not f then Cli.die("report", "could not write " .. opt.out) end
f:write(page)
f:close()

-- --- what was drawn ---------------------------------------------------------

-- --- the combo list, on its own ------------------------------------------------

local combos_path = opt.combos
    or ("docs/ComboExplorer/combos-%s-%s.md"):format(char_lc, opt.scheme)

local function chain(names, sep)
    return table.concat(names, sep or " → ")
end

local md = {}
local function line(fmt, ...)
    md[#md + 1] = select("#", ...) > 0 and fmt:format(...) or fmt
end

local confirmed, once = {}, {}
for _, c in ipairs(model.combos) do
    if c.status == SweepReport.COMBO.CONFIRMED then confirmed[#confirmed + 1] = c
    else once[#once + 1] = c end
end

local function classic_of(c)
    local names = {}
    for i, s in ipairs(c.steps) do names[i] = s.classic or "?" end
    return chain(names)
end

local function combo_rows(list)
    line("| コンボ（Modern） | Classic | 繋がった | 試行の内訳 | 繋がった隙間 (tick) | ダメージ |")
    line("|---|---|---|---|---|---|")
    for _, c in ipairs(list) do
        local inputs = {}
        for i, names in ipairs(c.inputs) do inputs[i] = chain(names) end
        -- Unanswered is shown apart from negative: most of it is an earlier
        -- experiment whose inputs never came out, not the combo failing.
        line("| %s | %s | %d 回 | 試行 %d・否定 %d・未回答 %d | %s | 未計測 |",
            table.concat(inputs, "<br>"), classic_of(c), c.links, c.attempts,
            c.negatives, c.unanswered, table.concat(c.linked_gaps, ", "))
    end
end

line("# %s %s — 繋がったコンボ", entry.catalog, opt.scheme == "modern" and "Modern" or opt.scheme)
line("")
line("`lua tools/lua/report.lua` が試行ログから書き出す一覧です。手で編集しないでください —")
line("実機でログが増えたら、同じコマンドで書き直します。")
line("")
line("- **確定**: %d 回以上の試行で繋がった", SweepReport.CONFIRM_LINKS)
line("- **1回だけ**: 繋がったのは1回。再試行で確かめるまで確定にしない")
line("- **ダメージは全件未計測**です。公開用の `ce.verified_combo.v1` は実測ダメージを必須にしています（#17, #36）")
line("")
line("## 確定 (%d)", #confirmed)
line("")
if #confirmed > 0 then combo_rows(confirmed) else line("まだありません。") end
line("")
line("## 1回だけ繋がった (%d)", #once)
line("")
if #once > 0 then combo_rows(once) else line("ありません。") end
line("")
line("生成: %s", model.generated_at)

do
    local mf = io.open(combos_path, "wb")
    if not mf then Cli.die("report", "could not write " .. combos_path) end
    mf:write(table.concat(md, "\n"), "\n")
    mf:close()
end

local rep = Cli.report()
rep:say("# Sweep report - %s / %s", entry.catalog, opt.scheme)
rep:say("")
rep:say("worklist pairs   %d  (pressable %d / repeated direction %d / follow-up %d)",
    model.worklist.count, model.press.single, model.press["repeat"], model.press.followup)
rep:say("combos           %d confirmed / %d seen once", #confirmed, #once)
for _, c in ipairs(confirmed) do
    rep:say("  %-40s  %s  (%d/%d)", chain(c.inputs[1]), classic_of(c), c.links, c.attempts)
end
for _, l in ipairs(model.pair_logs) do
    local v = l.counts.verdicts
    rep:say("pair log   %-36s %4d rows  link %d / combo_broke %d / whiff %d / wrong_move %d / other-pairs %d",
        l.name, l.counts.rows, v.link or 0, v.combo_broke or 0, v.whiff or 0, v.wrong_move or 0,
        l.counts.elsewhere)
end
for _, l in ipairs(model.route_logs) do
    rep:say("route log  %-36s %4d rows  link %d", l.name, l.counts.rows, l.counts.verdicts.link or 0)
end
rep:say("")
rep:say("written: %s (%d bytes)", opt.out, #page)
rep:say("written: %s", combos_path)
