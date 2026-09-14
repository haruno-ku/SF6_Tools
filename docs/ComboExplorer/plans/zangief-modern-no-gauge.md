# Route plan - Zangief / modern - no-gauge

Generated 2026-09-14T11:23:36Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

EVERY ROUTE HERE IS A THEORETICAL CANDIDATE. The ranking is a prediction from
the frame data. The worklist below is the smallest set of pairs that lets the
game say whether these routes connect.

## Conditions

- `no_gauge` = `true`
- sort: `scaled_damage`, top 20
- search: explore.lua's settings (normal,command_normal -> normal,command_normal,special,od_special,super, manual -> manual,simple, max 3 moves, beam 4000, collapse true)
- Drive Rush Cancel edges in the search: no (pass --drive-rush to route through them)
- demote routes through a rejected pair: yes

`no_gauge` removes a route with an OD move, a super, a Drive Rush Cancel, or any
KNOWN Drive or Super spend. A route where some move has no Drive figure is kept and
flagged: nothing in the source says it spends, and a missing value never excludes.

## Damage figure

Ordered on `offline_score.predicted_damage_scaled`, the combo-scaled prediction.

6 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 917 (search complete: true)

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| no_gauge | true | 917 | 380 | 537 | 6 |

- routes satisfying every condition: 537
- of those, through a pair the logs rejected: 475 (ranked after the clean ones)
- in this plan (top 20): 20

### Moved below the top 20 by a rejected pair: 20

The sort alone would have put these in the plan. They are not deleted - they
rank after every clean route, and `--no-demote-rejected` puts them back. Some
rejections in the logs come from experiments later found broken (#46, #49).

- sort #1 3 + 强 → 6 + 强 → 360 + 强 - rejected: 633:manual->662:manual, 662:manual->940:manual
- sort #2 6 + 强 → 2 + 强 → 360 + 强 - rejected: 662:manual->623:manual, 623:manual->940:manual
- sort #3 6 + 强 → 3 + 强 → 360 + 强 - rejected: 662:manual->633:manual, 633:manual->940:manual
- sort #4 6 + 强 → 3 + 中 → 360 + 强 - rejected: 662:manual->655:manual, 655:manual->940:manual
- sort #5 2 + 强 → 3 + 强 → 360 + 强 - rejected: 623:manual->633:manual, 633:manual->940:manual
- sort #6 3 + 强 → 2 + 强 → 360 + 强 - rejected: 633:manual->623:manual, 623:manual->940:manual
- sort #7 6 + 强 → 2 + 中 → 360 + 强 - rejected: 662:manual->621:manual, 621:manual->940:manual
- sort #8 3 + 强 → 6 + 强 → 360 + 中 - rejected: 633:manual->662:manual, 662:manual->935:manual
- sort #9 6 + 强 → 2 + 强 → 360 + 中 - rejected: 662:manual->623:manual, 623:manual->935:manual
- sort #10 6 + 强 → 3 + 强 → 360 + 中 - rejected: 662:manual->633:manual, 633:manual->935:manual
- sort #11 6 + 强 → 360 + 强 - rejected: 662:manual->940:manual
- sort #12 2 + 强 → 3 + 中 → 360 + 强 - rejected: 623:manual->655:manual, 655:manual->940:manual
- sort #13 3 + 强 → 3 + 中 → 360 + 强 - rejected: 633:manual->655:manual, 655:manual->940:manual
- sort #14 6 + 强 → 3 + 中 → 360 + 中 - rejected: 662:manual->655:manual, 655:manual->935:manual
- sort #15 3 + 强 → 6 + 强 → SP - rejected: 633:manual->662:manual, 662:manual->940:simple
- sort #16 6 + 强 → 2 + 强 → SP - rejected: 662:manual->623:manual, 623:manual->940:simple
- sort #17 6 + 强 → 3 + 强 → SP - rejected: 662:manual->633:manual, 633:manual->940:simple
- sort #18 3 + 强 → 6 + 强 → 63214 + 强 - rejected: 633:manual->662:manual, 662:manual->1010:manual
- sort #19 6 + 强 → 2 + 强 → 63214 + 强 - rejected: 662:manual->623:manual, 623:manual->1010:manual
- sort #20 6 + 强 → 3 + 强 → 63214 + 强 - rejected: 662:manual->633:manual, 633:manual->1010:manual

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 92 | 6 + 强 → 22 + 强 | 6+HK → 22+HK | 3700 | 3700 | drive 0 | 5.3 | low | 0/1 pairs verified |
| 2 | 122 | 2 + 强 → 22 + 强 | 2+HP → 22+HK | 3400 | 3400 | drive 0 | 5.3 | low | 0/1 pairs verified |
| 3 | 124 | 3 + 强 → 22 + 强 | 2+HK → 22+HK | 3400 | 3400 | drive 0 | 5.3 | low | 0/1 pairs verified |
| 4 | 147 | 3 + 中 → 22 + 强 | 3+MP → 22+HK | 3200 | 3200 | drive 0 | 5.3 | low | 0/1 pairs verified |
| 5 | 154 | 弱 → 6 + 强 → 22 + 强 | LP → 6+HK → 22+HK | 3120 | 4100 | drive 0 | 6.8 | low | 0/2 pairs verified |
| 6 | 190 | 弱 → 2 + 强 → 22 + 强 | LP → 2+HP → 22+HK | 2880 | 3800 | drive 0 | 6.8 | low | 0/2 pairs verified |
| 7 | 191 | 弱 → 3 + 强 → 22 + 强 | LP → 2+HK → 22+HK | 2880 | 3800 | drive 0 | 6.8 | low | 0/2 pairs verified |
| 8 | 221 | 弱 → 3 + 中 → 22 + 强 | LP → 3+MP → 22+HK | 2720 | 3600 | drive 0 | 6.8 | low | 0/2 pairs verified |
| 9 | 277 | 弱 → 弱 → 22 + 强 | LP → LP → 22+HK | 2400 | 3200 | drive 0 | 5.8 | low | 0/2 pairs verified |
| 10 | 294 | 弱 → 22 + 强 | LP → 22+HK | 2320 | 2800 | drive 0 | 4.8 | low | 0/1 pairs verified |
| 11 | 302 | 6 + 强 → 强 | 6+HK → HP | 2300 | 2300 | drive 0 | 3.5 | low | 0/1 pairs verified |
| 12 | 325 | 弱 → 6 + 强 → 强 | LP → 6+HK → HP | 2140 | 2700 | drive 0 | 5.0 | low | 0/2 pairs verified |
| 13 | 346 | 2 + 强 → 强 | 2+HP → HP | 2000 | 2000 | drive 0 | 3.5 | low | 0/1 pairs verified |
| 14 | 348 | 3 + 强 → 强 | 2+HK → HP | 2000 | 2000 | drive 0 | 3.5 | low | 0/1 pairs verified |
| 15 | 367 | 弱 → 2 + 强 → 强 | LP → 2+HP → HP | 1900 | 2400 | drive 0 | 5.0 | low | 0/2 pairs verified |
| 16 | 369 | 弱 → 3 + 强 → 强 | LP → 2+HK → HP | 1900 | 2400 | drive 0 | 5.0 | low | 0/2 pairs verified |
| 17 | 389 | 3 + 中 → 强 | 3+MP → HP | 1800 | 1800 | drive 0 | 3.5 | low | 0/1 pairs verified |
| 18 | 390 | 6 + 强 → 22 + 中 | 6+HK → 22+MK | 1800 | 1800 | drive 0 | 5.3 | medium | 0/1 pairs verified |
| 19 | 391 | 弱 → 6 + 强 → 22 + 中 | LP → 6+HK → 22+MK | 1790 | 2200 | drive 0 | 6.8 | medium | 0/2 pairs verified |
| 20 | 394 | 弱 → 3 + 中 → 强 | LP → 3+MP → HP | 1740 | 2200 | drive 0 | 5.0 | low | 0/2 pairs verified |

## Pairs to sweep: 15

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 324 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 6 + 强 → 22 + 强 | `662:manual->785:manual` | 1, 5 | pending | repeat | low | 22 |
| 2 | 2 + 强 → 22 + 强 | `623:manual->785:manual` | 2, 6 | pending | repeat | low | 14 |
| 3 | 3 + 强 → 22 + 强 | `633:manual->785:manual` | 3, 7 | pending | repeat | low | 30 |
| 4 | 3 + 中 → 22 + 强 | `655:manual->785:manual` | 4, 8 | pending | repeat | low | -7 |
| 5 | 弱 → 6 + 强 | `601:manual->662:manual` | 5, 12, 19 | pending as `611:manual->662:manual` | single | medium | -18 |
| 6 | 弱 → 2 + 强 | `601:manual->623:manual` | 6, 15 | pending as `611:manual->623:manual` | single | medium | -7 |
| 7 | 弱 → 3 + 强 | `601:manual->633:manual` | 7, 16 | pending as `611:manual->633:manual` | single | medium | -8 |
| 8 | 弱 → 3 + 中 | `601:manual->655:manual` | 8, 20 | pending as `611:manual->655:manual` | single | medium | -3 |
| 9 | 弱 → 弱 | `601:manual->601:manual` | 9 | pending as `611:manual->611:manual` | single | medium | -3 |
| 10 | 弱 → 22 + 强 | `601:manual->785:manual` | 9, 10 | pending as `611:manual->785:manual` | repeat | low | -2 |
| 11 | 6 + 强 → 强 | `662:manual->637:manual` | 11, 12 | pending | single | low | - |
| 12 | 2 + 强 → 强 | `623:manual->637:manual` | 13, 15 | pending | single | low | - |
| 13 | 3 + 强 → 强 | `633:manual->637:manual` | 14, 16 | pending | single | low | - |
| 14 | 3 + 中 → 强 | `655:manual->637:manual` | 17, 20 | pending | single | low | - |
| 15 | 6 + 强 → 22 + 中 | `662:manual->678:manual` | 18, 19 | pending | repeat | medium | 19 |

**6 of these the sweep cannot press as written.**

## Already known: 0

Nothing these routes need has been answered yet.

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

- reframework/data/ComboExplorer_data/worklist/zangief-modern-plan-no-gauge.json  (15 pairs, 8755 bytes)
- docs/ComboExplorer/plans/zangief-modern-no-gauge.md
