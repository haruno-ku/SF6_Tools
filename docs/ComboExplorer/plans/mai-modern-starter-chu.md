# Route plan - Mai / modern - starter-chu

Generated 2026-09-14T13:02:41Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 454 (search complete: true)

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| starter_button | M | 454 | 366 | 88 | 0 |

- routes satisfying every condition: 88
- of those, through a pair the logs rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 2 + 中 → 214214 + 强 | 2+MK → 214214+P | 4500 | 4500 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs verified |
| 2 | 2 | 中 → 弱 → 214214 + 强 | MK → LK → 214214+P | 4200 | 5000 | SA 1, drive >=0 (1 unknown) | 9.9 | low | 0/2 pairs verified |
| 3 | 3 | 中 → 2 + 弱 → 214214 + 强 | MK → 2+LP → 214214+P | 4200 | 5000 | SA 1, drive >=0 (1 unknown) | 10.4 | low | 0/2 pairs verified |
| 4 | 4 | 2 + 中 → 2 + SP + 强 | 2+MK → 214214+P | 3700 | 4500 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs verified |
| 5 | 5 | 中 → 弱 → 2 + SP + 强 | MK → LK → 214214+P | 3560 | 5000 | SA 1, drive >=0 (1 unknown) | 7.5 | low | 0/2 pairs verified |
| 6 | 6 | 中 → 2 + 弱 → 2 + SP + 强 | MK → 2+LP → 214214+P | 3560 | 5000 | SA 1, drive >=0 (1 unknown) | 8.0 | low | 0/2 pairs verified |
| 7 | 7 | 中 → 2 + 弱 → 强 | MK → 2+LP → HK | 1720 | 1900 | drive 0 | 5.0 | medium | 0/2 pairs verified |
| 8 | 8 | 中 → 2 + 弱 → 3 + 强 | MK → 2+LP → 2+HK | 1720 | 1900 | drive 0 | 5.5 | medium | 0/2 pairs verified |
| 9 | 9 | 中 → 弱 → 214 + 弱 | MK → LK → 214+LP | 1640 | 1800 | drive 0 | 7.2 | low | 0/2 pairs verified |
| 10 | 10 | 中 → 2 + 弱 → 214 + 弱 | MK → 2+LP → 214+LP | 1640 | 1800 | drive 0 | 7.7 | low | 0/2 pairs verified |
| 11 | 11 | 中 → 2 + 弱 → 4 + 强 | MK → 2+LP → 4+HK | 1640 | 1800 | drive 0 | 5.5 | medium | 0/2 pairs verified |
| 12 | 12 | 中 → 2 + 弱 → 中 | MK → 2+LP → MK | 1560 | 1700 | drive 0 | 5.0 | medium | 0/2 pairs verified |
| 13 | 13 | 中 → 弱 → 4 + SP | MK → LK → 214+LP | 1512 | 1800 | drive 0 | 7.0 | low | 0/2 pairs verified |
| 14 | 14 | 中 → 弱 → 6 + AUTO + SP | MK → LK → 623+KK | 1512 | 1800 | OD 1, drive 20000 | 7.5 | low | 0/2 pairs verified |
| 15 | 15 | 中 → 2 + 弱 → 4 + SP | MK → 2+LP → 214+LP | 1512 | 1800 | drive 0 | 7.5 | low | 0/2 pairs verified |
| 16 | 16 | 中 → 2 + 弱 → 6 + AUTO + SP | MK → 2+LP → 623+KK | 1512 | 1800 | OD 1, drive 20000 | 8.0 | low | 0/2 pairs verified |
| 17 | 17 | 中 → 弱 → 623 + 强 | MK → LK → 623+HK | 1480 | 1600 | drive 0 | 7.2 | low | 0/2 pairs verified |
| 18 | 18 | 中 → 2 + 弱 → 623 + 强 | MK → 2+LP → 623+HK | 1480 | 1600 | drive 0 | 7.7 | low | 0/2 pairs verified |
| 19 | 19 | 中 → 2 + 弱 → 6 + 中 | MK → 2+LP → 6+MP | 1480 | 1600 | drive 0 | 5.5 | medium | 0/2 pairs verified |
| 20 | 20 | 中 → 弱 → 623 + 中 | MK → LK → 623+MK | 1400 | 1500 | drive 0 | 7.2 | low | 0/2 pairs verified |

## Pairs to sweep: 22

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 519 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 2 + 中 → 214214 + 强 | `623:manual->1233:manual` | 1 | untested | single | low | -12 |
| 2 | 中 → 弱 | `610:manual->606:manual` | 2, 5, 9, 13, 14, 17, 20 | untested | single | medium | 1 |
| 3 | 弱 → 214214 + 强 | `606:manual->1233:manual` | 2 | untested | single | low | -9 |
| 4 | 中 → 2 + 弱 | `610:manual->613:manual` | 3, 6, 7, 8, 10, 11, 12, 15, 16, 18, 19 | untested | single | medium | 1 |
| 5 | 2 + 弱 → 214214 + 强 | `613:manual->1233:manual` | 3 | untested | single | low | -6 |
| 6 | 2 + 中 → 2 + SP + 强 | `623:manual->1233:simple` | 4 | untested | single | low | -12 |
| 7 | 弱 → 2 + SP + 强 | `606:manual->1233:simple` | 5 | untested | single | low | -9 |
| 8 | 2 + 弱 → 2 + SP + 强 | `613:manual->1233:simple` | 6 | untested | single | low | -6 |
| 9 | 2 + 弱 → 强 | `613:manual->611:manual` | 7 | untested | single | medium | -10 |
| 10 | 2 + 弱 → 3 + 强 | `613:manual->624:manual` | 8 | untested | single | medium | -5 |
| 11 | 弱 → 214 + 弱 | `606:manual->1024:manual` | 9 | untested | single | low | -13 |
| 12 | 2 + 弱 → 214 + 弱 | `613:manual->1024:manual` | 10 | untested | single | low | -10 |
| 13 | 2 + 弱 → 4 + 强 | `613:manual->643:manual` | 11 | untested | single | medium | -4 |
| 14 | 2 + 弱 → 中 | `613:manual->610:manual` | 12 | untested | single | medium | -5 |
| 15 | 弱 → 4 + SP | `606:manual->1024:simple` | 13 | untested | single | low | -13 |
| 16 | 弱 → 6 + AUTO + SP | `606:manual->1050:simple` | 14 | untested | single | low | -5 |
| 17 | 2 + 弱 → 4 + SP | `613:manual->1024:simple` | 15 | untested | single | low | -10 |
| 18 | 2 + 弱 → 6 + AUTO + SP | `613:manual->1050:simple` | 16 | untested | single | low | -2 |
| 19 | 弱 → 623 + 强 | `606:manual->1049:manual` | 17 | untested | single | low | -6 |
| 20 | 2 + 弱 → 623 + 强 | `613:manual->1049:manual` | 18 | untested | single | low | -3 |
| 21 | 2 + 弱 → 6 + 中 | `613:manual->651:manual` | 19 | untested | single | medium | -16 |
| 22 | 弱 → 623 + 中 | `606:manual->1048:manual` | 20 | untested | single | low | -5 |

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

- reframework/data/ComboExplorer_data/worklist/mai-modern-plan-starter-chu.json  (22 pairs, 12660 bytes)
- docs/ComboExplorer/plans/mai-modern-starter-chu.md
