# Offline candidate report - DeeJay / modern / midscreen / none

EVERYTHING BELOW IS A THEORETICAL CANDIDATE. Nothing here has been run on
Street Fighter 6. These are pairs and sequences worth spending a trial on,
not combos that are known to work.

## Provenance

- command_display: DeeJay, generated 2026-08-03T00:00:00.000Z
  - ac_sha256  5e13ad6972e82410a8222c42cf0adc0b8ae7ca22872457334c48cbf32cfacdf2
  - bcm_sha256 3b0133d317a1527a08b85fb8284f53e19f1dbb130a522183ae49f7b01b11811f
- frame data: RyoSogawa/sf6-sensei @ a64f2acf90fffc855ddc1a958a4ee752e15c571c (CC-BY-SA)
  - original work: SuperCombo Wiki, CC-BY-SA-4.0. See docs/NOTICE.md.
- game patch: command_display@2026-08-03T00:00:00.000Z
  (the command_display generation date, not a confirmed game version - the real patch is only knowable on the machine running the game)

## Moves searched

- catalog rows            125
- starting moves          44  (normal,command_normal / manual)
- target moves            77  (normal,command_normal,special,od_special,super / manual,simple)
- excluded from probing   41  (classic-only, air, throws, system, follow-ups)
- frame data coverage     77 of 88 (88%)  over every row this run uses
    starters      44 of  44 (100%)
    targets       77 of  77 (100%)
    follow-ups     0 of  11 (  0%)
    39 matched only by guessing between several source spellings:
      LK (999) -> 5LK
      MK (1000) -> 5MK
      HK (1001) -> 5HK
      LP (1208) -> 5LP
      MP (1209) -> 5MP
      HP (1210) -> 5HP
      LK (1211) -> 5LK
      MK (1212) -> 5MK
      HK (1213) -> 5HK
      LP (1219) -> 5LP
      MP (1220) -> 5MP
      HP (1221) -> 5HP
      LK (1222) -> 5LK
      MK (1223) -> 5MK
      HK (1224) -> 5HK
      HK (1225) -> 5HK
      HP (1226) -> 5HP
      LP (1230) -> 5LP
      MP (1231) -> 5MP
      HP (1232) -> 5HP
      LK (1233) -> 5LK
      MK (1234) -> 5MK
      HK (1235) -> 5HK
      HK (1236) -> 5HK
      HP (1237) -> 5HP
      LP (1260) -> 5LP
      MP (1261) -> 5MP
      HP (1262) -> 5HP
      LK (1263) -> 5LK
      MK (1264) -> 5MK
      HK (1265) -> 5HK
      22+PP (685) -> 22PP
      22+PP (688) -> 22PP
      22+PP (697) -> 22PP
      22+PP (700) -> 22PP
      214214+P (1268) -> 214214P
      214214+P (1268) -> 214214P
      214214+P (1272) -> 214214P
      214214+P (1272) -> 214214P
    11 with no frame data at all:
      >MK (668)
      >MK (669)
      >MP (671)
      >HP (673)
      >4+HP (674)
      >HP (677)
      >HK (678)
      >6+P (1006)
      >4+P (1007)
      >6+P (1009)
      >4+P (1010)
- unresolved canonical ids 20 groups covering 75 rows
- no Modern form at all     7
    34  8
    606  HP
    611  MK
    617  2+LP
    852  6
    1218  236236+MP
    1229  236236+HP

## Theoretical edges

- pairs considered        3872
- candidate edges         1572
- excluded                2300

by reason:
  chain_cancel             454
  frame_data_incomplete    88
  frame_link               419
  special_cancel           525
  super_cancel             176
  target_combo             29

by confidence:
  high                     142
  medium                   183
  low                      1247

excluded because the data said no:
  followup_after_a_move_not_its_parent 455
  frame_margin_negative    1811
  self_pair_without_chain  34

Nothing was excluded for missing data. A gap in the source is recorded as
an unknown and the pair stays a candidate; only a KNOWN negative margin
excludes, and the margin is kept with it.

followup_after_a_move_not_its_parent is not a gap either. The frame source spells
a follow-up only as a chain from the move it comes out of ("5MP~MP"), so
these 455 pairs put a follow-up after a move the source says it does not
follow. A follow-up whose parent the source never names stays a candidate.

- follow-up edges         29  (parent named by the frame data: 29)

## Drive Rush Cancel candidates

A -> Drive Rush Cancel -> B. NONE OF THESE CAN BE PRESSED YET: how Drive
Rush is input on this build and which action id a Drive Rush Cancel is
have never been measured. They are not in the route search below, and with
--worklist they go to their own file, which the sweep does not read.

- DRC record              "MPMK or 66": startup 9, recovery 15, drive cost 30000
- starters that can rush  6  (drc_on_hit in the frame data)
- starters nobody knows   31  (no record, or a guessed one: kept, low)
- starters that cannot    7  (record present, no Drive Rush Cancel in it)
    604:manual 中
    613:manual 强
    623:manual 2 + 强
    626:manual 2 + 弱
    630:manual 2 + 中
    632:manual 3 + 强
    661:manual 6 + 中
- pairs considered        3256
- DRC edges               1862
- excluded                1394

by confidence:
  high                     26
  medium                   22
  low                      1814

excluded:
  drc_margin_negative      987
  followup_after_drive_rush 407

drc_margin_negative is drc_on_hit minus B's startup, known and below zero,
kept with the number. followup_after_drive_rush is structure: a derivation
comes out of its parent with nothing in between, and a rush is in between.
A starter the source lists without a Drive Rush Cancel is counted once above
rather than once per target.

## Route candidates

- routes                  1070
- graph nodes             82
- graph edges             1572
- folded canonical variants 4502  (same buttons, unresolved action id)
- search complete         false
  beam dropped 25726 partial routes, 0 routes not emitted
  length 2               225
  length 3               845

dropped by a search bound (not by the game):
  max_repeat_per_action    10

## Top 10 by predicted damage

Predicted damage is an UNSCALED frame-table sum. Combo scaling appears in no
frame table and neither does Modern's own damage reduction, so this is an
upper bound for ordering, never a damage figure.

#   route                                            dmg~   cost conf    unknowns
1   3 + 强 > 强 > 214214 + 强                     5700   10.4 low     8
2   3 + 强 > 强 > 2 + SP + 强                     5700    8.0 low     8
3   3 + 强 > 4 + 强 > 214214 + 强                 5700   10.9 low     8
4   3 + 强 > 4 + 强 > 2 + SP + 强                 5700    8.5 low     8
5   2 + 中 > 3 + 强 > 214214 + 强                 5600   10.9 low     8
6   2 + 中 > 3 + 强 > 2 + SP + 强                 5600    8.5 low     8
7   3 + 强 > 2 + 中 > 214214 + 强                 5600   10.9 low     8
8   3 + 强 > 2 + 中 > 2 + SP + 强                 5600    8.5 low     8
9   3 + 强 > 6 + 中 > 214214 + 强                 5600   10.9 low     8
10  3 + 强 > 6 + 中 > 2 + SP + 强                 5600    8.5 low     8

## Top 10 by predicted scaled damage (model)

A MODEL, NOT A DAMAGE FIGURE. Each move's frame-table damage times a
per-move factor from public descriptions of SF6 scaling (sf6-public-scaling-v1,
verified = false): 100/100/80/70.. per move, a light-normal starter
100/80/70.., floor 10%, x0.85 after a Drive Rush, x0.8 on SP moves, and
the Super Art minimum. Not modelled: 9 things, listed in
scaling_model.not_modelled on every route. Used for ordering only.

#   route                                         scaled~     dmg~   cost conf   
1   3 + 强 > 强 > 214214 + 强                     4900     5700   10.4 low    
2   3 + 强 > 4 + 强 > 214214 + 强                 4900     5700   10.9 low    
3   3 + 强 > 214214 + 强                           4900     4900    8.9 low    
4   强 > 214214 + 强                               4800     4800    8.4 low    
5   2 + 中 > 3 + 强 > 214214 + 强                 4800     5600   10.9 low    
6   3 + 强 > 2 + 中 > 214214 + 强                 4800     5600   10.9 low    
7   3 + 强 > 6 + 中 > 214214 + 强                 4800     5600   10.9 low    
8   2 + 中 > 强 > 214214 + 强                     4700     5500   10.4 low    
9   2 + 中 > 4 + 强 > 214214 + 强                 4700     5500   10.9 low    
10  2 + 中 > 214214 + 强                           4700     4700    8.9 low    

## Top 10 by fewest inputs

#   route                                            dmg~   cost conf   
1   弱 > 弱                                         600    2.5 medium 
2   弱 > 中                                         900    3.0 medium 
3   弱 > 强                                        1100    3.0 medium 
4   弱 > > 中                                       300    3.0 medium 
5   中 > 弱                                         900    3.0 medium 
6   中 > > 中                                       600    3.0 medium 
7   中 > > 强                                       600    3.0 medium 
8   弱 > 2 + 弱                                     600    3.5 medium 
9   弱 > 2 + 强                                    1100    3.5 medium 
10  弱 > 2 + 中                                    1000    3.5 medium 

## Pareto frontier: 10 routes nothing beats on both damage and inputs

1   3 + 强 > 强 > 2 + SP + 强                     5700    8.0
2   弱 > 强 > 2 + SP + 强                         5100    7.5
3   3 + 强 > 2 + SP + 强                           4900    6.5
4   强 > 2 + SP + 强                               4800    6.0
5   强 > 214 + 强                                  3000    5.7
6   强 > SP + 强                                   2800    5.5
7   弱 > 3 + 强 > 强                              2000    5.0
8   3 + 强 > 强                                    1700    3.5
9   弱 > 强                                        1100    3.0
10  弱 > 弱                                         600    2.5

## Why the game still has to answer

- **actual_input_timing**
  the actual input window is what the sweep exists to measure
- **cancel_window_conditions**
  cancel windows into specials and supers have conditions no frame table lists
- **frame_data_variant_ambiguous**
  the frame source lists "22PP" 2 times - Speedy Maracas / Speedy Maracas (2+ Bars) - and the join took whichever came first; which one the input produces depends on something the frame table does not model
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

  989  classic_modern but no Modern command form
  989  simple_command names neither SP nor AUTO
  991  classic_modern but no Modern command form
  991  simple_command names neither SP nor AUTO
  994  classic_modern but no Modern command form
  994  simple_command names neither SP nor AUTO
  995  classic_modern but no Modern command form
  995  simple_command names neither SP nor AUTO
  1240  classic_modern but no Modern command form
  1240  simple_command names neither SP nor AUTO

## Written

- candidates/deejay/modern/candidate-edges.json  (2583033 bytes)
- candidates/deejay/modern/candidate-routes.json  (7497594 bytes)
- reframework/data/ComboExplorer_data/worklist/deejay-modern-drc.json  (801167 bytes)
- reframework/data/ComboExplorer_data/worklist/deejay-modern.json  (635541 bytes)

Both documents carry runtime_verified = false and every record in them is
status = theoretical. The next step is the gaming machine: calibration,
then a sweep, then these become confirmed edges or rejected ones.
