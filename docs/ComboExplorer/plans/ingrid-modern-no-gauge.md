# Route plan - Ingrid / modern - no-gauge

Generated 2026-09-14T13:03:08Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

299 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 2502 (search complete: false)
  - the beam dropped 4159 partial routes and 0 routes were not emitted, so a route
    satisfying these conditions may be missing

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| no_gauge | true | 2502 | 1222 | 1280 | 265 |

- routes satisfying every condition: 1280
- of those, through a pair the logs rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 6 + 弱 + 中 + 强 → 2 + 弱 + 中 + 强 → 236 + 强 | 6+KKK → 2+KKK → 236+HK | 3140 | 3400 | drive 0 | 10.2 | medium | 0/2 pairs verified |
| 2 | 2 | 2 + 弱 + 中 + 强 → 6 + 弱 + 中 + 强 → 236 + 强 | 2+KKK → 6+KKK → 236+HK | 3140 | 3400 | drive 0 | 10.2 | medium | 0/2 pairs verified |
| 3 | 3 | 6 + 弱 + 中 + 强 → 2 + 弱 + 中 + 强 → 236 + 中 | 6+KKK → 2+KKK → 236+MK | 3060 | 3300 | drive 0 | 10.2 | medium | 0/2 pairs verified |
| 4 | 4 | 2 + 弱 + 中 + 强 → 6 + 弱 + 中 + 强 → 236 + 中 | 2+KKK → 6+KKK → 236+MK | 3060 | 3300 | drive 0 | 10.2 | medium | 0/2 pairs verified |
| 5 | 5 | 2 + 弱 + 中 + 强 → 3 + 强 → 236 + 强 | 2+KKK → 2+HK → 236+HK | 3040 | 3300 | drive 0 | 9.2 | medium | 0/2 pairs verified |
| 6 | 6 | 2 + 弱 + 中 + 强 → 6 + 强 → 236 + 强 | 2+KKK → 6+HP → 236+HK | 3040 | 3300 | drive 0 | 9.2 | medium | 0/2 pairs verified |
| 7 | 7 | 6 + 弱 + 中 + 强 → 2 + 弱 + 中 + 强 → 214 + 强 | 6+KKK → 2+KKK → 214+HP | 2980 | 3200 | drive 0 | 10.2 | low | 0/2 pairs verified |
| 8 | 8 | 2 + 弱 + 中 + 强 → 6 + 弱 + 中 + 强 → 2 + 弱 + 中 + 强 | 2+KKK → 6+KKK → 2+KKK | 2980 | 3200 | drive 0 | 9.0 | medium | 0/2 pairs verified |
| 9 | 9 | 2 + 弱 + 中 + 强 → 6 + 弱 + 中 + 强 → 214 + 强 | 2+KKK → 6+KKK → 214+HP | 2980 | 3200 | drive 0 | 10.2 | low | 0/2 pairs verified |
| 10 | 10 | 2 + 弱 + 中 + 强 → 3 + 强 → 236 + 中 | 2+KKK → 2+HK → 236+MK | 2960 | 3200 | drive 0 | 9.2 | medium | 0/2 pairs verified |
| 11 | 11 | 2 + 弱 + 中 + 强 → 6 + 强 → 236 + 中 | 2+KKK → 6+HP → 236+MK | 2960 | 3200 | drive 0 | 9.2 | medium | 0/2 pairs verified |
| 12 | 12 | 6 + 强 → 6 + 弱 + 中 + 强 → 236 + 强 | 6+HP → 6+KKK → 236+HK | 2940 | 3200 | drive 0 | 9.2 | medium | 0/2 pairs verified |
| 13 | 13 | 4 + 强 → 2 + 弱 + 中 + 强 → 236 + 强 | 4+HP → 2+KKK → 236+HK | 2940 | 3200 | drive 0 | 9.2 | medium | 0/2 pairs verified |
| 14 | 14 | 6 + 弱 + 中 + 强 → 3 + 强 → 236 + 强 | 6+KKK → 2+HK → 236+HK | 2940 | 3200 | drive 0 | 9.2 | medium | 0/2 pairs verified |
| 15 | 15 | 6 + 弱 + 中 + 强 → 6 + 强 → 236 + 强 | 6+KKK → 6+HP → 236+HK | 2940 | 3200 | drive 0 | 9.2 | medium | 0/2 pairs verified |
| 16 | 16 | 2 + 弱 + 中 + 强 → 2 + 强 → 236 + 强 | 2+KKK → 2+HP → 236+HK | 2940 | 3200 | drive 0 | 9.2 | medium | 0/2 pairs verified |
| 17 | 17 | 2 + 弱 + 中 + 强 → 4 + 强 → 236 + 强 | 2+KKK → 4+HP → 236+HK | 2940 | 3200 | drive 0 | 9.2 | medium | 0/2 pairs verified |
| 18 | 18 | 6 + 弱 + 中 + 强 → 2 + 弱 + 中 + 强 → 236 + 弱 | 6+KKK → 2+KKK → 236+LK | 2900 | 3100 | drive 0 | 10.2 | medium | 0/2 pairs verified |
| 19 | 19 | 6 + 弱 + 中 + 强 → 2 + 弱 + 中 + 强 → 6 + 弱 + 中 + 强 | 6+KKK → 2+KKK → 6+KKK | 2900 | 3100 | drive 0 | 9.0 | medium | 0/2 pairs verified |
| 20 | 20 | 2 + 弱 + 中 + 强 → 6 + 弱 + 中 + 强 → 236 + 弱 | 2+KKK → 6+KKK → 236+LK | 2900 | 3100 | drive 0 | 10.2 | medium | 0/2 pairs verified |

## Pairs to sweep: 24

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 719 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 6 + 弱 + 中 + 强 → 2 + 弱 + 中 + 强 | `963:manual->964:manual` | 1, 3, 7, 8, 18, 19 | untested | single | medium | 1 |
| 2 | 2 + 弱 + 中 + 强 → 236 + 强 | `964:manual->946:manual` | 1, 13 | untested | single | medium | 21 |
| 3 | 2 + 弱 + 中 + 强 → 6 + 弱 + 中 + 强 | `964:manual->963:manual` | 2, 4, 8, 9, 19, 20 | untested | single | medium | 12 |
| 4 | 6 + 弱 + 中 + 强 → 236 + 强 | `963:manual->946:manual` | 2, 12 | untested | single | medium | 17 |
| 5 | 2 + 弱 + 中 + 强 → 236 + 中 | `964:manual->945:manual` | 3 | untested | single | medium | 35 |
| 6 | 6 + 弱 + 中 + 强 → 236 + 中 | `963:manual->945:manual` | 4 | untested | single | medium | 31 |
| 7 | 2 + 弱 + 中 + 强 → 3 + 强 | `964:manual->643:manual` | 5, 10 | untested | single | medium | 38 |
| 8 | 3 + 强 → 236 + 强 | `643:manual->946:manual` | 5, 14 | untested | single | medium | 3 |
| 9 | 2 + 弱 + 中 + 强 → 6 + 强 | `964:manual->663:manual` | 6, 11 | untested | single | medium | 31 |
| 10 | 6 + 强 → 236 + 强 | `663:manual->946:manual` | 6, 15 | untested | single | medium | 11 |
| 11 | 2 + 弱 + 中 + 强 → 214 + 强 | `964:manual->990:manual` | 7 | untested | single | low | 30 |
| 12 | 6 + 弱 + 中 + 强 → 214 + 强 | `963:manual->990:manual` | 9 | untested | single | low | 26 |
| 13 | 3 + 强 → 236 + 中 | `643:manual->945:manual` | 10 | untested | single | medium | 17 |
| 14 | 6 + 强 → 236 + 中 | `663:manual->945:manual` | 11 | untested | single | medium | 25 |
| 15 | 6 + 强 → 6 + 弱 + 中 + 强 | `663:manual->963:manual` | 12 | untested | single | medium | 2 |
| 16 | 4 + 强 → 2 + 弱 + 中 + 强 | `674:manual->964:manual` | 13 | untested | single | medium | 2 |
| 17 | 6 + 弱 + 中 + 强 → 3 + 强 | `963:manual->643:manual` | 14 | untested | single | medium | 34 |
| 18 | 6 + 弱 + 中 + 强 → 6 + 强 | `963:manual->663:manual` | 15 | untested | single | medium | 27 |
| 19 | 2 + 弱 + 中 + 强 → 2 + 强 | `964:manual->631:manual` | 16 | untested | single | medium | 36 |
| 20 | 2 + 强 → 236 + 强 | `631:manual->946:manual` | 16 | untested | single | high | -26 |
| 21 | 2 + 弱 + 中 + 强 → 4 + 强 | `964:manual->674:manual` | 17 | untested | single | medium | 34 |
| 22 | 4 + 强 → 236 + 强 | `674:manual->946:manual` | 17 | untested | single | medium | 18 |
| 23 | 2 + 弱 + 中 + 强 → 236 + 弱 | `964:manual->944:manual` | 18 | untested | single | medium | 40 |
| 24 | 6 + 弱 + 中 + 强 → 236 + 弱 | `963:manual->944:manual` | 20 | untested | single | medium | 36 |

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

- reframework/data/ComboExplorer_data/worklist/ingrid-modern-plan-no-gauge.json  (24 pairs, 13417 bytes)
- docs/ComboExplorer/plans/ingrid-modern-no-gauge.md
