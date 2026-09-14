# Route plan - Juri / modern - starter-chu

Generated 2026-09-14T13:00:37Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

41 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 775 (search complete: false)
  - the beam dropped 15401 partial routes and 0 routes were not emitted, so a route
    satisfying these conditions may be missing

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| starter_button | M | 775 | 606 | 169 | 0 |

- routes satisfying every condition: 169
- of those, through a pair the logs rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 中 → 214214 + 强 | MP → 214214+K | 4600 | 4600 | SA 1, drive >=0 (1 unknown) | 8.4 | low | 0/1 pairs verified |
| 2 | 2 | 2 + 中 → 214214 + 强 | 2+MK → 214214+K | 4500 | 4500 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs verified |
| 3 | 3 | 中 → 2 + SP + 强 | MP → 214214+K | 3800 | 4600 | SA 1, drive >=0 (1 unknown) | 6.0 | low | 0/1 pairs verified |
| 4 | 4 | 2 + 中 → 2 + SP + 强 | 2+MK → 214214+K | 3700 | 4500 | SA 1, drive >=0 (1 unknown) | 6.5 | low | 0/1 pairs verified |
| 5 | 5 | 中 → 中 → 236236 + 弱 | MP → MP → 236236+K | 2640 | 3000 | SA 1, drive >=0 (1 unknown) | 9.9 | medium | 0/2 pairs verified |
| 6 | 6 | 中 → 236236 + 弱 | MP → 236236+K | 2400 | 2400 | SA 1, drive >=0 (1 unknown) | 8.4 | high | 0/1 pairs verified |
| 7 | 7 | 中 → 中 → SP + 强 | MP → MP → 236236+K | 2352 | 3000 | SA 1, drive >=0 (1 unknown) | 7.0 | medium | 0/2 pairs verified |
| 8 | 8 | 中 → 弱 → 236236 + 弱 | MP → LP → 236236+K | 2340 | 2700 | SA 1, drive >=0 (1 unknown) | 9.9 | high | 0/2 pairs verified |
| 9 | 9 | 中 → 2 + 弱 → 236236 + 弱 | MP → 2+LP → 236236+K | 2340 | 2700 | SA 1, drive >=0 (1 unknown) | 10.4 | high | 0/2 pairs verified |
| 10 | 10 | 2 + 中 → 236236 + 弱 | 2+MK → 236236+K | 2300 | 2300 | SA 1, drive >=0 (1 unknown) | 8.9 | high | 0/1 pairs verified |
| 11 | 11 | 中 → 弱 → SP + 强 | MP → LP → 236236+K | 2052 | 2700 | SA 1, drive >=0 (1 unknown) | 7.0 | high | 0/2 pairs verified |
| 12 | 12 | 中 → 2 + 弱 → SP + 强 | MP → 2+LP → 236236+K | 2052 | 2700 | SA 1, drive >=0 (1 unknown) | 7.5 | high | 0/2 pairs verified |
| 13 | 13 | 中 → SP + 强 | MP → 236236+K | 2040 | 2400 | SA 1, drive >=0 (1 unknown) | 5.5 | high | 0/1 pairs verified |
| 14 | 14 | 2 + 中 → SP + 强 | 2+MK → 236236+K | 1940 | 2300 | SA 1, drive >=0 (1 unknown) | 6.0 | high | 0/1 pairs verified |
| 15 | 15 | 中 → 中 → 236 + 弱 + 强 | MP → MP → 236+LK+HK | 1840 | 2000 | drive 20000 | 7.7 | medium | 0/2 pairs verified |
| 16 | 16 | 中 → 中 → 2 + AUTO + SP | MP → MP → 236+LK+HK | 1712 | 2000 | drive 20000 | 7.5 | medium | 0/2 pairs verified |
| 17 | 17 | 中 → 中 → 中 | MP → MP → MP | 1680 | 1800 | drive 0 | 4.5 | medium | 0/2 pairs verified |
| 18 | 18 | 中 → 中 → 214 + 弱 | MP → MP → 214+LK | 1680 | 1800 | drive 0 | 7.2 | medium | 0/2 pairs verified |
| 19 | 19 | 中 → 中 → 214 + 中 | MP → MP → 214+MK | 1680 | 1800 | drive 0 | 7.2 | medium | 0/2 pairs verified |
| 20 | 20 | 中 → 中 → 236 + 中 | MP → MP → 236+MK | 1680 | 1800 | drive 0 | 7.2 | medium | 0/2 pairs verified |

## Pairs to sweep: 23

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 2388 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 中 → 214214 + 强 | `603:manual->1221:manual` | 1 | untested | single | low | -3 |
| 2 | 2 + 中 → 214214 + 强 | `634:manual->1221:manual` | 2 | untested | single | low | -9 |
| 3 | 中 → 2 + SP + 强 | `603:manual->1221:simple` | 3 | untested | single | low | -3 |
| 4 | 2 + 中 → 2 + SP + 强 | `634:manual->1221:simple` | 4 | untested | single | low | -9 |
| 5 | 中 → 中 | `603:manual->606:manual` | 5, 7, 15, 16, 17, 18, 19, 20 | untested | single | medium | 1 |
| 6 | 中 → 236236 + 弱 | `606:manual->1200:manual` | 5 | untested | single | high | 0 |
| 7 | 中 → 236236 + 弱 | `603:manual->1200:manual` | 6 | untested | single | high | 0 |
| 8 | 中 → SP + 强 | `606:manual->1200:simple` | 7 | untested | single | high | 0 |
| 9 | 中 → 弱 | `603:manual->602:manual` | 8, 11 | untested | single | high | 3 |
| 10 | 弱 → 236236 + 弱 | `602:manual->1200:manual` | 8 | untested | single | high | -2 |
| 11 | 中 → 2 + 弱 | `603:manual->618:manual` | 9, 12 | untested | single | high | 3 |
| 12 | 2 + 弱 → 236236 + 弱 | `618:manual->1200:manual` | 9 | untested | single | high | -3 |
| 13 | 2 + 中 → 236236 + 弱 | `634:manual->1200:manual` | 10 | untested | single | high | -6 |
| 14 | 弱 → SP + 强 | `602:manual->1200:simple` | 11 | untested | single | high | -2 |
| 15 | 2 + 弱 → SP + 强 | `618:manual->1200:simple` | 12 | untested | single | high | -3 |
| 16 | 中 → SP + 强 | `603:manual->1200:simple` | 13 | untested | single | high | 0 |
| 17 | 2 + 中 → SP + 强 | `634:manual->1200:simple` | 14 | untested | single | high | -6 |
| 18 | 中 → 236 + 弱 + 强 | `606:manual->932:manual` | 15 | untested | single | high | -17 |
| 19 | 中 → 2 + AUTO + SP | `606:manual->932:simple` | 16 | untested | single | high | -17 |
| 20 | 中 → 中 | `606:manual->603:manual` | 17 | untested | single | medium | 1 |
| 21 | 中 → 214 + 弱 | `606:manual->900:manual` | 18 | untested | single | high | -3 |
| 22 | 中 → 214 + 中 | `606:manual->904:manual` | 19 | untested | single | high | -6 |
| 23 | 中 → 236 + 中 | `606:manual->931:manual` | 20 | untested | single | high | -17 |

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

- reframework/data/ComboExplorer_data/worklist/juri-modern-plan-starter-chu.json  (23 pairs, 13050 bytes)
- docs/ComboExplorer/plans/juri-modern-starter-chu.md
