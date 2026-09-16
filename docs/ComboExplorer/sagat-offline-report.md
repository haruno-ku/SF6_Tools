# Offline candidate report - Sagat / modern / midscreen / none

EVERYTHING BELOW IS A THEORETICAL CANDIDATE. Nothing here has been run on
Street Fighter 6. These are pairs and sequences worth spending a trial on,
not combos that are known to work.

## Provenance

- command_display: Sagat, generated 2026-08-03T00:00:00.000Z
  - ac_sha256  424195e69fc11d9f0738c712bb85f24cbcb90a653c1e8ada0a7f87dda0bc89e2
  - bcm_sha256 d41344a360bc152e203f01fd4690109b461005945fbdc409358f31ec0e200706
- frame data: RyoSogawa/sf6-sensei @ a64f2acf90fffc855ddc1a958a4ee752e15c571c (CC-BY-SA)
  - original work: SuperCombo Wiki, CC-BY-SA-4.0. See docs/NOTICE.md.
- game patch: command_display@2026-08-03T00:00:00.000Z
  (the command_display generation date, not a confirmed game version - the real patch is only knowable on the machine running the game)

## Moves searched

- catalog rows            100
- starting moves          15  (normal,command_normal / manual)
- target moves            47  (normal,command_normal,special,od_special,super / manual,simple)
- excluded from probing   45  (followup 16, system 12, air 6, ac_state 3, any_button 3, assist_combo 2, throw 2, unclassified 1)
- frame data coverage     47 of 63 (75%)  over every row this run uses
    starters      15 of  15 (100%)
    targets       47 of  47 (100%)
    follow-ups     0 of  16 (  0%)
    8 matched only by guessing between several source spellings:
      236236+K (1228) -> 236236K
      236236+K (1228) -> 236236K
      236236+K (1229) -> 236236K
      236236+K (1229) -> 236236K
      236236+K (1235) -> 236236K
      236236+K (1235) -> 236236K
      236236+K (1236) -> 236236K
      236236+K (1236) -> 236236K
    16 with no frame data at all:
      >HK (608)
      >HK (615)
      >HP (630)
      >HK (631)
      >6+LK (958)
      >6+LK (958)
      >6+MK (960)
      >6+MK (960)
      >6+HK (963)
      >6+HK (963)
      >6+LK (970)
      >6+LK (970)
      >6+MK (972)
      >6+MK (972)
      >6+HK (975)
      >6+HK (975)
- unresolved canonical ids 16 groups covering 39 rows
- no Modern form at all     4
    34  8
    600  LP
    604  MP
    852  6

## Theoretical edges

- pairs considered        945
- candidate edges         412
- excluded                533

by reason:
  chain_cancel             75
  frame_link               134
  special_cancel           160
  super_cancel             96
  target_combo             6

by confidence:
  high                     171
  medium                   169
  low                      72

excluded because the data said no:
  followup_after_a_move_not_its_parent 234
  frame_margin_negative    289
  self_pair_without_chain  10

Nothing was excluded for missing data. A gap in the source is recorded as
an unknown and the pair stays a candidate; only a KNOWN negative margin
excludes, and the margin is kept with it.

followup_after_a_move_not_its_parent is not a gap either. The frame source spells
a follow-up only as a chain from the move it comes out of ("5MP~MP"), so
these 234 pairs put a follow-up after a move the source says it does not
follow. A follow-up whose parent the source never names stays a candidate.

- follow-up edges         6  (parent named by the frame data: 6)

## Drive Rush Cancel candidates

A -> Drive Rush Cancel -> B. NONE OF THESE CAN BE PRESSED YET: how Drive
Rush is input on this build and which action id a Drive Rush Cancel is
have never been measured. They are not in the route search below, and with
--worklist they go to their own file, which the sweep does not read.

- DRC record              "MPMK or 66": startup 9, recovery 15, drive cost 30000
- starters that can rush  8  (drc_on_hit in the frame data)
- starters nobody knows   0  (no record, or a guessed one: kept, low)
- starters that cannot    7  (record present, no Drive Rush Cancel in it)
    606:manual 强
    614:manual 中
    640:manual 2 + 中
    643:manual 3 + 强
    664:manual 6 + 弱
    667:manual 6 + 中
    673:manual 6 + 强
- pairs considered        504
- DRC edges               96
- excluded                408

by confidence:
  high                     21
  medium                   59
  low                      16

excluded:
  drc_margin_negative      280
  followup_after_drive_rush 128

drc_margin_negative is drc_on_hit minus B's startup, known and below zero,
kept with the number. followup_after_drive_rush is structure: a derivation
comes out of its parent with nothing in between, and a rush is in between.
A starter the source lists without a Drive Rush Cancel is counted once above
rather than once per target.

## Route candidates

- routes                  979
- graph nodes             50
- graph edges             412
- folded canonical variants 2722  (same buttons, unresolved action id)
- search complete         true
  length 2               181
  length 3               798

dropped by a search bound (not by the game):
  max_repeat_per_action    5

## Top 10 by predicted damage

Predicted damage is an UNSCALED frame-table sum. Combo scaling appears in no
frame table and neither does Modern's own damage reduction, so this is an
upper bound for ordering, never a damage figure.

#   route                                            dmg~   cost conf    unknowns
1   3 + 强 > 2 + 强 > 236236 + 强                 5700   10.9 low     8
2   3 + 强 > 2 + 强 > 2 + SP + 强                 5700    8.5 low     8
3   弱 > 3 + 强 > 236236 + 强                     5200   10.4 low     8
4   弱 > 3 + 强 > 2 + SP + 强                     5200    8.0 low     8
5   2 + 弱 > 3 + 强 > 236236 + 强                 5200   10.9 low     8
6   2 + 弱 > 3 + 强 > 2 + SP + 强                 5200    8.5 low     8
7   3 + 强 > 弱 > 236236 + 强                     5200   10.4 low     8
8   3 + 强 > 弱 > 2 + SP + 强                     5200    8.0 low     8
9   3 + 强 > 2 + 弱 > 236236 + 强                 5200   10.9 low     8
10  3 + 强 > 2 + 弱 > 2 + SP + 强                 5200    8.5 low     8

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
4   3 + 强 > 弱 > 236236 + 强                     4400     5200   10.4 low    
5   3 + 强 > 2 + 弱 > 236236 + 强                 4400     5200   10.9 low    
6   6 + 强 > 弱 > 236236 + 强                     4400     5200   10.4 low    
7   6 + 强 > 2 + 弱 > 236236 + 强                 4400     5200   10.9 low    
8   3 + 强 > 4 + 强 > 236236 + 强                 4300     5100   10.9 low    
9   4 + 强 > 3 + 强 > 236236 + 强                 4300     5100   10.9 low    
10  3 + 强 > 2 + 强 > 2 + SP + 强                 4260     5700    8.5 low    

## Top 10 by fewest inputs

#   route                                            dmg~   cost conf   
1   弱 > 弱                                         600    2.5 medium 
2   弱 > 强                                        1100    3.0 medium 
3   弱 > 中                                        1000    3.0 medium 
4   强 > > 强                                       800    3.0 medium 
5   强 > > 中                                       800    3.0 medium 
6   中 > > 强                                       700    3.0 medium 
7   中 > > 中                                       700    3.0 medium 
8   弱 > 2 + 弱                                     600    3.5 medium 
9   弱 > 2 + 强                                    1100    3.5 medium 
10  弱 > 2 + 中                                     900    3.5 medium 

## Pareto frontier: 10 routes nothing beats on both damage and inputs

1   3 + 强 > 2 + 强 > 2 + SP + 强                 5700    8.5
2   弱 > 3 + 强 > 2 + SP + 强                     5200    8.0
3   3 + 强 > 2 + SP + 强                           4900    6.5
4   弱 > 2 + SP + 强                               4300    6.0
5   弱 > 3 + 强 > 6 + 强                          2100    5.5
6   弱 > 3 + 强 > 强                              2000    5.0
7   3 + 强 > 6 + 强                                1800    4.0
8   3 + 强 > 强                                    1700    3.5
9   弱 > 强                                        1100    3.0
10  弱 > 弱                                         600    2.5

## Why the game still has to answer

- **actual_input_timing**
  the actual input window is what the sweep exists to measure
- **cancel_window_conditions**
  cancel windows into specials and supers have conditions no frame table lists
- **frame_data_variant_ambiguous**
  the frame source lists "236236K" 2 times - Tiger Vanquisher / Tiger Vanquisher (CA) - and the join took whichever came first; which one the input produces depends on something the frame table does not model
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

  923  classic_modern but no Modern command form
  923  simple_command names neither SP nor AUTO

## Written

- candidates/sagat/modern/candidate-edges.json  (540212 bytes)
- candidates/sagat/modern/candidate-routes.json  (6813113 bytes)
- reframework/data/ComboExplorer_data/worklist/sagat-modern-drc.json  (45886 bytes)
- reframework/data/ComboExplorer_data/worklist/sagat-modern.json  (169093 bytes)

Both documents carry runtime_verified = false and every record in them is
status = theoretical. The next step is the gaming machine: calibration,
then a sweep, then these become confirmed edges or rejected ones.
