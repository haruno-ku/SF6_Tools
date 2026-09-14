# Route plan - Guile / modern - no-gauge

Generated 2026-09-14T13:01:02Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

322 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 1178 (search complete: false)
  - the beam dropped 78139 partial routes and 0 routes were not emitted, so a route
    satisfying these conditions may be missing

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| no_gauge | true | 1178 | 259 | 919 | 322 |

- routes satisfying every condition: 919
- of those, through a pair the logs rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 3 + 强 → 2 + 强 → [2]8 + 强 | 2+HK → 2+HP → [2]8+HK | 2310 | 2550 | drive 0 | 7.3 | medium | 0/2 pairs verified |
| 2 | 2 | 3 + 强 → 2 + 强 → [2]8 + 中 | 2+HK → 2+HP → [2]8+MK | 2230 | 2450 | drive 0 | 7.3 | medium | 0/2 pairs verified |
| 3 | 3 | 3 + 强 → 4 + 强 → [2]8 + 强 | 2+HK → 4+HP → [2]8+HK | 2210 | 2450 | drive 0 | 7.3 | medium | 0/2 pairs verified |
| 4 | 4 | 3 + 强 → 2 + 强 → [2]8 + 弱 | 2+HK → 2+HP → [2]8+LK | 2150 | 2350 | drive 0 | 7.3 | medium | 0/2 pairs verified |
| 5 | 5 | 3 + 强 → 4 + 强 → [2]8 + 中 | 2+HK → 4+HP → [2]8+MK | 2130 | 2350 | drive 0 | 7.3 | medium | 0/2 pairs verified |
| 6 | 6 | 3 + 强 → 2 + 强 → [2] + AUTO + SP | 2+HK → 2+HP → [2]8+HK | 2118 | 2550 | drive 0 | 8.5 | medium | 0/2 pairs verified |
| 7 | 7 | 强 → [2]8 + 强 | HP → [2]8+HK | 2100 | 2100 | drive 0 | 4.8 | low | 0/1 pairs verified |
| 8 | 8 | 2 + 强 → [2]8 + 强 | 2+HP → [2]8+HK | 2100 | 2100 | drive 0 | 5.3 | high | 0/1 pairs verified |
| 9 | 9 | 强 → 2 + 弱 → [2]8 + 强 | HK → 2+LP → [2]8+HK | 2060 | 2300 | drive 0 | 6.8 | medium | 0/2 pairs verified |
| 10 | 10 | 6 + 强 → 弱 → [2]8 + 强 | 6+HP → LP → [2]8+HK | 2060 | 2300 | drive 0 | 6.8 | medium | 0/2 pairs verified |
| 11 | 11 | 6 + 强 → 2 + 弱 → [2]8 + 强 | 6+HP → 2+LP → [2]8+HK | 2060 | 2300 | drive 0 | 7.3 | medium | 0/2 pairs verified |
| 12 | 12 | 3 + 强 → 2 + 强 → [2] + SP | 2+HK → 2+HP → [2]8+MK | 2054 | 2450 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 13 | 13 | 3 + 强 → 2 + 强 → [2]8 + SP | 2+HK → 2+HP → [2]8+MK | 2054 | 2450 | drive 0 | 9.3 | medium | 0/2 pairs verified |
| 14 | 14 | 3 + 强 → 4 + 强 → [2]8 + 弱 | 2+HK → 4+HP → [2]8+LK | 2050 | 2250 | drive 0 | 7.3 | medium | 0/2 pairs verified |
| 15 | 15 | 3 + 强 → 6 + 强 → [2]8 + 弱 | 2+HK → 6+HP → [2]8+LK | 2050 | 2250 | drive 0 | 7.3 | medium | 0/2 pairs verified |
| 16 | 16 | 3 + 强 → 4 + 强 → [2] + AUTO + SP | 2+HK → 4+HP → [2]8+HK | 2018 | 2450 | drive 0 | 8.5 | medium | 0/2 pairs verified |
| 17 | 17 | 强 → [2]8 + 中 | HP → [2]8+MK | 2000 | 2000 | drive 0 | 4.8 | low | 0/1 pairs verified |
| 18 | 18 | 2 + 强 → [2]8 + 中 | 2+HP → [2]8+MK | 2000 | 2000 | drive 0 | 5.3 | high | 0/1 pairs verified |
| 19 | 19 | 4 + 强 → [2]8 + 强 | 4+HP → [2]8+HK | 2000 | 2000 | drive 0 | 5.3 | high | 0/1 pairs verified |
| 20 | 20 | 强 → 2 + 弱 → [2]8 + 中 | HK → 2+LP → [2]8+MK | 1980 | 2200 | drive 0 | 6.8 | medium | 0/2 pairs verified |

## Pairs to sweep: 22

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 2797 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 3 + 强 → 2 + 强 | `641:manual->629:manual` | 1, 2, 4, 6, 12, 13 | untested | single | medium | 25 |
| 2 | 2 + 强 → [2]8 + 强 | `629:manual->993:manual` | 1, 8 | untested | single | high | -7 |
| 3 | 2 + 强 → [2]8 + 中 | `629:manual->991:manual` | 2, 18 | untested | single | high | -6 |
| 4 | 3 + 强 → 4 + 强 | `641:manual->656:manual` | 3, 5, 14, 16 | untested | single | medium | 25 |
| 5 | 4 + 强 → [2]8 + 强 | `656:manual->993:manual` | 3, 19 | untested | single | high | -6 |
| 6 | 2 + 强 → [2]8 + 弱 | `629:manual->989:manual` | 4 | untested | single | high | -5 |
| 7 | 4 + 强 → [2]8 + 中 | `656:manual->991:manual` | 5 | untested | single | high | -5 |
| 8 | 2 + 强 → [2] + AUTO + SP | `629:manual->994:simple` | 6 | untested | single | high | -7 |
| 9 | 强 → [2]8 + 强 | `1217:manual->993:manual` | 7 | untested | single | low | -8 |
| 10 | 强 → 2 + 弱 | `618:manual->621:manual` | 9, 20 | untested | single | medium | 0 |
| 11 | 2 + 弱 → [2]8 + 强 | `621:manual->993:manual` | 9, 11 | untested | single | high | -2 |
| 12 | 6 + 强 → 弱 | `668:manual->600:manual` | 10 | untested | single | medium | 0 |
| 13 | 弱 → [2]8 + 强 | `600:manual->993:manual` | 10 | untested | single | high | -3 |
| 14 | 6 + 强 → 2 + 弱 | `668:manual->621:manual` | 11 | untested | single | medium | 1 |
| 15 | 2 + 强 → [2] + SP | `629:manual->991:simple` | 12 | untested | single | high | -6 |
| 16 | 2 + 强 → [2]8 + SP | `629:manual->992:simple` | 13 | untested | single | high | -6 |
| 17 | 4 + 强 → [2]8 + 弱 | `656:manual->989:manual` | 14 | untested | single | high | -4 |
| 18 | 3 + 强 → 6 + 强 | `641:manual->668:manual` | 15 | untested | single | medium | 18 |
| 19 | 6 + 强 → [2]8 + 弱 | `668:manual->989:manual` | 15 | untested | single | medium | 0 |
| 20 | 4 + 强 → [2] + AUTO + SP | `656:manual->994:simple` | 16 | untested | single | high | -6 |
| 21 | 强 → [2]8 + 中 | `1217:manual->991:manual` | 17 | untested | single | low | -7 |
| 22 | 2 + 弱 → [2]8 + 中 | `621:manual->991:manual` | 20 | untested | single | high | -1 |

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

- reframework/data/ComboExplorer_data/worklist/guile-modern-plan-no-gauge.json  (22 pairs, 12667 bytes)
- docs/ComboExplorer/plans/guile-modern-no-gauge.md
