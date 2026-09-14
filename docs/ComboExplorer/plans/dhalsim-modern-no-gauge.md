# Route plan - Dhalsim / modern - no-gauge

Generated 2026-09-14T12:59:31Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

1162 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 2681 (search complete: false)
  - the beam dropped 1576 partial routes and 0 routes were not emitted, so a route
    satisfying these conditions may be missing

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| no_gauge | true | 2681 | 926 | 1755 | 1162 |

- routes satisfying every condition: 1755
- of those, through a pair the logs rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 3 + 强 → 4 + 强 → 2 + SP | 2+HK → 4+HP → 63214+MK | 2568 | 3000 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 2 | 2 | 3 + 强 → 4 + 强 → 3 + SP | 2+HK → 4+HP → 63214+HK | 2568 | 3000 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 3 | 3 | 3 + 强 → 1 + 强 → 2 + SP | 2+HK → 1+HP → 63214+MK | 2468 | 2900 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 4 | 4 | 3 + 强 → 1 + 强 → 3 + SP | 2+HK → 1+HP → 63214+HK | 2468 | 2900 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 5 | 5 | 3 + 强 → 4 + 强 → 1 + SP | 2+HK → 4+HP → 63214+LK | 2440 | 2800 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 6 | 6 | 3 + 强 → 4 + 强 → 63214 + 弱 | 2+HK → 4+HP → 63214+LP | 2440 | 2600 | drive 0 | 10.0 | medium | 0/2 pairs verified |
| 7 | 7 | 3 + 强 → 4 + 中 → 2 + SP | 2+HK → 4+MP → 63214+MK | 2368 | 2800 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 8 | 8 | 3 + 强 → 4 + 中 → 3 + SP | 2+HK → 4+MP → 63214+HK | 2368 | 2800 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 9 | 9 | 3 + 强 → 1 + 强 → 1 + SP | 2+HK → 1+HP → 63214+LK | 2340 | 2700 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 10 | 10 | 3 + 强 → 1 + 强 → 63214 + 弱 | 2+HK → 1+HP → 63214+LP | 2340 | 2500 | drive 0 | 10.0 | medium | 0/2 pairs verified |
| 11 | 11 | 3 + 强 → 4 + 强 → 4 + SP | 2+HK → 4+HP → 63214+LP | 2312 | 2600 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 12 | 12 | 3 + 强 → 4 + 强 → 236 + 弱 | 2+HK → 4+HP → 236+LP | 2280 | 2400 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 13 | 13 | 3 + 强 → 4 + 强 → 236 + 中 | 2+HK → 4+HP → 236+MP | 2280 | 2400 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 14 | 14 | 3 + 强 → 4 + 强 → 236 + 强 | 2+HK → 4+HP → 236+HP | 2280 | 2400 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 15 | 15 | 3 + 强 → 4 + 中 → 1 + SP | 2+HK → 4+MP → 63214+LK | 2240 | 2600 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 16 | 16 | 3 + 强 → 4 + 中 → 63214 + 弱 | 2+HK → 4+MP → 63214+LP | 2240 | 2400 | drive 0 | 10.0 | medium | 0/2 pairs verified |
| 17 | 17 | 3 + 强 → 1 + 强 → 4 + SP | 2+HK → 1+HP → 63214+LP | 2212 | 2500 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 18 | 18 | 3 + 强 → 4 + 强 → 6 + SP | 2+HK → 4+HP → 236+LP | 2184 | 2400 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 19 | 19 | 3 + 强 → 1 + 强 → 236 + 弱 | 2+HK → 1+HP → 236+LP | 2180 | 2300 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 20 | 20 | 3 + 强 → 1 + 强 → 236 + 中 | 2+HK → 1+HP → 236+MP | 2180 | 2300 | drive 0 | 8.2 | medium | 0/2 pairs verified |

## Pairs to sweep: 23

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 664 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 3 + 强 → 4 + 强 | `659:manual->656:manual` | 1, 2, 5, 6, 11, 12, 13, 14, 18 | untested | single | medium | 8 |
| 2 | 4 + 强 → 2 + SP | `656:manual->938:simple` | 1 | untested | single | high | -24 |
| 3 | 4 + 强 → 3 + SP | `656:manual->939:simple` | 2 | untested | single | high | -26 |
| 4 | 3 + 强 → 1 + 强 | `659:manual->654:manual` | 3, 4, 9, 10, 17, 19, 20 | untested | single | medium | 12 |
| 5 | 1 + 强 → 2 + SP | `654:manual->938:simple` | 3 | untested | single | high | -12 |
| 6 | 1 + 强 → 3 + SP | `654:manual->939:simple` | 4 | untested | single | high | -14 |
| 7 | 4 + 强 → 1 + SP | `656:manual->937:simple` | 5 | untested | single | high | -21 |
| 8 | 4 + 强 → 63214 + 弱 | `656:manual->966:manual` | 6 | untested | single | high | -25 |
| 9 | 3 + 强 → 4 + 中 | `659:manual->655:manual` | 7, 8, 15, 16 | untested | single | medium | 14 |
| 10 | 4 + 中 → 2 + SP | `655:manual->938:simple` | 7 | untested | single | high | -13 |
| 11 | 4 + 中 → 3 + SP | `655:manual->939:simple` | 8 | untested | single | high | -15 |
| 12 | 1 + 强 → 1 + SP | `654:manual->937:simple` | 9 | untested | single | high | -9 |
| 13 | 1 + 强 → 63214 + 弱 | `654:manual->966:manual` | 10 | untested | single | high | -13 |
| 14 | 4 + 强 → 4 + SP | `656:manual->966:simple` | 11 | untested | single | high | -25 |
| 15 | 4 + 强 → 236 + 弱 | `656:manual->900:manual` | 12 | untested | single | high | -24 |
| 16 | 4 + 强 → 236 + 中 | `656:manual->904:manual` | 13 | untested | single | high | -24 |
| 17 | 4 + 强 → 236 + 强 | `656:manual->908:manual` | 14 | untested | single | high | -24 |
| 18 | 4 + 中 → 1 + SP | `655:manual->937:simple` | 15 | untested | single | high | -10 |
| 19 | 4 + 中 → 63214 + 弱 | `655:manual->966:manual` | 16 | untested | single | high | -14 |
| 20 | 1 + 强 → 4 + SP | `654:manual->966:simple` | 17 | untested | single | high | -13 |
| 21 | 4 + 强 → 6 + SP | `656:manual->900:simple` | 18 | untested | single | high | -24 |
| 22 | 1 + 强 → 236 + 弱 | `654:manual->900:manual` | 19 | untested | single | high | -12 |
| 23 | 1 + 强 → 236 + 中 | `654:manual->904:manual` | 20 | untested | single | high | -12 |

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

- reframework/data/ComboExplorer_data/worklist/dhalsim-modern-plan-no-gauge.json  (23 pairs, 13171 bytes)
- docs/ComboExplorer/plans/dhalsim-modern-no-gauge.md
