# Offline candidate report - Cammy / modern / midscreen / none

EVERYTHING BELOW IS A THEORETICAL CANDIDATE. Nothing here has been run on
Street Fighter 6. These are pairs and sequences worth spending a trial on,
not combos that are known to work.

## Provenance

- command_display: Cammy, generated 2026-08-03T00:00:00.000Z
  - ac_sha256  41ddf70bd1d5575d721ea88168ef4239bc3fb16c4f082d5a9dbc7dbb9ac89868
  - bcm_sha256 2114b1872f9397a6a4f45750a2ea67563aeffca51b60963aac212a35f34c703f
- frame data: RyoSogawa/sf6-sensei @ a64f2acf90fffc855ddc1a958a4ee752e15c571c (CC-BY-SA)
  - original work: SuperCombo Wiki, CC-BY-SA-4.0. See docs/NOTICE.md.
- game patch: command_display@2026-08-03T00:00:00.000Z
  (the command_display generation date, not a confirmed game version - the real patch is only knowable on the machine running the game)

## Moves searched

- catalog rows            93
- starting moves          14  (normal,command_normal / manual)
- target moves            44  (normal,command_normal,special,od_special,super / manual,simple)
- excluded from probing   40  (air 17, system 11, any_button 6, assist_combo 2, throw 2, followup 1, unclassified 1)
- frame data coverage     44 of 45 (98%)  over every row this run uses
    starters      14 of  14 (100%)
    targets       44 of  44 (100%)
    follow-ups     0 of   1 (  0%)
    4 matched only by guessing between several source spellings:
      236236+P (1231) -> 236236P
      236236+P (1231) -> 236236P
      236236+P (1241) -> 236236P
      236236+P (1241) -> 236236P
    1 with no frame data at all:
      >HK (651)
- unresolved canonical ids 15 groups covering 32 rows
- no Modern form at all     22
    609  LK
    612  MK
    618  2+LP
    750  >8
    852  6
    964  j.P
    965  j.P
    966  j.P
    970  j.Throw
    975  j.Throw
    979  j.Throw
    985  j.2+K
    987  j.2+K
    989  j.2+K
    999  j.2+K
    1000  j.2+K
    1001  j.2+K
    1005  j.LK
    1007  j.MK
    1009  j.HK
    1011  j.K
    1013  j.K

## Theoretical edges

- pairs considered        630
- candidate edges         453
- excluded                177

by reason:
  chain_cancel             84
  frame_link               198
  special_cancel           198
  super_cancel             72
  target_combo             1

by confidence:
  high                     187
  medium                   226
  low                      40

excluded because the data said no:
  followup_after_a_move_not_its_parent 13
  frame_margin_negative    156
  self_pair_without_chain  8

Nothing was excluded for missing data. A gap in the source is recorded as
an unknown and the pair stays a candidate; only a KNOWN negative margin
excludes, and the margin is kept with it.

followup_after_a_move_not_its_parent is not a gap either. The frame source spells
a follow-up only as a chain from the move it comes out of ("5MP~MP"), so
these 13 pairs put a follow-up after a move the source says it does not
follow. A follow-up whose parent the source never names stays a candidate.

- follow-up edges         1  (parent named by the frame data: 1)

## Drive Rush Cancel candidates

A -> Drive Rush Cancel -> B. NONE OF THESE CAN BE PRESSED YET: how Drive
Rush is input on this build and which action id a Drive Rush Cancel is
have never been measured. They are not in the route search below, and with
--worklist they go to their own file, which the sweep does not read.

- DRC record              "MPMK or 66": startup 9, recovery 15, drive cost 30000
- starters that can rush  9  (drc_on_hit in the frame data)
- starters nobody knows   0  (no record, or a guessed one: kept, low)
- starters that cannot    5  (record present, no Drive Rush Cancel in it)
    604:manual 中
    615:manual 强
    625:manual 2 + 强
    628:manual 2 + 弱
    635:manual 3 + 强
- pairs considered        405
- DRC edges               166
- excluded                239

by confidence:
  high                     27
  medium                   123
  low                      16

excluded:
  drc_margin_negative      230
  followup_after_drive_rush 9

drc_margin_negative is drc_on_hit minus B's startup, known and below zero,
kept with the number. followup_after_drive_rush is structure: a derivation
comes out of its parent with nothing in between, and a rush is in between.
A starter the source lists without a Drive Rush Cancel is counted once above
rather than once per target.

## Route candidates

- routes                  1541
- graph nodes             45
- graph edges             453
- folded canonical variants 2912  (same buttons, unresolved action id)
- search complete         false
  beam dropped 713 partial routes, 0 routes not emitted
  length 2               248
  length 3               1293

dropped by a search bound (not by the game):
  max_repeat_per_action    6

## Top 10 by predicted damage

Predicted damage is an UNSCALED frame-table sum. Combo scaling appears in no
frame table and neither does Modern's own damage reduction, so this is an
upper bound for ordering, never a damage figure.

#   route                                            dmg~   cost conf    unknowns
1   3 + 强 > 236236 + 强                           4900    8.9 low     8
2   3 + 强 > 2 + SP + 强                           4900    6.5 low     8
3   4 + 强 > 236236 + 强                           4800    8.9 low     8
4   4 + 强 > 2 + SP + 强                           4800    6.5 low     8
5   6 + 强 > 236236 + 强                           4800    8.9 low     8
6   6 + 强 > 2 + SP + 强                           4800    6.5 low     8
7   3 + 强 > 4 + 强 > 214214 + 中                 4700   10.9 medium  7
8   3 + 强 > 4 + 强 > 4 + SP + 强                 4700    8.5 medium  7
9   3 + 强 > 6 + 强 > 214214 + 中                 4700   10.9 medium  7
10  3 + 强 > 6 + 强 > 4 + SP + 强                 4700    8.5 medium  7

## Top 10 by predicted scaled damage (model)

A MODEL, NOT A DAMAGE FIGURE. Each move's frame-table damage times a
per-move factor from public descriptions of SF6 scaling (sf6-public-scaling-v1,
verified = false): 100/100/80/70.. per move, a light-normal starter
100/80/70.., floor 10%, x0.85 after a Drive Rush, x0.8 on SP moves, and
the Super Art minimum. Not modelled: 9 things, listed in
scaling_model.not_modelled on every route. Used for ordering only.

#   route                                         scaled~     dmg~   cost conf   
1   3 + 强 > 236236 + 强                           4900     4900    8.9 low    
2   4 + 强 > 236236 + 强                           4800     4800    8.9 low    
3   6 + 强 > 236236 + 强                           4800     4800    8.9 low    
4   2 + 中 > 236236 + 强                           4500     4500    8.9 low    
5   4 + 中 > 236236 + 强                           4500     4500    8.9 low    
6   3 + 强 > 2 + SP + 强                           4100     4900    6.5 low    
7   3 + 强 > 4 + 强 > 214214 + 中                 4100     4700   10.9 medium 
8   3 + 强 > 6 + 强 > 214214 + 中                 4100     4700   10.9 medium 
9   4 + 强 > 3 + 强 > 214214 + 中                 4100     4700   10.9 medium 
10  6 + 强 > 3 + 强 > 214214 + 中                 4100     4700   10.9 medium 

## Top 10 by fewest inputs

#   route                                            dmg~   cost conf   
1   弱 > 弱                                         600    2.5 medium 
2   弱 > 中                                         900    3.0 medium 
3   弱 > 强                                        1200    3.0 medium 
4   中 > 弱                                         900    3.0 medium 
5   弱 > 2 + 弱                                     600    3.5 medium 
6   弱 > 2 + 强                                    1000    3.5 medium 
7   弱 > 2 + 中                                     800    3.5 medium 
8   弱 > 3 + 强                                    1200    3.5 medium 
9   弱 > 4 + 中                                     800    3.5 medium 
10  弱 > 4 + 强                                    1100    3.5 medium 

## Pareto frontier: 7 routes nothing beats on both damage and inputs

1   3 + 强 > 2 + SP + 强                           4900    6.5
2   弱 > 2 + SP + 强                               4300    6.0
3   3 + 强 > 4 + 强 > 强                          2600    5.5
4   弱 > 3 + 强 > 强                              2100    5.0
5   3 + 强 > 强                                    1800    3.5
6   弱 > 强                                        1200    3.0
7   弱 > 弱                                         600    2.5

## Why the game still has to answer

- **actual_input_timing**
  the actual input window is what the sweep exists to measure
- **cancel_window_conditions**
  cancel windows into specials and supers have conditions no frame table lists
- **frame_data_variant_ambiguous**
  the frame source lists "236236P" 2 times - Delta Red Assault / Delta Red Assault (CA) - and the join took whichever came first; which one the input produces depends on something the frame table does not model
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

  652  classic_modern but no Modern command form
  652  simple_command names neither SP nor AUTO

## Written

- candidates/cammy/modern/candidate-edges.json  (586160 bytes)
- candidates/cammy/modern/candidate-routes.json  (10674113 bytes)
- reframework/data/ComboExplorer_data/worklist/cammy-modern-drc.json  (77892 bytes)
- reframework/data/ComboExplorer_data/worklist/cammy-modern.json  (184138 bytes)

Both documents carry runtime_verified = false and every record in them is
status = theoretical. The next step is the gaming machine: calibration,
then a sweep, then these become confirmed edges or rejected ones.
