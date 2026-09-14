# Offline candidate report - AKI / modern / midscreen / none

EVERYTHING BELOW IS A THEORETICAL CANDIDATE. Nothing here has been run on
Street Fighter 6. These are pairs and sequences worth spending a trial on,
not combos that are known to work.

## Provenance

- command_display: AKI, generated 2026-08-03T00:00:00.000Z
  - ac_sha256  29fcef9b54e71cc0dfdea28336ca32cbaba49c1bcd65dd0b438c307d9bfcf7e4
  - bcm_sha256 1eee569acb78de6e1442dd0197a98900a930d39726a03379f2cc99e3d3f2cb67
- frame data: RyoSogawa/sf6-sensei @ a64f2acf90fffc855ddc1a958a4ee752e15c571c (CC-BY-SA)
  - original work: SuperCombo Wiki, CC-BY-SA-4.0. See docs/NOTICE.md.
- game patch: command_display@2026-08-03T00:00:00.000Z
  (the command_display generation date, not a confirmed game version - the real patch is only knowable on the machine running the game)

## Moves searched

- catalog rows            77
- starting moves          15  (normal,command_normal / manual)
- target moves            41  (normal,command_normal,special,od_special,super / manual,simple)
- excluded from probing   29  (classic-only, air, throws, system, follow-ups)
- frame data coverage     39 of 41 (95%)  over every row this run uses
    starters      15 of  15 (100%)
    targets       39 of  41 ( 95%)
    4 matched only by guessing between several source spellings:
      236236+P (1254) -> 236236P
      236236+P (1254) -> 236236P
      236236+P (1260) -> 236236P
      236236+P (1260) -> 236236P
    2 with no frame data at all:
      6+P (901)
      6+P (907)
- unresolved canonical ids 10 groups covering 23 rows
- no Modern form at all     8
    623  2+MP
    672  6+HP
    852  6
    972  236+LK
    976  236+HK
    992  8
    1223  214214+LP
    1225  214214+HP

## Theoretical edges

- pairs considered        615
- candidate edges         330
- excluded                285

by reason:
  chain_cancel             51
  frame_data_incomplete    68
  frame_link               66
  special_cancel           96
  super_cancel             64

by confidence:
  high                     128
  medium                   98
  low                      104

excluded because the data said no:
  frame_margin_negative    273
  self_pair_without_chain  12

Nothing was excluded for missing data. A gap in the source is recorded as
an unknown and the pair stays a candidate; only a KNOWN negative margin
excludes, and the margin is kept with it.

## Drive Rush Cancel candidates

A -> Drive Rush Cancel -> B. NONE OF THESE CAN BE PRESSED YET: how Drive
Rush is input on this build and which action id a Drive Rush Cancel is
have never been measured. They are not in the route search below, and with
--worklist they go to their own file, which the sweep does not read.

- DRC record              "MPMK or 66": startup 9, recovery 15, drive cost 30000
- starters that can rush  6  (drc_on_hit in the frame data)
- starters nobody knows   0  (no record, or a guessed one: kept, low)
- starters that cannot    9  (record present, no Drive Rush Cancel in it)
    606:manual 强
    612:manual 中
    626:manual 3 + 强
    634:manual 2 + 中
    637:manual 2 + 强
    663:manual 强
    667:manual 3 + 中
    668:manual 6 + 强
    990:manual 2 + 中 + 强
- pairs considered        246
- DRC edges               30
- excluded                216

by confidence:
  high                     0
  medium                   18
  low                      12

excluded:
  drc_margin_negative      216

drc_margin_negative is drc_on_hit minus B's startup, known and below zero,
kept with the number. followup_after_drive_rush is structure: a derivation
comes out of its parent with nothing in between, and a rush is in between.
A starter the source lists without a Drive Rush Cancel is counted once above
rather than once per target.

## Route candidates

- routes                  657
- graph nodes             41
- graph edges             330
- folded canonical variants 2157  (same buttons, unresolved action id)
- search complete         true
  length 2               135
  length 3               522

dropped by a search bound (not by the game):
  max_repeat_per_action    3

## Top 10 by predicted damage

Predicted damage is an UNSCALED frame-table sum. Combo scaling appears in no
frame table and neither does Modern's own damage reduction, so this is an
upper bound for ordering, never a damage figure.

#   route                                            dmg~   cost conf    unknowns
1   3 + 强 > 2 + 强 > 236236 + 强                 5800   10.9 low     8
2   3 + 强 > 2 + 强 > 2 + SP + 强                 5800    8.5 low     8
3   3 + 强 > 2 + 中 > 236236 + 强                 5500   10.9 low     8
4   3 + 强 > 2 + 中 > 2 + SP + 强                 5500    8.5 low     8
5   2 + 弱 > 3 + 强 > 236236 + 强                 5200   10.9 low     8
6   2 + 弱 > 3 + 强 > 2 + SP + 强                 5200    8.5 low     8
7   2 + 弱 > 2 + 强 > 236236 + 强                 5200   10.9 low     7
8   2 + 弱 > 2 + 强 > 2 + SP + 强                 5200    8.5 low     7
9   3 + 强 > 弱 > 236236 + 强                     5200   10.4 low     8
10  3 + 强 > 弱 > 2 + SP + 强                     5200    8.0 low     8

## Top 10 by predicted scaled damage (model)

A MODEL, NOT A DAMAGE FIGURE. Each move's frame-table damage times a
per-move factor from public descriptions of SF6 scaling (sf6-public-scaling-v1,
verified = false): 100/100/80/70.. per move, a light-normal starter
100/80/70.., floor 10%, x0.85 after a Drive Rush, x0.8 on SP moves, and
the Super Art minimum. Not modelled: 9 things, listed in
scaling_model.not_modelled on every route. Used for ordering only.

#   route                                         scaled~     dmg~   cost conf   
1   3 + 强 > 2 + 强 > 236236 + 强                 5000     5800   10.9 low    
2   3 + 强 > 236236 + 强                           4900     4900    8.9 low    
3   2 + 强 > 236236 + 强                           4900     4900    8.9 low    
4   3 + 强 > 2 + 中 > 236236 + 强                 4700     5500   10.9 low    
5   2 + 中 > 236236 + 强                           4600     4600    8.9 low    
6   3 + 强 > 弱 > 236236 + 强                     4400     5200   10.4 low    
7   3 + 强 > 2 + 弱 > 236236 + 强                 4400     5200   10.9 low    
8   3 + 强 > 2 + 强 > 2 + SP + 强                 4360     5800    8.5 low    
9   中 > 弱 > 236236 + 强                         4200     5000    9.9 low    
10  中 > 2 + 弱 > 236236 + 强                     4200     5000   10.4 low    

## Top 10 by fewest inputs

#   route                                            dmg~   cost conf   
1   中 > 弱                                        1000    3.0 medium 
2   弱 > 2 + 弱                                     600    3.5 medium 
3   中 > 2 + 弱                                    1000    3.5 medium 
4   2 + 弱 > 弱                                     600    3.5 medium 
5   2 + 弱 > 强                                    1100    3.5 medium 
6   2 + 弱 > 中                                    1000    3.5 medium 
7   2 + 弱 > 2 + 弱                                 600    3.5 medium 
8   3 + 强 > 弱                                    1200    3.5 medium 
9   3 + 强 > 强                                    1700    3.5 medium 
10  3 + 强 > 中                                    1600    3.5 medium 

## Pareto frontier: 10 routes nothing beats on both damage and inputs

1   3 + 强 > 2 + 强 > 2 + SP + 强                 5800    8.5
2   3 + 强 > 弱 > 2 + SP + 强                     5200    8.0
3   中 > 弱 > 2 + SP + 强                         5000    7.5
4   3 + 强 > 2 + SP + 强                           4900    6.5
5   弱 > 2 + SP + 强                               4300    6.0
6   2 + 弱 > 3 + 强 > 强                          2000    5.5
7   3 + 强 > 中 > 弱                              1900    5.0
8   3 + 强 > 2 + 强                                1800    4.0
9   3 + 强 > 强                                    1700    3.5
10  中 > 弱                                        1000    3.0

## Why the game still has to answer

- **actual_input_timing**
  the actual input window is what the sweep exists to measure
- **cancel_window_conditions**
  cancel windows into specials and supers have conditions no frame table lists
- **frame_data_variant_ambiguous**
  the frame source lists "236236P" 2 times - Claws of Ya Zi / Claws of Ya Zi - and the join took whichever came first; which one the input produces depends on something the frame table does not model
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

  609  classic_modern but no Modern command form
  609  simple_command names neither SP nor AUTO

## Written

- candidates/aki/modern/candidate-edges.json  (429268 bytes)
- candidates/aki/modern/candidate-routes.json  (4569189 bytes)
- reframework/data/ComboExplorer_data/worklist/aki-modern-drc.json  (14637 bytes)
- reframework/data/ComboExplorer_data/worklist/aki-modern.json  (131063 bytes)

Both documents carry runtime_verified = false and every record in them is
status = theoretical. The next step is the gaming machine: calibration,
then a sweep, then these become confirmed edges or rejected ones.
