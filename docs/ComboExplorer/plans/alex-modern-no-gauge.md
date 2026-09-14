# Route plan - Alex / modern - no-gauge

Generated 2026-09-14T13:02:45Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

5 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 919 (search complete: false)
  - the beam dropped 2652 partial routes and 0 routes were not emitted, so a route
    satisfying these conditions may be missing

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| no_gauge | true | 919 | 298 | 621 | 5 |

- routes satisfying every condition: 621
- of those, through a pair the logs rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 2 + 强 → 3 + 强 → 63214 + 弱 | 2+HK → 2+HK → 63214+LP | 4000 | 4500 | drive 0 | 10.0 | medium | 0/2 pairs verified |
| 2 | 2 | 2 + 强 → 3 + 强 → 63214 + 中 | 2+HK → 2+HK → 63214+MP | 4000 | 4500 | drive 0 | 10.0 | medium | 0/2 pairs verified |
| 3 | 3 | 2 + 强 → 3 + 强 → 63214 + 强 | 2+HK → 2+HK → 63214+HP | 4000 | 4500 | drive 0 | 10.0 | medium | 0/2 pairs verified |
| 4 | 4 | 3 + 强 → 2 + 强 → 63214 + 弱 | 2+HK → 2+HK → 63214+LP | 4000 | 4500 | drive 0 | 10.0 | medium | 0/2 pairs verified |
| 5 | 5 | 3 + 强 → 2 + 强 → 63214 + 中 | 2+HK → 2+HK → 63214+MP | 4000 | 4500 | drive 0 | 10.0 | medium | 0/2 pairs verified |
| 6 | 6 | 3 + 强 → 2 + 强 → 63214 + 强 | 2+HK → 2+HK → 63214+HP | 4000 | 4500 | drive 0 | 10.0 | medium | 0/2 pairs verified |
| 7 | 7 | 2 + 强 → 2 + 强 → 63214 + 弱 | 2+HK → 2+HP → 63214+LP | 3800 | 4300 | drive 0 | 10.0 | medium | 0/2 pairs verified |
| 8 | 8 | 2 + 强 → 2 + 强 → 63214 + 中 | 2+HK → 2+HP → 63214+MP | 3800 | 4300 | drive 0 | 10.0 | medium | 0/2 pairs verified |
| 9 | 9 | 2 + 强 → 2 + 强 → 63214 + 强 | 2+HK → 2+HP → 63214+HP | 3800 | 4300 | drive 0 | 10.0 | medium | 0/2 pairs verified |
| 10 | 10 | 2 + 强 → 中 → 63214 + 弱 | 2+HK → MP → 63214+LP | 3600 | 4100 | drive 0 | 9.5 | medium | 0/2 pairs verified |
| 11 | 11 | 2 + 强 → 中 → 63214 + 中 | 2+HK → MP → 63214+MP | 3600 | 4100 | drive 0 | 9.5 | medium | 0/2 pairs verified |
| 12 | 12 | 2 + 强 → 中 → 63214 + 强 | 2+HK → MP → 63214+HP | 3600 | 4100 | drive 0 | 9.5 | medium | 0/2 pairs verified |
| 13 | 13 | 2 + 强 → 2 + 中 → 63214 + 强 | 2+HK → 2+MK → 63214+HP | 3600 | 4100 | drive 0 | 10.0 | medium | 0/2 pairs verified |
| 14 | 14 | 2 + 强 → 3 + 强 → 4 + SP | 2+HK → 2+HK → 63214+LP | 3600 | 4500 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 15 | 15 | 2 + 强 → 4 + 中 → 63214 + 强 | 2+HK → 4+MK → 63214+HP | 3600 | 4100 | drive 0 | 10.0 | medium | 0/2 pairs verified |
| 16 | 16 | 3 + 强 → 中 → 63214 + 弱 | 2+HK → MP → 63214+LP | 3600 | 4100 | drive 0 | 9.5 | medium | 0/2 pairs verified |
| 17 | 17 | 3 + 强 → 中 → 63214 + 中 | 2+HK → MP → 63214+MP | 3600 | 4100 | drive 0 | 9.5 | medium | 0/2 pairs verified |
| 18 | 18 | 3 + 强 → 中 → 63214 + 强 | 2+HK → MP → 63214+HP | 3600 | 4100 | drive 0 | 9.5 | medium | 0/2 pairs verified |
| 19 | 19 | 3 + 强 → 2 + 强 → 4 + SP | 2+HK → 2+HK → 63214+LP | 3600 | 4500 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 20 | 20 | 3 + 强 → 2 + 中 → 63214 + 强 | 2+HK → 2+MK → 63214+HP | 3600 | 4100 | drive 0 | 10.0 | medium | 0/2 pairs verified |

## Pairs to sweep: 24

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 583 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 2 + 强 → 3 + 强 | `636:manual->640:manual` | 1, 2, 3, 14 | untested | single | medium | 19 |
| 2 | 3 + 强 → 63214 + 弱 | `640:manual->910:manual` | 1 | untested | single | medium | 20 |
| 3 | 3 + 强 → 63214 + 中 | `640:manual->911:manual` | 2 | untested | single | medium | 22 |
| 4 | 3 + 强 → 63214 + 强 | `640:manual->912:manual` | 3 | untested | single | medium | 24 |
| 5 | 3 + 强 → 2 + 强 | `640:manual->636:manual` | 4, 5, 6, 19 | untested | single | medium | 19 |
| 6 | 2 + 强 → 63214 + 弱 | `636:manual->910:manual` | 4 | untested | single | medium | 20 |
| 7 | 2 + 强 → 63214 + 中 | `636:manual->911:manual` | 5 | untested | single | medium | 22 |
| 8 | 2 + 强 → 63214 + 强 | `636:manual->912:manual` | 6 | untested | single | medium | 24 |
| 9 | 2 + 强 → 2 + 强 | `636:manual->628:manual` | 7, 8, 9 | untested | single | medium | 20 |
| 10 | 2 + 强 → 63214 + 弱 | `628:manual->910:manual` | 7 | untested | single | high | -12 |
| 11 | 2 + 强 → 63214 + 中 | `628:manual->911:manual` | 8 | untested | single | high | -10 |
| 12 | 2 + 强 → 63214 + 强 | `628:manual->912:manual` | 9 | untested | single | high | -8 |
| 13 | 2 + 强 → 中 | `636:manual->604:manual` | 10, 11, 12 | untested | single | medium | 22 |
| 14 | 中 → 63214 + 弱 | `604:manual->910:manual` | 10, 16 | untested | single | high | -5 |
| 15 | 中 → 63214 + 中 | `604:manual->911:manual` | 11, 17 | untested | single | high | -3 |
| 16 | 中 → 63214 + 强 | `604:manual->912:manual` | 12, 18 | untested | single | high | -1 |
| 17 | 2 + 强 → 2 + 中 | `636:manual->638:manual` | 13 | untested | single | medium | 21 |
| 18 | 2 + 中 → 63214 + 强 | `638:manual->912:manual` | 13, 20 | untested | single | medium | 0 |
| 19 | 3 + 强 → 4 + SP | `640:manual->910:simple` | 14 | untested | single | medium | 20 |
| 20 | 2 + 强 → 4 + 中 | `636:manual->671:manual` | 15 | untested | single | medium | 22 |
| 21 | 4 + 中 → 63214 + 强 | `671:manual->912:manual` | 15 | untested | single | medium | 0 |
| 22 | 3 + 强 → 中 | `640:manual->604:manual` | 16, 17, 18 | untested | single | medium | 22 |
| 23 | 2 + 强 → 4 + SP | `636:manual->910:simple` | 19 | untested | single | medium | 20 |
| 24 | 3 + 强 → 2 + 中 | `640:manual->638:manual` | 20 | untested | single | medium | 21 |

## Already known: 0

Nothing these routes need has been answered yet.

## Where the known statuses come from

- trial logs read: 0 (0 records for modern)
- pairs answered: 0 across 0 cohort(s) - verified 0, rejected 0, pending 0
- route runs (combos, not pairs): 0 rows
- combos confirmed in the logs: 0

A pair measured in several cohorts is `verified` if any cohort linked it, else
`rejected` if any answered no, else `pending`. `(mixed)` marks a pair one cohort
linked and another rejected.

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

- reframework/data/ComboExplorer_data/worklist/alex-modern-plan-no-gauge.json  (24 pairs, 13335 bytes)
- docs/ComboExplorer/plans/alex-modern-no-gauge.md
