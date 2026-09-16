# Route plan - Marisa / modern - starter-chu

Generated 2026-09-16T02:31:14Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

EVERY ROUTE HERE IS A THEORETICAL CANDIDATE. The ranking is a prediction from
the frame data. The worklist below is the smallest set of pairs that lets the
game say whether these routes connect.

## Conditions

- `starter_button` = `M`
- sort: `scaled_damage`, top 20
- search: explore.lua's settings (normal,command_normal -> normal,command_normal,special,od_special,super, manual -> manual,simple, max 3 moves, beam 4000, collapse true)
- search complete: true - every route the settings can reach is in the list below
- Drive Rush Cancel edges in the search: no (pass --drive-rush to route through them)
- demote routes through a rejected pair: yes

`starter_button` keeps a route whose first move has that button with ANY direction
(中 keeps 中, 2 + 中, 3 + 中, 6 + 中). `--starter-neutral` narrows it to no direction.

## Damage figure

Ordered on `offline_score.predicted_damage_scaled`, the combo-scaled prediction.

11 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 803 (search complete: true)

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| starter_button | M | 803 | 733 | 70 | 0 |

- routes satisfying every condition: 70
- of those, through a pair the policy CONCLUSIVELY rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

Demotion counts conclusive failures only. Under policy `ce-eval-v1` a negative is one when the run pressed a playable input at the right timing; 0 of 0 runs were left out for asking something else, 0 of them negatives. 0 pair(s) changed status because of it.

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 2 + 中 → 236236 + 强 | 2+MP → 236236+K | 4700 | 4700 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs reproduced |
| 2 | 2 | 中 → 2 + 弱 → 236236 + 强 | MK → 2+LP → 236236+K | 4300 | 5100 | SA 1, drive >=0 (1 unknown) | 10.4 | low | 0/2 pairs reproduced |
| 3 | 3 | 2 + 中 → 2 + SP + 强 | 2+MP → 236236+K | 3900 | 4700 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs reproduced |
| 4 | 4 | 2 + 中 → 214214 + 中 | 2+MP → 214214+P | 3700 | 3700 | SA 1, drive >=0 (1 unknown) | 8.9 | high | 0/1 pairs reproduced |
| 5 | 5 | 中 → 2 + 弱 → 2 + SP + 强 | MK → 2+LP → 236236+K | 3660 | 5100 | SA 1, drive >=0 (1 unknown) | 8.0 | low | 0/2 pairs reproduced |
| 6 | 6 | 中 → 2 + 弱 → 214214 + 中 | MK → 2+LP → 214214+P | 3500 | 4100 | SA 1, drive >=0 (1 unknown) | 10.4 | medium | 0/2 pairs reproduced |
| 7 | 7 | 2 + 中 → 4 + SP + 强 | 2+MP → 214214+P | 3100 | 3700 | SA 1, drive >=0 (1 unknown) | 6.5 | high | 0/1 pairs reproduced |
| 8 | 8 | 中 → 2 + 弱 → 4 + SP + 强 | MK → 2+LP → 214214+P | 3020 | 4100 | SA 1, drive >=0 (1 unknown) | 8.0 | medium | 0/2 pairs reproduced |
| 9 | 9 | 2 + 中 → 236236 + 弱 | 2+MP → 236236+P | 2900 | 2900 | SA 1, drive >=0 (1 unknown) | 8.9 | high | 0/1 pairs reproduced |
| 10 | 10 | 中 → 2 + 弱 → 236236 + 弱 | MK → 2+LP → 236236+P | 2860 | 3300 | SA 1, drive >=0 (1 unknown) | 10.4 | medium | 0/2 pairs reproduced |
| 11 | 11 | 中 → 2 + 弱 → SP + 强 | MK → 2+LP → 236236+P | 2508 | 3300 | SA 1, drive >=0 (1 unknown) | 7.5 | medium | 0/2 pairs reproduced |
| 12 | 12 | 中 → 2 + 弱 → 623 + 强 | MK → 2+LP → 623+HP | 2460 | 2800 | drive 0 | 7.7 | medium | 0/2 pairs reproduced |
| 13 | 13 | 2 + 中 → SP + 强 | 2+MP → 236236+P | 2460 | 2900 | SA 1, drive >=0 (1 unknown) | 6.0 | high | 0/1 pairs reproduced |
| 14 | 14 | 2 + 中 → 623 + 强 | 2+MP → 623+HP | 2400 | 2400 | drive 0 | 6.2 | high | 0/1 pairs reproduced |
| 15 | 15 | 中 → 2 + 弱 → 236 + 强 | MK → 2+LP → 236+HP | 2380 | 2700 | drive 0 | 7.7 | medium | 0/2 pairs reproduced |
| 16 | 16 | 中 → 2 + 弱 → 623 + 中 | MK → 2+LP → 623+MP | 2380 | 2700 | drive 0 | 7.7 | medium | 0/2 pairs reproduced |
| 17 | 17 | 中 → 2 + 弱 → 623 + 弱 | MK → 2+LP → 623+LP | 2300 | 2600 | drive 0 | 7.7 | medium | 0/2 pairs reproduced |
| 18 | 18 | 2 + 中 → 236 + 强 | 2+MP → 236+HP | 2300 | 2300 | drive 0 | 6.2 | high | 0/1 pairs reproduced |
| 19 | 19 | 2 + 中 → 623 + 中 | 2+MP → 623+MP | 2300 | 2300 | drive 0 | 6.2 | high | 0/1 pairs reproduced |
| 20 | 20 | 中 → 2 + 弱 → 236 + 中 | MK → 2+LP → 236+MP | 2220 | 2500 | drive 0 | 7.7 | medium | 0/2 pairs reproduced |

## Pairs to sweep: 21

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 313 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 2 + 中 → 236236 + 强 | `625:manual->1213:manual` | 1 | untested | single | low | -10 |
| 2 | 中 → 2 + 弱 | `615:manual->621:manual` | 2, 5, 6, 8, 10, 11, 12, 15, 16, 17, 20 | untested | single | medium | 0 |
| 3 | 2 + 弱 → 236236 + 强 | `621:manual->1213:manual` | 2 | untested | single | low | -9 |
| 4 | 2 + 中 → 2 + SP + 强 | `625:manual->1213:simple` | 3 | untested | single | low | -10 |
| 5 | 2 + 中 → 214214 + 中 | `625:manual->1208:manual` | 4 | untested | single | high | -6 |
| 6 | 2 + 弱 → 2 + SP + 强 | `621:manual->1213:simple` | 5 | untested | single | low | -9 |
| 7 | 2 + 弱 → 214214 + 中 | `621:manual->1208:manual` | 6 | untested | single | high | -5 |
| 8 | 2 + 中 → 4 + SP + 强 | `625:manual->1208:simple` | 7 | untested | single | high | -6 |
| 9 | 2 + 弱 → 4 + SP + 强 | `621:manual->1208:simple` | 8 | untested | single | high | -5 |
| 10 | 2 + 中 → 236236 + 弱 | `625:manual->1200:manual` | 9 | untested | single | high | -16 |
| 11 | 2 + 弱 → 236236 + 弱 | `621:manual->1200:manual` | 10 | untested | single | high | -15 |
| 12 | 2 + 弱 → SP + 强 | `621:manual->1200:simple` | 11 | untested | single | high | -15 |
| 13 | 2 + 弱 → 623 + 强 | `621:manual->938:manual` | 12 | untested | single | high | -28 |
| 14 | 2 + 中 → SP + 强 | `625:manual->1200:simple` | 13 | untested | single | high | -16 |
| 15 | 2 + 中 → 623 + 强 | `625:manual->938:manual` | 14 | untested | single | high | -29 |
| 16 | 2 + 弱 → 236 + 强 | `621:manual->902:manual` | 15 | untested | single | high | -18 |
| 17 | 2 + 弱 → 623 + 中 | `621:manual->937:manual` | 16 | untested | single | high | -24 |
| 18 | 2 + 弱 → 623 + 弱 | `621:manual->936:manual` | 17 | untested | single | high | -21 |
| 19 | 2 + 中 → 236 + 强 | `625:manual->902:manual` | 18 | untested | single | high | -19 |
| 20 | 2 + 中 → 623 + 中 | `625:manual->937:manual` | 19 | untested | single | high | -25 |
| 21 | 2 + 弱 → 236 + 中 | `621:manual->901:manual` | 20 | untested | single | high | -15 |

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

- reframework/data/ComboExplorer_data/worklist/marisa-modern-plan-starter-chu.json  (21 pairs, 42364 bytes)
- docs/ComboExplorer/plans/marisa-modern-starter-chu.md
