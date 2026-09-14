# Route plan - Zangief / modern - max-damage

Generated 2026-09-14T11:18:35Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

**Scaled damage is not available in this build of Scoring.** no route carries offline_score.predicted_damage_scaled, so the routes are ordered on the unscaled predicted_damage instead.
The `dmg scaled` column is empty for that reason. Rerun this plan once
`offline_score.predicted_damage_scaled` exists and the order will follow it.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 917 (search complete: true)

- routes satisfying every condition: 917
- of those, through a pair the logs rejected: 793 (ranked after the clean ones)
- in this plan (top 20): 20

### Moved below the top 20 by a rejected pair: 20

The sort alone would have put these in the plan. They are not deleted - they
rank after every clean route, and `--no-demote-rejected` puts them back. Some
rejections in the logs come from experiments later found broken (#46, #49).

- sort #1 3 + 强 → 6 + 强 → 720 + 强 - rejected: 633:manual->662:manual, 662:manual->1218:manual
- sort #2 3 + 强 → 6 + 强 → 2 + SP + 强 - rejected: 633:manual->662:manual, 662:manual->1218:simple
- sort #3 6 + 强 → 2 + 强 → 720 + 强 - rejected: 662:manual->623:manual, 623:manual->1218:manual
- sort #4 6 + 强 → 2 + 强 → 2 + SP + 强 - rejected: 662:manual->623:manual, 623:manual->1218:simple
- sort #5 6 + 强 → 3 + 强 → 720 + 强 - rejected: 662:manual->633:manual, 633:manual->1218:manual
- sort #6 6 + 强 → 3 + 强 → 2 + SP + 强 - rejected: 662:manual->633:manual, 633:manual->1218:simple
- sort #7 6 + 强 → 3 + 中 → 720 + 强 - rejected: 662:manual->655:manual, 655:manual->1218:manual
- sort #8 6 + 强 → 3 + 中 → 2 + SP + 强 - rejected: 662:manual->655:manual, 655:manual->1218:simple
- sort #9 2 + 强 → 3 + 强 → 720 + 强 - rejected: 623:manual->633:manual, 633:manual->1218:manual
- sort #10 2 + 强 → 3 + 强 → 2 + SP + 强 - rejected: 623:manual->633:manual, 633:manual->1218:simple
- sort #11 3 + 强 → 2 + 强 → 720 + 强 - rejected: 633:manual->623:manual, 623:manual->1218:manual
- sort #12 3 + 强 → 2 + 强 → 2 + SP + 强 - rejected: 633:manual->623:manual, 623:manual->1218:simple
- sort #13 6 + 强 → 2 + 中 → 720 + 强 - rejected: 662:manual->621:manual, 621:manual->1218:manual
- sort #14 6 + 强 → 2 + 中 → 2 + SP + 强 - rejected: 662:manual->621:manual, 621:manual->1218:simple
- sort #15 2 + 强 → 3 + 中 → 720 + 强 - rejected: 623:manual->655:manual, 655:manual->1218:manual
- sort #16 2 + 强 → 3 + 中 → 2 + SP + 强 - rejected: 623:manual->655:manual, 655:manual->1218:simple
- sort #17 3 + 强 → 3 + 中 → 720 + 强 - rejected: 633:manual->655:manual, 655:manual->1218:manual
- sort #18 3 + 强 → 3 + 中 → 2 + SP + 强 - rejected: 633:manual->655:manual, 655:manual->1218:simple
- sort #19 弱 → 6 + 强 → 720 + 强 - rejected: 662:manual->1218:manual
- sort #20 弱 → 6 + 强 → 2 + SP + 强 - rejected: 662:manual->1218:simple

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 201 | 弱 → 6 + 强 → 63214 + THROW | LP → 6+HK → 63214+LK+MK | - | 4900 | drive 20000 | 9.5 | low | 0/2 pairs verified |
| 2 | 202 | 弱 → 6 + 强 → 4 + SP | LP → 6+HK → 63214+LK+MK | - | 4900 | drive 20000 | 7.5 | low | 0/2 pairs verified |
| 3 | 203 | 弱 → 6 + 强 → 4 + AUTO + SP | LP → 6+HK → 63214+KK | - | 4900 | OD 1, drive 20000 | 8.0 | low | 0/2 pairs verified |
| 4 | 285 | 弱 → 2 + 强 → 63214 + THROW | LP → 2+HP → 63214+LK+MK | - | 4600 | drive 20000 | 9.5 | low | 0/2 pairs verified |
| 5 | 286 | 弱 → 2 + 强 → 4 + SP | LP → 2+HP → 63214+LK+MK | - | 4600 | drive 20000 | 7.5 | low | 0/2 pairs verified |
| 6 | 287 | 弱 → 2 + 强 → 4 + AUTO + SP | LP → 2+HP → 63214+KK | - | 4600 | OD 1, drive 20000 | 8.0 | low | 0/2 pairs verified |
| 7 | 288 | 弱 → 3 + 强 → 63214 + THROW | LP → 2+HK → 63214+LK+MK | - | 4600 | drive 20000 | 9.5 | low | 0/2 pairs verified |
| 8 | 289 | 弱 → 3 + 强 → 4 + SP | LP → 2+HK → 63214+LK+MK | - | 4600 | drive 20000 | 7.5 | low | 0/2 pairs verified |
| 9 | 290 | 弱 → 3 + 强 → 4 + AUTO + SP | LP → 2+HK → 63214+KK | - | 4600 | OD 1, drive 20000 | 8.0 | low | 0/2 pairs verified |
| 10 | 321 | 弱 → 3 + 强 → 4 + SP + 强 | LP → 2+HK → 236236+P | - | 4560 | SA 1, drive >=0 (1 unknown) | 8.0 | medium | 1/2 pairs verified |
| 11 | 354 | 6 + 强 → 63214 + THROW | 6+HK → 63214+LK+MK | - | 4500 | drive 20000 | 8.0 | low | 0/1 pairs verified |
| 12 | 355 | 6 + 强 → 4 + SP | 6+HK → 63214+LK+MK | - | 4500 | drive 20000 | 6.0 | low | 0/1 pairs verified |
| 13 | 356 | 6 + 强 → 4 + AUTO + SP | 6+HK → 63214+KK | - | 4500 | OD 1, drive 20000 | 6.5 | low | 0/1 pairs verified |
| 14 | 369 | 弱 → 3 + 中 → 63214 + THROW | LP → 3+MP → 63214+LK+MK | - | 4400 | drive 20000 | 9.5 | low | 0/2 pairs verified |
| 15 | 370 | 弱 → 3 + 中 → 4 + SP | LP → 3+MP → 63214+LK+MK | - | 4400 | drive 20000 | 7.5 | low | 0/2 pairs verified |
| 16 | 371 | 弱 → 3 + 中 → 4 + AUTO + SP | LP → 3+MP → 63214+KK | - | 4400 | OD 1, drive 20000 | 8.0 | low | 0/2 pairs verified |
| 17 | 382 | 弱 → 3 + 中 → 236236 + 中 | LP → 3+MP → 236236+P | - | 4360 | SA 1, drive >=0 (1 unknown) | 10.4 | medium | 1/2 pairs verified |
| 18 | 383 | 弱 → 3 + 中 → 4 + SP + 强 | LP → 3+MP → 236236+P | - | 4360 | SA 1, drive >=0 (1 unknown) | 8.0 | medium | 1/2 pairs verified |
| 19 | 386 | 弱 → 2 + 中 → 63214 + THROW | LP → 2+MP → 63214+LK+MK | - | 4300 | drive 20000 | 9.5 | low | 0/2 pairs verified |
| 20 | 387 | 弱 → 2 + 中 → 4 + SP | LP → 2+MP → 63214+LK+MK | - | 4300 | drive 20000 | 7.5 | low | 0/2 pairs verified |

## Pairs to sweep: 19

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 324 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 弱 → 6 + 强 | `601:manual->662:manual` | 1, 2, 3 | pending as `611:manual->662:manual` | single | medium | -18 |
| 2 | 6 + 强 → 63214 + THROW | `662:manual->918:manual` | 1, 11 | pending | single | low | 18 |
| 3 | 6 + 强 → 4 + SP | `662:manual->918:simple` | 2, 12 | pending | single | low | 18 |
| 4 | 6 + 强 → 4 + AUTO + SP | `662:manual->924:simple` | 3, 13 | pending | single | low | 18 |
| 5 | 弱 → 2 + 强 | `601:manual->623:manual` | 4, 5, 6 | pending as `611:manual->623:manual` | single | medium | -7 |
| 6 | 2 + 强 → 63214 + THROW | `623:manual->918:manual` | 4 | pending | single | low | 10 |
| 7 | 2 + 强 → 4 + SP | `623:manual->918:simple` | 5 | pending | single | low | 10 |
| 8 | 2 + 强 → 4 + AUTO + SP | `623:manual->924:simple` | 6 | pending | single | low | 10 |
| 9 | 弱 → 3 + 强 | `601:manual->633:manual` | 7, 8, 9, 10 | pending as `611:manual->633:manual` | single | medium | -8 |
| 10 | 3 + 强 → 63214 + THROW | `633:manual->918:manual` | 7 | pending | single | low | 26 |
| 11 | 3 + 强 → 4 + SP | `633:manual->918:simple` | 8 | pending | single | low | 26 |
| 12 | 3 + 强 → 4 + AUTO + SP | `633:manual->924:simple` | 9 | pending | single | low | 26 |
| 13 | 弱 → 3 + 中 | `601:manual->655:manual` | 14, 15, 16, 17, 18 | pending as `611:manual->655:manual` | single | medium | -3 |
| 14 | 3 + 中 → 63214 + THROW | `655:manual->918:manual` | 14 | pending | single | low | -11 |
| 15 | 3 + 中 → 4 + SP | `655:manual->918:simple` | 15 | pending | single | low | -11 |
| 16 | 3 + 中 → 4 + AUTO + SP | `655:manual->924:simple` | 16 | pending | single | low | -11 |
| 17 | 弱 → 2 + 中 | `601:manual->621:manual` | 19, 20 | pending as `611:manual->621:manual` | single | medium | -4 |
| 18 | 2 + 中 → 63214 + THROW | `621:manual->918:manual` | 19 | pending | single | low | -7 |
| 19 | 2 + 中 → 4 + SP | `621:manual->918:simple` | 20 | pending | single | low | -7 |

## Already known: 3

Left out of the worklist (pass --include-verified to keep verified pairs).

- `633:manual->1206:simple` (3 + 强 → 4 + SP + 强): verified by the game, needed by 10
- `655:manual->1206:manual` (3 + 中 → 236236 + 中): verified by the game, needed by 17
- `655:manual->1206:simple` (3 + 中 → 4 + SP + 强): verified by the game, needed by 18

## Where the known statuses come from

- trial logs read: 7 (1000 records for modern)
- pairs answered: 418 across 2 cohort(s) - verified 12, rejected 151, pending 255
- route runs (combos, not pairs): 366 rows
- combos confirmed in the logs: 7

A pair measured in several cohorts is `verified` if any cohort linked it, else
`rejected` if any answered no, else `pending`. `(mixed)` marks a pair one cohort
linked and another rejected.

`as <key>` means the answer was recorded under another action id with the same
buttons. The catalog lists Modern 弱 as 601, 602 and 611; the search keeps one of
them, and the sweep folds every pair onto the id the calibration measured (611)
before pressing it, so that is the id its trials carry.

## Running it

The in-game SWEEP panel reads `worklist/<char>-<scheme>.json` by that exact name.
To sweep this plan, put the plan's worklist in its place on the game machine
(keep the full one aside), or teach the panel to pick a file.

## Written

- reframework/data/ComboExplorer_data/worklist/zangief-modern-plan-max-damage.json  (19 pairs, 10761 bytes)
- docs/ComboExplorer/plans/zangief-modern-max-damage.md
