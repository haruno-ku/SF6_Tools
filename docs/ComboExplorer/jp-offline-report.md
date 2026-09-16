# Offline candidate report - JP / modern / midscreen / none

EVERYTHING BELOW IS A THEORETICAL CANDIDATE. Nothing here has been run on
Street Fighter 6. These are pairs and sequences worth spending a trial on,
not combos that are known to work.

## Provenance

- command_display: JP, generated 2026-08-03T00:00:00.000Z
  - ac_sha256  945eda4c32195abe427a22fef1c4f9ab79414bf68cb203b9dc26a05b7a6a6701
  - bcm_sha256 58debe7d95aae9ed56c77660dba038975db734db93da502ae974a5740d87193b
- frame data: RyoSogawa/sf6-sensei @ a64f2acf90fffc855ddc1a958a4ee752e15c571c (CC-BY-SA)
  - original work: SuperCombo Wiki, CC-BY-SA-4.0. See docs/NOTICE.md.
- game patch: command_display@2026-08-03T00:00:00.000Z
  (the command_display generation date, not a confirmed game version - the real patch is only knowable on the machine running the game)

## Moves searched

- catalog rows            93
- starting moves          14  (normal,command_normal / manual)
- target moves            53  (normal,command_normal,special,od_special,super / manual,simple)
- excluded from probing   33  (classic-only, air, throws, system, follow-ups)
- frame data coverage     53 of 64 (83%)  over every row this run uses
    starters      14 of  14 (100%)
    targets       53 of  53 (100%)
    follow-ups     0 of  11 (  0%)
    4 matched only by guessing between several source spellings:
      236236+K (1235) -> 236236K
      236236+K (1235) -> 236236K
      236236+K (1239) -> 236236K
      236236+K (1239) -> 236236K
    11 with no frame data at all:
      >MP (638)
      >HP (642)
      >HP (643)
      >HK (644)
      >j.Throw (717)
      >22+LP+HP (960)
      >22+LP+HP (960)
      >22+LP+HP (960)
      >22+MP+HP (961)
      >22+MP+HP (961)
      >22+MP+HP (961)
- unresolved canonical ids 17 groups covering 39 rows
- no Modern form at all     6
    34  8
    603  MP
    605  LK
    619  2+LK
    622  2+HK
    852  6

## Theoretical edges

- pairs considered        896
- candidate edges         611
- excluded                285

by reason:
  chain_cancel             84
  frame_data_incomplete    98
  frame_link               134
  special_cancel           350
  super_cancel             80
  target_combo             17

by confidence:
  high                     325
  medium                   148
  low                      138

excluded because the data said no:
  followup_after_a_move_not_its_parent 53
  frame_margin_negative    196
  self_pair_without_chain  8
  throw_after_a_hit        48

Nothing was excluded for missing data. A gap in the source is recorded as
an unknown and the pair stays a candidate; only a KNOWN negative margin
excludes, and the margin is kept with it.

followup_after_a_move_not_its_parent is not a gap either. The frame source spells
a follow-up only as a chain from the move it comes out of ("5MP~MP"), so
these 53 pairs put a follow-up after a move the source says it does not
follow. A follow-up whose parent the source never names stays a candidate.

- follow-up edges         101  (parent named by the frame data: 3)

## Drive Rush Cancel candidates

A -> Drive Rush Cancel -> B. NONE OF THESE CAN BE PRESSED YET: how Drive
Rush is input on this build and which action id a Drive Rush Cancel is
have never been measured. They are not in the route search below, and with
--worklist they go to their own file, which the sweep does not read.

- DRC record              "MPMK or 66": startup 9, recovery 15, drive cost 30000
- starters that can rush  10  (drc_on_hit in the frame data)
- starters nobody knows   0  (no record, or a guessed one: kept, low)
- starters that cannot    4  (record present, no Drive Rush Cancel in it)
    607:manual 强
    621:manual 2 + 中
    639:manual 6 + 中
    640:manual 3 + 强
- pairs considered        640
- DRC edges               173
- excluded                467

by confidence:
  high                     78
  medium                   91
  low                      4

excluded:
  drc_margin_negative      337
  followup_after_drive_rush 110

drc_margin_negative is drc_on_hit minus B's startup, known and below zero,
kept with the number. followup_after_drive_rush is structure: a derivation
comes out of its parent with nothing in between, and a rush is in between.
A starter the source lists without a Drive Rush Cancel is counted once above
rather than once per target.

## Route candidates

- routes                  1156
- graph nodes             61
- graph edges             611
- folded canonical variants 3455  (same buttons, unresolved action id)
- search complete         false
  beam dropped 1307 partial routes, 0 routes not emitted
  length 2               280
  length 3               876

dropped by a search bound (not by the game):
  max_repeat_per_action    6

## Top 10 by predicted damage

Predicted damage is an UNSCALED frame-table sum. Combo scaling appears in no
frame table and neither does Modern's own damage reduction, so this is an
upper bound for ordering, never a damage figure.

#   route                                            dmg~   cost conf    unknowns
1   2 + 强 > 236236 + 强                           4800    8.9 low     7
2   2 + 强 > 2 + SP + 强                           4800    6.5 low     7
3   中 > 236236 + 强                               4600    8.4 low     7
4   中 > 2 + SP + 强                               4600    6.0 low     7
5   4 + 中 > 236236 + 强                           4500    8.9 low     7
6   4 + 中 > 2 + SP + 强                           4500    6.5 low     7
7   弱 > 236236 + 强                               4300    8.4 low     7
8   弱 > 2 + SP + 强                               4300    6.0 low     7
9   2 + 弱 > 236236 + 强                           4300    8.9 low     7
10  2 + 弱 > 2 + SP + 强                           4300    6.5 low     7

## Top 10 by predicted scaled damage (model)

A MODEL, NOT A DAMAGE FIGURE. Each move's frame-table damage times a
per-move factor from public descriptions of SF6 scaling (sf6-public-scaling-v1,
verified = false): 100/100/80/70.. per move, a light-normal starter
100/80/70.., floor 10%, x0.85 after a Drive Rush, x0.8 on SP moves, and
the Super Art minimum. Not modelled: 9 things, listed in
scaling_model.not_modelled on every route. Used for ordering only.

#   route                                         scaled~     dmg~   cost conf   
1   2 + 强 > 236236 + 强                           4800     4800    8.9 low    
2   中 > 236236 + 强                               4600     4600    8.4 low    
3   4 + 中 > 236236 + 强                           4500     4500    8.9 low    
4   6 + 强 > 236236 + 强                           4300     4300    8.9 low    
5   2 + 强 > 2 + SP + 强                           4000     4800    6.5 low    
6   中 > 2 + SP + 强                               3800     4600    6.0 low    
7   4 + 中 > 2 + SP + 强                           3700     4500    6.5 low    
8   弱 > 236236 + 强                               3500     4300    8.4 low    
9   2 + 弱 > 236236 + 强                           3500     4300    8.9 low    
10  6 + 强 > 2 + SP + 强                           3500     4300    6.5 low    

## Top 10 by fewest inputs

#   route                                            dmg~   cost conf   
1   弱 > 弱                                         600    2.5 medium 
2   弱 > 中                                         900    3.0 medium 
3   弱 > 强                                        1100    3.0 medium 
4   弱 > > 空中 THROW                              300    3.0 low    
5   中 > > 空中 THROW                              600    3.0 low    
6   强 > 弱                                        1100    3.0 medium 
7   强 > > 强                                       800    3.0 medium 
8   强 > > 空中 THROW                              800    3.0 low    
9   弱 > 2 + 弱                                     600    3.5 medium 
10  弱 > 2 + 强                                    1100    3.5 medium 

## Pareto frontier: 8 routes nothing beats on both damage and inputs

1   2 + 强 > 2 + SP + 强                           4800    6.5
2   中 > 2 + SP + 强                               4600    6.0
3   3 + 强 > 弱 > 3 + 强                          2100    5.5
4   弱 > 3 + 强 > 强                              2000    5.0
5   强 > 弱 > 强                                  1900    4.5
6   3 + 强 > 强                                    1700    3.5
7   弱 > 强                                        1100    3.0
8   弱 > 弱                                         600    2.5

## Why the game still has to answer

- **actual_input_timing**
  the actual input window is what the sweep exists to measure
- **cancel_window_conditions**
  cancel windows into specials and supers have conditions no frame table lists
- **frame_data_variant_ambiguous**
  the frame source lists "236236K" 2 times - Interdiction / Interdiction (CA) - and the join took whichever came first; which one the input produces depends on something the frame table does not model
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

- candidates/jp/modern/candidate-edges.json  (801845 bytes)
- candidates/jp/modern/candidate-routes.json  (7980795 bytes)
- reframework/data/ComboExplorer_data/worklist/jp-modern-drc.json  (81930 bytes)
- reframework/data/ComboExplorer_data/worklist/jp-modern.json  (249447 bytes)

Both documents carry runtime_verified = false and every record in them is
status = theoretical. The next step is the gaming machine: calibration,
then a sweep, then these become confirmed edges or rejected ones.
