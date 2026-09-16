# Route plan - Zangief / modern - starter-chu

Generated 2026-09-16T00:28:59Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

1 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 423 (search complete: true)

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| starter_button | M | 423 | 410 | 13 | 0 |

- routes satisfying every condition: 13
- of those, through a pair the policy CONCLUSIVELY rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 13

Demotion counts conclusive failures only. Under policy `ce-eval-v1` a negative is one when the run pressed a playable input at the right timing; 343 of 856 runs were left out for asking something else, 213 of them negatives. 70 pair(s) changed status because of it.

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 3 + 中 → 236236 + 中 | 3+MP → 236236+P | 3960 | 3960 | SA 1, drive >=0 (1 unknown) | 8.9 | high | linked once as a combo; 0/1 pairs reproduced; linked once: 655:manual->1206:manual |
| 2 | 2 | 2 + 中 → 236236 + 中 | 2+MP → 236236+P | 3860 | 3860 | SA 1, drive >=0 (1 unknown) | 8.9 | high | confirmed combo |
| 3 | 3 | 3 + 中 → 4 + SP + 强 | 3+MP → 236236+P | 3328 | 3960 | SA 1, drive >=0 (1 unknown) | 6.5 | high | linked once as a combo; 0/1 pairs reproduced; linked once: 655:manual->1206:simple |
| 4 | 4 | 2 + 中 → 4 + SP + 强 | 2+MP → 236236+P | 3228 | 3860 | SA 1, drive >=0 (1 unknown) | 6.5 | high | confirmed combo |
| 5 | 5 | 3 + 中 → 22 + 强 | 3+MP → 22+HK | 3200 | 3200 | drive 0 | 5.3 | low | 0/1 pairs reproduced |
| 6 | 6 | 2 + 中 → 22 + 强 | 2+MP → 22+HK | 3100 | 3100 | drive 0 | 5.3 | low | 0/1 pairs reproduced; never asked properly: 621:manual->785:manual |
| 7 | 7 | 3 + 中 → 强 | 3+MP → HP | 1800 | 1800 | drive 0 | 3.5 | low | 0/1 pairs reproduced |
| 8 | 8 | 中 → 强 | MP → HP | 1700 | 1700 | drive 0 | 3.0 | low | 0/1 pairs reproduced |
| 9 | 9 | 2 + 中 → 强 | 2+MP → HP | 1700 | 1700 | drive 0 | 3.5 | low | 0/1 pairs reproduced |
| 10 | 10 | 6 + 中 → 强 | 6+MK → HP | 1700 | 1700 | drive 0 | 3.5 | low | 0/1 pairs reproduced |
| 11 | 11 | 3 + 中 → 22 + 中 | 3+MP → 22+MK | 1300 | 1300 | drive 0 | 5.3 | high | 0/1 pairs reproduced |
| 12 | 12 | 2 + 中 → 22 + 中 | 2+MP → 22+MK | 1200 | 1200 | drive 0 | 5.3 | high | 0/1 pairs reproduced |
| 13 | 13 | 中 → > 中 | MP → >MP | - | 700 (incomplete) | drive >=0 (1 unknown) | 3.0 | medium | 0/1 pairs reproduced |

## Pairs to sweep: 11

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 159 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 3 + 中 → 236236 + 中 | `655:manual->1206:manual` | 1 | linked_once | single | high | -19 |
| 2 | 3 + 中 → 4 + SP + 强 | `655:manual->1206:simple` | 3 | linked_once | single | high | -19 |
| 3 | 3 + 中 → 22 + 强 | `655:manual->785:manual` | 5 | pending | repeat | low | -7 |
| 4 | 2 + 中 → 22 + 强 | `621:manual->785:manual` | 6 | asked_badly | repeat | low | -3 |
| 5 | 3 + 中 → 强 | `655:manual->637:manual` | 7 | pending | single | low | - |
| 6 | 中 → 强 | `604:manual->637:manual` | 8 | pending | single | low | - |
| 7 | 2 + 中 → 强 | `621:manual->637:manual` | 9 | pending | single | low | - |
| 8 | 6 + 中 → 强 | `682:manual->637:manual` | 10 | pending | single | low | - |
| 9 | 3 + 中 → 22 + 中 | `655:manual->678:manual` | 11 | pending | repeat | high | -10 |
| 10 | 2 + 中 → 22 + 中 | `621:manual->678:manual` | 12 | pending | repeat | high | -6 |
| 11 | 中 → > 中 | `604:manual->605:manual` | 13 | pending | followup | medium | -7 |

**5 of these the sweep cannot press as written.**

### Pairs whose every negative was thrown out: 1

Trials were spent on these and none of them asked whether the pair links: the
fixed gap of 4 inside A's animation (#46), a cancel-only pair pressed at the link
gap after A had recovered, B's button a motion's worth of ticks late, or an input
today's compiler would not press (#49). They read as `pending` to the plan and
they do NOT demote a route - nobody has asked yet.

- `621:manual->785:manual`: pending (0 linked / 0 counted no / 1 left out: fixed_delay_4 1); pending (0 linked / 0 counted no / 1 left out: superseded_rerun 1)

### Pairs that linked but were never reproduced: 2

The game said yes, and not twice at one delay - which is ConfirmedEdge's rule for
`stable` and the database's for a confirmed pair. They stay in the sweep: one more
link at the gap that already worked is the cheapest question in the plan.

- `655:manual->1206:manual`: observed_success (1 linked / 0 counted no / 0 left out); pending (0 linked / 0 counted no / 2 left out: link_timing_on_cancel_pair 1, superseded_rerun 1)
- `655:manual->1206:simple`: observed_success (1 linked / 0 counted no / 0 left out); pending (0 linked / 0 counted no / 2 left out: link_timing_on_cancel_pair 1, superseded_rerun 1)

## Already known: 2

Left out of the worklist (pass --include-verified to keep verified pairs).

- `621:manual->1206:manual` (2 + 中 → 236236 + 中): every route needing it is already a confirmed combo, needed by 2
- `621:manual->1206:simple` (2 + 中 → 4 + SP + 强): verified by the game, needed by 4

## Where the known statuses come from

- trial logs read: 7 (1000 records for modern)
- pairs answered: 418 across 2 cohort(s) - raw ConfirmedEdge: verified 12, rejected 151, pending 255
- route runs (combos, not pairs): 366 rows
- combos the looser page rule calls confirmed: 7 (2+ links at any gap, across input methods, cohorts and gaps, superseded rows included)

### Policy `ce-eval-v1`

A superseded re-run is left out unless it linked. A link counts under every flag. A negative counts only when the run asked the question at the right timing with a pressable input (no fixed_delay_4, unplayable_input, link_timing_on_cancel_pair, motion_button_late). Unanswered runs count as unanswered. Pairs fold per cohort through ConfirmedEdge (reproduced = stable); routes per cohort through the combo rule (reproduced = 2 counted links at any gap).

- rows built from the trial files: 856 (1000 lines, 144 committed twice, 0 refused)
- runs counted: 513; left out: 343 (of which negatives: 213)
  - `fixed_delay_4`: 37
  - `link_timing_on_cancel_pair`: 12
  - `motion_button_late`: 52
  - `superseded_rerun`: 242
- evaluations (one per subject per cohort): 420
- pairs by status: asked_badly 65, linked_once 5, pending 92, rejected 50, verified 4
- reclassified by the policy: 70 of 216 (`rejected -> asked_badly` 65, `verified -> linked_once` 5)

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

## Route files for the next session: 3

`--routes 3` wrote the plan's best routes where the panel's ROUTE section reads
them. A route run presses the whole combo and records every gap combination, which
is what a verified combo with measured damage needs (#36, #37) and what a pair
sweep cannot give.

| # | route | file | grid | gap delays (where each came from) |
|---:|---|---|---:|---|
| 1 | 3 + 中 → 236236 + 中 | `zangief-modern-starter-chu-1.json` | 1 | gap 1 4 (measured) |
| 2 | 2 + 中 → 236236 + 中 | `zangief-modern-starter-chu-2.json` | 1 | gap 1 4 (measured) |
| 3 | 3 + 中 → 4 + SP + 强 | `zangief-modern-starter-chu-3.json` | 1 | gap 1 4 (measured) |

`measured` is the gaps the policy's counted runs linked that pair at; `predicted`
is runtime/Sweep.plan_for's own grid from the frame data, a link gap widened to the
window the input buffer covers (`input_buffer_ticks` = 4, unverified); `default` is
core/Route.DEFAULT_DELAYS, which measures nothing and says so. No gap is ever
given a single invented number.

## Running it

Copy the worklist to the game machine (`scripts/install-dev.ps1` syncs
reframework/data), then pick `plan: starter-chu` in the SWEEP panel's worklist list
(REFRESH if the panel was already open) and START SWEEP. It writes to the same
trial log as the full sweep, so pairs the full sweep already answered under the
same calibration and conditions are skipped, and the other way round.

## Written

- reframework/data/ComboExplorer_data/worklist/zangief-modern-plan-starter-chu.json  (11 pairs, 6947 bytes)
- reframework/data/ComboExplorer_data/route/zangief-modern-starter-chu-1.json  (2 step(s), 1 gap combination(s), 1505 bytes)
- reframework/data/ComboExplorer_data/route/zangief-modern-starter-chu-2.json  (2 step(s), 1 gap combination(s), 1499 bytes)
- reframework/data/ComboExplorer_data/route/zangief-modern-starter-chu-3.json  (2 step(s), 1 gap combination(s), 1505 bytes)
- docs/ComboExplorer/plans/zangief-modern-starter-chu.md
