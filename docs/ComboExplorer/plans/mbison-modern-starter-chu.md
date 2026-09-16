# Route plan - MBison / modern - starter-chu

Generated 2026-09-16T00:27:05Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

317 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 1368 (search complete: false)
  - the beam dropped 3257 partial routes and 0 routes were not emitted, so a route
    satisfying these conditions may be missing

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| starter_button | M | 1368 | 1028 | 340 | 0 |

- routes satisfying every condition: 340
- of those, through a pair the policy CONCLUSIVELY rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

Demotion counts conclusive failures only. Under policy `ce-eval-v1` a negative is one when the run pressed a playable input at the right timing; 0 of 0 runs were left out for asking something else, 0 of them negatives. 0 pair(s) changed status because of it.

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 2 + 中 → 236236 + 强 | 2+MK → 236236+P | 4500 | 4500 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs reproduced |
| 2 | 2 | 2 + 中 → 2 + SP + 强 | 2+MK → 236236+P | 3700 | 4500 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs reproduced |
| 3 | 3 | 2 + 中 → 214214 + 中 | 2+MK → 214214+K | 3500 | 3500 | SA 1, drive >=0 (1 unknown) | 8.9 | high | 0/1 pairs reproduced |
| 4 | 4 | 2 + 中 → 22 + 弱 + 中 + 强 | 2+MK → 214214+P | 3500 | 3500 | SA 1, drive >=0 (1 unknown) | 6.3 | high | 0/1 pairs reproduced |
| 5 | 5 | 2 + 中 → 4 + SP + 强 | 2+MK → 214214+K | 2900 | 3500 | SA 1, drive >=0 (1 unknown) | 6.5 | high | 0/1 pairs reproduced |
| 6 | 6 | 2 + 中 → 236236 + 弱 | 2+MK → 236236+K | 2500 | 2500 | SA 1, drive >=0 (1 unknown) | 8.9 | high | 0/1 pairs reproduced |
| 7 | 7 | 2 + 中 → [4]6 + 强 | 2+MK → [4]6+HP | 2100 | 2100 | drive 0 | 5.3 | low | 0/1 pairs reproduced |
| 8 | 8 | 2 + 中 → SP + 强 | 2+MK → 236236+K | 2100 | 2500 | SA 1, drive >=0 (1 unknown) | 6.0 | high | 0/1 pairs reproduced |
| 9 | 9 | 2 + 中 → [4]6 + 中 | 2+MK → [4]6+MP | 1900 | 1900 | drive 0 | 5.3 | low | 0/1 pairs reproduced |
| 10 | 10 | 2 + 中 → [4]6 + 弱 | 2+MK → [4]6+LP | 1700 | 1700 | drive 0 | 5.3 | low | 0/1 pairs reproduced |
| 11 | 11 | 2 + 中 → [4] + SP | 2+MK → [4]6+LP | 1460 | 1700 | drive 0 | 6.0 | low | 0/1 pairs reproduced |
| 12 | 12 | 2 + 中 → 2 + AUTO + SP | 2+MK → 623+PP | 1460 | 1700 | OD 1, drive 0 | 6.5 | high | 0/1 pairs reproduced |
| 13 | 13 | 2 + 中 → 236 + 强 | 2+MK → 236+HK | 1000 | 1000 | drive 0 | 6.2 | high | 0/1 pairs reproduced |
| 14 | 14 | 2 + 中 → [4] + AUTO + SP | 2+MK → [4]6+PP | 820 | 900 | OD 1, drive 20000 | 6.5 | low | 0/1 pairs reproduced |
| 15 | 15 | 2 + 中 → AUTO + SP | 2+MK → 214+PP | 820 | 900 | OD 1, drive 20000 | 6.0 | low | 0/1 pairs reproduced |
| 16 | 16 | 2 + 中 → 236 + 弱 | 2+MK → 236+LK | 800 | 800 | drive 0 | 6.2 | high | 0/1 pairs reproduced |
| 17 | 17 | 2 + 中 → 236 + 中 | 2+MK → 236+MK | 800 | 800 | drive 0 | 6.2 | high | 0/1 pairs reproduced |
| 18 | 18 | 2 + 中 → 214 + 弱 | 2+MK → 214+LP | 800 | 800 | drive 0 | 6.2 | low | 0/1 pairs reproduced |
| 19 | 19 | 2 + 中 → 214 + 中 | 2+MK → 214+MP | 800 | 800 | drive 0 | 6.2 | low | 0/1 pairs reproduced |
| 20 | 20 | 2 + 中 → 214 + 强 | 2+MK → 214+HP | 800 | 800 | drive 0 | 6.2 | low | 0/1 pairs reproduced |

## Pairs to sweep: 20

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 694 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 2 + 中 → 236236 + 强 | `627:manual->1216:manual` | 1 | untested | single | low | -12 |
| 2 | 2 + 中 → 2 + SP + 强 | `627:manual->1216:simple` | 2 | untested | single | low | -12 |
| 3 | 2 + 中 → 214214 + 中 | `627:manual->1205:manual` | 3 | untested | single | high | -26 |
| 4 | 2 + 中 → 22 + 弱 + 中 + 强 | `627:manual->1209:manual` | 4 | untested | repeat | high | -11 |
| 5 | 2 + 中 → 4 + SP + 强 | `627:manual->1205:simple` | 5 | untested | single | high | -26 |
| 6 | 2 + 中 → 236236 + 弱 | `627:manual->1200:manual` | 6 | untested | single | high | -12 |
| 7 | 2 + 中 → [4]6 + 强 | `627:manual->1030:manual` | 7 | untested | single | low | -26 |
| 8 | 2 + 中 → SP + 强 | `627:manual->1200:simple` | 8 | untested | single | high | -12 |
| 9 | 2 + 中 → [4]6 + 中 | `627:manual->1024:manual` | 9 | untested | single | low | -22 |
| 10 | 2 + 中 → [4]6 + 弱 | `627:manual->1018:manual` | 10 | untested | single | low | -16 |
| 11 | 2 + 中 → [4] + SP | `627:manual->1018:simple` | 11 | untested | single | low | -16 |
| 12 | 2 + 中 → 2 + AUTO + SP | `627:manual->1085:simple` | 12 | untested | single | high | -17 |
| 13 | 2 + 中 → 236 + 强 | `627:manual->904:manual` | 13 | untested | single | high | -24 |
| 14 | 2 + 中 → [4] + AUTO + SP | `627:manual->1038:simple` | 14 | untested | single | low | -18 |
| 15 | 2 + 中 → AUTO + SP | `627:manual->999:simple` | 15 | untested | single | low | -16 |
| 16 | 2 + 中 → 236 + 弱 | `627:manual->900:manual` | 16 | untested | single | high | -15 |
| 17 | 2 + 中 → 236 + 中 | `627:manual->902:manual` | 17 | untested | single | high | -19 |
| 18 | 2 + 中 → 214 + 弱 | `627:manual->973:manual` | 18 | untested | single | low | -15 |
| 19 | 2 + 中 → 214 + 中 | `627:manual->977:manual` | 19 | untested | single | low | -19 |
| 20 | 2 + 中 → 214 + 强 | `627:manual->981:manual` | 20 | untested | single | low | -24 |

**1 of these the sweep cannot press as written.**

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

- reframework/data/ComboExplorer_data/worklist/mbison-modern-plan-starter-chu.json  (20 pairs, 11613 bytes)
- docs/ComboExplorer/plans/mbison-modern-starter-chu.md
