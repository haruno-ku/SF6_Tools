# Offline candidate report - Dhalsim / modern / midscreen / none

EVERYTHING BELOW IS A THEORETICAL CANDIDATE. Nothing here has been run on
Street Fighter 6. These are pairs and sequences worth spending a trial on,
not combos that are known to work.

## Provenance

- command_display: Dhalsim, generated 2026-08-03T00:00:00.000Z
  - ac_sha256  4d4e618babf28e6b4bc34dc04111f7ce3a3eab41311609554091d056109144e0
  - bcm_sha256 cfc105d998ca39b06f95f89d36eb65fadc5ea84a96b1f2d4fe83afed324e5a47
- frame data: RyoSogawa/sf6-sensei @ a64f2acf90fffc855ddc1a958a4ee752e15c571c (CC-BY-SA)
  - original work: SuperCombo Wiki, CC-BY-SA-4.0. See docs/NOTICE.md.
- game patch: command_display@2026-08-03T00:00:00.000Z
  (the command_display generation date, not a confirmed game version - the real patch is only knowable on the machine running the game)

## Moves searched

- catalog rows            108
- starting moves          18  (normal,command_normal / manual)
- target moves            54  (normal,command_normal,special,od_special,super / manual,simple)
- excluded from probing   46  (classic-only, air, throws, system, follow-ups)
- frame data coverage     53 of 58 (91%)  over every row this run uses
    starters      18 of  18 (100%)
    targets       53 of  54 ( 98%)
    follow-ups     0 of   4 (  0%)
    12 matched only by guessing between several source spellings:
      236236+K (1282) -> 236236K
      236236+K (1282) -> 236236K
      236236+K (1283) -> 236236K
      236236+K (1283) -> 236236K
      236236+K (1284) -> 236236K
      236236+K (1284) -> 236236K
      236236+K (1289) -> 236236K
      236236+K (1289) -> 236236K
      236236+K (1290) -> 236236K
      236236+K (1290) -> 236236K
      236236+K (1291) -> 236236K
      236236+K (1291) -> 236236K
    5 with no frame data at all:
      236+MK (989)
      >j.2+LK (666)
      >j.2+MK (668)
      >j.2+HK (670)
      >j.2+LP (681)
- unresolved canonical ids 13 groups covering 35 rows
- no Modern form at all     17
    34  8
    605  LK
    606  MK
    612  2+LP
    622  1+HK
    661  4+HK
    852  6
    988  236+LK
    990  236+HK
    992  236+LK+MK
    994  236+MK+HK
    1032  6+KKK
    1047  j.6+KK
    1049  j.4+KK
    1200  236236+LP
    1206  236236+HP
    1210  214214+LK

## Theoretical edges

- pairs considered        1044
- candidate edges         664
- excluded                380

by reason:
  chain_cancel             72
  frame_data_incomplete    298
  frame_link               64
  special_cancel           140
  super_cancel             112

by confidence:
  high                     161
  medium                   109
  low                      394

excluded because the data said no:
  frame_margin_negative    366
  self_pair_without_chain  14

Nothing was excluded for missing data. A gap in the source is recorded as
an unknown and the pair stays a candidate; only a KNOWN negative margin
excludes, and the margin is kept with it.

- follow-up edges         72  (parent named by the frame data: 0)

## Drive Rush Cancel candidates

A -> Drive Rush Cancel -> B. NONE OF THESE CAN BE PRESSED YET: how Drive
Rush is input on this build and which action id a Drive Rush Cancel is
have never been measured. They are not in the route search below, and with
--worklist they go to their own file, which the sweep does not read.

- DRC record              "MPMK or 66": startup 9, recovery 15, drive cost 30000
- starters that can rush  7  (drc_on_hit in the frame data)
- starters nobody knows   0  (no record, or a guessed one: kept, low)
- starters that cannot    11  (record present, no Drive Rush Cancel in it)
    603:manual 中
    604:manual 强
    616:manual 2 + 强
    618:manual 1 + 弱
    657:manual 2 + 弱
    658:manual 2 + 中
    659:manual 3 + 强
    1031:manual 6 + 弱 + 中 + 强
    1033:manual 4 + 弱 + 中 + 强
    1042:manual 2 + 中 + 强
    1043:manual 3 + 中 + 强
- pairs considered        406
- DRC edges               158
- excluded                248

by confidence:
  high                     68
  medium                   47
  low                      43

excluded:
  drc_margin_negative      220
  followup_after_drive_rush 28

drc_margin_negative is drc_on_hit minus B's startup, known and below zero,
kept with the number. followup_after_drive_rush is structure: a derivation
comes out of its parent with nothing in between, and a rush is in between.
A starter the source lists without a Drive Rush Cancel is counted once above
rather than once per target.

## Route candidates

- routes                  2681
- graph nodes             58
- graph edges             664
- folded canonical variants 1983  (same buttons, unresolved action id)
- search complete         false
  beam dropped 1576 partial routes, 0 routes not emitted
  length 2               464
  length 3               2217

dropped by a search bound (not by the game):
  max_repeat_per_action    4

## Top 10 by predicted damage

Predicted damage is an UNSCALED frame-table sum. Combo scaling appears in no
frame table and neither does Modern's own damage reduction, so this is an
upper bound for ordering, never a damage figure.

#   route                                            dmg~   cost conf    unknowns
1   3 + 强 > 4 + 强 > 236236 + 强                 5800   10.9 low     8
2   3 + 强 > 4 + 强 > 2 + SP + 强                 5800    8.5 low     8
3   3 + 强 > 1 + 强 > 236236 + 强                 5700   10.9 low     8
4   3 + 强 > 1 + 强 > 2 + SP + 强                 5700    8.5 low     8
5   3 + 强 > 4 + 中 > 236236 + 强                 5600   10.9 low     8
6   3 + 强 > 4 + 中 > 2 + SP + 强                 5600    8.5 low     8
7   3 + 强 > 1 + 中 > 236236 + 强                 5400   10.9 low     8
8   3 + 强 > 1 + 中 > 2 + SP + 强                 5400    8.5 low     8
9   弱 > 4 + 强 > 236236 + 强                     5200   10.4 low     7
10  弱 > 4 + 强 > 2 + SP + 强                     5200    8.0 low     7

## Top 10 by predicted scaled damage (model)

A MODEL, NOT A DAMAGE FIGURE. Each move's frame-table damage times a
per-move factor from public descriptions of SF6 scaling (sf6-public-scaling-v1,
verified = false): 100/100/80/70.. per move, a light-normal starter
100/80/70.., floor 10%, x0.85 after a Drive Rush, x0.8 on SP moves, and
the Super Art minimum. Not modelled: 9 things, listed in
scaling_model.not_modelled on every route. Used for ordering only.

#   route                                         scaled~     dmg~   cost conf   
1   3 + 强 > 4 + 强 > 236236 + 强                 5000     5800   10.9 low    
2   4 + 强 > 236236 + 强                           4900     4900    8.9 low    
3   3 + 强 > 236236 + 强                           4900     4900    8.9 low    
4   3 + 强 > 1 + 强 > 236236 + 强                 4900     5700   10.9 low    
5   1 + 强 > 236236 + 强                           4800     4800    8.9 low    
6   3 + 强 > 4 + 中 > 236236 + 强                 4800     5600   10.9 low    
7   4 + 中 > 236236 + 强                           4700     4700    8.9 low    
8   3 + 强 > 1 + 中 > 236236 + 强                 4600     5400   10.9 low    
9   1 + 中 > 236236 + 强                           4500     4500    8.9 low    
10  3 + 强 > 弱 > 236236 + 强                     4400     5200   10.4 low    

## Top 10 by fewest inputs

#   route                                            dmg~   cost conf   
1   弱 > 弱                                         600    2.5 medium 
2   弱 > 中                                        1000    3.0 medium 
3   弱 > 强                                        1300    3.0 medium 
4   弱 > 2 + 弱                                     600    3.5 medium 
5   弱 > 2 + 强                                    1100    3.5 medium 
6   弱 > 1 + 弱                                     500    3.5 medium 
7   弱 > 1 + 中                                     800    3.5 medium 
8   弱 > 1 + 强                                    1100    3.5 medium 
9   弱 > 4 + 中                                    1000    3.5 medium 
10  弱 > 4 + 强                                    1200    3.5 medium 

## Pareto frontier: 9 routes nothing beats on both damage and inputs

1   3 + 强 > 4 + 强 > 2 + SP + 强                 5800    8.5
2   弱 > 4 + 强 > 2 + SP + 强                     5200    8.0
3   4 + 强 > 2 + SP + 强                           4900    6.5
4   弱 > 2 + SP + 强                               4300    6.0
5   弱 > SP + 强                                   2400    5.5
6   弱 > 3 + 强 > 强                              2200    5.0
7   3 + 强 > 强                                    1900    3.5
8   弱 > 强                                        1300    3.0
9   弱 > 弱                                         600    2.5

## Why the game still has to answer

- **actual_input_timing**
  the actual input window is what the sweep exists to measure
- **cancel_window_conditions**
  cancel windows into specials and supers have conditions no frame table lists
- **frame_data_variant_ambiguous**
  the frame source lists "236236K" 2 times - Merciless Yoga / Merciless Yoga (CA) - and the join took whichever came first; which one the input produces depends on something the frame table does not model
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

  1254  classic_modern but no Modern command form
  1254  simple_command names neither SP nor AUTO

## Written

- candidates/dhalsim/modern/candidate-edges.json  (883277 bytes)
- candidates/dhalsim/modern/candidate-routes.json  (18471734 bytes)
- reframework/data/ComboExplorer_data/worklist/dhalsim-modern-drc.json  (75917 bytes)
- reframework/data/ComboExplorer_data/worklist/dhalsim-modern.json  (254754 bytes)

Both documents carry runtime_verified = false and every record in them is
status = theoretical. The next step is the gaming machine: calibration,
then a sweep, then these become confirmed edges or rejected ones.
