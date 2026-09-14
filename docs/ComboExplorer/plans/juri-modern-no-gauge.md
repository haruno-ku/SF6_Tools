# Route plan - Juri / modern - no-gauge

Generated 2026-09-14T13:00:28Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

71 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 775 (search complete: false)
  - the beam dropped 15401 partial routes and 0 routes were not emitted, so a route
    satisfying these conditions may be missing

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| no_gauge | true | 775 | 323 | 452 | 71 |

- routes satisfying every condition: 452
- of those, through a pair the logs rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 3 + 强 → 3 + 强 → 强 | 2+HK → 2+HK → HK | 2520 | 2700 | drive 0 | 5.5 | medium | 0/2 pairs verified |
| 2 | 2 | 3 + 强 → 3 + 强 → 2 + 强 | 2+HK → 2+HK → 2+HP | 2520 | 2700 | drive 0 | 6.0 | medium | 0/2 pairs verified |
| 3 | 3 | 3 + 强 → 3 + 强 → 3 + 强 | 2+HK → 2+HK → 2+HK | 2520 | 2700 | drive 0 | 6.0 | medium | 0/2 pairs verified |
| 4 | 4 | 3 + 强 → 2 + 强 → 214 + 弱 | 2+HK → 2+HP → 214+LK | 2280 | 2400 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 5 | 5 | 3 + 强 → 2 + 强 → 214 + 中 | 2+HK → 2+HP → 214+MK | 2280 | 2400 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 6 | 6 | 3 + 强 → 2 + 强 → 236 + 中 | 2+HK → 2+HP → 236+MK | 2280 | 2400 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 7 | 7 | 3 + 强 → 3 + 强 → 中 | 2+HK → 2+HK → MP | 2280 | 2400 | drive 0 | 5.5 | medium | 0/2 pairs verified |
| 8 | 8 | 3 + 强 → 3 + 强 → 6 + 中 | 2+HK → 2+HK → 6+MK | 2280 | 2400 | drive 0 | 6.0 | medium | 0/2 pairs verified |
| 9 | 9 | 3 + 强 → 3 + 强 → 214 + 弱 | 2+HK → 2+HK → 214+LK | 2280 | 2400 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 10 | 10 | 3 + 强 → 3 + 强 → 214 + 中 | 2+HK → 2+HK → 214+MK | 2280 | 2400 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 11 | 11 | 3 + 强 → 3 + 强 → 236 + 中 | 2+HK → 2+HK → 236+MK | 2280 | 2400 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 12 | 12 | 3 + 强 → 2 + 强 → 214 + 强 | 2+HK → 2+HP → 214+HK | 2200 | 2300 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 13 | 13 | 3 + 强 → 3 + 强 → 2 + 中 | 2+HK → 2+HK → 2+MK | 2200 | 2300 | drive 0 | 6.0 | medium | 0/2 pairs verified |
| 14 | 14 | 3 + 强 → 3 + 强 → 6 + 强 | 2+HK → 2+HK → 6+HP | 2200 | 2300 | drive 0 | 6.0 | medium | 0/2 pairs verified |
| 15 | 15 | 3 + 强 → 3 + 强 → 214 + 强 | 2+HK → 2+HK → 214+HK | 2200 | 2300 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 16 | 16 | 3 + 强 → 2 + 强 → 4 + SP | 2+HK → 2+HP → 214+MK | 2184 | 2400 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 17 | 17 | 3 + 强 → 2 + 强 → 2 + SP | 2+HK → 2+HP → 236+MK | 2184 | 2400 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 18 | 18 | 3 + 强 → 3 + 强 → 4 + SP | 2+HK → 2+HK → 214+MK | 2184 | 2400 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 19 | 19 | 3 + 强 → 3 + 强 → 2 + SP | 2+HK → 2+HK → 236+MK | 2184 | 2400 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 20 | 20 | 3 + 强 → 2 + 强 → 236 + 弱 | 2+HK → 2+HP → 236+LK | 2120 | 2200 | drive 0 | 8.2 | medium | 0/2 pairs verified |

## Pairs to sweep: 22

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 2388 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 3 + 强 → 3 + 强 | `637:manual->638:manual` | 1, 2, 3, 7, 8, 9, 10, 11, 13, 14, 15, 18, 19 | untested | single | medium | 28 |
| 2 | 3 + 强 → 强 | `638:manual->615:manual` | 1 | untested | single | medium | 21 |
| 3 | 3 + 强 → 2 + 强 | `638:manual->626:manual` | 2 | untested | single | medium | 30 |
| 4 | 3 + 强 → 3 + 强 | `638:manual->637:manual` | 3 | untested | single | medium | 28 |
| 5 | 3 + 强 → 2 + 强 | `637:manual->626:manual` | 4, 5, 6, 12, 16, 17, 20 | untested | single | medium | 30 |
| 6 | 2 + 强 → 214 + 弱 | `626:manual->900:manual` | 4 | untested | single | high | -7 |
| 7 | 2 + 强 → 214 + 中 | `626:manual->904:manual` | 5 | untested | single | high | -10 |
| 8 | 2 + 强 → 236 + 中 | `626:manual->931:manual` | 6 | untested | single | high | -21 |
| 9 | 3 + 强 → 中 | `638:manual->603:manual` | 7 | untested | single | medium | 32 |
| 10 | 3 + 强 → 6 + 中 | `638:manual->670:manual` | 8 | untested | single | medium | 17 |
| 11 | 3 + 强 → 214 + 弱 | `638:manual->900:manual` | 9 | untested | single | medium | 28 |
| 12 | 3 + 强 → 214 + 中 | `638:manual->904:manual` | 10 | untested | single | medium | 25 |
| 13 | 3 + 强 → 236 + 中 | `638:manual->931:manual` | 11 | untested | single | medium | 14 |
| 14 | 2 + 强 → 214 + 强 | `626:manual->907:manual` | 12 | untested | single | high | -22 |
| 15 | 3 + 强 → 2 + 中 | `638:manual->634:manual` | 13 | untested | single | medium | 30 |
| 16 | 3 + 强 → 6 + 强 | `638:manual->674:manual` | 14 | untested | single | medium | 23 |
| 17 | 3 + 强 → 214 + 强 | `638:manual->907:manual` | 15 | untested | single | medium | 13 |
| 18 | 2 + 强 → 4 + SP | `626:manual->904:simple` | 16 | untested | single | high | -10 |
| 19 | 2 + 强 → 2 + SP | `626:manual->931:simple` | 17 | untested | single | high | -21 |
| 20 | 3 + 强 → 4 + SP | `638:manual->904:simple` | 18 | untested | single | medium | 25 |
| 21 | 3 + 强 → 2 + SP | `638:manual->931:simple` | 19 | untested | single | medium | 14 |
| 22 | 2 + 强 → 236 + 弱 | `626:manual->921:manual` | 20 | untested | single | high | -13 |

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

- reframework/data/ComboExplorer_data/worklist/juri-modern-plan-no-gauge.json  (22 pairs, 12389 bytes)
- docs/ComboExplorer/plans/juri-modern-no-gauge.md
