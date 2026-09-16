# Route plan - Blanka / modern - no-gauge

Generated 2026-09-16T02:28:45Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

EVERY ROUTE HERE IS A THEORETICAL CANDIDATE. The ranking is a prediction from
the frame data. The worklist below is the smallest set of pairs that lets the
game say whether these routes connect.

## Conditions

- `no_gauge` = `true`
- sort: `scaled_damage`, top 20
- search: explore.lua's settings (normal,command_normal -> normal,command_normal,special,od_special,super, manual -> manual,simple, max 3 moves, beam 4000, collapse true)
- search complete: false - the beam dropped 1267 partial route(s) and 0 route(s) were not emitted, so the list below is a sample
- Drive Rush Cancel edges in the search: no (pass --drive-rush to route through them)
- demote routes through a rejected pair: yes

`no_gauge` removes a route with an OD move, a super, a Drive Rush Cancel, or any
KNOWN Drive or Super spend. A route where some move has no Drive figure is kept and
flagged: nothing in the source says it spends, and a missing value never excludes.

## Damage figure

Ordered on `offline_score.predicted_damage_scaled`, the combo-scaled prediction.

936 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 2105 (search complete: false)
  - the beam dropped 1267 partial routes and 0 routes were not emitted, so a route
    satisfying these conditions may be missing

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| no_gauge | true | 2105 | 649 | 1456 | 936 |

- routes satisfying every condition: 1456
- of those, through a pair the policy CONCLUSIVELY rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

Demotion counts conclusive failures only. Under policy `ce-eval-v1` a negative is one when the run pressed a playable input at the right timing; 0 of 0 runs were left out for asking something else, 0 of them negatives. 0 pair(s) changed status because of it.

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 6 + 强 → 3 + 强 → [2]8 + 强 | 6+HP → 3+HP → [2]8+HK | 3220 | 3500 | drive 0 | 7.3 | low | 0/2 pairs reproduced |
| 2 | 2 | 3 + 强 → 6 + 强 → [2]8 + 强 | 3+HP → 6+HP → [2]8+HK | 3220 | 3500 | drive 0 | 7.3 | low | 0/2 pairs reproduced |
| 3 | 3 | 6 + 强 → 3 + 强 → [4]6 + 强 | 6+HP → 3+HP → [4]6+HP | 3140 | 3400 | drive 0 | 7.3 | low | 0/2 pairs reproduced |
| 4 | 4 | 6 + 强 → 3 + 强 → [2]8 + 中 | 6+HP → 3+HP → [2]8+MK | 3140 | 3400 | drive 0 | 7.3 | low | 0/2 pairs reproduced |
| 5 | 5 | 3 + 强 → 6 + 强 → [4]6 + 强 | 3+HP → 6+HP → [4]6+HP | 3140 | 3400 | drive 0 | 7.3 | low | 0/2 pairs reproduced |
| 6 | 6 | 3 + 强 → 6 + 强 → [2]8 + 中 | 3+HP → 6+HP → [2]8+MK | 3140 | 3400 | drive 0 | 7.3 | low | 0/2 pairs reproduced |
| 7 | 7 | 6 + 强 → 3 + 强 → [4]6 + 中 | 6+HP → 3+HP → [4]6+MP | 3060 | 3300 | drive 0 | 7.3 | low | 0/2 pairs reproduced |
| 8 | 8 | 6 + 强 → 3 + 强 → [2]8 + 弱 | 6+HP → 3+HP → [2]8+LK | 3060 | 3300 | drive 0 | 7.3 | low | 0/2 pairs reproduced |
| 9 | 9 | 3 + 强 → 6 + 强 → [4]6 + 中 | 3+HP → 6+HP → [4]6+MP | 3060 | 3300 | drive 0 | 7.3 | low | 0/2 pairs reproduced |
| 10 | 10 | 3 + 强 → 6 + 强 → [2]8 + 弱 | 3+HP → 6+HP → [2]8+LK | 3060 | 3300 | drive 0 | 7.3 | low | 0/2 pairs reproduced |
| 11 | 11 | 6 + 强 → 3 + 强 → 6 + 强 | 6+HP → 3+HP → 6+HP | 2980 | 3200 | drive 0 | 6.0 | medium | 0/2 pairs reproduced |
| 12 | 12 | 6 + 强 → 3 + 强 → [4]6 + 弱 | 6+HP → 3+HP → [4]6+LP | 2900 | 3100 | drive 0 | 7.3 | low | 0/2 pairs reproduced |
| 13 | 13 | 3 + 强 → 6 + 强 → 3 + 强 | 3+HP → 6+HP → 3+HP | 2900 | 3100 | drive 0 | 6.0 | medium | 0/2 pairs reproduced |
| 14 | 14 | 3 + 强 → 6 + 强 → [4]6 + 弱 | 3+HP → 6+HP → [4]6+LP | 2900 | 3100 | drive 0 | 7.3 | low | 0/2 pairs reproduced |
| 15 | 15 | 6 + 强 → 3 + 强 → [4] + SP | 6+HP → 3+HP → [4]6+MP | 2868 | 3300 | drive 0 | 8.0 | low | 0/2 pairs reproduced |
| 16 | 16 | 6 + 强 → 3 + 强 → [2] + SP | 6+HP → 3+HP → [2]8+LK | 2868 | 3300 | drive 0 | 8.0 | low | 0/2 pairs reproduced |
| 17 | 17 | 3 + 强 → 6 + 强 → [4] + SP | 3+HP → 6+HP → [4]6+MP | 2868 | 3300 | drive 0 | 8.0 | low | 0/2 pairs reproduced |
| 18 | 18 | 3 + 强 → 6 + 强 → [2] + SP | 3+HP → 6+HP → [2]8+LK | 2868 | 3300 | drive 0 | 8.0 | low | 0/2 pairs reproduced |
| 19 | 19 | 6 + 强 → 中 → [2]8 + 强 | 6+HP → MK → [2]8+HK | 2820 | 3100 | drive 0 | 6.8 | low | 0/2 pairs reproduced |
| 20 | 20 | 6 + 强 → 4 + 中 → [2]8 + 强 | 6+HP → 4+MK → [2]8+HK | 2820 | 3100 | drive 0 | 7.3 | low | 0/2 pairs reproduced |

## Pairs to sweep: 22

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 532 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 6 + 强 → 3 + 强 | `644:manual->646:manual` | 1, 3, 4, 7, 8, 11, 12, 13, 15, 16 | untested | single | medium | 13 |
| 2 | 3 + 强 → [2]8 + 强 | `646:manual->984:manual` | 1 | untested | single | low | 21 |
| 3 | 3 + 强 → 6 + 强 | `646:manual->644:manual` | 2, 5, 6, 9, 10, 11, 13, 14, 17, 18 | untested | single | medium | 11 |
| 4 | 6 + 强 → [2]8 + 强 | `644:manual->984:manual` | 2 | untested | single | low | 19 |
| 5 | 3 + 强 → [4]6 + 强 | `646:manual->873:manual` | 3 | untested | single | low | 7 |
| 6 | 3 + 强 → [2]8 + 中 | `646:manual->975:manual` | 4 | untested | single | low | 21 |
| 7 | 6 + 强 → [4]6 + 强 | `644:manual->873:manual` | 5 | untested | single | low | 5 |
| 8 | 6 + 强 → [2]8 + 中 | `644:manual->975:manual` | 6 | untested | single | low | 19 |
| 9 | 3 + 强 → [4]6 + 中 | `646:manual->867:manual` | 7 | untested | single | low | 17 |
| 10 | 3 + 强 → [2]8 + 弱 | `646:manual->971:manual` | 8 | untested | single | low | 21 |
| 11 | 6 + 强 → [4]6 + 中 | `644:manual->867:manual` | 9 | untested | single | low | 15 |
| 12 | 6 + 强 → [2]8 + 弱 | `644:manual->971:manual` | 10 | untested | single | low | 19 |
| 13 | 3 + 强 → [4]6 + 弱 | `646:manual->859:manual` | 12 | untested | single | low | 19 |
| 14 | 6 + 强 → [4]6 + 弱 | `644:manual->859:manual` | 14 | untested | single | low | 17 |
| 15 | 3 + 强 → [4] + SP | `646:manual->867:simple` | 15 | untested | single | low | 17 |
| 16 | 3 + 强 → [2] + SP | `646:manual->971:simple` | 16 | untested | single | low | 21 |
| 17 | 6 + 强 → [4] + SP | `644:manual->867:simple` | 17 | untested | single | low | 15 |
| 18 | 6 + 强 → [2] + SP | `644:manual->971:simple` | 18 | untested | single | low | 19 |
| 19 | 6 + 强 → 中 | `644:manual->609:manual` | 19 | untested | single | medium | 19 |
| 20 | 中 → [2]8 + 强 | `609:manual->984:manual` | 19 | untested | single | low | -3 |
| 21 | 6 + 强 → 4 + 中 | `644:manual->642:manual` | 20 | untested | single | medium | 18 |
| 22 | 4 + 中 → [2]8 + 强 | `642:manual->984:manual` | 20 | untested | single | low | 0 |

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

- reframework/data/ComboExplorer_data/worklist/blanka-modern-plan-no-gauge.json  (22 pairs, 45459 bytes)
- docs/ComboExplorer/plans/blanka-modern-no-gauge.md
