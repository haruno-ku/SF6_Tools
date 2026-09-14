# Offline candidate report - Elena / modern / midscreen / none

EVERYTHING BELOW IS A THEORETICAL CANDIDATE. Nothing here has been run on
Street Fighter 6. These are pairs and sequences worth spending a trial on,
not combos that are known to work.

## Provenance

- command_display: Elena, generated 2026-08-03T00:00:00.000Z
  - ac_sha256  5ea2b2aa212ea33b373336853ddb0efd1fe3774ac55b7b2cc77d3e8861508033
  - bcm_sha256 099485cf8c2fc6530e5ede52304df5862e21e17c8415acfee1f132a3b5799d2c
- frame data: RyoSogawa/sf6-sensei @ a64f2acf90fffc855ddc1a958a4ee752e15c571c (CC-BY-SA)
  - original work: SuperCombo Wiki, CC-BY-SA-4.0. See docs/NOTICE.md.
- game patch: command_display@2026-08-03T00:00:00.000Z
  (the command_display generation date, not a confirmed game version - the real patch is only knowable on the machine running the game)

## Moves searched

- catalog rows            126
- starting moves          23  (normal,command_normal / manual)
- target moves            74  (normal,command_normal,special,od_special,super / manual,simple)
- excluded from probing   35  (classic-only, air, throws, system, follow-ups)
- frame data coverage     58 of 78 (74%)  over every row this run uses
    starters      17 of  23 ( 74%)
    targets       58 of  74 ( 78%)
    follow-ups     0 of   4 (  0%)
    15 matched only by guessing between several source spellings:
      6+MK (968) -> 6MK
      6+MK (973) -> 6MK
      6+MK (979) -> 6MK
      6+HP (945) -> 6HP
      6+HP (949) -> 6HP
      6+HP (959) -> 6HP
      6+HP (963) -> 6HP
      214214+K (1210) -> 214214K
      214214+K (1210) -> 214214K
      214214+K (1211) -> 214214K
      214214+K (1211) -> 214214K
      214214+K (1215) -> 214214K
      214214+K (1215) -> 214214K
      214214+K (1216) -> 214214K
      214214+K (1216) -> 214214K
    20 with no frame data at all:
      6+LK (967)
      6+HK (969)
      6+LK (971)
      6+HK (975)
      6+LK (978)
      6+HK (980)
      6+LP (943)
      6+MP (944)
      6+LP (947)
      6+MP (948)
      6+P (952)
      6+P (953)
      6+LP (956)
      6+MP (958)
      6+LP (961)
      6+MP (962)
      >MP (604)
      >HK (637)
      >HP (681)
      >HP (682)
- unresolved canonical ids 29 groups covering 85 rows
- no Modern form at all     7
    34  8
    600  LP
    616  HK
    669  3+HK
    852  6
    930  214+MP
    931  214+HP

## Theoretical edges

- pairs considered        1794
- candidate edges         1093
- excluded                701

by reason:
  chain_cancel             111
  frame_data_incomplete    716
  frame_link               89
  special_cancel           138
  super_cancel             98
  target_combo             9

by confidence:
  high                     180
  medium                   105
  low                      808

excluded because the data said no:
  followup_after_a_move_not_its_parent 83
  frame_margin_negative    604
  self_pair_without_chain  14

Nothing was excluded for missing data. A gap in the source is recorded as
an unknown and the pair stays a candidate; only a KNOWN negative margin
excludes, and the margin is kept with it.

followup_after_a_move_not_its_parent is not a gap either. The frame source spells
a follow-up only as a chain from the move it comes out of ("5MP~MP"), so
these 83 pairs put a follow-up after a move the source says it does not
follow. A follow-up whose parent the source never names stays a candidate.

- follow-up edges         9  (parent named by the frame data: 9)

## Drive Rush Cancel candidates

A -> Drive Rush Cancel -> B. NONE OF THESE CAN BE PRESSED YET: how Drive
Rush is input on this build and which action id a Drive Rush Cancel is
have never been measured. They are not in the route search below, and with
--worklist they go to their own file, which the sweep does not read.

- DRC record              "MPMK or 66": startup 9, recovery 15, drive cost 30000
- starters that can rush  6  (drc_on_hit in the frame data)
- starters nobody knows   9  (no record, or a guessed one: kept, low)
- starters that cannot    8  (record present, no Drive Rush Cancel in it)
    603:manual 中
    607:manual 强
    608:manual 强
    635:manual 2 + 中
    640:manual 3 + 强
    671:manual 6 + 中
    677:manual 4 + 强
    680:manual 6 + 强
- pairs considered        1170
- DRC edges               858
- excluded                312

by confidence:
  high                     15
  medium                   61
  low                      782

excluded:
  drc_margin_negative      252
  followup_after_drive_rush 60

drc_margin_negative is drc_on_hit minus B's startup, known and below zero,
kept with the number. followup_after_drive_rush is structure: a derivation
comes out of its parent with nothing in between, and a rush is in between.
A starter the source lists without a Drive Rush Cancel is counted once above
rather than once per target.

## Route candidates

- routes                  857
- graph nodes             78
- graph edges             1093
- folded canonical variants 4236  (same buttons, unresolved action id)
- search complete         false
  beam dropped 13450 partial routes, 0 routes not emitted
  length 2               257
  length 3               600

dropped by a search bound (not by the game):
  max_repeat_per_action    9

## Top 10 by predicted damage

Predicted damage is an UNSCALED frame-table sum. Combo scaling appears in no
frame table and neither does Modern's own damage reduction, so this is an
upper bound for ordering, never a damage figure.

#   route                                            dmg~   cost conf    unknowns
1   3 + 强 > 中 > 214214 + 强                     5500   10.4 low     8
2   3 + 强 > 中 > 2 + SP + 强                     5500    8.0 low     8
3   3 + 强 > 2 + 强 > 214214 + 强                 5300   10.9 low     8
4   3 + 强 > 2 + 强 > 2 + SP + 强                 5300    8.5 low     8
5   2 + 弱 > 3 + 强 > 214214 + 强                 5200   10.9 low     8
6   2 + 弱 > 3 + 强 > 2 + SP + 强                 5200    8.5 low     8
7   3 + 强 > 弱 > 214214 + 强                     5200   10.4 low     8
8   3 + 强 > 弱 > 2 + SP + 强                     5200    8.0 low     8
9   3 + 强 > 2 + 弱 > 214214 + 强                 5200   10.9 low     8
10  3 + 强 > 2 + 弱 > 2 + SP + 强                 5200    8.5 low     8

## Top 10 by predicted scaled damage (model)

A MODEL, NOT A DAMAGE FIGURE. Each move's frame-table damage times a
per-move factor from public descriptions of SF6 scaling (sf6-public-scaling-v1,
verified = false): 100/100/80/70.. per move, a light-normal starter
100/80/70.., floor 10%, x0.85 after a Drive Rush, x0.8 on SP moves, and
the Super Art minimum. Not modelled: 9 things, listed in
scaling_model.not_modelled on every route. Used for ordering only.

#   route                                         scaled~     dmg~   cost conf   
1   3 + 强 > 214214 + 强                           4900     4900    8.9 low    
2   3 + 强 > 中 > 214214 + 强                     4700     5500   10.4 low    
3   中 > 214214 + 强                               4600     4600    8.4 low    
4   3 + 强 > 2 + 强 > 214214 + 强                 4500     5300   10.9 low    
5   2 + 强 > 214214 + 强                           4400     4400    8.9 low    
6   3 + 强 > 弱 > 214214 + 强                     4400     5200   10.4 low    
7   3 + 强 > 2 + 弱 > 214214 + 强                 4400     5200   10.9 low    
8   2 + 强 > 中 > 214214 + 强                     4100     4900   10.4 low    
9   2 + 中 > 2 + 弱 > 214214 + 强                 4100     4900   10.9 low    
10  3 + 强 > 2 + SP + 强                           4100     4900    6.5 low    

## Top 10 by fewest inputs

#   route                                            dmg~   cost conf   
1   中 > > 中                                       600    3.0 medium 
2   强 > > 强                                       800    3.0 medium 
3   中 > 弱                                         800    3.0 medium 
4   中 > 6 + 弱                                     600    3.5 low    
5   中 > 6 + 强                                     600    3.5 low    
6   强 > 6 + 弱                                     800    3.5 low    
7   强 > 6 + 强                                     800    3.5 low    
8   弱 > 2 + 中                                     300    3.5 high   
9   弱 > 3 + 强                                     300    3.5 high   
10  弱 > 6 + 弱                                     300    3.5 low    

## Pareto frontier: 7 routes nothing beats on both damage and inputs

1   3 + 强 > 中 > 2 + SP + 强                     5500    8.0
2   3 + 强 > 2 + SP + 强                           4900    6.5
3   中 > 2 + SP + 强                               4600    6.0
4   2 + 弱 > 3 + 强 > 强                          2000    5.5
5   3 + 强 > 4 + 强                                1800    4.0
6   3 + 强 > 强                                    1700    3.5
7   强 > > 强                                       800    3.0

## Why the game still has to answer

- **actual_input_timing**
  the actual input window is what the sweep exists to measure
- **cancel_window_conditions**
  the frame source is missing to_startup for this pair
- **frame_data_variant_ambiguous**
  the frame source lists "214214K" 2 times - Song of the Grasslands / Song of the Grasslands (CA) - and the join took whichever came first; which one the input produces depends on something the frame table does not model
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

  615  classic_modern but no Modern command form
  615  simple_command names neither SP nor AUTO
  957  classic_modern but no Modern command form
  957  simple_command names neither SP nor AUTO

## Written

- candidates/elena/modern/candidate-edges.json  (1464322 bytes)
- candidates/elena/modern/candidate-routes.json  (6006998 bytes)
- reframework/data/ComboExplorer_data/worklist/elena-modern-drc.json  (299975 bytes)
- reframework/data/ComboExplorer_data/worklist/elena-modern.json  (361067 bytes)

Both documents carry runtime_verified = false and every record in them is
status = theoretical. The next step is the gaming machine: calibration,
then a sweep, then these become confirmed edges or rejected ones.
