# Route plan - Lily / modern - max-damage

Generated 2026-09-14T12:59:59Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

13 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 848 (search complete: false)
  - the beam dropped 562 partial routes and 0 routes were not emitted, so a route
    satisfying these conditions may be missing

- routes satisfying every condition: 848
- of those, through a pair the logs rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 4 + 强 → 214214 + 强 | 4+HP → 214214+P | 5500 | 5500 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs verified |
| 2 | 2 | 强 → 214214 + 强 | HP → 214214+P | 5400 | 5400 | SA 1, drive >=0 (1 unknown) | 8.4 | low | 0/1 pairs verified |
| 3 | 3 | 6 + 强 → 214214 + 强 | 6+HP → 214214+P | 5400 | 5400 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs verified |
| 4 | 4 | 2 + 中 → 214214 + 强 | 2+MP → 214214+P | 5200 | 5200 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs verified |
| 5 | 5 | 3 + 强 → 4 + 强 → 214214 + 强 | 2+HK → 4+HP → 214214+P | 5050 | 5950 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs verified |
| 6 | 6 | 2 + 强 → 214214 + 强 | 2+HP → 214214+P | 5000 | 5000 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs verified |
| 7 | 7 | 3 + 强 → 214214 + 强 | 2+HK → 214214+P | 4950 | 4950 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs verified |
| 8 | 8 | 3 + 强 → 强 → 214214 + 强 | 2+HK → HP → 214214+P | 4950 | 5850 | SA 1, drive >=0 (1 unknown) | 10.4 | low | 0/2 pairs verified |
| 9 | 9 | 3 + 强 → 6 + 强 → 214214 + 强 | 2+HK → 6+HP → 214214+P | 4950 | 5850 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs verified |
| 10 | 10 | 4 + 强 → 弱 → 214214 + 强 | 4+HP → LP → 214214+P | 4950 | 5850 | SA 1, drive >=0 (1 unknown) | 10.4 | low | 0/2 pairs verified |
| 11 | 11 | 3 + 强 → 2 + 中 → 214214 + 强 | 2+HK → 2+MP → 214214+P | 4750 | 5650 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs verified |
| 12 | 12 | 4 + 强 → 2 + SP + 强 | 4+HP → 214214+P | 4600 | 5500 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs verified |
| 13 | 13 | 3 + 强 → 2 + 强 → 214214 + 强 | 2+HK → 2+HP → 214214+P | 4550 | 5450 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs verified |
| 14 | 14 | 强 → 2 + SP + 强 | HP → 214214+P | 4500 | 5400 | SA 1, drive >=0 (1 unknown) | 6.0 | low | 0/1 pairs verified |
| 15 | 15 | 6 + 强 → 2 + SP + 强 | 6+HP → 214214+P | 4500 | 5400 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs verified |
| 16 | 16 | 3 + 强 → 弱 → 214214 + 强 | 2+HK → LP → 214214+P | 4400 | 5300 | SA 1, drive >=0 (1 unknown) | 10.4 | low | 0/2 pairs verified |
| 17 | 17 | 3 + 强 → 2 + 弱 → 214214 + 强 | 2+HK → 2+LP → 214214+P | 4350 | 5250 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs verified |
| 18 | 18 | 3 + 强 → 4 + 强 → 2 + SP + 强 | 2+HK → 4+HP → 214214+P | 4330 | 5950 | SA 1, drive >=0 (1 unknown) | 8.5 | low | 0/2 pairs verified |
| 19 | 19 | 弱 → 4 + 强 → 214214 + 强 | LP → 4+HP → 214214+P | 4300 | 5850 | SA 1, drive >=0 (1 unknown) | 10.4 | low | 0/2 pairs verified |
| 20 | 20 | 2 + 中 → 2 + SP + 强 | 2+MP → 214214+P | 4300 | 5200 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs verified |

## Pairs to sweep: 21

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 635 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 4 + 强 → 214214 + 强 | `658:manual->1216:manual` | 1, 5, 19 | untested | single | low | 0 |
| 2 | 强 → 214214 + 强 | `606:manual->1216:manual` | 2, 8 | untested | single | low | -5 |
| 3 | 6 + 强 → 214214 + 强 | `653:manual->1216:manual` | 3, 9 | untested | single | low | -3 |
| 4 | 2 + 中 → 214214 + 强 | `620:manual->1216:manual` | 4, 11 | untested | single | low | -4 |
| 5 | 3 + 强 → 4 + 强 | `630:manual->658:manual` | 5, 18 | untested | single | medium | 18 |
| 6 | 2 + 强 → 214214 + 强 | `622:manual->1216:manual` | 6, 13 | untested | single | low | -5 |
| 7 | 3 + 强 → 214214 + 强 | `630:manual->1216:manual` | 7 | untested | single | low | 27 |
| 8 | 3 + 强 → 强 | `630:manual->606:manual` | 8 | untested | single | medium | 22 |
| 9 | 3 + 强 → 6 + 强 | `630:manual->653:manual` | 9 | untested | single | medium | 16 |
| 10 | 4 + 强 → 弱 | `658:manual->601:manual` | 10 | untested | single | medium | 0 |
| 11 | 弱 → 214214 + 强 | `601:manual->1216:manual` | 10, 16 | untested | single | low | 1 |
| 12 | 3 + 强 → 2 + 中 | `630:manual->620:manual` | 11 | untested | single | medium | 24 |
| 13 | 4 + 强 → 2 + SP + 强 | `658:manual->1216:simple` | 12, 18 | untested | single | low | 0 |
| 14 | 3 + 强 → 2 + 强 | `630:manual->622:manual` | 13 | untested | single | medium | 22 |
| 15 | 强 → 2 + SP + 强 | `606:manual->1216:simple` | 14 | untested | single | low | -5 |
| 16 | 6 + 强 → 2 + SP + 强 | `653:manual->1216:simple` | 15 | untested | single | low | -3 |
| 17 | 3 + 强 → 弱 | `630:manual->601:manual` | 16 | untested | single | medium | 27 |
| 18 | 3 + 强 → 2 + 弱 | `630:manual->616:manual` | 17 | untested | single | medium | 26 |
| 19 | 2 + 弱 → 214214 + 强 | `616:manual->1216:manual` | 17 | untested | single | low | 1 |
| 20 | 弱 → 4 + 强 | `601:manual->658:manual` | 19 | untested | single | medium | -8 |
| 21 | 2 + 中 → 2 + SP + 强 | `620:manual->1216:simple` | 20 | untested | single | low | -4 |

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

- reframework/data/ComboExplorer_data/worklist/lily-modern-plan-max-damage.json  (21 pairs, 12123 bytes)
- docs/ComboExplorer/plans/lily-modern-max-damage.md
