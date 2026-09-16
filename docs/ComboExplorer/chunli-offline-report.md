# Offline candidate report - ChunLi / modern / midscreen / none

EVERYTHING BELOW IS A THEORETICAL CANDIDATE. Nothing here has been run on
Street Fighter 6. These are pairs and sequences worth spending a trial on,
not combos that are known to work.

## Provenance

- command_display: ChunLi, generated 2026-08-03T00:00:00.000Z
  - ac_sha256  8dcd21cab1ae11982c8fb011d4ad04beece543d366205552dabedc861c5e24a2
  - bcm_sha256 a98f1bd8ad8d517fbda07a0fb57bea7786d3266ea57f6b1a3a2b613ac7e331d6
- frame data: RyoSogawa/sf6-sensei @ a64f2acf90fffc855ddc1a958a4ee752e15c571c (CC-BY-SA)
  - original work: SuperCombo Wiki, CC-BY-SA-4.0. See docs/NOTICE.md.
- game patch: command_display@2026-08-03T00:00:00.000Z
  (the command_display generation date, not a confirmed game version - the real patch is only knowable on the machine running the game)

## Moves searched

- catalog rows            109
- starting moves          19  (normal,command_normal / manual)
- target moves            49  (normal,command_normal,special,od_special,super / manual,simple)
- excluded from probing   53  (air 17, any_button 17, system 11, followup 3, throw 2, unclassified 2, assist_combo 1)
- frame data coverage     49 of 52 (94%)  over every row this run uses
    starters      19 of  19 (100%)
    targets       49 of  49 (100%)
    follow-ups     0 of   3 (  0%)
    4 matched only by guessing between several source spellings:
      214214+K (1218) -> 214214K
      214214+K (1218) -> 214214K
      214214+K (1222) -> 214214K
      214214+K (1222) -> 214214K
    3 with no frame data at all:
      >j.2+MK (699)
      >j.2+MK (700)
      >j.HP (709)
- unresolved canonical ids 15 groups covering 42 rows
- no Modern form at all     6
    604  MK
    605  HK
    607  2+LP
    627  3+HP
    629  3+HK
    852  6

## Theoretical edges

- pairs considered        988
- candidate edges         619
- excluded                369

by reason:
  chain_cancel             114
  frame_link               150
  special_cancel           308
  super_cancel             112

by confidence:
  high                     364
  medium                   195
  low                      60

excluded because the data said no:
  followup_after_a_move_not_its_parent 57
  frame_margin_negative    299
  self_pair_without_chain  13

Nothing was excluded for missing data. A gap in the source is recorded as
an unknown and the pair stays a candidate; only a KNOWN negative margin
excludes, and the margin is kept with it.

followup_after_a_move_not_its_parent is not a gap either. The frame source spells
a follow-up only as a chain from the move it comes out of ("5MP~MP"), so
these 57 pairs put a follow-up after a move the source says it does not
follow. A follow-up whose parent the source never names stays a candidate.

## Drive Rush Cancel candidates

A -> Drive Rush Cancel -> B. NONE OF THESE CAN BE PRESSED YET: how Drive
Rush is input on this build and which action id a Drive Rush Cancel is
have never been measured. They are not in the route search below, and with
--worklist they go to their own file, which the sweep does not read.

- DRC record              "MPMK or 66": startup 9, recovery 15, drive cost 30000
- starters that can rush  14  (drc_on_hit in the frame data)
- starters nobody knows   0  (no record, or a guessed one: kept, low)
- starters that cannot    5  (record present, no Drive Rush Cancel in it)
    602:manual 强
    614:manual 3 + 强
    628:manual 6 + 强
    666:manual 强
    669:manual 2 + 强
- pairs considered        728
- DRC edges               257
- excluded                471

by confidence:
  high                     143
  medium                   86
  low                      28

excluded:
  drc_margin_negative      429
  followup_after_drive_rush 42

drc_margin_negative is drc_on_hit minus B's startup, known and below zero,
kept with the number. followup_after_drive_rush is structure: a derivation
comes out of its parent with nothing in between, and a rush is in between.
A starter the source lists without a Drive Rush Cancel is counted once above
rather than once per target.

## Route candidates

- routes                  1157
- graph nodes             49
- graph edges             619
- folded canonical variants 3462  (same buttons, unresolved action id)
- search complete         false
  beam dropped 1991 partial routes, 0 routes not emitted
  length 2               263
  length 3               894

dropped by a search bound (not by the game):
  max_repeat_per_action    6

## Top 10 by predicted damage

Predicted damage is an UNSCALED frame-table sum. Combo scaling appears in no
frame table and neither does Modern's own damage reduction, so this is an
upper bound for ordering, never a damage figure.

#   route                                            dmg~   cost conf    unknowns
1   3 + 强 > 214214 + 强                           4900    8.9 low     8
2   3 + 强 > 2 + SP + 强                           4900    6.5 low     8
3   4 + 强 > 214214 + 强                           4800    8.9 low     7
4   4 + 强 > 2 + SP + 强                           4800    6.5 low     7
5   中 > 214214 + 强                               4600    8.4 low     7
6   中 > 2 + SP + 强                               4600    6.0 low     7
7   6 或 4 + 中 > 214214 + 强                     4600   10.2 low     7
8   6 或 4 + 中 > 2 + SP + 强                     4600    7.8 low     7
9   2 + 中 > 214214 + 强                           4500    8.9 low     7
10  2 + 中 > 2 + SP + 强                           4500    6.5 low     7

## Top 10 by predicted scaled damage (model)

A MODEL, NOT A DAMAGE FIGURE. Each move's frame-table damage times a
per-move factor from public descriptions of SF6 scaling (sf6-public-scaling-v1,
verified = false): 100/100/80/70.. per move, a light-normal starter
100/80/70.., floor 10%, x0.85 after a Drive Rush, x0.8 on SP moves, and
the Super Art minimum. Not modelled: 9 things, listed in
scaling_model.not_modelled on every route. Used for ordering only.

#   route                                         scaled~     dmg~   cost conf   
1   3 + 强 > 214214 + 强                           4900     4900    8.9 low    
2   4 + 强 > 214214 + 强                           4800     4800    8.9 low    
3   中 > 214214 + 强                               4600     4600    8.4 low    
4   6 或 4 + 中 > 214214 + 强                     4600     4600   10.2 low    
5   2 + 中 > 214214 + 强                           4500     4500    8.9 low    
6   2 + 强 > 214214 + 强                           4450     4450    8.9 low    
7   3 + 强 > 2 + SP + 强                           4100     4900    6.5 low    
8   4 + 强 > 2 + SP + 强                           4000     4800    6.5 low    
9   中 > 2 + SP + 强                               3800     4600    6.0 low    
10  6 或 4 + 中 > 2 + SP + 强                     3800     4600    7.8 low    

## Top 10 by fewest inputs

#   route                                            dmg~   cost conf   
1   弱 > 弱                                         600    2.5 medium 
2   弱 > 中                                         900    3.0 medium 
3   弱 > 强                                        1100    3.0 medium 
4   中 > 弱                                         900    3.0 medium 
5   中 > 中                                        1200    3.0 medium 
6   弱 > 2 + 强                                     750    3.5 medium 
7   弱 > 2 + 弱                                     500    3.5 medium 
8   弱 > 2 + 中                                     800    3.5 medium 
9   弱 > 3 + 强                                    1200    3.5 medium 
10  弱 > 4 + 强                                    1100    3.5 medium 

## Pareto frontier: 8 routes nothing beats on both damage and inputs

1   3 + 强 > 2 + SP + 强                           4900    6.5
2   中 > 2 + SP + 强                               4600    6.0
3   3 + 强 > 4 + 强 > 中                          2300    5.5
4   3 + 强 > 中 > 中                              2100    5.0
5   中 > 中 > 中                                  1800    4.5
6   3 + 强 > 强                                    1700    3.5
7   中 > 中                                        1200    3.0
8   弱 > 弱                                         600    2.5

## Why the game still has to answer

- **actual_input_timing**
  the actual input window is what the sweep exists to measure
- **cancel_window_conditions**
  cancel windows into specials and supers have conditions no frame table lists
- **frame_data_variant_ambiguous**
  the frame source lists "214214K" 2 times - Soten Ranka / Soten Ranka (CA) - and the join took whichever came first; which one the input produces depends on something the frame table does not model
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

  755  classic_modern but no Modern command form
  755  simple_command names neither SP nor AUTO

## Written

- candidates/chunli/modern/candidate-edges.json  (790454 bytes)
- candidates/chunli/modern/candidate-routes.json  (8010782 bytes)
- reframework/data/ComboExplorer_data/worklist/chunli-modern-drc.json  (122460 bytes)
- reframework/data/ComboExplorer_data/worklist/chunli-modern.json  (253994 bytes)

Both documents carry runtime_verified = false and every record in them is
status = theoretical. The next step is the gaming machine: calibration,
then a sweep, then these become confirmed edges or rejected ones.
