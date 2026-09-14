# Offline candidate report - Ryu / modern / midscreen / none

EVERYTHING BELOW IS A THEORETICAL CANDIDATE. Nothing here has been run on
Street Fighter 6. These are pairs and sequences worth spending a trial on,
not combos that are known to work.

## Provenance

- command_display: Ryu, generated 2026-08-03T00:00:00.000Z
  - ac_sha256  afedc65f24d5968174fdcdd8e42720199564623ba993c35870f4d6084d94c195
  - bcm_sha256 b77a3e65145add3d864a56e3f325435b5bf85b420fc9d36f8daf33bf03699ee9
- frame data: RyoSogawa/sf6-sensei @ a64f2acf90fffc855ddc1a958a4ee752e15c571c (CC-BY-SA)
  - original work: SuperCombo Wiki, CC-BY-SA-4.0. See docs/NOTICE.md.
- game patch: command_display@2026-08-03T00:00:00.000Z
  (the command_display generation date, not a confirmed game version - the real patch is only knowable on the machine running the game)

## Moves searched

- catalog rows            102
- starting moves          14  (normal,command_normal / manual)
- target moves            52  (normal,command_normal,special,od_special,super / manual,simple)
- excluded from probing   43  (classic-only, air, throws, system, follow-ups)
- frame data coverage     52 of 55 (95%)  over every row this run uses
    starters      14 of  14 (100%)
    targets       52 of  52 (100%)
    follow-ups     0 of   3 (  0%)
    23 matched only by guessing between several source spellings:
      236+HP (904) -> 236HP
      236+HP (904) -> 236HP
      214+HP (1039) -> 214HP
      236+HP (1052) -> 236HP
      236+HP (1052) -> 236HP
      236+PP (1053) -> 236PP
      214+HP (1061) -> 214HP
      236236+P (1200) -> 236236P
      236236+P (1200) -> 236236P
      236236+P (1201) -> 236236P
      236236+P (1201) -> 236236P
      214214+P (1212) -> 214214P
      214214+P (1212) -> 214214P
      214214+P (1214) -> 214214P
      214214+P (1214) -> 214214P
      236236+K (1233) -> 236236K
      236236+K (1233) -> 236236K
      236236+K (1234) -> 236236K
      236236+K (1234) -> 236236K
      236236+K (1238) -> 236236K
      236236+K (1238) -> 236236K
      236236+K (1239) -> 236236K
      236236+K (1239) -> 236236K
    3 with no frame data at all:
      >HK (685)
      >LK (687)
      >HK (689)
- unresolved canonical ids 23 groups covering 53 rows
- no Modern form at all     6
    614  MK
    617  HK
    622  2+LP
    663  4+HP
    852  6
    1005  214+HK

## Theoretical edges

- pairs considered        770
- candidate edges         551
- excluded                219

by reason:
  chain_cancel             84
  frame_link               105
  special_cancel           242
  super_cancel             160
  target_combo             3

by confidence:
  high                     170
  medium                   121
  low                      260

excluded because the data said no:
  followup_after_a_move_not_its_parent 39
  frame_margin_negative    172
  self_pair_without_chain  8

Nothing was excluded for missing data. A gap in the source is recorded as
an unknown and the pair stays a candidate; only a KNOWN negative margin
excludes, and the margin is kept with it.

followup_after_a_move_not_its_parent is not a gap either. The frame source spells
a follow-up only as a chain from the move it comes out of ("5MP~MP"), so
these 39 pairs put a follow-up after a move the source says it does not
follow. A follow-up whose parent the source never names stays a candidate.

- follow-up edges         3  (parent named by the frame data: 3)

## Drive Rush Cancel candidates

A -> Drive Rush Cancel -> B. NONE OF THESE CAN BE PRESSED YET: how Drive
Rush is input on this build and which action id a Drive Rush Cancel is
have never been measured. They are not in the route search below, and with
--worklist they go to their own file, which the sweep does not read.

- DRC record              "MPMK or 66": startup 9, recovery 15, drive cost 30000
- starters that can rush  10  (drc_on_hit in the frame data)
- starters nobody knows   0  (no record, or a guessed one: kept, low)
- starters that cannot    4  (record present, no Drive Rush Cancel in it)
    635:manual 2 + 弱
    643:manual 3 + 强
    660:manual 6 + 中
    670:manual 6 + 强
- pairs considered        550
- DRC edges               234
- excluded                316

by confidence:
  high                     84
  medium                   47
  low                      103

excluded:
  drc_margin_negative      286
  followup_after_drive_rush 30

drc_margin_negative is drc_on_hit minus B's startup, known and below zero,
kept with the number. followup_after_drive_rush is structure: a derivation
comes out of its parent with nothing in between, and a rush is in between.
A starter the source lists without a Drive Rush Cancel is counted once above
rather than once per target.

## Route candidates

- routes                  1092
- graph nodes             55
- graph edges             551
- folded canonical variants 3459  (same buttons, unresolved action id)
- search complete         false
  beam dropped 334 partial routes, 0 routes not emitted
  length 2               255
  length 3               837

dropped by a search bound (not by the game):
  max_repeat_per_action    6

## Top 10 by predicted damage

Predicted damage is an UNSCALED frame-table sum. Combo scaling appears in no
frame table and neither does Modern's own damage reduction, so this is an
upper bound for ordering, never a damage figure.

#   route                                            dmg~   cost conf    unknowns
1   3 + 强 > 强 > 236236 + 强                     5700   10.4 low     8
2   3 + 强 > 强 > 2 + SP + 强                     5700    8.0 low     8
3   3 + 强 > 2 + 强 > 236236 + 强                 5700   10.9 low     8
4   3 + 强 > 2 + 强 > 2 + SP + 强                 5700    8.5 low     8
5   3 + 强 > 中 > 236236 + 强                     5500   10.4 low     8
6   3 + 强 > 中 > 2 + SP + 强                     5500    8.0 low     8
7   3 + 强 > 2 + 中 > 236236 + 强                 5400   10.9 low     8
8   3 + 强 > 2 + 中 > 2 + SP + 强                 5400    8.5 low     8
9   3 + 强 > 4 + 强 > 236236 + 强                 5300   10.9 low     8
10  3 + 强 > 4 + 强 > 2 + SP + 强                 5300    8.5 low     8

## Top 10 by predicted scaled damage (model)

A MODEL, NOT A DAMAGE FIGURE. Each move's frame-table damage times a
per-move factor from public descriptions of SF6 scaling (sf6-public-scaling-v1,
verified = false): 100/100/80/70.. per move, a light-normal starter
100/80/70.., floor 10%, x0.85 after a Drive Rush, x0.8 on SP moves, and
the Super Art minimum. Not modelled: 9 things, listed in
scaling_model.not_modelled on every route. Used for ordering only.

#   route                                         scaled~     dmg~   cost conf   
1   3 + 强 > 236236 + 强                           4900     4900    8.9 low    
2   3 + 强 > 强 > 236236 + 强                     4900     5700   10.4 low    
3   3 + 强 > 2 + 强 > 236236 + 强                 4900     5700   10.9 low    
4   强 > 236236 + 强                               4800     4800    8.4 low    
5   2 + 强 > 236236 + 强                           4800     4800    8.9 low    
6   3 + 强 > 中 > 236236 + 强                     4700     5500   10.4 low    
7   中 > 236236 + 强                               4600     4600    8.4 low    
8   3 + 强 > 2 + 中 > 236236 + 强                 4600     5400   10.9 low    
9   2 + 中 > 236236 + 强                           4500     4500    8.9 low    
10  3 + 强 > 4 + 强 > 236236 + 强                 4500     5300   10.9 low    

## Top 10 by fewest inputs

#   route                                            dmg~   cost conf   
1   弱 > 弱                                         600    2.5 medium 
2   弱 > 中                                         900    3.0 medium 
3   弱 > 强                                        1100    3.0 medium 
4   中 > 弱                                         900    3.0 high   
5   中 > > 中                                       600    3.0 medium 
6   强 > 弱                                        1100    3.0 medium 
7   强 > > 强                                       800    3.0 medium 
8   强 > > 中                                       800    3.0 medium 
9   弱 > 2 + 弱                                     600    3.5 medium 
10  弱 > 2 + 强                                    1100    3.5 medium 

## Pareto frontier: 10 routes nothing beats on both damage and inputs

1   3 + 强 > 强 > 2 + SP + 强                     5700    8.0
2   弱 > 强 > 2 + SP + 强                         5100    7.5
3   3 + 强 > 2 + SP + 强                           4900    6.5
4   强 > 2 + SP + 强                               4800    6.0
5   强 > 6 + SP                                     2200    5.5
6   弱 > 3 + 强 > 强                              2000    5.0
7   强 > 弱 > 强                                  1900    4.5
8   3 + 强 > 强                                    1700    3.5
9   弱 > 强                                        1100    3.0
10  弱 > 弱                                         600    2.5

## Why the game still has to answer

- **actual_input_timing**
  the actual input window is what the sweep exists to measure
- **cancel_window_conditions**
  cancel windows into specials and supers have conditions no frame table lists
- **frame_data_variant_ambiguous**
  the frame source lists "236HP" 2 times - Hadoken / Denjin Charge Hadoken - and the join took whichever came first; which one the input produces depends on something the frame table does not model
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

  1000  classic_modern but no Modern command form
  1000  simple_command names neither SP nor AUTO
  1213  classic_modern but no Modern command form
  1213  simple_command names neither SP nor AUTO

## Written

- candidates/ryu/modern/candidate-edges.json  (801705 bytes)
- candidates/ryu/modern/candidate-routes.json  (7651129 bytes)
- reframework/data/ComboExplorer_data/worklist/ryu-modern-drc.json  (111633 bytes)
- reframework/data/ComboExplorer_data/worklist/ryu-modern.json  (226375 bytes)

Both documents carry runtime_verified = false and every record in them is
status = theoretical. The next step is the gaming machine: calibration,
then a sweep, then these become confirmed edges or rejected ones.
