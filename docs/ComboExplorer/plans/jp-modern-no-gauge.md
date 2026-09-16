# Route plan - JP / modern - no-gauge

Generated 2026-09-16T00:25:33Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

EVERY ROUTE HERE IS A THEORETICAL CANDIDATE. The ranking is a prediction from
the frame data. The worklist below is the smallest set of pairs that lets the
game say whether these routes connect.

## Conditions

- `no_gauge` = `true`
- sort: `scaled_damage`, top 20
- search: explore.lua's settings (normal,command_normal -> normal,command_normal,special,od_special,super, manual -> manual,simple, max 3 moves, beam 4000, collapse true)
- Drive Rush Cancel edges in the search: no (pass --drive-rush to route through them)
- demote routes through a rejected pair: yes

`no_gauge` removes a route with an OD move, a super, a Drive Rush Cancel, or any
KNOWN Drive or Super spend. A route where some move has no Drive figure is kept and
flagged: nothing in the source says it spends, and a missing value never excludes.

## Damage figure

Ordered on `offline_score.predicted_damage_scaled`, the combo-scaled prediction.

98 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 1156 (search complete: false)
  - the beam dropped 1307 partial routes and 0 routes were not emitted, so a route
    satisfying these conditions may be missing

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| no_gauge | true | 1156 | 413 | 743 | 61 |

- routes satisfying every condition: 743
- of those, through a pair the policy CONCLUSIVELY rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

Demotion counts conclusive failures only. Under policy `ce-eval-v1` a negative is one when the run pressed a playable input at the right timing; 0 of 0 runs were left out for asking something else, 0 of them negatives. 0 pair(s) changed status because of it.

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 3 + 强 → 2 + 强 → 236 + 中 | 3+HP → 2+HP → 236+MK | 2500 | 2700 | drive 0 | 8.2 | high | 0/2 pairs reproduced |
| 2 | 2 | 3 + 强 → 2 + 强 → 236 + 强 | 3+HP → 2+HP → 236+HK | 2500 | 2700 | drive 0 | 8.2 | high | 0/2 pairs reproduced |
| 3 | 3 | 3 + 强 → 2 + 强 → 214 + 弱 | 3+HP → 2+HP → 214+LP | 2340 | 2500 | drive 0 | 8.2 | high | 0/2 pairs reproduced |
| 4 | 4 | 3 + 强 → 2 + 强 → 214 + 中 | 3+HP → 2+HP → 214+MP | 2340 | 2500 | drive 0 | 8.2 | high | 0/2 pairs reproduced |
| 5 | 5 | 3 + 强 → 2 + 强 → 214 + 强 | 3+HP → 2+HP → 214+HP | 2340 | 2500 | drive 0 | 8.2 | high | 0/2 pairs reproduced |
| 6 | 6 | 3 + 强 → 2 + 强 → 22 + 弱 | 3+HP → 2+HP → 22+LP | 2340 | 2500 | drive 0 | 7.3 | high | 0/2 pairs reproduced |
| 7 | 7 | 3 + 强 → 2 + 强 → 22 + 中 | 3+HP → 2+HP → 22+MP | 2340 | 2500 | drive 0 | 7.3 | high | 0/2 pairs reproduced |
| 8 | 8 | 3 + 强 → 2 + 强 → 22 + 强 | 3+HP → 2+HP → 22+HP | 2340 | 2500 | drive 0 | 7.3 | high | 0/2 pairs reproduced |
| 9 | 9 | 3 + 强 → 2 + 强 → 236 + 弱 | 3+HP → 2+HP → 236+LK | 2340 | 2500 | drive 0 | 8.2 | high | 0/2 pairs reproduced |
| 10 | 10 | 3 + 强 → 中 → 236 + 中 | 3+HP → MK → 236+MK | 2300 | 2500 | drive 0 | 7.7 | high | 0/2 pairs reproduced |
| 11 | 11 | 3 + 强 → 中 → 236 + 强 | 3+HP → MK → 236+HK | 2300 | 2500 | drive 0 | 7.7 | high | 0/2 pairs reproduced |
| 12 | 12 | 3 + 强 → 2 + 强 → 1 + SP | 3+HP → 2+HP → 22+LP | 2212 | 2500 | drive 0 | 8.0 | high | 0/2 pairs reproduced |
| 13 | 13 | 3 + 强 → 2 + 强 → SP | 3+HP → 2+HP → 22+MP | 2212 | 2500 | drive 0 | 7.5 | high | 0/2 pairs reproduced |
| 14 | 14 | 3 + 强 → 2 + 强 → 3 + SP | 3+HP → 2+HP → 22+HP | 2212 | 2500 | drive 0 | 8.0 | high | 0/2 pairs reproduced |
| 15 | 15 | 3 + 强 → 4 + 中 → 236 + 中 | 3+HP → 4+MP → 236+MK | 2200 | 2400 | drive 0 | 8.2 | high | 0/2 pairs reproduced |
| 16 | 16 | 3 + 强 → 4 + 中 → 236 + 强 | 3+HP → 4+MP → 236+HK | 2200 | 2400 | drive 0 | 8.2 | high | 0/2 pairs reproduced |
| 17 | 17 | 3 + 强 → 中 → 214 + 弱 | 3+HP → MK → 214+LP | 2140 | 2300 | drive 0 | 7.7 | high | 0/2 pairs reproduced |
| 18 | 18 | 3 + 强 → 中 → 214 + 中 | 3+HP → MK → 214+MP | 2140 | 2300 | drive 0 | 7.7 | high | 0/2 pairs reproduced |
| 19 | 19 | 3 + 强 → 中 → 214 + 强 | 3+HP → MK → 214+HP | 2140 | 2300 | drive 0 | 7.7 | high | 0/2 pairs reproduced |
| 20 | 20 | 3 + 强 → 中 → 22 + 弱 | 3+HP → MK → 22+LP | 2140 | 2300 | drive 0 | 6.8 | high | 0/2 pairs reproduced |

## Pairs to sweep: 23

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 611 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 3 + 强 → 2 + 强 | `640:manual->617:manual` | 1, 2, 3, 4, 5, 6, 7, 8, 9, 12, 13, 14 | untested | single | high | 8 |
| 2 | 2 + 强 → 236 + 中 | `617:manual->972:manual` | 1 | untested | single | high | -13 |
| 3 | 2 + 强 → 236 + 强 | `617:manual->973:manual` | 2 | untested | single | high | -13 |
| 4 | 2 + 强 → 214 + 弱 | `617:manual->915:manual` | 3 | untested | single | high | -49 |
| 5 | 2 + 强 → 214 + 中 | `617:manual->916:manual` | 4 | untested | single | high | -49 |
| 6 | 2 + 强 → 214 + 强 | `617:manual->917:manual` | 5 | untested | single | high | -49 |
| 7 | 2 + 强 → 22 + 弱 | `617:manual->956:manual` | 6 | untested | repeat | high | -21 |
| 8 | 2 + 强 → 22 + 中 | `617:manual->957:manual` | 7 | untested | repeat | high | -21 |
| 9 | 2 + 强 → 22 + 强 | `617:manual->958:manual` | 8 | untested | repeat | high | -21 |
| 10 | 2 + 强 → 236 + 弱 | `617:manual->971:manual` | 9 | untested | single | high | -13 |
| 11 | 3 + 强 → 中 | `640:manual->606:manual` | 10, 11, 17, 18, 19, 20 | untested | single | high | 9 |
| 12 | 中 → 236 + 中 | `606:manual->972:manual` | 10 | untested | single | high | -11 |
| 13 | 中 → 236 + 强 | `606:manual->973:manual` | 11 | untested | single | high | -11 |
| 14 | 2 + 强 → 1 + SP | `617:manual->956:simple` | 12 | untested | single | high | -21 |
| 15 | 2 + 强 → SP | `617:manual->957:simple` | 13 | untested | single | high | -21 |
| 16 | 2 + 强 → 3 + SP | `617:manual->958:simple` | 14 | untested | single | high | -21 |
| 17 | 3 + 强 → 4 + 中 | `640:manual->637:manual` | 15, 16 | untested | single | high | 9 |
| 18 | 4 + 中 → 236 + 中 | `637:manual->972:manual` | 15 | untested | single | high | -9 |
| 19 | 4 + 中 → 236 + 强 | `637:manual->973:manual` | 16 | untested | single | high | -9 |
| 20 | 中 → 214 + 弱 | `606:manual->915:manual` | 17 | untested | single | high | -47 |
| 21 | 中 → 214 + 中 | `606:manual->916:manual` | 18 | untested | single | high | -47 |
| 22 | 中 → 214 + 强 | `606:manual->917:manual` | 19 | untested | single | high | -47 |
| 23 | 中 → 22 + 弱 | `606:manual->956:manual` | 20 | untested | repeat | high | -19 |

**4 of these the sweep cannot press as written.**

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
reframework/data), then pick `plan: no-gauge` in the SWEEP panel's worklist list
(REFRESH if the panel was already open) and START SWEEP. It writes to the same
trial log as the full sweep, so pairs the full sweep already answered under the
same calibration and conditions are skipped, and the other way round.

## Written

- reframework/data/ComboExplorer_data/worklist/jp-modern-plan-no-gauge.json  (23 pairs, 13112 bytes)
- docs/ComboExplorer/plans/jp-modern-no-gauge.md
