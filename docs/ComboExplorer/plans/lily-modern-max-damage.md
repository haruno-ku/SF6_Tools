# Route plan - Lily / modern - max-damage

Generated 2026-09-16T00:25:53Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

40 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 725 (search complete: true)

- routes satisfying every condition: 725
- of those, through a pair the policy CONCLUSIVELY rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

Demotion counts conclusive failures only. Under policy `ce-eval-v1` a negative is one when the run pressed a playable input at the right timing; 0 of 0 runs were left out for asking something else, 0 of them negatives. 0 pair(s) changed status because of it.

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 4 + 强 → 236236 + 中 | 4+HP → 236236+K | 3600 | 3600 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs reproduced |
| 2 | 2 | 3 + 强 → 4 + 强 → 236236 + 中 | 2+HK → 4+HP → 236236+K | 3530 | 4050 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs reproduced |
| 3 | 3 | 强 → 236236 + 中 | HP → 236236+K | 3500 | 3500 | SA 1, drive >=0 (1 unknown) | 8.4 | low | 0/1 pairs reproduced |
| 4 | 4 | 6 + 强 → 236236 + 中 | 6+HP → 236236+K | 3500 | 3500 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs reproduced |
| 5 | 5 | 3 + 强 → 强 → 236236 + 中 | 2+HK → HP → 236236+K | 3430 | 3950 | SA 1, drive >=0 (1 unknown) | 10.4 | low | 0/2 pairs reproduced |
| 6 | 6 | 3 + 强 → 6 + 强 → 236236 + 中 | 2+HK → 6+HP → 236236+K | 3430 | 3950 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs reproduced |
| 7 | 7 | 4 + 强 → 弱 → 236236 + 中 | 4+HP → LP → 236236+K | 3430 | 3950 | SA 1, drive >=0 (1 unknown) | 10.4 | low | 0/2 pairs reproduced |
| 8 | 8 | 2 + 中 → 236236 + 中 | 2+MP → 236236+K | 3300 | 3300 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs reproduced |
| 9 | 9 | 3 + 强 → 2 + 中 → 236236 + 中 | 2+HK → 2+MP → 236236+K | 3230 | 3750 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs reproduced |
| 10 | 10 | 3 + 强 → 4 + 强 → 236236 + 弱 | 2+HK → 4+HP → 236236+P | 3210 | 3650 | SA 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs reproduced |
| 11 | 11 | 4 + 强 → 236236 + 弱 | 4+HP → 236236+P | 3200 | 3200 | SA 1, drive >=0 (1 unknown) | 8.9 | high | 0/1 pairs reproduced |
| 12 | 12 | 3 + 强 → 4 + 强 → 4 + SP + 强 | 2+HK → 4+HP → 236236+K | 3114 | 4050 | SA 1, drive >=0 (1 unknown) | 8.5 | low | 0/2 pairs reproduced |
| 13 | 13 | 3 + 强 → 强 → 236236 + 弱 | 2+HK → HP → 236236+P | 3110 | 3550 | SA 1, drive >=0 (1 unknown) | 10.4 | medium | 0/2 pairs reproduced |
| 14 | 14 | 3 + 强 → 6 + 强 → 236236 + 弱 | 2+HK → 6+HP → 236236+P | 3110 | 3550 | SA 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs reproduced |
| 15 | 15 | 4 + 强 → 弱 → 236236 + 弱 | 4+HP → LP → 236236+P | 3110 | 3550 | SA 1, drive >=0 (1 unknown) | 10.4 | medium | 0/2 pairs reproduced |
| 16 | 16 | 强 → 236236 + 弱 | HP → 236236+P | 3100 | 3100 | SA 1, drive >=0 (1 unknown) | 8.4 | high | 0/1 pairs reproduced |
| 17 | 17 | 2 + 强 → 236236 + 中 | 2+HP → 236236+K | 3100 | 3100 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs reproduced |
| 18 | 18 | 6 + 强 → 236236 + 弱 | 6+HP → 236236+P | 3100 | 3100 | SA 1, drive >=0 (1 unknown) | 8.9 | high | 0/1 pairs reproduced |
| 19 | 19 | 4 + 强 → 4 + SP + 强 | 4+HP → 236236+K | 3080 | 3600 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs reproduced |
| 20 | 20 | 3 + 强 → 236236 + 中 | 2+HK → 236236+K | 3050 | 3050 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs reproduced |

## Pairs to sweep: 17

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 532 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 4 + 强 → 236236 + 中 | `658:manual->1206:manual` | 1, 2 | untested | single | low | -4 |
| 2 | 3 + 强 → 4 + 强 | `630:manual->658:manual` | 2, 10, 12 | untested | single | medium | 18 |
| 3 | 强 → 236236 + 中 | `606:manual->1206:manual` | 3, 5 | untested | single | low | -9 |
| 4 | 6 + 强 → 236236 + 中 | `653:manual->1206:manual` | 4, 6 | untested | single | low | -7 |
| 5 | 3 + 强 → 强 | `630:manual->606:manual` | 5, 13 | untested | single | medium | 22 |
| 6 | 3 + 强 → 6 + 强 | `630:manual->653:manual` | 6, 14 | untested | single | medium | 16 |
| 7 | 4 + 强 → 弱 | `658:manual->601:manual` | 7, 15 | untested | single | medium | 0 |
| 8 | 弱 → 236236 + 中 | `601:manual->1206:manual` | 7 | untested | single | low | -3 |
| 9 | 2 + 中 → 236236 + 中 | `620:manual->1206:manual` | 8, 9 | untested | single | low | -8 |
| 10 | 3 + 强 → 2 + 中 | `630:manual->620:manual` | 9 | untested | single | medium | 24 |
| 11 | 4 + 强 → 236236 + 弱 | `658:manual->1200:manual` | 10, 11 | untested | single | high | -5 |
| 12 | 4 + 强 → 4 + SP + 强 | `658:manual->1206:simple` | 12, 19 | untested | single | low | -4 |
| 13 | 强 → 236236 + 弱 | `606:manual->1200:manual` | 13, 16 | untested | single | high | -10 |
| 14 | 6 + 强 → 236236 + 弱 | `653:manual->1200:manual` | 14, 18 | untested | single | high | -8 |
| 15 | 弱 → 236236 + 弱 | `601:manual->1200:manual` | 15 | untested | single | high | -4 |
| 16 | 2 + 强 → 236236 + 中 | `622:manual->1206:manual` | 17 | untested | single | low | -9 |
| 17 | 3 + 强 → 236236 + 中 | `630:manual->1206:manual` | 20 | untested | single | low | 23 |

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

- reframework/data/ComboExplorer_data/worklist/lily-modern-plan-max-damage.json  (17 pairs, 10214 bytes)
- docs/ComboExplorer/plans/lily-modern-max-damage.md
