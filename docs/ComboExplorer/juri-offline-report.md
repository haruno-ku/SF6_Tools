# Offline candidate report - Juri / modern / midscreen / none

EVERYTHING BELOW IS A THEORETICAL CANDIDATE. Nothing here has been run on
Street Fighter 6. These are pairs and sequences worth spending a trial on,
not combos that are known to work.

## Provenance

- command_display: Juri, generated 2026-08-03T00:00:00.000Z
  - ac_sha256  58905c345ed46631cb36794997051ebbf8a1f7cb190046f55090b7367447512b
  - bcm_sha256 81e679302a8b255054bef13002b37e1a5e44155589db3ab6d5d0cda51e78c0d1
- frame data: RyoSogawa/sf6-sensei @ a64f2acf90fffc855ddc1a958a4ee752e15c571c (CC-BY-SA)
  - original work: SuperCombo Wiki, CC-BY-SA-4.0. See docs/NOTICE.md.
- game patch: command_display@2026-08-03T00:00:00.000Z
  (the command_display generation date, not a confirmed game version - the real patch is only knowable on the machine running the game)

## Moves searched

- catalog rows            182
- starting moves          40  (normal,command_normal / manual)
- target moves            108  (normal,command_normal,special,od_special,super / manual,simple)
- excluded from probing   46  (classic-only, air, throws, system, follow-ups)
- frame data coverage     108 of 120 (90%)  over every row this run uses
    starters      40 of  40 (100%)
    targets      108 of 108 (100%)
    follow-ups     0 of  12 (  0%)
    42 matched only by guessing between several source spellings:
      LK (923) -> 5LK
      LK (924) -> 5LK
      LK (925) -> 5LK
      LK (927) -> 5LK
      LK (928) -> 5LK
      LK (929) -> 5LK
      MK (934) -> 5MK
      MK (935) -> 5MK
      MK (936) -> 5MK
      MK (938) -> 5MK
      MK (939) -> 5MK
      MK (940) -> 5MK
      HK (944) -> 5HK
      HK (945) -> 5HK
      HK (946) -> 5HK
      HK (956) -> 5HK
      HK (957) -> 5HK
      HK (958) -> 5HK
      LK (923) -> 5LK
      LK (924) -> 5LK
      LK (925) -> 5LK
      LK (927) -> 5LK
      LK (928) -> 5LK
      LK (929) -> 5LK
      MK (934) -> 5MK
      MK (935) -> 5MK
      MK (936) -> 5MK
      MK (938) -> 5MK
      MK (939) -> 5MK
      MK (940) -> 5MK
      236+HK (942) -> 236HK
      HK (944) -> 5HK
      HK (945) -> 5HK
      HK (946) -> 5HK
      236+HK (955) -> 236HK
      HK (956) -> 5HK
      HK (957) -> 5HK
      HK (958) -> 5HK
      214214+K (1221) -> 214214K
      214214+K (1221) -> 214214K
      214214+K (1226) -> 214214K
      214214+K (1226) -> 214214K
    12 with no frame data at all:
      >4+HP (604)
      >HP (605)
      >j.214+K (965)
      >j.214+K (965)
      >j.K (966)
      >j.K (966)
      >j.K (966)
      >j.214+KK (978)
      >j.214+KK (978)
      >j.214+KK (978)
      >j.K (981)
      >j.K (981)
- unresolved canonical ids 43 groups covering 147 rows
- no Modern form at all     5
    34  8
    600  LP
    612  MK
    665  8
    852  6

## Theoretical edges

- pairs considered        4800
- candidate edges         2388
- excluded                2412

by reason:
  chain_cancel             290
  frame_data_incomplete    400
  frame_link               457
  special_cancel           1148
  super_cancel             392
  target_combo             22

by confidence:
  high                     714
  medium                   254
  low                      1420

excluded because the data said no:
  followup_after_a_move_not_its_parent 78
  frame_margin_negative    2299
  self_pair_without_chain  35

Nothing was excluded for missing data. A gap in the source is recorded as
an unknown and the pair stays a candidate; only a KNOWN negative margin
excludes, and the margin is kept with it.

followup_after_a_move_not_its_parent is not a gap either. The frame source spells
a follow-up only as a chain from the move it comes out of ("5MP~MP"), so
these 78 pairs put a follow-up after a move the source says it does not
follow. A follow-up whose parent the source never names stays a candidate.

- follow-up edges         402  (parent named by the frame data: 2)

## Drive Rush Cancel candidates

A -> Drive Rush Cancel -> B. NONE OF THESE CAN BE PRESSED YET: how Drive
Rush is input on this build and which action id a Drive Rush Cancel is
have never been measured. They are not in the route search below, and with
--worklist they go to their own file, which the sweep does not read.

- DRC record              "MPMK or 66": startup 9, recovery 15, drive cost 30000
- starters that can rush  16  (drc_on_hit in the frame data)
- starters nobody knows   18  (no record, or a guessed one: kept, low)
- starters that cannot    6  (record present, no Drive Rush Cancel in it)
    615:manual 强
    616:manual 强
    637:manual 3 + 强
    638:manual 3 + 强
    670:manual 6 + 中
    672:manual 6 + 中
- pairs considered        4080
- DRC edges               2026
- excluded                2054

by confidence:
  high                     250
  medium                   220
  low                      1556

excluded:
  drc_margin_negative      1646
  followup_after_drive_rush 408

drc_margin_negative is drc_on_hit minus B's startup, known and below zero,
kept with the number. followup_after_drive_rush is structure: a derivation
comes out of its parent with nothing in between, and a rush is in between.
A starter the source lists without a Drive Rush Cancel is counted once above
rather than once per target.

## Route candidates

- routes                  775
- graph nodes             119
- graph edges             2388
- folded canonical variants 5613  (same buttons, unresolved action id)
- search complete         false
  beam dropped 15401 partial routes, 0 routes not emitted
  length 2               350
  length 3               425

dropped by a search bound (not by the game):
  max_repeat_per_action    5

## Top 10 by predicted damage

Predicted damage is an UNSCALED frame-table sum. Combo scaling appears in no
frame table and neither does Modern's own damage reduction, so this is an
upper bound for ordering, never a damage figure.

#   route                                            dmg~   cost conf    unknowns
1   2 + 强 > 214214 + 强                           4900    8.9 low     7
2   2 + 强 > 2 + SP + 强                           4900    6.5 low     7
3   3 + 强 > 214214 + 强                           4900    8.9 low     8
4   3 + 强 > 2 + SP + 强                           4900    6.5 low     8
5   中 > 214214 + 强                               4600    8.4 low     7
6   中 > 2 + SP + 强                               4600    6.0 low     7
7   2 + 中 > 214214 + 强                           4500    8.9 low     7
8   2 + 中 > 2 + SP + 强                           4500    6.5 low     7
9   6 + 强 > 214214 + 强                           4500    8.9 low     7
10  6 + 强 > 2 + SP + 强                           4500    6.5 low     7

## Top 10 by predicted scaled damage (model)

A MODEL, NOT A DAMAGE FIGURE. Each move's frame-table damage times a
per-move factor from public descriptions of SF6 scaling (sf6-public-scaling-v1,
verified = false): 100/100/80/70.. per move, a light-normal starter
100/80/70.., floor 10%, x0.85 after a Drive Rush, x0.8 on SP moves, and
the Super Art minimum. Not modelled: 9 things, listed in
scaling_model.not_modelled on every route. Used for ordering only.

#   route                                         scaled~     dmg~   cost conf   
1   2 + 强 > 214214 + 强                           4900     4900    8.9 low    
2   3 + 强 > 214214 + 强                           4900     4900    8.9 low    
3   中 > 214214 + 强                               4600     4600    8.4 low    
4   2 + 中 > 214214 + 强                           4500     4500    8.9 low    
5   6 + 强 > 214214 + 强                           4500     4500    8.9 low    
6   4 + 强 > 214214 + 强                           4400     4400    8.9 low    
7   2 + 强 > 2 + SP + 强                           4100     4900    6.5 low    
8   3 + 强 > 2 + SP + 强                           4100     4900    6.5 low    
9   中 > 2 + SP + 强                               3800     4600    6.0 low    
10  2 + 中 > 2 + SP + 强                           3700     4500    6.5 low    

## Top 10 by fewest inputs

#   route                                            dmg~   cost conf   
1   弱 > 弱                                         600    2.5 medium 
2   弱 > > 空中 任意键                          300    2.5 low    
3   弱 > 空中 任意键                            300    2.5 low    
4   中 > > 空中 任意键                          600    2.5 low    
5   中 > 空中 任意键                            600    2.5 low    
6   强 > > 空中 任意键                          900    2.5 low    
7   强 > 空中 任意键                            900    2.5 low    
8   弱 > 中                                         900    3.0 medium 
9   弱 > 强                                        1200    3.0 medium 
10  中 > 弱                                         900    3.0 high   

## Pareto frontier: 7 routes nothing beats on both damage and inputs

1   2 + 强 > 2 + SP + 强                           4900    6.5
2   中 > 2 + SP + 强                               4600    6.0
3   3 + 强 > 3 + 强 > 强                          2700    5.5
4   弱 > 3 + 强 > 强                              2100    5.0
5   3 + 强 > 强                                    1800    3.5
6   弱 > 强                                        1200    3.0
7   强 > > 空中 任意键                          900    2.5

## Why the game still has to answer

- **actual_input_timing**
  the actual input window is what the sweep exists to measure
- **cancel_window_conditions**
  cancel windows into specials and supers have conditions no frame table lists
- **frame_data_variant_ambiguous**
  for the second move, the join took "5LK", whose frame record describes a normal, but this row's action id puts it among the specials. The two sources disagree about what move this is, so the numbers may belong to a different one
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

  668  classic_modern but no Modern command form
  668  simple_command names neither SP nor AUTO
  933  classic_modern but no Modern command form
  933  simple_command names neither SP nor AUTO

## Written

- candidates/juri/modern/candidate-edges.json  (3584537 bytes)
- candidates/juri/modern/candidate-routes.json  (5348299 bytes)
- reframework/data/ComboExplorer_data/worklist/juri-modern-drc.json  (919770 bytes)
- reframework/data/ComboExplorer_data/worklist/juri-modern.json  (974596 bytes)

Both documents carry runtime_verified = false and every record in them is
status = theoretical. The next step is the gaming machine: calibration,
then a sweep, then these become confirmed edges or rejected ones.
