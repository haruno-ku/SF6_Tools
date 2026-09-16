# Route plan - Sagat / modern - starter-chu

Generated 2026-09-16T00:27:08Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

3 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 979 (search complete: true)

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| starter_button | M | 979 | 900 | 79 | 0 |

- routes satisfying every condition: 79
- of those, through a pair the policy CONCLUSIVELY rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

Demotion counts conclusive failures only. Under policy `ce-eval-v1` a negative is one when the run pressed a playable input at the right timing; 0 of 0 runs were left out for asking something else, 0 of them negatives. 0 pair(s) changed status because of it.

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 2 + 中 → 弱 → 236236 + 强 | 2+MK → LP → 236236+K | 4100 | 4900 | SA 1, drive >=0 (1 unknown) | 10.4 | low | 0/2 pairs reproduced |
| 2 | 2 | 2 + 中 → 2 + 弱 → 236236 + 强 | 2+MK → 2+LP → 236236+K | 4100 | 4900 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs reproduced |
| 3 | 3 | 2 + 中 → 弱 → 2 + SP + 强 | 2+MK → LP → 236236+K | 3460 | 4900 | SA 1, drive >=0 (1 unknown) | 8.0 | low | 0/2 pairs reproduced |
| 4 | 4 | 2 + 中 → 2 + 弱 → 2 + SP + 强 | 2+MK → 2+LP → 236236+K | 3460 | 4900 | SA 1, drive >=0 (1 unknown) | 8.5 | low | 0/2 pairs reproduced |
| 5 | 5 | 2 + 中 → 弱 → 214214 + 中 | 2+MK → LP → 214214+K | 2260 | 2600 | SA 1, drive >=0 (1 unknown) | 10.4 | medium | 0/2 pairs reproduced |
| 6 | 6 | 2 + 中 → 2 + 弱 → 214214 + 中 | 2+MK → 2+LP → 214214+K | 2260 | 2600 | SA 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs reproduced |
| 7 | 7 | 2 + 中 → 弱 → 623 + 强 | 2+MK → LP → 623+HP | 2180 | 2500 | drive 0 | 7.7 | medium | 0/2 pairs reproduced |
| 8 | 8 | 2 + 中 → 2 + 弱 → 623 + 强 | 2+MK → 2+LP → 623+HP | 2180 | 2500 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 9 | 9 | 2 + 中 → 弱 → 623 + 中 | 2+MK → LP → 623+MP | 2020 | 2300 | drive 0 | 7.7 | medium | 0/2 pairs reproduced |
| 10 | 10 | 2 + 中 → 2 + 弱 → 623 + 中 | 2+MK → 2+LP → 623+MP | 2020 | 2300 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 11 | 11 | 2 + 中 → 弱 → 4 + SP + 强 | 2+MK → LP → 214214+K | 1988 | 2600 | SA 1, drive >=0 (1 unknown) | 8.0 | medium | 0/2 pairs reproduced |
| 12 | 12 | 2 + 中 → 2 + 弱 → 4 + SP + 强 | 2+MK → 2+LP → 214214+K | 1988 | 2600 | SA 1, drive >=0 (1 unknown) | 8.5 | medium | 0/2 pairs reproduced |
| 13 | 13 | 2 + 中 → 弱 → 623 + 弱 | 2+MK → LP → 623+LP | 1780 | 2000 | drive 0 | 7.7 | medium | 0/2 pairs reproduced |
| 14 | 14 | 2 + 中 → 2 + 弱 → 623 + 弱 | 2+MK → 2+LP → 623+LP | 1780 | 2000 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 15 | 15 | 2 + 中 → 弱 → 236 + 中 | 2+MK → LP → 236+MK | 1700 | 1900 | drive 0 | 7.7 | medium | 0/2 pairs reproduced |
| 16 | 16 | 2 + 中 → 2 + 弱 → 236 + 中 | 2+MK → 2+LP → 236+MK | 1700 | 1900 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 17 | 17 | 2 + 中 → 623 + 弱 | 2+MK → 623+LP | 1700 | 1700 | drive 0 | 6.2 | medium | 0/1 pairs reproduced |
| 18 | 18 | 2 + 中 → 弱 → 3 + 强 | 2+MK → LP → 2+HK | 1620 | 1800 | drive 0 | 5.5 | medium | 0/2 pairs reproduced |
| 19 | 19 | 2 + 中 → 弱 → 6 + 强 | 2+MK → LP → 6+HK | 1620 | 1800 | drive 0 | 5.5 | medium | 0/2 pairs reproduced |
| 20 | 20 | 2 + 中 → 2 + 弱 → 3 + 强 | 2+MK → 2+LP → 2+HK | 1620 | 1800 | drive 0 | 6.0 | medium | 0/2 pairs reproduced |

## Pairs to sweep: 22

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 412 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 2 + 中 → 弱 | `640:manual->601:manual` | 1, 3, 5, 7, 9, 11, 13, 15, 18, 19 | untested | single | medium | 0 |
| 2 | 弱 → 236236 + 强 | `601:manual->1228:manual` | 1 | untested | single | low | -8 |
| 3 | 2 + 中 → 2 + 弱 | `640:manual->622:manual` | 2, 4, 6, 8, 10, 12, 14, 16, 20 | untested | single | medium | 1 |
| 4 | 2 + 弱 → 236236 + 强 | `622:manual->1228:manual` | 2 | untested | single | low | -7 |
| 5 | 弱 → 2 + SP + 强 | `601:manual->1228:simple` | 3 | untested | single | low | -8 |
| 6 | 2 + 弱 → 2 + SP + 强 | `622:manual->1228:simple` | 4 | untested | single | low | -7 |
| 7 | 弱 → 214214 + 中 | `601:manual->1208:manual` | 5 | untested | single | high | -6 |
| 8 | 2 + 弱 → 214214 + 中 | `622:manual->1208:manual` | 6 | untested | single | high | -5 |
| 9 | 弱 → 623 + 强 | `601:manual->922:manual` | 7 | untested | single | high | -14 |
| 10 | 2 + 弱 → 623 + 强 | `622:manual->922:manual` | 8 | untested | single | high | -13 |
| 11 | 弱 → 623 + 中 | `601:manual->921:manual` | 9 | untested | single | high | -6 |
| 12 | 2 + 弱 → 623 + 中 | `622:manual->921:manual` | 10 | untested | single | high | -5 |
| 13 | 弱 → 4 + SP + 强 | `601:manual->1208:simple` | 11 | untested | single | high | -6 |
| 14 | 2 + 弱 → 4 + SP + 强 | `622:manual->1208:simple` | 12 | untested | single | high | -5 |
| 15 | 弱 → 623 + 弱 | `601:manual->920:manual` | 13 | untested | single | high | -1 |
| 16 | 2 + 弱 → 623 + 弱 | `622:manual->920:manual` | 14 | untested | single | high | 0 |
| 17 | 弱 → 236 + 中 | `601:manual->941:manual` | 15 | untested | single | high | -14 |
| 18 | 2 + 弱 → 236 + 中 | `622:manual->941:manual` | 16 | untested | single | high | -13 |
| 19 | 2 + 中 → 623 + 弱 | `640:manual->920:manual` | 17 | untested | single | medium | 0 |
| 20 | 弱 → 3 + 强 | `601:manual->643:manual` | 18 | untested | single | medium | -7 |
| 21 | 弱 → 6 + 强 | `601:manual->673:manual` | 19 | untested | single | medium | -12 |
| 22 | 2 + 弱 → 3 + 强 | `622:manual->643:manual` | 20 | untested | single | medium | -6 |

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

- reframework/data/ComboExplorer_data/worklist/sagat-modern-plan-starter-chu.json  (22 pairs, 12692 bytes)
- docs/ComboExplorer/plans/sagat-modern-starter-chu.md
