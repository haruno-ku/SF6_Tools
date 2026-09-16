# Route plan - Manon / modern - no-gauge

Generated 2026-09-16T02:20:47Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

EVERY ROUTE HERE IS A THEORETICAL CANDIDATE. The ranking is a prediction from
the frame data. The worklist below is the smallest set of pairs that lets the
game say whether these routes connect.

## Conditions

- `no_gauge` = `true`
- sort: `scaled_damage`, top 20
- search: explore.lua's settings (normal,command_normal -> normal,command_normal,special,od_special,super, manual -> manual,simple, max 3 moves, beam 4000, collapse true)
- search complete: true - every route the settings can reach is in the list below
- Drive Rush Cancel edges in the search: no (pass --drive-rush to route through them)
- demote routes through a rejected pair: yes

`no_gauge` removes a route with an OD move, a super, a Drive Rush Cancel, or any
KNOWN Drive or Super spend. A route where some move has no Drive figure is kept and
flagged: nothing in the source says it spends, and a missing value never excludes.

## Damage figure

Ordered on `offline_score.predicted_damage_scaled`, the combo-scaled prediction.

16 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 490 (search complete: true)

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| no_gauge | true | 490 | 142 | 348 | 16 |

- routes satisfying every condition: 348
- of those, through a pair the policy CONCLUSIVELY rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

Demotion counts conclusive failures only. Under policy `ce-eval-v1` a negative is one when the run pressed a playable input at the right timing; 0 of 0 runs were left out for asking something else, 0 of them negatives. 0 pair(s) changed status because of it.

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 3 + 强 → 4 + 强 → 214 + 强 | 2+HK → 4+HP → 214+HK | 2500 | 2700 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 2 | 2 | 3 + 强 → 中 → 214 + 强 | 2+HK → MP → 214+HK | 2300 | 2500 | drive 0 | 7.7 | medium | 0/2 pairs reproduced |
| 3 | 3 | 3 + 强 → 4 + 强 → 214 + 中 | 2+HK → 4+HP → 214+MK | 2020 | 2100 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 4 | 4 | 3 + 强 → 4 + 强 → 236 + 弱 | 2+HK → 4+HP → 236+LK | 2020 | 2100 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 5 | 5 | 3 + 强 → 4 + 强 → 236 + 中 | 2+HK → 4+HP → 236+MK | 2020 | 2100 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 6 | 6 | 3 + 强 → 4 + 强 → 236 + 强 | 2+HK → 4+HP → 236+HK | 2020 | 2100 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 7 | 7 | 3 + 强 → 弱 → 214 + 强 | 2+HK → LP → 214+HK | 2000 | 2200 | drive 0 | 7.7 | medium | 0/2 pairs reproduced |
| 8 | 8 | 3 + 强 → 2 + 弱 → 214 + 强 | 2+HK → 2+LP → 214+HK | 2000 | 2200 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 9 | 9 | 3 + 强 → 4 + 强 → 6 + SP | 2+HK → 4+HP → 236+MK | 1956 | 2100 | drive 0 | 8.0 | medium | 0/2 pairs reproduced |
| 10 | 10 | 3 + 强 → 4 + 强 → 214 + 弱 | 2+HK → 4+HP → 214+LK | 1940 | 2000 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 11 | 11 | 3 + 强 → 弱 → 3 + 强 | 2+HK → LP → 2+HK | 1920 | 2100 | drive 0 | 5.5 | medium | 0/2 pairs reproduced |
| 12 | 12 | 3 + 强 → 2 + 弱 → 3 + 强 | 2+HK → 2+LP → 2+HK | 1920 | 2100 | drive 0 | 6.0 | medium | 0/2 pairs reproduced |
| 13 | 13 | 3 + 强 → 214 + 强 | 2+HK → 214+HK | 1900 | 1900 | drive 0 | 6.2 | medium | 0/1 pairs reproduced |
| 14 | 14 | 3 + 强 → 4 + 强 → 4 + SP | 2+HK → 4+HP → 214+LK | 1892 | 2000 | drive 0 | 8.0 | medium | 0/2 pairs reproduced |
| 15 | 15 | 3 + 强 → 弱 → 强 | 2+HK → LP → HP | 1840 | 2000 | drive 0 | 5.0 | medium | 0/2 pairs reproduced |
| 16 | 16 | 3 + 强 → 弱 → 4 + 强 | 2+HK → LP → 4+HP | 1840 | 2000 | drive 0 | 5.5 | medium | 0/2 pairs reproduced |
| 17 | 17 | 3 + 强 → 2 + 弱 → 强 | 2+HK → 2+LP → HP | 1840 | 2000 | drive 0 | 5.5 | medium | 0/2 pairs reproduced |
| 18 | 18 | 3 + 强 → 2 + 弱 → 4 + 强 | 2+HK → 2+LP → 4+HP | 1840 | 2000 | drive 0 | 6.0 | medium | 0/2 pairs reproduced |
| 19 | 19 | 3 + 强 → 4 + 强 → 6 + AUTO + SP | 2+HK → 4+HP → 236+HP | 1828 | 1900 | drive 0 | 8.5 | medium | 0/2 pairs reproduced |
| 20 | 20 | 3 + 强 → 中 → 214 + 中 | 2+HK → MP → 214+MK | 1820 | 1900 | drive 0 | 7.7 | medium | 0/2 pairs reproduced |

## Pairs to sweep: 24

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 343 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 3 + 强 → 4 + 强 | `643:manual->665:manual` | 1, 3, 4, 5, 6, 9, 10, 14, 19 | untested | single | medium | 21 |
| 2 | 4 + 强 → 214 + 强 | `665:manual->1003:manual` | 1 | untested | single | high | -17 |
| 3 | 3 + 强 → 中 | `643:manual->605:manual` | 2, 20 | untested | single | medium | 22 |
| 4 | 中 → 214 + 强 | `605:manual->1003:manual` | 2 | untested | single | high | -18 |
| 5 | 4 + 强 → 214 + 中 | `665:manual->1002:manual` | 3 | untested | single | high | -13 |
| 6 | 4 + 强 → 236 + 弱 | `665:manual->1007:manual` | 4 | untested | single | high | -6 |
| 7 | 4 + 强 → 236 + 中 | `665:manual->1008:manual` | 5 | untested | single | high | -8 |
| 8 | 4 + 强 → 236 + 强 | `665:manual->1009:manual` | 6 | untested | single | high | -11 |
| 9 | 3 + 强 → 弱 | `643:manual->600:manual` | 7, 11, 15, 16 | untested | single | medium | 25 |
| 10 | 弱 → 214 + 强 | `600:manual->1003:manual` | 7 | untested | single | high | -16 |
| 11 | 3 + 强 → 2 + 弱 | `643:manual->625:manual` | 8, 12, 17, 18 | untested | single | medium | 25 |
| 12 | 2 + 弱 → 214 + 强 | `625:manual->1003:manual` | 8 | untested | single | high | -17 |
| 13 | 4 + 强 → 6 + SP | `665:manual->1008:simple` | 9 | untested | single | high | -8 |
| 14 | 4 + 强 → 214 + 弱 | `665:manual->1001:manual` | 10 | untested | single | high | -13 |
| 15 | 弱 → 3 + 强 | `600:manual->643:manual` | 11 | untested | single | medium | -7 |
| 16 | 2 + 弱 → 3 + 强 | `625:manual->643:manual` | 12 | untested | single | medium | -8 |
| 17 | 3 + 强 → 214 + 强 | `643:manual->1003:manual` | 13 | untested | single | medium | 9 |
| 18 | 4 + 强 → 4 + SP | `665:manual->1001:simple` | 14 | untested | single | high | -13 |
| 19 | 弱 → 强 | `600:manual->609:manual` | 15 | untested | single | medium | -6 |
| 20 | 弱 → 4 + 强 | `600:manual->665:manual` | 16 | untested | single | medium | -4 |
| 21 | 2 + 弱 → 强 | `625:manual->609:manual` | 17 | untested | single | medium | -7 |
| 22 | 2 + 弱 → 4 + 强 | `625:manual->665:manual` | 18 | untested | single | medium | -5 |
| 23 | 4 + 强 → 6 + AUTO + SP | `665:manual->1028:simple` | 19 | untested | single | high | -26 |
| 24 | 中 → 214 + 中 | `605:manual->1002:manual` | 20 | untested | single | high | -14 |

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

- reframework/data/ComboExplorer_data/worklist/manon-modern-plan-no-gauge.json  (24 pairs, 46306 bytes)
- docs/ComboExplorer/plans/manon-modern-no-gauge.md
