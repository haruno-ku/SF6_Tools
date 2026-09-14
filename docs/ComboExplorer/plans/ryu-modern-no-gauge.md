# Route plan - Ryu / modern - no-gauge

Generated 2026-09-14T12:58:54Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

12 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 1092 (search complete: false)
  - the beam dropped 334 partial routes and 0 routes were not emitted, so a route
    satisfying these conditions may be missing

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| no_gauge | true | 1092 | 339 | 753 | 12 |

- routes satisfying every condition: 753
- of those, through a pair the logs rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 3 + 强 → 强 → 623 + 强 | 2+HK → HP → 623+HP | 2820 | 3100 | drive 0 | 7.7 | medium | 0/2 pairs verified |
| 2 | 2 | 3 + 强 → 2 + 强 → 623 + 强 | 2+HK → 2+HP → 623+HP | 2820 | 3100 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 3 | 3 | 3 + 强 → 6 + 强 → 623 + 强 | 2+HK → 6+HK → 623+HP | 2820 | 3100 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 4 | 4 | 3 + 强 → 强 → 623 + 中 | 2+HK → HP → 623+MP | 2660 | 2900 | drive 0 | 7.7 | medium | 0/2 pairs verified |
| 5 | 5 | 3 + 强 → 2 + 强 → 623 + 中 | 2+HK → 2+HP → 623+MP | 2660 | 2900 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 6 | 6 | 3 + 强 → 6 + 强 → 623 + 中 | 2+HK → 6+HK → 623+MP | 2660 | 2900 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 7 | 7 | 3 + 强 → 中 → 623 + 强 | 2+HK → MP → 623+HP | 2620 | 2900 | drive 0 | 7.7 | medium | 0/2 pairs verified |
| 8 | 8 | 3 + 强 → 强 → 6 + SP | 2+HK → HP → 623+HP | 2596 | 3100 | drive 0 | 7.5 | medium | 0/2 pairs verified |
| 9 | 9 | 3 + 强 → 2 + 强 → 6 + SP | 2+HK → 2+HP → 623+HP | 2596 | 3100 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 10 | 10 | 3 + 强 → 6 + 强 → 6 + SP | 2+HK → 6+HK → 623+HP | 2596 | 3100 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 11 | 11 | 3 + 强 → 强 → 623 + 弱 | 2+HK → HP → 623+LP | 2580 | 2800 | drive 0 | 7.7 | medium | 0/2 pairs verified |
| 12 | 12 | 3 + 强 → 2 + 强 → 623 + 弱 | 2+HK → 2+HP → 623+LP | 2580 | 2800 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 13 | 13 | 3 + 强 → 6 + 强 → 623 + 弱 | 2+HK → 6+HK → 623+LP | 2580 | 2800 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 14 | 14 | 3 + 强 → 强 → 3 + SP | 2+HK → HP → 236+HK | 2532 | 3000 | drive 0 | 7.5 | medium | 0/2 pairs verified |
| 15 | 15 | 3 + 强 → 2 + 强 → 3 + SP | 2+HK → 2+HP → 236+HK | 2532 | 3000 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 16 | 16 | 3 + 强 → 6 + 强 → 3 + SP | 2+HK → 6+HK → 236+HK | 2532 | 3000 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 17 | 17 | 3 + 强 → 2 + 中 → 623 + 强 | 2+HK → 2+MK → 623+HP | 2520 | 2800 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 18 | 18 | 3 + 强 → 强 → 2 + SP | 2+HK → HP → 236+MK | 2468 | 2900 | drive 0 | 7.5 | medium | 0/2 pairs verified |
| 19 | 19 | 3 + 强 → 2 + 强 → 2 + SP | 2+HK → 2+HP → 236+MK | 2468 | 2900 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 20 | 20 | 3 + 强 → 6 + 强 → 2 + SP | 2+HK → 6+HK → 236+MK | 2468 | 2900 | drive 0 | 8.0 | medium | 0/2 pairs verified |

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

- reframework/data/ComboExplorer_data/worklist/ryu-modern-plan-no-gauge.json  (25 pairs, 14005 bytes)
- docs/ComboExplorer/plans/ryu-modern-no-gauge.md
