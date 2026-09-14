# Route plan - EHonda / modern - no-gauge

Generated 2026-09-14T13:01:23Z by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.

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

47 route(s) carry no value on that field and are ranked after the rest, not removed.

Unscaled damage is a frame-table sum: an upper bound for ordering when complete,
never a damage figure.

## What each condition removed

- routes found by the search: 609 (search complete: true)

| condition | value | before | removed | after | kept on a gap |
|---|---|---:|---:|---:|---:|
| no_gauge | true | 609 | 233 | 376 | 47 |

- routes satisfying every condition: 376
- of those, through a pair the logs rejected: 0 (ranked after the clean ones)
- in this plan (top 20): 20

## Routes

`#` is the plan order; `sort` is where the route stood before routes through a
rejected pair were moved behind the clean ones.

| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |
|---:|---:|---|---|---:|---:|---|---:|---|---|
| 1 | 1 | 3 + 强 → 强 → 2 + SP | 2+HK → HP → 63214+HK | 3336 | 4200 | drive 0 | 7.5 | medium | 0/2 pairs verified |
| 2 | 2 | 3 + 强 → 中 → 2 + SP | 2+HK → MP → 63214+HK | 3136 | 4000 | drive 0 | 7.5 | medium | 0/2 pairs verified |
| 3 | 3 | 3 + 强 → 强 → [4]6 + 强 | 2+HK → HP → [4]6+HP | 3000 | 3300 | drive 0 | 6.8 | medium | 0/2 pairs verified |
| 4 | 4 | 3 + 强 → 2 + 中 → 2 + SP | 2+HK → 2+MK → 63214+HK | 2936 | 3800 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 5 | 5 | 3 + 强 → 强 → [4]6 + 弱 | 2+HK → HP → [4]6+LP | 2920 | 3200 | drive 0 | 6.8 | medium | 0/2 pairs verified |
| 6 | 6 | 3 + 强 → 强 → [4]6 + 中 | 2+HK → HP → [4]6+MP | 2920 | 3200 | drive 0 | 6.8 | medium | 0/2 pairs verified |
| 7 | 7 | 强 → 2 + SP | HP → 63214+HK | 2820 | 3300 | drive 0 | 5.5 | high | 0/1 pairs verified |
| 8 | 8 | 3 + 强 → 2 + SP | 2+HK → 63214+HK | 2820 | 3300 | drive 0 | 6.0 | medium | 0/1 pairs verified |
| 9 | 9 | 3 + 强 → 中 → [4]6 + 强 | 2+HK → MP → [4]6+HP | 2800 | 3100 | drive 0 | 6.8 | medium | 0/2 pairs verified |
| 10 | 10 | 3 + 强 → 弱 → 2 + SP | 2+HK → LP → 63214+HK | 2736 | 3600 | drive 0 | 7.5 | medium | 0/2 pairs verified |
| 11 | 11 | 3 + 强 → 2 + 弱 → 2 + SP | 2+HK → 2+LP → 63214+HK | 2736 | 3600 | drive 0 | 8.0 | medium | 0/2 pairs verified |
| 12 | 12 | 3 + 强 → 中 → [4]6 + 弱 | 2+HK → MP → [4]6+LP | 2720 | 3000 | drive 0 | 6.8 | medium | 0/2 pairs verified |
| 13 | 13 | 3 + 强 → 中 → [4]6 + 中 | 2+HK → MP → [4]6+MP | 2720 | 3000 | drive 0 | 6.8 | medium | 0/2 pairs verified |
| 14 | 14 | 3 + 强 → 强 → [4] + SP | 2+HK → HP → [4]6+MP | 2696 | 3200 | drive 0 | 7.5 | medium | 0/2 pairs verified |
| 15 | 15 | 中 → 2 + SP | MP → 63214+HK | 2620 | 3100 | drive 0 | 5.5 | high | 0/1 pairs verified |
| 16 | 16 | 中 → 弱 → 2 + SP | MP → LP → 63214+HK | 2536 | 3400 | drive 0 | 7.0 | medium | 0/2 pairs verified |
| 17 | 17 | 中 → 2 + 弱 → 2 + SP | MP → 2+LP → 63214+HK | 2536 | 3400 | drive 0 | 7.5 | medium | 0/2 pairs verified |
| 18 | 18 | 3 + 强 → 中 → [4] + SP | 2+HK → MP → [4]6+MP | 2496 | 3000 | drive 0 | 7.5 | medium | 0/2 pairs verified |
| 19 | 19 | 2 + 中 → 2 + SP | 2+MK → 63214+HK | 2420 | 2900 | drive 0 | 6.0 | medium | 0/1 pairs verified |
| 20 | 20 | 强 → [4]6 + 强 | HP → [4]6+HP | 2400 | 2400 | drive 0 | 4.8 | high | 0/1 pairs verified |

## Pairs to sweep: 21

In the order the worklist holds them. `needed by` lists the plan ranks of the
routes containing the pair. The full worklist has 444 pairs.

`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`
is a direction pressed twice in a row (22), `followup` a move that only exists
after a specific previous one. The sweep sets both aside rather than pressing
them (#49), so a plan that needs one needs a route run or a compiler change.

| # | pair | key | needed by | logs say | press | confidence | margin |
|---:|---|---|---|---|---|---|---:|
| 1 | 3 + 强 → 强 | `635:manual->605:manual` | 1, 3, 5, 6, 14 | untested | single | medium | 22 |
| 2 | 强 → 2 + SP | `605:manual->993:simple` | 1, 7 | untested | single | high | -5 |
| 3 | 3 + 强 → 中 | `635:manual->603:manual` | 2, 9, 12, 13, 18 | untested | single | medium | 20 |
| 4 | 中 → 2 + SP | `603:manual->993:simple` | 2, 15 | untested | single | high | 0 |
| 5 | 强 → [4]6 + 强 | `605:manual->902:manual` | 3, 20 | untested | single | high | -13 |
| 6 | 3 + 强 → 2 + 中 | `635:manual->633:manual` | 4 | untested | single | medium | 21 |
| 7 | 2 + 中 → 2 + SP | `633:manual->993:simple` | 4, 19 | untested | single | medium | 0 |
| 8 | 强 → [4]6 + 弱 | `605:manual->900:manual` | 5 | untested | single | high | -9 |
| 9 | 强 → [4]6 + 中 | `605:manual->901:manual` | 6 | untested | single | high | -9 |
| 10 | 3 + 强 → 2 + SP | `635:manual->993:simple` | 8 | untested | single | medium | 24 |
| 11 | 中 → [4]6 + 强 | `603:manual->902:manual` | 9 | untested | single | high | -8 |
| 12 | 3 + 强 → 弱 | `635:manual->600:manual` | 10 | untested | single | medium | 25 |
| 13 | 弱 → 2 + SP | `600:manual->993:simple` | 10, 16 | untested | single | high | -2 |
| 14 | 3 + 强 → 2 + 弱 | `635:manual->615:manual` | 11 | untested | single | medium | 26 |
| 15 | 2 + 弱 → 2 + SP | `615:manual->993:simple` | 11, 17 | untested | single | high | -2 |
| 16 | 中 → [4]6 + 弱 | `603:manual->900:manual` | 12 | untested | single | high | -4 |
| 17 | 中 → [4]6 + 中 | `603:manual->901:manual` | 13 | untested | single | high | -4 |
| 18 | 强 → [4] + SP | `605:manual->901:simple` | 14 | untested | single | high | -9 |
| 19 | 中 → 弱 | `603:manual->600:manual` | 16 | untested | single | medium | 1 |
| 20 | 中 → 2 + 弱 | `603:manual->615:manual` | 17 | untested | single | medium | 2 |
| 21 | 中 → [4] + SP | `603:manual->901:simple` | 18 | untested | single | high | -4 |

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

- reframework/data/ComboExplorer_data/worklist/ehonda-modern-plan-no-gauge.json  (21 pairs, 11992 bytes)
- docs/ComboExplorer/plans/ehonda-modern-no-gauge.md
