# Offline candidate report - Alex / modern / midscreen / none

EVERYTHING BELOW IS A THEORETICAL CANDIDATE. Nothing here has been run on
Street Fighter 6. These are pairs and sequences worth spending a trial on,
not combos that are known to work.

## Provenance

- command_display: Alex, generated 2026-08-03T00:00:00.000Z
  - ac_sha256  3f208fbb93b989829c8a5435a8b83ced717c87ebe16020058efba0dcac3d6dda
  - bcm_sha256 73d20f4a8efc2d8042572ac0a4655f4967a4706fa852035aeef127e2c9dc05f2
- frame data: RyoSogawa/sf6-sensei @ a64f2acf90fffc855ddc1a958a4ee752e15c571c (CC-BY-SA)
  - original work: SuperCombo Wiki, CC-BY-SA-4.0. See docs/NOTICE.md.
- game patch: command_display@2026-08-03T00:00:00.000Z
  (the command_display generation date, not a confirmed game version - the real patch is only knowable on the machine running the game)

## Moves searched

- catalog rows            96
- starting moves          22  (normal,command_normal / manual)
- target moves            48  (normal,command_normal,special,od_special,super / manual,simple)
- excluded from probing   42  (classic-only, air, throws, system, follow-ups)
- frame data coverage     48 of 56 (86%)  over every row this run uses
    starters      22 of  22 (100%)
    targets       48 of  48 (100%)
    follow-ups     0 of   8 (  0%)
    12 matched only by guessing between several source spellings:
      LP (971) -> 5LP
      MP (973) -> 5MP
      HP (976) -> 5HP
      LK (978) -> 5LK
      LK (979) -> 5LK
      MK (980) -> 5MK
      MK (981) -> 5MK
      63214+P (923) -> 63214LP
      236236+P (1230) -> 236236P
      236236+P (1230) -> 236236P
      236236+P (1242) -> 236236P
      236236+P (1242) -> 236236P
    8 with no frame data at all:
      >HP (606)
      >6 (962)
      >4 (964)
      >6+P (967)
      >LP (970)
      >LP (972)
      >HK (982)
      >HK (983)
- unresolved canonical ids 18 groups covering 49 rows
- no Modern form at all     6
    34  8
    614  MK
    621  2+LP
    852  6
    958  2+PP
    959  2+PP

## Theoretical edges

- pairs considered        1232
- candidate edges         583
- excluded                649

by reason:
  chain_cancel             154
  frame_link               187
  special_cancel           198
  super_cancel             96
  target_combo             2

by confidence:
  high                     147
  medium                   188
  low                      248

excluded because the data said no:
  followup_after_a_move_not_its_parent 174
  frame_margin_negative    460
  self_pair_without_chain  15

Nothing was excluded for missing data. A gap in the source is recorded as
an unknown and the pair stays a candidate; only a KNOWN negative margin
excludes, and the margin is kept with it.

followup_after_a_move_not_its_parent is not a gap either. The frame source spells
a follow-up only as a chain from the move it comes out of ("5MP~MP"), so
these 174 pairs put a follow-up after a move the source says it does not
follow. A follow-up whose parent the source never names stays a candidate.

- follow-up edges         2  (parent named by the frame data: 2)

## Drive Rush Cancel candidates

A -> Drive Rush Cancel -> B. NONE OF THESE CAN BE PRESSED YET: how Drive
Rush is input on this build and which action id a Drive Rush Cancel is
have never been measured. They are not in the route search below, and with
--worklist they go to their own file, which the sweep does not read.

- DRC record              "MPMK or 66": startup 9, recovery 15, drive cost 30000
- starters that can rush  7  (drc_on_hit in the frame data)
- starters nobody knows   7  (no record, or a guessed one: kept, low)
- starters that cannot    8  (record present, no Drive Rush Cancel in it)
    616:manual 强
    633:manual 2 + 弱
    636:manual 2 + 强
    638:manual 2 + 中
    640:manual 3 + 强
    670:manual 6 + 中
    671:manual 4 + 中
    672:manual 4 + 中
- pairs considered        784
- DRC edges               349
- excluded                435

by confidence:
  high                     47
  medium                   55
  low                      247

excluded:
  drc_margin_negative      323
  followup_after_drive_rush 112

drc_margin_negative is drc_on_hit minus B's startup, known and below zero,
kept with the number. followup_after_drive_rush is structure: a derivation
comes out of its parent with nothing in between, and a rush is in between.
A starter the source lists without a Drive Rush Cancel is counted once above
rather than once per target.

## Route candidates

- routes                  919
- graph nodes             49
- graph edges             583
- folded canonical variants 3664  (same buttons, unresolved action id)
- search complete         false
  beam dropped 2652 partial routes, 0 routes not emitted
  length 2               162
  length 3               757

dropped by a search bound (not by the game):
  max_repeat_per_action    7

## Top 10 by predicted damage

Predicted damage is an UNSCALED frame-table sum. Combo scaling appears in no
frame table and neither does Modern's own damage reduction, so this is an
upper bound for ordering, never a damage figure.

#   route                                            dmg~   cost conf    unknowns
1   2 + 强 > 3 + 强 > 236236 + 强                 6000   10.9 low     8
2   2 + 强 > 3 + 强 > 2 + SP + 强                 6000    8.5 low     8
3   3 + 强 > 2 + 强 > 236236 + 强                 6000   10.9 low     8
4   3 + 强 > 2 + 强 > 2 + SP + 强                 6000    8.5 low     8
5   2 + 强 > 强 > 236236 + 强                     5900   10.4 low     8
6   2 + 强 > 强 > 2 + SP + 强                     5900    8.0 low     8
7   3 + 强 > 强 > 236236 + 强                     5900   10.4 low     8
8   3 + 强 > 强 > 2 + SP + 强                     5900    8.0 low     8
9   2 + 强 > 2 + 强 > 236236 + 强                 5800   10.9 low     8
10  2 + 强 > 2 + 强 > 2 + SP + 强                 5800    8.5 low     8

## Top 10 by predicted scaled damage (model)

A MODEL, NOT A DAMAGE FIGURE. Each move's frame-table damage times a
per-move factor from public descriptions of SF6 scaling (sf6-public-scaling-v1,
verified = false): 100/100/80/70.. per move, a light-normal starter
100/80/70.., floor 10%, x0.85 after a Drive Rush, x0.8 on SP moves, and
the Super Art minimum. Not modelled: 9 things, listed in
scaling_model.not_modelled on every route. Used for ordering only.

#   route                                         scaled~     dmg~   cost conf   
1   2 + 强 > 3 + 强 > 236236 + 强                 5200     6000   10.9 low    
2   3 + 强 > 2 + 强 > 236236 + 强                 5200     6000   10.9 low    
3   2 + 强 > 强 > 236236 + 强                     5100     5900   10.4 low    
4   3 + 强 > 强 > 236236 + 强                     5100     5900   10.4 low    
5   2 + 强 > 2 + 强 > 236236 + 强                 5000     5800   10.9 low    
6   3 + 强 > 236236 + 强                           5000     5000    8.9 low    
7   强 > 236236 + 强                               4900     4900    8.4 low    
8   2 + 强 > 236236 + 强                           4800     4800    8.9 low    
9   2 + 强 > 中 > 236236 + 强                     4800     5600   10.4 low    
10  3 + 强 > 中 > 236236 + 强                     4800     5600   10.4 low    

## Top 10 by fewest inputs

#   route                                            dmg~   cost conf   
1   弱 > 弱                                         600    2.5 medium 
2   弱 > 中                                         900    3.0 medium 
3   弱 > 强                                        1200    3.0 medium 
4   中 > 弱                                         900    3.0 medium 
5   中 > > 中                                       600    3.0 medium 
6   强 > 弱                                        1200    3.0 low    
7   弱 > 2 + 弱                                     600    3.5 medium 
8   弱 > 2 + 强                                    1100    3.5 medium 
9   弱 > 2 + 中                                     900    3.5 medium 
10  弱 > 3 + 强                                    1300    3.5 medium 

## Pareto frontier: 11 routes nothing beats on both damage and inputs

1   2 + 强 > 3 + 强 > 2 + SP + 强                 6000    8.5
2   2 + 强 > 强 > 2 + SP + 强                     5900    8.0
3   弱 > 强 > 2 + SP + 强                         5200    7.5
4   3 + 强 > 2 + SP + 强                           5000    6.5
5   强 > 2 + SP + 强                               4900    6.0
6   中 > 4 + SP                                     3100    5.5
7   弱 > 2 + 强 > 强                              2200    5.0
8   2 + 强 > 3 + 强                                2000    4.0
9   2 + 强 > 强                                    1900    3.5
10  弱 > 强                                        1200    3.0

## Why the game still has to answer

- **actual_input_timing**
  the actual input window is what the sweep exists to measure
- **cancel_window_conditions**
  cancel windows into specials and supers have conditions no frame table lists
- **frame_data_variant_ambiguous**
  the frame source lists "236236P" 2 times - The Final Prison / The Final Prison (CA) - and the join took whichever came first; which one the input produces depends on something the frame table does not model
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

  957  classic_modern but no Modern command form
  957  simple_command names neither SP nor AUTO

## Written

- candidates/alex/modern/candidate-edges.json  (853153 bytes)
- candidates/alex/modern/candidate-routes.json  (6458697 bytes)
- reframework/data/ComboExplorer_data/worklist/alex-modern-drc.json  (156907 bytes)
- reframework/data/ComboExplorer_data/worklist/alex-modern.json  (237466 bytes)

Both documents carry runtime_verified = false and every record in them is
status = theoretical. The next step is the gaming machine: calibration,
then a sweep, then these become confirmed edges or rejected ones.
