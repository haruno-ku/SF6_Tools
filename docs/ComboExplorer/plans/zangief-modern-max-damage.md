# Route plan - Zangief / modern - max-damage

Generated 2026-09-16T02:18:31Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

EVERY ROUTE HERE IS A THEORETICAL CANDIDATE. The ranking is a prediction from
the frame data. The worklist below is the smallest set of pairs that lets the
game say whether these routes connect.

## Conditions

- none: every route the search found
- sort: `scaled_damage`, top 20
- search: explore.lua's settings (normal,command_normal -> normal,command_normal,special,od_special,super, manual -> manual,simple, max 3 moves, beam 4000, collapse true)
- search complete: true - every route the settings can reach is in the list below
- Drive Rush Cancel edges in the search: no (pass --drive-rush to route through them)
- demote routes through a rejected pair: yes

## Damage figure

Ordered on `offline_score.predicted_damage_scaled`, the combo-scaled prediction.

6 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 423 (search complete: true)

- routes satisfying every condition: 423
- of those, through a pair the policy CONCLUSIVELY rejected: 277 (ranked after the clean ones)
- in this plan (top 20): 20

Demotion counts conclusive failures only. Under policy `ce-eval-v1` a negative is one when the run pressed a playable input at the right timing; 343 of 856 runs were left out for asking something else, 213 of them negatives. 70 pair(s) changed status because of it.

### Moved below the top 20 by a rejected pair: 18

The sort alone would have put these in the plan. They are not deleted - they
rank after every clean route, and `--no-demote-rejected` puts them back. Some
rejections in the logs come from experiments later found broken (#46, #49).

- sort #1 3 + 强 → 6 + 强 → 236236 + 中 - rejected: 633:manual->662:manual
- sort #2 6 + 强 → 2 + 强 → 236236 + 中 - rejected: 662:manual->623:manual
- sort #3 6 + 强 → 3 + 强 → 236236 + 中 - rejected: 662:manual->633:manual
- sort #4 6 + 强 → 3 + 中 → 236236 + 中 - rejected: 662:manual->655:manual
- sort #5 2 + 强 → 3 + 强 → 236236 + 中 - rejected: 623:manual->633:manual
- sort #6 3 + 强 → 2 + 强 → 236236 + 中 - rejected: 633:manual->623:manual
- sort #7 6 + 强 → 2 + 中 → 236236 + 中 - rejected: 662:manual->621:manual
- sort #9 2 + 强 → 3 + 中 → 236236 + 中 - rejected: 623:manual->655:manual
- sort #10 3 + 强 → 3 + 中 → 236236 + 中 - rejected: 633:manual->655:manual
- sort #11 3 + 强 → 6 + 强 → 4 + SP + 强 - rejected: 633:manual->662:manual, 662:manual->1206:simple
- sort #12 6 + 强 → 2 + 强 → 4 + SP + 强 - rejected: 662:manual->623:manual, 623:manual->1206:simple
- sort #13 6 + 强 → 3 + 强 → 4 + SP + 强 - rejected: 662:manual->633:manual
- sort #14 2 + 强 → 2 + 中 → 236236 + 中 - rejected: 623:manual->621:manual
- sort #15 3 + 强 → 2 + 中 → 236236 + 中 - rejected: 633:manual->621:manual
- sort #16 6 + 强 → 弱 → 236236 + 中 - rejected: 662:manual->601:manual
- sort #17 3 + 强 → 6 + 强 → 22 + 强 - rejected: 633:manual->662:manual
- sort #18 6 + 强 → 2 + 强 → 22 + 强 - rejected: 662:manual->623:manual
- sort #19 6 + 强 → 3 + 强 → 22 + 强 - rejected: 662:manual->633:manual

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 8 | 6 + 强 → 236236 + 中 | 6+HK → 236236+P | 4460 | 4460 | SA 1, drive >=0 (1 unknown) | 8.9 | medium | 0/1 pairs reproduced; never asked properly: 662:manual->1206:manual |
| 2 | 20 | 2 + 强 → 236236 + 中 | 2+HP → 236236+P | 4160 | 4160 | SA 1, drive >=0 (1 unknown) | 8.9 | medium | 0/1 pairs reproduced; never asked properly: 623:manual->1206:manual |
| 3 | 21 | 3 + 强 → 236236 + 中 | 2+HK → 236236+P | 4160 | 4160 | SA 1, drive >=0 (1 unknown) | 8.9 | medium | confirmed combo |
| 4 | 28 | 3 + 中 → 236236 + 中 | 3+MP → 236236+P | 3960 | 3960 | SA 1, drive >=0 (1 unknown) | 8.9 | high | linked once as a combo; 0/1 pairs reproduced; linked once: 655:manual->1206:manual |
| 5 | 34 | 2 + 中 → 236236 + 中 | 2+MP → 236236+P | 3860 | 3860 | SA 1, drive >=0 (1 unknown) | 8.9 | high | confirmed combo |
| 6 | 45 | 6 + 强 → 22 + 强 | 6+HK → 22+HK | 3700 | 3700 | drive 0 | 5.3 | low | 0/1 pairs reproduced |
| 7 | 46 | 弱 → 6 + 强 → 236236 + 中 | LP → 6+HK → 236236+P | 3652 | 4860 | SA 1, drive >=0 (1 unknown) | 10.4 | medium | 0/2 pairs reproduced; never asked properly: 662:manual->1206:manual |
| 8 | 51 | 2 + 弱 → 6 + 强 → 236236 + 中 | 2+LP → 6+HK → 236236+P | 3552 | 4760 | SA 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs reproduced; never asked properly: 617:manual->662:manual, 662:manual->1206:manual |
| 9 | 53 | 3 + 强 → 4 + SP + 强 | 2+HK → 236236+P | 3528 | 4160 | SA 1, drive >=0 (1 unknown) | 6.5 | medium | confirmed combo |
| 10 | 57 | 弱 → 2 + 强 → 236236 + 中 | LP → 2+HP → 236236+P | 3412 | 4560 | SA 1, drive >=0 (1 unknown) | 10.4 | medium | 0/2 pairs reproduced; never asked properly: 623:manual->1206:manual |
| 11 | 58 | 弱 → 3 + 强 → 236236 + 中 | LP → 2+HK → 236236+P | 3412 | 4560 | SA 1, drive >=0 (1 unknown) | 10.4 | medium | 0/2 pairs reproduced; never asked properly: 633:manual->1206:manual |
| 12 | 59 | 2 + 强 → 22 + 强 | 2+HP → 22+HK | 3400 | 3400 | drive 0 | 5.3 | low | 0/1 pairs reproduced |
| 13 | 60 | 3 + 强 → 22 + 强 | 2+HK → 22+HK | 3400 | 3400 | drive 0 | 5.3 | low | 0/1 pairs reproduced |
| 14 | 62 | 3 + 中 → 4 + SP + 强 | 3+MP → 236236+P | 3328 | 3960 | SA 1, drive >=0 (1 unknown) | 6.5 | high | linked once as a combo; 0/1 pairs reproduced; linked once: 655:manual->1206:simple |
| 15 | 67 | 2 + 弱 → 2 + 强 → 236236 + 中 | 2+LP → 2+HP → 236236+P | 3312 | 4460 | SA 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs reproduced; never asked properly: 617:manual->623:manual, 623:manual->1206:manual |
| 16 | 68 | 2 + 弱 → 3 + 强 → 236236 + 中 | 2+LP → 2+HK → 236236+P | 3312 | 4460 | SA 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs reproduced; never asked properly: 617:manual->633:manual, 633:manual->1206:manual |
| 17 | 69 | 弱 → 3 + 中 → 236236 + 中 | LP → 3+MP → 236236+P | 3252 | 4360 | SA 1, drive >=0 (1 unknown) | 10.4 | medium | 0/2 pairs reproduced; linked once: 655:manual->1206:manual |
| 18 | 70 | 2 + 中 → 4 + SP + 强 | 2+MP → 236236+P | 3228 | 3860 | SA 1, drive >=0 (1 unknown) | 6.5 | high | confirmed combo |
| 19 | 74 | 3 + 中 → 22 + 强 | 3+MP → 22+HK | 3200 | 3200 | drive 0 | 5.3 | low | 0/1 pairs reproduced |
| 20 | 75 | 弱 → 2 + 中 → 236236 + 中 | LP → 2+MP → 236236+P | 3172 | 4260 | SA 1, drive >=0 (1 unknown) | 10.4 | medium | 0/2 pairs reproduced; linked once: 621:manual->1206:manual |

## Pairs to sweep: 18

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 159 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 6 + 强 → 236236 + 中 | `662:manual->1206:manual` | 1, 7, 8 | asked_badly | single | medium | 10 |
| 2 | 2 + 强 → 236236 + 中 | `623:manual->1206:manual` | 2, 10, 15 | asked_badly | single | medium | 2 |
| 3 | 3 + 强 → 236236 + 中 | `633:manual->1206:manual` | 3, 11, 16 | asked_badly | single | medium | 18 |
| 4 | 3 + 中 → 236236 + 中 | `655:manual->1206:manual` | 4, 17 | linked_once | single | high | -19 |
| 5 | 2 + 中 → 236236 + 中 | `621:manual->1206:manual` | 5, 20 | linked_once | single | high | -15 |
| 6 | 6 + 强 → 22 + 强 | `662:manual->785:manual` | 6 | pending | repeat | low | 22 |
| 7 | 弱 → 6 + 强 | `601:manual->662:manual` | 7 | pending as `611:manual->662:manual` | single | medium | -18 |
| 8 | 2 + 弱 → 6 + 强 | `617:manual->662:manual` | 8 | asked_badly | single | medium | -16 |
| 9 | 弱 → 2 + 强 | `601:manual->623:manual` | 10 | pending as `611:manual->623:manual` | single | medium | -7 |
| 10 | 弱 → 3 + 强 | `601:manual->633:manual` | 11 | pending as `611:manual->633:manual` | single | medium | -8 |
| 11 | 2 + 强 → 22 + 强 | `623:manual->785:manual` | 12 | pending | repeat | low | 14 |
| 12 | 3 + 强 → 22 + 强 | `633:manual->785:manual` | 13 | pending | repeat | low | 30 |
| 13 | 3 + 中 → 4 + SP + 强 | `655:manual->1206:simple` | 14 | linked_once | single | high | -19 |
| 14 | 2 + 弱 → 2 + 强 | `617:manual->623:manual` | 15 | asked_badly | single | medium | -5 |
| 15 | 2 + 弱 → 3 + 强 | `617:manual->633:manual` | 16 | asked_badly | single | medium | -6 |
| 16 | 弱 → 3 + 中 | `601:manual->655:manual` | 17 | pending as `611:manual->655:manual` | single | medium | -3 |
| 17 | 3 + 中 → 22 + 强 | `655:manual->785:manual` | 19 | pending | repeat | low | -7 |
| 18 | 弱 → 2 + 中 | `601:manual->621:manual` | 20 | pending as `611:manual->621:manual` | single | medium | -4 |

**4 of these the sweep cannot press as written.**

### Pairs whose every negative was thrown out: 6

Trials were spent on these and none of them asked whether the pair links: the
fixed gap of 4 inside A's animation (#46), a cancel-only pair pressed at the link
gap after A had recovered, B's button a motion's worth of ticks late, or an input
today's compiler would not press (#49). They read as `pending` to the plan and
they do NOT demote a route - nobody has asked yet.

- `662:manual->1206:manual`: pending (0 linked / 0 counted no / 0 left out); pending (0 linked / 0 counted no / 2 left out: motion_button_late 1, superseded_rerun 1)
- `623:manual->1206:manual`: pending (0 linked / 0 counted no / 0 left out); pending (0 linked / 0 counted no / 2 left out: motion_button_late 1, superseded_rerun 1)
- `633:manual->1206:manual`: pending (0 linked / 0 counted no / 0 left out); pending (0 linked / 0 counted no / 2 left out: motion_button_late 1, superseded_rerun 1)
- `617:manual->662:manual`: pending (0 linked / 0 counted no / 0 left out); pending (0 linked / 0 counted no / 2 left out: link_timing_on_cancel_pair 1, superseded_rerun 1)
- `617:manual->623:manual`: pending (0 linked / 0 counted no / 0 left out); pending (0 linked / 0 counted no / 2 left out: link_timing_on_cancel_pair 1, superseded_rerun 1)
- `617:manual->633:manual`: pending (0 linked / 0 counted no / 0 left out); pending (0 linked / 0 counted no / 2 left out: link_timing_on_cancel_pair 1, superseded_rerun 1)

### Pairs that linked but were never reproduced: 3

The game said yes, and not twice at one delay - which is ConfirmedEdge's rule for
`stable` and the database's for a confirmed pair. They stay in the sweep: one more
link at the gap that already worked is the cheapest question in the plan.

- `655:manual->1206:manual`: observed_success (1 linked / 0 counted no / 0 left out); pending (0 linked / 0 counted no / 2 left out: link_timing_on_cancel_pair 1, superseded_rerun 1)
- `621:manual->1206:manual`: observed_success (1 linked / 0 counted no / 0 left out); pending (0 linked / 0 counted no / 2 left out: link_timing_on_cancel_pair 1, superseded_rerun 1)
- `655:manual->1206:simple`: observed_success (1 linked / 0 counted no / 0 left out); pending (0 linked / 0 counted no / 2 left out: link_timing_on_cancel_pair 1, superseded_rerun 1)

## Already known: 2

Left out of the worklist (pass --include-verified to keep verified pairs).

- `633:manual->1206:simple` (3 + 强 → 4 + SP + 强): verified by the game, needed by 9
- `621:manual->1206:simple` (2 + 中 → 4 + SP + 强): verified by the game, needed by 18

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

## Running it

Copy the worklist to the game machine (`scripts/install-dev.ps1` syncs
reframework/data), then pick `plan: max-damage` in the SWEEP panel's worklist list
(REFRESH if the panel was already open) and START SWEEP. It writes to the same
trial log as the full sweep, so pairs the full sweep already answered under the
same calibration and conditions are skipped, and the other way round.

## Written

- reframework/data/ComboExplorer_data/worklist/zangief-modern-plan-max-damage.json  (18 pairs, 40700 bytes)
- docs/ComboExplorer/plans/zangief-modern-max-damage.md
