# Route plan - ChunLi / modern - starter-chu

Generated 2026-09-14T12:58:59Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 1157 (search complete: false)
  - the beam dropped 1991 partial routes and 0 routes were not emitted, so a route
    satisfying these conditions may be missing

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| starter_button | M | 1157 | 923 | 234 | 0 |

- routes satisfying every condition: 234
- of those, through a pair the logs rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 中 → 214214 + 强 | MP → 214214+K | 4600 | 4600 | SA 1, drive >=0 (1 unknown) | 8.4 | low | 0/1 pairs verified |
| 2 | 2 | 6 或 4 + 中 → 214214 + 强 | 6+MP → 214214+K | 4600 | 4600 | SA 1, drive >=0 (1 unknown) | 10.2 | low | 0/1 pairs verified |
| 3 | 3 | 2 + 中 → 214214 + 强 | 2+MK → 214214+K | 4500 | 4500 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs verified |
| 4 | 4 | 中 → 2 + SP + 强 | MP → 214214+K | 3800 | 4600 | SA 1, drive >=0 (1 unknown) | 6.0 | low | 0/1 pairs verified |
| 5 | 5 | 6 或 4 + 中 → 2 + SP + 强 | 6+MP → 214214+K | 3800 | 4600 | SA 1, drive >=0 (1 unknown) | 7.8 | low | 0/1 pairs verified |
| 6 | 6 | 2 + 中 → 2 + SP + 强 | 2+MK → 214214+K | 3700 | 4500 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs verified |
| 7 | 7 | 中 → 中 → 236236 + 中 | MP → MP → 236236+K | 2800 | 3200 | SA 1, drive >=0 (1 unknown) | 9.9 | medium | 0/2 pairs verified |
| 8 | 8 | 中 → 236236 + 中 | MP → 236236+K | 2600 | 2600 | SA 1, drive >=0 (1 unknown) | 8.4 | high | 0/1 pairs verified |
| 9 | 9 | 6 或 4 + 中 → 236236 + 中 | 6+MP → 236236+K | 2600 | 2600 | SA 1, drive >=0 (1 unknown) | 10.2 | high | 0/1 pairs verified |
| 10 | 10 | 中 → 弱 → 236236 + 中 | MP → LP → 236236+K | 2500 | 2900 | SA 1, drive >=0 (1 unknown) | 9.9 | medium | 0/2 pairs verified |
| 11 | 11 | 中 → 2 + 弱 → 236236 + 中 | MP → 2+LP → 236236+K | 2500 | 2900 | SA 1, drive >=0 (1 unknown) | 10.4 | medium | 0/2 pairs verified |
| 12 | 12 | 2 + 中 → 236236 + 中 | 2+MK → 236236+K | 2500 | 2500 | SA 1, drive >=0 (1 unknown) | 8.9 | high | 0/1 pairs verified |
| 13 | 13 | 中 → 中 → 4 + SP + 强 | MP → MP → 236236+K | 2480 | 3200 | SA 1, drive >=0 (1 unknown) | 7.5 | medium | 0/2 pairs verified |
| 14 | 14 | 2 + 中 → 弱 → 236236 + 中 | MK → LP → 236236+K | 2400 | 2800 | SA 1, drive >=0 (1 unknown) | 10.4 | medium | 0/2 pairs verified |
| 15 | 15 | 2 + 中 → 2 + 弱 → 236236 + 中 | MK → 2+LP → 236236+K | 2400 | 2800 | SA 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs verified |
| 16 | 16 | 中 → 4 + SP + 强 | MP → 236236+K | 2200 | 2600 | SA 1, drive >=0 (1 unknown) | 6.0 | high | 0/1 pairs verified |
| 17 | 17 | 6 或 4 + 中 → 4 + SP + 强 | 6+MP → 236236+K | 2200 | 2600 | SA 1, drive >=0 (1 unknown) | 7.8 | high | 0/1 pairs verified |
| 18 | 18 | 中 → 弱 → 4 + SP + 强 | MP → LP → 236236+K | 2180 | 2900 | SA 1, drive >=0 (1 unknown) | 7.5 | medium | 0/2 pairs verified |
| 19 | 19 | 中 → 2 + 弱 → 4 + SP + 强 | MP → 2+LP → 236236+K | 2180 | 2900 | SA 1, drive >=0 (1 unknown) | 8.0 | medium | 0/2 pairs verified |
| 20 | 20 | 2 + 中 → 4 + SP + 强 | 2+MK → 236236+K | 2100 | 2500 | SA 1, drive >=0 (1 unknown) | 6.5 | high | 0/1 pairs verified |

## Pairs to sweep: 23

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 619 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 中 → 214214 + 强 | `601:manual->1218:manual` | 1 | untested | single | low | -2 |
| 2 | 6 或 4 + 中 → 214214 + 强 | `625:manual->1218:manual` | 2 | untested | single | low | -6 |
| 3 | 2 + 中 → 214214 + 强 | `613:manual->1218:manual` | 3 | untested | single | low | -10 |
| 4 | 中 → 2 + SP + 强 | `601:manual->1218:simple` | 4 | untested | single | low | -2 |
| 5 | 6 或 4 + 中 → 2 + SP + 强 | `625:manual->1218:simple` | 5 | untested | single | low | -6 |
| 6 | 2 + 中 → 2 + SP + 强 | `613:manual->1218:simple` | 6 | untested | single | low | -10 |
| 7 | 中 → 中 | `601:manual->664:manual` | 7, 13 | untested | single | medium | 1 |
| 8 | 中 → 236236 + 中 | `664:manual->1215:manual` | 7 | untested | single | high | -5 |
| 9 | 中 → 236236 + 中 | `601:manual->1215:manual` | 8 | untested | single | high | -5 |
| 10 | 6 或 4 + 中 → 236236 + 中 | `625:manual->1215:manual` | 9 | untested | single | high | -9 |
| 11 | 中 → 弱 | `601:manual->600:manual` | 10, 18 | untested | single | medium | 2 |
| 12 | 弱 → 236236 + 中 | `600:manual->1215:manual` | 10, 14 | untested | single | high | -6 |
| 13 | 中 → 2 + 弱 | `601:manual->637:manual` | 11, 19 | untested | single | medium | 2 |
| 14 | 2 + 弱 → 236236 + 中 | `637:manual->1215:manual` | 11, 15 | untested | single | high | -7 |
| 15 | 2 + 中 → 236236 + 中 | `613:manual->1215:manual` | 12 | untested | single | high | -13 |
| 16 | 中 → 4 + SP + 强 | `664:manual->1215:simple` | 13 | untested | single | high | -5 |
| 17 | 2 + 中 → 弱 | `668:manual->600:manual` | 14 | untested | single | medium | 0 |
| 18 | 2 + 中 → 2 + 弱 | `668:manual->637:manual` | 15 | untested | single | medium | 0 |
| 19 | 中 → 4 + SP + 强 | `601:manual->1215:simple` | 16 | untested | single | high | -5 |
| 20 | 6 或 4 + 中 → 4 + SP + 强 | `625:manual->1215:simple` | 17 | untested | single | high | -9 |
| 21 | 弱 → 4 + SP + 强 | `600:manual->1215:simple` | 18 | untested | single | high | -6 |
| 22 | 2 + 弱 → 4 + SP + 强 | `637:manual->1215:simple` | 19 | untested | single | high | -7 |
| 23 | 2 + 中 → 4 + SP + 强 | `613:manual->1215:simple` | 20 | untested | single | high | -13 |

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

- reframework/data/ComboExplorer_data/worklist/chunli-modern-plan-starter-chu.json  (23 pairs, 13100 bytes)
- docs/ComboExplorer/plans/chunli-modern-starter-chu.md
