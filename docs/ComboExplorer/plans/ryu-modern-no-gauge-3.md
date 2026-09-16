# Route plan - Ryu / modern - no-gauge-3

Generated 2026-09-16T02:18:13Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

EVERY ROUTE HERE IS A THEORETICAL CANDIDATE. The ranking is a prediction from
the frame data. The worklist below is the smallest set of pairs that lets the
game say whether these routes connect.

## Conditions

- `min_steps` = `3`
- `max_steps` = `3`
- `no_gauge` = `true`
- sort: `scaled_damage`, top 20
- search: explore.lua's settings (normal,command_normal -> normal,command_normal,special,od_special,super, manual -> manual,simple, max 4 moves - --search-steps, deeper than explore.lua's 3, beam 60000, collapse true)
- search complete: true - every route the settings can reach is in the list below
- Drive Rush Cancel edges in the search: no (pass --drive-rush to route through them)
- demote routes through a rejected pair: yes

`no_gauge` removes a route with an OD move, a super, a Drive Rush Cancel, or any
KNOWN Drive or Super spend. A route where some move has no Drive figure is kept and
flagged: nothing in the source says it spends, and a missing value never excludes.

## Damage figure

Ordered on `offline_score.predicted_damage_scaled`, the combo-scaled prediction.

9 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 4538 (search complete: true)

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| min_steps | 3 | 4538 | 255 | 4283 | 0 |
| max_steps | 3 | 4283 | 3412 | 871 | 0 |
| no_gauge | true | 871 | 282 | 589 | 9 |

- routes satisfying every condition: 589
- of those, through a pair the policy CONCLUSIVELY rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

Demotion counts conclusive failures only. Under policy `ce-eval-v1` a negative is one when the run pressed a playable input at the right timing; 0 of 0 runs were left out for asking something else, 0 of them negatives. 0 pair(s) changed status because of it.

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 3 + 强 → 强 → 623 + 强 | 2+HK → HP → 623+HP | 2820 | 3100 | drive 0 | 7.7 | medium | 0/2 pairs reproduced |
| 2 | 2 | 3 + 强 → 2 + 强 → 623 + 强 | 2+HK → 2+HP → 623+HP | 2820 | 3100 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 3 | 3 | 3 + 强 → 6 + 强 → 623 + 强 | 2+HK → 6+HK → 623+HP | 2820 | 3100 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 4 | 4 | 3 + 强 → 强 → 623 + 中 | 2+HK → HP → 623+MP | 2660 | 2900 | drive 0 | 7.7 | medium | 0/2 pairs reproduced |
| 5 | 5 | 3 + 强 → 2 + 强 → 623 + 中 | 2+HK → 2+HP → 623+MP | 2660 | 2900 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 6 | 6 | 3 + 强 → 6 + 强 → 623 + 中 | 2+HK → 6+HK → 623+MP | 2660 | 2900 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 7 | 7 | 3 + 强 → 中 → 623 + 强 | 2+HK → MP → 623+HP | 2620 | 2900 | drive 0 | 7.7 | medium | 0/2 pairs reproduced |
| 8 | 8 | 3 + 强 → 强 → 6 + SP | 2+HK → HP → 623+HP | 2596 | 3100 | drive 0 | 7.5 | medium | 0/2 pairs reproduced |
| 9 | 9 | 3 + 强 → 2 + 强 → 6 + SP | 2+HK → 2+HP → 623+HP | 2596 | 3100 | drive 0 | 8.0 | medium | 0/2 pairs reproduced |
| 10 | 10 | 3 + 强 → 6 + 强 → 6 + SP | 2+HK → 6+HK → 623+HP | 2596 | 3100 | drive 0 | 8.0 | medium | 0/2 pairs reproduced |
| 11 | 11 | 3 + 强 → 强 → 623 + 弱 | 2+HK → HP → 623+LP | 2580 | 2800 | drive 0 | 7.7 | medium | 0/2 pairs reproduced |
| 12 | 12 | 3 + 强 → 2 + 强 → 623 + 弱 | 2+HK → 2+HP → 623+LP | 2580 | 2800 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 13 | 13 | 3 + 强 → 6 + 强 → 623 + 弱 | 2+HK → 6+HK → 623+LP | 2580 | 2800 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 14 | 14 | 3 + 强 → 强 → 3 + SP | 2+HK → HP → 236+HK | 2532 | 3000 | drive 0 | 7.5 | medium | 0/2 pairs reproduced |
| 15 | 15 | 3 + 强 → 2 + 强 → 3 + SP | 2+HK → 2+HP → 236+HK | 2532 | 3000 | drive 0 | 8.0 | medium | 0/2 pairs reproduced |
| 16 | 16 | 3 + 强 → 6 + 强 → 3 + SP | 2+HK → 6+HK → 236+HK | 2532 | 3000 | drive 0 | 8.0 | medium | 0/2 pairs reproduced |
| 17 | 17 | 3 + 强 → 2 + 中 → 623 + 强 | 2+HK → 2+MK → 623+HP | 2520 | 2800 | drive 0 | 8.2 | medium | 0/2 pairs reproduced |
| 18 | 18 | 3 + 强 → 强 → 2 + SP | 2+HK → HP → 236+MK | 2468 | 2900 | drive 0 | 7.5 | medium | 0/2 pairs reproduced |
| 19 | 19 | 3 + 强 → 2 + 强 → 2 + SP | 2+HK → 2+HP → 236+MK | 2468 | 2900 | drive 0 | 8.0 | medium | 0/2 pairs reproduced |
| 20 | 20 | 3 + 强 → 6 + 强 → 2 + SP | 2+HK → 6+HK → 236+MK | 2468 | 2900 | drive 0 | 8.0 | medium | 0/2 pairs reproduced |

## Pairs to sweep: 25

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 551 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 3 + 强 → 强 | `643:manual->608:manual` | 1, 4, 8, 11, 14, 18 | untested | single | medium | 30 |
| 2 | 强 → 623 + 强 | `608:manual->934:manual` | 1 | untested | single | high | -3 |
| 3 | 3 + 强 → 2 + 强 | `643:manual->630:manual` | 2, 5, 9, 12, 15, 19 | untested | single | medium | 31 |
| 4 | 2 + 强 → 623 + 强 | `630:manual->934:manual` | 2 | untested | single | high | -6 |
| 5 | 3 + 强 → 6 + 强 | `643:manual->670:manual` | 3, 6, 10, 13, 16, 20 | untested | single | medium | 24 |
| 6 | 6 + 强 → 623 + 强 | `670:manual->934:manual` | 3 | untested | single | high | -5 |
| 7 | 强 → 623 + 中 | `608:manual->932:manual` | 4 | untested | single | high | -2 |
| 8 | 2 + 强 → 623 + 中 | `630:manual->932:manual` | 5 | untested | single | high | -5 |
| 9 | 6 + 强 → 623 + 中 | `670:manual->932:manual` | 6 | untested | single | high | -4 |
| 10 | 3 + 强 → 中 | `643:manual->605:manual` | 7 | untested | single | medium | 34 |
| 11 | 中 → 623 + 强 | `605:manual->934:manual` | 7 | untested | single | high | 0 |
| 12 | 强 → 6 + SP | `608:manual->934:simple` | 8 | untested | single | high | -3 |
| 13 | 2 + 强 → 6 + SP | `630:manual->934:simple` | 9 | untested | single | high | -6 |
| 14 | 6 + 强 → 6 + SP | `670:manual->934:simple` | 10 | untested | single | high | -5 |
| 15 | 强 → 623 + 弱 | `608:manual->930:manual` | 11 | untested | single | high | -1 |
| 16 | 2 + 强 → 623 + 弱 | `630:manual->930:manual` | 12 | untested | single | high | -4 |
| 17 | 6 + 强 → 623 + 弱 | `670:manual->930:manual` | 13 | untested | single | high | -3 |
| 18 | 强 → 3 + SP | `608:manual->1029:simple` | 14 | untested | single | high | -23 |
| 19 | 2 + 强 → 3 + SP | `630:manual->1029:simple` | 15 | untested | single | high | -26 |
| 20 | 6 + 强 → 3 + SP | `670:manual->1029:simple` | 16 | untested | single | high | -25 |
| 21 | 3 + 强 → 2 + 中 | `643:manual->640:manual` | 17 | untested | single | medium | 32 |
| 22 | 2 + 中 → 623 + 强 | `640:manual->934:manual` | 17 | untested | single | high | -6 |
| 23 | 强 → 2 + SP | `608:manual->1027:simple` | 18 | untested | single | high | -14 |
| 24 | 2 + 强 → 2 + SP | `630:manual->1027:simple` | 19 | untested | single | high | -17 |
| 25 | 6 + 强 → 2 + SP | `670:manual->1027:simple` | 20 | untested | single | high | -16 |

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

## Route files for the next session: 3

`--routes 3` wrote the plan's best routes where the panel's ROUTE section reads
them. A route run presses the whole combo and records every gap combination, which
is what a verified combo with measured damage needs (#36, #37) and what a pair
sweep cannot give.

| # | route | file | grid | gap delays (where each came from) |
|---:|---|---|---:|---|
| 1 | 3 + 强 → 强 → 623 + 强 | `ryu-modern-no-gauge-3-1.json` | 20 | gap 1 41/42/43/44/45 (predicted); gap 2 4/17/19/21 (predicted) |
| 2 | 3 + 强 → 2 + 强 → 623 + 强 | `ryu-modern-no-gauge-3-2.json` | 20 | gap 1 41/42/43/44/45 (predicted); gap 2 3/16/18/20 (predicted) |
| 3 | 3 + 强 → 6 + 强 → 623 + 强 | `ryu-modern-no-gauge-3-3.json` | 20 | gap 1 41/42/43/44/45 (predicted); gap 2 10/23/25/27 (predicted) |

`measured` is the gaps the policy's counted runs linked that pair at; `predicted`
is runtime/Sweep.plan_for's own grid from the frame data, a link gap widened to the
window the input buffer covers (`input_buffer_ticks` = 4, unverified); `default` is
core/Route.DEFAULT_DELAYS, which measures nothing and says so. No gap is ever
given a single invented number.

## Running it

Copy the worklist to the game machine (`scripts/install-dev.ps1` syncs
reframework/data), then pick `plan: no-gauge-3` in the SWEEP panel's worklist list
(REFRESH if the panel was already open) and START SWEEP. It writes to the same
trial log as the full sweep, so pairs the full sweep already answered under the
same calibration and conditions are skipped, and the other way round.

## Written

- reframework/data/ComboExplorer_data/worklist/ryu-modern-plan-no-gauge-3.json  (25 pairs, 47253 bytes)
- reframework/data/ComboExplorer_data/route/ryu-modern-no-gauge-3-1.json  (3 step(s), 20 gap combination(s), 2052 bytes)
- reframework/data/ComboExplorer_data/route/ryu-modern-no-gauge-3-2.json  (3 step(s), 20 gap combination(s), 2064 bytes)
- reframework/data/ComboExplorer_data/route/ryu-modern-no-gauge-3-3.json  (3 step(s), 20 gap combination(s), 2067 bytes)
- docs/ComboExplorer/plans/ryu-modern-no-gauge-3.md
