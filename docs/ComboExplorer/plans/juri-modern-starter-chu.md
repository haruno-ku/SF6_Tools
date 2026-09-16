# Route plan - Juri / modern - starter-chu

Generated 2026-09-16T02:27:12Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

EVERY ROUTE HERE IS A THEORETICAL CANDIDATE. The ranking is a prediction from
the frame data. The worklist below is the smallest set of pairs that lets the
game say whether these routes connect.

## Conditions

- `starter_button` = `M`
- sort: `scaled_damage`, top 20
- search: explore.lua's settings (normal,command_normal -> normal,command_normal,special,od_special,super, manual -> manual,simple, max 3 moves, beam 4000, collapse true)
- search complete: false - the beam dropped 15401 partial route(s) and 0 route(s) were not emitted, so the list below is a sample
- Drive Rush Cancel edges in the search: no (pass --drive-rush to route through them)
- demote routes through a rejected pair: yes

`starter_button` keeps a route whose first move has that button with ANY direction
(中 keeps 中, 2 + 中, 3 + 中, 6 + 中). `--starter-neutral` narrows it to no direction.

## Damage figure

Ordered on `offline_score.predicted_damage_scaled`, the combo-scaled prediction.

41 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 775 (search complete: false)
  - the beam dropped 15401 partial routes and 0 routes were not emitted, so a route
    satisfying these conditions may be missing

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| starter_button | M | 775 | 606 | 169 | 0 |

- routes satisfying every condition: 169
- of those, through a pair the policy CONCLUSIVELY rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

Demotion counts conclusive failures only. Under policy `ce-eval-v1` a negative is one when the run pressed a playable input at the right timing; 0 of 0 runs were left out for asking something else, 0 of them negatives. 0 pair(s) changed status because of it.

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 中 → 214214 + 强 | MP → 214214+K | 4600 | 4600 | SA 1, drive >=0 (1 unknown) | 8.4 | low | 0/1 pairs reproduced |
| 2 | 2 | 2 + 中 → 214214 + 强 | 2+MK → 214214+K | 4500 | 4500 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs reproduced |
| 3 | 3 | 中 → 2 + SP + 强 | MP → 214214+K | 3800 | 4600 | SA 1, drive >=0 (1 unknown) | 6.0 | low | 0/1 pairs reproduced |
| 4 | 4 | 2 + 中 → 2 + SP + 强 | 2+MK → 214214+K | 3700 | 4500 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs reproduced |
| 5 | 5 | 中 → 中 → 236236 + 弱 | MP → MP → 236236+K | 2640 | 3000 | SA 1, drive >=0 (1 unknown) | 9.9 | medium | 0/2 pairs reproduced |
| 6 | 6 | 中 → 236236 + 弱 | MP → 236236+K | 2400 | 2400 | SA 1, drive >=0 (1 unknown) | 8.4 | high | 0/1 pairs reproduced |
| 7 | 7 | 中 → 中 → SP + 强 | MP → MP → 236236+K | 2352 | 3000 | SA 1, drive >=0 (1 unknown) | 7.0 | medium | 0/2 pairs reproduced |
| 8 | 8 | 中 → 弱 → 236236 + 弱 | MP → LP → 236236+K | 2340 | 2700 | SA 1, drive >=0 (1 unknown) | 9.9 | high | 0/2 pairs reproduced |
| 9 | 9 | 中 → 2 + 弱 → 236236 + 弱 | MP → 2+LP → 236236+K | 2340 | 2700 | SA 1, drive >=0 (1 unknown) | 10.4 | high | 0/2 pairs reproduced |
| 10 | 10 | 2 + 中 → 236236 + 弱 | 2+MK → 236236+K | 2300 | 2300 | SA 1, drive >=0 (1 unknown) | 8.9 | high | 0/1 pairs reproduced |
| 11 | 11 | 中 → 弱 → SP + 强 | MP → LP → 236236+K | 2052 | 2700 | SA 1, drive >=0 (1 unknown) | 7.0 | high | 0/2 pairs reproduced |
| 12 | 12 | 中 → 2 + 弱 → SP + 强 | MP → 2+LP → 236236+K | 2052 | 2700 | SA 1, drive >=0 (1 unknown) | 7.5 | high | 0/2 pairs reproduced |
| 13 | 13 | 中 → SP + 强 | MP → 236236+K | 2040 | 2400 | SA 1, drive >=0 (1 unknown) | 5.5 | high | 0/1 pairs reproduced |
| 14 | 14 | 2 + 中 → SP + 强 | 2+MK → 236236+K | 1940 | 2300 | SA 1, drive >=0 (1 unknown) | 6.0 | high | 0/1 pairs reproduced |
| 15 | 15 | 中 → 中 → 236 + 弱 + 强 | MP → MP → 236+LK+HK | 1840 | 2000 | drive 20000 | 7.7 | medium | 0/2 pairs reproduced |
| 16 | 16 | 中 → 中 → 2 + AUTO + SP | MP → MP → 236+LK+HK | 1712 | 2000 | drive 20000 | 7.5 | medium | 0/2 pairs reproduced |
| 17 | 17 | 中 → 中 → 中 | MP → MP → MP | 1680 | 1800 | drive 0 | 4.5 | medium | 0/2 pairs reproduced |
| 18 | 18 | 中 → 中 → 214 + 弱 | MP → MP → 214+LK | 1680 | 1800 | drive 0 | 7.2 | medium | 0/2 pairs reproduced |
| 19 | 19 | 中 → 中 → 214 + 中 | MP → MP → 214+MK | 1680 | 1800 | drive 0 | 7.2 | medium | 0/2 pairs reproduced |
| 20 | 20 | 中 → 中 → 236 + 中 | MP → MP → 236+MK | 1680 | 1800 | drive 0 | 7.2 | medium | 0/2 pairs reproduced |

## Pairs to sweep: 23

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 2388 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 中 → 214214 + 强 | `603:manual->1221:manual` | 1 | untested | single | low | -3 |
| 2 | 2 + 中 → 214214 + 强 | `634:manual->1221:manual` | 2 | untested | single | low | -9 |
| 3 | 中 → 2 + SP + 强 | `603:manual->1221:simple` | 3 | untested | single | low | -3 |
| 4 | 2 + 中 → 2 + SP + 强 | `634:manual->1221:simple` | 4 | untested | single | low | -9 |
| 5 | 中 → 中 | `603:manual->606:manual` | 5, 7, 15, 16, 17, 18, 19, 20 | untested | single | medium | 1 |
| 6 | 中 → 236236 + 弱 | `606:manual->1200:manual` | 5 | untested | single | high | 0 |
| 7 | 中 → 236236 + 弱 | `603:manual->1200:manual` | 6 | untested | single | high | 0 |
| 8 | 中 → SP + 强 | `606:manual->1200:simple` | 7 | untested | single | high | 0 |
| 9 | 中 → 弱 | `603:manual->602:manual` | 8, 11 | untested | single | high | 3 |
| 10 | 弱 → 236236 + 弱 | `602:manual->1200:manual` | 8 | untested | single | high | -2 |
| 11 | 中 → 2 + 弱 | `603:manual->618:manual` | 9, 12 | untested | single | high | 3 |
| 12 | 2 + 弱 → 236236 + 弱 | `618:manual->1200:manual` | 9 | untested | single | high | -3 |
| 13 | 2 + 中 → 236236 + 弱 | `634:manual->1200:manual` | 10 | untested | single | high | -6 |
| 14 | 弱 → SP + 强 | `602:manual->1200:simple` | 11 | untested | single | high | -2 |
| 15 | 2 + 弱 → SP + 强 | `618:manual->1200:simple` | 12 | untested | single | high | -3 |
| 16 | 中 → SP + 强 | `603:manual->1200:simple` | 13 | untested | single | high | 0 |
| 17 | 2 + 中 → SP + 强 | `634:manual->1200:simple` | 14 | untested | single | high | -6 |
| 18 | 中 → 236 + 弱 + 强 | `606:manual->932:manual` | 15 | untested | single | high | -17 |
| 19 | 中 → 2 + AUTO + SP | `606:manual->932:simple` | 16 | untested | single | high | -17 |
| 20 | 中 → 中 | `606:manual->603:manual` | 17 | untested | single | medium | 1 |
| 21 | 中 → 214 + 弱 | `606:manual->900:manual` | 18 | untested | single | high | -3 |
| 22 | 中 → 214 + 中 | `606:manual->904:manual` | 19 | untested | single | high | -6 |
| 23 | 中 → 236 + 中 | `606:manual->931:manual` | 20 | untested | single | high | -17 |

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

- reframework/data/ComboExplorer_data/worklist/juri-modern-plan-starter-chu.json  (23 pairs, 43278 bytes)
- docs/ComboExplorer/plans/juri-modern-starter-chu.md
