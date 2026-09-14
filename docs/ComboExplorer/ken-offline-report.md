# Offline candidate report - Ken / modern / midscreen / none

EVERYTHING BELOW IS A THEORETICAL CANDIDATE. Nothing here has been run on
Street Fighter 6. These are pairs and sequences worth spending a trial on,
not combos that are known to work.

## Provenance

- command_display: Ken, generated 2026-08-03T00:00:00.000Z
  - ac_sha256  3f8582aecd0f559a3c04f82e837832ccc6ce80a52ceec1edaf6c78fabd41dd57
  - bcm_sha256 5c7217d86f64547ef2771a434a51980e454b9020aa4f54ebbdec9f183ad059a9
- frame data: RyoSogawa/sf6-sensei @ a64f2acf90fffc855ddc1a958a4ee752e15c571c (CC-BY-SA)
  - original work: SuperCombo Wiki, CC-BY-SA-4.0. See docs/NOTICE.md.
- game patch: command_display@2026-08-03T00:00:00.000Z
  (the command_display generation date, not a confirmed game version - the real patch is only knowable on the machine running the game)

## Moves searched

- catalog rows            110
- starting moves          11  (normal,command_normal / manual)
- target moves            39  (normal,command_normal,special,od_special,super / manual,simple)
- excluded from probing   64  (classic-only, air, throws, system, follow-ups)
- frame data coverage     39 of 75 (52%)  over every row this run uses
    starters      11 of  11 (100%)
    targets       39 of  39 (100%)
    follow-ups     0 of  36 (  0%)
    6 matched only by guessing between several source spellings:
      623+K (983) -> 623LK
      214+K (1003) -> 214LK
      236236+P (1215) -> 236236P
      236236+P (1215) -> 236236P
      236236+P (1220) -> 236236P
      236236+P (1220) -> 236236P
    36 with no frame data at all:
      >MK (670)
      >HK (671)
      >LK (681)
      >MK (682)
      >HK (683)
      >6+LK (924)
      >6+LK (924)
      >6+LK (924)
      >6+MK (925)
      >6+MK (925)
      >6+MK (925)
      >6+HK (926)
      >6+HK (926)
      >6+HK (926)
      >6+LK (930)
      >6+LK (930)
      >6+LK (930)
      >6+MK (931)
      >6+MK (931)
      >6+MK (931)
      ... and 16 more
- unresolved canonical ids 22 groups covering 52 rows
- no Modern form at all     7
    34  8
    618  2+LP
    623  2+MP
    852  6
    900  236+LP
    980  623+LK
    981  623+MK

## Theoretical edges

- pairs considered        825
- candidate edges         365
- excluded                460

by reason:
  chain_cancel             66
  frame_data_incomplete    55
  frame_link               77
  special_cancel           175
  super_cancel             64
  target_combo             7

by confidence:
  high                     158
  medium                   100
  low                      107

excluded because the data said no:
  followup_after_a_move_not_its_parent 339
  frame_margin_negative    116
  self_pair_without_chain  5

Nothing was excluded for missing data. A gap in the source is recorded as
an unknown and the pair stays a candidate; only a KNOWN negative margin
excludes, and the margin is kept with it.

followup_after_a_move_not_its_parent is not a gap either. The frame source spells
a follow-up only as a chain from the move it comes out of ("5MP~MP"), so
these 339 pairs put a follow-up after a move the source says it does not
follow. A follow-up whose parent the source never names stays a candidate.

- follow-up edges         57  (parent named by the frame data: 2)

## Drive Rush Cancel candidates

A -> Drive Rush Cancel -> B. NONE OF THESE CAN BE PRESSED YET: how Drive
Rush is input on this build and which action id a Drive Rush Cancel is
have never been measured. They are not in the route search below, and with
--worklist they go to their own file, which the sweep does not read.

- DRC record              "MPMK or 66": startup 9, recovery 15, drive cost 30000
- starters that can rush  7  (drc_on_hit in the frame data)
- starters nobody knows   0  (no record, or a guessed one: kept, low)
- starters that cannot    4  (record present, no Drive Rush Cancel in it)
    612:manual 中
    615:manual 强
    629:manual 2 + 弱
    637:manual 3 + 强
- pairs considered        525
- DRC edges               97
- excluded                428

by confidence:
  high                     8
  medium                   73
  low                      16

excluded:
  drc_margin_negative      176
  followup_after_drive_rush 252

drc_margin_negative is drc_on_hit minus B's startup, known and below zero,
kept with the number. followup_after_drive_rush is structure: a derivation
comes out of its parent with nothing in between, and a rush is in between.
A starter the source lists without a Drive Rush Cancel is counted once above
rather than once per target.

## Route candidates

- routes                  674
- graph nodes             46
- graph edges             365
- folded canonical variants 2197  (same buttons, unresolved action id)
- search complete         true
  length 2               177
  length 3               497

dropped by a search bound (not by the game):
  max_repeat_per_action    6

## Top 10 by predicted damage

Predicted damage is an UNSCALED frame-table sum. Combo scaling appears in no
frame table and neither does Modern's own damage reduction, so this is an
upper bound for ordering, never a damage figure.

#   route                                            dmg~   cost conf    unknowns
1   3 + 强 > 2 + 强 > 236236 + 强                 5700   10.9 low     8
2   3 + 强 > 2 + 强 > 2 + SP + 强                 5700    8.5 low     8
3   3 + 强 > 中 > 236236 + 强                     5500   10.4 low     8
4   3 + 强 > 中 > 2 + SP + 强                     5500    8.0 low     8
5   3 + 强 > 2 + 中 > 236236 + 强                 5400   10.9 low     8
6   3 + 强 > 2 + 中 > 2 + SP + 强                 5400    8.5 low     8
7   弱 > 3 + 强 > 236236 + 强                     5200   10.4 low     8
8   弱 > 3 + 强 > 2 + SP + 强                     5200    8.0 low     8
9   2 + 弱 > 3 + 强 > 236236 + 强                 5200   10.9 low     8
10  2 + 弱 > 3 + 强 > 2 + SP + 强                 5200    8.5 low     8

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
4   3 + 强 > 中 > 236236 + 强                     4700     5500   10.4 low    
5   中 > 236236 + 强                               4600     4600    8.4 low    
6   3 + 强 > 2 + 中 > 236236 + 强                 4600     5400   10.9 low    
7   2 + 中 > 236236 + 强                           4500     4500    8.9 low    
8   3 + 强 > 弱 > 236236 + 强                     4400     5200   10.4 low    
9   3 + 强 > 2 + 弱 > 236236 + 强                 4400     5200   10.9 low    
10  3 + 强 > 2 + 强 > 2 + SP + 强                 4260     5700    8.5 low    

## Top 10 by fewest inputs

#   route                                            dmg~   cost conf   
1   弱 > 弱                                         600    2.5 medium 
2   弱 > 中                                         900    3.0 medium 
3   弱 > 强                                        1100    3.0 medium 
4   中 > > 中                                       600    3.0 medium 
5   弱 > 2 + 弱                                     600    3.5 medium 
6   弱 > 2 + 强                                    1100    3.5 medium 
7   弱 > 2 + 中                                     800    3.5 medium 
8   弱 > 3 + 强                                    1200    3.5 medium 
9   2 + 弱 > 弱                                     600    3.5 medium 
10  2 + 弱 > 中                                     900    3.5 medium 

## Pareto frontier: 9 routes nothing beats on both damage and inputs

1   3 + 强 > 2 + 强 > 2 + SP + 强                 5700    8.5
2   3 + 强 > 中 > 2 + SP + 强                     5500    8.0
3   3 + 强 > 2 + SP + 强                           4900    6.5
4   中 > 2 + SP + 强                               4600    6.0
5   中 > SP + 强                                   2600    5.5
6   弱 > 3 + 强 > 强                              2000    5.0
7   3 + 强 > 强                                    1700    3.5
8   弱 > 强                                        1100    3.0
9   弱 > 弱                                         600    2.5

## Why the game still has to answer

- **actual_input_timing**
  the actual input window is what the sweep exists to measure
- **cancel_window_conditions**
  cancel windows into specials and supers have conditions no frame table lists
- **frame_data_variant_ambiguous**
  the frame source lists "236236P" 2 times - Shinryu Reppa / Shinryu Reppa (CA) - and the join took whichever came first; which one the input produces depends on something the frame table does not model
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

  677  classic_modern but no Modern command form
  677  simple_command names neither SP nor AUTO
  929  classic_modern but no Modern command form
  929  simple_command names neither SP nor AUTO

## Written

- candidates/ken/modern/candidate-edges.json  (499558 bytes)
- candidates/ken/modern/candidate-routes.json  (4689587 bytes)
- reframework/data/ComboExplorer_data/worklist/ken-modern-drc.json  (46956 bytes)
- reframework/data/ComboExplorer_data/worklist/ken-modern.json  (149473 bytes)

Both documents carry runtime_verified = false and every record in them is
status = theoretical. The next step is the gaming machine: calibration,
then a sweep, then these become confirmed edges or rejected ones.
