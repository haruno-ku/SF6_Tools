# Route plan - EHonda / modern - starter-chu

Generated 2026-09-14T13:01:31Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

17 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 609 (search complete: true)

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| starter_button | M | 609 | 452 | 157 | 0 |

- routes satisfying every condition: 157
- of those, through a pair the logs rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 中 → 214214 + 强 | MP → 214214+P | 4700 | 4700 | SA 1, drive >=0 (1 unknown) | 8.4 | low | 0/1 pairs verified |
| 2 | 2 | 中 → 弱 → 214214 + 强 | MP → LP → 214214+P | 4200 | 5000 | SA 1, drive >=0 (1 unknown) | 9.9 | low | 0/2 pairs verified |
| 3 | 3 | 中 → 2 + 弱 → 214214 + 强 | MP → 2+LP → 214214+P | 4200 | 5000 | SA 1, drive >=0 (1 unknown) | 10.4 | low | 0/2 pairs verified |
| 4 | 4 | 2 + 中 → 弱 → 214214 + 强 | 2+MK → LP → 214214+P | 4000 | 4800 | SA 1, drive >=0 (1 unknown) | 10.4 | low | 0/2 pairs verified |
| 5 | 5 | 2 + 中 → 2 + 弱 → 214214 + 强 | 2+MK → 2+LP → 214214+P | 4000 | 4800 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs verified |
| 6 | 6 | 中 → 2 + SP + 强 | MP → 214214+P | 3900 | 4700 | SA 1, drive >=0 (1 unknown) | 6.0 | low | 0/1 pairs verified |
| 7 | 7 | 中 → 弱 → 2 + SP + 强 | MP → LP → 214214+P | 3560 | 5000 | SA 1, drive >=0 (1 unknown) | 7.5 | low | 0/2 pairs verified |
| 8 | 8 | 中 → 2 + 弱 → 2 + SP + 强 | MP → 2+LP → 214214+P | 3560 | 5000 | SA 1, drive >=0 (1 unknown) | 8.0 | low | 0/2 pairs verified |
| 9 | 9 | 中 → [4]646 + 中 | MP → [4]646+K | 3550 | 3550 | SA 1, drive >=0 (1 unknown) | 6.6 | high | 0/1 pairs verified |
| 10 | 10 | 2 + 中 → 弱 → 2 + SP + 强 | 2+MK → LP → 214214+P | 3360 | 4800 | SA 1, drive >=0 (1 unknown) | 8.0 | low | 0/2 pairs verified |
| 11 | 11 | 2 + 中 → 2 + 弱 → 2 + SP + 强 | 2+MK → 2+LP → 214214+P | 3360 | 4800 | SA 1, drive >=0 (1 unknown) | 8.5 | low | 0/2 pairs verified |
| 12 | 12 | 中 → 弱 → [4]646 + 中 | MP → LP → [4]646+K | 3280 | 3850 | SA 1, drive >=0 (1 unknown) | 8.1 | medium | 0/2 pairs verified |
| 13 | 13 | 中 → 2 + 弱 → [4]646 + 中 | MP → 2+LP → [4]646+K | 3280 | 3850 | SA 1, drive >=0 (1 unknown) | 8.6 | medium | 0/2 pairs verified |
| 14 | 14 | 2 + 中 → 弱 → [4]646 + 中 | 2+MK → LP → [4]646+K | 3080 | 3650 | SA 1, drive >=0 (1 unknown) | 8.6 | medium | 0/2 pairs verified |
| 15 | 15 | 2 + 中 → 2 + 弱 → [4]646 + 中 | 2+MK → 2+LP → [4]646+K | 3080 | 3650 | SA 1, drive >=0 (1 unknown) | 9.1 | medium | 0/2 pairs verified |
| 16 | 16 | 中 → [4] + SP + 强 | MP → [4]646+K | 2980 | 3550 | SA 1, drive >=0 (1 unknown) | 6.0 | high | 0/1 pairs verified |
| 17 | 17 | 中 → 2 + AUTO + SP | MP → 63214+KK | 2940 | 3500 | OD 1, drive 20000 | 6.0 | high | 0/1 pairs verified |
| 18 | 18 | 中 → 弱 → [4] + SP + 强 | MP → LP → [4]646+K | 2824 | 3850 | SA 1, drive >=0 (1 unknown) | 7.5 | medium | 0/2 pairs verified |
| 19 | 19 | 中 → 2 + 弱 → [4] + SP + 强 | MP → 2+LP → [4]646+K | 2824 | 3850 | SA 1, drive >=0 (1 unknown) | 8.0 | medium | 0/2 pairs verified |
| 20 | 20 | 中 → 弱 → 2 + AUTO + SP | MP → LP → 63214+KK | 2792 | 3800 | OD 1, drive 20000 | 7.5 | medium | 0/2 pairs verified |

## Pairs to sweep: 18

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 444 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 中 → 214214 + 强 | `603:manual->1215:manual` | 1 | untested | single | low | -3 |
| 2 | 中 → 弱 | `603:manual->600:manual` | 2, 7, 12, 18, 20 | untested | single | medium | 1 |
| 3 | 弱 → 214214 + 强 | `600:manual->1215:manual` | 2, 4 | untested | single | low | -5 |
| 4 | 中 → 2 + 弱 | `603:manual->615:manual` | 3, 8, 13, 19 | untested | single | medium | 2 |
| 5 | 2 + 弱 → 214214 + 强 | `615:manual->1215:manual` | 3, 5 | untested | single | low | -5 |
| 6 | 2 + 中 → 弱 | `633:manual->600:manual` | 4, 10, 14 | untested | single | medium | 1 |
| 7 | 2 + 中 → 2 + 弱 | `633:manual->615:manual` | 5, 11, 15 | untested | single | medium | 2 |
| 8 | 中 → 2 + SP + 强 | `603:manual->1215:simple` | 6 | untested | single | low | -3 |
| 9 | 弱 → 2 + SP + 强 | `600:manual->1215:simple` | 7, 10 | untested | single | low | -5 |
| 10 | 2 + 弱 → 2 + SP + 强 | `615:manual->1215:simple` | 8, 11 | untested | single | low | -5 |
| 11 | 中 → [4]646 + 中 | `603:manual->1203:manual` | 9 | untested | single | high | -6 |
| 12 | 弱 → [4]646 + 中 | `600:manual->1203:manual` | 12, 14 | untested | single | high | -8 |
| 13 | 2 + 弱 → [4]646 + 中 | `615:manual->1203:manual` | 13, 15 | untested | single | high | -8 |
| 14 | 中 → [4] + SP + 强 | `603:manual->1203:simple` | 16 | untested | single | high | -6 |
| 15 | 中 → 2 + AUTO + SP | `603:manual->998:simple` | 17 | untested | single | high | 0 |
| 16 | 弱 → [4] + SP + 强 | `600:manual->1203:simple` | 18 | untested | single | high | -8 |
| 17 | 2 + 弱 → [4] + SP + 强 | `615:manual->1203:simple` | 19 | untested | single | high | -8 |
| 18 | 弱 → 2 + AUTO + SP | `600:manual->998:simple` | 20 | untested | single | high | -2 |

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

- reframework/data/ComboExplorer_data/worklist/ehonda-modern-plan-starter-chu.json  (18 pairs, 10736 bytes)
- docs/ComboExplorer/plans/ehonda-modern-starter-chu.md
