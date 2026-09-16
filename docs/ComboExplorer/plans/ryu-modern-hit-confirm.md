# Route plan - Ryu / modern - hit-confirm

Generated 2026-09-16T01:53:17Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

EVERY ROUTE HERE IS A THEORETICAL CANDIDATE. The ranking is a prediction from
the frame data. The worklist below is the smallest set of pairs that lets the
game say whether these routes connect.

## Conditions

- `starter_buttons` = `L,M`
- `first_pair_mechanism` = `cancel,both`
- sort: `scaled_damage`, top 20
- search: explore.lua's settings (normal,command_normal -> normal,command_normal,special,od_special,super, manual -> manual,simple, max 4 moves - --search-steps, deeper than explore.lua's 3, beam 60000, collapse true)
- search complete: true - every route the settings can reach is in the list below
- Drive Rush Cancel edges in the search: no (pass --drive-rush to route through them)
- demote routes through a rejected pair: yes

## Damage figure

Ordered on `offline_score.predicted_damage_scaled`, the combo-scaled prediction.

25 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 4538 (search complete: true)

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| starter_buttons | L,M | 4538 | 1583 | 2955 | 0 |
| first_pair_mechanism | cancel,both | 2955 | 582 | 2373 | 0 |

- routes satisfying every condition: 2373
- of those, through a pair the policy CONCLUSIVELY rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

Demotion counts conclusive failures only. Under policy `ce-eval-v1` a negative is one when the run pressed a playable input at the right timing; 0 of 0 runs were left out for asking something else, 0 of them negatives. 0 pair(s) changed status because of it.

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 中 → 236236 + 强 | MP → 236236+K | 4600 | 4600 | SA 1, drive >=0 (1 unknown) | 8.4 | low | 0/1 pairs reproduced |
| 2 | 2 | 2 + 中 → 236236 + 强 | 2+MK → 236236+K | 4500 | 4500 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs reproduced |
| 3 | 3 | 弱 → 3 + 强 → 强 → 236236 + 强 | LP → 2+HK → HP → 236236+K | 3980 | 6000 | SA 1, drive >=0 (1 unknown) | 11.9 | low | 0/3 pairs reproduced |
| 4 | 4 | 弱 → 3 + 强 → 2 + 强 → 236236 + 强 | LP → 2+HK → 2+HP → 236236+K | 3980 | 6000 | SA 1, drive >=0 (1 unknown) | 12.4 | low | 0/3 pairs reproduced |
| 5 | 5 | 2 + 弱 → 3 + 强 → 强 → 236236 + 强 | 2+LP → 2+HK → HP → 236236+K | 3980 | 6000 | SA 1, drive >=0 (1 unknown) | 12.4 | low | 0/3 pairs reproduced |
| 6 | 6 | 2 + 弱 → 3 + 强 → 2 + 强 → 236236 + 强 | 2+LP → 2+HK → 2+HP → 236236+K | 3980 | 6000 | SA 1, drive >=0 (1 unknown) | 12.9 | low | 0/3 pairs reproduced |
| 7 | 7 | 弱 → 3 + 强 → 中 → 236236 + 强 | LP → 2+HK → MP → 236236+K | 3840 | 5800 | SA 1, drive >=0 (1 unknown) | 11.9 | low | 0/3 pairs reproduced |
| 8 | 8 | 2 + 弱 → 3 + 强 → 中 → 236236 + 强 | 2+LP → 2+HK → MP → 236236+K | 3840 | 5800 | SA 1, drive >=0 (1 unknown) | 12.4 | low | 0/3 pairs reproduced |
| 9 | 9 | 弱 → 3 + 强 → 236236 + 强 | LP → 2+HK → 236236+K | 3820 | 5200 | SA 1, drive >=0 (1 unknown) | 10.4 | low | 0/2 pairs reproduced |
| 10 | 10 | 2 + 弱 → 3 + 强 → 236236 + 强 | 2+LP → 2+HK → 236236+K | 3820 | 5200 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs reproduced |
| 11 | 11 | 中 → 2 + SP + 强 | MP → 236236+K | 3800 | 4600 | SA 1, drive >=0 (1 unknown) | 6.0 | low | 0/1 pairs reproduced |
| 12 | 12 | 弱 → 3 + 强 → 2 + 中 → 236236 + 强 | LP → 2+HK → 2+MK → 236236+K | 3770 | 5700 | SA 1, drive >=0 (1 unknown) | 12.4 | low | 0/3 pairs reproduced |
| 13 | 13 | 2 + 弱 → 3 + 强 → 2 + 中 → 236236 + 强 | 2+LP → 2+HK → 2+MK → 236236+K | 3770 | 5700 | SA 1, drive >=0 (1 unknown) | 12.9 | low | 0/3 pairs reproduced |
| 14 | 14 | 弱 → 强 → 236236 + 强 | LP → HP → 236236+K | 3740 | 5100 | SA 1, drive >=0 (1 unknown) | 9.9 | low | 0/2 pairs reproduced |
| 15 | 15 | 弱 → 2 + 强 → 236236 + 强 | LP → 2+HP → 236236+K | 3740 | 5100 | SA 1, drive >=0 (1 unknown) | 10.4 | low | 0/2 pairs reproduced |
| 16 | 16 | 2 + 弱 → 强 → 236236 + 强 | 2+LP → HP → 236236+K | 3740 | 5100 | SA 1, drive >=0 (1 unknown) | 10.4 | low | 0/2 pairs reproduced |
| 17 | 17 | 2 + 弱 → 2 + 强 → 236236 + 强 | 2+LP → 2+HP → 236236+K | 3740 | 5100 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs reproduced |
| 18 | 18 | 弱 → 3 + 强 → 4 + 强 → 236236 + 强 | LP → 2+HK → 4+HK → 236236+K | 3700 | 5600 | SA 1, drive >=0 (1 unknown) | 12.4 | low | 0/3 pairs reproduced |
| 19 | 19 | 2 + 弱 → 3 + 强 → 4 + 强 → 236236 + 强 | 2+LP → 2+HK → 4+HK → 236236+K | 3700 | 5600 | SA 1, drive >=0 (1 unknown) | 12.9 | low | 0/3 pairs reproduced |
| 20 | 20 | 2 + 中 → 2 + SP + 强 | 2+MK → 236236+K | 3700 | 4500 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs reproduced |

## Pairs to sweep: 19

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 551 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 中 → 236236 + 强 | `605:manual->1233:manual` | 1, 7, 8 | untested | single | low | 2 |
| 2 | 2 + 中 → 236236 + 强 | `640:manual->1233:manual` | 2, 12, 13 | untested | single | low | -4 |
| 3 | 弱 → 3 + 强 | `600:manual->643:manual` | 3, 4, 7, 9, 12, 18 | untested | single | medium | -5 |
| 4 | 3 + 强 → 强 | `643:manual->608:manual` | 3, 5 | untested | single | medium | 30 |
| 5 | 强 → 236236 + 强 | `608:manual->1233:manual` | 3, 5, 14, 16 | untested | single | low | -1 |
| 6 | 3 + 强 → 2 + 强 | `643:manual->630:manual` | 4, 6 | untested | single | medium | 31 |
| 7 | 2 + 强 → 236236 + 强 | `630:manual->1233:manual` | 4, 6, 15, 17 | untested | single | low | -4 |
| 8 | 2 + 弱 → 3 + 强 | `623:manual->643:manual` | 5, 6, 8, 10, 13, 19 | untested | single | medium | -5 |
| 9 | 3 + 强 → 中 | `643:manual->605:manual` | 7, 8 | untested | single | medium | 34 |
| 10 | 3 + 强 → 236236 + 强 | `643:manual->1233:manual` | 9, 10 | untested | single | low | 35 |
| 11 | 中 → 2 + SP + 强 | `605:manual->1233:simple` | 11 | untested | single | low | 2 |
| 12 | 3 + 强 → 2 + 中 | `643:manual->640:manual` | 12, 13 | untested | single | medium | 32 |
| 13 | 弱 → 强 | `600:manual->608:manual` | 14 | untested | single | medium | -6 |
| 14 | 弱 → 2 + 强 | `600:manual->630:manual` | 15 | untested | single | medium | -5 |
| 15 | 2 + 弱 → 强 | `623:manual->608:manual` | 16 | untested | single | medium | -6 |
| 16 | 2 + 弱 → 2 + 强 | `623:manual->630:manual` | 17 | untested | single | medium | -5 |
| 17 | 3 + 强 → 4 + 强 | `643:manual->668:manual` | 18, 19 | untested | single | medium | 30 |
| 18 | 4 + 强 → 236236 + 强 | `668:manual->1233:manual` | 18, 19 | untested | single | low | -5 |
| 19 | 2 + 中 → 2 + SP + 强 | `640:manual->1233:simple` | 20 | untested | single | low | -4 |

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
| 1 | 中 → 236236 + 强 | `ryu-modern-hit-confirm-1.json` | 9 | gap 1 0/8/10/12/20/21/22/23/24 (predicted) |
| 2 | 2 + 中 → 236236 + 强 | `ryu-modern-hit-confirm-2.json` | 4 | gap 1 0/8/10/12 (predicted) |
| 3 | 弱 → 3 + 强 → 强 → 236236 + 强 | `ryu-modern-hit-confirm-3.json` | 80 | gap 1 0/9/11/13 (predicted); gap 2 41/42/43/44/45 (predicted); gap 3 1/14/16/18 (predicted) |

`measured` is the gaps the policy's counted runs linked that pair at; `predicted`
is runtime/Sweep.plan_for's own grid from the frame data, a link gap widened to the
window the input buffer covers (`input_buffer_ticks` = 4, unverified); `default` is
core/Route.DEFAULT_DELAYS, which measures nothing and says so. No gap is ever
given a single invented number.

## Running it

Copy the worklist to the game machine (`scripts/install-dev.ps1` syncs
reframework/data), then pick `plan: hit-confirm` in the SWEEP panel's worklist list
(REFRESH if the panel was already open) and START SWEEP. It writes to the same
trial log as the full sweep, so pairs the full sweep already answered under the
same calibration and conditions are skipped, and the other way round.

## Written

- reframework/data/ComboExplorer_data/worklist/ryu-modern-plan-hit-confirm.json  (19 pairs, 46167 bytes)
- reframework/data/ComboExplorer_data/route/ryu-modern-hit-confirm-1.json  (2 step(s), 9 gap combination(s), 1717 bytes)
- reframework/data/ComboExplorer_data/route/ryu-modern-hit-confirm-2.json  (2 step(s), 4 gap combination(s), 1531 bytes)
- reframework/data/ComboExplorer_data/route/ryu-modern-hit-confirm-3.json  (4 step(s), 80 gap combination(s), 2579 bytes)
- docs/ComboExplorer/plans/ryu-modern-hit-confirm.md
