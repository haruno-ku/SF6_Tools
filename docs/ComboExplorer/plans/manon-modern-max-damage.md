# Route plan - Manon / modern - max-damage

Generated 2026-09-14T12:59:17Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

13 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 599 (search complete: false)
  - the beam dropped 900 partial routes and 0 routes were not emitted, so a route
    satisfying these conditions may be missing

- routes satisfying every condition: 599
- of those, through a pair the logs rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 3 + 强 → 236236 + 强 | 2+HK → 236236+P | 4900 | 4900 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs verified |
| 2 | 2 | 强 → 236236 + 强 | HP → 236236+P | 4800 | 4800 | SA 1, drive >=0 (1 unknown) | 8.4 | low | 0/1 pairs verified |
| 3 | 3 | 4 + 强 → 236236 + 强 | 4+HP → 236236+P | 4800 | 4800 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs verified |
| 4 | 4 | 中 → 236236 + 强 | MP → 236236+P | 4600 | 4600 | SA 1, drive >=0 (1 unknown) | 8.4 | low | 0/1 pairs verified |
| 5 | 5 | 3 + 强 → 2 + SP + 强 | 2+HK → 236236+P | 4100 | 4900 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs verified |
| 6 | 6 | 强 → 2 + SP + 强 | HP → 236236+P | 4000 | 4800 | SA 1, drive >=0 (1 unknown) | 6.0 | low | 0/1 pairs verified |
| 7 | 7 | 4 + 强 → 2 + SP + 强 | 4+HP → 236236+P | 4000 | 4800 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs verified |
| 8 | 8 | 3 + 强 → 强 → 214214 + 中 | 2+HK → HP → 214214+K | 3940 | 4500 | SA 1, drive >=0 (1 unknown) | 10.4 | medium | 0/2 pairs verified |
| 9 | 9 | 3 + 强 → 4 + 强 → 214214 + 中 | 2+HK → 4+HP → 214214+K | 3940 | 4500 | SA 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs verified |
| 10 | 10 | 中 → 2 + SP + 强 | MP → 236236+P | 3800 | 4600 | SA 1, drive >=0 (1 unknown) | 6.0 | low | 0/1 pairs verified |
| 11 | 11 | 3 + 强 → 中 → 214214 + 中 | 2+HK → MP → 214214+K | 3740 | 4300 | SA 1, drive >=0 (1 unknown) | 10.4 | medium | 0/2 pairs verified |
| 12 | 12 | 3 + 强 → 214214 + 中 | 2+HK → 214214+K | 3700 | 3700 | SA 1, drive >=0 (1 unknown) | 8.9 | medium | 0/1 pairs verified |
| 13 | 13 | 强 → 214214 + 中 | HP → 214214+K | 3600 | 3600 | SA 1, drive >=0 (1 unknown) | 8.4 | high | 0/1 pairs verified |
| 14 | 14 | 4 + 强 → 214214 + 中 | 4+HP → 214214+K | 3600 | 3600 | SA 1, drive >=0 (1 unknown) | 8.9 | high | 0/1 pairs verified |
| 15 | 15 | 弱 → 236236 + 强 | LP → 236236+P | 3500 | 4300 | SA 1, drive >=0 (1 unknown) | 8.4 | low | 0/1 pairs verified |
| 16 | 16 | 2 + 弱 → 236236 + 强 | 2+LP → 236236+P | 3500 | 4300 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs verified |
| 17 | 17 | 3 + 强 → 强 → 4 + SP + 强 | 2+HK → HP → 214214+K | 3492 | 4500 | SA 1, drive >=0 (1 unknown) | 8.0 | medium | 0/2 pairs verified |
| 18 | 18 | 3 + 强 → 4 + 强 → 4 + SP + 强 | 2+HK → 4+HP → 214214+K | 3492 | 4500 | SA 1, drive >=0 (1 unknown) | 8.5 | medium | 0/2 pairs verified |
| 19 | 19 | 3 + 强 → 弱 → 214214 + 中 | 2+HK → LP → 214214+K | 3440 | 4000 | SA 1, drive >=0 (1 unknown) | 10.4 | medium | 0/2 pairs verified |
| 20 | 20 | 3 + 强 → 2 + 弱 → 214214 + 中 | 2+HK → 2+LP → 214214+K | 3440 | 4000 | SA 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs verified |

## Pairs to sweep: 23

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 655 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 3 + 强 → 236236 + 强 | `643:manual->1215:manual` | 1 | untested | single | low | 23 |
| 2 | 强 → 236236 + 强 | `609:manual->1215:manual` | 2 | untested | single | low | -6 |
| 3 | 4 + 强 → 236236 + 强 | `665:manual->1215:manual` | 3 | untested | single | low | -3 |
| 4 | 中 → 236236 + 强 | `605:manual->1215:manual` | 4 | untested | single | low | -4 |
| 5 | 3 + 强 → 2 + SP + 强 | `643:manual->1215:simple` | 5 | untested | single | low | 23 |
| 6 | 强 → 2 + SP + 强 | `609:manual->1215:simple` | 6 | untested | single | low | -6 |
| 7 | 4 + 强 → 2 + SP + 强 | `665:manual->1215:simple` | 7 | untested | single | low | -3 |
| 8 | 3 + 强 → 强 | `643:manual->609:manual` | 8, 17 | untested | single | medium | 19 |
| 9 | 强 → 214214 + 中 | `609:manual->1210:manual` | 8, 13 | untested | single | high | -7 |
| 10 | 3 + 强 → 4 + 强 | `643:manual->665:manual` | 9, 18 | untested | single | medium | 21 |
| 11 | 4 + 强 → 214214 + 中 | `665:manual->1210:manual` | 9, 14 | untested | single | high | -4 |
| 12 | 中 → 2 + SP + 强 | `605:manual->1215:simple` | 10 | untested | single | low | -4 |
| 13 | 3 + 强 → 中 | `643:manual->605:manual` | 11 | untested | single | medium | 22 |
| 14 | 中 → 214214 + 中 | `605:manual->1210:manual` | 11 | untested | single | high | -5 |
| 15 | 3 + 强 → 214214 + 中 | `643:manual->1210:manual` | 12 | untested | single | medium | 22 |
| 16 | 弱 → 236236 + 强 | `600:manual->1215:manual` | 15 | untested | single | low | -2 |
| 17 | 2 + 弱 → 236236 + 强 | `625:manual->1215:manual` | 16 | untested | single | low | -3 |
| 18 | 强 → 4 + SP + 强 | `609:manual->1210:simple` | 17 | untested | single | high | -7 |
| 19 | 4 + 强 → 4 + SP + 强 | `665:manual->1210:simple` | 18 | untested | single | high | -4 |
| 20 | 3 + 强 → 弱 | `643:manual->600:manual` | 19 | untested | single | medium | 25 |
| 21 | 弱 → 214214 + 中 | `600:manual->1210:manual` | 19 | untested | single | high | -3 |
| 22 | 3 + 强 → 2 + 弱 | `643:manual->625:manual` | 20 | untested | single | medium | 25 |
| 23 | 2 + 弱 → 214214 + 中 | `625:manual->1210:manual` | 20 | untested | single | high | -4 |

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

- reframework/data/ComboExplorer_data/worklist/manon-modern-plan-max-damage.json  (23 pairs, 12858 bytes)
- docs/ComboExplorer/plans/manon-modern-max-damage.md
