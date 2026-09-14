# Route plan - Zangief / modern - starter-chu

Generated 2026-09-14T11:18:42Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

EVERY ROUTE HERE IS A THEORETICAL CANDIDATE. The ranking is a prediction from
the frame data. The worklist below is the smallest set of pairs that lets the
game say whether these routes connect.

## Conditions

- `starter_button` = `中`
- sort: `scaled_damage`, top 20
- search: explore.lua's settings (normal,command_normal -> normal,command_normal,special,od_special,super, manual -> manual,simple, max 3 moves, beam 4000, collapse true)
- Drive Rush Cancel edges in the search: no (pass --drive-rush to route through them)
- demote routes through a rejected pair: yes

`starter_button` keeps a route whose first move has that button with ANY direction
(中 keeps 中, 2 + 中, 3 + 中, 6 + 中). `--starter-neutral` narrows it to no direction.

## Damage figure

**Scaled damage is not available in this build of Scoring.** no route carries offline_score.predicted_damage_scaled, so the routes are ordered on the unscaled predicted_damage instead.
The `dmg scaled` column is empty for that reason. Rerun this plan once
`offline_score.predicted_damage_scaled` exists and the order will follow it.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 917 (search complete: true)

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| starter_button | 中 | 917 | 878 | 39 | 0 |

- routes satisfying every condition: 39
- of those, through a pair the logs rejected: 21 (ranked after the clean ones)
- in this plan (top 20): 20

### Moved below the top 20 by a rejected pair: 12

The sort alone would have put these in the plan. They are not deleted - they
rank after every clean route, and `--no-demote-rejected` puts them back. Some
rejections in the logs come from experiments later found broken (#46, #49).

- sort #3 2 + 中 → 720 + 强 - rejected: 621:manual->1218:manual
- sort #4 2 + 中 → 2 + SP + 强 - rejected: 621:manual->1218:simple
- sort #5 3 + 中 → SP + 强 - rejected: 655:manual->1195:simple
- sort #6 3 + 中 → 236236 + 弱 - rejected: 655:manual->1200:manual
- sort #7 2 + 中 → SP + 强 - rejected: 621:manual->1195:simple
- sort #8 2 + 中 → 236236 + 弱 - rejected: 621:manual->1200:manual
- sort #9 3 + 中 → AUTO + SP - rejected: 655:manual->945:simple
- sort #10 2 + 中 → AUTO + SP - rejected: 621:manual->945:simple
- sort #11 3 + 中 → 360 + 强 - rejected: 655:manual->940:manual
- sort #12 3 + 中 → SP - rejected: 655:manual->940:simple
- sort #13 2 + 中 → 360 + 强 - rejected: 621:manual->940:manual
- sort #14 2 + 中 → SP - rejected: 621:manual->940:simple

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 15 | 3 + 中 → 63214 + THROW | 3+MP → 63214+LK+MK | - | 4000 | drive 20000 | 8.0 | low | 0/1 pairs verified |
| 2 | 16 | 3 + 中 → 4 + SP | 3+MP → 63214+LK+MK | - | 4000 | drive 20000 | 6.0 | low | 0/1 pairs verified |
| 3 | 17 | 3 + 中 → 4 + AUTO + SP | 3+MP → 63214+KK | - | 4000 | OD 1, drive 20000 | 6.5 | low | 0/1 pairs verified |
| 4 | 18 | 3 + 中 → 236236 + 中 | 3+MP → 236236+P | - | 3960 | SA 1, drive >=0 (1 unknown) | 8.9 | high | confirmed combo |
| 5 | 19 | 3 + 中 → 4 + SP + 强 | 3+MP → 236236+P | - | 3960 | SA 1, drive >=0 (1 unknown) | 6.5 | high | confirmed combo |
| 6 | 20 | 2 + 中 → 63214 + THROW | 2+MP → 63214+LK+MK | - | 3900 | drive 20000 | 8.0 | low | 0/1 pairs verified |
| 7 | 21 | 2 + 中 → 4 + SP | 2+MP → 63214+LK+MK | - | 3900 | drive 20000 | 6.0 | low | 0/1 pairs verified |
| 8 | 22 | 2 + 中 → 4 + AUTO + SP | 2+MP → 63214+KK | - | 3900 | OD 1, drive 20000 | 6.5 | low | 0/1 pairs verified |
| 9 | 23 | 2 + 中 → 236236 + 中 | 2+MP → 236236+P | - | 3860 | SA 1, drive >=0 (1 unknown) | 8.9 | high | confirmed combo |
| 10 | 24 | 2 + 中 → 4 + SP + 强 | 2+MP → 236236+P | - | 3860 | SA 1, drive >=0 (1 unknown) | 6.5 | high | confirmed combo |
| 11 | 31 | 3 + 中 → 22 + 强 | 3+MP → 22+HK | - | 3200 | drive 0 | 5.3 | low | 0/1 pairs verified |
| 12 | 33 | 3 + 中 → 强 | 3+MP → HP | - | 1800 | drive 0 | 3.5 | low | 0/1 pairs verified |
| 13 | 34 | 中 → 强 | MP → HP | - | 1700 | drive 0 | 3.0 | low | 0/1 pairs verified |
| 14 | 35 | 2 + 中 → 强 | 2+MP → HP | - | 1700 | drive 0 | 3.5 | low | 0/1 pairs verified |
| 15 | 36 | 6 + 中 → 强 | 6+MK → HP | - | 1700 | drive 0 | 3.5 | low | 0/1 pairs verified |
| 16 | 37 | 3 + 中 → 22 + 中 | 3+MP → 22+MK | - | 1300 | drive 0 | 5.3 | high | 0/1 pairs verified |
| 17 | 38 | 2 + 中 → 22 + 中 | 2+MP → 22+MK | - | 1200 | drive 0 | 5.3 | high | 0/1 pairs verified |
| 18 | 39 | 中 → > 中 | MP → >MP | - | 700 (incomplete) | drive >=0 (1 unknown) | 3.0 | medium | 0/1 pairs verified |
| 19 | 1 | 3 + 中 → 720 + 强 | 3+MP → 720+P | - | 5600 | SA 1, drive >=0 (1 unknown) | 13.4 | low | 0/1 pairs verified; REJECTED pair: 655:manual->1218:manual |
| 20 | 2 | 3 + 中 → 2 + SP + 强 | 3+MP → 720+P | - | 5600 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs verified; REJECTED pair: 655:manual->1218:simple |

## Pairs to sweep: 16

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 324 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 3 + 中 → 63214 + THROW | `655:manual->918:manual` | 1 | pending | single | low | -11 |
| 2 | 3 + 中 → 4 + SP | `655:manual->918:simple` | 2 | pending | single | low | -11 |
| 3 | 3 + 中 → 4 + AUTO + SP | `655:manual->924:simple` | 3 | pending | single | low | -11 |
| 4 | 2 + 中 → 63214 + THROW | `621:manual->918:manual` | 6 | pending | single | low | -7 |
| 5 | 2 + 中 → 4 + SP | `621:manual->918:simple` | 7 | pending | single | low | -7 |
| 6 | 2 + 中 → 4 + AUTO + SP | `621:manual->924:simple` | 8 | pending | single | low | -7 |
| 7 | 3 + 中 → 22 + 强 | `655:manual->785:manual` | 11 | pending | repeat | low | -7 |
| 8 | 3 + 中 → 强 | `655:manual->637:manual` | 12 | pending | single | low | - |
| 9 | 中 → 强 | `604:manual->637:manual` | 13 | pending | single | low | - |
| 10 | 2 + 中 → 强 | `621:manual->637:manual` | 14 | pending | single | low | - |
| 11 | 6 + 中 → 强 | `682:manual->637:manual` | 15 | pending | single | low | - |
| 12 | 3 + 中 → 22 + 中 | `655:manual->678:manual` | 16 | pending | repeat | high | -10 |
| 13 | 2 + 中 → 22 + 中 | `621:manual->678:manual` | 17 | pending | repeat | high | -6 |
| 14 | 中 → > 中 | `604:manual->605:manual` | 18 | pending | followup | medium | -7 |
| 15 | 3 + 中 → 720 + 强 | `655:manual->1218:manual` | 19 | rejected | single | low | -7 |
| 16 | 3 + 中 → 2 + SP + 强 | `655:manual->1218:simple` | 20 | rejected | single | low | -7 |

**4 of these the sweep cannot press as written.**

### Rejected pairs kept in the sweep: 2

A "no" in the committed logs is not trusted enough to delete a route. Some of
those experiments were later found broken: the fixed delay of 4 that pressed B
inside A's cancel window (#46), and follow-ups pressed after a move they cannot
come out of (#49). These pairs are asked again, after the clean routes' pairs
when demotion is on.

- `655:manual->1218:manual`: rejected (ESF_006-20260911T180157Z: 0/1 linked); rejected (ESF_006-20260912T074740Z: 0/2 linked)
- `655:manual->1218:simple`: rejected (ESF_006-20260911T180157Z: 0/1 linked); rejected (ESF_006-20260912T074740Z: 0/2 linked)

## Already known: 4

Left out of the worklist (pass --include-verified to keep verified pairs).

- `655:manual->1206:manual` (3 + 中 → 236236 + 中): verified by the game, needed by 4
- `655:manual->1206:simple` (3 + 中 → 4 + SP + 强): verified by the game, needed by 5
- `621:manual->1206:manual` (2 + 中 → 236236 + 中): verified by the game, needed by 9
- `621:manual->1206:simple` (2 + 中 → 4 + SP + 强): verified by the game, needed by 10

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

- reframework/data/ComboExplorer_data/worklist/zangief-modern-plan-starter-chu.json  (16 pairs, 8961 bytes)
- docs/ComboExplorer/plans/zangief-modern-starter-chu.md
