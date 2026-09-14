# Route plan - Zangief / modern - max-damage

Generated 2026-09-14T12:59:12Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

6 route(s) carry no value on that field and are ranked after the rest, not removed.

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
- sort #2 6 + 强 → 2 + 强 → 720 + 强 - rejected: 662:manual->623:manual, 623:manual->1218:manual
- sort #3 6 + 强 → 3 + 强 → 720 + 强 - rejected: 662:manual->633:manual, 633:manual->1218:manual
- sort #4 6 + 强 → 720 + 强 - rejected: 662:manual->1218:manual
- sort #5 6 + 强 → 3 + 中 → 720 + 强 - rejected: 662:manual->655:manual, 655:manual->1218:manual
- sort #6 2 + 强 → 3 + 强 → 720 + 强 - rejected: 623:manual->633:manual, 633:manual->1218:manual
- sort #7 3 + 强 → 2 + 强 → 720 + 强 - rejected: 633:manual->623:manual, 623:manual->1218:manual
- sort #8 6 + 强 → 2 + 中 → 720 + 强 - rejected: 662:manual->621:manual, 621:manual->1218:manual
- sort #9 2 + 强 → 720 + 强 - rejected: 623:manual->1218:manual
- sort #10 3 + 强 → 720 + 强 - rejected: 633:manual->1218:manual
- sort #11 2 + 强 → 3 + 中 → 720 + 强 - rejected: 623:manual->655:manual, 655:manual->1218:manual
- sort #12 3 + 强 → 3 + 中 → 720 + 强 - rejected: 633:manual->655:manual, 655:manual->1218:manual
- sort #13 3 + 中 → 720 + 强 - rejected: 655:manual->1218:manual
- sort #14 2 + 强 → 2 + 中 → 720 + 强 - rejected: 623:manual->621:manual, 621:manual->1218:manual
- sort #15 3 + 强 → 2 + 中 → 720 + 强 - rejected: 633:manual->621:manual, 621:manual->1218:manual
- sort #16 6 + 强 → 弱 → 720 + 强 - rejected: 662:manual->601:manual, 601:manual->1218:manual
- sort #17 2 + 中 → 720 + 强 - rejected: 621:manual->1218:manual
- sort #18 6 + 强 → 2 + 弱 → 720 + 强 - rejected: 662:manual->617:manual, 617:manual->1218:manual
- sort #19 3 + 强 → 6 + 强 → 2 + SP + 强 - rejected: 633:manual->662:manual, 662:manual->1218:simple
- sort #20 6 + 强 → 2 + 强 → 2 + SP + 强 - rejected: 662:manual->623:manual, 623:manual->1218:simple

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 88 | 6 + 强 → 63214 + THROW | 6+HK → 63214+LK+MK | 4500 | 4500 | drive 20000 | 8.0 | low | 0/1 pairs verified |
| 2 | 157 | 2 + 强 → 63214 + THROW | 2+HP → 63214+LK+MK | 4200 | 4200 | drive 20000 | 8.0 | low | 0/1 pairs verified |
| 3 | 159 | 3 + 强 → 63214 + THROW | 2+HK → 63214+LK+MK | 4200 | 4200 | drive 20000 | 8.0 | low | 0/1 pairs verified |
| 4 | 166 | 3 + 强 → 236236 + 中 | 2+HK → 236236+P | 4160 | 4160 | SA 1, drive >=0 (1 unknown) | 8.9 | medium | confirmed combo |
| 5 | 211 | 3 + 中 → 63214 + THROW | 3+MP → 63214+LK+MK | 4000 | 4000 | drive 20000 | 8.0 | low | 0/1 pairs verified |
| 6 | 218 | 3 + 中 → 236236 + 中 | 3+MP → 236236+P | 3960 | 3960 | SA 1, drive >=0 (1 unknown) | 8.9 | high | confirmed combo |
| 7 | 234 | 2 + 中 → 63214 + THROW | 2+MP → 63214+LK+MK | 3900 | 3900 | drive 20000 | 8.0 | low | 0/1 pairs verified |
| 8 | 246 | 2 + 中 → 236236 + 中 | 2+MP → 236236+P | 3860 | 3860 | SA 1, drive >=0 (1 unknown) | 8.9 | high | confirmed combo |
| 9 | 249 | 6 + 强 → 4 + SP | 6+HK → 63214+LK+MK | 3860 | 4500 | drive 20000 | 6.0 | low | 0/1 pairs verified |
| 10 | 250 | 6 + 强 → 4 + AUTO + SP | 6+HK → 63214+KK | 3860 | 4500 | OD 1, drive 20000 | 6.5 | low | 0/1 pairs verified |
| 11 | 298 | 6 + 强 → 22 + 强 | 6+HK → 22+HK | 3700 | 3700 | drive 0 | 5.3 | low | 0/1 pairs verified |
| 12 | 299 | 弱 → 6 + 强 → 63214 + THROW | LP → 6+HK → 63214+LK+MK | 3680 | 4900 | drive 20000 | 9.5 | low | 0/2 pairs verified |
| 13 | 327 | 2 + 强 → 4 + SP | 2+HP → 63214+LK+MK | 3560 | 4200 | drive 20000 | 6.0 | low | 0/1 pairs verified |
| 14 | 328 | 2 + 强 → 4 + AUTO + SP | 2+HP → 63214+KK | 3560 | 4200 | OD 1, drive 20000 | 6.5 | low | 0/1 pairs verified |
| 15 | 329 | 3 + 强 → 4 + SP | 2+HK → 63214+LK+MK | 3560 | 4200 | drive 20000 | 6.0 | low | 0/1 pairs verified |
| 16 | 330 | 3 + 强 → 4 + AUTO + SP | 2+HK → 63214+KK | 3560 | 4200 | OD 1, drive 20000 | 6.5 | low | 0/1 pairs verified |
| 17 | 338 | 3 + 强 → 4 + SP + 强 | 2+HK → 236236+P | 3528 | 4160 | SA 1, drive >=0 (1 unknown) | 6.5 | medium | confirmed combo |
| 18 | 359 | 弱 → 2 + 强 → 63214 + THROW | LP → 2+HP → 63214+LK+MK | 3440 | 4600 | drive 20000 | 9.5 | low | 0/2 pairs verified |
| 19 | 360 | 弱 → 3 + 强 → 63214 + THROW | LP → 2+HK → 63214+LK+MK | 3440 | 4600 | drive 20000 | 9.5 | low | 0/2 pairs verified |
| 20 | 375 | 2 + 强 → 22 + 强 | 2+HP → 22+HK | 3400 | 3400 | drive 0 | 5.3 | low | 0/1 pairs verified |

## Pairs to sweep: 17

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 324 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 6 + 强 → 63214 + THROW | `662:manual->918:manual` | 1, 12 | pending | single | low | 18 |
| 2 | 2 + 强 → 63214 + THROW | `623:manual->918:manual` | 2, 18 | pending | single | low | 10 |
| 3 | 3 + 强 → 63214 + THROW | `633:manual->918:manual` | 3, 19 | pending | single | low | 26 |
| 4 | 3 + 强 → 236236 + 中 | `633:manual->1206:manual` | 4 | rejected | single | medium | 18 |
| 5 | 3 + 中 → 63214 + THROW | `655:manual->918:manual` | 5 | pending | single | low | -11 |
| 6 | 2 + 中 → 63214 + THROW | `621:manual->918:manual` | 7 | pending | single | low | -7 |
| 7 | 6 + 强 → 4 + SP | `662:manual->918:simple` | 9 | pending | single | low | 18 |
| 8 | 6 + 强 → 4 + AUTO + SP | `662:manual->924:simple` | 10 | pending | single | low | 18 |
| 9 | 6 + 强 → 22 + 强 | `662:manual->785:manual` | 11 | pending | repeat | low | 22 |
| 10 | 弱 → 6 + 强 | `601:manual->662:manual` | 12 | pending as `611:manual->662:manual` | single | medium | -18 |
| 11 | 2 + 强 → 4 + SP | `623:manual->918:simple` | 13 | pending | single | low | 10 |
| 12 | 2 + 强 → 4 + AUTO + SP | `623:manual->924:simple` | 14 | pending | single | low | 10 |
| 13 | 3 + 强 → 4 + SP | `633:manual->918:simple` | 15 | pending | single | low | 26 |
| 14 | 3 + 强 → 4 + AUTO + SP | `633:manual->924:simple` | 16 | pending | single | low | 26 |
| 15 | 弱 → 2 + 强 | `601:manual->623:manual` | 18 | pending as `611:manual->623:manual` | single | medium | -7 |
| 16 | 弱 → 3 + 强 | `601:manual->633:manual` | 19 | pending as `611:manual->633:manual` | single | medium | -8 |
| 17 | 2 + 强 → 22 + 强 | `623:manual->785:manual` | 20 | pending | repeat | low | 14 |

**2 of these the sweep cannot press as written.**

### Rejected pairs kept in the sweep: 1

A "no" in the committed logs is not trusted enough to delete a route. Some of
those experiments were later found broken: the fixed delay of 4 that pressed B
inside A's cancel window (#46), and follow-ups pressed after a move they cannot
come out of (#49). These pairs are asked again, after the clean routes' pairs
when demotion is on.

- `633:manual->1206:manual`: runtime_pending (ESF_006-20260911T180157Z: 0/0 linked); rejected (ESF_006-20260912T074740Z: 0/2 linked)

## Already known: 3

Left out of the worklist (pass --include-verified to keep verified pairs).

- `655:manual->1206:manual` (3 + 中 → 236236 + 中): verified by the game, needed by 6
- `621:manual->1206:manual` (2 + 中 → 236236 + 中): verified by the game, needed by 8
- `633:manual->1206:simple` (3 + 强 → 4 + SP + 强): verified by the game, needed by 17

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

Copy the worklist to the game machine (`scripts/install-dev.ps1` syncs
reframework/data), then pick `plan: max-damage` in the SWEEP panel's worklist list
(REFRESH if the panel was already open) and START SWEEP. It writes to the same
trial log as the full sweep, so pairs the full sweep already answered under the
same calibration and conditions are skipped, and the other way round.

## Written

- reframework/data/ComboExplorer_data/worklist/zangief-modern-plan-max-damage.json  (17 pairs, 9981 bytes)
- docs/ComboExplorer/plans/zangief-modern-max-damage.md
