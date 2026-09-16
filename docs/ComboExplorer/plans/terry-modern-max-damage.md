# Route plan - Terry / modern - max-damage

Generated 2026-09-16T00:26:56Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

- routes found by the search: 699 (search complete: true)

- routes satisfying every condition: 699
- of those, through a pair the policy CONCLUSIVELY rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

Demotion counts conclusive failures only. Under policy `ce-eval-v1` a negative is one when the run pressed a playable input at the right timing; 0 of 0 runs were left out for asking something else, 0 of them negatives. 0 pair(s) changed status because of it.

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 3 + 强 → 236236 + 强 | 2+HK → 236236+P | 4900 | 4900 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs reproduced |
| 2 | 2 | 3 + 强 → 2 + 强 → 236236 + 强 | 2+HK → 2+HP → 236236+P | 4900 | 5700 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs reproduced |
| 3 | 3 | 2 + 强 → 236236 + 强 | 2+HP → 236236+P | 4800 | 4800 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs reproduced |
| 4 | 4 | 3 + 强 → 中 → 236236 + 强 | 2+HK → MP → 236236+P | 4800 | 5600 | SA 1, drive >=0 (1 unknown) | 10.4 | low | 0/2 pairs reproduced |
| 5 | 5 | 中 → 236236 + 强 | MP → 236236+P | 4700 | 4700 | SA 1, drive >=0 (1 unknown) | 8.4 | low | 0/1 pairs reproduced |
| 6 | 6 | 3 + 强 → 2 + 中 → 236236 + 强 | 2+HK → 2+MK → 236236+P | 4600 | 5400 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs reproduced |
| 7 | 7 | 2 + 中 → 236236 + 强 | 2+MK → 236236+P | 4500 | 4500 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs reproduced |
| 8 | 8 | 3 + 强 → 弱 → 236236 + 强 | 2+HK → LP → 236236+P | 4400 | 5200 | SA 1, drive >=0 (1 unknown) | 10.4 | low | 0/2 pairs reproduced |
| 9 | 9 | 3 + 强 → 2 + 弱 → 236236 + 强 | 2+HK → 2+LP → 236236+P | 4400 | 5200 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs reproduced |
| 10 | 10 | 3 + 强 → 2 + 强 → 2 + SP + 强 | 2+HK → 2+HP → 236236+P | 4260 | 5700 | SA 1, drive >=0 (1 unknown) | 8.5 | low | 0/2 pairs reproduced |
| 11 | 11 | 3 + 强 → 中 → 2 + SP + 强 | 2+HK → MP → 236236+P | 4160 | 5600 | SA 1, drive >=0 (1 unknown) | 8.0 | low | 0/2 pairs reproduced |
| 12 | 12 | 3 + 强 → 2 + SP + 强 | 2+HK → 236236+P | 4100 | 4900 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs reproduced |
| 13 | 13 | 2 + 强 → 2 + SP + 强 | 2+HP → 236236+P | 4000 | 4800 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs reproduced |
| 14 | 14 | 3 + 强 → 2 + 中 → 2 + SP + 强 | 2+HK → 2+MK → 236236+P | 3960 | 5400 | SA 1, drive >=0 (1 unknown) | 8.5 | low | 0/2 pairs reproduced |
| 15 | 15 | 中 → 2 + SP + 强 | MP → 236236+P | 3900 | 4700 | SA 1, drive >=0 (1 unknown) | 6.0 | low | 0/1 pairs reproduced |
| 16 | 16 | 弱 → 3 + 强 → 236236 + 强 | LP → 2+HK → 236236+P | 3820 | 5200 | SA 1, drive >=0 (1 unknown) | 10.4 | low | 0/2 pairs reproduced |
| 17 | 17 | 2 + 弱 → 3 + 强 → 236236 + 强 | 2+LP → 2+HK → 236236+P | 3820 | 5200 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs reproduced |
| 18 | 18 | 3 + 强 → 2 + 强 → 214214 + 中 | 2+HK → 2+HP → 214214+P | 3780 | 4300 | SA 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs reproduced |
| 19 | 19 | 3 + 强 → 弱 → 2 + SP + 强 | 2+HK → LP → 236236+P | 3760 | 5200 | SA 1, drive >=0 (1 unknown) | 8.0 | low | 0/2 pairs reproduced |
| 20 | 20 | 3 + 强 → 2 + 弱 → 2 + SP + 强 | 2+HK → 2+LP → 236236+P | 3760 | 5200 | SA 1, drive >=0 (1 unknown) | 8.5 | low | 0/2 pairs reproduced |

## Pairs to sweep: 20

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 409 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 3 + 强 → 236236 + 强 | `638:manual->1230:manual` | 1, 16, 17 | untested | single | low | 32 |
| 2 | 3 + 强 → 2 + 强 | `638:manual->627:manual` | 2, 10, 18 | untested | single | medium | 32 |
| 3 | 2 + 强 → 236236 + 强 | `627:manual->1230:manual` | 2, 3 | untested | single | low | -7 |
| 4 | 3 + 强 → 中 | `638:manual->604:manual` | 4, 11 | untested | single | medium | 33 |
| 5 | 中 → 236236 + 强 | `604:manual->1230:manual` | 4, 5 | untested | single | low | -6 |
| 6 | 3 + 强 → 2 + 中 | `638:manual->635:manual` | 6, 14 | untested | single | medium | 32 |
| 7 | 2 + 中 → 236236 + 强 | `635:manual->1230:manual` | 6, 7 | untested | single | low | -10 |
| 8 | 3 + 强 → 弱 | `638:manual->600:manual` | 8, 19 | untested | single | medium | 36 |
| 9 | 弱 → 236236 + 强 | `600:manual->1230:manual` | 8 | untested | single | low | -4 |
| 10 | 3 + 强 → 2 + 弱 | `638:manual->618:manual` | 9, 20 | untested | single | medium | 36 |
| 11 | 2 + 弱 → 236236 + 强 | `618:manual->1230:manual` | 9 | untested | single | low | -4 |
| 12 | 2 + 强 → 2 + SP + 强 | `627:manual->1230:simple` | 10, 13 | untested | single | low | -7 |
| 13 | 中 → 2 + SP + 强 | `604:manual->1230:simple` | 11, 15 | untested | single | low | -6 |
| 14 | 3 + 强 → 2 + SP + 强 | `638:manual->1230:simple` | 12 | untested | single | low | 32 |
| 15 | 2 + 中 → 2 + SP + 强 | `635:manual->1230:simple` | 14 | untested | single | low | -10 |
| 16 | 弱 → 3 + 强 | `600:manual->638:manual` | 16 | untested | single | medium | -6 |
| 17 | 2 + 弱 → 3 + 强 | `618:manual->638:manual` | 17 | untested | single | medium | -6 |
| 18 | 2 + 强 → 214214 + 中 | `627:manual->1210:manual` | 18 | untested | single | high | -12 |
| 19 | 弱 → 2 + SP + 强 | `600:manual->1230:simple` | 19 | untested | single | low | -4 |
| 20 | 2 + 弱 → 2 + SP + 强 | `618:manual->1230:simple` | 20 | untested | single | low | -4 |

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

- reframework/data/ComboExplorer_data/worklist/terry-modern-plan-max-damage.json  (20 pairs, 11505 bytes)
- docs/ComboExplorer/plans/terry-modern-max-damage.md
