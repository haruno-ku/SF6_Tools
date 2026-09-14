# Route plan - Terry / modern - no-gauge

Generated 2026-09-14T13:02:13Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

16 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 699 (search complete: true)

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| no_gauge | true | 699 | 253 | 446 | 16 |

- routes satisfying every condition: 446
- of those, through a pair the logs rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 3 + 强 → 2 + 强 → 214 + 强 | 2+HK → 2+HP → 214+HP | 2660 | 2900 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 2 | 2 | 3 + 强 → 中 → 214 + 强 | 2+HK → MP → 214+HP | 2560 | 2800 | drive 0 | 7.7 | medium | 0/2 pairs verified |
| 3 | 3 | 3 + 强 → 2 + 强 → 214 + 中 | 2+HK → 2+HP → 214+MP | 2500 | 2700 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 4 | 4 | 3 + 强 → 2 + 强 → 623 + 弱 | 2+HK → 2+HP → 623+LP | 2500 | 2700 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 5 | 5 | 3 + 强 → 2 + 强 → 236 + 强 | 2+HK → 2+HP → 236+HP | 2420 | 2600 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 6 | 6 | 3 + 强 → 中 → 214 + 中 | 2+HK → MP → 214+MP | 2400 | 2600 | drive 0 | 7.7 | medium | 0/2 pairs verified |
| 7 | 7 | 3 + 强 → 中 → 623 + 弱 | 2+HK → MP → 623+LP | 2400 | 2600 | drive 0 | 7.7 | medium | 0/2 pairs verified |
| 8 | 8 | 3 + 强 → 2 + 中 → 214 + 强 | 2+HK → 2+MK → 214+HP | 2360 | 2600 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 9 | 9 | 3 + 强 → 2 + 强 → 6 + SP | 2+HK → 2+HP → 623+LP | 2340 | 2700 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 10 | 10 | 3 + 强 → 中 → 236 + 强 | 2+HK → MP → 236+HP | 2320 | 2500 | drive 0 | 7.7 | medium | 0/2 pairs verified |
| 11 | 11 | 3 + 强 → 2 + 强 → 236 + 中 | 2+HK → 2+HP → 236+MP | 2260 | 2400 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 12 | 12 | 3 + 强 → 2 + 强 → 623 + 强 | 2+HK → 2+HP → 623+HP | 2260 | 2400 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 13 | 13 | 3 + 强 → 中 → 6 + SP | 2+HK → MP → 623+LP | 2240 | 2600 | drive 0 | 7.5 | medium | 0/2 pairs verified |
| 14 | 14 | 3 + 强 → 2 + 强 → 2 + SP | 2+HK → 2+HP → 236+MK | 2212 | 2500 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 15 | 15 | 3 + 强 → 2 + 强 → 3 + SP | 2+HK → 2+HP → 236+HK | 2212 | 2500 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 16 | 16 | 3 + 强 → 2 + 中 → 214 + 中 | 2+HK → 2+MK → 214+MP | 2200 | 2400 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 17 | 17 | 3 + 强 → 2 + 中 → 623 + 弱 | 2+HK → 2+MK → 623+LP | 2200 | 2400 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 18 | 18 | 3 + 强 → 2 + 强 → 236 + 弱 | 2+HK → 2+HP → 236+LP | 2180 | 2300 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 19 | 19 | 3 + 强 → 2 + 强 → 623 + 中 | 2+HK → 2+HP → 623+MP | 2180 | 2300 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 20 | 20 | 3 + 强 → 弱 → 214 + 强 | 2+HK → LP → 214+HP | 2160 | 2400 | drive 0 | 7.7 | medium | 0/2 pairs verified |

## Pairs to sweep: 24

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 409 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 3 + 强 → 2 + 强 | `638:manual->627:manual` | 1, 3, 4, 5, 9, 11, 12, 14, 15, 18, 19 | untested | single | medium | 32 |
| 2 | 2 + 强 → 214 + 强 | `627:manual->933:manual` | 1 | untested | single | high | -22 |
| 3 | 3 + 强 → 中 | `638:manual->604:manual` | 2, 6, 7, 10, 13 | untested | single | medium | 33 |
| 4 | 中 → 214 + 强 | `604:manual->933:manual` | 2 | untested | single | high | -21 |
| 5 | 2 + 强 → 214 + 中 | `627:manual->931:manual` | 3 | untested | single | high | -13 |
| 6 | 2 + 强 → 623 + 弱 | `627:manual->940:manual` | 4 | untested | single | high | -4 |
| 7 | 2 + 强 → 236 + 强 | `627:manual->902:manual` | 5 | untested | single | high | -28 |
| 8 | 中 → 214 + 中 | `604:manual->931:manual` | 6 | untested | single | high | -12 |
| 9 | 中 → 623 + 弱 | `604:manual->940:manual` | 7 | untested | single | high | -3 |
| 10 | 3 + 强 → 2 + 中 | `638:manual->635:manual` | 8, 16, 17 | untested | single | medium | 32 |
| 11 | 2 + 中 → 214 + 强 | `635:manual->933:manual` | 8 | untested | single | high | -25 |
| 12 | 2 + 强 → 6 + SP | `627:manual->940:simple` | 9 | untested | single | high | -4 |
| 13 | 中 → 236 + 强 | `604:manual->902:manual` | 10 | untested | single | high | -27 |
| 14 | 2 + 强 → 236 + 中 | `627:manual->901:manual` | 11 | untested | single | high | -15 |
| 15 | 2 + 强 → 623 + 强 | `627:manual->942:manual` | 12 | untested | single | high | -6 |
| 16 | 中 → 6 + SP | `604:manual->940:simple` | 13 | untested | single | high | -3 |
| 17 | 2 + 强 → 2 + SP | `627:manual->916:simple` | 14 | untested | single | high | -19 |
| 18 | 2 + 强 → 3 + SP | `627:manual->917:simple` | 15 | untested | single | high | -24 |
| 19 | 2 + 中 → 214 + 中 | `635:manual->931:manual` | 16 | untested | single | high | -16 |
| 20 | 2 + 中 → 623 + 弱 | `635:manual->940:manual` | 17 | untested | single | high | -7 |
| 21 | 2 + 强 → 236 + 弱 | `627:manual->900:manual` | 18 | untested | single | high | -13 |
| 22 | 2 + 强 → 623 + 中 | `627:manual->941:manual` | 19 | untested | single | high | -5 |
| 23 | 3 + 强 → 弱 | `638:manual->600:manual` | 20 | untested | single | medium | 36 |
| 24 | 弱 → 214 + 强 | `600:manual->933:manual` | 20 | untested | single | high | -19 |

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

- reframework/data/ComboExplorer_data/worklist/terry-modern-plan-no-gauge.json  (24 pairs, 13602 bytes)
- docs/ComboExplorer/plans/terry-modern-no-gauge.md
