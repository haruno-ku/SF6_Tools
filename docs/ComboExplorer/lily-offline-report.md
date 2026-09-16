# Offline candidate report - Lily / modern / midscreen / none

EVERYTHING BELOW IS A THEORETICAL CANDIDATE. Nothing here has been run on
Street Fighter 6. These are pairs and sequences worth spending a trial on,
not combos that are known to work.

## Provenance

- command_display: Lily, generated 2026-08-03T00:00:00.000Z
  - ac_sha256  36d9b3d87d425b093aeee36ae7acc355efb5609db17438a5f2e90a13abdb0c6c
  - bcm_sha256 b55590307aa3f59ecb1622eb9cd862a1314e519b553563c6622f29f5725d3f12
- frame data: RyoSogawa/sf6-sensei @ a64f2acf90fffc855ddc1a958a4ee752e15c571c (CC-BY-SA)
  - original work: SuperCombo Wiki, CC-BY-SA-4.0. See docs/NOTICE.md.
- game patch: command_display@2026-08-03T00:00:00.000Z
  (the command_display generation date, not a confirmed game version - the real patch is only knowable on the machine running the game)

## Moves searched

- catalog rows            126
- starting moves          13  (normal,command_normal / manual)
- target moves            60  (normal,command_normal,special,od_special,super / manual,simple)
- excluded from probing   53  (classic-only, air, throws, system, follow-ups)
- frame data coverage     60 of 63 (95%)  over every row this run uses
    starters      13 of  13 (100%)
    targets       60 of  60 (100%)
    follow-ups     0 of   3 (  0%)
    8 matched only by guessing between several source spellings:
      236236+K (1206) -> 236236K
      236236+K (1206) -> 236236K
      236236+K (1207) -> 236236K
      236236+K (1207) -> 236236K
      214214+P (1216) -> 214214P
      214214+P (1216) -> 214214P
      214214+P (1220) -> 214214P
      214214+P (1220) -> 214214P
    3 with no frame data at all:
      >j.MP (636)
      >HP (654)
      >HP (655)
- unresolved canonical ids 30 groups covering 82 rows
- no Modern form at all     8
    34  8
    600  LP
    609  LK
    610  LK
    612  MK
    614  HK
    651  3+HP
    852  6

## Theoretical edges

- pairs considered        819
- candidate edges         532
- excluded                287

by reason:
  chain_cancel             78
  frame_data_incomplete    13
  frame_link               106
  special_cancel           320
  super_cancel             66
  target_combo             3

by confidence:
  high                     342
  medium                   129
  low                      61

excluded because the data said no:
  followup_after_a_move_not_its_parent 24
  frame_margin_negative    139
  self_pair_without_chain  7
  throw_after_a_hit        207

Nothing was excluded for missing data. A gap in the source is recorded as
an unknown and the pair stays a candidate; only a KNOWN negative margin
excludes, and the margin is kept with it.

followup_after_a_move_not_its_parent is not a gap either. The frame source spells
a follow-up only as a chain from the move it comes out of ("5MP~MP"), so
these 24 pairs put a follow-up after a move the source says it does not
follow. A follow-up whose parent the source never names stays a candidate.

- follow-up edges         15  (parent named by the frame data: 2)

## Drive Rush Cancel candidates

A -> Drive Rush Cancel -> B. NONE OF THESE CAN BE PRESSED YET: how Drive
Rush is input on this build and which action id a Drive Rush Cancel is
have never been measured. They are not in the route search below, and with
--worklist they go to their own file, which the sweep does not read.

- DRC record              "MPMK or 66": startup 9, recovery 15, drive cost 30000
- starters that can rush  10  (drc_on_hit in the frame data)
- starters nobody knows   0  (no record, or a guessed one: kept, low)
- starters that cannot    3  (record present, no Drive Rush Cancel in it)
    604:manual 中
    620:manual 2 + 中
    630:manual 3 + 强
- pairs considered        630
- DRC edges               204
- excluded                426

by confidence:
  high                     76
  medium                   112
  low                      16

excluded:
  drc_margin_negative      306
  followup_after_drive_rush 30

drc_margin_negative is drc_on_hit minus B's startup, known and below zero,
kept with the number. followup_after_drive_rush is structure: a derivation
comes out of its parent with nothing in between, and a rush is in between.
A starter the source lists without a Drive Rush Cancel is counted once above
rather than once per target.

## Route candidates

- routes                  725
- graph nodes             54
- graph edges             532
- folded canonical variants 3630  (same buttons, unresolved action id)
- search complete         true
  length 2               181
  length 3               544

dropped by a search bound (not by the game):
  max_repeat_per_action    6

## Top 10 by predicted damage

Predicted damage is an UNSCALED frame-table sum. Combo scaling appears in no
frame table and neither does Modern's own damage reduction, so this is an
upper bound for ordering, never a damage figure.

#   route                                            dmg~   cost conf    unknowns
1   3 + 强 > 4 + 强 > 236236 + 中                 4050   10.9 low     8
2   3 + 强 > 4 + 强 > 4 + SP + 强                 4050    8.5 low     8
3   弱 > 4 + 强 > 236236 + 中                     3950   10.4 low     7
4   弱 > 4 + 强 > 4 + SP + 强                     3950    8.0 low     7
5   3 + 强 > 强 > 236236 + 中                     3950   10.4 low     8
6   3 + 强 > 强 > 4 + SP + 强                     3950    8.0 low     8
7   3 + 强 > 6 + 强 > 236236 + 中                 3950   10.9 low     8
8   3 + 强 > 6 + 强 > 4 + SP + 强                 3950    8.5 low     8
9   4 + 强 > 弱 > 236236 + 中                     3950   10.4 low     7
10  4 + 强 > 弱 > 4 + SP + 强                     3950    8.0 low     7

## Top 10 by predicted scaled damage (model)

A MODEL, NOT A DAMAGE FIGURE. Each move's frame-table damage times a
per-move factor from public descriptions of SF6 scaling (sf6-public-scaling-v1,
verified = false): 100/100/80/70.. per move, a light-normal starter
100/80/70.., floor 10%, x0.85 after a Drive Rush, x0.8 on SP moves, and
the Super Art minimum. Not modelled: 9 things, listed in
scaling_model.not_modelled on every route. Used for ordering only.

#   route                                         scaled~     dmg~   cost conf   
1   4 + 强 > 236236 + 中                           3600     3600    8.9 low    
2   3 + 强 > 4 + 强 > 236236 + 中                 3530     4050   10.9 low    
3   强 > 236236 + 中                               3500     3500    8.4 low    
4   6 + 强 > 236236 + 中                           3500     3500    8.9 low    
5   3 + 强 > 强 > 236236 + 中                     3430     3950   10.4 low    
6   3 + 强 > 6 + 强 > 236236 + 中                 3430     3950   10.9 low    
7   4 + 强 > 弱 > 236236 + 中                     3430     3950   10.4 low    
8   2 + 中 > 236236 + 中                           3300     3300    8.9 low    
9   3 + 强 > 2 + 中 > 236236 + 中                 3230     3750   10.9 low    
10  3 + 强 > 4 + 强 > 236236 + 弱                 3210     3650   10.9 medium 

## Top 10 by fewest inputs

#   route                                            dmg~   cost conf   
1   弱 > 弱                                         700    2.5 medium 
2   弱 > 中                                        1150    3.0 medium 
3   弱 > 强                                        1250    3.0 medium 
4   弱 > > 空中 中                                350    3.0 low    
5   中 > > 空中 中                                800    3.0 low    
6   强 > > 空中 中                                900    3.0 low    
7   弱 > 2 + 弱                                     650    3.5 medium 
8   弱 > 2 + 中                                    1050    3.5 medium 
9   弱 > 2 + 强                                     850    3.5 medium 
10  弱 > 3 + 强                                     800    3.5 medium 

## Pareto frontier: 12 routes nothing beats on both damage and inputs

1   3 + 强 > 4 + 强 > 4 + SP + 强                 4050    8.5
2   弱 > 4 + 强 > 4 + SP + 强                     3950    8.0
3   弱 > 强 > 4 + SP + 强                         3850    7.5
4   4 + 强 > 4 + SP + 强                           3600    6.5
5   强 > 4 + SP + 强                               3500    6.0
6   强 > SP + 强                                   3100    5.5
7   4 + 强 > 弱 > 强                              2250    5.0
8   弱 > 弱 > 4 + 强                              1700    4.5
9   弱 > 弱 > 强                                  1600    4.0
10  弱 > 4 + 强                                    1350    3.5

## Why the game still has to answer

- **actual_input_timing**
  the actual input window is what the sweep exists to measure
- **cancel_window_conditions**
  cancel windows into specials and supers have conditions no frame table lists
- **frame_data_variant_ambiguous**
  the frame source lists "236236K" 2 times - Thunderbird / Thunderbird (Windclad) - and the join took whichever came first; which one the input produces depends on something the frame table does not model
- **hitbox_hurtbox**
  which action id this input actually produces is unresolved, so the move being described may not be the move that comes out
- **juggle_behaviour**
  the first move carries juggle state, which decides what may follow
- **knockdown_vs_link_advantage**
  the first move's advantage is large enough to be a knockdown, and a knockdown's advantage is time before the opponent stands up rather than time to land another hit; no property in the source distinguishes them
- **modern_specific_scaling**
  Modern damage and its simple-input reduction appear in no frame table
- **pushback_range**
  the frame source records pushback as null; whether the two moves are still in range after the first is only knowable in game

Three of these apply to every candidate without exception: pushback and
range, Modern-specific damage scaling, and the actual input timing. No
frame table contains any of them, which is why no edge in this file is
marked as decidable offline.

## Written

- candidates/lily/modern/candidate-edges.json  (688259 bytes)
- candidates/lily/modern/candidate-routes.json  (5080419 bytes)
- reframework/data/ComboExplorer_data/worklist/lily-modern-drc.json  (97788 bytes)
- reframework/data/ComboExplorer_data/worklist/lily-modern.json  (220244 bytes)

Both documents carry runtime_verified = false and every record in them is
status = theoretical. The next step is the gaming machine: calibration,
then a sweep, then these become confirmed edges or rejected ones.
