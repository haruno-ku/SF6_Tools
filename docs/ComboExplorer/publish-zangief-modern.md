# Publishing Zangief / modern - the dry run

Generated 2026-09-16T05:15:05Z by `tools/lua/publish.lua`.

This is the last link of the chain in #51 run end to end with nothing
invented: the committed trials are folded by policy `ce-eval-v1`, every
subject the policy calls `reproduced` is offered as a `ce.verified_combo.v1`,
and `KnowledgeDb.export` is asked to take it. **Nothing below is published.**
The value of the document is the refusal list: it is the work list.

## What this ran on

| | |
|---|---|
| character | Zangief (`zangief`) |
| control scheme | modern |
| policy | `ce-eval-v1` v1 |
| trial files | 7 |
| lines / distinct observations | 1000 / 856 |
| evaluations | 420 |
| exporting for patch | `24176760` |
| exporting for calibration | `ESF_006-20260912T074740Z` |
| slug table given | none - the mapping is empty |
| game_version code | `dry-run-no-version-code` - **a stand-in** |

`combos.yaml` carries a version code that has to name a row in the target's
`game_versions.yaml`, and this repository has no copy of that file. The dry run
used a stand-in so that every record could still be judged one by one; it
appears nowhere except the line above. Pass `--game-version` with the real code
before anything is written for real.

## Publishable now: 0

Nothing crosses. Every reason is below, and each one names what would clear it.

## What the logs say, before anything is published

| result | evaluations | what it means |
|---|---:|---|
| `no_success_observed` | 50 | only conclusive failures, over the delays that were tried |
| `observed_success` | 8 | linked, but never twice at one delay - one coin toss |
| `pending` | 356 | no counted run answered either way |
| `reproduced` | 6 | the policy's bar: a pair stable at one delay, or a route linked twice |

## Refused before the export, by `tools/lua/verifiedcombo.lua`

These never became a record, so `KnowledgeDb.export` never saw them.

| reason | subjects |
|---|---:|
| `damage_not_measured` | 6 |
| `not_reproduced` | 414 |

### The 6 reproduced subject(s) held up only by the measurement

Each of these is a combo the game has already shown connects, in this cohort,
under this policy. The only thing missing is the number.

| subject | kind | the combo | links | gaps | why not |
|---|---|---|---:|---|---|
| `617:manual->1206:manual` | edge | 2 + 弱 > 236236 + 中 | 2 | 22 | `damage_not_measured` |
| `617:manual->1206:simple` | edge | 2 + 弱 > 4 + SP + 强 | 2 | 22 | `damage_not_measured` |
| `621:manual->1206:simple` | edge | 2 + 中 > 4 + SP + 强 | 2 | 35 | `damage_not_measured` |
| `633:manual->1206:simple` | edge | 3 + 强 > 4 + SP + 强 | 2 | 53 | `damage_not_measured` |
| `zangief-assist-ab` | route | AUTO + 强 > 3 + 中 | 2 | 40 44 | `damage_not_measured` |
| `zangief-assist-ground-truth` | route | AUTO + 强 > 3 + 中 > 2 + SP | 19 | 40,2 40,4 40,6 40,8 40,10 40,12 40,14 40,16 40,20 40,24 44,2 44,4 44,6 44,8 44,10 44,12 44,14 44,16 44,20 | `damage_not_measured` |

## The export's own answer

0 record(s) were offered; 0 crossed and 0 were rejected.

No record reached the export at all, so its `missing_moves` list is empty -
`KnowledgeDb.combo` checks the measurement before it looks at the steps, and
never gets as far as asking about a slug. The next section asks that question
on its behalf.

## `missing_moves`: the slug table this needs (#17)

Every action id below appears in a route that would be published for this cohort
and has no slug in `data/characters/zangief/moves.yaml`. This is the input for the
mapping table; nothing here guesses a slug.

7 move(s), over 6 reproduced subject(s) in this cohort.

| action id | how it was pressed | notation | display | combos blocked |
|---:|---|---|---|---:|
| 1206 | manual | 236236 + 中 | 236236 + M | 4 |
| 617 | manual | 2 + 弱 | 2 + L | 2 |
| 655 | manual | 3 + 中 | 3 + M | 2 |
| 660 | simple | AUTO + 强 | Assist + H | 2 |
| 621 | manual | 2 + 中 | 2 + M | 1 |
| 633 | manual | 3 + 强 | 3 + H | 1 |
| 900 | simple | 2 + SP | 2 + Special | 1 |

- `1206` blocks: 617:manual->1206:manual, 617:manual->1206:simple, 621:manual->1206:simple, 633:manual->1206:simple
- `617` blocks: 617:manual->1206:manual, 617:manual->1206:simple
- `655` blocks: zangief-assist-ab, zangief-assist-ground-truth
- `660` blocks: zangief-assist-ab, zangief-assist-ground-truth
- `621` blocks: 621:manual->1206:simple
- `633` blocks: 633:manual->1206:simple
- `900` blocks: zangief-assist-ground-truth

The export's own `missing_moves` holds 0 entr(ies) rather than 7, because the
records it refused earlier never reached its step check. When the measurement
lands, the two lists become one.

A table to fill in has been written to `reframework/data/ComboExplorer_data/slugs/zangief-modern.json`
(7 new entr(ies), 0 kept from the existing file). Every `slug` in it is null
and every `source` is `unfilled`: the file's own header says what filling it
enables. It carries the frame source's English move names, so it is a derived
work and ships the CC-BY-SA attribution; this report does not.

## What one session on the game would change

**6 reproduced combo(s) have no measured damage.** `evidence.damage` was wired
in 6d67e7c and `evidence.gauges` in f986074, both after every committed trial,
so every row in the logs is from before the runtime recorded either. Running
these routes with `RouteRun` records the damage, the hit count and both gauges
on each trial, and the same fold then produces 6 record(s) with a
`measured.damage` the schema accepts.

Concretely, for this cohort:

- **2 + 弱 > 236236 + 中** - 617:manual->1206:manual (linked at gap 22)
- **2 + 弱 > 4 + SP + 强** - 617:manual->1206:simple (linked at gap 22)
- **2 + 中 > 4 + SP + 强** - 621:manual->1206:simple (linked at gap 35)
- **3 + 强 > 4 + SP + 强** - 633:manual->1206:simple (linked at gap 53)
- **AUTO + 强 > 3 + 中** - zangief-assist-ab (linked at gap 40, 44)
- **AUTO + 强 > 3 + 中 > 2 + SP** - zangief-assist-ground-truth (linked at gap 40,2, 40,4, 40,6, 40,8, 40,10, 40,12, 40,14, 40,16, 40,20, 40,24, 44,2, 44,4, 44,6, 44,8, 44,10, 44,12, 44,14, 44,16, 44,20)

After that session, what is still missing is not a measurement:

1. the 7 slug(s) above, in the other project's `moves.yaml` (#17)
2. the real `game_version` code from `game_versions.yaml`
3. the release shape (#38 section 9): `public.combos` cannot hold conditions,
   calibration or evidence, and #38 has already decided that what cannot be
   represented is not exported automatically

Everything in this list is a decision or a mapping. Only the first paragraph
needs the game.

## Licence

Measured on Street Fighter 6. No value in this document is derived from the frame
data, so it carries no CC-BY-SA obligation - the same split `tools/lua/confirm.lua`
states in its `licence_note`. Joining these rows to startup / on-hit figures, as a
published page showing frame numbers would, does inherit one; see `docs/NOTICE.md`.

