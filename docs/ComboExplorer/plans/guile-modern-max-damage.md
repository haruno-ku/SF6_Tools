# Route plan - Guile / modern - max-damage

Generated 2026-09-14T13:00:45Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

458 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 1178 (search complete: false)
  - the beam dropped 78139 partial routes and 0 routes were not emitted, so a route
    satisfying these conditions may be missing

- routes satisfying every condition: 1178
- of those, through a pair the logs rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 2 + 强 → [4]646 + 强 | 2+HP → [4]646+K | 4900 | 4900 | SA 1, drive >=0 (1 unknown) | 7.1 | low | 0/1 pairs verified |
| 2 | 2 | 强 → [4]646 + 强 | HK → [4]646+K | 4800 | 4800 | SA 1, drive >=0 (1 unknown) | 6.6 | low | 0/1 pairs verified |
| 3 | 3 | 4 + 强 → [4]646 + 强 | 4+HP → [4]646+K | 4800 | 4800 | SA 1, drive >=0 (1 unknown) | 7.1 | low | 0/1 pairs verified |
| 4 | 4 | 中 → [4]646 + 强 | MP → [4]646+K | 4600 | 4600 | SA 1, drive >=0 (1 unknown) | 6.6 | low | 0/1 pairs verified |
| 5 | 5 | 3 + 强 → 强 → [4]646 + 强 | 2+HK → HP → [4]646+K | 4550 | 5350 | SA 1, drive >=0 (1 unknown) | 8.6 | low | 0/2 pairs verified |
| 6 | 6 | 3 + 强 → 2 + 强 → [4]646 + 强 | 2+HK → 2+HP → [4]646+K | 4550 | 5350 | SA 1, drive >=0 (1 unknown) | 9.1 | low | 0/2 pairs verified |
| 7 | 7 | 3 + 强 → [4]646 + 强 | 2+HK → [4]646+K | 4450 | 4450 | SA 1, drive >=0 (1 unknown) | 7.1 | low | 0/1 pairs verified |
| 8 | 8 | 3 + 强 → 4 + 强 → [4]646 + 强 | 2+HK → 4+HP → [4]646+K | 4450 | 5250 | SA 1, drive >=0 (1 unknown) | 9.1 | low | 0/2 pairs verified |
| 9 | 9 | 强 → 2 + 弱 → [4]646 + 强 | HK → 2+LP → [4]646+K | 4300 | 5100 | SA 1, drive >=0 (1 unknown) | 8.6 | low | 0/2 pairs verified |
| 10 | 10 | 6 + 强 → 弱 → [4]646 + 强 | 6+HP → LP → [4]646+K | 4300 | 5100 | SA 1, drive >=0 (1 unknown) | 8.6 | low | 0/2 pairs verified |
| 11 | 11 | 6 + 强 → 2 + 弱 → [4]646 + 强 | 6+HP → 2+LP → [4]646+K | 4300 | 5100 | SA 1, drive >=0 (1 unknown) | 9.1 | low | 0/2 pairs verified |
| 12 | 12 | 3 + 强 → 中 → [4]646 + 强 | 2+HK → MP → [4]646+K | 4250 | 5050 | SA 1, drive >=0 (1 unknown) | 8.6 | low | 0/2 pairs verified |
| 13 | 13 | 2 + 强 → [2] + SP + 强 | 2+HP → [4]646+K | 4100 | 4900 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs verified |
| 14 | 14 | 强 → [2] + SP + 强 | HK → [4]646+K | 4000 | 4800 | SA 1, drive >=0 (1 unknown) | 6.0 | low | 0/1 pairs verified |
| 15 | 15 | 4 + 强 → [2] + SP + 强 | 4+HP → [4]646+K | 4000 | 4800 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs verified |
| 16 | 16 | 3 + 强 → 强 → [2] + SP + 强 | 2+HK → HP → [4]646+K | 3910 | 5350 | SA 1, drive >=0 (1 unknown) | 8.0 | low | 0/2 pairs verified |
| 17 | 17 | 3 + 强 → 2 + 强 → [2] + SP + 强 | 2+HK → 2+HP → [4]646+K | 3910 | 5350 | SA 1, drive >=0 (1 unknown) | 8.5 | low | 0/2 pairs verified |
| 18 | 18 | 弱 → 强 → [4]646 + 强 | LP → HP → [4]646+K | 3820 | 5200 | SA 1, drive >=0 (1 unknown) | 8.1 | low | 0/2 pairs verified |
| 19 | 19 | 弱 → 2 + 强 → [4]646 + 强 | LP → 2+HP → [4]646+K | 3820 | 5200 | SA 1, drive >=0 (1 unknown) | 8.6 | low | 0/2 pairs verified |
| 20 | 20 | 2 + 弱 → 强 → [4]646 + 强 | 2+LP → HP → [4]646+K | 3820 | 5200 | SA 1, drive >=0 (1 unknown) | 8.6 | low | 0/2 pairs verified |

## Pairs to sweep: 22

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 2797 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 2 + 强 → [4]646 + 强 | `629:manual->1240:manual` | 1, 6, 19 | untested | single | low | -9 |
| 2 | 强 → [4]646 + 强 | `618:manual->1240:manual` | 2 | untested | single | low | -5 |
| 3 | 4 + 强 → [4]646 + 强 | `656:manual->1240:manual` | 3, 8 | untested | single | low | -8 |
| 4 | 中 → [4]646 + 强 | `1216:manual->1240:manual` | 4, 12 | untested | single | low | -3 |
| 5 | 3 + 强 → 强 | `641:manual->1217:manual` | 5, 16 | untested | single | low | 27 |
| 6 | 强 → [4]646 + 强 | `1217:manual->1240:manual` | 5, 18, 20 | untested | single | low | -10 |
| 7 | 3 + 强 → 2 + 强 | `641:manual->629:manual` | 6, 17 | untested | single | medium | 25 |
| 8 | 3 + 强 → [4]646 + 强 | `641:manual->1240:manual` | 7 | untested | single | low | 25 |
| 9 | 3 + 强 → 4 + 强 | `641:manual->656:manual` | 8 | untested | single | medium | 25 |
| 10 | 强 → 2 + 弱 | `618:manual->621:manual` | 9 | untested | single | medium | 0 |
| 11 | 2 + 弱 → [4]646 + 强 | `621:manual->1240:manual` | 9, 11 | untested | single | low | -4 |
| 12 | 6 + 强 → 弱 | `668:manual->1215:manual` | 10 | untested | single | low | 0 |
| 13 | 弱 → [4]646 + 强 | `1215:manual->1240:manual` | 10 | untested | single | low | -5 |
| 14 | 6 + 强 → 2 + 弱 | `668:manual->621:manual` | 11 | untested | single | medium | 1 |
| 15 | 3 + 强 → 中 | `641:manual->1216:manual` | 12 | untested | single | low | 27 |
| 16 | 2 + 强 → [2] + SP + 强 | `629:manual->1240:simple` | 13, 17 | untested | single | low | -9 |
| 17 | 强 → [2] + SP + 强 | `618:manual->1240:simple` | 14 | untested | single | low | -5 |
| 18 | 4 + 强 → [2] + SP + 强 | `656:manual->1240:simple` | 15 | untested | single | low | -8 |
| 19 | 强 → [2] + SP + 强 | `1217:manual->1240:simple` | 16 | untested | single | low | -10 |
| 20 | 弱 → 强 | `1215:manual->1217:manual` | 18 | untested | single | low | -3 |
| 21 | 弱 → 2 + 强 | `1215:manual->629:manual` | 19 | untested | single | low | -5 |
| 22 | 2 + 弱 → 强 | `621:manual->1217:manual` | 20 | untested | single | low | -2 |

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

- reframework/data/ComboExplorer_data/worklist/guile-modern-plan-max-damage.json  (22 pairs, 12593 bytes)
- docs/ComboExplorer/plans/guile-modern-max-damage.md
