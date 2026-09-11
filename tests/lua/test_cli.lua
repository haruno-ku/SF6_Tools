-- Unit tests for tools/lua/cli.lua
--
-- The four dev-machine CLIs are about 1700 lines and had no tests, while every
-- one of the 23 core modules has one. They are not incidental scripts: the
-- numbers in catalog-audit.md and character-survey.md are what decisions get
-- made from, and "0 rows dropped for missing data" is a claim about the whole
-- project's core rule.
--
-- This covers the half that is genuinely shared. The part that matters most is
-- argument parsing, because a mistyped flag that is silently ignored runs the
-- whole tool with the wrong settings and reports nothing wrong.

local t = require("tests.lua.harness")
local Cli = dofile("tools/lua/cli.lua")

-- --- the require shim --------------------------------------------------------

t.group("the require shim")

-- If this did not work, nothing else in any CLI would load.
local ok, Schema = pcall(require, "func/ComboExplorer/core/Schema")
t.ok(ok, "a shipped module resolves through the shim")
t.ok(Schema ~= nil and Schema.STATUS ~= nil, "and is the real module")

-- dofile()ing the file again must not stack a second searcher.
local before = #package.searchers
dofile("tools/lua/cli.lua")
t.eq(#package.searchers, before, "loading it twice installs one searcher, not two")

-- --- arguments ---------------------------------------------------------------

t.group("argument parsing")

local DEFAULTS = { character = "all", out = "docs", beam = 400, collapse = true }

local opt = Cli.parse({}, DEFAULTS)
t.eq(opt.character, "all", "defaults come through when nothing is passed")
t.eq(opt.beam, 400, "including numbers")

opt = Cli.parse({ "--character", "Guile" }, DEFAULTS)
t.eq(opt.character, "Guile", "a value overrides its default")
t.eq(opt.out, "docs", "and the others are untouched")

opt = Cli.parse({ "--beam", "4000" }, DEFAULTS)
t.eq(opt.beam, 4000, "a numeric value arrives as a number")
t.eq(math.type(opt.beam), "integer", "and stays an integer")

opt = Cli.parse({ "--max-steps", "3" }, DEFAULTS)
t.eq(opt.max_steps, 3, "a dashed flag becomes an underscored key")

-- The one that was a real bug. A non-empty string is truthy in Lua, so
-- `--collapse false` used to turn collapsing ON and then write the string
-- "false" into the exported document's own account of the run - a file whose
-- record of the search said the opposite of what the search did.
opt = Cli.parse({ "--collapse", "false" }, DEFAULTS)
t.eq(opt.collapse, false, "--collapse false means false, not a truthy string")
t.eq(type(opt.collapse), "boolean", "as a boolean")
opt = Cli.parse({ "--collapse", "true" }, DEFAULTS)
t.eq(opt.collapse, true, "and --collapse true means true")

opt = Cli.parse({ "--no-collapse" }, DEFAULTS)
t.eq(opt.collapse, false, "--no-x is a bare false")
t.eq(opt.no_collapse, nil, "and does not leave a stray no_x key behind")

-- A mistyped flag has to be an error. Ignoring it runs the tool with the wrong
-- settings and reports nothing, which is worse than not running.
local bad, why = Cli.parse({ "-character", "Guile" }, DEFAULTS)
t.is_nil(bad, "a single dash is refused")
t.ok(why:find("unrecognised") ~= nil, "and says so")

bad, why = Cli.parse({ "Guile" }, DEFAULTS)
t.is_nil(bad, "a bare word is refused")

bad, why = Cli.parse({ "--character" }, DEFAULTS)
t.is_nil(bad, "a flag with no value is refused")
t.ok(why:find("needs a value") ~= nil, "and says which one: " .. tostring(why))

-- Defaults are not mutated by parsing - two runs in one process must not leak.
t.eq(DEFAULTS.character, "all", "the defaults table is left alone")
t.eq(DEFAULTS.collapse, true, "in every field")

-- --- die ---------------------------------------------------------------------

t.group("die")

local exited, written
local real_exit, real_stderr = Cli.exit, Cli.stderr
Cli.exit = function(code) exited = code end
Cli.stderr = { write = function(_, s) written = s end }

Cli.die("mytool", "something specific went wrong")
t.eq(exited, 1, "die exits non-zero")
t.ok(written:find("mytool") ~= nil, "naming the tool")
t.ok(written:find("something specific") ~= nil, "and the reason")

-- args() is parse-or-die, which is what a script wants at the top.
exited, written = nil, nil
Cli.args("mytool", { "--nope" }, DEFAULTS)
t.eq(exited, 1, "args dies on a bad option")

exited = nil
local good = Cli.args("mytool", { "--character", "Ryu" }, DEFAULTS)
t.is_nil(exited, "and does not die on a good one")
t.eq(good.character, "Ryu", "returning the parsed options")

Cli.exit, Cli.stderr = real_exit, real_stderr

-- --- reports -----------------------------------------------------------------

t.group("reports")

local r = Cli.report()
r:say("plain")
r:say("%s = %d", "count", 7)
t.eq(#r.lines, 2, "lines are collected")
t.eq(r.lines[2], "count = 7", "with formatting applied")

-- What is printed and what is saved must be the same text. A report that showed
-- one thing and wrote another would be the worst kind of artifact.
t.eq(r:text(), "plain\ncount = 7\n", "the saved text is exactly the printed lines")

local path = os.tmpname()
local n = r:write(path)
t.eq(n, 2, "writing reports how many lines went out")
local f = io.open(path, "rb")
t.eq(f:read("a"), r:text(), "and the file matches")
f:close()
os.remove(path)

t.is_nil(Cli.report():write("no/such/dir/x.md"), "an unwritable path is reported, not raised")

-- --- filesystem --------------------------------------------------------------

t.group("listing")

local names = Cli.list_dir("reframework/data/TrainingComboTrials_data/command_display")
t.eq(#names, 31, "a real directory lists (" .. #names .. ")")

local sorted = true
for i = 2, #names do
    if names[i - 1] > names[i] then sorted = false end
end
t.ok(sorted, "sorted, because `ls` order is not guaranteed and a report should not "
     .. "differ between runs for no reason")

t.eq_list(Cli.list_dir("no/such/directory"), {}, "a missing directory is empty, not an error")

t.eq(Cli.mkdir(""), false, "mkdir refuses an empty path")
t.eq(Cli.mkdir(nil), false, "and nil")

return t.finish()
