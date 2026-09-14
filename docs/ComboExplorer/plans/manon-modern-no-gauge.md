# Route plan - Manon / modern - no-gauge

Generated 2026-09-14T12:59:25Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

13 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 599 (search complete: false)
  - the beam dropped 900 partial routes and 0 routes were not emitted, so a route
    satisfying these conditions may be missing

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| no_gauge | true | 599 | 154 | 445 | 13 |

- routes satisfying every condition: 445
- of those, through a pair the logs rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 3 + 强 → 4 + 强 → 63214 + 弱 | 2+HK → 4+HP → 63214+LP | 3300 | 3700 | drive 0 | 10.0 | medium | 0/2 pairs verified |
| 2 | 2 | 3 + 强 → 4 + 强 → 63214 + 中 | 2+HK → 4+HP → 63214+MP | 3300 | 3700 | drive 0 | 10.0 | medium | 0/2 pairs verified |
| 3 | 3 | 3 + 强 → 4 + 强 → 63214 + 强 | 2+HK → 4+HP → 63214+HP | 3300 | 3700 | drive 0 | 10.0 | medium | 0/2 pairs verified |
| 4 | 4 | 3 + 强 → 中 → 63214 + 弱 | 2+HK → MP → 63214+LP | 3100 | 3500 | drive 0 | 9.5 | medium | 0/2 pairs verified |
| 5 | 5 | 3 + 强 → 中 → 63214 + 中 | 2+HK → MP → 63214+MP | 3100 | 3500 | drive 0 | 9.5 | medium | 0/2 pairs verified |
| 6 | 6 | 3 + 强 → 中 → 63214 + 强 | 2+HK → MP → 63214+HP | 3100 | 3500 | drive 0 | 9.5 | medium | 0/2 pairs verified |
| 7 | 7 | 3 + 强 → 4 + 强 → AUTO + SP | 2+HK → 4+HP → 63214+LP | 2980 | 3700 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 8 | 8 | 3 + 强 → 4 + 强 → SP | 2+HK → 4+HP → 63214+HP | 2980 | 3700 | drive 0 | 7.5 | medium | 0/2 pairs verified |
| 9 | 9 | 3 + 强 → 63214 + 弱 | 2+HK → 63214+LP | 2900 | 2900 | drive 0 | 8.0 | medium | 0/1 pairs verified |
| 10 | 10 | 3 + 强 → 63214 + 中 | 2+HK → 63214+MP | 2900 | 2900 | drive 0 | 8.0 | medium | 0/1 pairs verified |
| 11 | 11 | 3 + 强 → 63214 + 强 | 2+HK → 63214+HP | 2900 | 2900 | drive 0 | 8.0 | medium | 0/1 pairs verified |
| 12 | 12 | 3 + 强 → 弱 → 63214 + 弱 | 2+HK → LP → 63214+LP | 2800 | 3200 | drive 0 | 9.5 | medium | 0/2 pairs verified |
| 13 | 13 | 3 + 强 → 弱 → 63214 + 中 | 2+HK → LP → 63214+MP | 2800 | 3200 | drive 0 | 9.5 | medium | 0/2 pairs verified |
| 14 | 14 | 3 + 强 → 弱 → 63214 + 强 | 2+HK → LP → 63214+HP | 2800 | 3200 | drive 0 | 9.5 | medium | 0/2 pairs verified |
| 15 | 15 | 3 + 强 → 2 + 弱 → 63214 + 弱 | 2+HK → 2+LP → 63214+LP | 2800 | 3200 | drive 0 | 10.0 | medium | 0/2 pairs verified |
| 16 | 16 | 3 + 强 → 2 + 弱 → 63214 + 中 | 2+HK → 2+LP → 63214+MP | 2800 | 3200 | drive 0 | 10.0 | medium | 0/2 pairs verified |
| 17 | 17 | 3 + 强 → 2 + 弱 → 63214 + 强 | 2+HK → 2+LP → 63214+HP | 2800 | 3200 | drive 0 | 10.0 | medium | 0/2 pairs verified |
| 18 | 18 | 4 + 强 → 63214 + 弱 | 4+HP → 63214+LP | 2800 | 2800 | drive 0 | 8.0 | high | 0/1 pairs verified |
| 19 | 19 | 4 + 强 → 63214 + 中 | 4+HP → 63214+MP | 2800 | 2800 | drive 0 | 8.0 | high | 0/1 pairs verified |
| 20 | 20 | 4 + 强 → 63214 + 强 | 4+HP → 63214+HP | 2800 | 2800 | drive 0 | 8.0 | high | 0/1 pairs verified |

## Pairs to sweep: 21

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 655 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 3 + 强 → 4 + 强 | `643:manual->665:manual` | 1, 2, 3, 7, 8 | untested | single | medium | 21 |
| 2 | 4 + 强 → 63214 + 弱 | `665:manual->900:manual` | 1, 18 | untested | single | high | -7 |
| 3 | 4 + 强 → 63214 + 中 | `665:manual->901:manual` | 2, 19 | untested | single | high | -5 |
| 4 | 4 + 强 → 63214 + 强 | `665:manual->902:manual` | 3, 20 | untested | single | high | -2 |
| 5 | 3 + 强 → 中 | `643:manual->605:manual` | 4, 5, 6 | untested | single | medium | 22 |
| 6 | 中 → 63214 + 弱 | `605:manual->900:manual` | 4 | untested | single | high | -8 |
| 7 | 中 → 63214 + 中 | `605:manual->901:manual` | 5 | untested | single | high | -6 |
| 8 | 中 → 63214 + 强 | `605:manual->902:manual` | 6 | untested | single | high | -3 |
| 9 | 4 + 强 → AUTO + SP | `665:manual->900:simple` | 7 | untested | single | high | -7 |
| 10 | 4 + 强 → SP | `665:manual->902:simple` | 8 | untested | single | high | -2 |
| 11 | 3 + 强 → 63214 + 弱 | `643:manual->900:manual` | 9 | untested | single | medium | 19 |
| 12 | 3 + 强 → 63214 + 中 | `643:manual->901:manual` | 10 | untested | single | medium | 21 |
| 13 | 3 + 强 → 63214 + 强 | `643:manual->902:manual` | 11 | untested | single | medium | 24 |
| 14 | 3 + 强 → 弱 | `643:manual->600:manual` | 12, 13, 14 | untested | single | medium | 25 |
| 15 | 弱 → 63214 + 弱 | `600:manual->900:manual` | 12 | untested | single | high | -6 |
| 16 | 弱 → 63214 + 中 | `600:manual->901:manual` | 13 | untested | single | high | -4 |
| 17 | 弱 → 63214 + 强 | `600:manual->902:manual` | 14 | untested | single | high | -1 |
| 18 | 3 + 强 → 2 + 弱 | `643:manual->625:manual` | 15, 16, 17 | untested | single | medium | 25 |
| 19 | 2 + 弱 → 63214 + 弱 | `625:manual->900:manual` | 15 | untested | single | high | -7 |
| 20 | 2 + 弱 → 63214 + 中 | `625:manual->901:manual` | 16 | untested | single | high | -5 |
| 21 | 2 + 弱 → 63214 + 强 | `625:manual->902:manual` | 17 | untested | single | high | -2 |

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

- reframework/data/ComboExplorer_data/worklist/manon-modern-plan-no-gauge.json  (21 pairs, 12003 bytes)
- docs/ComboExplorer/plans/manon-modern-no-gauge.md
