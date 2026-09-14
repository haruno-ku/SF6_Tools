# Route plan - Ken / modern - no-gauge

Generated 2026-09-14T12:59:56Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

58 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 674 (search complete: true)

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| no_gauge | true | 674 | 295 | 379 | 58 |

- routes satisfying every condition: 379
- of those, through a pair the logs rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 3 + 强 → 2 + 强 → 623 + 弱 | 2+HK → 2+HP → 623+LP | 2580 | 2800 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 2 | 2 | 3 + 强 → 2 + 强 → 4 + SP | 2+HK → 2+HP → 623+HK | 2468 | 2900 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 3 | 3 | 3 + 强 → 2 + 强 → 623 + 强 | 2+HK → 2+HP → 623+HP | 2340 | 2500 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 4 | 4 | 3 + 强 → 2 + 中 → 623 + 弱 | 2+HK → 2+MK → 623+LP | 2280 | 2500 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 5 | 5 | 3 + 强 → 2 + 强 → 236 + 强 | 2+HK → 2+HP → 236+HK | 2260 | 2400 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 6 | 6 | 3 + 强 → 2 + 强 → 623 + 中 | 2+HK → 2+HP → 623+MP | 2260 | 2400 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 7 | 7 | 3 + 强 → 2 + 强 → 236 + 中 | 2+HK → 2+HP → 236+MK | 2180 | 2300 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 8 | 8 | 3 + 强 → 2 + 中 → 4 + SP | 2+HK → 2+MK → 623+HK | 2168 | 2600 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 9 | 9 | 3 + 强 → 2 + 强 → 6 + SP | 2+HK → 2+HP → 623+MP | 2148 | 2400 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 10 | 10 | 3 + 强 → 2 + 强 → 236 + 弱 | 2+HK → 2+HP → 236+LK | 2100 | 2200 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 11 | 11 | 3 + 强 → 2 + 强 → SP | 2+HK → 2+HP → 236+MP | 2084 | 2300 | drive 0 | 7.5 | medium | 0/2 pairs verified |
| 12 | 12 | 3 + 强 → 2 + 强 → 2 + SP | 2+HK → 2+HP → 236+MK | 2084 | 2300 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 13 | 13 | 3 + 强 → 弱 → 623 + 弱 | 2+HK → LP → 623+LP | 2080 | 2300 | drive 0 | 7.7 | medium | 0/2 pairs verified |
| 14 | 14 | 3 + 强 → 2 + 弱 → 623 + 弱 | 2+HK → 2+LP → 623+LP | 2080 | 2300 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 15 | 15 | 3 + 强 → 2 + 强 → 214 + 中 | 2+HK → 2+HP → 214+MK | 2060 | 2150 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 16 | 16 | 3 + 强 → 2 + 中 → 623 + 强 | 2+HK → 2+MK → 623+HP | 2040 | 2200 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 17 | 17 | 3 + 强 → 623 + 弱 | 2+HK → 623+LP | 2000 | 2000 | drive 0 | 6.2 | medium | 0/1 pairs verified |
| 18 | 18 | 3 + 强 → 弱 → 4 + SP | 2+HK → LP → 623+HK | 1968 | 2400 | drive 0 | 7.5 | medium | 0/2 pairs verified |
| 19 | 19 | 3 + 强 → 2 + 弱 → 4 + SP | 2+HK → 2+LP → 623+HK | 1968 | 2400 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 20 | 20 | 3 + 强 → 2 + 中 → 236 + 强 | 2+HK → 2+MK → 236+HK | 1960 | 2100 | drive 0 | 8.2 | medium | 0/2 pairs verified |

## Pairs to sweep: 24

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 365 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 3 + 强 → 2 + 强 | `637:manual->626:manual` | 1, 2, 3, 5, 6, 7, 9, 10, 11, 12, 15 | untested | single | medium | 32 |
| 2 | 2 + 强 → 623 + 弱 | `626:manual->955:manual` | 1 | untested | single | high | -2 |
| 3 | 2 + 强 → 4 + SP | `626:manual->982:simple` | 2 | untested | single | high | -25 |
| 4 | 2 + 强 → 623 + 强 | `626:manual->957:manual` | 3 | untested | single | high | -4 |
| 5 | 3 + 强 → 2 + 中 | `637:manual->634:manual` | 4, 8, 16, 20 | untested | single | medium | 33 |
| 6 | 2 + 中 → 623 + 弱 | `634:manual->955:manual` | 4 | untested | single | high | -7 |
| 7 | 2 + 强 → 236 + 强 | `626:manual->922:manual` | 5 | untested | single | high | -22 |
| 8 | 2 + 强 → 623 + 中 | `626:manual->956:manual` | 6 | untested | single | high | -3 |
| 9 | 2 + 强 → 236 + 中 | `626:manual->921:manual` | 7 | untested | single | high | -13 |
| 10 | 2 + 中 → 4 + SP | `634:manual->982:simple` | 8 | untested | single | high | -30 |
| 11 | 2 + 强 → 6 + SP | `626:manual->956:simple` | 9 | untested | single | high | -3 |
| 12 | 2 + 强 → 236 + 弱 | `626:manual->920:manual` | 10 | untested | single | high | -9 |
| 13 | 2 + 强 → SP | `626:manual->902:simple` | 11 | untested | single | high | -11 |
| 14 | 2 + 强 → 2 + SP | `626:manual->921:simple` | 12 | untested | single | high | -13 |
| 15 | 3 + 强 → 弱 | `637:manual->600:manual` | 13, 18 | untested | single | medium | 36 |
| 16 | 弱 → 623 + 弱 | `600:manual->955:manual` | 13 | untested | single | high | -1 |
| 17 | 3 + 强 → 2 + 弱 | `637:manual->619:manual` | 14, 19 | untested | single | medium | 36 |
| 18 | 2 + 弱 → 623 + 弱 | `619:manual->955:manual` | 14 | untested | single | high | 0 |
| 19 | 2 + 强 → 214 + 中 | `626:manual->1001:manual` | 15 | untested | single | high | -11 |
| 20 | 2 + 中 → 623 + 强 | `634:manual->957:manual` | 16 | untested | single | high | -9 |
| 21 | 3 + 强 → 623 + 弱 | `637:manual->955:manual` | 17 | untested | single | medium | 35 |
| 22 | 弱 → 4 + SP | `600:manual->982:simple` | 18 | untested | single | high | -24 |
| 23 | 2 + 弱 → 4 + SP | `619:manual->982:simple` | 19 | untested | single | high | -23 |
| 24 | 2 + 中 → 236 + 强 | `634:manual->922:manual` | 20 | untested | single | high | -27 |

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

- reframework/data/ComboExplorer_data/worklist/ken-modern-plan-no-gauge.json  (24 pairs, 13523 bytes)
- docs/ComboExplorer/plans/ken-modern-no-gauge.md
