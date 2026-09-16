# Route plan - Ingrid / modern - starter-chu

Generated 2026-09-16T02:35:49Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

EVERY ROUTE HERE IS A THEORETICAL CANDIDATE. The ranking is a prediction from
the frame data. The worklist below is the smallest set of pairs that lets the
game say whether these routes connect.

## Conditions

- `starter_button` = `M`
- sort: `scaled_damage`, top 20
- search: explore.lua's settings (normal,command_normal -> normal,command_normal,special,od_special,super, manual -> manual,simple, max 3 moves, beam 4000, collapse true)
- search complete: false - the beam dropped 4159 partial route(s) and 0 route(s) were not emitted, so the list below is a sample
- Drive Rush Cancel edges in the search: no (pass --drive-rush to route through them)
- demote routes through a rejected pair: yes

`starter_button` keeps a route whose first move has that button with ANY direction
(中 keeps 中, 2 + 中, 3 + 中, 6 + 中). `--starter-neutral` narrows it to no direction.

## Damage figure

Ordered on `offline_score.predicted_damage_scaled`, the combo-scaled prediction.

312 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 2502 (search complete: false)
  - the beam dropped 4159 partial routes and 0 routes were not emitted, so a route
    satisfying these conditions may be missing

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| starter_button | M | 2502 | 1566 | 936 | 0 |

- routes satisfying every condition: 936
- of those, through a pair the policy CONCLUSIVELY rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

Demotion counts conclusive failures only. Under policy `ce-eval-v1` a negative is one when the run pressed a playable input at the right timing; 0 of 0 runs were left out for asking something else, 0 of them negatives. 0 pair(s) changed status because of it.

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 2 + 弱 + 中 + 强 → 6 + 强 → 214214 + 强 | 2+KKK → 6+HP → 22+PPP | 6000 | 7000 | OD 1, drive >=0 (1 unknown) | 11.9 | medium | 0/2 pairs reproduced |
| 2 | 2 | 6 + 弱 + 中 + 强 → 6 + 强 → 214214 + 强 | 6+KKK → 6+HP → 22+PPP | 5900 | 6900 | OD 1, drive >=0 (1 unknown) | 11.9 | medium | 0/2 pairs reproduced |
| 3 | 3 | 2 + 弱 + 中 + 强 → 2 + 强 → 214214 + 强 | 2+KKK → 2+HP → 22+PPP | 5900 | 6900 | OD 1, drive >=0 (1 unknown) | 11.9 | medium | 0/2 pairs reproduced |
| 4 | 4 | 6 + 弱 + 中 + 强 → 2 + 强 → 214214 + 强 | 6+KKK → 2+HP → 22+PPP | 5800 | 6800 | OD 1, drive >=0 (1 unknown) | 11.9 | medium | 0/2 pairs reproduced |
| 5 | 5 | 2 + 弱 + 中 + 强 → 2 + 中 → 214214 + 强 | 2+KKK → 2+MK → 22+PPP | 5600 | 6600 | OD 1, drive >=0 (1 unknown) | 11.9 | medium | 0/2 pairs reproduced |
| 6 | 6 | 2 + 中 → 214214 + 强 | 2+MK → 22+PPP | 5500 | 5500 | OD 1, drive >=0 (1 unknown) | 8.9 | high | 0/1 pairs reproduced |
| 7 | 7 | 6 + 弱 + 中 + 强 → 2 + 中 → 214214 + 强 | 6+KKK → 2+MK → 22+PPP | 5500 | 6500 | OD 1, drive >=0 (1 unknown) | 11.9 | medium | 0/2 pairs reproduced |
| 8 | 8 | 2 + 弱 + 中 + 强 → 2 + 弱 → 214214 + 强 | 2+KKK → 2+LP → 22+PPP | 5400 | 6400 | OD 1, drive >=0 (1 unknown) | 11.9 | medium | 0/2 pairs reproduced |
| 9 | 9 | 6 + 弱 + 中 + 强 → 2 + 弱 → 214214 + 强 | 6+KKK → 2+LP → 22+PPP | 5300 | 6300 | OD 1, drive >=0 (1 unknown) | 11.9 | medium | 0/2 pairs reproduced |
| 10 | 10 | 6 + 弱 + 中 + 强 → 2 + 弱 + 中 + 强 → 236236 + 强 | 6+KKK → 2+KKK → 236236+P | 5300 | 6100 | SA 1, drive >=0 (1 unknown) | 12.9 | low | 0/2 pairs reproduced |
| 11 | 11 | 2 + 弱 + 中 + 强 → 6 + 弱 + 中 + 强 → 236236 + 强 | 2+KKK → 6+KKK → 236236+P | 5300 | 6100 | SA 1, drive >=0 (1 unknown) | 12.9 | low | 0/2 pairs reproduced |
| 12 | 12 | 2 + 弱 + 中 + 强 → 3 + 强 → 236236 + 强 | 2+KKK → 2+HK → 236236+P | 5200 | 6000 | SA 1, drive >=0 (1 unknown) | 11.9 | low | 0/2 pairs reproduced |
| 13 | 13 | 2 + 弱 + 中 + 强 → 6 + 强 → 236236 + 强 | 2+KKK → 6+HP → 236236+P | 5200 | 6000 | SA 1, drive >=0 (1 unknown) | 11.9 | low | 0/2 pairs reproduced |
| 14 | 14 | 6 + 弱 + 中 + 强 → 3 + 强 → 236236 + 强 | 6+KKK → 2+HK → 236236+P | 5100 | 5900 | SA 1, drive >=0 (1 unknown) | 11.9 | low | 0/2 pairs reproduced |
| 15 | 15 | 6 + 弱 + 中 + 强 → 6 + 强 → 236236 + 强 | 6+KKK → 6+HP → 236236+P | 5100 | 5900 | SA 1, drive >=0 (1 unknown) | 11.9 | low | 0/2 pairs reproduced |
| 16 | 16 | 2 + 弱 + 中 + 强 → 236236 + 强 | 2+KKK → 236236+P | 5100 | 5100 | SA 1, drive >=0 (1 unknown) | 9.9 | low | 0/1 pairs reproduced |
| 17 | 17 | 2 + 弱 + 中 + 强 → 2 + 强 → 236236 + 强 | 2+KKK → 2+HP → 236236+P | 5100 | 5900 | SA 1, drive >=0 (1 unknown) | 11.9 | low | 0/2 pairs reproduced |
| 18 | 18 | 2 + 弱 + 中 + 强 → 4 + 强 → 236236 + 强 | 2+KKK → 4+HP → 236236+P | 5100 | 5900 | SA 1, drive >=0 (1 unknown) | 11.9 | low | 0/2 pairs reproduced |
| 19 | 19 | 4 + 中 → 2 + 弱 → 214214 + 强 | 4+MK → 2+LP → 22+PPP | 5000 | 6000 | OD 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs reproduced |
| 20 | 20 | 6 + 弱 + 中 + 强 → 236236 + 强 | 6+KKK → 236236+P | 5000 | 5000 | SA 1, drive >=0 (1 unknown) | 9.9 | low | 0/1 pairs reproduced |

## Pairs to sweep: 24

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 719 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 2 + 弱 + 中 + 强 → 6 + 强 | `964:manual->663:manual` | 1, 13 | untested | single | medium | 31 |
| 2 | 6 + 强 → 214214 + 强 | `663:manual->1317:manual` | 1, 2 | untested | single | medium | -23 |
| 3 | 6 + 弱 + 中 + 强 → 6 + 强 | `963:manual->663:manual` | 2, 15 | untested | single | medium | 27 |
| 4 | 2 + 弱 + 中 + 强 → 2 + 强 | `964:manual->631:manual` | 3, 17 | untested | single | medium | 36 |
| 5 | 2 + 强 → 214214 + 强 | `631:manual->1317:manual` | 3, 4 | untested | single | high | -60 |
| 6 | 6 + 弱 + 中 + 强 → 2 + 强 | `963:manual->631:manual` | 4 | untested | single | medium | 32 |
| 7 | 2 + 弱 + 中 + 强 → 2 + 中 | `964:manual->640:manual` | 5 | untested | single | medium | 40 |
| 8 | 2 + 中 → 214214 + 强 | `640:manual->1317:manual` | 5, 6, 7 | untested | single | high | -60 |
| 9 | 6 + 弱 + 中 + 强 → 2 + 中 | `963:manual->640:manual` | 7 | untested | single | medium | 36 |
| 10 | 2 + 弱 + 中 + 强 → 2 + 弱 | `964:manual->623:manual` | 8 | untested | single | medium | 44 |
| 11 | 2 + 弱 → 214214 + 强 | `623:manual->1317:manual` | 8, 9, 19 | untested | single | high | -57 |
| 12 | 6 + 弱 + 中 + 强 → 2 + 弱 | `963:manual->623:manual` | 9 | untested | single | medium | 40 |
| 13 | 6 + 弱 + 中 + 强 → 2 + 弱 + 中 + 强 | `963:manual->964:manual` | 10 | untested | single | medium | 1 |
| 14 | 2 + 弱 + 中 + 强 → 236236 + 强 | `964:manual->1287:manual` | 10, 16 | untested | single | low | 28 |
| 15 | 2 + 弱 + 中 + 强 → 6 + 弱 + 中 + 强 | `964:manual->963:manual` | 11 | untested | single | medium | 12 |
| 16 | 6 + 弱 + 中 + 强 → 236236 + 强 | `963:manual->1287:manual` | 11, 20 | untested | single | low | 24 |
| 17 | 2 + 弱 + 中 + 强 → 3 + 强 | `964:manual->643:manual` | 12 | untested | single | medium | 38 |
| 18 | 3 + 强 → 236236 + 强 | `643:manual->1287:manual` | 12, 14 | untested | single | low | 10 |
| 19 | 6 + 强 → 236236 + 强 | `663:manual->1287:manual` | 13, 15 | untested | single | low | 18 |
| 20 | 6 + 弱 + 中 + 强 → 3 + 强 | `963:manual->643:manual` | 14 | untested | single | medium | 34 |
| 21 | 2 + 强 → 236236 + 强 | `631:manual->1287:manual` | 17 | untested | single | low | -19 |
| 22 | 2 + 弱 + 中 + 强 → 4 + 强 | `964:manual->674:manual` | 18 | untested | single | medium | 34 |
| 23 | 4 + 强 → 236236 + 强 | `674:manual->1287:manual` | 18 | untested | single | low | 25 |
| 24 | 4 + 中 → 2 + 弱 | `670:manual->623:manual` | 19 | untested | single | medium | 0 |

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

- reframework/data/ComboExplorer_data/worklist/ingrid-modern-plan-starter-chu.json  (24 pairs, 46071 bytes)
- docs/ComboExplorer/plans/ingrid-modern-starter-chu.md
