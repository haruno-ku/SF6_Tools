# Route plan - Lily / modern - starter-chu

Generated 2026-09-14T13:00:08Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

EVERY ROUTE HERE IS A THEORETICAL CANDIDATE. The ranking is a prediction from
the frame data. The worklist below is the smallest set of pairs that lets the
game say whether these routes connect.

## Conditions

- `starter_button` = `M`
- sort: `scaled_damage`, top 20
- search: explore.lua's settings (normal,command_normal -> normal,command_normal,special,od_special,super, manual -> manual,simple, max 3 moves, beam 4000, collapse true)
- Drive Rush Cancel edges in the search: no (pass --drive-rush to route through them)
- demote routes through a rejected pair: yes

`starter_button` keeps a route whose first move has that button with ANY direction
(中 keeps 中, 2 + 中, 3 + 中, 6 + 中). `--starter-neutral` narrows it to no direction.

## Damage figure

Ordered on `offline_score.predicted_damage_scaled`, the combo-scaled prediction.

2 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 848 (search complete: false)
  - the beam dropped 562 partial routes and 0 routes were not emitted, so a route
    satisfying these conditions may be missing

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| starter_button | M | 848 | 840 | 8 | 0 |

- routes satisfying every condition: 8
- of those, through a pair the logs rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 8

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 2 + 中 → 214214 + 强 | 2+MP → 214214+P | 5200 | 5200 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs verified |
| 2 | 2 | 2 + 中 → 2 + SP + 强 | 2+MP → 214214+P | 4300 | 5200 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs verified |
| 3 | 3 | 2 + 中 → 236236 + 中 | 2+MP → 236236+K | 3300 | 3300 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs verified |
| 4 | 4 | 2 + 中 → 236236 + 弱 | 2+MP → 236236+P | 2900 | 2900 | SA 1, drive >=0 (1 unknown) | 8.9 | high | 0/1 pairs verified |
| 5 | 5 | 2 + 中 → 4 + SP + 强 | 2+MP → 236236+K | 2780 | 3300 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs verified |
| 6 | 6 | 2 + 中 → SP + 强 | 2+MP → 236236+P | 2460 | 2900 | SA 1, drive >=0 (1 unknown) | 6.0 | high | 0/1 pairs verified |
| 7 | 7 | 中 → > 空中 中 | MP → >j.MP | - | 800 (incomplete) | drive >=0 (1 unknown) | 3.0 | low | 0/1 pairs verified |
| 8 | 8 | 2 + 中 → > 空中 中 | 2+MP → >j.MP | - | 700 (incomplete) | drive >=0 (1 unknown) | 3.5 | low | 0/1 pairs verified |

## Pairs to sweep: 8

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 635 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 2 + 中 → 214214 + 强 | `620:manual->1216:manual` | 1 | untested | single | low | -4 |
| 2 | 2 + 中 → 2 + SP + 强 | `620:manual->1216:simple` | 2 | untested | single | low | -4 |
| 3 | 2 + 中 → 236236 + 中 | `620:manual->1206:manual` | 3 | untested | single | low | -8 |
| 4 | 2 + 中 → 236236 + 弱 | `620:manual->1200:manual` | 4 | untested | single | high | -9 |
| 5 | 2 + 中 → 4 + SP + 强 | `620:manual->1206:simple` | 5 | untested | single | low | -8 |
| 6 | 2 + 中 → SP + 强 | `620:manual->1200:simple` | 6 | untested | single | high | -9 |
| 7 | 中 → > 空中 中 | `604:manual->636:manual` | 7 | untested | followup | low | - |
| 8 | 2 + 中 → > 空中 中 | `620:manual->636:manual` | 8 | untested | followup | low | - |

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
reframework/data), then pick `plan: starter-chu` in the SWEEP panel's worklist list
(REFRESH if the panel was already open) and START SWEEP. It writes to the same
trial log as the full sweep, so pairs the full sweep already answered under the
same calibration and conditions are skipped, and the other way round.

## Written

- reframework/data/ComboExplorer_data/worklist/lily-modern-plan-starter-chu.json  (8 pairs, 5605 bytes)
- docs/ComboExplorer/plans/lily-modern-starter-chu.md
