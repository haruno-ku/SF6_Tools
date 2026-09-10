# SF6 Combo Explorer

Automated combo discovery for Street Fighter 6, built on
[Wael3rd/SF6_Tools](https://github.com/Wael3rd/SF6_Tools). It drives Training
Mode, records which moves actually link into which, and exports the verified
results.

The guiding rule, from the plan: **theory generates candidates, the game decides
what is true.** Nothing is written down as a fact because a frame-data table
said so.

- Plan: [`plan-v3-implementation.md`](plan-v3-implementation.md) (the current one)
- Original: [`plan-v2-modern-first.md`](plan-v2-modern-first.md)

---

## Current build: `0.3.0-diagnostics` — READ ONLY

This build **never injects input**. It watches and measures.

That is not caution for its own sake. Three things decide how everything after
them is built, and none of them can be settled by reading source:

| Probe | Question | Why it blocks everything |
|---|---|---|
| **A** | Is combo damage actually readable? | `mpTeam.mComboDamage` is read at exactly one site in all of upstream, inside a `pcall`, with an HP-delta fallback its author wrote because it may read zero. If it reads zero here, every recorded edge gets damage 0 and the scoring phase produces garbage that looks fine. |
| **B** | Is one input-hook call one frame? | The hook fires at least once per player per frame, and upstream says hitstop makes hook ticks drift from engine frames. Until that is measured, a recorded "delay 5" has no unit. |
| **C** | What does one attempt cost in real time? | That single number decides how large the brute-force matrix can be. There is no way to run the game faster. |
| **D** | Does the shipped move catalog describe *this* build? | Everything downstream is keyed on its action ids. If they have moved, every recorded edge is about a move nobody meant — and the failure is silent. |

All four are in this build, and none of them presses a button. C turned out
to be measurable by watching the operator reset the stage, rather than needing
injection first.

---

## Two machines

The code is written on a machine with no SF6 on it; the game runs somewhere
else. Git is the link.

```
[dev machine]                            [gaming PC]
  edit Lua, run tests      --push-->       git pull
  read the reports                         scripts/install-dev.ps1
        ^                                  play, run the probes
        |                                  reframework/data/ComboExplorer_data/
        +----------------pull------------  diagnostics/*.json  --commit-->
```

Diagnostic reports are written as JSON inside the game folder, so they get
copied back into the repo and committed. That is the whole feedback loop.

---

## Install (gaming PC)

**Prerequisites:** Street Fighter 6 (Steam), and the base SF6_Tools suite
working — REFramework menu opens on `Insert`, Training Script Manager appears.
If that is not already true, set it up and confirm it before going further.

```powershell
git clone https://github.com/haruno-ku/SF6_Tools.git sf6-combo-explorer
cd sf6-combo-explorer
git checkout feat/combo-explorer

# See what would be copied, without writing anything
.\scripts\install-dev.ps1 -WhatIf

# First install on this machine: also places REFramework (dinput8.dll) and the
# D2D plugin. Later runs should omit -Bootstrap.
.\scripts\install-dev.ps1 -Bootstrap
```

The script finds the game through the Steam library index. If it cannot,
pass `-GameDir "…\steamapps\common\StreetFighter6"` or set `$env:SF6_DIR`.

It will not run while SF6 is open, and it never overwrites recorded combos,
slot exports, session stats or your own config — those live in the same tree as
the shipped data files, so the exclusions are what keep a sync from wiping a
training setup.

To update later: `git pull` then `.\scripts\install-dev.ps1` (no `-Bootstrap`).

---

## Running the probes

1. Launch SF6, enter **Training Mode**, pick **Zangief** on **Modern** for P1.
2. `Insert` → REFramework menu.
3. **Training Script Manager → TRAINING MODES → COMBO EXPLORER**.
   (It is not on the top bar and not in the `SWITCH` cycle, on purpose: it is an
   unattended mode that can run for an hour, and landing on it by accident
   while cycling with a pad would be unwelcome.)
4. Open **SF6 COMBO EXPLORER** in the REFramework menu.

### First: sanity-check the live readout

Expand **LIVE READOUT** and hit the dummy a few times. Every row should move:

- `P1 control` reads **MODERN**
- `P1 action id` changes when you press a button
- `P1 combo_cnt` counts your hits
- `P2 gard_combo_cnt` counts when the dummy blocks instead
- `mComboDamage P1 / P2` shows a number on at least one side during a combo

> **If `mComboDamage P1 / P2` stays `-- / --`**, that is the important
> finding, not a bug to work around. Run probe A anyway and send the report:
> it means the Explorer has to measure damage from HP instead.

### Probe A — damage readability

1. Expand **PROBE A**, press **START**.
2. Land **at least 5 combos on the dummy, of clearly different lengths**, and
   include at least one that does **not** kill.

   Both of those matter. A lethal combo cannot be used for the comparison at
   all: the HP delta is capped at the health that existed while the damage
   field is not, so the two legitimately diverge. And combos that are all the
   same size cannot tell a scale factor from a fixed per-hit offset - the probe
   will say so rather than guess.
3. Press **WRITE REPORT**.

Writes `diagnostics/probe_a_damage-<timestamp>.json` plus a `-latest.json`
copy. The timestamped file is the record: a re-run after a patch must not
destroy the sample a decision was made on.

The panel states its own conclusion and says when it does not yet have enough
to offer one.

### Probe B — clock

1. Expand **PROBE B**, press **START**.
2. Play normally for **30 seconds or so, including some hits**. Hitstop has to
   be represented in the sample, because it is exactly what is suspected of
   making the two clocks disagree — the probe refuses to draw a conclusion from
   a sample without any.
3. Press **WRITE REPORT**.

Writes `diagnostics/probe_b_clock-<timestamp>.json`.

Frames where the injection gate was shut, where the game was paused, and the
partial frame the probe started in are excluded from the arithmetic and
reported separately. That exclusion is the whole point: those frames cannot be
observed, and counting them as "frames where the engine called nothing" is how
a perfectly clean build gets reported as a broken one.

The result to hope for is *one call per player per frame* and *no gap*. Any
other answer is still useful — it just means delays stay in ticks and get
converted later.

### Probe C — what a reset costs

1. Expand **PROBE C**, press **START**.
2. Reset the stage from the training menu **a dozen times**. Play a little
   between resets; it does not matter what you do.
3. Press **WRITE REPORT**.

This times how long a reset takes to actually settle, which is not the same as
how long the game's refresh flag is up — the flag clears well before the stage
is reproducible. That number is what decides how large the brute-force sweep
can be, and it also replaces the current guess for how long to wait before
starting a trial.

The suggested value it reports is the **worst** reset seen, not the average. A
settle gate that is right on average starts half its trials against a stale
combo counter.

### Probe D — does the catalog match this game

1. Run **PROBE A** for a while first, so there are observed action ids to
   compare against. Just playing normally is enough.
2. Expand **PROBE D**, press **LOAD CATALOG**, then **WRITE REPORT**.

This loads the shipped `command_display` file for P1's character — raw, never
through the suite's own reader — and checks it against the action ids the game
actually produced.

> If it reports that **none** of the observed ids are in the catalog, stop and
> send that report. It means the catalog is for a different character or the
> game data has moved, and every id in the project would be wrong.

### Send the results back

```powershell
# from the game folder
Copy-Item "…\StreetFighter6\reframework\data\ComboExplorer_data\diagnostics\*.json" `
          ".\reframework\data\ComboExplorer_data\diagnostics\"
git add reframework/data/ComboExplorer_data/diagnostics
git commit -m "probe: A-D results from <machine>"
git push
```

---

## Regression check

The Explorer adds a mode; it must not disturb the ones already there. After
installing, confirm each still behaves normally:

- Hit Confirm, Reaction Drills, Post Guard, Custom Combo Trials, Execution Drill
- Distance Viewer, Sheldon's Boxes, Recording Slot Manager
- **REFramework menu → Training Suite → Script Errors is empty.**
  In particular there must be no `pl_input_sub hook not installed` — that hook
  is the foundation of the whole approach.

Switching to COMBO EXPLORER sets the dummy to no-guard, the same way the other
modes set their own guard type. Switching back to DISABLED restores it.

---

## Development (dev machine)

```bash
pnpm test           # parse every Explorer Lua file, then run the unit tests
pnpm lint:lua       # parse only
pnpm gen:fixtures   # regenerate the notation fixture from the shipped catalog
```

Needs Node 20+ and Lua 5.4 (`winget install --id DEVCOM.Lua`). A shell opened
before that install will not have Lua on PATH yet; the runner falls back to the
default install location.

Only the pure modules are testable off-game — `InputMask`, and later the catalog
and scoring logic. That split is the design: anything touching `sdk` / `re` /
`imgui` needs the game, so everything that does not is kept out of those files
deliberately.

The notation fixture is generated from the shipped `command_display` catalog
rather than typed by hand. A notation the parser cannot handle is a move that
disappears from the Move Catalog without any error, which would show up much
later as "these links do not work".

---

## Layout

```
reframework/autorun/
  ComboExplorer.lua                  entry point, mode 6, panel

  func/ComboExplorer/core/           PURE - no sdk, unit-tested on the dev machine
    Provenance.lua                   the register of what has not been measured yet
    InputMask.lua                    notation <-> bitmask, given a button profile
    DamageTracker.lua                two damage measurements and whether they agree
    ProbeA.lua                       segments a snapshot stream into combos
    ClockStats.lua                   per-frame clock accounting

  func/ComboExplorer/runtime/        GAME - the only files that touch sdk
    GameAdapter.lua                  every read, in one place
    Clock.lua                        the frame anchor and its callback registry
    Config.lua                       preferences and artifact writing

reframework/data/ComboExplorer_data/
  Config.json                        preferences
  calibration/latest.json            measured values, once they exist
  diagnostics/                       probe reports (committed back)
scripts/install-dev.ps1              repo -> game folder sync
tools/                               dev-machine generators and runners
tests/lua/                           unit tests (314 assertions)
docs/ComboExplorer/                  the plan and the work split
```

`core/Provenance.lua` is the one to read first. It lists everything nobody has
measured yet, why each guess is only a guess, and what breaks if it is wrong.
Everything else in the Explorer reads its unknowns from there rather than
spelling them out, which is what stops a wrong guess from becoming a dataset.

---

## Licence

MIT, inherited from SF6_Tools — `Copyright (c) 2026 Wael Hadjmouldi`. See
[`LICENSE`](../../LICENSE); it stays with any copy.
