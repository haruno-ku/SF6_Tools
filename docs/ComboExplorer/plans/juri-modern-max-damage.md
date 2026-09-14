# Route plan - Juri / modern - max-damage

Generated 2026-09-14T13:00:23Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

EVERY ROUTE HERE IS A THEORETICAL CANDIDATE. The ranking is a prediction from
the frame data. The worklist below is the smallest set of pairs that lets the
game say whether these routes connect.

## Conditions

- none: every route the search found
- sort: `scaled_damage`, top 20
- search: explore.lua's settings (normal,command_normal -> normal,command_normal,special,od_special,super, manual -> manual,simple, max 3 moves, beam 4000, collapse true)
- Drive Rush Cancel edges in the search: no (pass --drive-rush to route through them)
- demote routes through a rejected pair: yes

## Damage figure

Ordered on `offline_score.predicted_damage_scaled`, the combo-scaled prediction.

131 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 775 (search complete: false)
  - the beam dropped 15401 partial routes and 0 routes were not emitted, so a route
    satisfying these conditions may be missing

- routes satisfying every condition: 775
- of those, through a pair the logs rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 2 + 强 → 214214 + 强 | 2+HP → 214214+K | 4900 | 4900 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs verified |
| 2 | 2 | 3 + 强 → 214214 + 强 | 2+HK → 214214+K | 4900 | 4900 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs verified |
| 3 | 3 | 中 → 214214 + 强 | MP → 214214+K | 4600 | 4600 | SA 1, drive >=0 (1 unknown) | 8.4 | low | 0/1 pairs verified |
| 4 | 4 | 2 + 中 → 214214 + 强 | 2+MK → 214214+K | 4500 | 4500 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs verified |
| 5 | 5 | 6 + 强 → 214214 + 强 | 6+HP → 214214+K | 4500 | 4500 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs verified |
| 6 | 6 | 4 + 强 → 214214 + 强 | 4+HK → 214214+K | 4400 | 4400 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs verified |
| 7 | 7 | 2 + 强 → 2 + SP + 强 | 2+HP → 214214+K | 4100 | 4900 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs verified |
| 8 | 8 | 3 + 强 → 2 + SP + 强 | 2+HK → 214214+K | 4100 | 4900 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs verified |
| 9 | 9 | 中 → 2 + SP + 强 | MP → 214214+K | 3800 | 4600 | SA 1, drive >=0 (1 unknown) | 6.0 | low | 0/1 pairs verified |
| 10 | 10 | 2 + 中 → 2 + SP + 强 | 2+MK → 214214+K | 3700 | 4500 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs verified |
| 11 | 11 | 6 + 强 → 2 + SP + 强 | 6+HP → 214214+K | 3700 | 4500 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs verified |
| 12 | 12 | 4 + 强 → 2 + SP + 强 | 4+HK → 214214+K | 3600 | 4400 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs verified |
| 13 | 13 | 弱 → 214214 + 强 | LP → 214214+K | 3500 | 4300 | SA 1, drive >=0 (1 unknown) | 8.4 | low | 0/1 pairs verified |
| 14 | 14 | 2 + 弱 → 214214 + 强 | 2+LP → 214214+K | 3500 | 4300 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs verified |
| 15 | 15 | 3 + 强 → 2 + 强 → 236236 + 弱 | 2+HK → 2+HP → 236236+K | 3240 | 3600 | SA 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs verified |
| 16 | 16 | 3 + 强 → 3 + 强 → 236236 + 弱 | 2+HK → 2+HK → 236236+K | 3240 | 3600 | SA 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs verified |
| 17 | 17 | 3 + 强 → 2 + 强 → SP + 强 | 2+HK → 2+HP → 236236+K | 2952 | 3600 | SA 1, drive >=0 (1 unknown) | 8.0 | medium | 0/2 pairs verified |
| 18 | 18 | 3 + 强 → 3 + 强 → SP + 强 | 2+HK → 2+HK → 236236+K | 2952 | 3600 | SA 1, drive >=0 (1 unknown) | 8.0 | medium | 0/2 pairs verified |
| 19 | 19 | 3 + 强 → 中 → 236236 + 弱 | 2+HK → MP → 236236+K | 2940 | 3300 | SA 1, drive >=0 (1 unknown) | 10.4 | medium | 0/2 pairs verified |
| 20 | 20 | 弱 → 2 + SP + 强 | LP → 214214+K | 2860 | 4300 | SA 1, drive >=0 (1 unknown) | 6.0 | low | 0/1 pairs verified |

## Pairs to sweep: 23

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 2388 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 2 + 强 → 214214 + 强 | `626:manual->1221:manual` | 1 | untested | single | low | -7 |
| 2 | 3 + 强 → 214214 + 强 | `637:manual->1221:manual` | 2 | untested | single | low | 28 |
| 3 | 中 → 214214 + 强 | `603:manual->1221:manual` | 3 | untested | single | low | -3 |
| 4 | 2 + 中 → 214214 + 强 | `634:manual->1221:manual` | 4 | untested | single | low | -9 |
| 5 | 6 + 强 → 214214 + 强 | `674:manual->1221:manual` | 5 | untested | single | low | -8 |
| 6 | 4 + 强 → 214214 + 强 | `677:manual->1221:manual` | 6 | untested | single | low | -7 |
| 7 | 2 + 强 → 2 + SP + 强 | `626:manual->1221:simple` | 7 | untested | single | low | -7 |
| 8 | 3 + 强 → 2 + SP + 强 | `637:manual->1221:simple` | 8 | untested | single | low | 28 |
| 9 | 中 → 2 + SP + 强 | `603:manual->1221:simple` | 9 | untested | single | low | -3 |
| 10 | 2 + 中 → 2 + SP + 强 | `634:manual->1221:simple` | 10 | untested | single | low | -9 |
| 11 | 6 + 强 → 2 + SP + 强 | `674:manual->1221:simple` | 11 | untested | single | low | -8 |
| 12 | 4 + 强 → 2 + SP + 强 | `677:manual->1221:simple` | 12 | untested | single | low | -7 |
| 13 | 弱 → 214214 + 强 | `602:manual->1221:manual` | 13 | untested | single | low | -5 |
| 14 | 2 + 弱 → 214214 + 强 | `618:manual->1221:manual` | 14 | untested | single | low | -6 |
| 15 | 3 + 强 → 2 + 强 | `637:manual->626:manual` | 15, 17 | untested | single | medium | 30 |
| 16 | 2 + 强 → 236236 + 弱 | `626:manual->1200:manual` | 15 | untested | single | high | -4 |
| 17 | 3 + 强 → 3 + 强 | `637:manual->638:manual` | 16, 18 | untested | single | medium | 28 |
| 18 | 3 + 强 → 236236 + 弱 | `638:manual->1200:manual` | 16 | untested | single | medium | 31 |
| 19 | 2 + 强 → SP + 强 | `626:manual->1200:simple` | 17 | untested | single | high | -4 |
| 20 | 3 + 强 → SP + 强 | `638:manual->1200:simple` | 18 | untested | single | medium | 31 |
| 21 | 3 + 强 → 中 | `637:manual->603:manual` | 19 | untested | single | medium | 32 |
| 22 | 中 → 236236 + 弱 | `603:manual->1200:manual` | 19 | untested | single | high | 0 |
| 23 | 弱 → 2 + SP + 强 | `602:manual->1221:simple` | 20 | untested | single | low | -5 |

## Already known: 0

Nothing these routes need has been answered yet.

## Where the known statuses come from

- trial logs read: 0 (0 records for modern)
- pairs answered: 0 across 0 cohort(s) - verified 0, rejected 0, pending 0
- route runs (combos, not pairs): 0 rows
- combos confirmed in the logs: 0

A pair measured in several cohorts is `verified` if any cohort linked it, else
`rejected` if any answered no, else `pending`. `(mixed)` marks a pair one cohort
linked and another rejected.

`as <key>` means the answer was recorded under another action id with the same
buttons. The catalog lists Modern 弱 as 601, 602 and 611; the search keeps one of
them, and the sweep folds every pair onto the id the calibration measured (611)
before pressing it, so that is the id its trials carry.

## Running it

Copy the worklist to the game machine (`scripts/install-dev.ps1` syncs
reframework/data), then pick `plan: max-damage` in the SWEEP panel's worklist list
(REFRESH if the panel was already open) and START SWEEP. It writes to the same
trial log as the full sweep, so pairs the full sweep already answered under the
same calibration and conditions are skipped, and the other way round.

## Written

- reframework/data/ComboExplorer_data/worklist/juri-modern-plan-max-damage.json  (23 pairs, 12901 bytes)
- docs/ComboExplorer/plans/juri-modern-max-damage.md
