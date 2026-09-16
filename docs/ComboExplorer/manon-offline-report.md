# Offline candidate report - Manon / modern / midscreen / none

EVERYTHING BELOW IS A THEORETICAL CANDIDATE. Nothing here has been run on
Street Fighter 6. These are pairs and sequences worth spending a trial on,
not combos that are known to work.

## Provenance

- command_display: Manon, generated 2026-08-03T00:00:00.000Z
  - ac_sha256  a7e6faf72135894edea1c8055f0d9fc2b031d761c7a766d90fa282421e29aff8
  - bcm_sha256 502d0352a03a2f0fac5243df69e4d8057b10de7decbe8e910eb9efd5d5f2cece
- frame data: RyoSogawa/sf6-sensei @ a64f2acf90fffc855ddc1a958a4ee752e15c571c (CC-BY-SA)
  - original work: SuperCombo Wiki, CC-BY-SA-4.0. See docs/NOTICE.md.
- game patch: command_display@2026-08-03T00:00:00.000Z
  (the command_display generation date, not a confirmed game version - the real patch is only knowable on the machine running the game)

## Moves searched

- catalog rows            139
- starting moves          13  (normal,command_normal / manual)
- target moves            80  (normal,command_normal,special,od_special,super / manual,simple)
- excluded from probing   35  (system 11, any_button 7, air 6, followup 6, assist_combo 2, throw 2, unclassified 1)
- frame data coverage     80 of 86 (93%)  over every row this run uses
    starters      13 of  13 (100%)
    targets       80 of  80 (100%)
    follow-ups     0 of   6 (  0%)
    8 matched only by guessing between several source spellings:
      236236+P (1215) -> 236236P
      236236+P (1215) -> 236236P
      236236+P (1223) -> 236236P
      236236+P (1223) -> 236236P
      236236+P (1232) -> 236236P
      236236+P (1232) -> 236236P
      236236+P (1234) -> 236236P
      236236+P (1234) -> 236236P
    6 with no frame data at all:
      >MK (607)
      >MK (608)
      >HP (611)
      >HP (613)
      >HP (632)
      >MK (659)
- unresolved canonical ids 19 groups covering 97 rows
- no Modern form at all     11
    34  8
    620  HK
    623  2+LP
    628  2+MP
    661  3+HK
    852  6
    1022  236+MP
    1023  236+MP
    1024  236+MP
    1025  236+MP
    1026  236+MP

## Theoretical edges

- pairs considered        1118
- candidate edges         343
- excluded                775

by reason:
  chain_cancel             78
  frame_link               61
  special_cancel           175
  super_cancel             32
  target_combo             12

by confidence:
  high                     207
  medium                   136
  low                      0

excluded because the data said no:
  followup_after_a_move_not_its_parent 66
  frame_margin_negative    208
  self_pair_without_chain  7
  throw_after_a_hit        760

Nothing was excluded for missing data. A gap in the source is recorded as
an unknown and the pair stays a candidate; only a KNOWN negative margin
excludes, and the margin is kept with it.

followup_after_a_move_not_its_parent is not a gap either. The frame source spells
a follow-up only as a chain from the move it comes out of ("5MP~MP"), so
these 66 pairs put a follow-up after a move the source says it does not
follow. A follow-up whose parent the source never names stays a candidate.

- follow-up edges         12  (parent named by the frame data: 12)

## Drive Rush Cancel candidates

A -> Drive Rush Cancel -> B. NONE OF THESE CAN BE PRESSED YET: how Drive
Rush is input on this build and which action id a Drive Rush Cancel is
have never been measured. They are not in the route search below, and with
--worklist they go to their own file, which the sweep does not read.

- DRC record              "MPMK or 66": startup 9, recovery 15, drive cost 30000
- starters that can rush  7  (drc_on_hit in the frame data)
- starters nobody knows   0  (no record, or a guessed one: kept, low)
- starters that cannot    6  (record present, no Drive Rush Cancel in it)
    609:manual 强
    631:manual 2 + 强
    635:manual 2 + 弱
    640:manual 2 + 中
    643:manual 3 + 强
    658:manual 4 + 中
- pairs considered        602
- DRC edges               76
- excluded                526

by confidence:
  high                     33
  medium                   43
  low                      0

excluded:
  drc_margin_negative      218
  followup_after_drive_rush 42

drc_margin_negative is drc_on_hit minus B's startup, known and below zero,
kept with the number. followup_after_drive_rush is structure: a derivation
comes out of its parent with nothing in between, and a rush is in between.
A starter the source lists without a Drive Rush Cancel is counted once above
rather than once per target.

## Route candidates

- routes                  490
- graph nodes             48
- graph edges             343
- folded canonical variants 2417  (same buttons, unresolved action id)
- search complete         true
  length 2               116
  length 3               374

dropped by a search bound (not by the game):
  max_repeat_per_action    6

## Top 10 by predicted damage

Predicted damage is an UNSCALED frame-table sum. Combo scaling appears in no
frame table and neither does Modern's own damage reduction, so this is an
upper bound for ordering, never a damage figure.

#   route                                            dmg~   cost conf    unknowns
1   3 + 强 > 强 > 214214 + 中                     4500   10.4 medium  7
2   3 + 强 > 强 > 4 + SP + 强                     4500    8.0 medium  7
3   3 + 强 > 4 + 强 > 214214 + 中                 4500   10.9 medium  7
4   3 + 强 > 4 + 强 > 4 + SP + 强                 4500    8.5 medium  7
5   3 + 强 > 中 > 214214 + 中                     4300   10.4 medium  7
6   3 + 强 > 中 > 4 + SP + 强                     4300    8.0 medium  7
7   弱 > 3 + 强 > 214214 + 中                     4000   10.4 medium  7
8   弱 > 3 + 强 > 4 + SP + 强                     4000    8.0 medium  7
9   2 + 弱 > 3 + 强 > 214214 + 中                 4000   10.9 medium  7
10  2 + 弱 > 3 + 强 > 4 + SP + 强                 4000    8.5 medium  7

## Top 10 by predicted scaled damage (model)

A MODEL, NOT A DAMAGE FIGURE. Each move's frame-table damage times a
per-move factor from public descriptions of SF6 scaling (sf6-public-scaling-v1,
verified = false): 100/100/80/70.. per move, a light-normal starter
100/80/70.., floor 10%, x0.85 after a Drive Rush, x0.8 on SP moves, and
the Super Art minimum. Not modelled: 9 things, listed in
scaling_model.not_modelled on every route. Used for ordering only.

#   route                                         scaled~     dmg~   cost conf   
1   3 + 强 > 强 > 214214 + 中                     3940     4500   10.4 medium 
2   3 + 强 > 4 + 强 > 214214 + 中                 3940     4500   10.9 medium 
3   3 + 强 > 中 > 214214 + 中                     3740     4300   10.4 medium 
4   3 + 强 > 214214 + 中                           3700     3700    8.9 medium 
5   强 > 214214 + 中                               3600     3600    8.4 high   
6   4 + 强 > 214214 + 中                           3600     3600    8.9 high   
7   3 + 强 > 强 > 4 + SP + 强                     3492     4500    8.0 medium 
8   3 + 强 > 4 + 强 > 4 + SP + 强                 3492     4500    8.5 medium 
9   3 + 强 > 弱 > 214214 + 中                     3440     4000   10.4 medium 
10  3 + 强 > 2 + 弱 > 214214 + 中                 3440     4000   10.9 medium 

## Top 10 by fewest inputs

#   route                                            dmg~   cost conf   
1   弱 > 弱                                         600    2.5 medium 
2   弱 > 中                                         900    3.0 medium 
3   弱 > 强                                        1100    3.0 medium 
4   中 > > 中                                       600    3.0 medium 
5   强 > > 强                                       800    3.0 medium 
6   弱 > 2 + 弱                                     600    3.5 medium 
7   弱 > 2 + 强                                     900    3.5 medium 
8   弱 > 2 + 中                                     900    3.5 medium 
9   弱 > 3 + 强                                    1200    3.5 medium 
10  弱 > 4 + 中                                     900    3.5 medium 

## Pareto frontier: 9 routes nothing beats on both damage and inputs

1   3 + 强 > 强 > 4 + SP + 强                     4500    8.0
2   弱 > 强 > 4 + SP + 强                         3900    7.5
3   3 + 强 > 4 + SP + 强                           3700    6.5
4   强 > 4 + SP + 强                               3600    6.0
5   强 > SP + 强                                   2800    5.5
6   弱 > 3 + 强 > 强                              2000    5.0
7   3 + 强 > 强                                    1700    3.5
8   弱 > 强                                        1100    3.0
9   弱 > 弱                                         600    2.5

## Why the game still has to answer

- **actual_input_timing**
  the actual input window is what the sweep exists to measure
- **cancel_window_conditions**
  cancel windows into specials and supers have conditions no frame table lists
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

## Catalog entries the classifier could not place: 4

  1013  classic_modern but no Modern command form
  1013  simple_command names neither SP nor AUTO
  1014  classic_modern but no Modern command form
  1014  simple_command names neither SP nor AUTO

## Written

- candidates/manon/modern/candidate-edges.json  (439953 bytes)
- candidates/manon/modern/candidate-routes.json  (3432376 bytes)
- reframework/data/ComboExplorer_data/worklist/manon-modern-drc.json  (36938 bytes)
- reframework/data/ComboExplorer_data/worklist/manon-modern.json  (142258 bytes)

Both documents carry runtime_verified = false and every record in them is
status = theoretical. The next step is the gaming machine: calibration,
then a sweep, then these become confirmed edges or rejected ones.
