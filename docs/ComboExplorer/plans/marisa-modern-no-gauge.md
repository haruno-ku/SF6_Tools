# Route plan - Marisa / modern - no-gauge

Generated 2026-09-16T00:26:21Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

EVERY ROUTE HERE IS A THEORETICAL CANDIDATE. The ranking is a prediction from
the frame data. The worklist below is the smallest set of pairs that lets the
game say whether these routes connect.

## Conditions

- `no_gauge` = `true`
- sort: `scaled_damage`, top 20
- search: explore.lua's settings (normal,command_normal -> normal,command_normal,special,od_special,super, manual -> manual,simple, max 3 moves, beam 4000, collapse true)
- Drive Rush Cancel edges in the search: no (pass --drive-rush to route through them)
- demote routes through a rejected pair: yes

`no_gauge` removes a route with an OD move, a super, a Drive Rush Cancel, or any
KNOWN Drive or Super spend. A route where some move has no Drive figure is kept and
flagged: nothing in the source says it spends, and a missing value never excludes.

## Damage figure

Ordered on `offline_score.predicted_damage_scaled`, the combo-scaled prediction.

96 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 803 (search complete: true)

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| no_gauge | true | 803 | 252 | 551 | 96 |

- routes satisfying every condition: 551
- of those, through a pair the policy CONCLUSIVELY rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

Demotion counts conclusive failures only. Under policy `ce-eval-v1` a negative is one when the run pressed a playable input at the right timing; 0 of 0 runs were left out for asking something else, 0 of them negatives. 0 pair(s) changed status because of it.

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 3 + 强 → 2 + 强 → 623 + 强 | 2+HK → 2+HP → 623+HP | 3260 | 3600 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 2 | 2 | 3 + 强 → 6 + 强 → 623 + 强 | 2+HK → 6+HK → 623+HP | 3260 | 3600 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 3 | 3 | 3 + 强 → 4 + 强 → 623 + 强 | 2+HK → 4+HP → 623+HP | 3260 | 3600 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 4 | 4 | 2 + 强 → 3 + 强 → 236 + 强 | 2+HP → 2+HK → 236+HP | 3180 | 3500 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 5 | 5 | 2 + 强 → 3 + 强 → 623 + 中 | 2+HP → 2+HK → 623+MP | 3180 | 3500 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 6 | 6 | 3 + 强 → 2 + 强 → 236 + 强 | 2+HK → 2+HP → 236+HP | 3180 | 3500 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 7 | 7 | 3 + 强 → 2 + 强 → 623 + 中 | 2+HK → 2+HP → 623+MP | 3180 | 3500 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 8 | 8 | 3 + 强 → 6 + 强 → 236 + 强 | 2+HK → 6+HK → 236+HP | 3180 | 3500 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 9 | 9 | 3 + 强 → 6 + 强 → 623 + 中 | 2+HK → 6+HK → 623+MP | 3180 | 3500 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 10 | 10 | 3 + 强 → 4 + 强 → 236 + 强 | 2+HK → 4+HP → 236+HP | 3180 | 3500 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 11 | 11 | 3 + 强 → 4 + 强 → 623 + 中 | 2+HK → 4+HP → 623+MP | 3180 | 3500 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 12 | 12 | 2 + 强 → 6 + 强 → 623 + 强 | 2+HP → 6+HK → 623+HP | 3160 | 3500 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 13 | 13 | 2 + 强 → 4 + 强 → 623 + 强 | 2+HP → 4+HP → 623+HP | 3160 | 3500 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 14 | 14 | 2 + 强 → 3 + 强 → 623 + 弱 | 2+HP → 2+HK → 623+LP | 3100 | 3400 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 15 | 15 | 3 + 强 → 2 + 强 → 623 + 弱 | 2+HK → 2+HP → 623+LP | 3100 | 3400 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 16 | 16 | 3 + 强 → 6 + 强 → 623 + 弱 | 2+HK → 6+HK → 623+LP | 3100 | 3400 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 17 | 17 | 3 + 强 → 4 + 强 → 623 + 弱 | 2+HK → 4+HP → 623+LP | 3100 | 3400 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 18 | 18 | 2 + 强 → 6 + 强 → 236 + 强 | 2+HP → 6+HK → 236+HP | 3080 | 3400 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 19 | 19 | 2 + 强 → 6 + 强 → 623 + 中 | 2+HP → 6+HK → 623+MP | 3080 | 3400 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 20 | 20 | 2 + 强 → 4 + 强 → 236 + 强 | 2+HP → 4+HP → 236+HP | 3080 | 3400 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |

## Pairs to sweep: 21

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 313 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 3 + 强 → 2 + 强 | `639:manual->627:manual` | 1, 6, 7, 15 | untested | single | medium | 20 |
| 2 | 2 + 强 → 623 + 强 | `627:manual->938:manual` | 1 | untested | single | medium | 3 |
| 3 | 3 + 强 → 6 + 强 | `639:manual->671:manual` | 2, 8, 9, 16 | untested | single | medium | 15 |
| 4 | 6 + 强 → 623 + 强 | `671:manual->938:manual` | 2, 12 | untested | single | high | -28 |
| 5 | 3 + 强 → 4 + 强 | `639:manual->686:manual` | 3, 10, 11, 17 | untested | single | medium | 21 |
| 6 | 4 + 强 → 623 + 强 | `686:manual->938:manual` | 3, 13 | untested | single | high | -29 |
| 7 | 2 + 强 → 3 + 强 | `627:manual->639:manual` | 4, 5, 14 | untested | single | medium | 24 |
| 8 | 3 + 强 → 236 + 强 | `639:manual->902:manual` | 4 | untested | single | medium | 7 |
| 9 | 3 + 强 → 623 + 中 | `639:manual->937:manual` | 5 | untested | single | medium | 1 |
| 10 | 2 + 强 → 236 + 强 | `627:manual->902:manual` | 6 | untested | single | medium | 13 |
| 11 | 2 + 强 → 623 + 中 | `627:manual->937:manual` | 7 | untested | single | medium | 7 |
| 12 | 6 + 强 → 236 + 强 | `671:manual->902:manual` | 8, 18 | untested | single | high | -18 |
| 13 | 6 + 强 → 623 + 中 | `671:manual->937:manual` | 9, 19 | untested | single | high | -24 |
| 14 | 4 + 强 → 236 + 强 | `686:manual->902:manual` | 10, 20 | untested | single | high | -19 |
| 15 | 4 + 强 → 623 + 中 | `686:manual->937:manual` | 11 | untested | single | high | -25 |
| 16 | 2 + 强 → 6 + 强 | `627:manual->671:manual` | 12, 18, 19 | untested | single | medium | 21 |
| 17 | 2 + 强 → 4 + 强 | `627:manual->686:manual` | 13, 20 | untested | single | medium | 27 |
| 18 | 3 + 强 → 623 + 弱 | `639:manual->936:manual` | 14 | untested | single | medium | 4 |
| 19 | 2 + 强 → 623 + 弱 | `627:manual->936:manual` | 15 | untested | single | medium | 10 |
| 20 | 6 + 强 → 623 + 弱 | `671:manual->936:manual` | 16 | untested | single | high | -21 |
| 21 | 4 + 强 → 623 + 弱 | `686:manual->936:manual` | 17 | untested | single | high | -22 |

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

- reframework/data/ComboExplorer_data/worklist/marisa-modern-plan-no-gauge.json  (21 pairs, 11972 bytes)
- docs/ComboExplorer/plans/marisa-modern-no-gauge.md
