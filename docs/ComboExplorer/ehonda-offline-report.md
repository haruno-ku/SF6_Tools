# Offline candidate report - EHonda / modern / midscreen / none

EVERYTHING BELOW IS A THEORETICAL CANDIDATE. Nothing here has been run on
Street Fighter 6. These are pairs and sequences worth spending a trial on,
not combos that are known to work.

## Provenance

- command_display: EHonda, generated 2026-08-03T00:00:00.000Z
  - ac_sha256  4b056355a52e8015732109cf9ff3cbd37154002c70d0a862d1b042aa2c7c9192
  - bcm_sha256 89513e4ec1351fc6488f823a570aa6e92ca68426e15541536e00387eb8aabdeb
- frame data: RyoSogawa/sf6-sensei @ a64f2acf90fffc855ddc1a958a4ee752e15c571c (CC-BY-SA)
  - original work: SuperCombo Wiki, CC-BY-SA-4.0. See docs/NOTICE.md.
- game patch: command_display@2026-08-03T00:00:00.000Z
  (the command_display generation date, not a confirmed game version - the real patch is only knowable on the machine running the game)

## Moves searched

- catalog rows            122
- starting moves          13  (normal,command_normal / manual)
- target moves            54  (normal,command_normal,special,od_special,super / manual,simple)
- excluded from probing   57  (classic-only, air, throws, system, follow-ups)
- frame data coverage     54 of 76 (71%)  over every row this run uses
    starters      13 of  13 (100%)
    targets       54 of  54 (100%)
    follow-ups     0 of  22 (  0%)
    4 matched only by guessing between several source spellings:
      214214+P (1215) -> 214214P
      214214+P (1215) -> 214214P
      214214+P (1221) -> 214214P
      214214+P (1221) -> 214214P
    22 with no frame data at all:
      >MP (667)
      >3+HK (670)
      >P (963)
      >P (963)
      >P (963)
      >P (964)
      >P (964)
      >P (964)
      >2+P (965)
      >2+P (965)
      >2+P (965)
      >P (968)
      >P (968)
      >P (968)
      >P (970)
      >P (970)
      >P (970)
      >2+P (971)
      >2+P (971)
      >2+P (971)
      ... and 2 more
- unresolved canonical ids 27 groups covering 69 rows
- no Modern form at all     7
    34  8
    608  LK
    610  MK
    660  3+HK
    852  6
    983  63214+LK
    988  63214+MK

## Theoretical edges

- pairs considered        988
- candidate edges         424
- excluded                564

by reason:
  chain_cancel             45
  frame_data_incomplete    26
  frame_link               79
  special_cancel           217
  super_cancel             72
  target_combo             6

by confidence:
  high                     253
  medium                   105
  low                      66

excluded because the data said no:
  followup_after_a_move_not_its_parent 258
  frame_margin_negative    270
  self_pair_without_chain  10
  throw_after_a_hit        40

Nothing was excluded for missing data. A gap in the source is recorded as
an unknown and the pair stays a candidate; only a KNOWN negative margin
excludes, and the margin is kept with it.

followup_after_a_move_not_its_parent is not a gap either. The frame source spells
a follow-up only as a chain from the move it comes out of ("5MP~MP"), so
these 258 pairs put a follow-up after a move the source says it does not
follow. A follow-up whose parent the source never names stays a candidate.

- follow-up edges         28  (parent named by the frame data: 2)

## Drive Rush Cancel candidates

A -> Drive Rush Cancel -> B. NONE OF THESE CAN BE PRESSED YET: how Drive
Rush is input on this build and which action id a Drive Rush Cancel is
have never been measured. They are not in the route search below, and with
--worklist they go to their own file, which the sweep does not read.

- DRC record              "MPMK or 66": startup 9, recovery 15, drive cost 30000
- starters that can rush  7  (drc_on_hit in the frame data)
- starters nobody knows   0  (no record, or a guessed one: kept, low)
- starters that cannot    6  (record present, no Drive Rush Cancel in it)
    622:manual 2 + 强
    624:manual 2 + 强
    633:manual 2 + 中
    634:manual 2 + 中
    635:manual 3 + 强
    663:manual 6 + 强
- pairs considered        532
- DRC edges               160
- excluded                372

by confidence:
  high                     104
  medium                   44
  low                      12

excluded:
  drc_margin_negative      204
  followup_after_drive_rush 154

drc_margin_negative is drc_on_hit minus B's startup, known and below zero,
kept with the number. followup_after_drive_rush is structure: a derivation
comes out of its parent with nothing in between, and a rush is in between.
A starter the source lists without a Drive Rush Cancel is counted once above
rather than once per target.

## Route candidates

- routes                  565
- graph nodes             56
- graph edges             424
- folded canonical variants 2282  (same buttons, unresolved action id)
- search complete         true
  length 2               150
  length 3               415

dropped by a search bound (not by the game):
  max_repeat_per_action    3

## Top 10 by predicted damage

Predicted damage is an UNSCALED frame-table sum. Combo scaling appears in no
frame table and neither does Modern's own damage reduction, so this is an
upper bound for ordering, never a damage figure.

#   route                                            dmg~   cost conf    unknowns
1   3 + 强 > 强 > 214214 + 强                     5800   10.4 low     8
2   3 + 强 > 强 > 2 + SP + 强                     5800    8.0 low     8
3   3 + 强 > 2 + 强 > 214214 + 强                 5700   10.9 low     8
4   3 + 强 > 2 + 强 > 2 + SP + 强                 5700    8.5 low     8
5   3 + 强 > 中 > 214214 + 强                     5600   10.4 low     8
6   3 + 强 > 中 > 2 + SP + 强                     5600    8.0 low     8
7   2 + 弱 > 强 > 214214 + 强                     5200   10.4 low     7
8   2 + 弱 > 强 > 2 + SP + 强                     5200    8.0 low     7
9   2 + 弱 > 3 + 强 > 214214 + 强                 5200   10.9 low     8
10  2 + 弱 > 3 + 强 > 2 + SP + 强                 5200    8.5 low     8

## Top 10 by predicted scaled damage (model)

A MODEL, NOT A DAMAGE FIGURE. Each move's frame-table damage times a
per-move factor from public descriptions of SF6 scaling (sf6-public-scaling-v1,
verified = false): 100/100/80/70.. per move, a light-normal starter
100/80/70.., floor 10%, x0.85 after a Drive Rush, x0.8 on SP moves, and
the Super Art minimum. Not modelled: 9 things, listed in
scaling_model.not_modelled on every route. Used for ordering only.

#   route                                         scaled~     dmg~   cost conf   
1   3 + 强 > 强 > 214214 + 强                     5000     5800   10.4 low    
2   强 > 214214 + 强                               4900     4900    8.4 low    
3   3 + 强 > 214214 + 强                           4900     4900    8.9 low    
4   3 + 强 > 2 + 强 > 214214 + 强                 4900     5700   10.9 low    
5   2 + 强 > 214214 + 强                           4800     4800    8.9 low    
6   3 + 强 > 中 > 214214 + 强                     4800     5600   10.4 low    
7   中 > 214214 + 强                               4700     4700    8.4 low    
8   3 + 强 > 弱 > 214214 + 强                     4400     5200   10.4 low    
9   3 + 强 > 2 + 弱 > 214214 + 强                 4400     5200   10.9 low    
10  3 + 强 > 强 > 2 + SP + 强                     4360     5800    8.0 low    

## Top 10 by fewest inputs

#   route                                            dmg~   cost conf   
1   弱 > > 弱                                       300    3.0 medium 
2   中 > 弱                                        1000    3.0 medium 
3   弱 > 2 + 弱                                     600    3.5 medium 
4   弱 > 2 + 中                                     300    3.5 low    
5   中 > 2 + 弱                                    1000    3.5 medium 
6   中 > > 3 + 中                                   700    3.5 medium 
7   中 > 2 + 中                                     700    3.5 low    
8   强 > 2 + 中                                     900    3.5 low    
9   2 + 弱 > 弱                                     600    3.5 medium 
10  2 + 弱 > 中                                    1000    3.5 medium 

## Pareto frontier: 7 routes nothing beats on both damage and inputs

1   3 + 强 > 强 > 2 + SP + 强                     5800    8.0
2   中 > 弱 > 2 + SP + 强                         5000    7.5
3   强 > 2 + SP + 强                               4900    6.0
4   强 > SP + 强                                   2900    5.5
5   强 > [4]6 + 强                                 2400    4.8
6   3 + 强 > 强                                    1800    3.5
7   中 > 弱                                        1000    3.0

## Why the game still has to answer

- **actual_input_timing**
  the actual input window is what the sweep exists to measure
- **cancel_window_conditions**
  cancel windows into specials and supers have conditions no frame table lists
- **frame_data_variant_ambiguous**
  the frame source lists "214214P" 2 times - The Final Bout / The Final Bout (CA) - and the join took whichever came first; which one the input produces depends on something the frame table does not model
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

## Catalog entries the classifier could not place: 2

  969  classic_modern but no Modern command form
  969  simple_command names neither SP nor AUTO

## Written

- candidates/ehonda/modern/candidate-edges.json  (550622 bytes)
- candidates/ehonda/modern/candidate-routes.json  (3920174 bytes)
- reframework/data/ComboExplorer_data/worklist/ehonda-modern-drc.json  (76491 bytes)
- reframework/data/ComboExplorer_data/worklist/ehonda-modern.json  (174269 bytes)

Both documents carry runtime_verified = false and every record in them is
status = theoretical. The next step is the gaming machine: calibration,
then a sweep, then these become confirmed edges or rejected ones.
