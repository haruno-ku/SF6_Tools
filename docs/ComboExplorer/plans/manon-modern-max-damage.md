# Route plan - Manon / modern - max-damage

Generated 2026-09-16T00:25:28Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

16 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 490 (search complete: true)

- routes satisfying every condition: 490
- of those, through a pair the policy CONCLUSIVELY rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

Demotion counts conclusive failures only. Under policy `ce-eval-v1` a negative is one when the run pressed a playable input at the right timing; 0 of 0 runs were left out for asking something else, 0 of them negatives. 0 pair(s) changed status because of it.

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 3 + 强 → 强 → 214214 + 中 | 2+HK → HP → 214214+K | 3940 | 4500 | SA 1, drive >=0 (1 unknown) | 10.4 | medium | 0/2 pairs reproduced |
| 2 | 2 | 3 + 强 → 4 + 强 → 214214 + 中 | 2+HK → 4+HP → 214214+K | 3940 | 4500 | SA 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs reproduced |
| 3 | 3 | 3 + 强 → 中 → 214214 + 中 | 2+HK → MP → 214214+K | 3740 | 4300 | SA 1, drive >=0 (1 unknown) | 10.4 | medium | 0/2 pairs reproduced |
| 4 | 4 | 3 + 强 → 214214 + 中 | 2+HK → 214214+K | 3700 | 3700 | SA 1, drive >=0 (1 unknown) | 8.9 | medium | 0/1 pairs reproduced |
| 5 | 5 | 强 → 214214 + 中 | HP → 214214+K | 3600 | 3600 | SA 1, drive >=0 (1 unknown) | 8.4 | high | 0/1 pairs reproduced |
| 6 | 6 | 4 + 强 → 214214 + 中 | 4+HP → 214214+K | 3600 | 3600 | SA 1, drive >=0 (1 unknown) | 8.9 | high | 0/1 pairs reproduced |
| 7 | 7 | 3 + 强 → 强 → 4 + SP + 强 | 2+HK → HP → 214214+K | 3492 | 4500 | SA 1, drive >=0 (1 unknown) | 8.0 | medium | 0/2 pairs reproduced |
| 8 | 8 | 3 + 强 → 4 + 强 → 4 + SP + 强 | 2+HK → 4+HP → 214214+K | 3492 | 4500 | SA 1, drive >=0 (1 unknown) | 8.5 | medium | 0/2 pairs reproduced |
| 9 | 9 | 3 + 强 → 弱 → 214214 + 中 | 2+HK → LP → 214214+K | 3440 | 4000 | SA 1, drive >=0 (1 unknown) | 10.4 | medium | 0/2 pairs reproduced |
| 10 | 10 | 3 + 强 → 2 + 弱 → 214214 + 中 | 2+HK → 2+LP → 214214+K | 3440 | 4000 | SA 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs reproduced |
| 11 | 11 | 中 → 214214 + 中 | MP → 214214+K | 3400 | 3400 | SA 1, drive >=0 (1 unknown) | 8.4 | high | 0/1 pairs reproduced |
| 12 | 12 | 3 + 强 → 强 → 236236 + 弱 | 2+HK → HP → 236236+K | 3300 | 3700 | SA 1, drive >=0 (1 unknown) | 10.4 | medium | 0/2 pairs reproduced |
| 13 | 13 | 3 + 强 → 4 + 强 → 236236 + 弱 | 2+HK → 4+HP → 236236+K | 3300 | 3700 | SA 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs reproduced |
| 14 | 14 | 3 + 强 → 中 → 4 + SP + 强 | 2+HK → MP → 214214+K | 3292 | 4300 | SA 1, drive >=0 (1 unknown) | 8.0 | medium | 0/2 pairs reproduced |
| 15 | 15 | 2 + 中 → 弱 → 214214 + 中 | 2+MK → LP → 214214+K | 3140 | 3700 | SA 1, drive >=0 (1 unknown) | 10.4 | medium | 0/2 pairs reproduced |
| 16 | 16 | 2 + 中 → 2 + 弱 → 214214 + 中 | 2+MK → 2+LP → 214214+K | 3140 | 3700 | SA 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs reproduced |
| 17 | 17 | 3 + 强 → 4 + SP + 强 | 2+HK → 214214+K | 3140 | 3700 | SA 1, drive >=0 (1 unknown) | 6.5 | medium | 0/1 pairs reproduced |
| 18 | 18 | 3 + 强 → 中 → 236236 + 弱 | 2+HK → MP → 236236+K | 3100 | 3500 | SA 1, drive >=0 (1 unknown) | 10.4 | medium | 0/2 pairs reproduced |
| 19 | 19 | 强 → 4 + SP + 强 | HP → 214214+K | 3040 | 3600 | SA 1, drive >=0 (1 unknown) | 6.0 | high | 0/1 pairs reproduced |
| 20 | 20 | 4 + 强 → 4 + SP + 强 | 4+HP → 214214+K | 3040 | 3600 | SA 1, drive >=0 (1 unknown) | 6.5 | high | 0/1 pairs reproduced |

## Pairs to sweep: 20

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 343 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 3 + 强 → 强 | `643:manual->609:manual` | 1, 7, 12 | untested | single | medium | 19 |
| 2 | 强 → 214214 + 中 | `609:manual->1210:manual` | 1, 5 | untested | single | high | -7 |
| 3 | 3 + 强 → 4 + 强 | `643:manual->665:manual` | 2, 8, 13 | untested | single | medium | 21 |
| 4 | 4 + 强 → 214214 + 中 | `665:manual->1210:manual` | 2, 6 | untested | single | high | -4 |
| 5 | 3 + 强 → 中 | `643:manual->605:manual` | 3, 14, 18 | untested | single | medium | 22 |
| 6 | 中 → 214214 + 中 | `605:manual->1210:manual` | 3, 11 | untested | single | high | -5 |
| 7 | 3 + 强 → 214214 + 中 | `643:manual->1210:manual` | 4 | untested | single | medium | 22 |
| 8 | 强 → 4 + SP + 强 | `609:manual->1210:simple` | 7, 19 | untested | single | high | -7 |
| 9 | 4 + 强 → 4 + SP + 强 | `665:manual->1210:simple` | 8, 20 | untested | single | high | -4 |
| 10 | 3 + 强 → 弱 | `643:manual->600:manual` | 9 | untested | single | medium | 25 |
| 11 | 弱 → 214214 + 中 | `600:manual->1210:manual` | 9, 15 | untested | single | high | -3 |
| 12 | 3 + 强 → 2 + 弱 | `643:manual->625:manual` | 10 | untested | single | medium | 25 |
| 13 | 2 + 弱 → 214214 + 中 | `625:manual->1210:manual` | 10, 16 | untested | single | high | -4 |
| 14 | 强 → 236236 + 弱 | `609:manual->1200:manual` | 12 | untested | single | high | -10 |
| 15 | 4 + 强 → 236236 + 弱 | `665:manual->1200:manual` | 13 | untested | single | high | -7 |
| 16 | 中 → 4 + SP + 强 | `605:manual->1210:simple` | 14 | untested | single | high | -5 |
| 17 | 2 + 中 → 弱 | `640:manual->600:manual` | 15 | untested | single | medium | 0 |
| 18 | 2 + 中 → 2 + 弱 | `640:manual->625:manual` | 16 | untested | single | medium | 0 |
| 19 | 3 + 强 → 4 + SP + 强 | `643:manual->1210:simple` | 17 | untested | single | medium | 22 |
| 20 | 中 → 236236 + 弱 | `605:manual->1200:manual` | 18 | untested | single | high | -8 |

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
reframework/data), then pick `plan: max-damage` in the SWEEP panel's worklist list
(REFRESH if the panel was already open) and START SWEEP. It writes to the same
trial log as the full sweep, so pairs the full sweep already answered under the
same calibration and conditions are skipped, and the other way round.

## Written

- reframework/data/ComboExplorer_data/worklist/manon-modern-plan-max-damage.json  (20 pairs, 11501 bytes)
- docs/ComboExplorer/plans/manon-modern-max-damage.md
