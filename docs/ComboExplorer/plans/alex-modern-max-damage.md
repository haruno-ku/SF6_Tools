# Route plan - Alex / modern - max-damage

Generated 2026-09-14T13:02:38Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

5 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 919 (search complete: false)
  - the beam dropped 2652 partial routes and 0 routes were not emitted, so a route
    satisfying these conditions may be missing

- routes satisfying every condition: 919
- of those, through a pair the logs rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 2 + 强 → 3 + 强 → 236236 + 强 | 2+HK → 2+HK → 236236+P | 5200 | 6000 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs verified |
| 2 | 2 | 3 + 强 → 2 + 强 → 236236 + 强 | 2+HK → 2+HK → 236236+P | 5200 | 6000 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs verified |
| 3 | 3 | 2 + 强 → 强 → 236236 + 强 | 2+HK → HP → 236236+P | 5100 | 5900 | SA 1, drive >=0 (1 unknown) | 10.4 | low | 0/2 pairs verified |
| 4 | 4 | 3 + 强 → 强 → 236236 + 强 | 2+HK → HP → 236236+P | 5100 | 5900 | SA 1, drive >=0 (1 unknown) | 10.4 | low | 0/2 pairs verified |
| 5 | 5 | 2 + 强 → 2 + 强 → 236236 + 强 | 2+HK → 2+HP → 236236+P | 5000 | 5800 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs verified |
| 6 | 6 | 3 + 强 → 236236 + 强 | 2+HK → 236236+P | 5000 | 5000 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs verified |
| 7 | 7 | 强 → 236236 + 强 | HP → 236236+P | 4900 | 4900 | SA 1, drive >=0 (1 unknown) | 8.4 | low | 0/1 pairs verified |
| 8 | 8 | 2 + 强 → 236236 + 强 | 2+HP → 236236+P | 4800 | 4800 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs verified |
| 9 | 9 | 2 + 强 → 中 → 236236 + 强 | 2+HK → MP → 236236+P | 4800 | 5600 | SA 1, drive >=0 (1 unknown) | 10.4 | low | 0/2 pairs verified |
| 10 | 10 | 3 + 强 → 中 → 236236 + 强 | 2+HK → MP → 236236+P | 4800 | 5600 | SA 1, drive >=0 (1 unknown) | 10.4 | low | 0/2 pairs verified |
| 11 | 11 | 中 → 236236 + 强 | MP → 236236+P | 4600 | 4600 | SA 1, drive >=0 (1 unknown) | 8.4 | low | 0/1 pairs verified |
| 12 | 12 | 2 + 强 → 3 + 强 → 2 + SP + 强 | 2+HK → 2+HK → 236236+P | 4560 | 6000 | SA 1, drive >=0 (1 unknown) | 8.5 | low | 0/2 pairs verified |
| 13 | 13 | 3 + 强 → 2 + 强 → 2 + SP + 强 | 2+HK → 2+HK → 236236+P | 4560 | 6000 | SA 1, drive >=0 (1 unknown) | 8.5 | low | 0/2 pairs verified |
| 14 | 14 | 2 + 强 → 弱 → 236236 + 强 | 2+HK → LP → 236236+P | 4500 | 5300 | SA 1, drive >=0 (1 unknown) | 10.4 | low | 0/2 pairs verified |
| 15 | 15 | 2 + 强 → 2 + 弱 → 236236 + 强 | 2+HK → 2+LP → 236236+P | 4500 | 5300 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs verified |
| 16 | 16 | 3 + 强 → 弱 → 236236 + 强 | 2+HK → LP → 236236+P | 4500 | 5300 | SA 1, drive >=0 (1 unknown) | 10.4 | low | 0/2 pairs verified |
| 17 | 17 | 3 + 强 → 2 + 弱 → 236236 + 强 | 2+HK → 2+LP → 236236+P | 4500 | 5300 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs verified |
| 18 | 18 | 2 + 强 → 强 → 2 + SP + 强 | 2+HK → HP → 236236+P | 4460 | 5900 | SA 1, drive >=0 (1 unknown) | 8.0 | low | 0/2 pairs verified |
| 19 | 19 | 3 + 强 → 强 → 2 + SP + 强 | 2+HK → HP → 236236+P | 4460 | 5900 | SA 1, drive >=0 (1 unknown) | 8.0 | low | 0/2 pairs verified |
| 20 | 20 | 2 + 强 → 3 + 强 → 214214 + 中 | 2+HK → 2+HK → 214214+P | 4400 | 5000 | SA 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs verified |

## Pairs to sweep: 22

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 583 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 2 + 强 → 3 + 强 | `636:manual->640:manual` | 1, 12, 20 | untested | single | medium | 19 |
| 2 | 3 + 强 → 236236 + 强 | `640:manual->1230:manual` | 1, 6 | untested | single | low | 17 |
| 3 | 3 + 强 → 2 + 强 | `640:manual->636:manual` | 2, 13 | untested | single | medium | 19 |
| 4 | 2 + 强 → 236236 + 强 | `636:manual->1230:manual` | 2 | untested | single | low | 17 |
| 5 | 2 + 强 → 强 | `636:manual->976:manual` | 3, 18 | untested | single | low | 17 |
| 6 | 强 → 236236 + 强 | `976:manual->1230:manual` | 3, 4, 7 | untested | single | low | -8 |
| 7 | 3 + 强 → 强 | `640:manual->976:manual` | 4, 19 | untested | single | low | 17 |
| 8 | 2 + 强 → 2 + 强 | `636:manual->628:manual` | 5 | untested | single | medium | 20 |
| 9 | 2 + 强 → 236236 + 强 | `628:manual->1230:manual` | 5, 8 | untested | single | low | -15 |
| 10 | 2 + 强 → 中 | `636:manual->604:manual` | 9 | untested | single | medium | 22 |
| 11 | 中 → 236236 + 强 | `604:manual->1230:manual` | 9, 10, 11 | untested | single | low | -8 |
| 12 | 3 + 强 → 中 | `640:manual->604:manual` | 10 | untested | single | medium | 22 |
| 13 | 3 + 强 → 2 + SP + 强 | `640:manual->1230:simple` | 12 | untested | single | low | 17 |
| 14 | 2 + 强 → 2 + SP + 强 | `636:manual->1230:simple` | 13 | untested | single | low | 17 |
| 15 | 2 + 强 → 弱 | `636:manual->600:manual` | 14 | untested | single | medium | 25 |
| 16 | 弱 → 236236 + 强 | `600:manual->1230:manual` | 14, 16 | untested | single | low | -7 |
| 17 | 2 + 强 → 2 + 弱 | `636:manual->622:manual` | 15 | untested | single | medium | 24 |
| 18 | 2 + 弱 → 236236 + 强 | `622:manual->1230:manual` | 15, 17 | untested | single | low | -7 |
| 19 | 3 + 强 → 弱 | `640:manual->600:manual` | 16 | untested | single | medium | 25 |
| 20 | 3 + 强 → 2 + 弱 | `640:manual->622:manual` | 17 | untested | single | medium | 24 |
| 21 | 强 → 2 + SP + 强 | `976:manual->1230:simple` | 18, 19 | untested | single | low | -8 |
| 22 | 3 + 强 → 214214 + 中 | `640:manual->1208:manual` | 20 | untested | single | medium | 16 |

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

- reframework/data/ComboExplorer_data/worklist/alex-modern-plan-max-damage.json  (22 pairs, 12284 bytes)
- docs/ComboExplorer/plans/alex-modern-max-damage.md
