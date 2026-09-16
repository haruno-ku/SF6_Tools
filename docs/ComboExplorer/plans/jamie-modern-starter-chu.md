# Route plan - Jamie / modern - starter-chu

Generated 2026-09-16T00:26:45Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

87 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 1079 (search complete: true)

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| starter_button | M | 1079 | 708 | 371 | 0 |

- routes satisfying every condition: 371
- of those, through a pair the policy CONCLUSIVELY rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

Demotion counts conclusive failures only. Under policy `ce-eval-v1` a negative is one when the run pressed a playable input at the right timing; 0 of 0 runs were left out for asking something else, 0 of them negatives. 0 pair(s) changed status because of it.

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 2 + 中 + 强 → 236236 + 强 | 2+KK → 236236+P | 5100 | 5100 | SA 1, drive >=0 (1 unknown) | 9.4 | low | 0/1 pairs reproduced |
| 2 | 2 | 2 + 中 + 强 → 2 + 强 → 236236 + 强 | 2+KK → 2+HP → 236236+P | 5100 | 6000 | SA 1, drive >=0 (1 unknown) | 11.4 | low | 0/2 pairs reproduced |
| 3 | 3 | 2 + 中 + 强 → 6 + 强 → 236236 + 强 | 2+KK → 6+HK → 236236+P | 5100 | 6000 | SA 1, drive >=0 (1 unknown) | 11.4 | low | 0/2 pairs reproduced |
| 4 | 4 | 2 + 中 → 236236 + 强 | 2+MK → 236236+P | 5000 | 5000 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs reproduced |
| 5 | 5 | 2 + 中 + 强 → 4 + 强 → 236236 + 强 | 2+KK → 4+HP → 236236+P | 5000 | 5900 | SA 1, drive >=0 (1 unknown) | 11.4 | low | 0/2 pairs reproduced |
| 6 | 6 | 2 + 中 + 强 → 2 + 中 → 236236 + 强 | 2+KK → 2+MK → 236236+P | 4700 | 5600 | SA 1, drive >=0 (1 unknown) | 11.4 | low | 0/2 pairs reproduced |
| 7 | 7 | 2 + 中 + 强 → 3 + 强 → 236236 + 强 | 2+KK → 2+HK → 236236+P | 4600 | 5500 | SA 1, drive >=0 (1 unknown) | 11.4 | low | 0/2 pairs reproduced |
| 8 | 8 | 中 → 弱 → 236236 + 强 | MP → LP → 236236+P | 4470 | 5370 | SA 1, drive >=0 (1 unknown) | 9.9 | low | 0/2 pairs reproduced |
| 9 | 9 | 2 + 中 + 强 → 弱 → 236236 + 强 | 2+KK → LP → 236236+P | 4470 | 5370 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs reproduced |
| 10 | 10 | 中 → 2 + 弱 → 236236 + 强 | MP → 2+LP → 236236+P | 4450 | 5350 | SA 1, drive >=0 (1 unknown) | 10.4 | low | 0/2 pairs reproduced |
| 11 | 11 | 2 + 中 + 强 → 2 + 弱 → 236236 + 强 | 2+KK → 2+LP → 236236+P | 4450 | 5350 | SA 1, drive >=0 (1 unknown) | 11.4 | low | 0/2 pairs reproduced |
| 12 | 12 | 2 + 中 + 强 → 2 + 强 → 2 + SP + 强 | 2+KK → 2+HP → 236236+P | 4380 | 6000 | SA 1, drive >=0 (1 unknown) | 9.0 | low | 0/2 pairs reproduced |
| 13 | 13 | 2 + 中 + 强 → 6 + 强 → 2 + SP + 强 | 2+KK → 6+HK → 236236+P | 4380 | 6000 | SA 1, drive >=0 (1 unknown) | 9.0 | low | 0/2 pairs reproduced |
| 14 | 14 | 中 → 强 → 236236 + 强 | MP → HP → 236236+P | 4300 | 5200 | SA 1, drive >=0 (1 unknown) | 9.9 | low | 0/2 pairs reproduced |
| 15 | 15 | 2 + 中 + 强 → 强 → 236236 + 强 | 2+KK → HP → 236236+P | 4300 | 5200 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs reproduced |
| 16 | 16 | 2 + 中 + 强 → 4 + 强 → 2 + SP + 强 | 2+KK → 4+HP → 236236+P | 4280 | 5900 | SA 1, drive >=0 (1 unknown) | 9.0 | low | 0/2 pairs reproduced |
| 17 | 17 | 2 + 中 + 强 → 2 + SP + 强 | 2+KK → 236236+P | 4200 | 5100 | SA 1, drive >=0 (1 unknown) | 7.0 | low | 0/1 pairs reproduced |
| 18 | 18 | 2 + 中 → 2 + SP + 强 | 2+MK → 236236+P | 4100 | 5000 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs reproduced |
| 19 | 19 | 2 + 中 + 强 → 2 + 中 → 2 + SP + 强 | 2+KK → 2+MK → 236236+P | 3980 | 5600 | SA 1, drive >=0 (1 unknown) | 9.0 | low | 0/2 pairs reproduced |
| 20 | 20 | 2 + 中 + 强 → 3 + 强 → 2 + SP + 强 | 2+KK → 2+HK → 236236+P | 3880 | 5500 | SA 1, drive >=0 (1 unknown) | 9.0 | low | 0/2 pairs reproduced |

## Pairs to sweep: 26

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 752 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 2 + 中 + 强 → 236236 + 强 | `666:manual->1211:manual` | 1 | untested | single | low | 43 |
| 2 | 2 + 中 + 强 → 2 + 强 | `666:manual->628:manual` | 2, 12 | untested | single | medium | 45 |
| 3 | 2 + 强 → 236236 + 强 | `628:manual->1211:manual` | 2 | untested | single | low | -10 |
| 4 | 2 + 中 + 强 → 6 + 强 | `666:manual->679:manual` | 3, 13 | untested | single | low | 37 |
| 5 | 6 + 强 → 236236 + 强 | `679:manual->1211:manual` | 3 | untested | single | low | -7 |
| 6 | 2 + 中 → 236236 + 强 | `635:manual->1211:manual` | 4, 6 | untested | single | low | -11 |
| 7 | 2 + 中 + 强 → 4 + 强 | `666:manual->673:manual` | 5, 16 | untested | single | low | 35 |
| 8 | 4 + 强 → 236236 + 强 | `673:manual->1211:manual` | 5 | untested | single | low | -9 |
| 9 | 2 + 中 + 强 → 2 + 中 | `666:manual->635:manual` | 6, 19 | untested | single | medium | 46 |
| 10 | 2 + 中 + 强 → 3 + 强 | `666:manual->638:manual` | 7, 20 | untested | single | medium | 44 |
| 11 | 3 + 强 → 236236 + 强 | `638:manual->1211:manual` | 7 | untested | single | low | 23 |
| 12 | 中 → 弱 | `608:manual->600:manual` | 8 | untested | single | low | 1 |
| 13 | 弱 → 236236 + 强 | `600:manual->1211:manual` | 8, 9 | untested | single | low | -5 |
| 14 | 2 + 中 + 强 → 弱 | `666:manual->600:manual` | 9 | untested | single | low | 48 |
| 15 | 中 → 2 + 弱 | `608:manual->622:manual` | 10 | untested | single | medium | 2 |
| 16 | 2 + 弱 → 236236 + 强 | `622:manual->1211:manual` | 10, 11 | untested | single | low | -5 |
| 17 | 2 + 中 + 强 → 2 + 弱 | `666:manual->622:manual` | 11 | untested | single | medium | 49 |
| 18 | 2 + 强 → 2 + SP + 强 | `628:manual->1211:simple` | 12 | untested | single | low | -10 |
| 19 | 6 + 强 → 2 + SP + 强 | `679:manual->1211:simple` | 13 | untested | single | low | -7 |
| 20 | 中 → 强 | `608:manual->610:manual` | 14 | untested | single | medium | 1 |
| 21 | 强 → 236236 + 强 | `610:manual->1211:manual` | 14, 15 | untested | single | low | -9 |
| 22 | 2 + 中 + 强 → 强 | `666:manual->610:manual` | 15 | untested | single | medium | 48 |
| 23 | 4 + 强 → 2 + SP + 强 | `673:manual->1211:simple` | 16 | untested | single | low | -9 |
| 24 | 2 + 中 + 强 → 2 + SP + 强 | `666:manual->1211:simple` | 17 | untested | single | low | 43 |
| 25 | 2 + 中 → 2 + SP + 强 | `635:manual->1211:simple` | 18, 19 | untested | single | low | -11 |
| 26 | 3 + 强 → 2 + SP + 强 | `638:manual->1211:simple` | 20 | untested | single | low | 23 |

## Already known: 0

Nothing these routes need has been answered yet.

## Where the known statuses come from

- trial logs read: 0 (0 records for modern)
- pairs answered: 0 across 0 cohort(s) - raw ConfirmedEdge: verified 0, rejected 0, pending 0
- route runs (combos, not pairs): 0 rows
- combos the looser page rule calls confirmed: 0 (2+ links at any gap, across input methods, cohorts and gaps, superseded rows included)

### Policy `ce-eval-v1`

A superseded re-run is left out unless it linked. A link counts under every flag. A negative counts only when the run asked the question at the right timing with a pressable input (no fixed_delay_4, unplayable_input, link_timing_on_cancel_pair, motion_button_late). Unanswered runs count as unanswered. Pairs fold per cohort through ConfirmedEdge (reproduced = stable); routes per cohort through the combo rule (reproduced = 2 counted links at any gap).

- rows built from the trial files: 0 (0 lines, 0 committed twice, 0 refused)
- runs counted: 0; left out: 0 (of which negatives: 0)
- evaluations (one per subject per cohort): 0
- pairs by status: 
- reclassified by the policy: 0 of 0 (none)

A pair measured in several cohorts takes the strongest result: `verified` when some
cohort REPRODUCED it (ConfirmedEdge stable on the counted runs), else `linked_once`
when some cohort linked it, else `rejected` when a cohort answered no on runs the
policy counted, else `asked_badly` when negatives exist and every one of them was
left out, else `pending`. `(mixed)` marks a pair that both linked and conclusively
failed. Only `rejected` demotes a route.

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

- reframework/data/ComboExplorer_data/worklist/jamie-modern-plan-starter-chu.json  (26 pairs, 14399 bytes)
- docs/ComboExplorer/plans/jamie-modern-starter-chu.md
