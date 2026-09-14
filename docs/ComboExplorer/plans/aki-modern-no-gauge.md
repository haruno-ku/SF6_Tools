# Route plan - AKI / modern - no-gauge

Generated 2026-09-14T13:00:22Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

EVERY ROUTE HERE IS A THEORETICAL CANDIDATE. The ranking is a prediction from
the frame data. The worklist below is the smallest set of pairs that lets the
game say whether these routes connect.

## Conditions

- `no_gauge` = `true`
- sort: `scaled_damage`, top 20
- search: explore.lua's settings (normal,command_normal -> normal,command_normal,special,od_special,super, manual -> manual,simple, max 3 moves, beam 4000, collapse true)
- Drive Rush Cancel edges in the search: no (pass --drive-rush to route through them)
- demote routes through a rejected pair: yes

`no_gauge` removes a route with an OD move, a super, a Drive Rush Cancel, or any
KNOWN Drive or Super spend. A route where some move has no Drive figure is kept and
flagged: nothing in the source says it spends, and a missing value never excludes.

## Damage figure

Ordered on `offline_score.predicted_damage_scaled`, the combo-scaled prediction.

194 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 657 (search complete: true)

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| no_gauge | true | 657 | 242 | 415 | 194 |

- routes satisfying every condition: 415
- of those, through a pair the logs rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 3 + 强 → 2 + 弱 → 3 + 强 | 2+HP → 2+LP → 2+HP | 1920 | 2100 | drive 0 | 6.0 | medium | 0/2 pairs verified |
| 2 | 2 | 3 + 强 → 2 + 弱 → 2 + 强 | 2+HP → 2+LP → 2+HK | 1920 | 2100 | drive 0 | 6.0 | medium | 0/2 pairs verified |
| 3 | 3 | 3 + 强 → 中 → 弱 | 2+HP → MK → LP | 1840 | 1900 | drive 0 | 5.0 | medium | 0/2 pairs verified |
| 4 | 4 | 3 + 强 → 中 → 2 + 弱 | 2+HP → MK → 2+LP | 1840 | 1900 | drive 0 | 5.5 | medium | 0/2 pairs verified |
| 5 | 5 | 3 + 强 → 2 + 弱 → 强 | 2+HP → 2+LP → HP | 1840 | 2000 | drive 0 | 5.5 | medium | 0/2 pairs verified |
| 6 | 6 | 3 + 强 → 2 + 强 | 2+HP → 2+HK | 1800 | 1800 | drive 0 | 4.0 | medium | 0/1 pairs verified |
| 7 | 7 | 3 + 强 → 弱 → 236 + 强 | 2+HP → LP → 236+HP | 1760 | 1900 | drive 0 | 7.7 | medium | 0/2 pairs verified |
| 8 | 8 | 3 + 强 → 2 + 弱 → 中 | 2+HP → 2+LP → MK | 1760 | 1900 | drive 0 | 5.5 | medium | 0/2 pairs verified |
| 9 | 9 | 3 + 强 → 2 + 弱 → 236 + 强 | 2+HP → 2+LP → 236+HP | 1760 | 1900 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 10 | 10 | 3 + 强 → 2 + 中 → 弱 | 2+HP → 2+MK → LP | 1740 | 1800 | drive 0 | 5.5 | medium | 0/2 pairs verified |
| 11 | 11 | 3 + 强 → 2 + 中 → 2 + 弱 | 2+HP → 2+MK → 2+LP | 1740 | 1800 | drive 0 | 6.0 | medium | 0/2 pairs verified |
| 12 | 12 | 中 → 2 + 弱 → 3 + 强 | MK → 2+LP → 2+HP | 1720 | 1900 | drive 0 | 5.5 | medium | 0/2 pairs verified |
| 13 | 13 | 中 → 2 + 弱 → 2 + 强 | MK → 2+LP → 2+HK | 1720 | 1900 | drive 0 | 5.5 | medium | 0/2 pairs verified |
| 14 | 14 | 3 + 强 → 强 | 2+HP → HP | 1700 | 1700 | drive 0 | 3.5 | medium | 0/1 pairs verified |
| 15 | 15 | 3 + 强 → 弱 → 236 + 中 | 2+HP → LP → 236+MP | 1680 | 1800 | drive 0 | 7.7 | medium | 0/2 pairs verified |
| 16 | 16 | 3 + 强 → 2 + 弱 → 2 + 中 | 2+HP → 2+LP → 2+MK | 1680 | 1800 | drive 0 | 6.0 | medium | 0/2 pairs verified |
| 17 | 17 | 3 + 强 → 2 + 弱 → 3 + 中 | 2+HP → 2+LP → 3+MP | 1680 | 1800 | drive 0 | 6.0 | medium | 0/2 pairs verified |
| 18 | 18 | 3 + 强 → 2 + 弱 → 236 + 中 | 2+HP → 2+LP → 236+MP | 1680 | 1800 | drive 0 | 8.2 | medium | 0/2 pairs verified |
| 19 | 19 | 2 + 弱 → 3 + 强 → 2 + 强 | 2+LP → 2+HP → 2+HK | 1650 | 2100 | drive 0 | 6.0 | medium | 0/2 pairs verified |
| 20 | 20 | 中 → 2 + 弱 → 强 | MK → 2+LP → HP | 1640 | 1800 | drive 0 | 5.0 | medium | 0/2 pairs verified |

## Pairs to sweep: 20

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 330 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 3 + 强 → 2 + 弱 | `626:manual->618:manual` | 1, 2, 5, 8, 9, 16, 17, 18 | untested | single | medium | 23 |
| 2 | 2 + 弱 → 3 + 强 | `618:manual->626:manual` | 1, 12, 19 | untested | single | medium | -6 |
| 3 | 2 + 弱 → 2 + 强 | `618:manual->637:manual` | 2, 13 | untested | single | medium | -6 |
| 4 | 3 + 强 → 中 | `626:manual->612:manual` | 3, 4 | untested | single | medium | 19 |
| 5 | 中 → 弱 | `612:manual->600:manual` | 3 | untested | single | medium | 1 |
| 6 | 中 → 2 + 弱 | `612:manual->618:manual` | 4, 12, 13, 20 | untested | single | medium | 2 |
| 7 | 2 + 弱 → 强 | `618:manual->606:manual` | 5, 20 | untested | single | medium | -8 |
| 8 | 3 + 强 → 2 + 强 | `626:manual->637:manual` | 6, 19 | untested | single | medium | 17 |
| 9 | 3 + 强 → 弱 | `626:manual->600:manual` | 7, 15 | untested | single | medium | 22 |
| 10 | 弱 → 236 + 强 | `600:manual->929:manual` | 7 | untested | single | high | -7 |
| 11 | 2 + 弱 → 中 | `618:manual->612:manual` | 8 | untested | single | medium | -4 |
| 12 | 2 + 弱 → 236 + 强 | `618:manual->929:manual` | 9 | untested | single | high | -7 |
| 13 | 3 + 强 → 2 + 中 | `626:manual->634:manual` | 10, 11 | untested | single | medium | 20 |
| 14 | 2 + 中 → 弱 | `634:manual->600:manual` | 10 | untested | single | medium | 0 |
| 15 | 2 + 中 → 2 + 弱 | `634:manual->618:manual` | 11 | untested | single | medium | 1 |
| 16 | 3 + 强 → 强 | `626:manual->606:manual` | 14 | untested | single | medium | 15 |
| 17 | 弱 → 236 + 中 | `600:manual->925:manual` | 15 | untested | single | high | -10 |
| 18 | 2 + 弱 → 2 + 中 | `618:manual->634:manual` | 16 | untested | single | medium | -3 |
| 19 | 2 + 弱 → 3 + 中 | `618:manual->667:manual` | 17 | untested | single | medium | -20 |
| 20 | 2 + 弱 → 236 + 中 | `618:manual->925:manual` | 18 | untested | single | high | -10 |

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
reframework/data), then pick `plan: no-gauge` in the SWEEP panel's worklist list
(REFRESH if the panel was already open) and START SWEEP. It writes to the same
trial log as the full sweep, so pairs the full sweep already answered under the
same calibration and conditions are skipped, and the other way round.

## Written

- reframework/data/ComboExplorer_data/worklist/aki-modern-plan-no-gauge.json  (20 pairs, 11531 bytes)
- docs/ComboExplorer/plans/aki-modern-no-gauge.md
