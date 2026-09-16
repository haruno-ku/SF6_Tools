# Route plan - Alex / modern - no-gauge

Generated 2026-09-16T02:36:02Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

EVERY ROUTE HERE IS A THEORETICAL CANDIDATE. The ranking is a prediction from
the frame data. The worklist below is the smallest set of pairs that lets the
game say whether these routes connect.

## Conditions

- `no_gauge` = `true`
- sort: `scaled_damage`, top 20
- search: explore.lua's settings (normal,command_normal -> normal,command_normal,special,od_special,super, manual -> manual,simple, max 3 moves, beam 4000, collapse true)
- search complete: false - the beam dropped 1583 partial route(s) and 0 route(s) were not emitted, so the list below is a sample
- Drive Rush Cancel edges in the search: no (pass --drive-rush to route through them)
- demote routes through a rejected pair: yes

`no_gauge` removes a route with an OD move, a super, a Drive Rush Cancel, or any
KNOWN Drive or Super spend. A route where some move has no Drive figure is kept and
flagged: nothing in the source says it spends, and a missing value never excludes.

## Damage figure

Ordered on `offline_score.predicted_damage_scaled`, the combo-scaled prediction.

5 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 777 (search complete: false)
  - the beam dropped 1583 partial routes and 0 routes were not emitted, so a route
    satisfying these conditions may be missing

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| no_gauge | true | 777 | 269 | 508 | 5 |

- routes satisfying every condition: 508
- of those, through a pair the policy CONCLUSIVELY rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

Demotion counts conclusive failures only. Under policy `ce-eval-v1` a negative is one when the run pressed a playable input at the right timing; 0 of 0 runs were left out for asking something else, 0 of them negatives. 0 pair(s) changed status because of it.

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 2 + 强 → 3 + 强 → 623 + 强 | 2+HK → 2+HK → 623+HK | 3200 | 3500 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 2 | 2 | 3 + 强 → 2 + 强 → 623 + 强 | 2+HK → 2+HK → 623+HK | 3200 | 3500 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 3 | 3 | 2 + 强 → 3 + 强 → 623 + 中 | 2+HK → 2+HK → 623+MK | 3120 | 3400 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 4 | 4 | 3 + 强 → 2 + 强 → 623 + 中 | 2+HK → 2+HK → 623+MK | 3120 | 3400 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 5 | 5 | 2 + 强 → 2 + 强 → 623 + 强 | 2+HK → 2+HP → 623+HK | 3000 | 3300 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 6 | 6 | 2 + 强 → 3 + 强 → 623 + 弱 | 2+HK → 2+HK → 623+LK | 2960 | 3200 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 7 | 7 | 2 + 强 → 3 + 强 → 2 + SP | 2+HK → 2+HK → 623+HK | 2960 | 3500 | drive 0 | 8.0 | medium | 0/2 pairs reproduced |
| 8 | 8 | 3 + 强 → 2 + 强 → 623 + 弱 | 2+HK → 2+HK → 623+LK | 2960 | 3200 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 9 | 9 | 3 + 强 → 2 + 强 → 2 + SP | 2+HK → 2+HK → 623+HK | 2960 | 3500 | drive 0 | 8.0 | medium | 0/2 pairs reproduced |
| 10 | 10 | 2 + 强 → 2 + 强 → 623 + 中 | 2+HK → 2+HP → 623+MK | 2920 | 3200 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 11 | 11 | 2 + 强 → 3 + 强 → 236 + 强 | 2+HK → 2+HK → 236+HP | 2880 | 3100 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 12 | 12 | 3 + 强 → 2 + 强 → 236 + 强 | 2+HK → 2+HK → 236+HP | 2880 | 3100 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 13 | 13 | 2 + 强 → 中 → 623 + 强 | 2+HK → MP → 623+HK | 2800 | 3100 | drive 0 | 7.7 | medium | 0/2 pairs reproduced |
| 14 | 14 | 2 + 强 → 3 + 强 → 2 + 强 | 2+HK → 2+HK → 2+HK | 2800 | 3000 | drive 0 | 6.0 | medium | 0/2 pairs reproduced |
| 15 | 15 | 2 + 强 → 3 + 强 → 236 + 中 | 2+HK → 2+HK → 236+MP | 2800 | 3000 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 16 | 16 | 3 + 强 → 中 → 623 + 强 | 2+HK → MP → 623+HK | 2800 | 3100 | drive 0 | 7.7 | medium | 0/2 pairs reproduced |
| 17 | 17 | 3 + 强 → 2 + 强 → 3 + 强 | 2+HK → 2+HK → 2+HK | 2800 | 3000 | drive 0 | 6.0 | medium | 0/2 pairs reproduced |
| 18 | 18 | 3 + 强 → 2 + 强 → 236 + 中 | 2+HK → 2+HK → 236+MP | 2800 | 3000 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 19 | 19 | 2 + 强 → 3 + 强 → 6 + SP | 2+HK → 2+HK → 623+LK | 2768 | 3200 | drive 0 | 8.0 | medium | 0/2 pairs reproduced |
| 20 | 20 | 3 + 强 → 2 + 强 → 6 + SP | 2+HK → 2+HK → 623+LK | 2768 | 3200 | drive 0 | 8.0 | medium | 0/2 pairs reproduced |

## Pairs to sweep: 22

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 486 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 2 + 强 → 3 + 强 | `636:manual->640:manual` | 1, 3, 6, 7, 11, 14, 15, 17, 19 | untested | single | medium | 19 |
| 2 | 3 + 强 → 623 + 强 | `640:manual->939:manual` | 1 | untested | single | medium | 15 |
| 3 | 3 + 强 → 2 + 强 | `640:manual->636:manual` | 2, 4, 8, 9, 12, 14, 17, 18, 20 | untested | single | medium | 19 |
| 4 | 2 + 强 → 623 + 强 | `636:manual->939:manual` | 2 | untested | single | medium | 15 |
| 5 | 3 + 强 → 623 + 中 | `640:manual->938:manual` | 3 | untested | single | medium | 21 |
| 6 | 2 + 强 → 623 + 中 | `636:manual->938:manual` | 4 | untested | single | medium | 21 |
| 7 | 2 + 强 → 2 + 强 | `636:manual->628:manual` | 5, 10 | untested | single | medium | 20 |
| 8 | 2 + 强 → 623 + 强 | `628:manual->939:manual` | 5 | untested | single | high | -17 |
| 9 | 3 + 强 → 623 + 弱 | `640:manual->937:manual` | 6 | untested | single | medium | 23 |
| 10 | 3 + 强 → 2 + SP | `640:manual->939:simple` | 7 | untested | single | medium | 15 |
| 11 | 2 + 强 → 623 + 弱 | `636:manual->937:manual` | 8 | untested | single | medium | 23 |
| 12 | 2 + 强 → 2 + SP | `636:manual->939:simple` | 9 | untested | single | medium | 15 |
| 13 | 2 + 强 → 623 + 中 | `628:manual->938:manual` | 10 | untested | single | high | -11 |
| 14 | 3 + 强 → 236 + 强 | `640:manual->902:manual` | 11 | untested | single | medium | 3 |
| 15 | 2 + 强 → 236 + 强 | `636:manual->902:manual` | 12 | untested | single | medium | 3 |
| 16 | 2 + 强 → 中 | `636:manual->604:manual` | 13 | untested | single | medium | 22 |
| 17 | 中 → 623 + 强 | `604:manual->939:manual` | 13, 16 | untested | single | high | -10 |
| 18 | 3 + 强 → 236 + 中 | `640:manual->901:manual` | 15 | untested | single | medium | 12 |
| 19 | 3 + 强 → 中 | `640:manual->604:manual` | 16 | untested | single | medium | 22 |
| 20 | 2 + 强 → 236 + 中 | `636:manual->901:manual` | 18 | untested | single | medium | 12 |
| 21 | 3 + 强 → 6 + SP | `640:manual->937:simple` | 19 | untested | single | medium | 23 |
| 22 | 2 + 强 → 6 + SP | `636:manual->937:simple` | 20 | untested | single | medium | 23 |

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

- reframework/data/ComboExplorer_data/worklist/alex-modern-plan-no-gauge.json  (22 pairs, 45427 bytes)
- docs/ComboExplorer/plans/alex-modern-no-gauge.md
