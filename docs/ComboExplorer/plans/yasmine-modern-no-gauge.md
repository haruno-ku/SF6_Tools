# Route plan - Yasmine / modern - no-gauge

Generated 2026-09-14T13:03:08Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

1266 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 1860 (search complete: false)
  - the beam dropped 2126 partial routes and 0 routes were not emitted, so a route
    satisfying these conditions may be missing

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| no_gauge | true | 1860 | 508 | 1352 | 1352 |

- routes satisfying every condition: 1352
- of those, through a pair the logs rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 3 + 强 → 6 + 中 → 3 + 强 | 2+HK → 6+MP → 2+HK | 2220 | 2400 | drive >=0 (2 unknown) | 6.0 | low | 0/2 pairs verified |
| 2 | 2 | 3 + 强 → 6 + 中 → 强 | 2+HK → 6+MP → HK | 2140 | 2300 | drive >=0 (2 unknown) | 5.5 | low | 0/2 pairs verified |
| 3 | 3 | 3 + 强 → 6 + 中 → 2 + 强 | 2+HK → 6+MP → 2+HP | 2140 | 2300 | drive >=0 (2 unknown) | 6.0 | low | 0/2 pairs verified |
| 4 | 4 | 6 + 中 → 3 + 强 → 强 | 6+MP → 2+HK → HK | 2140 | 2300 | drive >=0 (2 unknown) | 5.5 | low | 0/2 pairs verified |
| 5 | 5 | 6 + 中 → 3 + 强 → 2 + 强 | 6+MP → 2+HK → 2+HP | 2140 | 2300 | drive >=0 (2 unknown) | 6.0 | low | 0/2 pairs verified |
| 6 | 6 | 6 + 中 → 3 + 强 → 6 + 中 | 6+MP → 2+HK → 6+MP | 1980 | 2100 | drive >=0 (1 unknown) | 6.0 | low | 0/2 pairs verified |
| 7 | 7 | 3 + 强 → 2 + 弱 → 3 + 强 | 2+HK → 2+LP → 2+HK | 1920 | 2100 | drive >=0 (3 unknown) | 6.0 | medium | 0/2 pairs verified |
| 8 | 8 | 3 + 强 → 6 + 中 → 2 + 中 | 2+HK → 6+MP → 2+MK | 1900 | 2000 | drive >=0 (2 unknown) | 6.0 | low | 0/2 pairs verified |
| 9 | 9 | 6 + 中 → 3 + 强 → 2 + 中 | 6+MP → 2+HK → 2+MK | 1900 | 2000 | drive >=0 (2 unknown) | 6.0 | low | 0/2 pairs verified |
| 10 | 10 | 3 + 强 → 2 + 弱 → 强 | 2+HK → 2+LP → HK | 1840 | 2000 | drive >=0 (3 unknown) | 5.5 | medium | 0/2 pairs verified |
| 11 | 11 | 3 + 强 → 2 + 弱 → 2 + 强 | 2+HK → 2+LP → 2+HP | 1840 | 2000 | drive >=0 (3 unknown) | 6.0 | medium | 0/2 pairs verified |
| 12 | 12 | 3 + 强 → 6 + 中 → 弱 | 2+HK → 6+MP → LP | 1740 | 1800 | drive >=0 (2 unknown) | 5.5 | low | 0/2 pairs verified |
| 13 | 13 | 3 + 强 → 6 + 中 → 中 | 2+HK → 6+MP → MP | 1740 | 1800 | drive >=0 (2 unknown) | 5.5 | low | 0/2 pairs verified |
| 14 | 14 | 3 + 强 → 6 + 中 → 2 + 弱 | 2+HK → 6+MP → 2+LP | 1740 | 1800 | drive >=0 (2 unknown) | 6.0 | low | 0/2 pairs verified |
| 15 | 15 | 6 + 中 → 3 + 强 → 弱 | 6+MP → 2+HK → LP | 1740 | 1800 | drive >=0 (2 unknown) | 5.5 | low | 0/2 pairs verified |
| 16 | 16 | 6 + 中 → 3 + 强 → 中 | 6+MP → 2+HK → MP | 1740 | 1800 | drive >=0 (2 unknown) | 5.5 | low | 0/2 pairs verified |
| 17 | 17 | 6 + 中 → 3 + 强 → 2 + 弱 | 6+MP → 2+HK → 2+LP | 1740 | 1800 | drive >=0 (2 unknown) | 6.0 | low | 0/2 pairs verified |
| 18 | 18 | 3 + 强 → 强 | 2+HK → HK | 1700 | 1700 | drive >=0 (2 unknown) | 3.5 | medium | 0/1 pairs verified |
| 19 | 19 | 3 + 强 → 2 + 强 | 2+HK → 2+HP | 1700 | 1700 | drive >=0 (2 unknown) | 4.0 | medium | 0/1 pairs verified |
| 20 | 20 | 3 + 强 → 2 + 弱 → 6 + 中 | 2+HK → 2+LP → 6+MP | 1680 | 1800 | drive >=0 (2 unknown) | 6.0 | medium | 0/2 pairs verified |

### Kept on a gap

These satisfy the conditions on what is known; a condition could not be fully
judged because the source has no figure.

- #1 `647:manual>664:manual>647:manual`: no_gauge - 2 move(s) carry no Drive figure, so the route is not known to be free
- #2 `647:manual>664:manual>621:manual`: no_gauge - 2 move(s) carry no Drive figure, so the route is not known to be free
- #3 `647:manual>664:manual>633:manual`: no_gauge - 2 move(s) carry no Drive figure, so the route is not known to be free
- #4 `664:manual>647:manual>621:manual`: no_gauge - 2 move(s) carry no Drive figure, so the route is not known to be free
- #5 `664:manual>647:manual>633:manual`: no_gauge - 2 move(s) carry no Drive figure, so the route is not known to be free
- #6 `664:manual>647:manual>664:manual`: no_gauge - 1 move(s) carry no Drive figure, so the route is not known to be free
- #7 `647:manual>624:manual>647:manual`: no_gauge - 3 move(s) carry no Drive figure, so the route is not known to be free
- #8 `647:manual>664:manual>641:manual`: no_gauge - 2 move(s) carry no Drive figure, so the route is not known to be free
- #9 `664:manual>647:manual>641:manual`: no_gauge - 2 move(s) carry no Drive figure, so the route is not known to be free
- #10 `647:manual>624:manual>621:manual`: no_gauge - 3 move(s) carry no Drive figure, so the route is not known to be free
- #11 `647:manual>624:manual>633:manual`: no_gauge - 3 move(s) carry no Drive figure, so the route is not known to be free
- #12 `647:manual>664:manual>602:manual`: no_gauge - 2 move(s) carry no Drive figure, so the route is not known to be free
- #13 `647:manual>664:manual>609:manual`: no_gauge - 2 move(s) carry no Drive figure, so the route is not known to be free
- #14 `647:manual>664:manual>624:manual`: no_gauge - 2 move(s) carry no Drive figure, so the route is not known to be free
- #15 `664:manual>647:manual>602:manual`: no_gauge - 2 move(s) carry no Drive figure, so the route is not known to be free
- #16 `664:manual>647:manual>609:manual`: no_gauge - 2 move(s) carry no Drive figure, so the route is not known to be free
- #17 `664:manual>647:manual>624:manual`: no_gauge - 2 move(s) carry no Drive figure, so the route is not known to be free
- #18 `647:manual>621:manual`: no_gauge - 2 move(s) carry no Drive figure, so the route is not known to be free
- #19 `647:manual>633:manual`: no_gauge - 2 move(s) carry no Drive figure, so the route is not known to be free
- #20 `647:manual>624:manual>664:manual`: no_gauge - 2 move(s) carry no Drive figure, so the route is not known to be free

## Pairs to sweep: 18

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 733 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 3 + 强 → 6 + 中 | `647:manual->664:manual` | 1, 2, 3, 6, 8, 12, 13, 14 | untested | single | medium | 18 |
| 2 | 6 + 中 → 3 + 强 | `664:manual->647:manual` | 1, 4, 5, 6, 9, 15, 16, 17 | untested | single | low | - |
| 3 | 6 + 中 → 强 | `664:manual->621:manual` | 2 | untested | single | low | - |
| 4 | 6 + 中 → 2 + 强 | `664:manual->633:manual` | 3 | untested | single | low | - |
| 5 | 3 + 强 → 强 | `647:manual->621:manual` | 4, 18 | untested | single | medium | 26 |
| 6 | 3 + 强 → 2 + 强 | `647:manual->633:manual` | 5, 19 | untested | single | medium | 32 |
| 7 | 3 + 强 → 2 + 弱 | `647:manual->624:manual` | 7, 10, 11, 17, 20 | untested | single | medium | 36 |
| 8 | 2 + 弱 → 3 + 强 | `624:manual->647:manual` | 7 | untested | single | medium | -6 |
| 9 | 6 + 中 → 2 + 中 | `664:manual->641:manual` | 8 | untested | single | low | - |
| 10 | 3 + 强 → 2 + 中 | `647:manual->641:manual` | 9 | untested | single | medium | 32 |
| 11 | 2 + 弱 → 强 | `624:manual->621:manual` | 10 | untested | single | medium | -10 |
| 12 | 2 + 弱 → 2 + 强 | `624:manual->633:manual` | 11 | untested | single | medium | -4 |
| 13 | 6 + 中 → 弱 | `664:manual->602:manual` | 12 | untested | single | low | - |
| 14 | 6 + 中 → 中 | `664:manual->609:manual` | 13 | untested | single | low | - |
| 15 | 6 + 中 → 2 + 弱 | `664:manual->624:manual` | 14 | untested | single | low | - |
| 16 | 3 + 强 → 弱 | `647:manual->602:manual` | 15 | untested | single | medium | 35 |
| 17 | 3 + 强 → 中 | `647:manual->609:manual` | 16 | untested | single | medium | 34 |
| 18 | 2 + 弱 → 6 + 中 | `624:manual->664:manual` | 20 | untested | single | medium | -18 |

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

- reframework/data/ComboExplorer_data/worklist/yasmine-modern-plan-no-gauge.json  (18 pairs, 9920 bytes)
- docs/ComboExplorer/plans/yasmine-modern-no-gauge.md
