# Route plan - Marisa / modern - max-damage

Generated 2026-09-14T13:00:41Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

108 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 803 (search complete: true)

- routes satisfying every condition: 803
- of those, through a pair the logs rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 2 + 强 → 3 + 强 → 236236 + 强 | 2+HP → 2+HK → 236236+K | 5100 | 5900 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs verified |
| 2 | 2 | 3 + 强 → 2 + 强 → 236236 + 强 | 2+HK → 2+HP → 236236+K | 5100 | 5900 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs verified |
| 3 | 3 | 3 + 强 → 6 + 强 → 236236 + 强 | 2+HK → 6+HK → 236236+K | 5100 | 5900 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs verified |
| 4 | 4 | 3 + 强 → 4 + 强 → 236236 + 强 | 2+HK → 4+HP → 236236+K | 5100 | 5900 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs verified |
| 5 | 5 | 2 + 强 → 6 + 强 → 236236 + 强 | 2+HP → 6+HK → 236236+K | 5000 | 5800 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs verified |
| 6 | 6 | 2 + 强 → 4 + 强 → 236236 + 强 | 2+HP → 4+HP → 236236+K | 5000 | 5800 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs verified |
| 7 | 7 | 3 + 强 → 236236 + 强 | 2+HK → 236236+K | 5000 | 5000 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs verified |
| 8 | 8 | 2 + 强 → 236236 + 强 | 2+HP → 236236+K | 4900 | 4900 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs verified |
| 9 | 9 | 3 + 强 → 2 + 中 → 236236 + 强 | 2+HK → 2+MP → 236236+K | 4900 | 5700 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs verified |
| 10 | 10 | 6 + 强 → 236236 + 强 | 6+HK → 236236+K | 4900 | 4900 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs verified |
| 11 | 11 | 4 + 强 → 236236 + 强 | 4+HP → 236236+K | 4900 | 4900 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs verified |
| 12 | 12 | 2 + 强 → 2 + 中 → 236236 + 强 | 2+HP → 2+MP → 236236+K | 4800 | 5600 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs verified |
| 13 | 13 | 2 + 中 → 236236 + 强 | 2+MP → 236236+K | 4700 | 4700 | SA 1, drive >=0 (1 unknown) | 8.9 | low | 0/1 pairs verified |
| 14 | 14 | 3 + 强 → 2 + 弱 → 236236 + 强 | 2+HK → 2+LP → 236236+K | 4500 | 5300 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs verified |
| 15 | 15 | 2 + 强 → 3 + 强 → 2 + SP + 强 | 2+HP → 2+HK → 236236+K | 4460 | 5900 | SA 1, drive >=0 (1 unknown) | 8.5 | low | 0/2 pairs verified |
| 16 | 16 | 3 + 强 → 2 + 强 → 2 + SP + 强 | 2+HK → 2+HP → 236236+K | 4460 | 5900 | SA 1, drive >=0 (1 unknown) | 8.5 | low | 0/2 pairs verified |
| 17 | 17 | 3 + 强 → 6 + 强 → 2 + SP + 强 | 2+HK → 6+HK → 236236+K | 4460 | 5900 | SA 1, drive >=0 (1 unknown) | 8.5 | low | 0/2 pairs verified |
| 18 | 18 | 3 + 强 → 4 + 强 → 2 + SP + 强 | 2+HK → 4+HP → 236236+K | 4460 | 5900 | SA 1, drive >=0 (1 unknown) | 8.5 | low | 0/2 pairs verified |
| 19 | 19 | 2 + 强 → 2 + 弱 → 236236 + 强 | 2+HP → 2+LP → 236236+K | 4400 | 5200 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs verified |
| 20 | 20 | 6 + 强 → 2 + 弱 → 236236 + 强 | 6+HK → 2+LP → 236236+K | 4400 | 5200 | SA 1, drive >=0 (1 unknown) | 10.9 | low | 0/2 pairs verified |

## Pairs to sweep: 21

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 313 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 2 + 强 → 3 + 强 | `627:manual->639:manual` | 1, 15 | untested | single | medium | 24 |
| 2 | 3 + 强 → 236236 + 强 | `639:manual->1213:manual` | 1, 7 | untested | single | low | 16 |
| 3 | 3 + 强 → 2 + 强 | `639:manual->627:manual` | 2, 16 | untested | single | medium | 20 |
| 4 | 2 + 强 → 236236 + 强 | `627:manual->1213:manual` | 2, 8 | untested | single | low | 22 |
| 5 | 3 + 强 → 6 + 强 | `639:manual->671:manual` | 3, 17 | untested | single | medium | 15 |
| 6 | 6 + 强 → 236236 + 强 | `671:manual->1213:manual` | 3, 5, 10 | untested | single | low | -9 |
| 7 | 3 + 强 → 4 + 强 | `639:manual->686:manual` | 4, 18 | untested | single | medium | 21 |
| 8 | 4 + 强 → 236236 + 强 | `686:manual->1213:manual` | 4, 6, 11 | untested | single | low | -10 |
| 9 | 2 + 强 → 6 + 强 | `627:manual->671:manual` | 5 | untested | single | medium | 21 |
| 10 | 2 + 强 → 4 + 强 | `627:manual->686:manual` | 6 | untested | single | medium | 27 |
| 11 | 3 + 强 → 2 + 中 | `639:manual->625:manual` | 9 | untested | single | medium | 21 |
| 12 | 2 + 中 → 236236 + 强 | `625:manual->1213:manual` | 9, 12, 13 | untested | single | low | -10 |
| 13 | 2 + 强 → 2 + 中 | `627:manual->625:manual` | 12 | untested | single | medium | 27 |
| 14 | 3 + 强 → 2 + 弱 | `639:manual->621:manual` | 14 | untested | single | medium | 25 |
| 15 | 2 + 弱 → 236236 + 强 | `621:manual->1213:manual` | 14, 19, 20 | untested | single | low | -9 |
| 16 | 3 + 强 → 2 + SP + 强 | `639:manual->1213:simple` | 15 | untested | single | low | 16 |
| 17 | 2 + 强 → 2 + SP + 强 | `627:manual->1213:simple` | 16 | untested | single | low | 22 |
| 18 | 6 + 强 → 2 + SP + 强 | `671:manual->1213:simple` | 17 | untested | single | low | -9 |
| 19 | 4 + 强 → 2 + SP + 强 | `686:manual->1213:simple` | 18 | untested | single | low | -10 |
| 20 | 2 + 强 → 2 + 弱 | `627:manual->621:manual` | 19 | untested | single | medium | 31 |
| 21 | 6 + 强 → 2 + 弱 | `671:manual->621:manual` | 20 | untested | single | medium | 0 |

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

- reframework/data/ComboExplorer_data/worklist/marisa-modern-plan-max-damage.json  (21 pairs, 11871 bytes)
- docs/ComboExplorer/plans/marisa-modern-max-damage.md
