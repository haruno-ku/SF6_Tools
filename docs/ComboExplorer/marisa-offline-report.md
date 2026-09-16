# Offline candidate report - Marisa / modern / midscreen / none

EVERYTHING BELOW IS A THEORETICAL CANDIDATE. Nothing here has been run on
Street Fighter 6. These are pairs and sequences worth spending a trial on,
not combos that are known to work.

## Provenance

- command_display: Marisa, generated 2026-08-03T00:00:00.000Z
  - ac_sha256  bf938898975f2df9c4c6180eb348b2a92762f239dbb47908513e7536adc6827f
  - bcm_sha256 f8793c8520e79aab21e666d34f85a396d526ca0c2867f169d93da7dd62ee1e8b
- frame data: RyoSogawa/sf6-sensei @ a64f2acf90fffc855ddc1a958a4ee752e15c571c (CC-BY-SA)
  - original work: SuperCombo Wiki, CC-BY-SA-4.0. See docs/NOTICE.md.
- game patch: command_display@2026-08-03T00:00:00.000Z
  (the command_display generation date, not a confirmed game version - the real patch is only knowable on the machine running the game)

## Moves searched

- catalog rows            89
- starting moves          12  (normal,command_normal / manual)
- target moves            40  (normal,command_normal,special,od_special,super / manual,simple)
- excluded from probing   42  (followup 16, system 11, air 7, any_button 3, assist_combo 2, throw 2, unclassified 1)
- frame data coverage     40 of 56 (71%)  over every row this run uses
    starters      12 of  12 (100%)
    targets       40 of  40 (100%)
    follow-ups     0 of  16 (  0%)
    6 matched only by guessing between several source spellings:
      214+K (952) -> 214K
      214+KK (969) -> 214KK
      236236+K (1213) -> 236236K
      236236+K (1213) -> 236236K
      236236+K (1217) -> 236236K
      236236+K (1217) -> 236236K
    16 with no frame data at all:
      >LP (601)
      >HP (611)
      >HP (612)
      >j.MP (647)
      >HK (667)
      >HP (668)
      >6+HK (674)
      >6+P (924)
      >6+P (924)
      >6+P (927)
      >6+P (927)
      >6+P (930)
      >6+P (930)
      >6+P (933)
      >6+P (933)
      >6+P (933)
- unresolved canonical ids 11 groups covering 28 rows
- no Modern form at all     12
    34  8
    613  LK
    617  HK
    637  2+MK
    678  3+HP
    681  >3+HP
    852  6
    953  Normal
    960  P
    962  K
    964  Throw
    970  Normal

## Theoretical edges

- pairs considered        672
- candidate edges         313
- excluded                359

by reason:
  chain_cancel             36
  frame_data_incomplete    12
  frame_link               109
  special_cancel           120
  super_cancel             48
  target_combo             13

by confidence:
  high                     132
  medium                   116
  low                      65

excluded because the data said no:
  followup_after_a_move_not_its_parent 171
  frame_margin_negative    179
  self_pair_without_chain  9

Nothing was excluded for missing data. A gap in the source is recorded as
an unknown and the pair stays a candidate; only a KNOWN negative margin
excludes, and the margin is kept with it.

followup_after_a_move_not_its_parent is not a gap either. The frame source spells
a follow-up only as a chain from the move it comes out of ("5MP~MP"), so
these 171 pairs put a follow-up after a move the source says it does not
follow. A follow-up whose parent the source never names stays a candidate.

- follow-up edges         21  (parent named by the frame data: 9)

## Drive Rush Cancel candidates

A -> Drive Rush Cancel -> B. NONE OF THESE CAN BE PRESSED YET: how Drive
Rush is input on this build and which action id a Drive Rush Cancel is
have never been measured. They are not in the route search below, and with
--worklist they go to their own file, which the sweep does not read.

- DRC record              "MPMK or 66": startup 9, recovery 15, drive cost 30000
- starters that can rush  6  (drc_on_hit in the frame data)
- starters nobody knows   0  (no record, or a guessed one: kept, low)
- starters that cannot    6  (record present, no Drive Rush Cancel in it)
    600:manual 弱
    607:manual 强
    615:manual 中
    627:manual 2 + 强
    639:manual 3 + 强
    666:manual 6 + 中
- pairs considered        336
- DRC edges               67
- excluded                269

by confidence:
  high                     20
  medium                   27
  low                      20

excluded:
  drc_margin_negative      173
  followup_after_drive_rush 96

drc_margin_negative is drc_on_hit minus B's startup, known and below zero,
kept with the number. followup_after_drive_rush is structure: a derivation
comes out of its parent with nothing in between, and a rush is in between.
A starter the source lists without a Drive Rush Cancel is counted once above
rather than once per target.

## Route candidates

- routes                  803
- graph nodes             47
- graph edges             313
- folded canonical variants 1239  (same buttons, unresolved action id)
- search complete         true
  length 2               200
  length 3               603

dropped by a search bound (not by the game):
  max_repeat_per_action    3

## Top 10 by predicted damage

Predicted damage is an UNSCALED frame-table sum. Combo scaling appears in no
frame table and neither does Modern's own damage reduction, so this is an
upper bound for ordering, never a damage figure.

#   route                                            dmg~   cost conf    unknowns
1   2 + 强 > 3 + 强 > 236236 + 强                 5900   10.9 low     8
2   2 + 强 > 3 + 强 > 2 + SP + 强                 5900    8.5 low     8
3   3 + 强 > 2 + 强 > 236236 + 强                 5900   10.9 low     8
4   3 + 强 > 2 + 强 > 2 + SP + 强                 5900    8.5 low     8
5   3 + 强 > 6 + 强 > 236236 + 强                 5900   10.9 low     8
6   3 + 强 > 6 + 强 > 2 + SP + 强                 5900    8.5 low     8
7   3 + 强 > 4 + 强 > 236236 + 强                 5900   10.9 low     8
8   3 + 强 > 4 + 强 > 2 + SP + 强                 5900    8.5 low     8
9   2 + 强 > 6 + 强 > 236236 + 强                 5800   10.9 low     8
10  2 + 强 > 6 + 强 > 2 + SP + 强                 5800    8.5 low     8

## Top 10 by predicted scaled damage (model)

A MODEL, NOT A DAMAGE FIGURE. Each move's frame-table damage times a
per-move factor from public descriptions of SF6 scaling (sf6-public-scaling-v1,
verified = false): 100/100/80/70.. per move, a light-normal starter
100/80/70.., floor 10%, x0.85 after a Drive Rush, x0.8 on SP moves, and
the Super Art minimum. Not modelled: 9 things, listed in
scaling_model.not_modelled on every route. Used for ordering only.

#   route                                         scaled~     dmg~   cost conf   
1   2 + 强 > 3 + 强 > 236236 + 强                 5100     5900   10.9 low    
2   3 + 强 > 2 + 强 > 236236 + 强                 5100     5900   10.9 low    
3   3 + 强 > 6 + 强 > 236236 + 强                 5100     5900   10.9 low    
4   3 + 强 > 4 + 强 > 236236 + 强                 5100     5900   10.9 low    
5   2 + 强 > 6 + 强 > 236236 + 强                 5000     5800   10.9 low    
6   2 + 强 > 4 + 强 > 236236 + 强                 5000     5800   10.9 low    
7   3 + 强 > 236236 + 强                           5000     5000    8.9 low    
8   2 + 强 > 236236 + 强                           4900     4900    8.9 low    
9   3 + 强 > 2 + 中 > 236236 + 强                 4900     5700   10.9 low    
10  6 + 强 > 236236 + 强                           4900     4900    8.9 low    

## Top 10 by fewest inputs

#   route                                            dmg~   cost conf   
1   弱 > > 弱                                       400    3.0 medium 
2   弱 > > 空中 中                                400    3.0 low    
3   强 > > 强                                      1000    3.0 medium 
4   强 > > 空中 中                               1000    3.0 low    
5   强 > > 中                                      1000    3.0 medium 
6   中 > > 空中 中                                800    3.0 low    
7   中 > 2 + 弱                                    1100    3.5 medium 
8   2 + 弱 > 弱                                     700    3.5 medium 
9   2 + 弱 > 强                                    1300    3.5 medium 
10  2 + 弱 > 中                                    1100    3.5 medium 

## Pareto frontier: 8 routes nothing beats on both damage and inputs

1   2 + 强 > 3 + 强 > 2 + SP + 强                 5900    8.5
2   中 > 2 + 弱 > 2 + SP + 强                     5100    8.0
3   3 + 强 > 2 + SP + 强                           5000    6.5
4   3 + 强 > SP + 强                               3200    6.0
5   2 + 强 > 3 + 强 > 强                          2900    5.5
6   中 > 2 + 弱 > 强                              2100    5.0
7   3 + 强 > 强                                    2000    3.5
8   强 > > 强                                      1000    3.0

## Why the game still has to answer

- **actual_input_timing**
  the actual input window is what the sweep exists to measure
- **cancel_window_conditions**
  a target-combo derivation only exists inside its own sequence
- **frame_data_variant_ambiguous**
  the frame source lists "214K" 2 times - Scutum / Scutum (Counter) - and the join took whichever came first; which one the input produces depends on something the frame table does not model
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

  605  classic_modern but no Modern command form
  605  simple_command names neither SP nor AUTO
  958  classic_modern but no Modern command form
  958  simple_command names neither SP nor AUTO

## Written

- candidates/marisa/modern/candidate-edges.json  (460635 bytes)
- candidates/marisa/modern/candidate-routes.json  (5612671 bytes)
- reframework/data/ComboExplorer_data/worklist/marisa-modern-drc.json  (33001 bytes)
- reframework/data/ComboExplorer_data/worklist/marisa-modern.json  (129009 bytes)

Both documents carry runtime_verified = false and every record in them is
status = theoretical. The next step is the gaming machine: calibration,
then a sweep, then these become confirmed edges or rejected ones.
