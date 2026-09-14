# Offline candidate report - Yasmine / modern / midscreen / none

EVERYTHING BELOW IS A THEORETICAL CANDIDATE. Nothing here has been run on
Street Fighter 6. These are pairs and sequences worth spending a trial on,
not combos that are known to work.

## Provenance

- command_display: Yasmine, generated 2026-08-03T00:00:00.000Z
  - ac_sha256  e895dc76d9702cbec027de99375383925b339352f5192420b5a78b6270eb8723
  - bcm_sha256 c9b2efb4b5c09251db69961b33df7a64574474ba27a45cae2113a2a36dbcd241
- frame data: RyoSogawa/sf6-sensei @ a64f2acf90fffc855ddc1a958a4ee752e15c571c (CC-BY-SA)
  - original work: SuperCombo Wiki, CC-BY-SA-4.0. See docs/NOTICE.md.
- game patch: command_display@2026-08-03T00:00:00.000Z
  (the command_display generation date, not a confirmed game version - the real patch is only knowable on the machine running the game)

## Moves searched

- catalog rows            138
- starting moves          14  (normal,command_normal / manual)
- target moves            56  (normal,command_normal,special,od_special,super / manual,simple)
- excluded from probing   73  (classic-only, air, throws, system, follow-ups)
- frame data coverage     55 of 94 (59%)  over every row this run uses
    starters      13 of  14 ( 93%)
    targets       55 of  56 ( 98%)
    follow-ups     0 of  38 (  0%)
    8 matched only by guessing between several source spellings:
      236236+P (1214) -> 236236P
      236236+P (1214) -> 236236P
      236236+P (1215) -> 236236P
      236236+P (1215) -> 236236P
      236236+P (1219) -> 236236P
      236236+P (1219) -> 236236P
      236236+P (1220) -> 236236P
      236236+P (1220) -> 236236P
    39 with no frame data at all:
      4+KK (1044)
      >LP (606)
      >LP (607)
      >MP (610)
      >MK (617)
      >HK (618)
      >HK (643)
      >HK (644)
      >22+HP (902)
      >22+LP+HP (905)
      >22+MP+HP (906)
      >6+P (929)
      >6+P (929)
      >6+P (929)
      >6+P (933)
      >6+P (937)
      >6+P (941)
      >6+P (941)
      >6+P (941)
      >6+P (947)
      ... and 19 more
- unresolved canonical ids 21 groups covering 81 rows
- no Modern form at all     8
    34  8
    600  LP
    616  MK
    852  6
    1007  j.LK
    1014  j.LP
    1020  j.LK
    1032  j.LP

## Theoretical edges

- pairs considered        1316
- candidate edges         733
- excluded                583

by reason:
  chain_cancel             42
  frame_data_incomplete    568
  frame_link               56
  special_cancel           297
  super_cancel             108
  target_combo             20

by confidence:
  high                     32
  medium                   61
  low                      640

excluded because the data said no:
  followup_after_a_move_not_its_parent 482
  frame_margin_negative    91
  self_pair_without_chain  10

Nothing was excluded for missing data. A gap in the source is recorded as
an unknown and the pair stays a candidate; only a KNOWN negative margin
excludes, and the margin is kept with it.

followup_after_a_move_not_its_parent is not a gap either. The frame source spells
a follow-up only as a chain from the move it comes out of ("5MP~MP"), so
these 482 pairs put a follow-up after a move the source says it does not
follow. A follow-up whose parent the source never names stays a candidate.

- follow-up edges         50  (parent named by the frame data: 8)

## Drive Rush Cancel candidates

A -> Drive Rush Cancel -> B. NONE OF THESE CAN BE PRESSED YET: how Drive
Rush is input on this build and which action id a Drive Rush Cancel is
have never been measured. They are not in the route search below, and with
--worklist they go to their own file, which the sweep does not read.

- DRC record              "MPMK or 66": startup 9, recovery 15, drive cost 30000
- starters that can rush  8  (drc_on_hit in the frame data)
- starters nobody knows   1  (no record, or a guessed one: kept, low)
- starters that cannot    5  (record present, no Drive Rush Cancel in it)
    609:manual 中
    621:manual 强
    647:manual 3 + 强
    662:manual 4 + 强
    664:manual 6 + 中
- pairs considered        846
- DRC edges               396
- excluded                450

by confidence:
  high                     21
  medium                   55
  low                      320

excluded:
  drc_margin_negative      108
  followup_after_drive_rush 342

drc_margin_negative is drc_on_hit minus B's startup, known and below zero,
kept with the number. followup_after_drive_rush is structure: a derivation
comes out of its parent with nothing in between, and a rush is in between.
A starter the source lists without a Drive Rush Cancel is counted once above
rather than once per target.

## Route candidates

- routes                  1860
- graph nodes             65
- graph edges             733
- folded canonical variants 2873  (same buttons, unresolved action id)
- search complete         false
  beam dropped 2126 partial routes, 0 routes not emitted
  length 2               363
  length 3               1497

dropped by a search bound (not by the game):
  max_repeat_per_action    4

## Top 10 by predicted damage

Predicted damage is an UNSCALED frame-table sum. Combo scaling appears in no
frame table and neither does Modern's own damage reduction, so this is an
upper bound for ordering, never a damage figure.

#   route                                            dmg~   cost conf    unknowns
1   3 + 强 > 2 + 强 > 236236 + 强                 5700   10.9 low     8
2   3 + 强 > 2 + 强 > 2 + SP + 强                 5700    8.5 low     8
3   3 + 强 > 6 + 中 > 236236 + 强                 5500   10.9 low     8
4   3 + 强 > 6 + 中 > 2 + SP + 强                 5500    8.5 low     8
5   6 + 中 > 3 + 强 > 236236 + 强                 5500   10.9 low     8
6   6 + 中 > 3 + 强 > 2 + SP + 强                 5500    8.5 low     8
7   3 + 强 > 2 + 中 > 236236 + 强                 5400   10.9 low     8
8   3 + 强 > 2 + 中 > 2 + SP + 强                 5400    8.5 low     8
9   6 + 中 > 2 + 强 > 236236 + 强                 5400   10.9 low     6
10  6 + 中 > 2 + 强 > 2 + SP + 强                 5400    8.5 low     6

## Top 10 by predicted scaled damage (model)

A MODEL, NOT A DAMAGE FIGURE. Each move's frame-table damage times a
per-move factor from public descriptions of SF6 scaling (sf6-public-scaling-v1,
verified = false): 100/100/80/70.. per move, a light-normal starter
100/80/70.., floor 10%, x0.85 after a Drive Rush, x0.8 on SP moves, and
the Super Art minimum. Not modelled: 9 things, listed in
scaling_model.not_modelled on every route. Used for ordering only.

#   route                                         scaled~     dmg~   cost conf   
1   3 + 强 > 236236 + 强                           4900     4900    8.9 low    
2   3 + 强 > 2 + 强 > 236236 + 强                 4900     5700   10.9 low    
3   2 + 强 > 236236 + 强                           4800     4800    8.9 low    
4   3 + 强 > 6 + 中 > 236236 + 强                 4700     5500   10.9 low    
5   6 + 中 > 3 + 强 > 236236 + 强                 4700     5500   10.9 low    
6   3 + 强 > 2 + 中 > 236236 + 强                 4600     5400   10.9 low    
7   6 + 中 > 236236 + 强                           4600     4600    8.9 low    
8   6 + 中 > 2 + 强 > 236236 + 强                 4600     5400   10.9 low    
9   2 + 中 > 236236 + 强                           4500     4500    8.9 low    
10  3 + 强 > 弱 > 236236 + 强                     4400     5200   10.4 low    

## Top 10 by fewest inputs

#   route                                            dmg~   cost conf   
1   弱 > > 弱                                       300    3.0 low    
2   中 > > 中                                       300    3.0 low    
3   弱 > 2 + 弱                                     600    3.5 medium 
4   弱 > 4 + 强                                     300    3.5 low    
5   中 > 4 + 强                                     300    3.5 low    
6   强 > 4 + 强                                     800    3.5 low    
7   2 + 弱 > 弱                                     600    3.5 medium 
8   2 + 弱 > 中                                     600    3.5 medium 
9   2 + 弱 > 强                                    1100    3.5 medium 
10  2 + 弱 > 2 + 弱                                 600    3.5 medium 

## Pareto frontier: 7 routes nothing beats on both damage and inputs

1   3 + 强 > 2 + 强 > 2 + SP + 强                 5700    8.5
2   3 + 强 > 弱 > 2 + SP + 强                     5200    8.0
3   3 + 强 > 2 + SP + 强                           4900    6.5
4   弱 > 2 + SP + 强                               4300    6.0
5   弱 > SP + 强                                   2300    5.5
6   3 + 强 > 强                                    1700    3.5
7   弱 > > 弱                                       300    3.0

## Why the game still has to answer

- **actual_input_timing**
  the actual input window is what the sweep exists to measure
- **cancel_window_conditions**
  the frame source is missing to_startup for this pair
- **frame_data_variant_ambiguous**
  the frame source lists "236236P" 2 times - Pamumukadkad ng Sampaguita / Pamumukadkad ng Sampaguita (CA) - and the join took whichever came first; which one the input produces depends on something the frame table does not model
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

## Catalog entries the classifier could not place: 38

  612  classic_modern but no Modern command form
  612  simple_command names neither SP nor AUTO
  1009  classic_modern but no Modern command form
  1009  simple_command names neither SP nor AUTO
  1010  classic_modern but no Modern command form
  1010  simple_command names neither SP nor AUTO
  1011  classic_modern but no Modern command form
  1011  simple_command names neither SP nor AUTO
  1012  classic_modern but no Modern command form
  1012  simple_command names neither SP nor AUTO

## Written

- candidates/yasmine/modern/candidate-edges.json  (1009613 bytes)
- candidates/yasmine/modern/candidate-routes.json  (12683069 bytes)
- reframework/data/ComboExplorer_data/worklist/yasmine-modern-drc.json  (162646 bytes)
- reframework/data/ComboExplorer_data/worklist/yasmine-modern.json  (258853 bytes)

Both documents carry runtime_verified = false and every record in them is
status = theoretical. The next step is the gaming machine: calibration,
then a sweep, then these become confirmed edges or rejected ones.
