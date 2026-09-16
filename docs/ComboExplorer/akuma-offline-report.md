# Offline candidate report - Akuma / modern / midscreen / none

EVERYTHING BELOW IS A THEORETICAL CANDIDATE. Nothing here has been run on
Street Fighter 6. These are pairs and sequences worth spending a trial on,
not combos that are known to work.

## Provenance

- command_display: Akuma, generated 2026-08-03T00:00:00.000Z
  - ac_sha256  48ca8bf84eb7ef41f87bb1b769a4b6f312b9023d137fbebb0bab981fc2b136e2
  - bcm_sha256 ee4cdee5f4d07194121f179a9fa82e8c46ac368beb1503f38d1abca0613fe3de
- frame data: RyoSogawa/sf6-sensei @ a64f2acf90fffc855ddc1a958a4ee752e15c571c (CC-BY-SA)
  - original work: SuperCombo Wiki, CC-BY-SA-4.0. See docs/NOTICE.md.
- game patch: command_display@2026-08-03T00:00:00.000Z
  (the command_display generation date, not a confirmed game version - the real patch is only knowable on the machine running the game)

## Moves searched

- catalog rows            116
- starting moves          18  (normal,command_normal / manual)
- target moves            56  (normal,command_normal,special,od_special,super / manual,simple)
- excluded from probing   52  (air 20, system 13, any_button 9, followup 4, throw 3, assist_combo 2, unclassified 1)
- frame data coverage     54 of 60 (90%)  over every row this run uses
    starters      16 of  18 ( 89%)
    targets       54 of  56 ( 96%)
    follow-ups     0 of   4 (  0%)
    8 matched only by guessing between several source spellings:
      236236+K (1220) -> 236236K
      236236+K (1220) -> 236236K
      236236+K (1221) -> 236236K
      236236+K (1221) -> 236236K
      236236+K (1225) -> 236236K
      236236+K (1225) -> 236236K
      236236+K (1226) -> 236236K
      236236+K (1226) -> 236236K
    6 with no frame data at all:
      5565+HP (1231)
      2+LP+MP+HP+LK+MK+HK (1495)
      >MP (606)
      >HK (615)
      >6+HP (668)
      >HK (670)
- unresolved canonical ids 19 groups covering 47 rows
- no Modern form at all     8
    622  2+LP
    627  2+MP
    661  6+MP
    852  6
    982  6+P
    985  6+P
    989  236+LK
    991  236+HK

## Theoretical edges

- pairs considered        1080
- candidate edges         822
- excluded                258

by reason:
  chain_cancel             108
  frame_data_incomplete    278
  frame_link               146
  special_cancel           231
  super_cancel             170
  target_combo             3

by confidence:
  high                     270
  medium                   186
  low                      366

excluded because the data said no:
  followup_after_a_move_not_its_parent 69
  frame_margin_negative    179
  self_pair_without_chain  10

Nothing was excluded for missing data. A gap in the source is recorded as
an unknown and the pair stays a candidate; only a KNOWN negative margin
excludes, and the margin is kept with it.

followup_after_a_move_not_its_parent is not a gap either. The frame source spells
a follow-up only as a chain from the move it comes out of ("5MP~MP"), so
these 69 pairs put a follow-up after a move the source says it does not
follow. A follow-up whose parent the source never names stays a candidate.

- follow-up edges         3  (parent named by the frame data: 3)

## Drive Rush Cancel candidates

A -> Drive Rush Cancel -> B. NONE OF THESE CAN BE PRESSED YET: how Drive
Rush is input on this build and which action id a Drive Rush Cancel is
have never been measured. They are not in the route search below, and with
--worklist they go to their own file, which the sweep does not read.

- DRC record              "MPMK or 66": startup 9, recovery 15, drive cost 30000
- starters that can rush  10  (drc_on_hit in the frame data)
- starters nobody knows   2  (no record, or a guessed one: kept, low)
- starters that cannot    6  (record present, no Drive Rush Cancel in it)
    635:manual 2 + 弱
    643:manual 3 + 强
    664:manual 6 + 中
    667:manual 6 + 强
    1075:manual 6 + 弱 + 中 + 强
    1081:manual 4 + 弱 + 中 + 强
- pairs considered        720
- DRC edges               408
- excluded                312

by confidence:
  high                     71
  medium                   145
  low                      192

excluded:
  drc_margin_negative      264
  followup_after_drive_rush 48

drc_margin_negative is drc_on_hit minus B's startup, known and below zero,
kept with the number. followup_after_drive_rush is structure: a derivation
comes out of its parent with nothing in between, and a rush is in between.
A starter the source lists without a Drive Rush Cancel is counted once above
rather than once per target.

## Route candidates

- routes                  1520
- graph nodes             59
- graph edges             822
- folded canonical variants 3302  (same buttons, unresolved action id)
- search complete         false
  beam dropped 7546 partial routes, 0 routes not emitted
  length 2               464
  length 3               1056

dropped by a search bound (not by the game):
  max_repeat_per_action    8

## Top 10 by predicted damage

Predicted damage is an UNSCALED frame-table sum. Combo scaling appears in no
frame table and neither does Modern's own damage reduction, so this is an
upper bound for ordering, never a damage figure.

#   route                                            dmg~   cost conf    unknowns
1   2 + 强 > 236236 + 强                           4900    8.9 low     7
2   2 + 强 > 2 + SP + 强                           4900    6.5 low     7
3   3 + 强 > 236236 + 强                           4900    8.9 low     8
4   3 + 强 > 2 + SP + 强                           4900    6.5 low     8
5   强 > 236236 + 强                               4800    8.4 low     7
6   强 > 2 + SP + 强                               4800    6.0 low     7
7   4 + 强 > 236236 + 强                           4800    8.9 low     8
8   4 + 强 > 2 + SP + 强                           4800    6.5 low     8
9   中 > 236236 + 强                               4700    8.4 low     7
10  中 > 2 + SP + 强                               4700    6.0 low     7

## Top 10 by predicted scaled damage (model)

A MODEL, NOT A DAMAGE FIGURE. Each move's frame-table damage times a
per-move factor from public descriptions of SF6 scaling (sf6-public-scaling-v1,
verified = false): 100/100/80/70.. per move, a light-normal starter
100/80/70.., floor 10%, x0.85 after a Drive Rush, x0.8 on SP moves, and
the Super Art minimum. Not modelled: 9 things, listed in
scaling_model.not_modelled on every route. Used for ordering only.

#   route                                         scaled~     dmg~   cost conf   
1   2 + 强 > 236236 + 强                           4900     4900    8.9 low    
2   3 + 强 > 236236 + 强                           4900     4900    8.9 low    
3   强 > 236236 + 强                               4800     4800    8.4 low    
4   4 + 强 > 236236 + 强                           4800     4800    8.9 low    
5   中 > 236236 + 强                               4700     4700    8.4 low    
6   2 + 中 > 236236 + 强                           4500     4500    8.9 low    
7   3 + 强 > 2 + 强 > 22 + 中 + 强               4120     4700    7.8 medium 
8   2 + 强 > 2 + SP + 强                           4100     4900    6.5 low    
9   3 + 强 > 2 + SP + 强                           4100     4900    6.5 low    
10  3 + 强 > 2 + 强 > 214214 + 中                 4040     4600   10.9 medium 

## Top 10 by fewest inputs

#   route                                            dmg~   cost conf   
1   弱 > 弱                                         600    2.5 medium 
2   弱 > 强                                        1100    3.0 medium 
3   弱 > 中                                        1000    3.0 medium 
4   中 > > 强                                       700    3.0 medium 
5   弱 > 2 + 弱                                     600    3.5 medium 
6   弱 > 2 + 强                                    1200    3.5 medium 
7   弱 > 2 + 中                                     800    3.5 medium 
8   弱 > 3 + 强                                    1200    3.5 medium 
9   弱 > 6 + 中                                    1000    3.5 medium 
10  弱 > 6 + 强                                    1100    3.5 medium 

## Pareto frontier: 9 routes nothing beats on both damage and inputs

1   2 + 强 > 2 + SP + 强                           4900    6.5
2   强 > 2 + SP + 强                               4800    6.0
3   2 + 强 > 22 + 中 + 强                         3800    5.8
4   强 > 22 + 中 + 强                             3700    5.3
5   弱 > 3 + 强 > 强                              2000    5.0
6   3 + 强 > 2 + 强                                1800    4.0
7   3 + 强 > 强                                    1700    3.5
8   弱 > 强                                        1100    3.0
9   弱 > 弱                                         600    2.5

## Why the game still has to answer

- **actual_input_timing**
  the actual input window is what the sweep exists to measure
- **cancel_window_conditions**
  cancel windows into specials and supers have conditions no frame table lists
- **frame_data_variant_ambiguous**
  the frame source lists "236236K" 2 times - Sip of Calamity / Sip of Calamity (CA) - and the join took whichever came first; which one the input produces depends on something the frame table does not model
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

  984  classic_modern but no Modern command form
  984  simple_command names neither SP nor AUTO
  986  classic_modern but no Modern command form
  986  simple_command names neither SP nor AUTO
  998  classic_modern but no Modern command form
  998  simple_command names neither SP nor AUTO
  999  classic_modern but no Modern command form
  999  simple_command names neither SP nor AUTO
  1000  classic_modern but no Modern command form
  1000  simple_command names neither SP nor AUTO

## Written

- candidates/akuma/modern/candidate-edges.json  (1070885 bytes)
- candidates/akuma/modern/candidate-routes.json  (10366408 bytes)
- reframework/data/ComboExplorer_data/worklist/akuma-modern-drc.json  (170783 bytes)
- reframework/data/ComboExplorer_data/worklist/akuma-modern.json  (306091 bytes)

Both documents carry runtime_verified = false and every record in them is
status = theoretical. The next step is the gaming machine: calibration,
then a sweep, then these become confirmed edges or rejected ones.
