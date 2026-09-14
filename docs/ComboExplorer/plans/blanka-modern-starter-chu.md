# Route plan - Blanka / modern - starter-chu

Generated 2026-09-14T13:00:42Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

890 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 2182 (search complete: false)
  - the beam dropped 1597 partial routes and 0 routes were not emitted, so a route
    satisfying these conditions may be missing

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| starter_button | M | 2182 | 1026 | 1156 | 0 |

- routes satisfying every condition: 1156
- of those, through a pair the logs rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 中 → 236236 + 强 | MK → 236236+K | 4600 | 4600 | SA 1, drive >=0 (1 unknown) | 8.4 | low | 0/1 pairs verified |
| 2 | 2 | 4 + 中 → 236236 + 强 | 4+MK → 236236+K | 4600 | 4600 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs verified |
| 3 | 3 | 2 + 中 → 236236 + 强 | 2+MK → 236236+K | 4500 | 4500 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs verified |
| 4 | 4 | 4 + 中 → 中 → 236236 + 强 | 4+MK → MK → 236236+K | 4400 | 5200 | SA 1, drive >=0 (1 unknown) | 10.4 | low | 0/2 pairs verified |
| 5 | 5 | 4 + 中 → 2 + 中 → 236236 + 强 | 4+MK → 2+MK → 236236+K | 4300 | 5100 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs verified |
| 6 | 6 | 中 → 弱 → 236236 + 强 | MK → LP → 236236+K | 4100 | 4900 | SA 1, drive >=0 (1 unknown) | 9.9 | low | 0/2 pairs verified |
| 7 | 7 | 4 + 中 → 弱 → 236236 + 强 | 4+MK → LP → 236236+K | 4100 | 4900 | SA 1, drive >=0 (1 unknown) | 10.4 | low | 0/2 pairs verified |
| 8 | 8 | 4 + 中 → 2 + 弱 → 236236 + 强 | 4+MK → 2+LP → 236236+K | 4100 | 4900 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs verified |
| 9 | 9 | 2 + 中 → 弱 → 236236 + 强 | 2+MK → LP → 236236+K | 4000 | 4800 | SA 1, drive >=0 (1 unknown) | 10.4 | low | 0/2 pairs verified |
| 10 | 10 | 中 → 2 + SP + 强 | MK → 236236+K | 3800 | 4600 | SA 1, drive >=0 (1 unknown) | 6.0 | low | 0/1 pairs verified |
| 11 | 11 | 6 + 中 → 弱 → 236236 + 强 | 6+MK → LP → 236236+K | 3800 | 4600 | SA 1, drive >=0 (1 unknown) | 10.4 | low | 0/2 pairs verified |
| 12 | 12 | 6 + 中 → 2 + 弱 → 236236 + 强 | 6+MK → 2+LP → 236236+K | 3800 | 4600 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs verified |
| 13 | 13 | 4 + 中 → 2 + SP + 强 | 4+MK → 236236+K | 3800 | 4600 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs verified |
| 14 | 14 | 4 + 中 → 中 → 2 + SP + 强 | 4+MK → MK → 236236+K | 3760 | 5200 | SA 1, drive >=0 (1 unknown) | 8.0 | low | 0/2 pairs verified |
| 15 | 15 | 2 + 中 → 2 + SP + 强 | 2+MK → 236236+K | 3700 | 4500 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs verified |
| 16 | 16 | 4 + 中 → 2 + 中 → 2 + SP + 强 | 4+MK → 2+MK → 236236+K | 3660 | 5100 | SA 1, drive >=0 (1 unknown) | 8.5 | low | 0/2 pairs verified |
| 17 | 17 | 中 → 弱 → 2 + SP + 强 | MK → LP → 236236+K | 3460 | 4900 | SA 1, drive >=0 (1 unknown) | 7.5 | low | 0/2 pairs verified |
| 18 | 18 | 4 + 中 → 弱 → 2 + SP + 强 | 4+MK → LP → 236236+K | 3460 | 4900 | SA 1, drive >=0 (1 unknown) | 8.0 | low | 0/2 pairs verified |
| 19 | 19 | 4 + 中 → 2 + 弱 → 2 + SP + 强 | 4+MK → 2+LP → 236236+K | 3460 | 4900 | SA 1, drive >=0 (1 unknown) | 8.5 | low | 0/2 pairs verified |
| 20 | 20 | 2 + 中 → 弱 → 2 + SP + 强 | 2+MK → LP → 236236+K | 3360 | 4800 | SA 1, drive >=0 (1 unknown) | 8.0 | low | 0/2 pairs verified |

## Pairs to sweep: 18

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 565 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 中 → 236236 + 强 | `609:manual->1215:manual` | 1, 4 | untested | single | low | -5 |
| 2 | 4 + 中 → 236236 + 强 | `642:manual->1215:manual` | 2 | untested | single | low | -2 |
| 3 | 2 + 中 → 236236 + 强 | `625:manual->1215:manual` | 3, 5 | untested | single | low | -5 |
| 4 | 4 + 中 → 中 | `642:manual->609:manual` | 4, 14 | untested | single | medium | 0 |
| 5 | 4 + 中 → 2 + 中 | `642:manual->625:manual` | 5, 16 | untested | single | medium | 0 |
| 6 | 中 → 弱 | `609:manual->600:manual` | 6, 17 | untested | single | medium | 0 |
| 7 | 弱 → 236236 + 强 | `600:manual->1215:manual` | 6, 7, 9, 11 | untested | single | low | -7 |
| 8 | 4 + 中 → 弱 | `642:manual->600:manual` | 7, 18 | untested | single | high | 3 |
| 9 | 4 + 中 → 2 + 弱 | `642:manual->614:manual` | 8, 19 | untested | single | medium | 2 |
| 10 | 2 + 弱 → 236236 + 强 | `614:manual->1215:manual` | 8, 12 | untested | single | low | -5 |
| 11 | 2 + 中 → 弱 | `625:manual->600:manual` | 9, 20 | untested | single | medium | 0 |
| 12 | 中 → 2 + SP + 强 | `609:manual->1215:simple` | 10, 14 | untested | single | low | -5 |
| 13 | 6 + 中 → 弱 | `640:manual->600:manual` | 11 | untested | single | medium | 1 |
| 14 | 6 + 中 → 2 + 弱 | `640:manual->614:manual` | 12 | untested | single | medium | 0 |
| 15 | 4 + 中 → 2 + SP + 强 | `642:manual->1215:simple` | 13 | untested | single | low | -2 |
| 16 | 2 + 中 → 2 + SP + 强 | `625:manual->1215:simple` | 15, 16 | untested | single | low | -5 |
| 17 | 弱 → 2 + SP + 强 | `600:manual->1215:simple` | 17, 18, 20 | untested | single | low | -7 |
| 18 | 2 + 弱 → 2 + SP + 强 | `614:manual->1215:simple` | 19 | untested | single | low | -5 |

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

- reframework/data/ComboExplorer_data/worklist/blanka-modern-plan-starter-chu.json  (18 pairs, 10706 bytes)
- docs/ComboExplorer/plans/blanka-modern-starter-chu.md
