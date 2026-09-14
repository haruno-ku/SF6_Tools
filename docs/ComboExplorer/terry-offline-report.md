# Offline candidate report - Terry / modern / midscreen / none

EVERYTHING BELOW IS A THEORETICAL CANDIDATE. Nothing here has been run on
Street Fighter 6. These are pairs and sequences worth spending a trial on,
not combos that are known to work.

## Provenance

- command_display: Terry, generated 2026-08-03T00:00:00.000Z
  - ac_sha256  604c0f7279f24805c20f70e1f4f780f9d5804cb7ee9f0744ebaaf3ea9c5d71ca
  - bcm_sha256 65f2330947425034f83190fb7e6a7ec97e0a1d08eba31f8a39cf2828ab8b4007
- frame data: RyoSogawa/sf6-sensei @ a64f2acf90fffc855ddc1a958a4ee752e15c571c (CC-BY-SA)
  - original work: SuperCombo Wiki, CC-BY-SA-4.0. See docs/NOTICE.md.
- game patch: command_display@2026-08-03T00:00:00.000Z
  (the command_display generation date, not a confirmed game version - the real patch is only knowable on the machine running the game)

## Moves searched

- catalog rows            87
- starting moves          12  (normal,command_normal / manual)
- target moves            44  (normal,command_normal,special,od_special,super / manual,simple)
- excluded from probing   36  (classic-only, air, throws, system, follow-ups)
- frame data coverage     44 of 51 (86%)  over every row this run uses
    starters      12 of  12 (100%)
    targets       44 of  44 (100%)
    follow-ups     0 of   7 (  0%)
    8 matched only by guessing between several source spellings:
      236236+P (1230) -> 236236P
      236236+P (1230) -> 236236P
      236236+P (1231) -> 236236P
      236236+P (1231) -> 236236P
      236236+P (1235) -> 236236P
      236236+P (1235) -> 236236P
      236236+P (1236) -> 236236P
      236236+P (1236) -> 236236P
    7 with no frame data at all:
      >2+HK (670)
      >MK (674)
      >MP (677)
      >MK (679)
      >HP (682)
      >HK (683)
      >HK (685)
- unresolved canonical ids 10 groups covering 30 rows
- no Modern form at all     8
    34  8
    609  LK
    612  MK
    852  6
    955  214+LK
    956  214+MK
    1214  21426+HP+MK
    1215  PP

## Theoretical edges

- pairs considered        612
- candidate edges         409
- excluded                203

by reason:
  chain_cancel             72
  frame_link               79
  special_cancel           180
  super_cancel             108
  target_combo             6

by confidence:
  high                     216
  medium                   113
  low                      80

excluded because the data said no:
  followup_after_a_move_not_its_parent 78
  frame_margin_negative    119
  self_pair_without_chain  6

Nothing was excluded for missing data. A gap in the source is recorded as
an unknown and the pair stays a candidate; only a KNOWN negative margin
excludes, and the margin is kept with it.

followup_after_a_move_not_its_parent is not a gap either. The frame source spells
a follow-up only as a chain from the move it comes out of ("5MP~MP"), so
these 78 pairs put a follow-up after a move the source says it does not
follow. A follow-up whose parent the source never names stays a candidate.

- follow-up edges         6  (parent named by the frame data: 6)

## Drive Rush Cancel candidates

A -> Drive Rush Cancel -> B. NONE OF THESE CAN BE PRESSED YET: how Drive
Rush is input on this build and which action id a Drive Rush Cancel is
have never been measured. They are not in the route search below, and with
--worklist they go to their own file, which the sweep does not read.

- DRC record              "MPMK or 66": startup 9, recovery 15, drive cost 30000
- starters that can rush  9  (drc_on_hit in the frame data)
- starters nobody knows   0  (no record, or a guessed one: kept, low)
- starters that cannot    3  (record present, no Drive Rush Cancel in it)
    615:manual 强
    638:manual 3 + 强
    665:manual 6 + 强
- pairs considered        459
- DRC edges               125
- excluded                334

by confidence:
  high                     43
  medium                   58
  low                      24

excluded:
  drc_margin_negative      271
  followup_after_drive_rush 63

drc_margin_negative is drc_on_hit minus B's startup, known and below zero,
kept with the number. followup_after_drive_rush is structure: a derivation
comes out of its parent with nothing in between, and a rush is in between.
A starter the source lists without a Drive Rush Cancel is counted once above
rather than once per target.

## Route candidates

- routes                  699
- graph nodes             50
- graph edges             409
- folded canonical variants 2524  (same buttons, unresolved action id)
- search complete         true
  length 2               183
  length 3               516

dropped by a search bound (not by the game):
  max_repeat_per_action    6

## Top 10 by predicted damage

Predicted damage is an UNSCALED frame-table sum. Combo scaling appears in no
frame table and neither does Modern's own damage reduction, so this is an
upper bound for ordering, never a damage figure.

#   route                                            dmg~   cost conf    unknowns
1   3 + 强 > 2 + 强 > 236236 + 强                 5700   10.9 low     8
2   3 + 强 > 2 + 强 > 2 + SP + 强                 5700    8.5 low     8
3   3 + 强 > 中 > 236236 + 强                     5600   10.4 low     8
4   3 + 强 > 中 > 2 + SP + 强                     5600    8.0 low     8
5   3 + 强 > 2 + 中 > 236236 + 强                 5400   10.9 low     8
6   3 + 强 > 2 + 中 > 2 + SP + 强                 5400    8.5 low     8
7   弱 > 3 + 强 > 236236 + 强                     5200   10.4 low     8
8   弱 > 3 + 强 > 2 + SP + 强                     5200    8.0 low     8
9   2 + 弱 > 3 + 强 > 236236 + 强                 5200   10.9 low     8
10  2 + 弱 > 3 + 强 > 2 + SP + 强                 5200    8.5 low     8

## Top 10 by predicted scaled damage (model)

A MODEL, NOT A DAMAGE FIGURE. Each move's frame-table damage times a
per-move factor from public descriptions of SF6 scaling (sf6-public-scaling-v1,
verified = false): 100/100/80/70.. per move, a light-normal starter
100/80/70.., floor 10%, x0.85 after a Drive Rush, x0.8 on SP moves, and
the Super Art minimum. Not modelled: 9 things, listed in
scaling_model.not_modelled on every route. Used for ordering only.

#   route                                         scaled~     dmg~   cost conf   
1   3 + 强 > 236236 + 强                           4900     4900    8.9 low    
2   3 + 强 > 2 + 强 > 236236 + 强                 4900     5700   10.9 low    
3   2 + 强 > 236236 + 强                           4800     4800    8.9 low    
4   3 + 强 > 中 > 236236 + 强                     4800     5600   10.4 low    
5   中 > 236236 + 强                               4700     4700    8.4 low    
6   3 + 强 > 2 + 中 > 236236 + 强                 4600     5400   10.9 low    
7   2 + 中 > 236236 + 强                           4500     4500    8.9 low    
8   3 + 强 > 弱 > 236236 + 强                     4400     5200   10.4 low    
9   3 + 强 > 2 + 弱 > 236236 + 强                 4400     5200   10.9 low    
10  3 + 强 > 2 + 强 > 2 + SP + 强                 4260     5700    8.5 low    

## Top 10 by fewest inputs

#   route                                            dmg~   cost conf   
1   弱 > 弱                                         600    2.5 medium 
2   弱 > 中                                        1000    3.0 medium 
3   弱 > 强                                        1200    3.0 medium 
4   中 > > 中                                       700    3.0 medium 
5   中 > > 强                                       700    3.0 medium 
6   弱 > 2 + 弱                                     600    3.5 medium 
7   弱 > 2 + 强                                    1100    3.5 medium 
8   弱 > 2 + 中                                     800    3.5 medium 
9   弱 > 3 + 强                                    1200    3.5 medium 
10  弱 > 6 + 强                                    1100    3.5 medium 

## Pareto frontier: 10 routes nothing beats on both damage and inputs

1   3 + 强 > 2 + 强 > 2 + SP + 强                 5700    8.5
2   3 + 强 > 中 > 2 + SP + 强                     5600    8.0
3   弱 > 中 > 2 + SP + 强                         5000    7.5
4   3 + 强 > 2 + SP + 强                           4900    6.5
5   中 > 2 + SP + 强                               4700    6.0
6   中 > SP + 强                                   2700    5.5
7   弱 > 3 + 强 > 强                              2100    5.0
8   3 + 强 > 强                                    1800    3.5
9   弱 > 强                                        1200    3.0
10  弱 > 弱                                         600    2.5

## Why the game still has to answer

- **actual_input_timing**
  the actual input window is what the sweep exists to measure
- **cancel_window_conditions**
  cancel windows into specials and supers have conditions no frame table lists
- **frame_data_variant_ambiguous**
  the frame source lists "236236P" 2 times - Rising Fang / Rising Fang (CA) - and the join took whichever came first; which one the input produces depends on something the frame table does not model
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

- candidates/terry/modern/candidate-edges.json  (534250 bytes)
- candidates/terry/modern/candidate-routes.json  (4848956 bytes)
- reframework/data/ComboExplorer_data/worklist/terry-modern-drc.json  (60132 bytes)
- reframework/data/ComboExplorer_data/worklist/terry-modern.json  (168520 bytes)

Both documents carry runtime_verified = false and every record in them is
status = theoretical. The next step is the gaming machine: calibration,
then a sweep, then these become confirmed edges or rejected ones.
