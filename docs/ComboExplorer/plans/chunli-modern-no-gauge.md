# Route plan - ChunLi / modern - no-gauge

Generated 2026-09-14T12:58:55Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 1157 (search complete: false)
  - the beam dropped 1991 partial routes and 0 routes were not emitted, so a route
    satisfying these conditions may be missing

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| no_gauge | true | 1157 | 294 | 863 | 0 |

- routes satisfying every condition: 863
- of those, through a pair the logs rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 3 + 强 → 4 + 强 → 3 + SP | 2+HK → 4+HP → 214+HK | 2468 | 2900 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 2 | 2 | 3 + 强 → 4 + 强 → 2 + SP | 2+HK → 4+HP → 214+MK | 2340 | 2700 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 3 | 3 | 3 + 强 → 中 → 3 + SP | 2+HK → MP → 214+HK | 2268 | 2700 | drive 0 | 7.5 | medium | 0/2 pairs verified |
| 4 | 4 | 3 + 强 → 6 或 4 + 中 → 3 + SP | 2+HK → 6+MP → 214+HK | 2268 | 2700 | drive 0 | 9.3 | medium | 0/2 pairs verified |
| 5 | 5 | 3 + 强 → 4 + 强 → 中 | 2+HK → 4+HP → MP | 2180 | 2300 | drive 0 | 5.5 | medium | 0/2 pairs verified |
| 6 | 6 | 3 + 强 → 4 + 强 → [4]6 + 弱 | 2+HK → 4+HP → [4]6+LP | 2180 | 2300 | drive 0 | 7.3 | medium | 0/2 pairs verified |
| 7 | 7 | 3 + 强 → 4 + 强 → [4]6 + 中 | 2+HK → 4+HP → [4]6+MP | 2180 | 2300 | drive 0 | 7.3 | medium | 0/2 pairs verified |
| 8 | 8 | 3 + 强 → 4 + 强 → [4]6 + 强 | 2+HK → 4+HP → [4]6+HP | 2180 | 2300 | drive 0 | 7.3 | medium | 0/2 pairs verified |
| 9 | 9 | 3 + 强 → 2 + 中 → 3 + SP | 2+HK → 2+MK → 214+HK | 2168 | 2600 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 10 | 10 | 4 + 强 → 中 → 3 + SP | 4+HP → MP → 214+HK | 2168 | 2600 | drive 0 | 7.5 | medium | 0/2 pairs verified |
| 11 | 11 | 3 + 强 → 4 + 强 → 1 + SP | 2+HK → 4+HP → 214+LK | 2148 | 2400 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 12 | 12 | 3 + 强 → 中 → 2 + SP | 2+HK → MP → 214+MK | 2140 | 2500 | drive 0 | 7.5 | medium | 0/2 pairs verified |
| 13 | 13 | 3 + 强 → 6 或 4 + 中 → 2 + SP | 2+HK → 6+MP → 214+MK | 2140 | 2500 | drive 0 | 9.3 | medium | 0/2 pairs verified |
| 14 | 14 | 3 + 强 → 2 + 强 → 3 + SP | 2+HK → 2+HP → 214+HK | 2118 | 2550 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 15 | 15 | 3 + 强 → 4 + 强 → [4] + SP | 2+HK → 4+HP → [4]6+HP | 2084 | 2300 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 16 | 16 | 3 + 强 → 4 + 强 → 22 + 弱 | 2+HK → 4+HP → 22+LK | 2060 | 2150 | drive 0 | 7.3 | medium | 0/2 pairs verified |
| 17 | 17 | 3 + 强 → 4 + 强 → 22 + 中 | 2+HK → 4+HP → 22+MK | 2060 | 2150 | drive 0 | 7.3 | medium | 0/2 pairs verified |
| 18 | 18 | 3 + 强 → 2 + 中 → 2 + SP | 2+HK → 2+MK → 214+MK | 2040 | 2400 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 19 | 19 | 3 + 强 → 2 + 强 → 弱 | 2+HK → HK → LP | 2040 | 2100 | drive 0 | 5.5 | medium | 0/2 pairs verified |
| 20 | 20 | 3 + 强 → 2 + 强 → 2 + 弱 | 2+HK → HK → 2+LP | 2040 | 2100 | drive 0 | 6.0 | medium | 0/2 pairs verified |

## Pairs to sweep: 25

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 619 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 3 + 强 → 4 + 强 | `614:manual->626:manual` | 1, 2, 5, 6, 7, 8, 11, 15, 16, 17 | untested | single | medium | 32 |
| 2 | 4 + 强 → 3 + SP | `626:manual->937:simple` | 1 | untested | single | high | -27 |
| 3 | 4 + 强 → 2 + SP | `626:manual->936:simple` | 2 | untested | single | high | -22 |
| 4 | 3 + 强 → 中 | `614:manual->601:manual` | 3, 12 | untested | single | medium | 35 |
| 5 | 中 → 3 + SP | `601:manual->937:simple` | 3, 10 | untested | single | high | -26 |
| 6 | 3 + 强 → 6 或 4 + 中 | `614:manual->625:manual` | 4, 13 | untested | single | medium | 33 |
| 7 | 6 或 4 + 中 → 3 + SP | `625:manual->937:simple` | 4 | untested | single | high | -30 |
| 8 | 4 + 强 → 中 | `626:manual->601:manual` | 5, 10 | untested | single | medium | 0 |
| 9 | 4 + 强 → [4]6 + 弱 | `626:manual->900:manual` | 6 | untested | single | high | -10 |
| 10 | 4 + 强 → [4]6 + 中 | `626:manual->901:manual` | 7 | untested | single | high | -7 |
| 11 | 4 + 强 → [4]6 + 强 | `626:manual->902:manual` | 8 | untested | single | high | -6 |
| 12 | 3 + 强 → 2 + 中 | `614:manual->613:manual` | 9, 18 | untested | single | medium | 33 |
| 13 | 2 + 中 → 3 + SP | `613:manual->937:simple` | 9 | untested | single | high | -34 |
| 14 | 4 + 强 → 1 + SP | `626:manual->935:simple` | 11 | untested | single | high | -18 |
| 15 | 中 → 2 + SP | `601:manual->936:simple` | 12 | untested | single | high | -21 |
| 16 | 6 或 4 + 中 → 2 + SP | `625:manual->936:simple` | 13 | untested | single | high | -25 |
| 17 | 3 + 强 → 2 + 强 | `614:manual->610:manual` | 14 | untested | single | medium | 29 |
| 18 | 2 + 强 → 3 + SP | `610:manual->937:simple` | 14 | untested | single | high | -31 |
| 19 | 4 + 强 → [4] + SP | `626:manual->902:simple` | 15 | untested | single | high | -6 |
| 20 | 4 + 强 → 22 + 弱 | `626:manual->951:manual` | 16 | untested | repeat | high | 0 |
| 21 | 4 + 强 → 22 + 中 | `626:manual->952:manual` | 17 | untested | repeat | high | -2 |
| 22 | 2 + 中 → 2 + SP | `613:manual->936:simple` | 18 | untested | single | high | -29 |
| 23 | 3 + 强 → 2 + 强 | `614:manual->669:manual` | 19, 20 | untested | single | medium | 26 |
| 24 | 2 + 强 → 弱 | `669:manual->600:manual` | 19 | untested | single | medium | 0 |
| 25 | 2 + 强 → 2 + 弱 | `669:manual->637:manual` | 20 | untested | single | medium | 0 |

**2 of these the sweep cannot press as written.**

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

- reframework/data/ComboExplorer_data/worklist/chunli-modern-plan-no-gauge.json  (25 pairs, 14008 bytes)
- docs/ComboExplorer/plans/chunli-modern-no-gauge.md
