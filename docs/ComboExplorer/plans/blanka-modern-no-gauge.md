# Route plan - Blanka / modern - no-gauge

Generated 2026-09-14T13:00:34Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

957 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 2182 (search complete: false)
  - the beam dropped 1597 partial routes and 0 routes were not emitted, so a route
    satisfying these conditions may be missing

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| no_gauge | true | 2182 | 615 | 1567 | 957 |

- routes satisfying every condition: 1567
- of those, through a pair the logs rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 6 + 强 → 3 + 强 → [2]8 + 强 | 6+HP → 3+HP → [2]8+HK | 3220 | 3500 | drive 0 | 7.3 | low | 0/2 pairs verified |
| 2 | 2 | 3 + 强 → 6 + 强 → [2]8 + 强 | 3+HP → 6+HP → [2]8+HK | 3220 | 3500 | drive 0 | 7.3 | low | 0/2 pairs verified |
| 3 | 3 | 6 + 强 → 中 → 236 + 强 | 6+HP → MK → 236+HK | 3140 | 3500 | drive 0 | 7.7 | medium | 0/2 pairs verified |
| 4 | 4 | 6 + 强 → 4 + 中 → 236 + 强 | 6+HP → 4+MK → 236+HK | 3140 | 3500 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 5 | 5 | 6 + 强 → 3 + 强 → [4]6 + 强 | 6+HP → 3+HP → [4]6+HP | 3140 | 3400 | drive 0 | 7.3 | low | 0/2 pairs verified |
| 6 | 6 | 6 + 强 → 3 + 强 → [2]8 + 中 | 6+HP → 3+HP → [2]8+MK | 3140 | 3400 | drive 0 | 7.3 | low | 0/2 pairs verified |
| 7 | 7 | 3 + 强 → 6 + 强 → [4]6 + 强 | 3+HP → 6+HP → [4]6+HP | 3140 | 3400 | drive 0 | 7.3 | low | 0/2 pairs verified |
| 8 | 8 | 3 + 强 → 6 + 强 → [2]8 + 中 | 3+HP → 6+HP → [2]8+MK | 3140 | 3400 | drive 0 | 7.3 | low | 0/2 pairs verified |
| 9 | 9 | 6 + 强 → 中 → 236 + 中 | 6+HP → MK → 236+MK | 3060 | 3400 | drive 0 | 7.7 | medium | 0/2 pairs verified |
| 10 | 10 | 6 + 强 → 4 + 中 → 236 + 中 | 6+HP → 4+MK → 236+MK | 3060 | 3400 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 11 | 11 | 6 + 强 → 3 + 强 → [4]6 + 中 | 6+HP → 3+HP → [4]6+MP | 3060 | 3300 | drive 0 | 7.3 | low | 0/2 pairs verified |
| 12 | 12 | 6 + 强 → 3 + 强 → [2]8 + 弱 | 6+HP → 3+HP → [2]8+LK | 3060 | 3300 | drive 0 | 7.3 | low | 0/2 pairs verified |
| 13 | 13 | 3 + 强 → 6 + 强 → [4]6 + 中 | 3+HP → 6+HP → [4]6+MP | 3060 | 3300 | drive 0 | 7.3 | low | 0/2 pairs verified |
| 14 | 14 | 3 + 强 → 6 + 强 → [2]8 + 弱 | 3+HP → 6+HP → [2]8+LK | 3060 | 3300 | drive 0 | 7.3 | low | 0/2 pairs verified |
| 15 | 15 | 6 + 强 → 2 + 中 → 236 + 强 | 6+HP → 2+MK → 236+HK | 3040 | 3400 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 16 | 16 | 3 + 强 → 中 → 236 + 强 | 3+HP → MK → 236+HK | 3040 | 3400 | drive 0 | 7.7 | medium | 0/2 pairs verified |
| 17 | 17 | 3 + 强 → 4 + 中 → 236 + 强 | 3+HP → 4+MK → 236+HK | 3040 | 3400 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 18 | 18 | 6 + 强 → 中 → 236 + 弱 | 6+HP → MK → 236+LK | 2980 | 3300 | drive 0 | 7.7 | medium | 0/2 pairs verified |
| 19 | 19 | 6 + 强 → 4 + 中 → 236 + 弱 | 6+HP → 4+MK → 236+LK | 2980 | 3300 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 20 | 20 | 6 + 强 → 3 + 强 → 6 + 强 | 6+HP → 3+HP → 6+HP | 2980 | 3200 | drive 0 | 6.0 | medium | 0/2 pairs verified |

## Pairs to sweep: 24

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 565 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 6 + 强 → 3 + 强 | `644:manual->646:manual` | 1, 5, 6, 11, 12, 20 | untested | single | medium | 13 |
| 2 | 3 + 强 → [2]8 + 强 | `646:manual->984:manual` | 1 | untested | single | low | 21 |
| 3 | 3 + 强 → 6 + 强 | `646:manual->644:manual` | 2, 7, 8, 13, 14, 20 | untested | single | medium | 11 |
| 4 | 6 + 强 → [2]8 + 强 | `644:manual->984:manual` | 2 | untested | single | low | 19 |
| 5 | 6 + 强 → 中 | `644:manual->609:manual` | 3, 9, 18 | untested | single | medium | 19 |
| 6 | 中 → 236 + 强 | `609:manual->1023:manual` | 3, 16 | untested | single | high | -38 |
| 7 | 6 + 强 → 4 + 中 | `644:manual->642:manual` | 4, 10, 19 | untested | single | medium | 18 |
| 8 | 4 + 中 → 236 + 强 | `642:manual->1023:manual` | 4, 17 | untested | single | high | -35 |
| 9 | 3 + 强 → [4]6 + 强 | `646:manual->873:manual` | 5 | untested | single | low | 7 |
| 10 | 3 + 强 → [2]8 + 中 | `646:manual->975:manual` | 6 | untested | single | low | 21 |
| 11 | 6 + 强 → [4]6 + 强 | `644:manual->873:manual` | 7 | untested | single | low | 5 |
| 12 | 6 + 强 → [2]8 + 中 | `644:manual->975:manual` | 8 | untested | single | low | 19 |
| 13 | 中 → 236 + 中 | `609:manual->1018:manual` | 9 | untested | single | high | -34 |
| 14 | 4 + 中 → 236 + 中 | `642:manual->1018:manual` | 10 | untested | single | high | -31 |
| 15 | 3 + 强 → [4]6 + 中 | `646:manual->867:manual` | 11 | untested | single | low | 17 |
| 16 | 3 + 强 → [2]8 + 弱 | `646:manual->971:manual` | 12 | untested | single | low | 21 |
| 17 | 6 + 强 → [4]6 + 中 | `644:manual->867:manual` | 13 | untested | single | low | 15 |
| 18 | 6 + 强 → [2]8 + 弱 | `644:manual->971:manual` | 14 | untested | single | low | 19 |
| 19 | 6 + 强 → 2 + 中 | `644:manual->625:manual` | 15 | untested | single | medium | 19 |
| 20 | 2 + 中 → 236 + 强 | `625:manual->1023:manual` | 15 | untested | single | high | -38 |
| 21 | 3 + 强 → 中 | `646:manual->609:manual` | 16 | untested | single | medium | 21 |
| 22 | 3 + 强 → 4 + 中 | `646:manual->642:manual` | 17 | untested | single | medium | 20 |
| 23 | 中 → 236 + 弱 | `609:manual->1012:manual` | 18 | untested | single | high | -29 |
| 24 | 4 + 中 → 236 + 弱 | `642:manual->1012:manual` | 19 | untested | single | high | -26 |

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

- reframework/data/ComboExplorer_data/worklist/blanka-modern-plan-no-gauge.json  (24 pairs, 13303 bytes)
- docs/ComboExplorer/plans/blanka-modern-no-gauge.md
