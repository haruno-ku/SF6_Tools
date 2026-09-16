# Route plan - Dhalsim / modern - starter-chu

Generated 2026-09-16T00:25:40Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

EVERY ROUTE HERE IS A THEORETICAL CANDIDATE. The ranking is a prediction from
the frame data. The worklist below is the smallest set of pairs that lets the
game say whether these routes connect.

## Conditions

- `starter_button` = `M`
- sort: `scaled_damage`, top 20
- search: explore.lua's settings (normal,command_normal -> normal,command_normal,special,od_special,super, manual -> manual,simple, max 3 moves, beam 4000, collapse true)
- Drive Rush Cancel edges in the search: no (pass --drive-rush to route through them)
- demote routes through a rejected pair: yes

`starter_button` keeps a route whose first move has that button with ANY direction
(中 keeps 中, 2 + 中, 3 + 中, 6 + 中). `--starter-neutral` narrows it to no direction.

## Damage figure

Ordered on `offline_score.predicted_damage_scaled`, the combo-scaled prediction.

1082 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 2681 (search complete: false)
  - the beam dropped 1576 partial routes and 0 routes were not emitted, so a route
    satisfying these conditions may be missing

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| starter_button | M | 2681 | 1551 | 1130 | 0 |

- routes satisfying every condition: 1130
- of those, through a pair the policy CONCLUSIVELY rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

Demotion counts conclusive failures only. Under policy `ce-eval-v1` a negative is one when the run pressed a playable input at the right timing; 0 of 0 runs were left out for asking something else, 0 of them negatives. 0 pair(s) changed status because of it.

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 4 + 中 → 236236 + 强 | 4+MP → 236236+K | 4700 | 4700 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs reproduced |
| 2 | 2 | 1 + 中 → 236236 + 强 | 1+MK → 236236+K | 4500 | 4500 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs reproduced |
| 3 | 3 | 4 + 中 → 2 + SP + 强 | 4+MP → 236236+K | 3900 | 4700 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs reproduced |
| 4 | 4 | 1 + 中 → 2 + SP + 强 | 1+MK → 236236+K | 3700 | 4500 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs reproduced |
| 5 | 5 | 4 + 中 → 236236 + 弱 | 4+MP → 236236+MP | 2800 | 2800 | SA 1, drive >=0 (1 unknown) | 8.9 | high | 0/1 pairs reproduced |
| 6 | 6 | 1 + 中 → 236236 + 弱 | 1+MK → 236236+MP | 2600 | 2600 | SA 1, drive >=0 (1 unknown) | 8.9 | high | 0/1 pairs reproduced |
| 7 | 7 | 4 + 中 → SP + 强 | 4+MP → 236236+MP | 2380 | 2800 | SA 1, drive >=0 (1 unknown) | 6.0 | high | 0/1 pairs reproduced |
| 8 | 8 | 1 + 中 → SP + 强 | 1+MK → 236236+MP | 2180 | 2600 | SA 1, drive >=0 (1 unknown) | 6.0 | high | 0/1 pairs reproduced |
| 9 | 9 | 4 + 中 → 2 + SP | 4+MP → 63214+MK | 1660 | 1900 | drive 0 | 6.0 | high | 0/1 pairs reproduced |
| 10 | 10 | 4 + 中 → 3 + SP | 4+MP → 63214+HK | 1660 | 1900 | drive 0 | 6.0 | high | 0/1 pairs reproduced |
| 11 | 11 | 4 + 中 → 1 + SP | 4+MP → 63214+LK | 1500 | 1700 | drive 0 | 6.0 | high | 0/1 pairs reproduced |
| 12 | 12 | 4 + 中 → 63214 + 弱 | 4+MP → 63214+LP | 1500 | 1500 | drive 0 | 8.0 | high | 0/1 pairs reproduced |
| 13 | 13 | 1 + 中 → 2 + SP | 1+MK → 63214+MK | 1460 | 1700 | drive 0 | 6.0 | high | 0/1 pairs reproduced |
| 14 | 14 | 1 + 中 → 3 + SP | 1+MK → 63214+HK | 1460 | 1700 | drive 0 | 6.0 | high | 0/1 pairs reproduced |
| 15 | 15 | 4 + 中 → 4 + SP | 4+MP → 63214+LP | 1340 | 1500 | drive 0 | 6.0 | high | 0/1 pairs reproduced |
| 16 | 16 | 1 + 中 → 1 + SP | 1+MK → 63214+LK | 1300 | 1500 | drive 0 | 6.0 | high | 0/1 pairs reproduced |
| 17 | 17 | 1 + 中 → 63214 + 弱 | 1+MK → 63214+LP | 1300 | 1300 | drive 0 | 8.0 | high | 0/1 pairs reproduced |
| 18 | 18 | 4 + 中 → 236 + 弱 | 4+MP → 236+LP | 1300 | 1300 | drive 0 | 6.2 | high | 0/1 pairs reproduced |
| 19 | 19 | 4 + 中 → 236 + 中 | 4+MP → 236+MP | 1300 | 1300 | drive 0 | 6.2 | high | 0/1 pairs reproduced |
| 20 | 20 | 4 + 中 → 236 + 强 | 4+MP → 236+HP | 1300 | 1300 | drive 0 | 6.2 | high | 0/1 pairs reproduced |

## Pairs to sweep: 20

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 664 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 4 + 中 → 236236 + 强 | `655:manual->1282:manual` | 1 | untested | single | low | -8 |
| 2 | 1 + 中 → 236236 + 强 | `621:manual->1282:manual` | 2 | untested | single | low | -13 |
| 3 | 4 + 中 → 2 + SP + 强 | `655:manual->1282:simple` | 3 | untested | single | low | -8 |
| 4 | 1 + 中 → 2 + SP + 强 | `621:manual->1282:simple` | 4 | untested | single | low | -13 |
| 5 | 4 + 中 → 236236 + 弱 | `655:manual->1203:manual` | 5 | untested | single | high | -8 |
| 6 | 1 + 中 → 236236 + 弱 | `621:manual->1203:manual` | 6 | untested | single | high | -13 |
| 7 | 4 + 中 → SP + 强 | `655:manual->1203:simple` | 7 | untested | single | high | -8 |
| 8 | 1 + 中 → SP + 强 | `621:manual->1203:simple` | 8 | untested | single | high | -13 |
| 9 | 4 + 中 → 2 + SP | `655:manual->938:simple` | 9 | untested | single | high | -13 |
| 10 | 4 + 中 → 3 + SP | `655:manual->939:simple` | 10 | untested | single | high | -15 |
| 11 | 4 + 中 → 1 + SP | `655:manual->937:simple` | 11 | untested | single | high | -10 |
| 12 | 4 + 中 → 63214 + 弱 | `655:manual->966:manual` | 12 | untested | single | high | -14 |
| 13 | 1 + 中 → 2 + SP | `621:manual->938:simple` | 13 | untested | single | high | -18 |
| 14 | 1 + 中 → 3 + SP | `621:manual->939:simple` | 14 | untested | single | high | -20 |
| 15 | 4 + 中 → 4 + SP | `655:manual->966:simple` | 15 | untested | single | high | -14 |
| 16 | 1 + 中 → 1 + SP | `621:manual->937:simple` | 16 | untested | single | high | -15 |
| 17 | 1 + 中 → 63214 + 弱 | `621:manual->966:manual` | 17 | untested | single | high | -19 |
| 18 | 4 + 中 → 236 + 弱 | `655:manual->900:manual` | 18 | untested | single | high | -13 |
| 19 | 4 + 中 → 236 + 中 | `655:manual->904:manual` | 19 | untested | single | high | -13 |
| 20 | 4 + 中 → 236 + 强 | `655:manual->908:manual` | 20 | untested | single | high | -13 |

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

- reframework/data/ComboExplorer_data/worklist/dhalsim-modern-plan-starter-chu.json  (20 pairs, 11575 bytes)
- docs/ComboExplorer/plans/dhalsim-modern-starter-chu.md
