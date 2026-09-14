# Route plan - Terry / modern - starter-chu

Generated 2026-09-14T13:02:20Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

4 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 699 (search complete: true)

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| starter_button | M | 699 | 643 | 56 | 0 |

- routes satisfying every condition: 56
- of those, through a pair the logs rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 中 → 236236 + 强 | MP → 236236+P | 4700 | 4700 | SA 1, drive >=0 (1 unknown) | 8.4 | low | 0/1 pairs verified |
| 2 | 2 | 2 + 中 → 236236 + 强 | 2+MK → 236236+P | 4500 | 4500 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs verified |
| 3 | 3 | 中 → 2 + SP + 强 | MP → 236236+P | 3900 | 4700 | SA 1, drive >=0 (1 unknown) | 6.0 | low | 0/1 pairs verified |
| 4 | 4 | 2 + 中 → 2 + SP + 强 | 2+MK → 236236+P | 3700 | 4500 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs verified |
| 5 | 5 | 中 → 214214 + 中 | MP → 214214+P | 3300 | 3300 | SA 1, drive >=0 (1 unknown) | 8.4 | high | 0/1 pairs verified |
| 6 | 6 | 2 + 中 → 214214 + 中 | 2+MK → 214214+P | 3100 | 3100 | SA 1, drive >=0 (1 unknown) | 8.9 | high | 0/1 pairs verified |
| 7 | 7 | 中 → 4 + SP + 强 | MP → 214214+P | 2780 | 3300 | SA 1, drive >=0 (1 unknown) | 6.0 | high | 0/1 pairs verified |
| 8 | 8 | 中 → 236236 + 弱 | MP → 236236+K | 2700 | 2700 | SA 1, drive >=0 (1 unknown) | 8.4 | high | 0/1 pairs verified |
| 9 | 9 | 2 + 中 → 4 + SP + 强 | 2+MK → 214214+P | 2580 | 3100 | SA 1, drive >=0 (1 unknown) | 6.5 | high | 0/1 pairs verified |
| 10 | 10 | 2 + 中 → 236236 + 弱 | 2+MK → 236236+K | 2500 | 2500 | SA 1, drive >=0 (1 unknown) | 8.9 | high | 0/1 pairs verified |
| 11 | 11 | 中 → SP + 强 | MP → 236236+K | 2300 | 2700 | SA 1, drive >=0 (1 unknown) | 5.5 | high | 0/1 pairs verified |
| 12 | 12 | 中 → 214 + 中 + 强 | MP → 214+MP+HP | 2100 | 2100 | drive 20000 | 6.2 | high | 0/1 pairs verified |
| 13 | 13 | 2 + 中 → SP + 强 | 2+MK → 236236+K | 2100 | 2500 | SA 1, drive >=0 (1 unknown) | 6.0 | high | 0/1 pairs verified |
| 14 | 14 | 中 → 214 + 强 | MP → 214+HP | 1900 | 1900 | drive 0 | 5.7 | high | 0/1 pairs verified |
| 15 | 15 | 2 + 中 → 214 + 中 + 强 | 2+MK → 214+MP+HP | 1900 | 1900 | drive 20000 | 6.7 | high | 0/1 pairs verified |
| 16 | 16 | 中 → 214 + 中 | MP → 214+MP | 1700 | 1700 | drive 0 | 5.7 | high | 0/1 pairs verified |
| 17 | 17 | 中 → 623 + 弱 | MP → 623+LP | 1700 | 1700 | drive 0 | 5.7 | high | 0/1 pairs verified |
| 18 | 18 | 2 + 中 → 214 + 强 | 2+MK → 214+HP | 1700 | 1700 | drive 0 | 6.2 | high | 0/1 pairs verified |
| 19 | 19 | 中 → 4 + AUTO + SP | MP → 214+KK | 1660 | 1900 | OD 1, drive 20000 | 6.0 | high | 0/1 pairs verified |
| 20 | 20 | 中 → 236 + 强 | MP → 236+HP | 1600 | 1600 | drive 0 | 5.7 | high | 0/1 pairs verified |

## Pairs to sweep: 20

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 409 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 中 → 236236 + 强 | `604:manual->1230:manual` | 1 | untested | single | low | -6 |
| 2 | 2 + 中 → 236236 + 强 | `635:manual->1230:manual` | 2 | untested | single | low | -10 |
| 3 | 中 → 2 + SP + 强 | `604:manual->1230:simple` | 3 | untested | single | low | -6 |
| 4 | 2 + 中 → 2 + SP + 强 | `635:manual->1230:simple` | 4 | untested | single | low | -10 |
| 5 | 中 → 214214 + 中 | `604:manual->1210:manual` | 5 | untested | single | high | -11 |
| 6 | 2 + 中 → 214214 + 中 | `635:manual->1210:manual` | 6 | untested | single | high | -15 |
| 7 | 中 → 4 + SP + 强 | `604:manual->1210:simple` | 7 | untested | single | high | -11 |
| 8 | 中 → 236236 + 弱 | `604:manual->1200:manual` | 8 | untested | single | high | -5 |
| 9 | 2 + 中 → 4 + SP + 强 | `635:manual->1210:simple` | 9 | untested | single | high | -15 |
| 10 | 2 + 中 → 236236 + 弱 | `635:manual->1200:manual` | 10 | untested | single | high | -9 |
| 11 | 中 → SP + 强 | `604:manual->1200:simple` | 11 | untested | single | high | -5 |
| 12 | 中 → 214 + 中 + 强 | `604:manual->934:manual` | 12 | untested | single | high | -17 |
| 13 | 2 + 中 → SP + 强 | `635:manual->1200:simple` | 13 | untested | single | high | -9 |
| 14 | 中 → 214 + 强 | `604:manual->933:manual` | 14 | untested | single | high | -21 |
| 15 | 2 + 中 → 214 + 中 + 强 | `635:manual->934:manual` | 15 | untested | single | high | -21 |
| 16 | 中 → 214 + 中 | `604:manual->931:manual` | 16 | untested | single | high | -12 |
| 17 | 中 → 623 + 弱 | `604:manual->940:manual` | 17 | untested | single | high | -3 |
| 18 | 2 + 中 → 214 + 强 | `635:manual->933:manual` | 18 | untested | single | high | -25 |
| 19 | 中 → 4 + AUTO + SP | `604:manual->958:simple` | 19 | untested | single | high | -18 |
| 20 | 中 → 236 + 强 | `604:manual->902:manual` | 20 | untested | single | high | -27 |

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

- reframework/data/ComboExplorer_data/worklist/terry-modern-plan-starter-chu.json  (20 pairs, 11562 bytes)
- docs/ComboExplorer/plans/terry-modern-starter-chu.md
