# Offline candidate report - Kimberly / modern / midscreen / none

EVERYTHING BELOW IS A THEORETICAL CANDIDATE. Nothing here has been run on
Street Fighter 6. These are pairs and sequences worth spending a trial on,
not combos that are known to work.

## Provenance

- command_display: Kimberly, generated 2026-08-03T00:00:00.000Z
  - ac_sha256  5cfe7670ec050610df704a90324d7288f46289f71873ea2de6025ca39edde7c6
  - bcm_sha256 d68c61125af9c9cbec2b239fb6b56a5bf15d6dd6e8a5bf01bec29ab3a184b314
- frame data: RyoSogawa/sf6-sensei @ a64f2acf90fffc855ddc1a958a4ee752e15c571c (CC-BY-SA)
  - original work: SuperCombo Wiki, CC-BY-SA-4.0. See docs/NOTICE.md.
- game patch: command_display@2026-08-03T00:00:00.000Z
  (the command_display generation date, not a confirmed game version - the real patch is only knowable on the machine running the game)

## Moves searched

- catalog rows            123
- starting moves          14  (normal,command_normal / manual)
- target moves            47  (normal,command_normal,special,od_special,super / manual,simple)
- excluded from probing   64  (air 18, system 17, any_button 14, followup 11, throw 2, assist_combo 1, unclassified 1)
- frame data coverage     45 of 58 (78%)  over every row this run uses
    starters      14 of  14 (100%)
    targets       45 of  47 ( 96%)
    follow-ups     0 of  11 (  0%)
    4 matched only by guessing between several source spellings:
      236236+P (1220) -> 236236P
      236236+P (1220) -> 236236P
      236236+P (1224) -> 236236P
      236236+P (1224) -> 236236P
    13 with no frame data at all:
      6 (908)
      6 (912)
      >MP (641)
      >HP (642)
      >HK (643)
      >HP (646)
      >2+HP (648)
      >HK (649)
      >2+HK (651)
      >22+MP (977)
      >22+MP (978)
      >j.236+P (1015)
      >j.236+P (1015)
- unresolved canonical ids 30 groups covering 66 rows
- no Modern form at all     11
    606  LK
    613  2+MP
    617  2+LK
    634  j.Normal
    635  j.8
    636  j.9
    655  8
    852  6
    979  >22+HP
    982  >22+LP+HP
    983  >22+MP+HP

## Theoretical edges

- pairs considered        812
- candidate edges         503
- excluded                309

by reason:
  chain_cancel             99
  frame_data_incomplete    84
  frame_link               78
  special_cancel           225
  super_cancel             90
  target_combo             21

by confidence:
  high                     243
  medium                   136
  low                      124

excluded because the data said no:
  followup_after_a_move_not_its_parent 93
  frame_margin_negative    208
  self_pair_without_chain  8

Nothing was excluded for missing data. A gap in the source is recorded as
an unknown and the pair stays a candidate; only a KNOWN negative margin
excludes, and the margin is kept with it.

followup_after_a_move_not_its_parent is not a gap either. The frame source spells
a follow-up only as a chain from the move it comes out of ("5MP~MP"), so
these 93 pairs put a follow-up after a move the source says it does not
follow. A follow-up whose parent the source never names stays a candidate.

- follow-up edges         61  (parent named by the frame data: 5)

## Drive Rush Cancel candidates

A -> Drive Rush Cancel -> B. NONE OF THESE CAN BE PRESSED YET: how Drive
Rush is input on this build and which action id a Drive Rush Cancel is
have never been measured. They are not in the route search below, and with
--worklist they go to their own file, which the sweep does not read.

- DRC record              "MPMK or 66": startup 9, recovery 15, drive cost 30000
- starters that can rush  9  (drc_on_hit in the frame data)
- starters nobody knows   0  (no record, or a guessed one: kept, low)
- starters that cannot    5  (record present, no Drive Rush Cancel in it)
    619:manual 2 + 中
    620:manual 3 + 强
    631:manual 4 + 强
    632:manual 6 + 强
    637:manual 3 + 中
- pairs considered        522
- DRC edges               144
- excluded                378

by confidence:
  high                     85
  medium                   29
  low                      30

excluded:
  drc_margin_negative      279
  followup_after_drive_rush 99

drc_margin_negative is drc_on_hit minus B's startup, known and below zero,
kept with the number. followup_after_drive_rush is structure: a derivation
comes out of its parent with nothing in between, and a rush is in between.
A starter the source lists without a Drive Rush Cancel is counted once above
rather than once per target.

## Route candidates

- routes                  912
- graph nodes             54
- graph edges             503
- folded canonical variants 3520  (same buttons, unresolved action id)
- search complete         true
  length 2               209
  length 3               703

dropped by a search bound (not by the game):
  max_repeat_per_action    6

## Top 10 by predicted damage

Predicted damage is an UNSCALED frame-table sum. Combo scaling appears in no
frame table and neither does Modern's own damage reduction, so this is an
upper bound for ordering, never a damage figure.

#   route                                            dmg~   cost conf    unknowns
1   3 + 强 > 2 + 强 > 236236 + 强                 5530   10.9 low     8
2   3 + 强 > 2 + 强 > 2 + SP + 强                 5530    8.5 low     8
3   3 + 强 > 强 > 236236 + 强                     5440   10.4 low     8
4   3 + 强 > 强 > 2 + SP + 强                     5440    8.0 low     8
5   3 + 强 > 中 > 236236 + 强                     5350   10.4 low     8
6   3 + 强 > 中 > 2 + SP + 强                     5350    8.0 low     8
7   弱 > 3 + 强 > 236236 + 强                     5080   10.4 low     8
8   弱 > 3 + 强 > 2 + SP + 强                     5080    8.0 low     8
9   2 + 弱 > 3 + 强 > 236236 + 强                 5080   10.9 low     8
10  2 + 弱 > 3 + 强 > 2 + SP + 强                 5080    8.5 low     8

## Top 10 by predicted scaled damage (model)

A MODEL, NOT A DAMAGE FIGURE. Each move's frame-table damage times a
per-move factor from public descriptions of SF6 scaling (sf6-public-scaling-v1,
verified = false): 100/100/80/70.. per move, a light-normal starter
100/80/70.., floor 10%, x0.85 after a Drive Rush, x0.8 on SP moves, and
the Super Art minimum. Not modelled: 9 things, listed in
scaling_model.not_modelled on every route. Used for ordering only.

#   route                                         scaled~     dmg~   cost conf   
1   3 + 强 > 236236 + 强                           4810     4810    8.9 low    
2   3 + 强 > 2 + 强 > 236236 + 强                 4730     5530   10.9 low    
3   2 + 强 > 236236 + 强                           4720     4720    8.9 low    
4   3 + 强 > 强 > 236236 + 强                     4640     5440   10.4 low    
5   强 > 236236 + 强                               4630     4630    8.4 low    
6   3 + 强 > 中 > 236236 + 强                     4550     5350   10.4 low    
7   中 > 236236 + 强                               4540     4540    8.4 low    
8   3 + 强 > 弱 > 236236 + 强                     4280     5080   10.4 low    
9   3 + 强 > 2 + 弱 > 236236 + 强                 4280     5080   10.9 low    
10  4 + 强 > 2 + 弱 > 236236 + 强                 4190     4990   10.9 low    

## Top 10 by fewest inputs

#   route                                            dmg~   cost conf   
1   弱 > 弱                                         540    2.5 medium 
2   弱 > 中                                         810    3.0 medium 
3   弱 > 强                                         900    3.0 medium 
4   弱 > > 弱                                       270    3.0 medium 
5   中 > > 弱                                       540    3.0 medium 
6   中 > > 中                                       540    3.0 medium 
7   弱 > 2 + 弱                                     540    3.5 medium 
8   弱 > 2 + 强                                     990    3.5 medium 
9   弱 > 2 + 中                                     810    3.5 medium 
10  弱 > 3 + 强                                    1080    3.5 medium 

## Pareto frontier: 11 routes nothing beats on both damage and inputs

1   3 + 强 > 2 + 强 > 2 + SP + 强                 5530    8.5
2   3 + 强 > 强 > 2 + SP + 强                     5440    8.0
3   弱 > 强 > 2 + SP + 强                         4900    7.5
4   3 + 强 > 2 + SP + 强                           4810    6.5
5   强 > 2 + SP + 强                               4630    6.0
6   强 > SP + 强                                   2430    5.5
7   弱 > 3 + 强 > 强                              1710    5.0
8   3 + 强 > 2 + 强                                1530    4.0
9   3 + 强 > 强                                    1440    3.5
10  弱 > 强                                         900    3.0

## Why the game still has to answer

- **actual_input_timing**
  the actual input window is what the sweep exists to measure
- **cancel_window_conditions**
  cancel windows into specials and supers have conditions no frame table lists
- **frame_data_variant_ambiguous**
  the frame source lists "236236P" 2 times - Bushin Ninjastar Cypher / Bushin Ninjastar Cypher (CA) - and the join took whichever came first; which one the input produces depends on something the frame table does not model
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

  902  classic_modern but no Modern command form
  902  simple_command names neither SP nor AUTO
  905  classic_modern but no Modern command form
  905  simple_command names neither SP nor AUTO
  909  simple_command names neither SP nor AUTO
  911  simple_command names neither SP nor AUTO
  913  simple_command names neither SP nor AUTO
  920  classic_modern but no Modern command form
  920  simple_command names neither SP nor AUTO
  924  simple_command names neither SP nor AUTO

## Written

- candidates/kimberly/modern/candidate-edges.json  (657491 bytes)
- candidates/kimberly/modern/candidate-routes.json  (6355608 bytes)
- reframework/data/ComboExplorer_data/worklist/kimberly-modern-drc.json  (67932 bytes)
- reframework/data/ComboExplorer_data/worklist/kimberly-modern.json  (204489 bytes)

Both documents carry runtime_verified = false and every record in them is
status = theoretical. The next step is the gaming machine: calibration,
then a sweep, then these become confirmed edges or rejected ones.
