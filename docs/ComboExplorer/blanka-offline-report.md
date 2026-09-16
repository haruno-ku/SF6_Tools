# Offline candidate report - Blanka / modern / midscreen / none

EVERYTHING BELOW IS A THEORETICAL CANDIDATE. Nothing here has been run on
Street Fighter 6. These are pairs and sequences worth spending a trial on,
not combos that are known to work.

## Provenance

- command_display: Blanka, generated 2026-08-03T00:00:00.000Z
  - ac_sha256  eea1ed2c62f8c33aeeccc63a8eddd2a4133fa77a648cb0e89427953655b8db02
  - bcm_sha256 1bb40291a7011ce50cd59d7a6e0fd4af3aaa2de4afedc63754bca9fb05dc3a3b
- frame data: RyoSogawa/sf6-sensei @ a64f2acf90fffc855ddc1a958a4ee752e15c571c (CC-BY-SA)
  - original work: SuperCombo Wiki, CC-BY-SA-4.0. See docs/NOTICE.md.
- game patch: command_display@2026-08-03T00:00:00.000Z
  (the command_display generation date, not a confirmed game version - the real patch is only knowable on the machine running the game)

## Moves searched

- catalog rows            112
- starting moves          17  (normal,command_normal / manual)
- target moves            44  (normal,command_normal,special,od_special,super / manual,simple)
- excluded from probing   63  (air 26, any_button 15, system 11, unclassified 6, followup 2, throw 2, assist_combo 1)
- frame data coverage     43 of 46 (93%)  over every row this run uses
    starters      17 of  17 (100%)
    targets       43 of  44 ( 98%)
    follow-ups     0 of   2 (  0%)
    16 matched only by guessing between several source spellings:
      [4]6+LP (859) -> [4]6LP
      [4]6+MP (867) -> [4]6MP
      [4]6+MP (867) -> [4]6MP
      [4]6+HP (873) -> [4]6HP
      [4]6+PP (885) -> [4]6PP
      63214+MK (958) -> 63214MK
      63214+KK (966) -> 63214KK
      [2]8+LK (971) -> [2]8LK
      [2]8+LK (971) -> [2]8LK
      [2]8+MK (975) -> [2]8MK
      [2]8+HK (984) -> [2]8HK
      [2]8+KK (990) -> [2]8KK
      236236+K (1215) -> 236236K
      236236+K (1215) -> 236236K
      236236+K (1220) -> 236236K
      236236+K (1220) -> 236236K
    3 with no frame data at all:
      214+LP+LK+MK (926)
      >22+MP (936)
      >22+HP (937)
- unresolved canonical ids 19 groups covering 53 rows
- no Modern form at all     58
    34  8
    602  MP
    608  LK
    613  2+LP
    616  2+MP
    627  2+HK
    639  6+MP
    852  6
    954  63214+LK
    962  63214+HK
    1075  >6+P
    1076  >9+P
    1077  >8+P
    1078  >7+P
    1079  >4+P
    1080  >1+P
    1081  >2+P
    1082  >3+P
    1084  >6+P
    1085  >9+P
    1086  >8+P
    1087  >7+P
    1088  >4+P
    1089  >1+P
    1090  >2+P
    1091  >3+P
    1093  >6+P
    1094  >9+P
    1095  >8+P
    1096  >7+P
    1097  >4+P
    1098  >1+P
    1099  >2+P
    1100  >3+P
    1106  >6+P
    1107  >9+P
    1108  >8+P
    1109  >7+P
    1110  >4+P
    1111  >1+P
    1112  >2+P
    1113  >3+P
    1115  >6+P
    1116  >9+P
    1117  >8+P
    1118  >7+P
    1119  >4+P
    1120  >1+P
    1121  >2+P
    1122  >3+P
    1124  >6+P
    1125  >9+P
    1126  >8+P
    1127  >7+P
    1128  >4+P
    1129  >1+P
    1130  >2+P
    1131  >3+P

## Theoretical edges

- pairs considered        782
- candidate edges         532
- excluded                250

by reason:
  chain_cancel             34
  frame_data_incomplete    285
  frame_link               128
  special_cancel           80
  super_cancel             50

by confidence:
  high                     45
  medium                   92
  low                      395

excluded because the data said no:
  frame_margin_negative    184
  self_pair_without_chain  15
  throw_after_a_hit        66

Nothing was excluded for missing data. A gap in the source is recorded as
an unknown and the pair stays a candidate; only a KNOWN negative margin
excludes, and the margin is kept with it.

- follow-up edges         34  (parent named by the frame data: 0)

## Drive Rush Cancel candidates

A -> Drive Rush Cancel -> B. NONE OF THESE CAN BE PRESSED YET: how Drive
Rush is input on this build and which action id a Drive Rush Cancel is
have never been measured. They are not in the route search below, and with
--worklist they go to their own file, which the sweep does not read.

- DRC record              "MPMK or 66": startup 9, recovery 15, drive cost 30000
- starters that can rush  5  (drc_on_hit in the frame data)
- starters nobody knows   0  (no record, or a guessed one: kept, low)
- starters that cannot    12  (record present, no Drive Rush Cancel in it)
    611:manual 强
    618:manual 2 + 强
    622:manual 2 + 弱
    640:manual 6 + 中
    644:manual 6 + 强
    646:manual 3 + 强
    999:manual 2 + 中 + 强
    1001:manual 2 + 中 + 强
    1007:manual 6 + 弱 + 中 + 强
    1008:manual 4 + 弱 + 中 + 强
    1009:manual 6 + 弱 + 中 + 强
    1010:manual 4 + 弱 + 中 + 强
- pairs considered        230
- DRC edges               105
- excluded                125

by confidence:
  high                     50
  medium                   11
  low                      44

excluded:
  drc_margin_negative      100
  followup_after_drive_rush 10

drc_margin_negative is drc_on_hit minus B's startup, known and below zero,
kept with the number. followup_after_drive_rush is structure: a derivation
comes out of its parent with nothing in between, and a rush is in between.
A starter the source lists without a Drive Rush Cancel is counted once above
rather than once per target.

## Route candidates

- routes                  2105
- graph nodes             43
- graph edges             532
- folded canonical variants 2427  (same buttons, unresolved action id)
- search complete         false
  beam dropped 1267 partial routes, 0 routes not emitted
  length 2               316
  length 3               1789

dropped by a search bound (not by the game):
  max_repeat_per_action    2

## Top 10 by predicted damage

Predicted damage is an UNSCALED frame-table sum. Combo scaling appears in no
frame table and neither does Modern's own damage reduction, so this is an
upper bound for ordering, never a damage figure.

#   route                                            dmg~   cost conf    unknowns
1   6 + 强 > 3 + 强 > 236236 + 强                 6100   10.9 low     8
2   6 + 强 > 3 + 强 > 2 + SP + 强                 6100    8.5 low     8
3   3 + 强 > 6 + 强 > 236236 + 强                 6100   10.9 low     8
4   3 + 强 > 6 + 强 > 2 + SP + 强                 6100    8.5 low     8
5   6 + 强 > 中 > 236236 + 强                     5700   10.4 low     8
6   6 + 强 > 中 > 2 + SP + 强                     5700    8.0 low     8
7   6 + 强 > 4 + 中 > 236236 + 强                 5700   10.9 low     8
8   6 + 强 > 4 + 中 > 2 + SP + 强                 5700    8.5 low     8
9   6 + 强 > 2 + 中 > 236236 + 强                 5600   10.9 low     8
10  6 + 强 > 2 + 中 > 2 + SP + 强                 5600    8.5 low     8

## Top 10 by predicted scaled damage (model)

A MODEL, NOT A DAMAGE FIGURE. Each move's frame-table damage times a
per-move factor from public descriptions of SF6 scaling (sf6-public-scaling-v1,
verified = false): 100/100/80/70.. per move, a light-normal starter
100/80/70.., floor 10%, x0.85 after a Drive Rush, x0.8 on SP moves, and
the Super Art minimum. Not modelled: 9 things, listed in
scaling_model.not_modelled on every route. Used for ordering only.

#   route                                         scaled~     dmg~   cost conf   
1   6 + 强 > 3 + 强 > 236236 + 强                 5300     6100   10.9 low    
2   3 + 强 > 6 + 强 > 236236 + 强                 5300     6100   10.9 low    
3   6 + 强 > 236236 + 强                           5100     5100    8.9 low    
4   3 + 强 > 236236 + 强                           5000     5000    8.9 low    
5   6 + 强 > 中 > 236236 + 强                     4900     5700   10.4 low    
6   6 + 强 > 4 + 中 > 236236 + 强                 4900     5700   10.9 low    
7   6 + 强 > 2 + 中 > 236236 + 强                 4800     5600   10.9 low    
8   3 + 强 > 中 > 236236 + 强                     4800     5600   10.4 low    
9   3 + 强 > 4 + 中 > 236236 + 强                 4800     5600   10.9 low    
10  3 + 强 > 2 + 中 > 236236 + 强                 4700     5500   10.9 low    

## Top 10 by fewest inputs

#   route                                            dmg~   cost conf   
1   中 > 弱                                         900    3.0 medium 
2   强 > 弱                                        1100    3.0 medium 
3   中 > 2 + 弱                                     800    3.5 medium 
4   强 > 2 + 弱                                    1100    3.5 medium 
5   2 + 弱 > 弱                                     600    3.5 medium 
6   2 + 弱 > 中                                     900    3.5 medium 
7   2 + 弱 > 强                                    1100    3.5 medium 
8   2 + 弱 > 2 + 弱                                 600    3.5 medium 
9   2 + 中 > 弱                                     800    3.5 medium 
10  6 + 中 > 弱                                     600    3.5 medium 

## Pareto frontier: 10 routes nothing beats on both damage and inputs

1   6 + 强 > 3 + 强 > 2 + SP + 强                 6100    8.5
2   6 + 强 > 中 > 2 + SP + 强                     5700    8.0
3   6 + 强 > 2 + SP + 强                           5100    6.5
4   中 > 2 + SP + 强                               4600    6.0
5   6 + 强 > 3 + 强 > 强                          2900    5.5
6   6 + 强 > [2]8 + 强                             2500    5.3
7   6 + 强 > 强 > 弱                              2200    5.0
8   6 + 强 > 3 + 强                                2100    4.0
9   6 + 强 > 强                                    1900    3.5
10  强 > 弱                                        1100    3.0

## Why the game still has to answer

- **actual_input_timing**
  the actual input window is what the sweep exists to measure
- **cancel_window_conditions**
  cancel windows into specials and supers have conditions no frame table lists
- **frame_data_variant_ambiguous**
  the frame source lists "[4]6LP" 2 times - Rolling Attack / Rolling Attack (SA2) - and the join took whichever came first; which one the input produces depends on something the frame table does not model
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

- candidates/blanka/modern/candidate-edges.json  (776026 bytes)
- candidates/blanka/modern/candidate-routes.json  (14866463 bytes)
- reframework/data/ComboExplorer_data/worklist/blanka-modern-drc.json  (50508 bytes)
- reframework/data/ComboExplorer_data/worklist/blanka-modern.json  (193963 bytes)

Both documents carry runtime_verified = false and every record in them is
status = theoretical. The next step is the gaming machine: calibration,
then a sweep, then these become confirmed edges or rejected ones.
