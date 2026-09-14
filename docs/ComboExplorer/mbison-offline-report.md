# Offline candidate report - MBison / modern / midscreen / none

EVERYTHING BELOW IS A THEORETICAL CANDIDATE. Nothing here has been run on
Street Fighter 6. These are pairs and sequences worth spending a trial on,
not combos that are known to work.

## Provenance

- command_display: MBison, generated 2026-08-03T00:00:00.000Z
  - ac_sha256  9436ca0bf5ace2722e4e9ac35c3d5b79cf26f2f2a139a8e0543f37e6701e7785
  - bcm_sha256 b3c58bcd979e14bce3abd8550249087000763520963a79c18d9c80a55d5db711
- frame data: RyoSogawa/sf6-sensei @ a64f2acf90fffc855ddc1a958a4ee752e15c571c (CC-BY-SA)
  - original work: SuperCombo Wiki, CC-BY-SA-4.0. See docs/NOTICE.md.
- game patch: command_display@2026-08-03T00:00:00.000Z
  (the command_display generation date, not a confirmed game version - the real patch is only knowable on the machine running the game)

## Moves searched

- catalog rows            94
- starting moves          15  (normal,command_normal / manual)
- target moves            49  (normal,command_normal,special,od_special,super / manual,simple)
- excluded from probing   37  (classic-only, air, throws, system, follow-ups)
- frame data coverage     49 of 60 (82%)  over every row this run uses
    starters      15 of  15 (100%)
    targets       49 of  49 (100%)
    follow-ups     0 of  11 (  0%)
    18 matched only by guessing between several source spellings:
      214+LP (973) -> 214LP
      214+MP (977) -> 214MP
      214+MP (977) -> 214MP
      214+HP (981) -> 214HP
      214+PP (999) -> 214PP
      [4]6+LP (1018) -> [4]6LP
      [4]6+LP (1018) -> [4]6LP
      [4]6+MP (1024) -> [4]6MP
      [4]6+HP (1030) -> [4]6HP
      [4]6+PP (1038) -> [4]6PP
      236236+P (1216) -> 236236P
      236236+P (1216) -> 236236P
      236236+P (1217) -> 236236P
      236236+P (1217) -> 236236P
      236236+P (1221) -> 236236P
      236236+P (1221) -> 236236P
      236236+P (1222) -> 236236P
      236236+P (1222) -> 236236P
    11 with no frame data at all:
      >6+HP (655)
      >2+HK (656)
      >j.MP (657)
      >j.K (918)
      >j.P (925)
      >j.P (939)
      >j.K (947)
      >j.KK (948)
      >j.P (956)
      >j.PP (957)
      >j.PP (957)
- unresolved canonical ids 9 groups covering 25 rows
- no Modern form at all     8
    34  8
    608  LK
    612  HK
    625  2+LK
    653  3+HK
    852  6
    1081  6+KKK
    1083  4+KKK

## Theoretical edges

- pairs considered        900
- candidate edges         694
- excluded                206

by reason:
  chain_cancel             90
  frame_data_incomplete    242
  frame_link               73
  special_cancel           189
  super_cancel             130

by confidence:
  high                     149
  medium                   115
  low                      430

excluded because the data said no:
  followup_after_a_move_not_its_parent 45
  frame_margin_negative    152
  self_pair_without_chain  9

Nothing was excluded for missing data. A gap in the source is recorded as
an unknown and the pair stays a candidate; only a KNOWN negative margin
excludes, and the margin is kept with it.

followup_after_a_move_not_its_parent is not a gap either. The frame source spells
a follow-up only as a chain from the move it comes out of ("5MP~MP"), so
these 45 pairs put a follow-up after a move the source says it does not
follow. A follow-up whose parent the source never names stays a candidate.

- follow-up edges         120  (parent named by the frame data: 0)

## Drive Rush Cancel candidates

A -> Drive Rush Cancel -> B. NONE OF THESE CAN BE PRESSED YET: how Drive
Rush is input on this build and which action id a Drive Rush Cancel is
have never been measured. They are not in the route search below, and with
--worklist they go to their own file, which the sweep does not read.

- DRC record              "MPMK or 66": startup 9, recovery 15, drive cost 30000
- starters that can rush  9  (drc_on_hit in the frame data)
- starters nobody knows   0  (no record, or a guessed one: kept, low)
- starters that cannot    6  (record present, no Drive Rush Cancel in it)
    606:manual 强
    610:manual 中
    629:manual 3 + 强
    649:manual 6 + 强
    1080:manual 6 + 弱 + 中 + 强
    1082:manual 4 + 弱 + 中 + 强
- pairs considered        540
- DRC edges               125
- excluded                415

by confidence:
  high                     36
  medium                   44
  low                      45

excluded:
  drc_margin_negative      316
  followup_after_drive_rush 99

drc_margin_negative is drc_on_hit minus B's startup, known and below zero,
kept with the number. followup_after_drive_rush is structure: a derivation
comes out of its parent with nothing in between, and a rush is in between.
A starter the source lists without a Drive Rush Cancel is counted once above
rather than once per target.

## Route candidates

- routes                  1368
- graph nodes             57
- graph edges             694
- folded canonical variants 3326  (same buttons, unresolved action id)
- search complete         false
  beam dropped 3257 partial routes, 0 routes not emitted
  length 2               353
  length 3               1015

dropped by a search bound (not by the game):
  max_repeat_per_action    6

## Top 10 by predicted damage

Predicted damage is an UNSCALED frame-table sum. Combo scaling appears in no
frame table and neither does Modern's own damage reduction, so this is an
upper bound for ordering, never a damage figure.

#   route                                            dmg~   cost conf    unknowns
1   3 + 强 > 强 > 236236 + 强                     5900   10.4 low     8
2   3 + 强 > 强 > 2 + SP + 强                     5900    8.0 low     8
3   3 + 强 > 2 + 强 > 236236 + 强                 5800   10.9 low     8
4   3 + 强 > 2 + 强 > 2 + SP + 强                 5800    8.5 low     8
5   3 + 强 > 4 + 强 > 236236 + 强                 5700   10.9 low     8
6   3 + 强 > 4 + 强 > 2 + SP + 强                 5700    8.5 low     8
7   3 + 强 > 2 + 中 > 236236 + 强                 5400   10.9 low     8
8   3 + 强 > 2 + 中 > 2 + SP + 强                 5400    8.5 low     8
9   弱 > 强 > 236236 + 强                         5300    9.9 low     7
10  弱 > 强 > 2 + SP + 强                         5300    7.5 low     7

## Top 10 by predicted scaled damage (model)

A MODEL, NOT A DAMAGE FIGURE. Each move's frame-table damage times a
per-move factor from public descriptions of SF6 scaling (sf6-public-scaling-v1,
verified = false): 100/100/80/70.. per move, a light-normal starter
100/80/70.., floor 10%, x0.85 after a Drive Rush, x0.8 on SP moves, and
the Super Art minimum. Not modelled: 9 things, listed in
scaling_model.not_modelled on every route. Used for ordering only.

#   route                                         scaled~     dmg~   cost conf   
1   3 + 强 > 强 > 236236 + 强                     5100     5900   10.4 low    
2   强 > 236236 + 强                               5000     5000    8.4 low    
3   3 + 强 > 2 + 强 > 236236 + 强                 5000     5800   10.9 low    
4   2 + 强 > 236236 + 强                           4900     4900    8.9 low    
5   3 + 强 > 236236 + 强                           4900     4900    8.9 low    
6   3 + 强 > 4 + 强 > 236236 + 强                 4900     5700   10.9 low    
7   4 + 强 > 236236 + 强                           4800     4800    8.9 low    
8   3 + 强 > 2 + 中 > 236236 + 强                 4600     5400   10.9 low    
9   强 > 弱 > 236236 + 强                         4500     5300    9.9 low    
10  强 > 2 + 弱 > 236236 + 强                     4500     5300   10.4 low    

## Top 10 by fewest inputs

#   route                                            dmg~   cost conf   
1   弱 > 弱                                         600    2.5 medium 
2   弱 > 空中 任意键                            300    2.5 low    
3   弱 > 空中 任意键 + 任意键                300    2.5 low    
4   强 > 空中 任意键                           1000    2.5 low    
5   强 > 空中 任意键 + 任意键               1000    2.5 low    
6   中 > 空中 任意键                            700    2.5 low    
7   中 > 空中 任意键 + 任意键                700    2.5 low    
8   弱 > 强                                        1300    3.0 medium 
9   弱 > 中                                        1000    3.0 medium 
10  强 > 弱                                        1300    3.0 medium 

## Pareto frontier: 10 routes nothing beats on both damage and inputs

1   3 + 强 > 强 > 2 + SP + 强                     5900    8.0
2   弱 > 强 > 2 + SP + 强                         5300    7.5
3   强 > 2 + SP + 强                               5000    6.0
4   强 > 22 + 弱 + 中 + 强                       4000    5.8
5   强 > SP + 强                                   3000    5.5
6   2 + 强 > [4]6 + 强                             2500    5.3
7   强 > 弱 > 强                                  2300    4.5
8   3 + 强 > 强                                    1900    3.5
9   弱 > 强                                        1300    3.0
10  强 > 空中 任意键                           1000    2.5

## Why the game still has to answer

- **actual_input_timing**
  the actual input window is what the sweep exists to measure
- **cancel_window_conditions**
  cancel windows into specials and supers have conditions no frame table lists
- **frame_data_variant_ambiguous**
  the frame source lists "214LP" 2 times - Backfist Combo / Backfist Combo (Mine) - and the join took whichever came first; which one the input produces depends on something the frame table does not model
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

- candidates/mbison/modern/candidate-edges.json  (994286 bytes)
- candidates/mbison/modern/candidate-routes.json  (9529032 bytes)
- reframework/data/ComboExplorer_data/worklist/mbison-modern-drc.json  (59498 bytes)
- reframework/data/ComboExplorer_data/worklist/mbison-modern.json  (272793 bytes)

Both documents carry runtime_verified = false and every record in them is
status = theoretical. The next step is the gaming machine: calibration,
then a sweep, then these become confirmed edges or rejected ones.
