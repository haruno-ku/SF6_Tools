# Offline candidate report - Ed / modern / midscreen / none

EVERYTHING BELOW IS A THEORETICAL CANDIDATE. Nothing here has been run on
Street Fighter 6. These are pairs and sequences worth spending a trial on,
not combos that are known to work.

## Provenance

- command_display: Ed, generated 2026-08-03T00:00:00.000Z
  - ac_sha256  d14a103a006e85bdd8cf04f5f51e0ec1931381127cfe86c3b0b75bbb355a6917
  - bcm_sha256 0dcd0071c2e771c5b90ef8503a5c45e5c5effed2af4ba9a0b5d20885e9ecc13f
- frame data: RyoSogawa/sf6-sensei @ a64f2acf90fffc855ddc1a958a4ee752e15c571c (CC-BY-SA)
  - original work: SuperCombo Wiki, CC-BY-SA-4.0. See docs/NOTICE.md.
- game patch: command_display@2026-08-03T00:00:00.000Z
  (the command_display generation date, not a confirmed game version - the real patch is only knowable on the machine running the game)

## Moves searched

- catalog rows            82
- starting moves          13  (normal,command_normal / manual)
- target moves            41  (normal,command_normal,special,od_special,super / manual,simple)
- excluded from probing   34  (classic-only, air, throws, system, follow-ups)
- frame data coverage     40 of 46 (87%)  over every row this run uses
    starters      13 of  13 (100%)
    targets       40 of  41 ( 98%)
    follow-ups     0 of   5 (  0%)
    4 matched only by guessing between several source spellings:
      236236+P (1224) -> 236236P
      236236+P (1224) -> 236236P
      236236+P (1228) -> 236236P
      236236+P (1228) -> 236236P
    6 with no frame data at all:
      6+MP (911)
      >LK (674)
      >LK (675)
      >MK (677)
      >HP (678)
      >HP (683)
- unresolved canonical ids 11 groups covering 25 rows
- no Modern form at all     6
    634  2+LK
    639  2+MK
    852  6
    904  6+MP
    993  44
    1212  214214+HP

## Theoretical edges

- pairs considered        598
- candidate edges         336
- excluded                262

by reason:
  chain_cancel             70
  frame_data_incomplete    64
  frame_link               59
  special_cancel           102
  super_cancel             60
  target_combo             5

by confidence:
  high                     143
  medium                   101
  low                      92

excluded because the data said no:
  followup_after_a_move_not_its_parent 60
  frame_margin_negative    194
  self_pair_without_chain  8

Nothing was excluded for missing data. A gap in the source is recorded as
an unknown and the pair stays a candidate; only a KNOWN negative margin
excludes, and the margin is kept with it.

followup_after_a_move_not_its_parent is not a gap either. The frame source spells
a follow-up only as a chain from the move it comes out of ("5MP~MP"), so
these 60 pairs put a follow-up after a move the source says it does not
follow. A follow-up whose parent the source never names stays a candidate.

- follow-up edges         5  (parent named by the frame data: 5)

## Drive Rush Cancel candidates

A -> Drive Rush Cancel -> B. NONE OF THESE CAN BE PRESSED YET: how Drive
Rush is input on this build and which action id a Drive Rush Cancel is
have never been measured. They are not in the route search below, and with
--worklist they go to their own file, which the sweep does not read.

- DRC record              "MPMK or 66": startup 9, recovery 15, drive cost 30000
- starters that can rush  6  (drc_on_hit in the frame data)
- starters nobody knows   0  (no record, or a guessed one: kept, low)
- starters that cannot    7  (record present, no Drive Rush Cancel in it)
    617:manual 弱
    623:manual 2 + 弱
    624:manual 2 + 弱
    625:manual 2 + 弱
    631:manual 3 + 强
    665:manual 6 + 强
    992:manual 4 + 弱 + 强 或 4 + THROW
- pairs considered        276
- DRC edges               108
- excluded                168

by confidence:
  high                     38
  medium                   46
  low                      24

excluded:
  drc_margin_negative      138
  followup_after_drive_rush 30

drc_margin_negative is drc_on_hit minus B's startup, known and below zero,
kept with the number. followup_after_drive_rush is structure: a derivation
comes out of its parent with nothing in between, and a rush is in between.
A starter the source lists without a Drive Rush Cancel is counted once above
rather than once per target.

## Route candidates

- routes                  1245
- graph nodes             46
- graph edges             336
- folded canonical variants 1755  (same buttons, unresolved action id)
- search complete         true
  length 2               216
  length 3               1029

dropped by a search bound (not by the game):
  max_repeat_per_action    5

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
9   强 > 2 + 中 > 236236 + 强                     5300   10.4 low     7
10  强 > 2 + 中 > 2 + SP + 强                     5300    8.0 low     7

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
9   强 > 2 + 中 > 236236 + 强                     4500     5300   10.4 low    
10  2 + 中 > 236236 + 强                           4500     4500    8.9 low    

## Top 10 by fewest inputs

#   route                                            dmg~   cost conf   
1   弱 > 弱                                         600    2.5 medium 
2   弱 > 中                                         900    3.0 medium 
3   弱 > 强                                        1100    3.0 medium 
4   弱 > > 弱                                       300    3.0 medium 
5   中 > > 中                                       600    3.0 medium 
6   强 > 弱                                        1100    3.0 high   
7   弱 > 2 + 弱                                     500    3.5 medium 
8   弱 > 2 + 中                                     800    3.5 medium 
9   弱 > 3 + 强                                    1200    3.5 medium 
10  弱 > 2 + 强                                    1100    3.5 medium 

## Pareto frontier: 11 routes nothing beats on both damage and inputs

1   3 + 强 > 强 > 2 + SP + 强                     5700    8.0
2   弱 > 强 > 2 + SP + 强                         5100    7.5
3   3 + 强 > 2 + SP + 强                           4900    6.5
4   强 > 2 + SP + 强                               4800    6.0
5   3 + 强 > 强 > 2 + 中                          2200    5.5
6   弱 > 3 + 强 > 强                              2000    5.0
7   强 > 弱 > 强                                  1900    4.5
8   3 + 强 > 6 + 强                                1800    4.0
9   3 + 强 > 强                                    1700    3.5
10  弱 > 强                                        1100    3.0

## Why the game still has to answer

- **actual_input_timing**
  the actual input window is what the sweep exists to measure
- **cancel_window_conditions**
  cancel windows into specials and supers have conditions no frame table lists
- **frame_data_variant_ambiguous**
  the frame source lists "236236P" 2 times - Psycho Chamber / Psycho Chamber (CA) - and the join took whichever came first; which one the input produces depends on something the frame table does not model
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

## Catalog entries the classifier could not place: 16

  681  classic_modern but no Modern command form
  681  simple_command names neither SP nor AUTO
  902  classic_modern but no Modern command form
  902  simple_command names neither SP nor AUTO
  906  classic_modern but no Modern command form
  906  simple_command names neither SP nor AUTO
  909  classic_modern but no Modern command form
  909  simple_command names neither SP nor AUTO
  913  classic_modern but no Modern command form
  913  simple_command names neither SP nor AUTO

## Written

- candidates/ed/modern/candidate-edges.json  (437446 bytes)
- candidates/ed/modern/candidate-routes.json  (8604474 bytes)
- reframework/data/ComboExplorer_data/worklist/ed-modern-drc.json  (51696 bytes)
- reframework/data/ComboExplorer_data/worklist/ed-modern.json  (133969 bytes)

Both documents carry runtime_verified = false and every record in them is
status = theoretical. The next step is the gaming machine: calibration,
then a sweep, then these become confirmed edges or rejected ones.
