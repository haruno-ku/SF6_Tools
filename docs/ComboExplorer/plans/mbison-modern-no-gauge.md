# Route plan - MBison / modern - no-gauge

Generated 2026-09-16T02:33:45Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

EVERY ROUTE HERE IS A THEORETICAL CANDIDATE. The ranking is a prediction from
the frame data. The worklist below is the smallest set of pairs that lets the
game say whether these routes connect.

## Conditions

- `no_gauge` = `true`
- sort: `scaled_damage`, top 20
- search: explore.lua's settings (normal,command_normal -> normal,command_normal,special,od_special,super, manual -> manual,simple, max 3 moves, beam 4000, collapse true)
- search complete: false - the beam dropped 3257 partial route(s) and 0 route(s) were not emitted, so the list below is a sample
- Drive Rush Cancel edges in the search: no (pass --drive-rush to route through them)
- demote routes through a rejected pair: yes

`no_gauge` removes a route with an OD move, a super, a Drive Rush Cancel, or any
KNOWN Drive or Super spend. A route where some move has no Drive figure is kept and
flagged: nothing in the source says it spends, and a missing value never excludes.

## Damage figure

Ordered on `offline_score.predicted_damage_scaled`, the combo-scaled prediction.

381 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 1368 (search complete: false)
  - the beam dropped 3257 partial routes and 0 routes were not emitted, so a route
    satisfying these conditions may be missing

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| no_gauge | true | 1368 | 600 | 768 | 381 |

- routes satisfying every condition: 768
- of those, through a pair the policy CONCLUSIVELY rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

Demotion counts conclusive failures only. Under policy `ce-eval-v1` a negative is one when the run pressed a playable input at the right timing; 0 of 0 runs were left out for asking something else, 0 of them negatives. 0 pair(s) changed status because of it.

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 3 + 强 → 2 + 强 → [4]6 + 强 | 2+HK → 2+HP → [4]6+HP | 3080 | 3400 | drive 0 | 7.3 | low | 0/2 pairs reproduced |
| 2 | 2 | 3 + 强 → 4 + 强 → [4]6 + 强 | 2+HK → 4+HK → [4]6+HP | 2980 | 3300 | drive 0 | 7.3 | low | 0/2 pairs reproduced |
| 3 | 3 | 3 + 强 → 2 + 强 → [4]6 + 中 | 2+HK → 2+HP → [4]6+MP | 2920 | 3200 | drive 0 | 7.3 | low | 0/2 pairs reproduced |
| 4 | 4 | 3 + 强 → 4 + 强 → [4]6 + 中 | 2+HK → 4+HK → [4]6+MP | 2820 | 3100 | drive 0 | 7.3 | low | 0/2 pairs reproduced |
| 5 | 5 | 3 + 强 → 2 + 强 → [4]6 + 弱 | 2+HK → 2+HP → [4]6+LP | 2760 | 3000 | drive 0 | 7.3 | low | 0/2 pairs reproduced |
| 6 | 6 | 3 + 强 → 2 + 中 → [4]6 + 强 | 2+HK → 2+MK → [4]6+HP | 2680 | 3000 | drive 0 | 7.3 | low | 0/2 pairs reproduced |
| 7 | 7 | 3 + 强 → 4 + 强 → [4]6 + 弱 | 2+HK → 4+HK → [4]6+LP | 2660 | 2900 | drive 0 | 7.3 | low | 0/2 pairs reproduced |
| 8 | 8 | 强 → 弱 → [4]6 + 强 | HP → LP → [4]6+HP | 2580 | 2900 | drive 0 | 6.3 | low | 0/2 pairs reproduced |
| 9 | 9 | 强 → 2 + 弱 → [4]6 + 强 | HP → 2+LP → [4]6+HP | 2580 | 2900 | drive 0 | 6.8 | low | 0/2 pairs reproduced |
| 10 | 10 | 3 + 强 → 2 + 强 → [4] + SP | 2+HK → 2+HP → [4]6+LP | 2568 | 3000 | drive 0 | 8.0 | low | 0/2 pairs reproduced |
| 11 | 11 | 3 + 强 → 2 + 中 → [4]6 + 中 | 2+HK → 2+MK → [4]6+MP | 2520 | 2800 | drive 0 | 7.3 | low | 0/2 pairs reproduced |
| 12 | 12 | 2 + 强 → [4]6 + 强 | 2+HP → [4]6+HP | 2500 | 2500 | drive 0 | 5.3 | low | 0/1 pairs reproduced |
| 13 | 13 | 3 + 强 → [4]6 + 强 | 2+HK → [4]6+HP | 2500 | 2500 | drive 0 | 5.3 | low | 0/1 pairs reproduced |
| 14 | 14 | 3 + 强 → 弱 → [4]6 + 强 | 2+HK → LP → [4]6+HP | 2480 | 2800 | drive 0 | 6.8 | low | 0/2 pairs reproduced |
| 15 | 15 | 3 + 强 → 2 + 弱 → [4]6 + 强 | 2+HK → 2+LP → [4]6+HP | 2480 | 2800 | drive 0 | 7.3 | low | 0/2 pairs reproduced |
| 16 | 16 | 3 + 强 → 4 + 强 → [4] + SP | 2+HK → 4+HK → [4]6+LP | 2468 | 2900 | drive 0 | 8.0 | low | 0/2 pairs reproduced |
| 17 | 17 | 强 → 弱 → [4]6 + 中 | HP → LP → [4]6+MP | 2420 | 2700 | drive 0 | 6.3 | low | 0/2 pairs reproduced |
| 18 | 18 | 强 → 2 + 弱 → [4]6 + 中 | HP → 2+LP → [4]6+MP | 2420 | 2700 | drive 0 | 6.8 | low | 0/2 pairs reproduced |
| 19 | 19 | 4 + 强 → [4]6 + 强 | 4+HK → [4]6+HP | 2400 | 2400 | drive 0 | 5.3 | low | 0/1 pairs reproduced |
| 20 | 20 | 4 + 强 → 2 + 弱 → [4]6 + 强 | 4+HK → 2+LP → [4]6+HP | 2380 | 2700 | drive 0 | 7.3 | low | 0/2 pairs reproduced |

## Pairs to sweep: 23

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 694 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 3 + 强 → 2 + 强 | `629:manual->621:manual` | 1, 3, 5, 10 | untested | single | medium | 19 |
| 2 | 2 + 强 → [4]6 + 强 | `621:manual->1030:manual` | 1, 12 | untested | single | low | -24 |
| 3 | 3 + 强 → 4 + 强 | `629:manual->651:manual` | 2, 4, 7, 16 | untested | single | medium | 19 |
| 4 | 4 + 强 → [4]6 + 强 | `651:manual->1030:manual` | 2, 19 | untested | single | low | -20 |
| 5 | 2 + 强 → [4]6 + 中 | `621:manual->1024:manual` | 3 | untested | single | low | -20 |
| 6 | 4 + 强 → [4]6 + 中 | `651:manual->1024:manual` | 4 | untested | single | low | -16 |
| 7 | 2 + 强 → [4]6 + 弱 | `621:manual->1018:manual` | 5 | untested | single | low | -14 |
| 8 | 3 + 强 → 2 + 中 | `629:manual->627:manual` | 6, 11 | untested | single | medium | 21 |
| 9 | 2 + 中 → [4]6 + 强 | `627:manual->1030:manual` | 6 | untested | single | low | -26 |
| 10 | 4 + 强 → [4]6 + 弱 | `651:manual->1018:manual` | 7 | untested | single | low | -10 |
| 11 | 强 → 弱 | `606:manual->600:manual` | 8, 17 | untested | single | medium | 0 |
| 12 | 弱 → [4]6 + 强 | `600:manual->1030:manual` | 8, 14 | untested | single | low | -20 |
| 13 | 强 → 2 + 弱 | `606:manual->614:manual` | 9, 18 | untested | single | medium | 1 |
| 14 | 2 + 弱 → [4]6 + 强 | `614:manual->1030:manual` | 9, 15, 20 | untested | single | low | -20 |
| 15 | 2 + 强 → [4] + SP | `621:manual->1018:simple` | 10 | untested | single | low | -14 |
| 16 | 2 + 中 → [4]6 + 中 | `627:manual->1024:manual` | 11 | untested | single | low | -22 |
| 17 | 3 + 强 → [4]6 + 强 | `629:manual->1030:manual` | 13 | untested | single | low | 5 |
| 18 | 3 + 强 → 弱 | `629:manual->600:manual` | 14 | untested | single | medium | 24 |
| 19 | 3 + 强 → 2 + 弱 | `629:manual->614:manual` | 15 | untested | single | medium | 25 |
| 20 | 4 + 强 → [4] + SP | `651:manual->1018:simple` | 16 | untested | single | low | -10 |
| 21 | 弱 → [4]6 + 中 | `600:manual->1024:manual` | 17 | untested | single | low | -16 |
| 22 | 2 + 弱 → [4]6 + 中 | `614:manual->1024:manual` | 18 | untested | single | low | -16 |
| 23 | 4 + 强 → 2 + 弱 | `651:manual->614:manual` | 20 | untested | single | medium | 0 |

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
reframework/data), then pick `plan: no-gauge` in the SWEEP panel's worklist list
(REFRESH if the panel was already open) and START SWEEP. It writes to the same
trial log as the full sweep, so pairs the full sweep already answered under the
same calibration and conditions are skipped, and the other way round.

## Written

- reframework/data/ComboExplorer_data/worklist/mbison-modern-plan-no-gauge.json  (23 pairs, 45374 bytes)
- docs/ComboExplorer/plans/mbison-modern-no-gauge.md
