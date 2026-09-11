# NOTICE

This repository is a fork of [Wael3rd/SF6_Tools](https://github.com/Wael3rd/SF6_Tools)
and is offered under the MIT licence, with one exception described below.

## Upstream

```
MIT License

Copyright (c) 2026 Wael Hadjmouldi
```

The full licence text is in `LICENSE`. The Combo Explorer additions under
`reframework/autorun/func/ComboExplorer/`, `tools/` and `tests/` are offered
under the same terms.

## The exception: frame data is CC-BY-SA-4.0

`data/frame-data/*.lua` and anything generated from it are **not** MIT.

| | |
|---|---|
| Original work | SuperCombo Wiki — Street Fighter 6 Frame Data |
| Original URL | https://wiki.supercombo.gg/w/Street_Fighter_6 |
| Licence | [CC-BY-SA-4.0](https://creativecommons.org/licenses/by-sa/4.0/) |
| Obtained via | [RyoSogawa/sf6-sensei](https://github.com/RyoSogawa/sf6-sensei), `packages/data/src/generated/<char>.json` |
| Pinned commit | recorded in each generated file's `_meta.commit` |

sf6-sensei splits its licensing: its **code** is MIT, its **data** is
CC-BY-SA-4.0 because the data came from the wiki. Only the data is used here.

**Modifications made:** reduced to the fields the candidate generator reads
(startup, on hit, on block, damage, cancel properties, gauge figures, juggle
state), and re-encoded as a Lua table. No source value was altered. The
generator that performs the reduction is `tools/gen-framedata-fixture.mjs`.

**ShareAlike:** because these files are a derived work, they are offered under
CC-BY-SA-4.0 rather than MIT, and so is anything derived from them in turn —
which includes `candidates/**/candidate-edges.json` and
`candidates/**/candidate-routes.json`, since every frame margin, damage sum and
confidence rating in them is computed from the frame data. Those documents carry
the attribution in their own `attribution` block, naming the commit they were
built from.

`external-data/` holds the unmodified upstream files and is **not** committed
(see `.gitignore`). It is a local working copy used to regenerate
`data/frame-data/`; the pin lives in `external-data/sf6-sensei/source.json`.

## What the frame data is and is not used for

Candidate generation only. A frame table saying that A recovers before B starts
is a reason to spend a trial on the real game, never evidence that the link
works — the data has no idea Modern controls exist, records pushback as null
throughout, and cannot tell a knockdown's advantage from a link's. Street
Fighter 6 itself is the only thing that promotes a candidate past
`theoretical`.
