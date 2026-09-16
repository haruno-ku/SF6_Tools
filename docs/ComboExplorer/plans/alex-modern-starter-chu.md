# Route plan - Alex / modern - starter-chu

Generated 2026-09-16T02:36:08Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

EVERY ROUTE HERE IS A THEORETICAL CANDIDATE. The ranking is a prediction from
the frame data. The worklist below is the smallest set of pairs that lets the
game say whether these routes connect.

## Conditions

- `starter_button` = `M`
- sort: `scaled_damage`, top 20
- search: explore.lua's settings (normal,command_normal -> normal,command_normal,special,od_special,super, manual -> manual,simple, max 3 moves, beam 4000, collapse true)
- search complete: false - the beam dropped 1583 partial route(s) and 0 route(s) were not emitted, so the list below is a sample
- Drive Rush Cancel edges in the search: no (pass --drive-rush to route through them)
- demote routes through a rejected pair: yes

`starter_button` keeps a route whose first move has that button with ANY direction
(中 keeps 中, 2 + 中, 3 + 中, 6 + 中). `--starter-neutral` narrows it to no direction.

## Damage figure

Ordered on `offline_score.predicted_damage_scaled`, the combo-scaled prediction.

1 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 777 (search complete: false)
  - the beam dropped 1583 partial routes and 0 routes were not emitted, so a route
    satisfying these conditions may be missing

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| starter_button | M | 777 | 624 | 153 | 0 |

- routes satisfying every condition: 153
- of those, through a pair the policy CONCLUSIVELY rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

Demotion counts conclusive failures only. Under policy `ce-eval-v1` a negative is one when the run pressed a playable input at the right timing; 0 of 0 runs were left out for asking something else, 0 of them negatives. 0 pair(s) changed status because of it.

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 中 → 236236 + 强 | MP → 236236+P | 4600 | 4600 | SA 1, drive >=0 (1 unknown) | 8.4 | low | 0/1 pairs reproduced |
| 2 | 2 | 中 → 弱 → 236236 + 强 | MP → LP → 236236+P | 4100 | 4900 | SA 1, drive >=0 (1 unknown) | 9.9 | low | 0/2 pairs reproduced |
| 3 | 3 | 2 + 中 → 弱 → 236236 + 强 | 2+MK → LP → 236236+P | 4100 | 4900 | SA 1, drive >=0 (1 unknown) | 10.4 | low | 0/2 pairs reproduced |
| 4 | 4 | 2 + 中 → 2 + 弱 → 236236 + 强 | 2+MK → 2+LP → 236236+P | 4100 | 4900 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs reproduced |
| 5 | 5 | 4 + 中 → 弱 → 236236 + 强 | 4+MK → LP → 236236+P | 4100 | 4900 | SA 1, drive >=0 (1 unknown) | 10.4 | low | 0/2 pairs reproduced |
| 6 | 6 | 4 + 中 → 2 + 弱 → 236236 + 强 | 4+MK → 2+LP → 236236+P | 4100 | 4900 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs reproduced |
| 7 | 7 | 中 → 2 + SP + 强 | MP → 236236+P | 3800 | 4600 | SA 1, drive >=0 (1 unknown) | 6.0 | low | 0/1 pairs reproduced |
| 8 | 8 | 中 → 214214 + 中 | MP → 214214+P | 3600 | 3600 | SA 1, drive >=0 (1 unknown) | 8.4 | high | 0/1 pairs reproduced |
| 9 | 9 | 中 → 弱 → 2 + SP + 强 | MP → LP → 236236+P | 3460 | 4900 | SA 1, drive >=0 (1 unknown) | 7.5 | low | 0/2 pairs reproduced |
| 10 | 10 | 2 + 中 → 弱 → 2 + SP + 强 | 2+MK → LP → 236236+P | 3460 | 4900 | SA 1, drive >=0 (1 unknown) | 8.0 | low | 0/2 pairs reproduced |
| 11 | 11 | 2 + 中 → 2 + 弱 → 2 + SP + 强 | 2+MK → 2+LP → 236236+P | 3460 | 4900 | SA 1, drive >=0 (1 unknown) | 8.5 | low | 0/2 pairs reproduced |
| 12 | 12 | 4 + 中 → 弱 → 2 + SP + 强 | 4+MK → LP → 236236+P | 3460 | 4900 | SA 1, drive >=0 (1 unknown) | 8.0 | low | 0/2 pairs reproduced |
| 13 | 13 | 4 + 中 → 2 + 弱 → 2 + SP + 强 | 4+MK → 2+LP → 236236+P | 3460 | 4900 | SA 1, drive >=0 (1 unknown) | 8.5 | low | 0/2 pairs reproduced |
| 14 | 14 | 中 → 弱 → 214214 + 中 | MP → LP → 214214+P | 3300 | 3900 | SA 1, drive >=0 (1 unknown) | 9.9 | medium | 0/2 pairs reproduced |
| 15 | 15 | 2 + 中 → 弱 → 214214 + 中 | 2+MK → LP → 214214+P | 3300 | 3900 | SA 1, drive >=0 (1 unknown) | 10.4 | medium | 0/2 pairs reproduced |
| 16 | 16 | 2 + 中 → 2 + 弱 → 214214 + 中 | 2+MK → 2+LP → 214214+P | 3300 | 3900 | SA 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs reproduced |
| 17 | 17 | 4 + 中 → 弱 → 214214 + 中 | 4+MK → LP → 214214+P | 3300 | 3900 | SA 1, drive >=0 (1 unknown) | 10.4 | medium | 0/2 pairs reproduced |
| 18 | 18 | 4 + 中 → 2 + 弱 → 214214 + 中 | 4+MK → 2+LP → 214214+P | 3300 | 3900 | SA 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs reproduced |
| 19 | 19 | 中 → 4 + SP + 强 | MP → 214214+P | 3000 | 3600 | SA 1, drive >=0 (1 unknown) | 6.0 | high | 0/1 pairs reproduced |
| 20 | 20 | 中 → 弱 → 4 + SP + 强 | MP → LP → 214214+P | 2820 | 3900 | SA 1, drive >=0 (1 unknown) | 7.5 | medium | 0/2 pairs reproduced |

## Pairs to sweep: 16

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 486 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 中 → 236236 + 强 | `604:manual->1230:manual` | 1 | untested | single | low | -8 |
| 2 | 中 → 弱 | `604:manual->600:manual` | 2, 9, 14, 20 | untested | single | medium | 0 |
| 3 | 弱 → 236236 + 强 | `600:manual->1230:manual` | 2, 3, 5 | untested | single | low | -7 |
| 4 | 2 + 中 → 弱 | `638:manual->600:manual` | 3, 10, 15 | untested | single | medium | 1 |
| 5 | 2 + 中 → 2 + 弱 | `638:manual->622:manual` | 4, 11, 16 | untested | single | medium | 0 |
| 6 | 2 + 弱 → 236236 + 强 | `622:manual->1230:manual` | 4, 6 | untested | single | low | -7 |
| 7 | 4 + 中 → 弱 | `671:manual->600:manual` | 5, 12, 17 | untested | single | medium | 1 |
| 8 | 4 + 中 → 2 + 弱 | `671:manual->622:manual` | 6, 13, 18 | untested | single | medium | 0 |
| 9 | 中 → 2 + SP + 强 | `604:manual->1230:simple` | 7 | untested | single | low | -8 |
| 10 | 中 → 214214 + 中 | `604:manual->1208:manual` | 8 | untested | single | high | -9 |
| 11 | 弱 → 2 + SP + 强 | `600:manual->1230:simple` | 9, 10, 12 | untested | single | low | -7 |
| 12 | 2 + 弱 → 2 + SP + 强 | `622:manual->1230:simple` | 11, 13 | untested | single | low | -7 |
| 13 | 弱 → 214214 + 中 | `600:manual->1208:manual` | 14, 15, 17 | untested | single | high | -8 |
| 14 | 2 + 弱 → 214214 + 中 | `622:manual->1208:manual` | 16, 18 | untested | single | high | -8 |
| 15 | 中 → 4 + SP + 强 | `604:manual->1208:simple` | 19 | untested | single | high | -9 |
| 16 | 弱 → 4 + SP + 强 | `600:manual->1208:simple` | 20 | untested | single | high | -8 |

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

- reframework/data/ComboExplorer_data/worklist/alex-modern-plan-starter-chu.json  (16 pairs, 41388 bytes)
- docs/ComboExplorer/plans/alex-modern-starter-chu.md
