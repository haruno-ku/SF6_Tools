# Offline candidate report - Zangief / modern / midscreen / none

EVERYTHING BELOW IS A THEORETICAL CANDIDATE. Nothing here has been run on
Street Fighter 6. These are pairs and sequences worth spending a trial on,
not combos that are known to work.

## Provenance

- command_display: Zangief, generated 2026-08-03T00:00:00.000Z
  - ac_sha256  753d02204cec89c5a885d5748cda2d51bde0769144a15be93f1e717f219006b2
  - bcm_sha256 09e9334a458b4e7073d13c5a0e25255d2b35b0cb71ccdccbd67c8774b62d4053
- frame data: RyoSogawa/sf6-sensei @ a64f2acf90fffc855ddc1a958a4ee752e15c571c (CC-BY-SA)
  - original work: SuperCombo Wiki, CC-BY-SA-4.0. See docs/NOTICE.md.
- game patch: command_display@2026-08-03T00:00:00.000Z
  (the command_display generation date, not a confirmed game version - the real patch is only knowable on the machine running the game)

## Moves searched

- catalog rows            88
- starting moves          14  (normal,command_normal / manual)
- target moves            33  (normal,command_normal,special,od_special,super / manual,simple)
- excluded from probing   51  (classic-only, air, throws, system, follow-ups)
- frame data coverage     30 of 37 (81%)  over every row this run uses
    starters      14 of  14 (100%)
    targets       30 of  33 ( 91%)
    follow-ups     0 of   4 (  0%)
    5 matched only by guessing between several source spellings:
      63214+KK (924) -> 63214KK (Close)
      720+P (1218) -> 720+P
      720+P (1218) -> 720+P
      720+P (1222) -> 720+P
      720+P (1222) -> 720+P
    7 with no frame data at all:
      63214+LK+MK (918)
      63214+LK+MK (918)
      63214+HK (1010)
      >MP (605)
      >MP (606)
      >MK (679)
      >MK (680)
- unresolved canonical ids 13 groups covering 31 rows
- no Modern form at all     9
    34  8
    600  LP
    613  MK
    615  HK
    631  2+MK
    685  3+HK
    852  6
    1015  63214+LK+MK
    1020  63214+KK

## Theoretical edges

- pairs considered        518
- candidate edges         387
- excluded                131

by reason:
  chain_cancel             90
  frame_data_incomplete    111
  frame_link               122
  special_cancel           88
  super_cancel             64
  target_combo             4

by confidence:
  high                     88
  medium                   133
  low                      166

excluded because the numbers said no:
  frame_margin_negative    122
  self_pair_without_chain  9

Nothing was excluded for missing data. A gap in the source is recorded as
an unknown and the pair stays a candidate; only a KNOWN negative margin
excludes, and the margin is kept with it.

## Route candidates

- routes                  1037
- graph nodes             37
- graph edges             387
- folded canonical variants 2333  (same buttons, unresolved action id)
- search complete         true
  length 2               188
  length 3               849

dropped by a search bound (not by the game):
  max_repeat_per_action    5

## Top 10 by predicted damage

Predicted damage is an UNSCALED frame-table sum. Combo scaling appears in no
frame table and neither does Modern's own damage reduction, so this is an
upper bound for ordering, never a damage figure.

#   route                                            dmg~   cost conf    unknowns
1   3 + 强 > 6 + 强 > 720 + 强                    7100   15.4 low     8
2   3 + 强 > 6 + 强 > 2 + SP + 强                 7100    8.5 low     8
3   6 + 强 > 2 + 强 > 720 + 强                    7100   15.4 low     8
4   6 + 强 > 2 + 强 > 2 + SP + 强                 7100    8.5 low     8
5   6 + 强 > 3 + 强 > 720 + 强                    7100   15.4 low     8
6   6 + 强 > 3 + 强 > 2 + SP + 强                 7100    8.5 low     8
7   6 + 强 > 3 + 中 > 720 + 强                    6900   15.4 low     8
8   6 + 强 > 3 + 中 > 2 + SP + 强                 6900    8.5 low     8
9   2 + 强 > 3 + 强 > 720 + 强                    6800   15.4 low     8
10  2 + 强 > 3 + 强 > 2 + SP + 强                 6800    8.5 low     8

## Top 10 by fewest inputs

#   route                                            dmg~   cost conf   
1   弱 > 弱                                         800    2.5 medium 
2   弱 > 中                                        1100    3.0 medium 
3   弱 > > 中                                       400    3.0 low    
4   弱 > 强                                        1400    3.0 low    
5   中 > > 中                                       700    3.0 low    
6   中 > 强                                        1700    3.0 low    
7   强 > > 中                                      1000    3.0 low    
8   弱 > 2 + 弱                                     700    3.5 medium 
9   弱 > 2 + 中                                    1100    3.5 medium 
10  弱 > 2 + 强                                    1400    3.5 medium 

## Pareto frontier: 10 routes nothing beats on both damage and inputs

1   3 + 强 > 6 + 强 > 2 + SP + 强                 7100    8.5
2   弱 > 6 + 强 > 2 + SP + 强                     6500    8.0
3   6 + 强 > 2 + SP + 强                           6100    6.5
4   弱 > 2 + SP + 强                               5200    6.0
5   6 + 强 > SP                                     4600    5.5
6   弱 > SP                                         3700    5.0
7   弱 > 22 + 强                                   2800    4.8
8   6 + 强 > 强                                    2300    3.5
9   中 > 强                                        1700    3.0
10  弱 > 弱                                         800    2.5

## Why the game still has to answer

- **actual_input_timing**
  the actual input window is what the sweep exists to measure
- **cancel_window_conditions**
  the frame source is missing to_startup for this pair
- **frame_data_variant_ambiguous**
  the frame source spells this move as several distance variants (63214KK (Close), 63214KK (Far), 63214KK (Mid)) and the join picked 63214KK (Close) by sort order, not by knowing which one applies
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

- candidates/zangief/modern/candidate-edges.json  (500013 bytes)
- candidates/zangief/modern/candidate-routes.json  (4456513 bytes)

Both documents carry runtime_verified = false and every record in them is
status = theoretical. The next step is the gaming machine: calibration,
then a sweep, then these become confirmed edges or rejected ones.
