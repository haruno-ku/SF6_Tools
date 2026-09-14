# Route plan - Kimberly / modern - starter-chu

Generated 2026-09-14T12:58:56Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

43 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 912 (search complete: true)

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| starter_button | M | 912 | 799 | 113 | 0 |

- routes satisfying every condition: 113
- of those, through a pair the logs rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 中 → 236236 + 强 | MP → 236236+P | 4540 | 4540 | SA 1, drive >=0 (1 unknown) | 8.4 | low | 0/1 pairs verified |
| 2 | 2 | 2 + 中 → 弱 → 236236 + 强 | 2+MK → LP → 236236+P | 4010 | 4810 | SA 1, drive >=0 (1 unknown) | 10.4 | low | 0/2 pairs verified |
| 3 | 3 | 2 + 中 → 2 + 弱 → 236236 + 强 | 2+MK → 2+LP → 236236+P | 4010 | 4810 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs verified |
| 4 | 4 | 中 → 2 + SP + 强 | MP → 236236+P | 3740 | 4540 | SA 1, drive >=0 (1 unknown) | 6.0 | low | 0/1 pairs verified |
| 5 | 5 | 2 + 中 → 弱 → 2 + SP + 强 | 2+MK → LP → 236236+P | 3370 | 4810 | SA 1, drive >=0 (1 unknown) | 8.0 | low | 0/2 pairs verified |
| 6 | 6 | 2 + 中 → 2 + 弱 → 2 + SP + 强 | 2+MK → 2+LP → 236236+P | 3370 | 4810 | SA 1, drive >=0 (1 unknown) | 8.5 | low | 0/2 pairs verified |
| 7 | 7 | 中 → 214214 + 中 | MP → 214214+P | 3340 | 3340 | SA 1, drive >=0 (1 unknown) | 8.4 | high | 0/1 pairs verified |
| 8 | 8 | 2 + 中 → 弱 → 214214 + 中 | 2+MK → LP → 214214+P | 3050 | 3610 | SA 1, drive >=0 (1 unknown) | 10.4 | medium | 0/2 pairs verified |
| 9 | 9 | 2 + 中 → 2 + 弱 → 214214 + 中 | 2+MK → 2+LP → 214214+P | 3050 | 3610 | SA 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs verified |
| 10 | 10 | 中 → 4 + SP + 强 | MP → 214214+P | 2780 | 3340 | SA 1, drive >=0 (1 unknown) | 6.0 | high | 0/1 pairs verified |
| 11 | 11 | 2 + 中 → 弱 → 4 + SP + 强 | 2+MK → LP → 214214+P | 2602 | 3610 | SA 1, drive >=0 (1 unknown) | 8.0 | medium | 0/2 pairs verified |
| 12 | 12 | 2 + 中 → 2 + 弱 → 4 + SP + 强 | 2+MK → 2+LP → 214214+P | 2602 | 3610 | SA 1, drive >=0 (1 unknown) | 8.5 | medium | 0/2 pairs verified |
| 13 | 13 | 中 → 236236 + 弱 | MP → 236236+K | 2340 | 2340 | SA 1, drive >=0 (1 unknown) | 8.4 | high | 0/1 pairs verified |
| 14 | 14 | 2 + 中 → 弱 → 236236 + 弱 | 2+MK → LP → 236236+K | 2250 | 2610 | SA 1, drive >=0 (1 unknown) | 10.4 | medium | 0/2 pairs verified |
| 15 | 15 | 2 + 中 → 2 + 弱 → 236236 + 弱 | 2+MK → 2+LP → 236236+K | 2250 | 2610 | SA 1, drive >=0 (1 unknown) | 10.9 | medium | 0/2 pairs verified |
| 16 | 16 | 中 → SP + 强 | MP → 236236+K | 1980 | 2340 | SA 1, drive >=0 (1 unknown) | 5.5 | high | 0/1 pairs verified |
| 17 | 17 | 2 + 中 → 弱 → SP + 强 | 2+MK → LP → 236236+K | 1962 | 2610 | SA 1, drive >=0 (1 unknown) | 7.5 | medium | 0/2 pairs verified |
| 18 | 18 | 2 + 中 → 2 + 弱 → SP + 强 | 2+MK → 2+LP → 236236+K | 1962 | 2610 | SA 1, drive >=0 (1 unknown) | 8.0 | medium | 0/2 pairs verified |
| 19 | 19 | 2 + 中 → 弱 → 3 + 强 | 2+MK → LP → 2+HK | 1458 | 1620 | drive 0 | 5.5 | medium | 0/2 pairs verified |
| 20 | 20 | 2 + 中 → 弱 → 236 + 弱 | 2+MK → LP → 236+LP | 1458 | 1620 | drive 0 | 7.7 | medium | 0/2 pairs verified |

## Pairs to sweep: 22

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 503 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 中 → 236236 + 强 | `603:manual->1220:manual` | 1 | untested | single | low | -5 |
| 2 | 2 + 中 → 弱 | `619:manual->600:manual` | 2, 5, 8, 11, 14, 17, 19, 20 | untested | single | medium | 0 |
| 3 | 弱 → 236236 + 强 | `600:manual->1220:manual` | 2 | untested | single | low | -3 |
| 4 | 2 + 中 → 2 + 弱 | `619:manual->610:manual` | 3, 6, 9, 12, 15, 18 | untested | single | medium | 1 |
| 5 | 2 + 弱 → 236236 + 强 | `610:manual->1220:manual` | 3 | untested | single | low | -4 |
| 6 | 中 → 2 + SP + 强 | `603:manual->1220:simple` | 4 | untested | single | low | -5 |
| 7 | 弱 → 2 + SP + 强 | `600:manual->1220:simple` | 5 | untested | single | low | -3 |
| 8 | 2 + 弱 → 2 + SP + 强 | `610:manual->1220:simple` | 6 | untested | single | low | -4 |
| 9 | 中 → 214214 + 中 | `603:manual->1209:manual` | 7 | untested | single | high | -10 |
| 10 | 弱 → 214214 + 中 | `600:manual->1209:manual` | 8 | untested | single | high | -8 |
| 11 | 2 + 弱 → 214214 + 中 | `610:manual->1209:manual` | 9 | untested | single | high | -9 |
| 12 | 中 → 4 + SP + 强 | `603:manual->1209:simple` | 10 | untested | single | high | -10 |
| 13 | 弱 → 4 + SP + 强 | `600:manual->1209:simple` | 11 | untested | single | high | -8 |
| 14 | 2 + 弱 → 4 + SP + 强 | `610:manual->1209:simple` | 12 | untested | single | high | -9 |
| 15 | 中 → 236236 + 弱 | `603:manual->1200:manual` | 13 | untested | single | high | -7 |
| 16 | 弱 → 236236 + 弱 | `600:manual->1200:manual` | 14 | untested | single | high | -5 |
| 17 | 2 + 弱 → 236236 + 弱 | `610:manual->1200:manual` | 15 | untested | single | high | -6 |
| 18 | 中 → SP + 强 | `603:manual->1200:simple` | 16 | untested | single | high | -7 |
| 19 | 弱 → SP + 强 | `600:manual->1200:simple` | 17 | untested | single | high | -5 |
| 20 | 2 + 弱 → SP + 强 | `610:manual->1200:simple` | 18 | untested | single | high | -6 |
| 21 | 弱 → 3 + 强 | `600:manual->620:manual` | 19 | untested | single | medium | -3 |
| 22 | 弱 → 236 + 弱 | `600:manual->957:manual` | 20 | untested | single | high | -5 |

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

- reframework/data/ComboExplorer_data/worklist/kimberly-modern-plan-starter-chu.json  (22 pairs, 12636 bytes)
- docs/ComboExplorer/plans/kimberly-modern-starter-chu.md
