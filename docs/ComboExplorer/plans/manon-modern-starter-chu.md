# Route plan - Manon / modern - starter-chu

Generated 2026-09-16T02:21:12Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

EVERY ROUTE HERE IS A THEORETICAL CANDIDATE. The ranking is a prediction from
the frame data. The worklist below is the smallest set of pairs that lets the
game say whether these routes connect.

## Conditions

- `starter_button` = `M`
- sort: `scaled_damage`, top 20
- search: explore.lua's settings (normal,command_normal -> normal,command_normal,special,od_special,super, manual -> manual,simple, max 3 moves, beam 4000, collapse true)
- search complete: true - every route the settings can reach is in the list below
- Drive Rush Cancel edges in the search: no (pass --drive-rush to route through them)
- demote routes through a rejected pair: yes

`starter_button` keeps a route whose first move has that button with ANY direction
(中 keeps 中, 2 + 中, 3 + 中, 6 + 中). `--starter-neutral` narrows it to no direction.

## Damage figure

Ordered on `offline_score.predicted_damage_scaled`, the combo-scaled prediction.

2 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 490 (search complete: true)

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| starter_button | M | 490 | 420 | 70 | 0 |

- routes satisfying every condition: 70
- of those, through a pair the policy CONCLUSIVELY rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

Demotion counts conclusive failures only. Under policy `ce-eval-v1` a negative is one when the run pressed a playable input at the right timing; 0 of 0 runs were left out for asking something else, 0 of them negatives. 0 pair(s) changed status because of it.

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 中 → 214214 + 中 | MP → 214214+K | 3400 | 3400 | SA 1, drive >=0 (1 unknown) | 8.4 | high | 0/1 pairs reproduced |
| 2 | 2 | 2 + 中 → 弱 → 214214 + 中 | 2+MK → LP → 214214+K | 3140 | 3700 | SA 1, drive >=0 (1 unknown) | 10.4 | medium | 0/2 pairs reproduced |
| 3 | 3 | 2 + 中 → 2 + 弱 → 214214 + 中 | 2+MK → 2+LP → 214214+K | 3140 | 3700 | SA 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs reproduced |
| 4 | 4 | 中 → 4 + SP + 强 | MP → 214214+K | 2840 | 3400 | SA 1, drive >=0 (1 unknown) | 6.0 | high | 0/1 pairs reproduced |
| 5 | 5 | 2 + 中 → 弱 → 4 + SP + 强 | 2+MK → LP → 214214+K | 2692 | 3700 | SA 1, drive >=0 (1 unknown) | 8.0 | medium | 0/2 pairs reproduced |
| 6 | 6 | 2 + 中 → 2 + 弱 → 4 + SP + 强 | 2+MK → 2+LP → 214214+K | 2692 | 3700 | SA 1, drive >=0 (1 unknown) | 8.5 | medium | 0/2 pairs reproduced |
| 7 | 7 | 中 → 236236 + 弱 | MP → 236236+K | 2600 | 2600 | SA 1, drive >=0 (1 unknown) | 8.4 | high | 0/1 pairs reproduced |
| 8 | 8 | 2 + 中 → 弱 → 236236 + 弱 | 2+MK → LP → 236236+K | 2500 | 2900 | SA 1, drive >=0 (1 unknown) | 10.4 | medium | 0/2 pairs reproduced |
| 9 | 9 | 2 + 中 → 2 + 弱 → 236236 + 弱 | 2+MK → 2+LP → 236236+K | 2500 | 2900 | SA 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs reproduced |
| 10 | 10 | 中 → SP + 强 | MP → 236236+K | 2200 | 2600 | SA 1, drive >=0 (1 unknown) | 5.5 | high | 0/1 pairs reproduced |
| 11 | 11 | 2 + 中 → 弱 → SP + 强 | 2+MK → LP → 236236+K | 2180 | 2900 | SA 1, drive >=0 (1 unknown) | 7.5 | medium | 0/2 pairs reproduced |
| 12 | 12 | 2 + 中 → 2 + 弱 → SP + 强 | 2+MK → 2+LP → 236236+K | 2180 | 2900 | SA 1, drive >=0 (1 unknown) | 8.0 | medium | 0/2 pairs reproduced |
| 13 | 13 | 2 + 中 → 弱 → 214 + 强 | 2+MK → LP → 214+HK | 1700 | 1900 | drive 0 | 7.7 | medium | 0/2 pairs reproduced |
| 14 | 14 | 2 + 中 → 2 + 弱 → 214 + 强 | 2+MK → 2+LP → 214+HK | 1700 | 1900 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 15 | 15 | 2 + 中 → 弱 → 3 + 强 | 2+MK → LP → 2+HK | 1620 | 1800 | drive 0 | 5.5 | medium | 0/2 pairs reproduced |
| 16 | 16 | 2 + 中 → 2 + 弱 → 3 + 强 | 2+MK → 2+LP → 2+HK | 1620 | 1800 | drive 0 | 6.0 | medium | 0/2 pairs reproduced |
| 17 | 17 | 中 → 214 + 强 | MP → 214+HK | 1600 | 1600 | drive 0 | 5.7 | high | 0/1 pairs reproduced |
| 18 | 18 | 2 + 中 → 弱 → 强 | 2+MK → LP → HP | 1540 | 1700 | drive 0 | 5.0 | medium | 0/2 pairs reproduced |
| 19 | 19 | 2 + 中 → 弱 → 4 + 强 | 2+MK → LP → 4+HP | 1540 | 1700 | drive 0 | 5.5 | medium | 0/2 pairs reproduced |
| 20 | 20 | 2 + 中 → 2 + 弱 → 强 | 2+MK → 2+LP → HP | 1540 | 1700 | drive 0 | 5.5 | medium | 0/2 pairs reproduced |

## Pairs to sweep: 22

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 343 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 中 → 214214 + 中 | `605:manual->1210:manual` | 1 | untested | single | high | -5 |
| 2 | 2 + 中 → 弱 | `640:manual->600:manual` | 2, 5, 8, 11, 13, 15, 18, 19 | untested | single | medium | 0 |
| 3 | 弱 → 214214 + 中 | `600:manual->1210:manual` | 2 | untested | single | high | -3 |
| 4 | 2 + 中 → 2 + 弱 | `640:manual->625:manual` | 3, 6, 9, 12, 14, 16, 20 | untested | single | medium | 0 |
| 5 | 2 + 弱 → 214214 + 中 | `625:manual->1210:manual` | 3 | untested | single | high | -4 |
| 6 | 中 → 4 + SP + 强 | `605:manual->1210:simple` | 4 | untested | single | high | -5 |
| 7 | 弱 → 4 + SP + 强 | `600:manual->1210:simple` | 5 | untested | single | high | -3 |
| 8 | 2 + 弱 → 4 + SP + 强 | `625:manual->1210:simple` | 6 | untested | single | high | -4 |
| 9 | 中 → 236236 + 弱 | `605:manual->1200:manual` | 7 | untested | single | high | -8 |
| 10 | 弱 → 236236 + 弱 | `600:manual->1200:manual` | 8 | untested | single | high | -6 |
| 11 | 2 + 弱 → 236236 + 弱 | `625:manual->1200:manual` | 9 | untested | single | high | -7 |
| 12 | 中 → SP + 强 | `605:manual->1200:simple` | 10 | untested | single | high | -8 |
| 13 | 弱 → SP + 强 | `600:manual->1200:simple` | 11 | untested | single | high | -6 |
| 14 | 2 + 弱 → SP + 强 | `625:manual->1200:simple` | 12 | untested | single | high | -7 |
| 15 | 弱 → 214 + 强 | `600:manual->1003:manual` | 13 | untested | single | high | -16 |
| 16 | 2 + 弱 → 214 + 强 | `625:manual->1003:manual` | 14 | untested | single | high | -17 |
| 17 | 弱 → 3 + 强 | `600:manual->643:manual` | 15 | untested | single | medium | -7 |
| 18 | 2 + 弱 → 3 + 强 | `625:manual->643:manual` | 16 | untested | single | medium | -8 |
| 19 | 中 → 214 + 强 | `605:manual->1003:manual` | 17 | untested | single | high | -18 |
| 20 | 弱 → 强 | `600:manual->609:manual` | 18 | untested | single | medium | -6 |
| 21 | 弱 → 4 + 强 | `600:manual->665:manual` | 19 | untested | single | medium | -4 |
| 22 | 2 + 弱 → 强 | `625:manual->609:manual` | 20 | untested | single | medium | -7 |

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

- reframework/data/ComboExplorer_data/worklist/manon-modern-plan-starter-chu.json  (22 pairs, 43936 bytes)
- docs/ComboExplorer/plans/manon-modern-starter-chu.md
