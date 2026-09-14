# Route plan - Ed / modern - starter-chu

Generated 2026-09-14T13:01:30Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

69 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 1245 (search complete: true)

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| starter_button | M | 1245 | 1130 | 115 | 0 |

- routes satisfying every condition: 115
- of those, through a pair the logs rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 中 → 236236 + 强 | MK → 236236+P | 4600 | 4600 | SA 1, drive >=0 (1 unknown) | 8.4 | low | 0/1 pairs verified |
| 2 | 2 | 2 + 中 → 236236 + 强 | 2+MP → 236236+P | 4500 | 4500 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs verified |
| 3 | 3 | 中 → 2 + SP + 强 | MK → 236236+P | 3800 | 4600 | SA 1, drive >=0 (1 unknown) | 6.0 | low | 0/1 pairs verified |
| 4 | 4 | 2 + 中 → 2 + SP + 强 | 2+MP → 236236+P | 3700 | 4500 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs verified |
| 5 | 5 | 中 → 623 + 强 | MK → 623+HP | 1800 | 1800 | drive 0 | 5.7 | high | 0/1 pairs verified |
| 6 | 6 | 2 + 中 → 623 + 强 | 2+MP → 623+HP | 1700 | 1700 | drive 0 | 6.2 | high | 0/1 pairs verified |
| 7 | 7 | 中 → 623 + 中 | MK → 623+MP | 1600 | 1600 | drive 0 | 5.7 | high | 0/1 pairs verified |
| 8 | 8 | 中 → 236 + 中 | MK → 236+MK | 1500 | 1500 | drive 0 | 5.7 | high | 0/1 pairs verified |
| 9 | 9 | 中 → 623 + 弱 | MK → 623+LP | 1500 | 1500 | drive 0 | 5.7 | high | 0/1 pairs verified |
| 10 | 10 | 2 + 中 → 623 + 中 | 2+MP → 623+MP | 1500 | 1500 | drive 0 | 6.2 | high | 0/1 pairs verified |
| 11 | 11 | 中 → 236 + 弱 | MK → 236+LK | 1400 | 1400 | drive 0 | 5.7 | high | 0/1 pairs verified |
| 12 | 12 | 中 → 236 + 强 | MK → 236+HK | 1400 | 1400 | drive 0 | 5.7 | high | 0/1 pairs verified |
| 13 | 13 | 2 + 中 → 236 + 中 | 2+MP → 236+MK | 1400 | 1400 | drive 0 | 6.2 | high | 0/1 pairs verified |
| 14 | 14 | 2 + 中 → 623 + 弱 | 2+MP → 623+LP | 1400 | 1400 | drive 0 | 6.2 | high | 0/1 pairs verified |
| 15 | 15 | 中 → 6 + SP | MK → 623+LP | 1320 | 1500 | drive 0 | 5.5 | high | 0/1 pairs verified |
| 16 | 16 | 2 + 中 → 236 + 弱 | 2+MP → 236+LK | 1300 | 1300 | drive 0 | 6.2 | high | 0/1 pairs verified |
| 17 | 17 | 2 + 中 → 236 + 强 | 2+MP → 236+HK | 1300 | 1300 | drive 0 | 6.2 | high | 0/1 pairs verified |
| 18 | 18 | 中 → 2 + SP | MK → 236+LK | 1240 | 1400 | drive 0 | 5.5 | high | 0/1 pairs verified |
| 19 | 19 | 中 → 6 + AUTO + SP | MK → 623+PP | 1240 | 1400 | OD 1, drive 20000 | 6.0 | high | 0/1 pairs verified |
| 20 | 20 | 2 + 中 → 6 + SP | 2+MP → 623+LP | 1220 | 1400 | drive 0 | 6.0 | high | 0/1 pairs verified |

## Pairs to sweep: 20

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 336 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 中 → 236236 + 强 | `618:manual->1224:manual` | 1 | untested | single | low | -10 |
| 2 | 2 + 中 → 236236 + 强 | `628:manual->1224:manual` | 2 | untested | single | low | -8 |
| 3 | 中 → 2 + SP + 强 | `618:manual->1224:simple` | 3 | untested | single | low | -10 |
| 4 | 2 + 中 → 2 + SP + 强 | `628:manual->1224:simple` | 4 | untested | single | low | -8 |
| 5 | 中 → 623 + 强 | `618:manual->975:manual` | 5 | untested | single | high | -16 |
| 6 | 2 + 中 → 623 + 强 | `628:manual->975:manual` | 6 | untested | single | high | -14 |
| 7 | 中 → 623 + 中 | `618:manual->974:manual` | 7 | untested | single | high | -14 |
| 8 | 中 → 236 + 中 | `618:manual->942:manual` | 8 | untested | single | high | -15 |
| 9 | 中 → 623 + 弱 | `618:manual->972:manual` | 9 | untested | single | high | -10 |
| 10 | 2 + 中 → 623 + 中 | `628:manual->974:manual` | 10 | untested | single | high | -12 |
| 11 | 中 → 236 + 弱 | `618:manual->934:manual` | 11 | untested | single | high | -11 |
| 12 | 中 → 236 + 强 | `618:manual->950:manual` | 12 | untested | single | high | -12 |
| 13 | 2 + 中 → 236 + 中 | `628:manual->942:manual` | 13 | untested | single | high | -13 |
| 14 | 2 + 中 → 623 + 弱 | `628:manual->972:manual` | 14 | untested | single | high | -8 |
| 15 | 中 → 6 + SP | `618:manual->972:simple` | 15 | untested | single | high | -10 |
| 16 | 2 + 中 → 236 + 弱 | `628:manual->934:manual` | 16 | untested | single | high | -9 |
| 17 | 2 + 中 → 236 + 强 | `628:manual->950:manual` | 17 | untested | single | high | -10 |
| 18 | 中 → 2 + SP | `618:manual->934:simple` | 18 | untested | single | high | -11 |
| 19 | 中 → 6 + AUTO + SP | `618:manual->976:simple` | 19 | untested | single | high | -13 |
| 20 | 2 + 中 → 6 + SP | `628:manual->972:simple` | 20 | untested | single | high | -8 |

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

- reframework/data/ComboExplorer_data/worklist/ed-modern-plan-starter-chu.json  (20 pairs, 11531 bytes)
- docs/ComboExplorer/plans/ed-modern-starter-chu.md
