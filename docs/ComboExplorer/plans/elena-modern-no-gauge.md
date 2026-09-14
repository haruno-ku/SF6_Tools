# Route plan - Elena / modern - no-gauge

Generated 2026-09-14T13:02:32Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

175 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 857 (search complete: false)
  - the beam dropped 13450 partial routes and 0 routes were not emitted, so a route
    satisfying these conditions may be missing

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| no_gauge | true | 857 | 344 | 513 | 175 |

- routes satisfying every condition: 513
- of those, through a pair the logs rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 3 + 强 → 中 → 623 + 弱 | 2+HK → MK → 623+LK | 2200 | 2400 | drive 0 | 7.7 | medium | 0/2 pairs verified |
| 2 | 2 | 3 + 强 → 2 + 强 → 623 + 弱 | 2+HK → 2+HP → 623+LK | 2100 | 2300 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 3 | 3 | 3 + 强 → 弱 → 623 + 弱 | 2+HK → LK → 623+LK | 2000 | 2200 | drive 0 | 7.7 | medium | 0/2 pairs verified |
| 4 | 4 | 3 + 强 → 2 + 弱 → 623 + 弱 | 2+HK → 2+LP → 623+LK | 2000 | 2200 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 5 | 5 | 3 + 强 → 2 + 弱 → 3 + 强 | 2+HK → 2+LP → 2+HK | 1920 | 2100 | drive 0 | 6.0 | medium | 0/2 pairs verified |
| 6 | 6 | 3 + 强 → 2 + 弱 → 4 + 强 | 2+HK → 2+LP → 4+HK | 1920 | 2100 | drive 0 | 6.0 | medium | 0/2 pairs verified |
| 7 | 7 | 3 + 强 → 2 + 弱 → 6 + 强 | 2+HK → 2+LP → 6+HP | 1920 | 2100 | drive 0 | 6.0 | medium | 0/2 pairs verified |
| 8 | 8 | 3 + 强 → 中 → 4 + SP | 2+HK → MK → 214+LP | 1912 | 2200 | drive 0 | 7.5 | medium | 0/2 pairs verified |
| 9 | 9 | 3 + 强 → 623 + 弱 | 2+HK → 623+LK | 1900 | 1900 | drive 0 | 6.2 | medium | 0/1 pairs verified |
| 10 | 10 | 3 + 强 → 中 → 623 + 中 | 2+HK → MK → 623+MK | 1880 | 2000 | drive 0 | 7.7 | medium | 0/2 pairs verified |
| 11 | 11 | 3 + 强 → 2 + 弱 → 强 | 2+HK → 2+LP → HP | 1840 | 2000 | drive 0 | 5.5 | medium | 0/2 pairs verified |
| 12 | 12 | 3 + 强 → 2 + 强 → 4 + SP | 2+HK → 2+HP → 214+LP | 1812 | 2100 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 13 | 13 | 3 + 强 → 中 → 623 + 强 | 2+HK → MK → 623+HK | 1800 | 1900 | drive 0 | 7.7 | medium | 0/2 pairs verified |
| 14 | 14 | 3 + 强 → 4 + 强 | 2+HK → 4+HK | 1800 | 1800 | drive 0 | 4.0 | medium | 0/1 pairs verified |
| 15 | 15 | 3 + 强 → 6 + 强 | 2+HK → 6+HP | 1800 | 1800 | drive 0 | 4.0 | medium | 0/1 pairs verified |
| 16 | 16 | 3 + 强 → 中 → 6 + SP | 2+HK → MK → 623+MK | 1784 | 2000 | drive 0 | 7.5 | medium | 0/2 pairs verified |
| 17 | 17 | 3 + 强 → 2 + 强 → 623 + 中 | 2+HK → 2+HP → 623+MK | 1780 | 1900 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 18 | 18 | 3 + 强 → 2 + 中 → 2 + 弱 | 2+HK → 2+MK → 2+LP | 1740 | 1800 | drive 0 | 6.0 | medium | 0/2 pairs verified |
| 19 | 19 | 2 + 弱 → 3 + 强 → 623 + 弱 | 2+LP → 2+HK → 623+LK | 1720 | 2200 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 20 | 20 | 3 + 强 → 中 → 236 + 弱 | 2+HK → MK → 236+LK | 1720 | 1800 | drive 0 | 7.7 | medium | 0/2 pairs verified |

## Pairs to sweep: 24

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 1093 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 3 + 强 → 中 | `640:manual->673:manual` | 1, 8, 10, 13, 16, 20 | untested | single | medium | 25 |
| 2 | 中 → 623 + 弱 | `673:manual->910:manual` | 1 | untested | single | high | 0 |
| 3 | 3 + 强 → 2 + 强 | `640:manual->627:manual` | 2, 12, 17 | untested | single | medium | 22 |
| 4 | 2 + 强 → 623 + 弱 | `627:manual->910:manual` | 2 | untested | single | high | 1 |
| 5 | 3 + 强 → 弱 | `640:manual->611:manual` | 3 | untested | single | medium | 26 |
| 6 | 弱 → 623 + 弱 | `611:manual->910:manual` | 3 | untested | single | high | -3 |
| 7 | 3 + 强 → 2 + 弱 | `640:manual->619:manual` | 4, 5, 6, 7, 11 | untested | single | medium | 27 |
| 8 | 2 + 弱 → 623 + 弱 | `619:manual->910:manual` | 4 | untested | single | high | 0 |
| 9 | 2 + 弱 → 3 + 强 | `619:manual->640:manual` | 5, 19 | untested | single | medium | -6 |
| 10 | 2 + 弱 → 4 + 强 | `619:manual->677:manual` | 6 | untested | single | medium | -9 |
| 11 | 2 + 弱 → 6 + 强 | `619:manual->680:manual` | 7 | untested | single | medium | -11 |
| 12 | 中 → 4 + SP | `673:manual->928:simple` | 8 | untested | single | high | -15 |
| 13 | 3 + 强 → 623 + 弱 | `640:manual->910:manual` | 9, 19 | untested | single | medium | 26 |
| 14 | 中 → 623 + 中 | `673:manual->911:manual` | 10 | untested | single | high | -1 |
| 15 | 2 + 弱 → 强 | `619:manual->607:manual` | 11 | untested | single | medium | -7 |
| 16 | 2 + 强 → 4 + SP | `627:manual->928:simple` | 12 | untested | single | high | -14 |
| 17 | 中 → 623 + 强 | `673:manual->912:manual` | 13 | untested | single | high | -2 |
| 18 | 3 + 强 → 4 + 强 | `640:manual->677:manual` | 14 | untested | single | medium | 17 |
| 19 | 3 + 强 → 6 + 强 | `640:manual->680:manual` | 15 | untested | single | medium | 15 |
| 20 | 中 → 6 + SP | `673:manual->911:simple` | 16 | untested | single | high | -1 |
| 21 | 2 + 强 → 623 + 中 | `627:manual->911:manual` | 17 | untested | single | high | 0 |
| 22 | 3 + 强 → 2 + 中 | `640:manual->635:manual` | 18 | untested | single | medium | 22 |
| 23 | 2 + 中 → 2 + 弱 | `635:manual->619:manual` | 18 | untested | single | medium | 0 |
| 24 | 中 → 236 + 弱 | `673:manual->900:manual` | 20 | untested | single | high | -8 |

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

- reframework/data/ComboExplorer_data/worklist/elena-modern-plan-no-gauge.json  (24 pairs, 13410 bytes)
- docs/ComboExplorer/plans/elena-modern-no-gauge.md
