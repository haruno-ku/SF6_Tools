# Offline candidate report - Jamie / modern / midscreen / none

EVERYTHING BELOW IS A THEORETICAL CANDIDATE. Nothing here has been run on
Street Fighter 6. These are pairs and sequences worth spending a trial on,
not combos that are known to work.

## Provenance

- command_display: Jamie, generated 2026-08-03T00:00:00.000Z
  - ac_sha256  abf8fbad51d9f39507e644780ed58c00abc1e4ec4299e8b9449daca84df7c04a
  - bcm_sha256 1f39f8d6bbc346251490dc8bd3d0846cc2162f7bc14f2924a250b3cab6ff24f8
- frame data: RyoSogawa/sf6-sensei @ a64f2acf90fffc855ddc1a958a4ee752e15c571c (CC-BY-SA)
  - original work: SuperCombo Wiki, CC-BY-SA-4.0. See docs/NOTICE.md.
- game patch: command_display@2026-08-03T00:00:00.000Z
  (the command_display generation date, not a confirmed game version - the real patch is only knowable on the machine running the game)

## Moves searched

- catalog rows            171
- starting moves          16  (normal,command_normal / manual)
- target moves            76  (normal,command_normal,special,od_special,super / manual,simple)
- excluded from probing   82  (classic-only, air, throws, system, follow-ups)
- frame data coverage     57 of 92 (62%)  over every row this run uses
    starters      16 of  16 (100%)
    targets       55 of  76 ( 72%)
    follow-ups     2 of  16 ( 12%)
    22 matched only by guessing between several source spellings:
      LP (600) -> 5LP
      LP (603) -> 5LP
      6+MK (659) -> 6MK
      6+MK (660) -> 6MK
      4+HP (673) -> 4HP
      4+HP (674) -> 4HP
      6+HK (679) -> 6HK
      6+HK (680) -> 6HK
      236+LP (900) -> 236LP
      236+MP (904) -> 236MP
      236+MP (904) -> 236MP
      236+HP (908) -> 236HP
      236+PP (912) -> 236PP
      236+LP (934) -> 236LP
      236+MP (935) -> 236MP
      236+MP (935) -> 236MP
      236+HP (936) -> 236HP
      236+PP (941) -> 236PP
      236236+P (1211) -> 236236P
      236236+P (1211) -> 236236P
      236236+P (1215) -> 236236P
      236236+P (1215) -> 236236P
    35 with no frame data at all:
      6+P (901)
      6+P (902)
      6+P (905)
      6+P (906)
      6+P (909)
      6+P (910)
      6+P (913)
      6+P (914)
      6+K (918)
      6+K (919)
      6+K (922)
      6+K (923)
      6+K (926)
      6+K (927)
      6+K (930)
      6+K (931)
      6+P (938)
      6+P (939)
      6+P (942)
      6+P (943)
      ... and 15 more
- unresolved canonical ids 32 groups covering 124 rows
- no Modern form at all     7
    612  LK
    613  LK
    615  LK
    626  2+MP
    667  >8
    853  6
    1013  nil

## Theoretical edges

- pairs considered        1472
- candidate edges         752
- excluded                720

by reason:
  chain_cancel             74
  frame_data_incomplete    338
  frame_link               149
  special_cancel           175
  super_cancel             88
  target_combo             4

by confidence:
  high                     97
  medium                   75
  low                      580

excluded because the data said no:
  followup_after_a_move_not_its_parent 214
  frame_margin_negative    364
  self_pair_without_chain  14
  throw_after_a_hit        232

Nothing was excluded for missing data. A gap in the source is recorded as
an unknown and the pair stays a candidate; only a KNOWN negative margin
excludes, and the margin is kept with it.

followup_after_a_move_not_its_parent is not a gap either. The frame source spells
a follow-up only as a chain from the move it comes out of ("5MP~MP"), so
these 214 pairs put a follow-up after a move the source says it does not
follow. A follow-up whose parent the source never names stays a candidate.

- follow-up edges         22  (parent named by the frame data: 4)

## Drive Rush Cancel candidates

A -> Drive Rush Cancel -> B. NONE OF THESE CAN BE PRESSED YET: how Drive
Rush is input on this build and which action id a Drive Rush Cancel is
have never been measured. They are not in the route search below, and with
--worklist they go to their own file, which the sweep does not read.

- DRC record              "MPMK or 66": startup 9, recovery 15, drive cost 30000
- starters that can rush  5  (drc_on_hit in the frame data)
- starters nobody knows   8  (no record, or a guessed one: kept, low)
- starters that cannot    3  (record present, no Drive Rush Cancel in it)
    608:manual 中
    638:manual 3 + 强
    666:manual 2 + 中 + 强
- pairs considered        1196
- DRC edges               650
- excluded                546

by confidence:
  high                     17
  medium                   44
  low                      589

excluded:
  drc_margin_negative      234
  followup_after_drive_rush 208

drc_margin_negative is drc_on_hit minus B's startup, known and below zero,
kept with the number. followup_after_drive_rush is structure: a derivation
comes out of its parent with nothing in between, and a rush is in between.
A starter the source lists without a Drive Rush Cancel is counted once above
rather than once per target.

## Route candidates

- routes                  1079
- graph nodes             73
- graph edges             752
- folded canonical variants 3353  (same buttons, unresolved action id)
- search complete         true
  length 2               243
  length 3               836

dropped by a search bound (not by the game):
  max_repeat_per_action    2

## Top 10 by predicted damage

Predicted damage is an UNSCALED frame-table sum. Combo scaling appears in no
frame table and neither does Modern's own damage reduction, so this is an
upper bound for ordering, never a damage figure.

#   route                                            dmg~   cost conf    unknowns
1   2 + 中 + 强 > 2 + 强 > 236236 + 强           6000   11.4 low     8
2   2 + 中 + 强 > 2 + 强 > 2 + SP + 强           6000    9.0 low     8
3   2 + 中 + 强 > 6 + 强 > 236236 + 强           6000   11.4 low     8
4   2 + 中 + 强 > 6 + 强 > 2 + SP + 强           6000    9.0 low     8
5   2 + 中 + 强 > 4 + 强 > 236236 + 强           5900   11.4 low     8
6   2 + 中 + 强 > 4 + 强 > 2 + SP + 强           5900    9.0 low     8
7   3 + 强 > 2 + 强 > 236236 + 强                 5800   10.9 low     8
8   3 + 强 > 2 + 强 > 2 + SP + 强                 5800    8.5 low     8
9   3 + 强 > 6 + 强 > 236236 + 强                 5800   10.9 low     8
10  3 + 强 > 6 + 强 > 2 + SP + 强                 5800    8.5 low     8

## Top 10 by predicted scaled damage (model)

A MODEL, NOT A DAMAGE FIGURE. Each move's frame-table damage times a
per-move factor from public descriptions of SF6 scaling (sf6-public-scaling-v1,
verified = false): 100/100/80/70.. per move, a light-normal starter
100/80/70.., floor 10%, x0.85 after a Drive Rush, x0.8 on SP moves, and
the Super Art minimum. Not modelled: 9 things, listed in
scaling_model.not_modelled on every route. Used for ordering only.

#   route                                         scaled~     dmg~   cost conf   
1   2 + 强 > 236236 + 强                           5400     5400    8.9 low    
2   6 + 强 > 236236 + 强                           5400     5400    8.9 low    
3   4 + 强 > 236236 + 强                           5300     5300    8.9 low    
4   2 + 中 + 强 > 236236 + 强                     5100     5100    9.4 low    
5   2 + 中 + 强 > 2 + 强 > 236236 + 强           5100     6000   11.4 low    
6   2 + 中 + 强 > 6 + 强 > 236236 + 强           5100     6000   11.4 low    
7   2 + 中 > 236236 + 强                           5000     5000    8.9 low    
8   2 + 中 + 强 > 4 + 强 > 236236 + 强           5000     5900   11.4 low    
9   3 + 强 > 236236 + 强                           4900     4900    8.9 low    
10  3 + 强 > 2 + 强 > 236236 + 强                 4900     5800   10.9 low    

## Top 10 by fewest inputs

#   route                                            dmg~   cost conf   
1   弱 > > 任意键                                 270    2.5 low    
2   强 > > 任意键                                 100    2.5 high   
3   弱 > 弱                                         540    3.0 low    
4   弱 > 强                                         370    3.0 low    
5   中 > 弱                                         870    3.0 low    
6   中 > 强                                         700    3.0 medium 
7   2 + 弱 > > 任意键                             250    3.0 high   
8   2 + 强 > > 任意键                             900    3.0 high   
9   2 + 中 > > 任意键                             500    3.0 high   
10  3 + 强 > > 任意键                             400    3.0 medium 

## Pareto frontier: 10 routes nothing beats on both damage and inputs

1   2 + 中 + 强 > 2 + 强 > 2 + SP + 强           6000    9.0
2   3 + 强 > 2 + 强 > 2 + SP + 强                 5800    8.5
3   2 + 强 > 2 + SP + 强                           5400    6.5
4   弱 > 2 + SP + 强                               4770    6.0
5   弱 > SP + 强                                   2470    5.5
6   2 + 中 + 强 > 2 + 强                          1500    4.5
7   3 + 强 > 2 + 强                                1300    4.0
8   3 + 强 > 中                                    1000    3.5
9   2 + 强 > > 任意键                             900    3.0
10  弱 > > 任意键                                 270    2.5

## Why the game still has to answer

- **actual_input_timing**
  the actual input window is what the sweep exists to measure
- **cancel_window_conditions**
  cancel windows into specials and supers have conditions no frame table lists
- **frame_data_variant_ambiguous**
  the frame source lists "5LP" 2 times - Stand LP (DL0) / Stand LP (DL2) - and the join took whichever came first; which one the input produces depends on something the frame table does not model
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

  614  classic_modern but no Modern command form
  614  simple_command names neither SP nor AUTO

## Written

- candidates/jamie/modern/candidate-edges.json  (1165125 bytes)
- candidates/jamie/modern/candidate-routes.json  (7602124 bytes)
- reframework/data/ComboExplorer_data/worklist/jamie-modern-drc.json  (273523 bytes)
- reframework/data/ComboExplorer_data/worklist/jamie-modern.json  (290457 bytes)

Both documents carry runtime_verified = false and every record in them is
status = theoretical. The next step is the gaming machine: calibration,
then a sweep, then these become confirmed edges or rejected ones.
