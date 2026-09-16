# Offline candidate report - Guile / modern / midscreen / none

EVERYTHING BELOW IS A THEORETICAL CANDIDATE. Nothing here has been run on
Street Fighter 6. These are pairs and sequences worth spending a trial on,
not combos that are known to work.

## Provenance

- command_display: Guile, generated 2026-08-03T00:00:00.000Z
  - ac_sha256  1ca99c13d2d24bff931ea6bb3c8cec6d6b50ad589a806b1f4588d0ac780f62d6
  - bcm_sha256 19e1c629dcb6054b7ffeae86213a70eed997d3dee55b773450625f8df0d48c3c
- frame data: RyoSogawa/sf6-sensei @ a64f2acf90fffc855ddc1a958a4ee752e15c571c (CC-BY-SA)
  - original work: SuperCombo Wiki, CC-BY-SA-4.0. See docs/NOTICE.md.
- game patch: command_display@2026-08-03T00:00:00.000Z
  (the command_display generation date, not a confirmed game version - the real patch is only knowable on the machine running the game)

## Moves searched

- catalog rows            144
- starting moves          41  (normal,command_normal / manual)
- target moves            94  (normal,command_normal,special,od_special,super / manual,simple)
- excluded from probing   35  (system 11, air 7, any_button 7, followup 3, throw 3, assist_combo 2, unclassified 2)
- frame data coverage     81 of 97 (84%)  over every row this run uses
    starters      31 of  41 ( 76%)
    targets       81 of  94 ( 86%)
    follow-ups     0 of   3 (  0%)
    24 matched only by guessing between several source spellings:
      6+MP (941) -> 6MP
      6+HP (943) -> 6HP
      6+MP (949) -> 6MP
      6+HP (951) -> 6HP
      LP (1215) -> 5LP
      MP (1216) -> 5MP
      HP (1217) -> 5HP
      LP (1218) -> 5LP
      MP (1219) -> 5MP
      HP (1220) -> 5HP
      LP (1224) -> 5LP
      MP (1225) -> 5MP
      HP (1226) -> 5HP
      LP (1227) -> 5LP
      MP (1228) -> 5MP
      HP (1229) -> 5HP
      [4]646+K (1240) -> [4]646K
      [4]646+K (1240) -> [4]646K
      [4]646+K (1241) -> [4]646K
      [4]646+K (1241) -> [4]646K
      [4]646+K (1243) -> [4]646K
      [4]646+K (1243) -> [4]646K
      [4]646+K (1244) -> [4]646K
      [4]646+K (1244) -> [4]646K
    16 with no frame data at all:
      6+LP (939)
      56+LP (940)
      56+MP (942)
      56+HP (944)
      6+LP (947)
      56+LP (948)
      56+MP (950)
      56+HP (952)
      4+PP (1212)
      6+PP (1214)
      6+LP (939)
      6+PP (945)
      6+LP (947)
      >2+MP (627)
      >6 (639)
      >3+HK (654)
- unresolved canonical ids 32 groups covering 98 rows
- no Modern form at all     6
    34  8
    609  HP
    653  3+HK
    665  6+MP
    674  6+HK
    852  6

## Theoretical edges

- pairs considered        3977
- candidate edges         2797
- excluded                1180

by reason:
  chain_cancel             405
  frame_data_incomplete    1384
  frame_link               266
  special_cancel           722
  super_cancel             240
  target_combo             7

by confidence:
  high                     302
  medium                   149
  low                      2346

excluded because the data said no:
  followup_after_a_move_not_its_parent 81
  frame_margin_negative    1077
  self_pair_without_chain  22

Nothing was excluded for missing data. A gap in the source is recorded as
an unknown and the pair stays a candidate; only a KNOWN negative margin
excludes, and the margin is kept with it.

followup_after_a_move_not_its_parent is not a gap either. The frame source spells
a follow-up only as a chain from the move it comes out of ("5MP~MP"), so
these 81 pairs put a follow-up after a move the source says it does not
follow. A follow-up whose parent the source never names stays a candidate.

- follow-up edges         42  (parent named by the frame data: 1)

## Drive Rush Cancel candidates

A -> Drive Rush Cancel -> B. NONE OF THESE CAN BE PRESSED YET: how Drive
Rush is input on this build and which action id a Drive Rush Cancel is
have never been measured. They are not in the route search below, and with
--worklist they go to their own file, which the sweep does not read.

- DRC record              "MPMK or 66": startup 9, recovery 15, drive cost 30000
- starters that can rush  7  (drc_on_hit in the frame data)
- starters nobody knows   26  (no record, or a guessed one: kept, low)
- starters that cannot    8  (record present, no Drive Rush Cancel in it)
    615:manual 中
    618:manual 强
    637:manual 2 + 中
    641:manual 3 + 强
    659:manual 4 + 弱
    662:manual 4 + 中
    668:manual 6 + 强
    671:manual 6 + 中
- pairs considered        3201
- DRC edges               2319
- excluded                882

by confidence:
  high                     114
  medium                   10
  low                      2195

excluded:
  drc_margin_negative      783
  followup_after_drive_rush 99

drc_margin_negative is drc_on_hit minus B's startup, known and below zero,
kept with the number. followup_after_drive_rush is structure: a derivation
comes out of its parent with nothing in between, and a rush is in between.
A starter the source lists without a Drive Rush Cancel is counted once above
rather than once per target.

## Route candidates

- routes                  1178
- graph nodes             96
- graph edges             2797
- folded canonical variants 5619  (same buttons, unresolved action id)
- search complete         false
  beam dropped 78139 partial routes, 0 routes not emitted
  length 2               571
  length 3               607

dropped by a search bound (not by the game):
  max_repeat_per_action    21

## Top 10 by predicted damage

Predicted damage is an UNSCALED frame-table sum. Combo scaling appears in no
frame table and neither does Modern's own damage reduction, so this is an
upper bound for ordering, never a damage figure.

#   route                                            dmg~   cost conf    unknowns
1   3 + 强 > 强 > [4]646 + 强                     5350    8.6 low     8
2   3 + 强 > 强 > [2] + SP + 强                   5350    8.0 low     8
3   3 + 强 > 2 + 强 > [4]646 + 强                 5350    9.1 low     8
4   3 + 强 > 2 + 强 > [2] + SP + 强               5350    8.5 low     8
5   3 + 强 > 4 + 强 > [4]646 + 强                 5250    9.1 low     8
6   3 + 强 > 4 + 强 > [2] + SP + 强               5250    8.5 low     8
7   弱 > 强 > [4]646 + 强                         5200    8.1 low     7
8   弱 > 强 > [2] + SP + 强                       5200    7.5 low     7
9   弱 > 2 + 强 > [4]646 + 强                     5200    8.6 low     7
10  弱 > 2 + 强 > [2] + SP + 强                   5200    8.0 low     7

## Top 10 by predicted scaled damage (model)

A MODEL, NOT A DAMAGE FIGURE. Each move's frame-table damage times a
per-move factor from public descriptions of SF6 scaling (sf6-public-scaling-v1,
verified = false): 100/100/80/70.. per move, a light-normal starter
100/80/70.., floor 10%, x0.85 after a Drive Rush, x0.8 on SP moves, and
the Super Art minimum. Not modelled: 9 things, listed in
scaling_model.not_modelled on every route. Used for ordering only.

#   route                                         scaled~     dmg~   cost conf   
1   2 + 强 > [4]646 + 强                           4900     4900    7.1 low    
2   强 > [4]646 + 强                               4800     4800    6.6 low    
3   4 + 强 > [4]646 + 强                           4800     4800    7.1 low    
4   中 > [4]646 + 强                               4600     4600    6.6 low    
5   3 + 强 > 强 > [4]646 + 强                     4550     5350    8.6 low    
6   3 + 强 > 2 + 强 > [4]646 + 强                 4550     5350    9.1 low    
7   3 + 强 > [4]646 + 强                           4450     4450    7.1 low    
8   3 + 强 > 4 + 强 > [4]646 + 强                 4450     5250    9.1 low    
9   强 > 2 + 弱 > [4]646 + 强                     4300     5100    8.6 low    
10  6 + 强 > 弱 > [4]646 + 强                     4300     5100    8.6 low    

## Top 10 by fewest inputs

#   route                                            dmg~   cost conf   
1   弱 > 弱                                         600    2.5 medium 
2   中 > 弱                                         900    3.0 low    
3   弱 > 中                                        1000    3.0 medium 
4   弱 > 强                                        1100    3.0 medium 
5   中 > 2 + 弱                                     900    3.5 low    
6   弱 > 2 + 弱                                     600    3.5 medium 
7   弱 > 2 + 强                                    1200    3.5 medium 
8   弱 > 2 + 中                                     800    3.5 medium 
9   弱 > > 6 + 中                                   300    3.5 low    
10  弱 > 3 + 强                                     750    3.5 medium 

## Pareto frontier: 10 routes nothing beats on both damage and inputs

1   3 + 强 > 强 > [2] + SP + 强                   5350    8.0
2   弱 > 强 > [2] + SP + 强                       5200    7.5
3   2 + 强 > [2] + SP + 强                         4900    6.5
4   强 > [2] + SP + 强                             4800    6.0
5   强 > [2]8 + 强                                 2100    4.8
6   弱 > 弱 > 2 + 强                              1500    4.5
7   弱 > 弱 > 强                                  1400    4.0
8   3 + 强 > 强                                    1250    3.5
9   弱 > 强                                        1100    3.0
10  弱 > 弱                                         600    2.5

## Why the game still has to answer

- **actual_input_timing**
  the actual input window is what the sweep exists to measure
- **cancel_window_conditions**
  cancel windows into specials and supers have conditions no frame table lists
- **frame_data_variant_ambiguous**
  the frame source lists "[4]646K" 2 times - Crossfire Somersault / Crossfire Somersault (CA) - and the join took whichever came first; which one the input produces depends on something the frame table does not model
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

  607  classic_modern but no Modern command form
  607  simple_command names neither SP nor AUTO
  612  classic_modern but no Modern command form
  612  simple_command names neither SP nor AUTO

## Written

- candidates/guile/modern/candidate-edges.json  (4181661 bytes)
- candidates/guile/modern/candidate-routes.json  (7968515 bytes)
- reframework/data/ComboExplorer_data/worklist/guile-modern-drc.json  (880638 bytes)
- reframework/data/ComboExplorer_data/worklist/guile-modern.json  (975757 bytes)

Both documents carry runtime_verified = false and every record in them is
status = theoretical. The next step is the gaming machine: calibration,
then a sweep, then these become confirmed edges or rejected ones.
