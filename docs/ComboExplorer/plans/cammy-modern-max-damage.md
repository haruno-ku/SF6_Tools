# Route plan - Cammy / modern - max-damage

Generated 2026-09-16T02:23:41Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

EVERY ROUTE HERE IS A THEORETICAL CANDIDATE. The ranking is a prediction from
the frame data. The worklist below is the smallest set of pairs that lets the
game say whether these routes connect.

## Conditions

- none: every route the search found
- sort: `scaled_damage`, top 20
- search: explore.lua's settings (normal,command_normal -> normal,command_normal,special,od_special,super, manual -> manual,simple, max 3 moves, beam 4000, collapse true)
- search complete: false - the beam dropped 713 partial route(s) and 0 route(s) were not emitted, so the list below is a sample
- Drive Rush Cancel edges in the search: no (pass --drive-rush to route through them)
- demote routes through a rejected pair: yes

## Damage figure

Ordered on `offline_score.predicted_damage_scaled`, the combo-scaled prediction.

200 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 1541 (search complete: false)
  - the beam dropped 713 partial routes and 0 routes were not emitted, so a route
    satisfying these conditions may be missing

- routes satisfying every condition: 1541
- of those, through a pair the policy CONCLUSIVELY rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

Demotion counts conclusive failures only. Under policy `ce-eval-v1` a negative is one when the run pressed a playable input at the right timing; 0 of 0 runs were left out for asking something else, 0 of them negatives. 0 pair(s) changed status because of it.

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 3 + 强 → 236236 + 强 | 2+HK → 236236+P | 4900 | 4900 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs reproduced |
| 2 | 2 | 4 + 强 → 236236 + 强 | 4+HK → 236236+P | 4800 | 4800 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs reproduced |
| 3 | 3 | 6 + 强 → 236236 + 强 | 6+HK → 236236+P | 4800 | 4800 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs reproduced |
| 4 | 4 | 2 + 中 → 236236 + 强 | 2+MK → 236236+P | 4500 | 4500 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs reproduced |
| 5 | 5 | 4 + 中 → 236236 + 强 | 4+MP → 236236+P | 4500 | 4500 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs reproduced |
| 6 | 6 | 3 + 强 → 2 + SP + 强 | 2+HK → 236236+P | 4100 | 4900 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs reproduced |
| 7 | 7 | 3 + 强 → 4 + 强 → 214214 + 中 | 2+HK → 4+HK → 214214+P | 4100 | 4700 | SA 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs reproduced |
| 8 | 8 | 3 + 强 → 6 + 强 → 214214 + 中 | 2+HK → 6+HK → 214214+P | 4100 | 4700 | SA 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs reproduced |
| 9 | 9 | 4 + 强 → 3 + 强 → 214214 + 中 | 4+HK → 2+HK → 214214+P | 4100 | 4700 | SA 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs reproduced |
| 10 | 10 | 6 + 强 → 3 + 强 → 214214 + 中 | 6+HK → 2+HK → 214214+P | 4100 | 4700 | SA 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs reproduced |
| 11 | 11 | 4 + 强 → 2 + SP + 强 | 4+HK → 236236+P | 4000 | 4800 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs reproduced |
| 12 | 12 | 4 + 强 → 6 + 强 → 214214 + 中 | 4+HK → 6+HK → 214214+P | 4000 | 4600 | SA 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs reproduced |
| 13 | 13 | 6 + 强 → 2 + SP + 强 | 6+HK → 236236+P | 4000 | 4800 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs reproduced |
| 14 | 14 | 6 + 强 → 4 + 强 → 214214 + 中 | 6+HK → 4+HK → 214214+P | 4000 | 4600 | SA 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs reproduced |
| 15 | 15 | 3 + 强 → 214214 + 中 | 2+HK → 214214+P | 3900 | 3900 | SA 1, drive >=0 (1 unknown) | 8.9 | medium | 0/1 pairs reproduced |
| 16 | 16 | 3 + 强 → 2 + 中 → 214214 + 中 | 2+HK → 2+MK → 214214+P | 3800 | 4400 | SA 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs reproduced |
| 17 | 17 | 3 + 强 → 4 + 中 → 214214 + 中 | 2+HK → 4+MP → 214214+P | 3800 | 4400 | SA 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs reproduced |
| 18 | 18 | 4 + 强 → 214214 + 中 | 4+HK → 214214+P | 3800 | 3800 | SA 1, drive >=0 (1 unknown) | 8.9 | medium | 0/1 pairs reproduced |
| 19 | 19 | 6 + 强 → 214214 + 中 | 6+HK → 214214+P | 3800 | 3800 | SA 1, drive >=0 (1 unknown) | 8.9 | medium | 0/1 pairs reproduced |
| 20 | 20 | 2 + 中 → 2 + SP + 强 | 2+MK → 236236+P | 3700 | 4500 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs reproduced |

## Pairs to sweep: 22

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 453 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 3 + 强 → 236236 + 强 | `635:manual->1231:manual` | 1 | untested | single | low | 29 |
| 2 | 4 + 强 → 236236 + 强 | `648:manual->1231:manual` | 2 | untested | single | low | 45 |
| 3 | 6 + 强 → 236236 + 强 | `649:manual->1231:manual` | 3 | untested | single | low | 22 |
| 4 | 2 + 中 → 236236 + 强 | `632:manual->1231:manual` | 4 | untested | single | low | -8 |
| 5 | 4 + 中 → 236236 + 强 | `647:manual->1231:manual` | 5 | untested | single | low | -5 |
| 6 | 3 + 强 → 2 + SP + 强 | `635:manual->1231:simple` | 6 | untested | single | low | 29 |
| 7 | 3 + 强 → 4 + 强 | `635:manual->648:manual` | 7 | untested | single | medium | 29 |
| 8 | 4 + 强 → 214214 + 中 | `648:manual->1210:manual` | 7, 14, 18 | untested | single | medium | 41 |
| 9 | 3 + 强 → 6 + 强 | `635:manual->649:manual` | 8 | untested | single | medium | 20 |
| 10 | 6 + 强 → 214214 + 中 | `649:manual->1210:manual` | 8, 12, 19 | untested | single | medium | 18 |
| 11 | 4 + 强 → 3 + 强 | `648:manual->635:manual` | 9 | untested | single | medium | 45 |
| 12 | 3 + 强 → 214214 + 中 | `635:manual->1210:manual` | 9, 10, 15 | untested | single | medium | 25 |
| 13 | 6 + 强 → 3 + 强 | `649:manual->635:manual` | 10 | untested | single | medium | 22 |
| 14 | 4 + 强 → 2 + SP + 强 | `648:manual->1231:simple` | 11 | untested | single | low | 45 |
| 15 | 4 + 强 → 6 + 强 | `648:manual->649:manual` | 12 | untested | single | medium | 36 |
| 16 | 6 + 强 → 2 + SP + 强 | `649:manual->1231:simple` | 13 | untested | single | low | 22 |
| 17 | 6 + 强 → 4 + 强 | `649:manual->648:manual` | 14 | untested | single | medium | 22 |
| 18 | 3 + 强 → 2 + 中 | `635:manual->632:manual` | 16 | untested | single | medium | 30 |
| 19 | 2 + 中 → 214214 + 中 | `632:manual->1210:manual` | 16 | untested | single | high | -12 |
| 20 | 3 + 强 → 4 + 中 | `635:manual->647:manual` | 17 | untested | single | medium | 33 |
| 21 | 4 + 中 → 214214 + 中 | `647:manual->1210:manual` | 17 | untested | single | high | -9 |
| 22 | 2 + 中 → 2 + SP + 强 | `632:manual->1231:simple` | 20 | untested | single | low | -8 |

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

- reframework/data/ComboExplorer_data/worklist/cammy-modern-plan-max-damage.json  (22 pairs, 41411 bytes)
- docs/ComboExplorer/plans/cammy-modern-max-damage.md
