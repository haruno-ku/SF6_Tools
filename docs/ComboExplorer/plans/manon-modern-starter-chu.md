# Route plan - Manon / modern - starter-chu

Generated 2026-09-14T12:59:32Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

EVERY ROUTE HERE IS A THEORETICAL CANDIDATE. The ranking is a prediction from
the frame data. The worklist below is the smallest set of pairs that lets the
game say whether these routes connect.

## Conditions

- `starter_button` = `M`
- sort: `scaled_damage`, top 20
- search: explore.lua's settings (normal,command_normal -> normal,command_normal,special,od_special,super, manual -> manual,simple, max 3 moves, beam 4000, collapse true)
- Drive Rush Cancel edges in the search: no (pass --drive-rush to route through them)
- demote routes through a rejected pair: yes

`starter_button` keeps a route whose first move has that button with ANY direction
(中 keeps 中, 2 + 中, 3 + 中, 6 + 中). `--starter-neutral` narrows it to no direction.

## Damage figure

Ordered on `offline_score.predicted_damage_scaled`, the combo-scaled prediction.

2 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 599 (search complete: false)
  - the beam dropped 900 partial routes and 0 routes were not emitted, so a route
    satisfying these conditions may be missing

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| starter_button | M | 599 | 512 | 87 | 0 |

- routes satisfying every condition: 87
- of those, through a pair the logs rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 中 → 236236 + 强 | MP → 236236+P | 4600 | 4600 | SA 1, drive >=0 (1 unknown) | 8.4 | low | 0/1 pairs verified |
| 2 | 2 | 中 → 2 + SP + 强 | MP → 236236+P | 3800 | 4600 | SA 1, drive >=0 (1 unknown) | 6.0 | low | 0/1 pairs verified |
| 3 | 3 | 中 → 214214 + 中 | MP → 214214+K | 3400 | 3400 | SA 1, drive >=0 (1 unknown) | 8.4 | high | 0/1 pairs verified |
| 4 | 4 | 2 + 中 → 弱 → 214214 + 中 | 2+MK → LP → 214214+K | 3140 | 3700 | SA 1, drive >=0 (1 unknown) | 10.4 | medium | 0/2 pairs verified |
| 5 | 5 | 2 + 中 → 2 + 弱 → 214214 + 中 | 2+MK → 2+LP → 214214+K | 3140 | 3700 | SA 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs verified |
| 6 | 6 | 中 → 4 + SP + 强 | MP → 214214+K | 2840 | 3400 | SA 1, drive >=0 (1 unknown) | 6.0 | high | 0/1 pairs verified |
| 7 | 7 | 2 + 中 → 弱 → 4 + SP + 强 | 2+MK → LP → 214214+K | 2692 | 3700 | SA 1, drive >=0 (1 unknown) | 8.0 | medium | 0/2 pairs verified |
| 8 | 8 | 2 + 中 → 2 + 弱 → 4 + SP + 强 | 2+MK → 2+LP → 214214+K | 2692 | 3700 | SA 1, drive >=0 (1 unknown) | 8.5 | medium | 0/2 pairs verified |
| 9 | 9 | 中 → 236236 + 弱 | MP → 236236+K | 2600 | 2600 | SA 1, drive >=0 (1 unknown) | 8.4 | high | 0/1 pairs verified |
| 10 | 10 | 中 → 63214 + 弱 | MP → 63214+LP | 2600 | 2600 | drive 0 | 7.5 | high | 0/1 pairs verified |
| 11 | 11 | 中 → 63214 + 中 | MP → 63214+MP | 2600 | 2600 | drive 0 | 7.5 | high | 0/1 pairs verified |
| 12 | 12 | 中 → 63214 + 强 | MP → 63214+HP | 2600 | 2600 | drive 0 | 7.5 | high | 0/1 pairs verified |
| 13 | 13 | 2 + 中 → 弱 → 236236 + 弱 | 2+MK → LP → 236236+K | 2500 | 2900 | SA 1, drive >=0 (1 unknown) | 10.4 | medium | 0/2 pairs verified |
| 14 | 14 | 2 + 中 → 弱 → 63214 + 弱 | 2+MK → LP → 63214+LP | 2500 | 2900 | drive 0 | 9.5 | medium | 0/2 pairs verified |
| 15 | 15 | 2 + 中 → 弱 → 63214 + 中 | 2+MK → LP → 63214+MP | 2500 | 2900 | drive 0 | 9.5 | medium | 0/2 pairs verified |
| 16 | 16 | 2 + 中 → 弱 → 63214 + 强 | 2+MK → LP → 63214+HP | 2500 | 2900 | drive 0 | 9.5 | medium | 0/2 pairs verified |
| 17 | 17 | 2 + 中 → 2 + 弱 → 236236 + 弱 | 2+MK → 2+LP → 236236+K | 2500 | 2900 | SA 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs verified |
| 18 | 18 | 2 + 中 → 2 + 弱 → 63214 + 弱 | 2+MK → 2+LP → 63214+LP | 2500 | 2900 | drive 0 | 10.0 | medium | 0/2 pairs verified |
| 19 | 19 | 2 + 中 → 2 + 弱 → 63214 + 中 | 2+MK → 2+LP → 63214+MP | 2500 | 2900 | drive 0 | 10.0 | medium | 0/2 pairs verified |
| 20 | 20 | 2 + 中 → 2 + 弱 → 63214 + 强 | 2+MK → 2+LP → 63214+HP | 2500 | 2900 | drive 0 | 10.0 | medium | 0/2 pairs verified |

## Pairs to sweep: 22

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 655 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 中 → 236236 + 强 | `605:manual->1215:manual` | 1 | untested | single | low | -4 |
| 2 | 中 → 2 + SP + 强 | `605:manual->1215:simple` | 2 | untested | single | low | -4 |
| 3 | 中 → 214214 + 中 | `605:manual->1210:manual` | 3 | untested | single | high | -5 |
| 4 | 2 + 中 → 弱 | `640:manual->600:manual` | 4, 7, 13, 14, 15, 16 | untested | single | medium | 0 |
| 5 | 弱 → 214214 + 中 | `600:manual->1210:manual` | 4 | untested | single | high | -3 |
| 6 | 2 + 中 → 2 + 弱 | `640:manual->625:manual` | 5, 8, 17, 18, 19, 20 | untested | single | medium | 0 |
| 7 | 2 + 弱 → 214214 + 中 | `625:manual->1210:manual` | 5 | untested | single | high | -4 |
| 8 | 中 → 4 + SP + 强 | `605:manual->1210:simple` | 6 | untested | single | high | -5 |
| 9 | 弱 → 4 + SP + 强 | `600:manual->1210:simple` | 7 | untested | single | high | -3 |
| 10 | 2 + 弱 → 4 + SP + 强 | `625:manual->1210:simple` | 8 | untested | single | high | -4 |
| 11 | 中 → 236236 + 弱 | `605:manual->1200:manual` | 9 | untested | single | high | -8 |
| 12 | 中 → 63214 + 弱 | `605:manual->900:manual` | 10 | untested | single | high | -8 |
| 13 | 中 → 63214 + 中 | `605:manual->901:manual` | 11 | untested | single | high | -6 |
| 14 | 中 → 63214 + 强 | `605:manual->902:manual` | 12 | untested | single | high | -3 |
| 15 | 弱 → 236236 + 弱 | `600:manual->1200:manual` | 13 | untested | single | high | -6 |
| 16 | 弱 → 63214 + 弱 | `600:manual->900:manual` | 14 | untested | single | high | -6 |
| 17 | 弱 → 63214 + 中 | `600:manual->901:manual` | 15 | untested | single | high | -4 |
| 18 | 弱 → 63214 + 强 | `600:manual->902:manual` | 16 | untested | single | high | -1 |
| 19 | 2 + 弱 → 236236 + 弱 | `625:manual->1200:manual` | 17 | untested | single | high | -7 |
| 20 | 2 + 弱 → 63214 + 弱 | `625:manual->900:manual` | 18 | untested | single | high | -7 |
| 21 | 2 + 弱 → 63214 + 中 | `625:manual->901:manual` | 19 | untested | single | high | -5 |
| 22 | 2 + 弱 → 63214 + 强 | `625:manual->902:manual` | 20 | untested | single | high | -2 |

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
reframework/data), then pick `plan: starter-chu` in the SWEEP panel's worklist list
(REFRESH if the panel was already open) and START SWEEP. It writes to the same
trial log as the full sweep, so pairs the full sweep already answered under the
same calibration and conditions are skipped, and the other way round.

## Written

- reframework/data/ComboExplorer_data/worklist/manon-modern-plan-starter-chu.json  (22 pairs, 12624 bytes)
- docs/ComboExplorer/plans/manon-modern-starter-chu.md
