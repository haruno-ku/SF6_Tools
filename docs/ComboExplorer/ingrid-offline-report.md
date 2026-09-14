# Offline candidate report - Ingrid / modern / midscreen / none

EVERYTHING BELOW IS A THEORETICAL CANDIDATE. Nothing here has been run on
Street Fighter 6. These are pairs and sequences worth spending a trial on,
not combos that are known to work.

## Provenance

- command_display: Ingrid, generated 2026-08-03T00:00:00.000Z
  - ac_sha256  0568c81221ccd0d676d8cac818e5af29d876063f176d3f8cec066c85ee31ccf3
  - bcm_sha256 16c8d193cc006d4fe03fa536dd120c794a44be630ba6d834ab72110bdc876331
- frame data: RyoSogawa/sf6-sensei @ a64f2acf90fffc855ddc1a958a4ee752e15c571c (CC-BY-SA)
  - original work: SuperCombo Wiki, CC-BY-SA-4.0. See docs/NOTICE.md.
- game patch: command_display@2026-08-03T00:00:00.000Z
  (the command_display generation date, not a confirmed game version - the real patch is only knowable on the machine running the game)

## Moves searched

- catalog rows            158
- starting moves          18  (normal,command_normal / manual)
- target moves            55  (normal,command_normal,special,od_special,super / manual,simple)
- excluded from probing   97  (classic-only, air, throws, system, follow-ups)
- frame data coverage     54 of 58 (93%)  over every row this run uses
    starters      17 of  18 ( 94%)
    targets       54 of  55 ( 98%)
    follow-ups     0 of   3 (  0%)
    12 matched only by guessing between several source spellings:
      LP (601) -> LP
      LK (612) -> LK
      MK (615) -> MK
      HK (618) -> HK
      214+HP (990) -> 214HP (1 Stock)
      214+HP (990) -> 214HP (1 Stock)
      214+HP (995) -> 214HP (1 Stock)
      214+HP (995) -> 214HP (1 Stock)
      236236+P (1287) -> 236236P
      236236+P (1287) -> 236236P
      236236+P (1296) -> 236236P
      236236+P (1296) -> 236236P
    4 with no frame data at all:
      5545+HK (1492)
      >j.HK (656)
      >HP (671)
      >HP (675)
- unresolved canonical ids 25 groups covering 100 rows
- no Modern form at all     14
    609  HP
    622  2+LP
    852  6
    905  236+MP
    913  236+LP+HP
    1201  236236+K
    1202  236236+K
    1218  214214+MP
    1219  214214+MP
    1222  214214+LP
    1223  214214+LP
    1224  214214+LP
    1228  214214+HP
    1229  214214+HP

## Theoretical edges

- pairs considered        1044
- candidate edges         719
- excluded                325

by reason:
  chain_cancel             54
  frame_data_incomplete    285
  frame_link               284
  special_cancel           140
  super_cancel             36
  target_combo             4

by confidence:
  high                     78
  medium                   197
  low                      444

excluded because the data said no:
  followup_after_a_move_not_its_parent 50
  frame_margin_negative    261
  self_pair_without_chain  14

Nothing was excluded for missing data. A gap in the source is recorded as
an unknown and the pair stays a candidate; only a KNOWN negative margin
excludes, and the margin is kept with it.

followup_after_a_move_not_its_parent is not a gap either. The frame source spells
a follow-up only as a chain from the move it comes out of ("5MP~MP"), so
these 50 pairs put a follow-up after a move the source says it does not
follow. A follow-up whose parent the source never names stays a candidate.

- follow-up edges         4  (parent named by the frame data: 4)

## Drive Rush Cancel candidates

A -> Drive Rush Cancel -> B. NONE OF THESE CAN BE PRESSED YET: how Drive
Rush is input on this build and which action id a Drive Rush Cancel is
have never been measured. They are not in the route search below, and with
--worklist they go to their own file, which the sweep does not read.

- DRC record              "MPMK or 66": startup 9, recovery 15, drive cost 30000
- starters that can rush  4  (drc_on_hit in the frame data)
- starters nobody knows   5  (no record, or a guessed one: kept, low)
- starters that cannot    9  (record present, no Drive Rush Cancel in it)
    635:manual 2 + 弱
    643:manual 3 + 强
    661:manual 6 + 中
    663:manual 6 + 强
    670:manual 4 + 中
    674:manual 4 + 强
    962:manual 4 + 弱 + 中 + 强
    963:manual 6 + 弱 + 中 + 强
    964:manual 2 + 弱 + 中 + 强
- pairs considered        522
- DRC edges               356
- excluded                166

by confidence:
  high                     24
  medium                   13
  low                      319

excluded:
  drc_margin_negative      139
  followup_after_drive_rush 27

drc_margin_negative is drc_on_hit minus B's startup, known and below zero,
kept with the number. followup_after_drive_rush is structure: a derivation
comes out of its parent with nothing in between, and a rush is in between.
A starter the source lists without a Drive Rush Cancel is counted once above
rather than once per target.

## Route candidates

- routes                  2502
- graph nodes             57
- graph edges             719
- folded canonical variants 2217  (same buttons, unresolved action id)
- search complete         false
  beam dropped 4159 partial routes, 0 routes not emitted
  length 2               399
  length 3               2103

dropped by a search bound (not by the game):
  max_repeat_per_action    4

## Top 10 by predicted damage

Predicted damage is an UNSCALED frame-table sum. Combo scaling appears in no
frame table and neither does Modern's own damage reduction, so this is an
upper bound for ordering, never a damage figure.

#   route                                            dmg~   cost conf    unknowns
1   2 + 弱 + 中 + 强 > 6 + 强 > 214214 + 强     7000   11.9 medium  7
2   6 + 弱 + 中 + 强 > 6 + 强 > 214214 + 强     6900   11.9 medium  7
3   2 + 弱 + 中 + 强 > 2 + 强 > 214214 + 强     6900   11.9 medium  7
4   3 + 强 > 6 + 强 > 214214 + 强                 6800   10.9 medium  7
5   6 + 弱 + 中 + 强 > 2 + 强 > 214214 + 强     6800   11.9 medium  7
6   3 + 强 > 2 + 强 > 214214 + 强                 6700   10.9 medium  7
7   6 + 强 > 2 + 强 > 214214 + 强                 6700   10.9 medium  7
8   4 + 强 > 6 + 强 > 214214 + 强                 6700   10.9 medium  7
9   4 + 强 > 2 + 强 > 214214 + 强                 6600   10.9 medium  7
10  2 + 弱 + 中 + 强 > 2 + 中 > 214214 + 强     6600   11.9 medium  7

## Top 10 by predicted scaled damage (model)

A MODEL, NOT A DAMAGE FIGURE. Each move's frame-table damage times a
per-move factor from public descriptions of SF6 scaling (sf6-public-scaling-v1,
verified = false): 100/100/80/70.. per move, a light-normal starter
100/80/70.., floor 10%, x0.85 after a Drive Rush, x0.8 on SP moves, and
the Super Art minimum. Not modelled: 9 things, listed in
scaling_model.not_modelled on every route. Used for ordering only.

#   route                                         scaled~     dmg~   cost conf   
1   2 + 弱 + 中 + 强 > 6 + 强 > 214214 + 强     6000     7000   11.9 medium 
2   6 + 强 > 214214 + 强                           5900     5900    8.9 medium 
3   6 + 弱 + 中 + 强 > 6 + 强 > 214214 + 强     5900     6900   11.9 medium 
4   2 + 弱 + 中 + 强 > 2 + 强 > 214214 + 强     5900     6900   11.9 medium 
5   2 + 强 > 214214 + 强                           5800     5800    8.9 high   
6   3 + 强 > 6 + 强 > 214214 + 强                 5800     6800   10.9 medium 
7   6 + 弱 + 中 + 强 > 2 + 强 > 214214 + 强     5800     6800   11.9 medium 
8   3 + 强 > 2 + 强 > 214214 + 强                 5700     6700   10.9 medium 
9   6 + 强 > 2 + 强 > 214214 + 强                 5700     6700   10.9 medium 
10  4 + 强 > 6 + 强 > 214214 + 强                 5700     6700   10.9 medium 

## Top 10 by fewest inputs

#   route                                            dmg~   cost conf   
1   弱 > 2 + 弱                                     600    3.5 low    
2   弱 > 2 + 中                                     800    3.5 low    
3   中 > 2 + 弱                                     900    3.5 low    
4   强 > 2 + 弱                                     900    3.5 low    
5   强 > 2 + 强                                    1400    3.5 low    
6   强 > 2 + 中                                    1100    3.5 low    
7   强 > 3 + 强                                    1500    3.5 low    
8   强 > 6 + 中                                    1200    3.5 low    
9   强 > 6 + 强                                    1500    3.5 low    
10  强 > 4 + 中                                    1300    3.5 low    

## Pareto frontier: 14 routes nothing beats on both damage and inputs

1   2 + 弱 + 中 + 强 > 6 + 强 > 214214 + 强     7000   11.9
2   3 + 强 > 6 + 强 > 214214 + 强                 6800   10.9
3   强 > 6 + 强 > 214214 + 强                     6500   10.4
4   2 + 弱 + 中 + 强 > 3 + 强 > 2 + SP + 强     6000    9.5
5   6 + 强 > 214214 + 强                           5900    8.9
6   3 + 强 > 6 + 强 > 2 + SP + 强                 5800    8.5
7   强 > 3 + 强 > 2 + SP + 强                     5500    8.0
8   2 + 弱 + 中 + 强 > 2 + SP + 强               5100    7.5
9   3 + 强 > 2 + SP + 强                           4900    6.5
10  强 > 2 + SP + 强                               4600    6.0

## Why the game still has to answer

- **actual_input_timing**
  the actual input window is what the sweep exists to measure
- **cancel_window_conditions**
  cancel windows into specials and supers have conditions no frame table lists
- **frame_data_variant_ambiguous**
  for the first move, the join took "LP", whose frame record describes a special, but this row's action id puts it among the normals. The two sources disagree about what move this is, so the numbers may belong to a different one
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

## Catalog entries the classifier could not place: 12

  606  classic_modern but no Modern command form
  606  simple_command names neither SP nor AUTO
  975  classic_modern but no Modern command form
  975  simple_command names neither SP nor AUTO
  976  classic_modern but no Modern command form
  976  simple_command names neither SP nor AUTO
  977  classic_modern but no Modern command form
  977  simple_command names neither SP nor AUTO
  980  classic_modern but no Modern command form
  980  simple_command names neither SP nor AUTO

## Written

- candidates/ingrid/modern/candidate-edges.json  (1048817 bytes)
- candidates/ingrid/modern/candidate-routes.json  (17592414 bytes)
- reframework/data/ComboExplorer_data/worklist/ingrid-modern-drc.json  (137992 bytes)
- reframework/data/ComboExplorer_data/worklist/ingrid-modern.json  (268416 bytes)

Both documents carry runtime_verified = false and every record in them is
status = theoretical. The next step is the gaming machine: calibration,
then a sweep, then these become confirmed edges or rejected ones.
