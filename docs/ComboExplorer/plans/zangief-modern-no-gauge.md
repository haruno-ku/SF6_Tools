# Route plan - Zangief / modern - no-gauge

Generated 2026-09-16T02:18:51Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

EVERY ROUTE HERE IS A THEORETICAL CANDIDATE. The ranking is a prediction from
the frame data. The worklist below is the smallest set of pairs that lets the
game say whether these routes connect.

## Conditions

- `no_gauge` = `true`
- sort: `scaled_damage`, top 20
- search: explore.lua's settings (normal,command_normal -> normal,command_normal,special,od_special,super, manual -> manual,simple, max 3 moves, beam 4000, collapse true)
- search complete: true - every route the settings can reach is in the list below
- Drive Rush Cancel edges in the search: no (pass --drive-rush to route through them)
- demote routes through a rejected pair: yes

`no_gauge` removes a route with an OD move, a super, a Drive Rush Cancel, or any
KNOWN Drive or Super spend. A route where some move has no Drive figure is kept and
flagged: nothing in the source says it spends, and a missing value never excludes.

## Damage figure

Ordered on `offline_score.predicted_damage_scaled`, the combo-scaled prediction.

6 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 423 (search complete: true)

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| no_gauge | true | 423 | 76 | 347 | 6 |

- routes satisfying every condition: 347
- of those, through a pair the policy CONCLUSIVELY rejected: 235 (ranked after the clean ones)
- in this plan (top 20): 20

Demotion counts conclusive failures only. Under policy `ce-eval-v1` a negative is one when the run pressed a playable input at the right timing; 343 of 856 runs were left out for asking something else, 213 of them negatives. 70 pair(s) changed status because of it.

### Moved below the top 20 by a rejected pair: 17

The sort alone would have put these in the plan. They are not deleted - they
rank after every clean route, and `--no-demote-rejected` puts them back. Some
rejections in the logs come from experiments later found broken (#46, #49).

- sort #1 3 + 强 → 6 + 强 → 22 + 强 - rejected: 633:manual->662:manual
- sort #2 6 + 强 → 2 + 强 → 22 + 强 - rejected: 662:manual->623:manual
- sort #3 6 + 强 → 3 + 强 → 22 + 强 - rejected: 662:manual->633:manual
- sort #4 6 + 强 → 3 + 中 → 22 + 强 - rejected: 662:manual->655:manual
- sort #5 2 + 强 → 3 + 强 → 22 + 强 - rejected: 623:manual->633:manual
- sort #6 3 + 强 → 2 + 强 → 22 + 强 - rejected: 633:manual->623:manual
- sort #7 6 + 强 → 2 + 中 → 22 + 强 - rejected: 662:manual->621:manual
- sort #8 2 + 强 → 3 + 中 → 22 + 强 - rejected: 623:manual->655:manual
- sort #9 3 + 强 → 3 + 中 → 22 + 强 - rejected: 633:manual->655:manual
- sort #11 2 + 强 → 2 + 中 → 22 + 强 - rejected: 623:manual->621:manual
- sort #12 3 + 强 → 2 + 中 → 22 + 强 - rejected: 633:manual->621:manual
- sort #13 6 + 强 → 弱 → 22 + 强 - rejected: 662:manual->601:manual
- sort #14 6 + 强 → 2 + 弱 → 22 + 强 - rejected: 662:manual->617:manual
- sort #17 6 + 强 → 3 + 强 → 6 + 强 - rejected: 662:manual->633:manual, 633:manual->662:manual
- sort #18 2 + 强 → 弱 → 22 + 强 - rejected: 623:manual->601:manual
- sort #19 3 + 强 → 弱 → 22 + 强 - rejected: 633:manual->601:manual
- sort #20 2 + 强 → 2 + 弱 → 22 + 强 - rejected: 623:manual->617:manual

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 10 | 6 + 强 → 22 + 强 | 6+HK → 22+HK | 3700 | 3700 | drive 0 | 5.3 | low | 0/1 pairs reproduced |
| 2 | 15 | 2 + 强 → 22 + 强 | 2+HP → 22+HK | 3400 | 3400 | drive 0 | 5.3 | low | 0/1 pairs reproduced |
| 3 | 16 | 3 + 强 → 22 + 强 | 2+HK → 22+HK | 3400 | 3400 | drive 0 | 5.3 | low | 0/1 pairs reproduced |
| 4 | 22 | 3 + 中 → 22 + 强 | 3+MP → 22+HK | 3200 | 3200 | drive 0 | 5.3 | low | 0/1 pairs reproduced |
| 5 | 23 | 弱 → 6 + 强 → 22 + 强 | LP → 6+HK → 22+HK | 3120 | 4100 | drive 0 | 6.8 | low | 0/2 pairs reproduced |
| 6 | 24 | 2 + 中 → 22 + 强 | 2+MP → 22+HK | 3100 | 3100 | drive 0 | 5.3 | low | 0/1 pairs reproduced; never asked properly: 621:manual->785:manual |
| 7 | 33 | 2 + 弱 → 6 + 强 → 22 + 强 | 2+LP → 6+HK → 22+HK | 3020 | 4000 | drive 0 | 7.3 | low | 0/2 pairs reproduced; never asked properly: 617:manual->662:manual |
| 8 | 38 | 弱 → 2 + 强 → 22 + 强 | LP → 2+HP → 22+HK | 2880 | 3800 | drive 0 | 6.8 | low | 0/2 pairs reproduced |
| 9 | 39 | 弱 → 3 + 强 → 22 + 强 | LP → 2+HK → 22+HK | 2880 | 3800 | drive 0 | 6.8 | low | 0/2 pairs reproduced |
| 10 | 56 | 2 + 弱 → 2 + 强 → 22 + 强 | 2+LP → 2+HP → 22+HK | 2780 | 3700 | drive 0 | 7.3 | low | 0/2 pairs reproduced; never asked properly: 617:manual->623:manual |
| 11 | 57 | 2 + 弱 → 3 + 强 → 22 + 强 | 2+LP → 2+HK → 22+HK | 2780 | 3700 | drive 0 | 7.3 | low | 0/2 pairs reproduced; never asked properly: 617:manual->633:manual |
| 12 | 59 | 弱 → 3 + 中 → 22 + 强 | LP → 3+MP → 22+HK | 2720 | 3600 | drive 0 | 6.8 | low | 0/2 pairs reproduced |
| 13 | 63 | 弱 → 2 + 中 → 22 + 强 | LP → 2+MP → 22+HK | 2640 | 3500 | drive 0 | 6.8 | low | 0/2 pairs reproduced; never asked properly: 621:manual->785:manual |
| 14 | 67 | 2 + 弱 → 3 + 中 → 22 + 强 | 2+LP → 3+MP → 22+HK | 2620 | 3500 | drive 0 | 7.3 | low | 0/2 pairs reproduced; never asked properly: 617:manual->655:manual |
| 15 | 79 | 2 + 弱 → 2 + 中 → 22 + 强 | 2+LP → 2+MP → 22+HK | 2540 | 3400 | drive 0 | 7.3 | low | 0/2 pairs reproduced; never asked properly: 617:manual->621:manual, 621:manual->785:manual |
| 16 | 95 | 弱 → 弱 → 22 + 强 | LP → LP → 22+HK | 2400 | 3200 | drive 0 | 5.8 | low | 0/2 pairs reproduced |
| 17 | 105 | 弱 → 2 + 弱 → 22 + 强 | LP → 2+LP → 22+HK | 2320 | 3100 | drive 0 | 6.8 | low | 0/2 pairs reproduced; never asked properly: 617:manual->785:manual |
| 18 | 106 | 弱 → 22 + 强 | LP → 22+HK | 2320 | 2800 | drive 0 | 4.8 | low | 0/1 pairs reproduced |
| 19 | 109 | 2 + 弱 → 弱 → 22 + 强 | 2+LP → LP → 22+HK | 2300 | 3100 | drive 0 | 6.8 | low | 0/2 pairs reproduced; never asked properly: 617:manual->601:manual |
| 20 | 113 | 6 + 强 → 强 | 6+HK → HP | 2300 | 2300 | drive 0 | 3.5 | low | 0/1 pairs reproduced |

## Pairs to sweep: 21

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 159 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 6 + 强 → 22 + 强 | `662:manual->785:manual` | 1, 5, 7 | pending | repeat | low | 22 |
| 2 | 2 + 强 → 22 + 强 | `623:manual->785:manual` | 2, 8, 10 | pending | repeat | low | 14 |
| 3 | 3 + 强 → 22 + 强 | `633:manual->785:manual` | 3, 9, 11 | pending | repeat | low | 30 |
| 4 | 3 + 中 → 22 + 强 | `655:manual->785:manual` | 4, 12, 14 | pending | repeat | low | -7 |
| 5 | 弱 → 6 + 强 | `601:manual->662:manual` | 5 | pending as `611:manual->662:manual` | single | medium | -18 |
| 6 | 2 + 中 → 22 + 强 | `621:manual->785:manual` | 6, 13, 15 | asked_badly | repeat | low | -3 |
| 7 | 2 + 弱 → 6 + 强 | `617:manual->662:manual` | 7 | asked_badly | single | medium | -16 |
| 8 | 弱 → 2 + 强 | `601:manual->623:manual` | 8 | pending as `611:manual->623:manual` | single | medium | -7 |
| 9 | 弱 → 3 + 强 | `601:manual->633:manual` | 9 | pending as `611:manual->633:manual` | single | medium | -8 |
| 10 | 2 + 弱 → 2 + 强 | `617:manual->623:manual` | 10 | asked_badly | single | medium | -5 |
| 11 | 2 + 弱 → 3 + 强 | `617:manual->633:manual` | 11 | asked_badly | single | medium | -6 |
| 12 | 弱 → 3 + 中 | `601:manual->655:manual` | 12 | pending as `611:manual->655:manual` | single | medium | -3 |
| 13 | 弱 → 2 + 中 | `601:manual->621:manual` | 13 | pending as `611:manual->621:manual` | single | medium | -4 |
| 14 | 2 + 弱 → 3 + 中 | `617:manual->655:manual` | 14 | asked_badly | single | medium | -1 |
| 15 | 2 + 弱 → 2 + 中 | `617:manual->621:manual` | 15 | asked_badly | single | medium | -2 |
| 16 | 弱 → 弱 | `601:manual->601:manual` | 16 | pending as `611:manual->611:manual` | single | medium | -3 |
| 17 | 弱 → 22 + 强 | `601:manual->785:manual` | 16, 18, 19 | pending as `611:manual->785:manual` | repeat | low | -2 |
| 18 | 弱 → 2 + 弱 | `601:manual->617:manual` | 17 | pending as `611:manual->617:manual` | single | medium | -2 |
| 19 | 2 + 弱 → 22 + 强 | `617:manual->785:manual` | 17 | asked_badly | repeat | low | 0 |
| 20 | 2 + 弱 → 弱 | `617:manual->601:manual` | 19 | asked_badly as `617:manual->611:manual` | single | medium | -1 |
| 21 | 6 + 强 → 强 | `662:manual->637:manual` | 20 | pending | single | low | - |

**7 of these the sweep cannot press as written.**

### Pairs whose every negative was thrown out: 8

Trials were spent on these and none of them asked whether the pair links: the
fixed gap of 4 inside A's animation (#46), a cancel-only pair pressed at the link
gap after A had recovered, B's button a motion's worth of ticks late, or an input
today's compiler would not press (#49). They read as `pending` to the plan and
they do NOT demote a route - nobody has asked yet.

- `621:manual->785:manual`: pending (0 linked / 0 counted no / 1 left out: fixed_delay_4 1); pending (0 linked / 0 counted no / 1 left out: superseded_rerun 1)
- `617:manual->662:manual`: pending (0 linked / 0 counted no / 0 left out); pending (0 linked / 0 counted no / 2 left out: link_timing_on_cancel_pair 1, superseded_rerun 1)
- `617:manual->623:manual`: pending (0 linked / 0 counted no / 0 left out); pending (0 linked / 0 counted no / 2 left out: link_timing_on_cancel_pair 1, superseded_rerun 1)
- `617:manual->633:manual`: pending (0 linked / 0 counted no / 0 left out); pending (0 linked / 0 counted no / 2 left out: link_timing_on_cancel_pair 1, superseded_rerun 1)
- `617:manual->655:manual`: pending (0 linked / 0 counted no / 0 left out); pending (0 linked / 0 counted no / 2 left out: link_timing_on_cancel_pair 1, superseded_rerun 1)
- `617:manual->621:manual`: pending (0 linked / 0 counted no / 0 left out); pending (0 linked / 0 counted no / 2 left out: link_timing_on_cancel_pair 1, superseded_rerun 1)
- `617:manual->785:manual`: pending (0 linked / 0 counted no / 1 left out: fixed_delay_4 1); pending (0 linked / 0 counted no / 1 left out: superseded_rerun 1)
- `617:manual->601:manual`: as 617:manual->611:manual pending (0 linked / 0 counted no / 0 left out); as 617:manual->611:manual pending (0 linked / 0 counted no / 2 left out: link_timing_on_cancel_pair 1, superseded_rerun 1)

## Already known: 0

Nothing these routes need has been answered yet.

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
reframework/data), then pick `plan: no-gauge` in the SWEEP panel's worklist list
(REFRESH if the panel was already open) and START SWEEP. It writes to the same
trial log as the full sweep, so pairs the full sweep already answered under the
same calibration and conditions are skipped, and the other way round.

## Written

- reframework/data/ComboExplorer_data/worklist/zangief-modern-plan-no-gauge.json  (21 pairs, 43774 bytes)
- docs/ComboExplorer/plans/zangief-modern-no-gauge.md
