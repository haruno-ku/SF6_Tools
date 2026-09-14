# Route plan - Yasmine / modern - max-damage

Generated 2026-09-14T13:03:04Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

EVERY ROUTE HERE IS A THEORETICAL CANDIDATE. The ranking is a prediction from
the frame data. The worklist below is the smallest set of pairs that lets the
game say whether these routes connect.

## Conditions

- none: every route the search found
- sort: `scaled_damage`, top 20
- search: explore.lua's settings (normal,command_normal -> normal,command_normal,special,od_special,super, manual -> manual,simple, max 3 moves, beam 4000, collapse true)
- Drive Rush Cancel edges in the search: no (pass --drive-rush to route through them)
- demote routes through a rejected pair: yes

## Damage figure

Ordered on `offline_score.predicted_damage_scaled`, the combo-scaled prediction.

1682 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 1860 (search complete: false)
  - the beam dropped 2126 partial routes and 0 routes were not emitted, so a route
    satisfying these conditions may be missing

- routes satisfying every condition: 1860
- of those, through a pair the logs rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 3 + 强 → 236236 + 强 | 2+HK → 236236+P | 4900 | 4900 | SA 1, drive >=0 (2 unknown) | 8.9 | low | 0/1 pairs verified |
| 2 | 2 | 3 + 强 → 2 + 强 → 236236 + 强 | 2+HK → 2+HP → 236236+P | 4900 | 5700 | SA 1, drive >=0 (3 unknown) | 10.9 | low | 0/2 pairs verified |
| 3 | 3 | 2 + 强 → 236236 + 强 | 2+HP → 236236+P | 4800 | 4800 | SA 1, drive >=0 (2 unknown) | 8.9 | low | 0/1 pairs verified |
| 4 | 4 | 3 + 强 → 6 + 中 → 236236 + 强 | 2+HK → 6+MP → 236236+P | 4700 | 5500 | SA 1, drive >=0 (2 unknown) | 10.9 | low | 0/2 pairs verified |
| 5 | 5 | 6 + 中 → 3 + 强 → 236236 + 强 | 6+MP → 2+HK → 236236+P | 4700 | 5500 | SA 1, drive >=0 (2 unknown) | 10.9 | low | 0/2 pairs verified |
| 6 | 6 | 3 + 强 → 2 + 中 → 236236 + 强 | 2+HK → 2+MK → 236236+P | 4600 | 5400 | SA 1, drive >=0 (3 unknown) | 10.9 | low | 0/2 pairs verified |
| 7 | 7 | 6 + 中 → 236236 + 强 | 6+MP → 236236+P | 4600 | 4600 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs verified |
| 8 | 8 | 6 + 中 → 2 + 强 → 236236 + 强 | 6+MP → 2+HP → 236236+P | 4600 | 5400 | SA 1, drive >=0 (2 unknown) | 10.9 | low | 0/2 pairs verified |
| 9 | 9 | 2 + 中 → 236236 + 强 | 2+MK → 236236+P | 4500 | 4500 | SA 1, drive >=0 (2 unknown) | 8.9 | low | 0/1 pairs verified |
| 10 | 10 | 3 + 强 → 弱 → 236236 + 强 | 2+HK → LP → 236236+P | 4400 | 5200 | SA 1, drive >=0 (3 unknown) | 10.4 | low | 0/2 pairs verified |
| 11 | 11 | 3 + 强 → 2 + 弱 → 236236 + 强 | 2+HK → 2+LP → 236236+P | 4400 | 5200 | SA 1, drive >=0 (3 unknown) | 10.9 | low | 0/2 pairs verified |
| 12 | 12 | 6 + 中 → 2 + 中 → 236236 + 强 | 6+MP → 2+MK → 236236+P | 4300 | 5100 | SA 1, drive >=0 (2 unknown) | 10.9 | low | 0/2 pairs verified |
| 13 | 13 | 3 + 强 → 2 + 强 → 2 + SP + 强 | 2+HK → 2+HP → 236236+P | 4260 | 5700 | SA 1, drive >=0 (3 unknown) | 8.5 | low | 0/2 pairs verified |
| 14 | 14 | 3 + 强 → 2 + SP + 强 | 2+HK → 236236+P | 4100 | 4900 | SA 1, drive >=0 (2 unknown) | 6.5 | low | 0/1 pairs verified |
| 15 | 15 | 6 + 中 → 弱 → 236236 + 强 | 6+MP → LP → 236236+P | 4100 | 4900 | SA 1, drive >=0 (2 unknown) | 10.4 | low | 0/2 pairs verified |
| 16 | 16 | 6 + 中 → 2 + 弱 → 236236 + 强 | 6+MP → 2+LP → 236236+P | 4100 | 4900 | SA 1, drive >=0 (2 unknown) | 10.9 | low | 0/2 pairs verified |
| 17 | 17 | 3 + 强 → 6 + 中 → 2 + SP + 强 | 2+HK → 6+MP → 236236+P | 4060 | 5500 | SA 1, drive >=0 (2 unknown) | 8.5 | low | 0/2 pairs verified |
| 18 | 18 | 6 + 中 → 3 + 强 → 2 + SP + 强 | 6+MP → 2+HK → 236236+P | 4060 | 5500 | SA 1, drive >=0 (2 unknown) | 8.5 | low | 0/2 pairs verified |
| 19 | 19 | 2 + 强 → 2 + SP + 强 | 2+HP → 236236+P | 4000 | 4800 | SA 1, drive >=0 (2 unknown) | 6.5 | low | 0/1 pairs verified |
| 20 | 20 | 3 + 强 → 2 + 中 → 2 + SP + 强 | 2+HK → 2+MK → 236236+P | 3960 | 5400 | SA 1, drive >=0 (3 unknown) | 8.5 | low | 0/2 pairs verified |

## Pairs to sweep: 20

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 733 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 3 + 强 → 236236 + 强 | `647:manual->1214:manual` | 1, 5 | untested | single | low | 30 |
| 2 | 3 + 强 → 2 + 强 | `647:manual->633:manual` | 2, 13 | untested | single | medium | 32 |
| 3 | 2 + 强 → 236236 + 强 | `633:manual->1214:manual` | 2, 3, 8 | untested | single | low | -8 |
| 4 | 3 + 强 → 6 + 中 | `647:manual->664:manual` | 4, 17 | untested | single | medium | 18 |
| 5 | 6 + 中 → 236236 + 强 | `664:manual->1214:manual` | 4, 7 | untested | single | low | - |
| 6 | 6 + 中 → 3 + 强 | `664:manual->647:manual` | 5, 18 | untested | single | low | - |
| 7 | 3 + 强 → 2 + 中 | `647:manual->641:manual` | 6, 20 | untested | single | medium | 32 |
| 8 | 2 + 中 → 236236 + 强 | `641:manual->1214:manual` | 6, 9, 12 | untested | single | low | -11 |
| 9 | 6 + 中 → 2 + 强 | `664:manual->633:manual` | 8 | untested | single | low | - |
| 10 | 3 + 强 → 弱 | `647:manual->602:manual` | 10 | untested | single | medium | 35 |
| 11 | 弱 → 236236 + 强 | `602:manual->1214:manual` | 10, 15 | untested | single | low | -6 |
| 12 | 3 + 强 → 2 + 弱 | `647:manual->624:manual` | 11 | untested | single | medium | 36 |
| 13 | 2 + 弱 → 236236 + 强 | `624:manual->1214:manual` | 11, 16 | untested | single | low | -6 |
| 14 | 6 + 中 → 2 + 中 | `664:manual->641:manual` | 12 | untested | single | low | - |
| 15 | 2 + 强 → 2 + SP + 强 | `633:manual->1214:simple` | 13, 19 | untested | single | low | -8 |
| 16 | 3 + 强 → 2 + SP + 强 | `647:manual->1214:simple` | 14, 18 | untested | single | low | 30 |
| 17 | 6 + 中 → 弱 | `664:manual->602:manual` | 15 | untested | single | low | - |
| 18 | 6 + 中 → 2 + 弱 | `664:manual->624:manual` | 16 | untested | single | low | - |
| 19 | 6 + 中 → 2 + SP + 强 | `664:manual->1214:simple` | 17 | untested | single | low | - |
| 20 | 2 + 中 → 2 + SP + 强 | `641:manual->1214:simple` | 20 | untested | single | low | -11 |

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
reframework/data), then pick `plan: max-damage` in the SWEEP panel's worklist list
(REFRESH if the panel was already open) and START SWEEP. It writes to the same
trial log as the full sweep, so pairs the full sweep already answered under the
same calibration and conditions are skipped, and the other way round.

## Written

- reframework/data/ComboExplorer_data/worklist/yasmine-modern-plan-max-damage.json  (20 pairs, 10873 bytes)
- docs/ComboExplorer/plans/yasmine-modern-max-damage.md
