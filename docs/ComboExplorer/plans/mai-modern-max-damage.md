# Route plan - Mai / modern - max-damage

Generated 2026-09-14T13:02:30Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 454 (search complete: true)

- routes satisfying every condition: 454
- of those, through a pair the logs rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 3 + 强 → 214214 + 强 | 2+HK → 214214+P | 4900 | 4900 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs verified |
| 2 | 2 | 3 + 强 → 2 + 中 → 214214 + 强 | 2+HK → 2+MK → 214214+P | 4600 | 5400 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs verified |
| 3 | 3 | 2 + 中 → 214214 + 强 | 2+MK → 214214+P | 4500 | 4500 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs verified |
| 4 | 4 | 3 + 强 → 弱 → 214214 + 强 | 2+HK → LK → 214214+P | 4400 | 5200 | SA 1, drive >=0 (1 unknown) | 10.4 | low | 0/2 pairs verified |
| 5 | 5 | 3 + 强 → 2 + 弱 → 214214 + 强 | 2+HK → 2+LP → 214214+P | 4400 | 5200 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs verified |
| 6 | 6 | 中 → 弱 → 214214 + 强 | MK → LK → 214214+P | 4200 | 5000 | SA 1, drive >=0 (1 unknown) | 9.9 | low | 0/2 pairs verified |
| 7 | 7 | 中 → 2 + 弱 → 214214 + 强 | MK → 2+LP → 214214+P | 4200 | 5000 | SA 1, drive >=0 (1 unknown) | 10.4 | low | 0/2 pairs verified |
| 8 | 8 | 3 + 强 → 2 + SP + 强 | 2+HK → 214214+P | 4100 | 4900 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs verified |
| 9 | 9 | 3 + 强 → 2 + 中 → 2 + SP + 强 | 2+HK → 2+MK → 214214+P | 3960 | 5400 | SA 1, drive >=0 (1 unknown) | 8.5 | low | 0/2 pairs verified |
| 10 | 10 | 2 + 强 → 弱 → 214214 + 强 | 2+HP → LK → 214214+P | 3900 | 4700 | SA 1, drive >=0 (1 unknown) | 10.4 | low | 0/2 pairs verified |
| 11 | 11 | 2 + 强 → 2 + 弱 → 214214 + 强 | 2+HP → 2+LP → 214214+P | 3900 | 4700 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs verified |
| 12 | 12 | 2 + 弱 → 3 + 强 → 214214 + 强 | 2+LP → 2+HK → 214214+P | 3820 | 5200 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs verified |
| 13 | 13 | 3 + 强 → 弱 → 2 + SP + 强 | 2+HK → LK → 214214+P | 3760 | 5200 | SA 1, drive >=0 (1 unknown) | 8.0 | low | 0/2 pairs verified |
| 14 | 14 | 3 + 强 → 2 + 弱 → 2 + SP + 强 | 2+HK → 2+LP → 214214+P | 3760 | 5200 | SA 1, drive >=0 (1 unknown) | 8.5 | low | 0/2 pairs verified |
| 15 | 15 | 2 + 中 → 2 + SP + 强 | 2+MK → 214214+P | 3700 | 4500 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs verified |
| 16 | 16 | 中 → 弱 → 2 + SP + 强 | MK → LK → 214214+P | 3560 | 5000 | SA 1, drive >=0 (1 unknown) | 7.5 | low | 0/2 pairs verified |
| 17 | 17 | 中 → 2 + 弱 → 2 + SP + 强 | MK → 2+LP → 214214+P | 3560 | 5000 | SA 1, drive >=0 (1 unknown) | 8.0 | low | 0/2 pairs verified |
| 18 | 18 | 弱 → 214214 + 强 | LK → 214214+P | 3500 | 4300 | SA 1, drive >=0 (1 unknown) | 8.4 | low | 0/1 pairs verified |
| 19 | 19 | 2 + 弱 → 214214 + 强 | 2+LP → 214214+P | 3500 | 4300 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs verified |
| 20 | 20 | 2 + 弱 → 2 + 中 → 214214 + 强 | 2+LP → 2+MK → 214214+P | 3500 | 4800 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs verified |

## Pairs to sweep: 17

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 519 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 3 + 强 → 214214 + 强 | `624:manual->1233:manual` | 1, 12 | untested | single | low | 28 |
| 2 | 3 + 强 → 2 + 中 | `624:manual->623:manual` | 2, 9 | untested | single | medium | 31 |
| 3 | 2 + 中 → 214214 + 强 | `623:manual->1233:manual` | 2, 3, 20 | untested | single | low | -12 |
| 4 | 3 + 强 → 弱 | `624:manual->606:manual` | 4, 13 | untested | single | medium | 34 |
| 5 | 弱 → 214214 + 强 | `606:manual->1233:manual` | 4, 6, 10, 18 | untested | single | low | -9 |
| 6 | 3 + 强 → 2 + 弱 | `624:manual->613:manual` | 5, 14 | untested | single | medium | 34 |
| 7 | 2 + 弱 → 214214 + 强 | `613:manual->1233:manual` | 5, 7, 11, 19 | untested | single | low | -6 |
| 8 | 中 → 弱 | `610:manual->606:manual` | 6, 16 | untested | single | medium | 1 |
| 9 | 中 → 2 + 弱 | `610:manual->613:manual` | 7, 17 | untested | single | medium | 1 |
| 10 | 3 + 强 → 2 + SP + 强 | `624:manual->1233:simple` | 8 | untested | single | low | 28 |
| 11 | 2 + 中 → 2 + SP + 强 | `623:manual->1233:simple` | 9, 15 | untested | single | low | -12 |
| 12 | 2 + 强 → 弱 | `618:manual->606:manual` | 10 | untested | single | medium | 0 |
| 13 | 2 + 强 → 2 + 弱 | `618:manual->613:manual` | 11 | untested | single | medium | 0 |
| 14 | 2 + 弱 → 3 + 强 | `613:manual->624:manual` | 12 | untested | single | medium | -5 |
| 15 | 弱 → 2 + SP + 强 | `606:manual->1233:simple` | 13, 16 | untested | single | low | -9 |
| 16 | 2 + 弱 → 2 + SP + 强 | `613:manual->1233:simple` | 14, 17 | untested | single | low | -6 |
| 17 | 2 + 弱 → 2 + 中 | `613:manual->623:manual` | 20 | untested | single | medium | -3 |

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

- reframework/data/ComboExplorer_data/worklist/mai-modern-plan-max-damage.json  (17 pairs, 10089 bytes)
- docs/ComboExplorer/plans/mai-modern-max-damage.md
