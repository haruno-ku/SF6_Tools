# Route plan - JP / modern - starter-chu

Generated 2026-09-14T12:59:28Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

31 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 1202 (search complete: false)
  - the beam dropped 1483 partial routes and 0 routes were not emitted, so a route
    satisfying these conditions may be missing

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| starter_button | M | 1202 | 1077 | 125 | 0 |

- routes satisfying every condition: 125
- of those, through a pair the logs rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 中 → 236236 + 强 | MK → 236236+K | 4600 | 4600 | SA 1, drive >=0 (1 unknown) | 8.4 | low | 0/1 pairs verified |
| 2 | 2 | 4 + 中 → 236236 + 强 | 4+MP → 236236+K | 4500 | 4500 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs verified |
| 3 | 3 | 中 → 2 + SP + 强 | MK → 236236+K | 3800 | 4600 | SA 1, drive >=0 (1 unknown) | 6.0 | low | 0/1 pairs verified |
| 4 | 4 | 4 + 中 → 2 + SP + 强 | 4+MP → 236236+K | 3700 | 4500 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs verified |
| 5 | 5 | 中 → 4 + AUTO + SP | MK → 214+KK | 2680 | 3200 | OD 1, drive 20000 | 6.0 | high | 0/1 pairs verified |
| 6 | 6 | 4 + 中 → 4 + AUTO + SP | 4+MP → 214+KK | 2580 | 3100 | OD 1, drive 20000 | 6.5 | high | 0/1 pairs verified |
| 7 | 7 | 4 + 中 → 2 + 弱 → 4 + AUTO + SP | 4+MP → 2+LP → 214+KK | 2464 | 3400 | OD 1, drive 20000 | 8.5 | medium | 0/2 pairs verified |
| 8 | 8 | 中 → 4 + SP | MK → 214+LK | 2040 | 2400 | drive 0 | 5.5 | high | 0/1 pairs verified |
| 9 | 9 | 4 + 中 → 2 + 弱 → 4 + SP | 4+MP → 2+LP → 214+LK | 1952 | 2600 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 10 | 10 | 4 + 中 → 4 + SP | 4+MP → 214+LK | 1940 | 2300 | drive 0 | 6.0 | high | 0/1 pairs verified |
| 11 | 11 | 中 → 236 + 中 | MK → 236+MK | 1600 | 1600 | drive 0 | 5.7 | high | 0/1 pairs verified |
| 12 | 12 | 中 → 236 + 强 | MK → 236+HK | 1600 | 1600 | drive 0 | 5.7 | high | 0/1 pairs verified |
| 13 | 13 | 4 + 中 → 2 + 弱 → 236 + 中 | 4+MP → 2+LP → 236+MK | 1600 | 1800 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 14 | 14 | 4 + 中 → 2 + 弱 → 236 + 强 | 4+MP → 2+LP → 236+HK | 1600 | 1800 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 15 | 15 | 4 + 中 → 2 + 弱 → 3 + 强 | 4+MP → 2+LP → 3+HP | 1520 | 1700 | drive 0 | 6.0 | medium | 0/2 pairs verified |
| 16 | 16 | 4 + 中 → 236 + 中 | 4+MP → 236+MK | 1500 | 1500 | drive 0 | 6.2 | high | 0/1 pairs verified |
| 17 | 17 | 4 + 中 → 236 + 强 | 4+MP → 236+HK | 1500 | 1500 | drive 0 | 6.2 | high | 0/1 pairs verified |
| 18 | 18 | 4 + 中 → 2 + 弱 → 强 | 4+MP → 2+LP → HK | 1440 | 1600 | drive 0 | 5.5 | medium | 0/2 pairs verified |
| 19 | 19 | 4 + 中 → 2 + 弱 → 2 + 强 | 4+MP → 2+LP → 2+HP | 1440 | 1600 | drive 0 | 6.0 | medium | 0/2 pairs verified |
| 20 | 20 | 4 + 中 → 2 + 弱 → 214 + 弱 | 4+MP → 2+LP → 214+LP | 1440 | 1600 | drive 0 | 8.2 | medium | 0/2 pairs verified |

## Pairs to sweep: 21

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 631 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 中 → 236236 + 强 | `606:manual->1235:manual` | 1 | untested | single | low | -15 |
| 2 | 4 + 中 → 236236 + 强 | `637:manual->1235:manual` | 2 | untested | single | low | -13 |
| 3 | 中 → 2 + SP + 强 | `606:manual->1235:simple` | 3 | untested | single | low | -15 |
| 4 | 4 + 中 → 2 + SP + 强 | `637:manual->1235:simple` | 4 | untested | single | low | -13 |
| 5 | 中 → 4 + AUTO + SP | `606:manual->1016:simple` | 5 | untested | single | high | -23 |
| 6 | 4 + 中 → 4 + AUTO + SP | `637:manual->1016:simple` | 6 | untested | single | high | -21 |
| 7 | 4 + 中 → 2 + 弱 | `637:manual->613:manual` | 7, 9, 13, 14, 15, 18, 19, 20 | untested | single | medium | 1 |
| 8 | 2 + 弱 → 4 + AUTO + SP | `613:manual->1016:simple` | 7 | untested | single | high | -22 |
| 9 | 中 → 4 + SP | `606:manual->1010:simple` | 8 | untested | single | high | -23 |
| 10 | 2 + 弱 → 4 + SP | `613:manual->1010:simple` | 9 | untested | single | high | -22 |
| 11 | 4 + 中 → 4 + SP | `637:manual->1010:simple` | 10 | untested | single | high | -21 |
| 12 | 中 → 236 + 中 | `606:manual->972:manual` | 11 | untested | single | high | -11 |
| 13 | 中 → 236 + 强 | `606:manual->973:manual` | 12 | untested | single | high | -11 |
| 14 | 2 + 弱 → 236 + 中 | `613:manual->972:manual` | 13 | untested | single | high | -10 |
| 15 | 2 + 弱 → 236 + 强 | `613:manual->973:manual` | 14 | untested | single | high | -10 |
| 16 | 2 + 弱 → 3 + 强 | `613:manual->640:manual` | 15 | untested | single | medium | -12 |
| 17 | 4 + 中 → 236 + 中 | `637:manual->972:manual` | 16 | untested | single | high | -9 |
| 18 | 4 + 中 → 236 + 强 | `637:manual->973:manual` | 17 | untested | single | high | -9 |
| 19 | 2 + 弱 → 强 | `613:manual->607:manual` | 18 | untested | single | medium | -8 |
| 20 | 2 + 弱 → 2 + 强 | `613:manual->617:manual` | 19 | untested | single | medium | -5 |
| 21 | 2 + 弱 → 214 + 弱 | `613:manual->915:manual` | 20 | untested | single | high | -46 |

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

- reframework/data/ComboExplorer_data/worklist/jp-modern-plan-starter-chu.json  (21 pairs, 12123 bytes)
- docs/ComboExplorer/plans/jp-modern-starter-chu.md
