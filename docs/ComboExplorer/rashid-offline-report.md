# Offline candidate report - Rashid / modern / midscreen / none

EVERYTHING BELOW IS A THEORETICAL CANDIDATE. Nothing here has been run on
Street Fighter 6. These are pairs and sequences worth spending a trial on,
not combos that are known to work.

## Provenance

- command_display: Rashid, generated 2026-08-03T00:00:00.000Z
  - ac_sha256  9faa158243bc4e58b99c17eecb2f1f2eee60f6b56c6ac1fe4cd7f250116a854a
  - bcm_sha256 3cfe76d91c024d0cbe5fb0d35d4b4d6526093a935822bd0a315dc1fdcaf7f041
- frame data: RyoSogawa/sf6-sensei @ a64f2acf90fffc855ddc1a958a4ee752e15c571c (CC-BY-SA)
  - original work: SuperCombo Wiki, CC-BY-SA-4.0. See docs/NOTICE.md.
- game patch: command_display@2026-08-03T00:00:00.000Z
  (the command_display generation date, not a confirmed game version - the real patch is only knowable on the machine running the game)

## Moves searched

- catalog rows            135
- starting moves          14  (normal,command_normal / manual)
- target moves            54  (normal,command_normal,special,od_special,super / manual,simple)
- excluded from probing   72  (air 39, system 11, followup 10, any_button 4, ac_state 2, assist_combo 2, throw 2, unclassified 2)
- frame data coverage     54 of 64 (84%)  over every row this run uses
    starters      14 of  14 (100%)
    targets       54 of  54 (100%)
    follow-ups     0 of  10 (  0%)
    5 matched only by guessing between several source spellings:
      6+KK (700) -> 6KK
      236236+P (1216) -> 236236P
      236236+P (1216) -> 236236P
      236236+P (1220) -> 236236P
      236236+P (1220) -> 236236P
    10 with no frame data at all:
      >6+K (974)
      >6+K (974)
      >6+K (974)
      >K (975)
      >K (975)
      >K (975)
      >4+K (976)
      >6+P (995)
      >6+K (998)
      >6+K (1015)
- unresolved canonical ids 35 groups covering 92 rows
- no Modern form at all     4
    595  8
    623  2+MP
    666  6+HK
    852  6

## Theoretical edges

- pairs considered        896
- candidate edges         495
- excluded                401

by reason:
  chain_cancel             84
  frame_data_incomplete    53
  frame_link               91
  special_cancel           224
  super_cancel             64

by confidence:
  high                     256
  medium                   144
  low                      95

excluded because the data said no:
  followup_after_a_move_not_its_parent 140
  frame_margin_negative    253
  self_pair_without_chain  8

Nothing was excluded for missing data. A gap in the source is recorded as
an unknown and the pair stays a candidate; only a KNOWN negative margin
excludes, and the margin is kept with it.

followup_after_a_move_not_its_parent is not a gap either. The frame source spells
a follow-up only as a chain from the move it comes out of ("5MP~MP"), so
these 140 pairs put a follow-up after a move the source says it does not
follow. A follow-up whose parent the source never names stays a candidate.

## Drive Rush Cancel candidates

A -> Drive Rush Cancel -> B. NONE OF THESE CAN BE PRESSED YET: how Drive
Rush is input on this build and which action id a Drive Rush Cancel is
have never been measured. They are not in the route search below, and with
--worklist they go to their own file, which the sweep does not read.

- DRC record              "MPMK or 66": startup 9, recovery 15, drive cost 30000
- starters that can rush  7  (drc_on_hit in the frame data)
- starters nobody knows   1  (no record, or a guessed one: kept, low)
- starters that cannot    6  (record present, no Drive Rush Cancel in it)
    612:manual 中
    615:manual 强
    626:manual 2 + 强
    629:manual 2 + 弱
    637:manual 3 + 强
    665:manual 6 + 强
- pairs considered        512
- DRC edges               131
- excluded                381

by confidence:
  high                     28
  medium                   45
  low                      58

excluded:
  drc_margin_negative      301
  followup_after_drive_rush 80

drc_margin_negative is drc_on_hit minus B's startup, known and below zero,
kept with the number. followup_after_drive_rush is structure: a derivation
comes out of its parent with nothing in between, and a rush is in between.
A starter the source lists without a Drive Rush Cancel is counted once above
rather than once per target.

## Route candidates

- routes                  872
- graph nodes             54
- graph edges             495
- folded canonical variants 3623  (same buttons, unresolved action id)
- search complete         false
  beam dropped 364 partial routes, 0 routes not emitted
  length 2               182
  length 3               690

dropped by a search bound (not by the game):
  max_repeat_per_action    6

## Top 10 by predicted damage

Predicted damage is an UNSCALED frame-table sum. Combo scaling appears in no
frame table and neither does Modern's own damage reduction, so this is an
upper bound for ordering, never a damage figure.

#   route                                            dmg~   cost conf    unknowns
1   3 + 强 > 2 + 强 > 236236 + 强                 5800   10.9 low     8
2   3 + 强 > 2 + 强 > 2 + SP + 强                 5800    8.5 low     8
3   3 + 强 > 2 + 中 > 236236 + 强                 5400   10.9 low     8
4   3 + 强 > 2 + 中 > 2 + SP + 强                 5400    8.5 low     8
5   弱 > 2 + 强 > 236236 + 强                     5200   10.4 low     7
6   弱 > 2 + 强 > 2 + SP + 强                     5200    8.0 low     7
7   弱 > 3 + 强 > 236236 + 强                     5200   10.4 low     8
8   弱 > 3 + 强 > 2 + SP + 强                     5200    8.0 low     8
9   2 + 弱 > 2 + 强 > 236236 + 强                 5200   10.9 low     7
10  2 + 弱 > 2 + 强 > 2 + SP + 强                 5200    8.5 low     7

## Top 10 by predicted scaled damage (model)

A MODEL, NOT A DAMAGE FIGURE. Each move's frame-table damage times a
per-move factor from public descriptions of SF6 scaling (sf6-public-scaling-v1,
verified = false): 100/100/80/70.. per move, a light-normal starter
100/80/70.., floor 10%, x0.85 after a Drive Rush, x0.8 on SP moves, and
the Super Art minimum. Not modelled: 9 things, listed in
scaling_model.not_modelled on every route. Used for ordering only.

#   route                                         scaled~     dmg~   cost conf   
1   3 + 强 > 2 + 强 > 236236 + 强                 5000     5800   10.9 low    
2   2 + 强 > 236236 + 强                           4900     4900    8.9 low    
3   3 + 强 > 236236 + 强                           4900     4900    8.9 low    
4   3 + 强 > 2 + 中 > 236236 + 强                 4600     5400   10.9 low    
5   2 + 中 > 236236 + 强                           4500     4500    8.9 low    
6   2 + 强 > 弱 > 236236 + 强                     4400     5200   10.4 low    
7   2 + 强 > 2 + 弱 > 236236 + 强                 4400     5200   10.9 low    
8   3 + 强 > 弱 > 236236 + 强                     4400     5200   10.4 low    
9   3 + 强 > 2 + 弱 > 236236 + 强                 4400     5200   10.9 low    
10  3 + 强 > 6 + 中 > 236236 + 强                 4400     5200   10.9 low    

## Top 10 by fewest inputs

#   route                                            dmg~   cost conf   
1   弱 > 弱                                         600    2.5 medium 
2   弱 > 中                                         900    3.0 medium 
3   弱 > 强                                        1100    3.0 medium 
4   中 > 弱                                         900    3.0 medium 
5   弱 > 2 + 弱                                     600    3.5 medium 
6   弱 > 2 + 强                                    1200    3.5 medium 
7   弱 > 2 + 中                                     800    3.5 medium 
8   弱 > 3 + 强                                    1200    3.5 medium 
9   弱 > 6 + 中                                     600    3.5 medium 
10  弱 > 6 + 强                                    1100    3.5 medium 

## Pareto frontier: 10 routes nothing beats on both damage and inputs

1   3 + 强 > 2 + 强 > 2 + SP + 强                 5800    8.5
2   弱 > 2 + 强 > 2 + SP + 强                     5200    8.0
3   2 + 强 > 2 + SP + 强                           4900    6.5
4   弱 > 2 + SP + 强                               4300    6.0
5   弱 > SP + 强                                   2400    5.5
6   弱 > 3 + 强 > 强                              2000    5.0
7   3 + 强 > 2 + 强                                1800    4.0
8   3 + 强 > 强                                    1700    3.5
9   弱 > 强                                        1100    3.0
10  弱 > 弱                                         600    2.5

## Why the game still has to answer

- **actual_input_timing**
  the actual input window is what the sweep exists to measure
- **cancel_window_conditions**
  cancel windows into specials and supers have conditions no frame table lists
- **frame_data_variant_ambiguous**
  for the second move, the join took "6KK", whose frame record describes a special, but this row's action id puts it among the throws. The two sources disagree about what move this is, so the numbers may belong to a different one
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

## Catalog entries the classifier could not place: 10

  604  classic_modern but no Modern command form
  604  simple_command names neither SP nor AUTO
  609  classic_modern but no Modern command form
  609  simple_command names neither SP nor AUTO
  1086  classic_modern but no Modern command form
  1086  simple_command names neither SP nor AUTO
  1089  classic_modern but no Modern command form
  1089  simple_command names neither SP nor AUTO
  1090  classic_modern but no Modern command form
  1090  simple_command names neither SP nor AUTO

## Written

- candidates/rashid/modern/candidate-edges.json  (668431 bytes)
- candidates/rashid/modern/candidate-routes.json  (6159870 bytes)
- reframework/data/ComboExplorer_data/worklist/rashid-modern-drc.json  (55533 bytes)
- reframework/data/ComboExplorer_data/worklist/rashid-modern.json  (197304 bytes)

Both documents carry runtime_verified = false and every record in them is
status = theoretical. The next step is the gaming machine: calibration,
then a sweep, then these become confirmed edges or rejected ones.
