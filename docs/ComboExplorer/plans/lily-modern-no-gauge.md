# Route plan - Lily / modern - no-gauge

Generated 2026-09-16T02:23:31Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

40 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 725 (search complete: true)

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| no_gauge | true | 725 | 212 | 513 | 40 |

- routes satisfying every condition: 513
- of those, through a pair the policy CONCLUSIVELY rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

Demotion counts conclusive failures only. Under policy `ce-eval-v1` a negative is one when the run pressed a playable input at the right timing; 0 of 0 runs were left out for asking something else, 0 of them negatives. 0 pair(s) changed status because of it.

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 3 + 强 → 4 + 强 → 623 + 强 | 2+HK → 4+HP → 623+HP | 2410 | 2650 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 2 | 2 | 3 + 强 → 4 + 强 → 214 + 强 | 2+HK → 4+HP → 214+HP | 2330 | 2550 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 3 | 3 | 3 + 强 → 强 → 623 + 强 | 2+HK → HP → 623+HP | 2310 | 2550 | drive 0 | 7.7 | medium | 0/2 pairs reproduced |
| 4 | 4 | 3 + 强 → 6 + 强 → 623 + 强 | 2+HK → 6+HP → 623+HP | 2310 | 2550 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 5 | 5 | 4 + 强 → 弱 → 623 + 强 | 4+HP → LP → 623+HP | 2310 | 2550 | drive 0 | 7.7 | medium | 0/2 pairs reproduced |
| 6 | 6 | 3 + 强 → 4 + 强 → 236 + 强 | 2+HK → 4+HP → 236+HK | 2250 | 2450 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 7 | 7 | 3 + 强 → 4 + 强 → 623 + 中 | 2+HK → 4+HP → 623+MP | 2250 | 2450 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 8 | 8 | 3 + 强 → 强 → 214 + 强 | 2+HK → HP → 214+HP | 2230 | 2450 | drive 0 | 7.7 | medium | 0/2 pairs reproduced |
| 9 | 9 | 3 + 强 → 6 + 强 → 214 + 强 | 2+HK → 6+HP → 214+HP | 2230 | 2450 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 10 | 10 | 4 + 强 → 弱 → 214 + 强 | 4+HP → LP → 214+HP | 2230 | 2450 | drive 0 | 7.7 | medium | 0/2 pairs reproduced |
| 11 | 11 | 3 + 强 → 4 + 强 → 6 + AUTO + SP | 2+HK → 4+HP → 623+HP | 2218 | 2650 | drive 0 | 8.5 | medium | 0/2 pairs reproduced |
| 12 | 12 | 4 + 强 → 623 + 强 | 4+HP → 623+HP | 2200 | 2200 | drive 0 | 6.2 | high | 0/1 pairs reproduced |
| 13 | 13 | 3 + 强 → 4 + 强 → 214 + 弱 | 2+HK → 4+HP → 214+LP | 2170 | 2350 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 14 | 14 | 3 + 强 → 4 + 强 → 214 + 中 | 2+HK → 4+HP → 214+MP | 2170 | 2350 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 15 | 15 | 3 + 强 → 4 + 强 → 236 + 中 | 2+HK → 4+HP → 236+MK | 2170 | 2350 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 16 | 16 | 3 + 强 → 4 + 强 → 623 + 弱 | 2+HK → 4+HP → 623+LP | 2170 | 2350 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 17 | 17 | 3 + 强 → 强 → 236 + 强 | 2+HK → HP → 236+HK | 2150 | 2350 | drive 0 | 7.7 | medium | 0/2 pairs reproduced |
| 18 | 18 | 3 + 强 → 强 → 623 + 中 | 2+HK → HP → 623+MP | 2150 | 2350 | drive 0 | 7.7 | medium | 0/2 pairs reproduced |
| 19 | 19 | 3 + 强 → 6 + 强 → 236 + 强 | 2+HK → 6+HP → 236+HK | 2150 | 2350 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 20 | 20 | 3 + 强 → 6 + 强 → 623 + 中 | 2+HK → 6+HP → 623+MP | 2150 | 2350 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |

## Pairs to sweep: 23

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 532 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 3 + 强 → 4 + 强 | `630:manual->658:manual` | 1, 2, 6, 7, 11, 13, 14, 15, 16 | untested | single | medium | 18 |
| 2 | 4 + 强 → 623 + 强 | `658:manual->938:manual` | 1, 12 | untested | single | high | -5 |
| 3 | 4 + 强 → 214 + 强 | `658:manual->912:manual` | 2 | untested | single | high | -20 |
| 4 | 3 + 强 → 强 | `630:manual->606:manual` | 3, 8, 17, 18 | untested | single | medium | 22 |
| 5 | 强 → 623 + 强 | `606:manual->938:manual` | 3 | untested | single | high | -10 |
| 6 | 3 + 强 → 6 + 强 | `630:manual->653:manual` | 4, 9, 19, 20 | untested | single | medium | 16 |
| 7 | 6 + 强 → 623 + 强 | `653:manual->938:manual` | 4 | untested | single | high | -8 |
| 8 | 4 + 强 → 弱 | `658:manual->601:manual` | 5, 10 | untested | single | medium | 0 |
| 9 | 弱 → 623 + 强 | `601:manual->938:manual` | 5 | untested | single | high | -4 |
| 10 | 4 + 强 → 236 + 强 | `658:manual->925:manual` | 6 | untested | single | high | -20 |
| 11 | 4 + 强 → 623 + 中 | `658:manual->937:manual` | 7 | untested | single | high | -3 |
| 12 | 强 → 214 + 强 | `606:manual->912:manual` | 8 | untested | single | high | -25 |
| 13 | 6 + 强 → 214 + 强 | `653:manual->912:manual` | 9 | untested | single | high | -23 |
| 14 | 弱 → 214 + 强 | `601:manual->912:manual` | 10 | untested | single | high | -19 |
| 15 | 4 + 强 → 6 + AUTO + SP | `658:manual->938:simple` | 11 | untested | single | high | -5 |
| 16 | 4 + 强 → 214 + 弱 | `658:manual->900:manual` | 13 | untested | single | high | -14 |
| 17 | 4 + 强 → 214 + 中 | `658:manual->907:manual` | 14 | untested | single | high | -18 |
| 18 | 4 + 强 → 236 + 中 | `658:manual->924:manual` | 15 | untested | single | high | -16 |
| 19 | 4 + 强 → 623 + 弱 | `658:manual->936:manual` | 16 | untested | single | high | -1 |
| 20 | 强 → 236 + 强 | `606:manual->925:manual` | 17 | untested | single | high | -25 |
| 21 | 强 → 623 + 中 | `606:manual->937:manual` | 18 | untested | single | high | -8 |
| 22 | 6 + 强 → 236 + 强 | `653:manual->925:manual` | 19 | untested | single | high | -23 |
| 23 | 6 + 强 → 623 + 中 | `653:manual->937:manual` | 20 | untested | single | high | -6 |

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

- reframework/data/ComboExplorer_data/worklist/lily-modern-plan-no-gauge.json  (23 pairs, 46110 bytes)
- docs/ComboExplorer/plans/lily-modern-no-gauge.md
