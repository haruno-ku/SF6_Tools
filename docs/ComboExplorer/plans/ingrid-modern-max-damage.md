# Route plan - Ingrid / modern - max-damage

Generated 2026-09-14T13:03:03Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

669 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 2502 (search complete: false)
  - the beam dropped 4159 partial routes and 0 routes were not emitted, so a route
    satisfying these conditions may be missing

- routes satisfying every condition: 2502
- of those, through a pair the logs rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 2 + 弱 + 中 + 强 → 6 + 强 → 214214 + 强 | 2+KKK → 6+HP → 22+PPP | 6000 | 7000 | OD 1, drive >=0 (1 unknown) | 11.9 | medium | 0/2 pairs verified |
| 2 | 2 | 6 + 强 → 214214 + 强 | 6+HP → 22+PPP | 5900 | 5900 | OD 1, drive >=0 (1 unknown) | 8.9 | medium | 0/1 pairs verified |
| 3 | 3 | 6 + 弱 + 中 + 强 → 6 + 强 → 214214 + 强 | 6+KKK → 6+HP → 22+PPP | 5900 | 6900 | OD 1, drive >=0 (1 unknown) | 11.9 | medium | 0/2 pairs verified |
| 4 | 4 | 2 + 弱 + 中 + 强 → 2 + 强 → 214214 + 强 | 2+KKK → 2+HP → 22+PPP | 5900 | 6900 | OD 1, drive >=0 (1 unknown) | 11.9 | medium | 0/2 pairs verified |
| 5 | 5 | 2 + 强 → 214214 + 强 | 2+HP → 22+PPP | 5800 | 5800 | OD 1, drive >=0 (1 unknown) | 8.9 | high | 0/1 pairs verified |
| 6 | 6 | 3 + 强 → 6 + 强 → 214214 + 强 | 2+HK → 6+HP → 22+PPP | 5800 | 6800 | OD 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs verified |
| 7 | 7 | 6 + 弱 + 中 + 强 → 2 + 强 → 214214 + 强 | 6+KKK → 2+HP → 22+PPP | 5800 | 6800 | OD 1, drive >=0 (1 unknown) | 11.9 | medium | 0/2 pairs verified |
| 8 | 8 | 3 + 强 → 2 + 强 → 214214 + 强 | 2+HK → 2+HP → 22+PPP | 5700 | 6700 | OD 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs verified |
| 9 | 9 | 6 + 强 → 2 + 强 → 214214 + 强 | 6+HP → 2+HP → 22+PPP | 5700 | 6700 | OD 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs verified |
| 10 | 10 | 4 + 强 → 6 + 强 → 214214 + 强 | 4+HP → 6+HP → 22+PPP | 5700 | 6700 | OD 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs verified |
| 11 | 11 | 4 + 强 → 2 + 强 → 214214 + 强 | 4+HP → 2+HP → 22+PPP | 5600 | 6600 | OD 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs verified |
| 12 | 12 | 2 + 弱 + 中 + 强 → 2 + 中 → 214214 + 强 | 2+KKK → 2+MK → 22+PPP | 5600 | 6600 | OD 1, drive >=0 (1 unknown) | 11.9 | medium | 0/2 pairs verified |
| 13 | 13 | 强 → 6 + 强 → 214214 + 强 | HK → 6+HP → 22+PPP | 5500 | 6500 | OD 1, drive >=0 (1 unknown) | 10.4 | low | 0/2 pairs verified |
| 14 | 14 | 2 + 中 → 214214 + 强 | 2+MK → 22+PPP | 5500 | 5500 | OD 1, drive >=0 (1 unknown) | 8.9 | high | 0/1 pairs verified |
| 15 | 15 | 6 + 弱 + 中 + 强 → 2 + 中 → 214214 + 强 | 6+KKK → 2+MK → 22+PPP | 5500 | 6500 | OD 1, drive >=0 (1 unknown) | 11.9 | medium | 0/2 pairs verified |
| 16 | 16 | 强 → 2 + 强 → 214214 + 强 | HK → 2+HP → 22+PPP | 5400 | 6400 | OD 1, drive >=0 (1 unknown) | 10.4 | low | 0/2 pairs verified |
| 17 | 17 | 3 + 强 → 2 + 中 → 214214 + 强 | 2+HK → 2+MK → 22+PPP | 5400 | 6400 | OD 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs verified |
| 18 | 18 | 6 + 强 → 2 + 中 → 214214 + 强 | 6+HP → 2+MK → 22+PPP | 5400 | 6400 | OD 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs verified |
| 19 | 19 | 2 + 弱 + 中 + 强 → 2 + 弱 → 214214 + 强 | 2+KKK → 2+LP → 22+PPP | 5400 | 6400 | OD 1, drive >=0 (1 unknown) | 11.9 | medium | 0/2 pairs verified |
| 20 | 20 | 4 + 强 → 2 + 中 → 214214 + 强 | 4+HP → 2+MK → 22+PPP | 5300 | 6300 | OD 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs verified |

## Pairs to sweep: 21

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 719 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 2 + 弱 + 中 + 强 → 6 + 强 | `964:manual->663:manual` | 1 | untested | single | medium | 31 |
| 2 | 6 + 强 → 214214 + 强 | `663:manual->1317:manual` | 1, 2, 3, 6, 10, 13 | untested | single | medium | -23 |
| 3 | 6 + 弱 + 中 + 强 → 6 + 强 | `963:manual->663:manual` | 3 | untested | single | medium | 27 |
| 4 | 2 + 弱 + 中 + 强 → 2 + 强 | `964:manual->631:manual` | 4 | untested | single | medium | 36 |
| 5 | 2 + 强 → 214214 + 强 | `631:manual->1317:manual` | 4, 5, 7, 8, 9, 11, 16 | untested | single | high | -60 |
| 6 | 3 + 强 → 6 + 强 | `643:manual->663:manual` | 6 | untested | single | medium | 13 |
| 7 | 6 + 弱 + 中 + 强 → 2 + 强 | `963:manual->631:manual` | 7 | untested | single | medium | 32 |
| 8 | 3 + 强 → 2 + 强 | `643:manual->631:manual` | 8 | untested | single | medium | 18 |
| 9 | 6 + 强 → 2 + 强 | `663:manual->631:manual` | 9 | untested | single | medium | 26 |
| 10 | 4 + 强 → 6 + 强 | `674:manual->663:manual` | 10 | untested | single | medium | 28 |
| 11 | 4 + 强 → 2 + 强 | `674:manual->631:manual` | 11 | untested | single | medium | 33 |
| 12 | 2 + 弱 + 中 + 强 → 2 + 中 | `964:manual->640:manual` | 12 | untested | single | medium | 40 |
| 13 | 2 + 中 → 214214 + 强 | `640:manual->1317:manual` | 12, 14, 15, 17, 18, 20 | untested | single | high | -60 |
| 14 | 强 → 6 + 强 | `618:manual->663:manual` | 13 | untested | single | low | 14 |
| 15 | 6 + 弱 + 中 + 强 → 2 + 中 | `963:manual->640:manual` | 15 | untested | single | medium | 36 |
| 16 | 强 → 2 + 强 | `618:manual->631:manual` | 16 | untested | single | low | 19 |
| 17 | 3 + 强 → 2 + 中 | `643:manual->640:manual` | 17 | untested | single | medium | 22 |
| 18 | 6 + 强 → 2 + 中 | `663:manual->640:manual` | 18 | untested | single | medium | 30 |
| 19 | 2 + 弱 + 中 + 强 → 2 + 弱 | `964:manual->623:manual` | 19 | untested | single | medium | 44 |
| 20 | 2 + 弱 → 214214 + 强 | `623:manual->1317:manual` | 19 | untested | single | high | -57 |
| 21 | 4 + 强 → 2 + 中 | `674:manual->640:manual` | 20 | untested | single | medium | 37 |

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

- reframework/data/ComboExplorer_data/worklist/ingrid-modern-plan-max-damage.json  (21 pairs, 11865 bytes)
- docs/ComboExplorer/plans/ingrid-modern-max-damage.md
