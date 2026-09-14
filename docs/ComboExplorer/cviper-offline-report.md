# Offline candidate report - CViper / modern / midscreen / none

EVERYTHING BELOW IS A THEORETICAL CANDIDATE. Nothing here has been run on
Street Fighter 6. These are pairs and sequences worth spending a trial on,
not combos that are known to work.

## Provenance

- command_display: CViper, generated 2026-08-03T00:00:00.000Z
  - ac_sha256  a9e27462064db02e61c86e7ca3087956b778a2311566e73f6937224181d161ea
  - bcm_sha256 96cf593e23d5bc91aafecf001dea43a71a703e7cfd129069afa845d887ff2a35
- frame data: RyoSogawa/sf6-sensei @ a64f2acf90fffc855ddc1a958a4ee752e15c571c (CC-BY-SA)
  - original work: SuperCombo Wiki, CC-BY-SA-4.0. See docs/NOTICE.md.
- game patch: command_display@2026-08-03T00:00:00.000Z
  (the command_display generation date, not a confirmed game version - the real patch is only knowable on the machine running the game)

## Moves searched

- catalog rows            117
- starting moves          12  (normal,command_normal / manual)
- target moves            43  (normal,command_normal,special,od_special,super / manual,simple)
- excluded from probing   64  (classic-only, air, throws, system, follow-ups)
- frame data coverage     39 of 43 (91%)  over every row this run uses
    starters      12 of  12 (100%)
    targets       39 of  43 ( 91%)
    4 matched only by guessing between several source spellings:
      214214+K (1218) -> 214214K
      214214+K (1218) -> 214214K
      214214+K (1222) -> 214214K
      214214+K (1222) -> 214214K
    4 with no frame data at all:
      6+PP (914)
      6+PP (915)
      6+PP (916)
      6+PP (917)
- unresolved canonical ids 27 groups covering 71 rows
- no Modern form at all     17
    34  8
    603  MP
    608  HK
    610  2+LP
    852  6
    906  Normal
    907  Normal
    974  Normal
    1002  66
    1014  528
    1015  528
    1018  528
    1019  528
    1036  528
    1037  528
    1040  528
    1041  528

## Theoretical edges

- pairs considered        516
- candidate edges         295
- excluded                221

by reason:
  chain_cancel             80
  frame_data_incomplete    48
  frame_link               73
  special_cancel           95
  super_cancel             40

by confidence:
  high                     115
  medium                   108
  low                      72

excluded because the data said no:
  frame_margin_negative    214
  self_pair_without_chain  7

Nothing was excluded for missing data. A gap in the source is recorded as
an unknown and the pair stays a candidate; only a KNOWN negative margin
excludes, and the margin is kept with it.

## Drive Rush Cancel candidates

A -> Drive Rush Cancel -> B. NONE OF THESE CAN BE PRESSED YET: how Drive
Rush is input on this build and which action id a Drive Rush Cancel is
have never been measured. They are not in the route search below, and with
--worklist they go to their own file, which the sweep does not read.

- DRC record              "MPMK or 66": startup 9, recovery 15, drive cost 30000
- starters that can rush  5  (drc_on_hit in the frame data)
- starters nobody knows   0  (no record, or a guessed one: kept, low)
- starters that cannot    7  (record present, no Drive Rush Cancel in it)
    604:manual 强
    606:manual 中
    614:manual 2 + 弱
    615:manual 2 + 中
    616:manual 3 + 强
    635:manual 6 + 中
    636:manual 6 + 强
- pairs considered        215
- DRC edges               64
- excluded                151

by confidence:
  high                     19
  medium                   21
  low                      24

excluded:
  drc_margin_negative      151

drc_margin_negative is drc_on_hit minus B's startup, known and below zero,
kept with the number. followup_after_drive_rush is structure: a derivation
comes out of its parent with nothing in between, and a rush is in between.
A starter the source lists without a Drive Rush Cancel is counted once above
rather than once per target.

## Route candidates

- routes                  719
- graph nodes             43
- graph edges             295
- folded canonical variants 1847  (same buttons, unresolved action id)
- search complete         true
  length 2               137
  length 3               582

dropped by a search bound (not by the game):
  max_repeat_per_action    5

## Top 10 by predicted damage

Predicted damage is an UNSCALED frame-table sum. Combo scaling appears in no
frame table and neither does Modern's own damage reduction, so this is an
upper bound for ordering, never a damage figure.

#   route                                            dmg~   cost conf    unknowns
1   3 + 强 > 2 + 强 > 214214 + 强                 5700   10.9 low     8
2   3 + 强 > 2 + 强 > 2 + SP + 强                 5700    8.5 low     8
3   弱 > 3 + 强 > 214214 + 强                     5200   10.4 low     8
4   弱 > 3 + 强 > 2 + SP + 强                     5200    8.0 low     8
5   3 + 强 > 弱 > 214214 + 强                     5200   10.4 low     8
6   3 + 强 > 弱 > 2 + SP + 强                     5200    8.0 low     8
7   3 + 强 > 2 + 弱 > 214214 + 强                 5200   10.9 low     8
8   3 + 强 > 2 + 弱 > 2 + SP + 强                 5200    8.5 low     8
9   弱 > 2 + 强 > 214214 + 强                     5100   10.4 low     7
10  弱 > 2 + 强 > 2 + SP + 强                     5100    8.0 low     7

## Top 10 by predicted scaled damage (model)

A MODEL, NOT A DAMAGE FIGURE. Each move's frame-table damage times a
per-move factor from public descriptions of SF6 scaling (sf6-public-scaling-v1,
verified = false): 100/100/80/70.. per move, a light-normal starter
100/80/70.., floor 10%, x0.85 after a Drive Rush, x0.8 on SP moves, and
the Super Art minimum. Not modelled: 9 things, listed in
scaling_model.not_modelled on every route. Used for ordering only.

#   route                                         scaled~     dmg~   cost conf   
1   3 + 强 > 214214 + 强                           4900     4900    8.9 low    
2   3 + 强 > 2 + 强 > 214214 + 强                 4900     5700   10.9 low    
3   2 + 强 > 214214 + 强                           4800     4800    8.9 low    
4   3 + 强 > 弱 > 214214 + 强                     4400     5200   10.4 low    
5   3 + 强 > 2 + 弱 > 214214 + 强                 4400     5200   10.9 low    
6   3 + 强 > 2 + 强 > 2 + SP + 强                 4260     5700    8.5 low    
7   中 > 弱 > 214214 + 强                         4200     5000    9.9 low    
8   中 > 2 + 弱 > 214214 + 强                     4200     5000   10.4 low    
9   2 + 中 > 弱 > 214214 + 强                     4100     4900   10.4 low    
10  2 + 中 > 2 + 弱 > 214214 + 强                 4100     4900   10.9 low    

## Top 10 by fewest inputs

#   route                                            dmg~   cost conf   
1   弱 > 弱                                         600    2.5 medium 
2   弱 > 强                                        1200    3.0 medium 
3   弱 > 中                                        1000    3.0 medium 
4   中 > 弱                                        1000    3.0 medium 
5   弱 > 2 + 强                                    1100    3.5 medium 
6   弱 > 2 + 弱                                     500    3.5 medium 
7   弱 > 2 + 中                                     900    3.5 medium 
8   弱 > 3 + 强                                    1200    3.5 medium 
9   弱 > 6 + 中                                     900    3.5 medium 
10  弱 > 6 + 强                                     750    3.5 medium 

## Pareto frontier: 10 routes nothing beats on both damage and inputs

1   3 + 强 > 2 + 强 > 2 + SP + 强                 5700    8.5
2   弱 > 3 + 强 > 2 + SP + 强                     5200    8.0
3   中 > 弱 > 2 + SP + 强                         5000    7.5
4   3 + 强 > 2 + SP + 强                           4900    6.5
5   弱 > 2 + SP + 强                               4300    6.0
6   弱 > 3 + 强 > 强                              2100    5.0
7   中 > 弱 > 强                                  1900    4.5
8   3 + 强 > 强                                    1800    3.5
9   弱 > 强                                        1200    3.0
10  弱 > 弱                                         600    2.5

## Why the game still has to answer

- **actual_input_timing**
  the actual input window is what the sweep exists to measure
- **cancel_window_conditions**
  cancel windows into specials and supers have conditions no frame table lists
- **frame_data_variant_ambiguous**
  the frame source lists "214214K" 2 times - Hard Luck Rejector / Hard Luck Rejector (CA) - and the join took whichever came first; which one the input produces depends on something the frame table does not model
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

  902  classic_modern but no Modern command form
  902  simple_command names neither SP nor AUTO
  904  classic_modern but no Modern command form
  904  simple_command names neither SP nor AUTO
  970  classic_modern but no Modern command form
  970  simple_command names neither SP nor AUTO
  1029  classic_modern but no Modern command form
  1029  simple_command names neither SP nor AUTO
  1030  classic_modern but no Modern command form
  1030  simple_command names neither SP nor AUTO

## Written

- candidates/cviper/modern/candidate-edges.json  (384085 bytes)
- candidates/cviper/modern/candidate-routes.json  (4991561 bytes)
- reframework/data/ComboExplorer_data/worklist/cviper-modern-drc.json  (30292 bytes)
- reframework/data/ComboExplorer_data/worklist/cviper-modern.json  (118815 bytes)

Both documents carry runtime_verified = false and every record in them is
status = theoretical. The next step is the gaming machine: calibration,
then a sweep, then these become confirmed edges or rejected ones.
