# Offline candidate report - Mai / modern / midscreen / none

EVERYTHING BELOW IS A THEORETICAL CANDIDATE. Nothing here has been run on
Street Fighter 6. These are pairs and sequences worth spending a trial on,
not combos that are known to work.

## Provenance

- command_display: Mai, generated 2026-08-03T00:00:00.000Z
  - ac_sha256  3157a731c060c85a10397a96d99f82d39ef7d3f973e72fac3223e968dc2a3027
  - bcm_sha256 da4486c0529af3bcf86bbb86e04aba590b34d00f2436d9f9a727c707803cf514
- frame data: RyoSogawa/sf6-sensei @ a64f2acf90fffc855ddc1a958a4ee752e15c571c (CC-BY-SA)
  - original work: SuperCombo Wiki, CC-BY-SA-4.0. See docs/NOTICE.md.
- game patch: command_display@2026-08-03T00:00:00.000Z
  (the command_display generation date, not a confirmed game version - the real patch is only knowable on the machine running the game)

## Moves searched

- catalog rows            137
- starting moves          14  (normal,command_normal / manual)
- target moves            70  (normal,command_normal,special,od_special,super / manual,simple)
- excluded from probing   54  (classic-only, air, throws, system, follow-ups)
- frame data coverage     70 of 70 (100%)  over every row this run uses
    starters      14 of  14 (100%)
    targets       70 of  70 (100%)
    56 matched only by guessing between several source spellings:
      236+LP (900) -> 236LP
      236+MP (902) -> 236MP
      236+MP (902) -> 236MP
      236+HP (904) -> 236HP
      236+HP (904) -> 236HP
      236+PP (906) -> 236PP
      236+LP (950) -> 236LP
      236+MP (952) -> 236MP
      236+MP (952) -> 236MP
      236+HP (954) -> 236HP
      236+HP (954) -> 236HP
      236+PP (956) -> 236PP
      236+LK (1012) -> 236LK
      236+MK (1013) -> 236MK
      236+HK (1014) -> 236HK
      236+KK (1015) -> 236KK
      236+LK (1018) -> 236LK
      236+MK (1019) -> 236MK
      236+HK (1020) -> 236HK
      236+KK (1021) -> 236KK
      214+LP (1024) -> 214LP
      214+LP (1024) -> 214LP
      214+MP (1026) -> 214MP
      214+HP (1027) -> 214HP
      214+PP (1028) -> 214PP
      214+LP (1031) -> 214LP
      214+LP (1031) -> 214LP
      214+MP (1032) -> 214MP
      214+HP (1033) -> 214HP
      214+PP (1034) -> 214PP
      623+LK (1047) -> 623LK
      623+LK (1047) -> 623LK
      623+MK (1048) -> 623MK
      623+HK (1049) -> 623HK
      623+KK (1050) -> 623KK
      623+LK (1057) -> 623LK
      623+LK (1057) -> 623LK
      623+MK (1058) -> 623MK
      623+HK (1059) -> 623HK
      623+KK (1060) -> 623KK
      236236+P (1200) -> 236236P
      236236+P (1200) -> 236236P
      236236+P (1204) -> 236236P
      236236+P (1204) -> 236236P
      236236+K (1219) -> 236236K
      236236+K (1219) -> 236236K
      236236+K (1225) -> 236236K
      236236+K (1225) -> 236236K
      214214+P (1233) -> 214214P
      214214+P (1233) -> 214214P
      214214+P (1234) -> 214214P
      214214+P (1234) -> 214214P
      214214+P (1237) -> 214214P
      214214+P (1237) -> 214214P
      214214+P (1238) -> 214214P
      214214+P (1238) -> 214214P
- unresolved canonical ids 46 groups covering 113 rows
- no Modern form at all     6
    34  8
    600  LP
    603  MP
    852  6
    907  6
    957  6

## Theoretical edges

- pairs considered        980
- candidate edges         519
- excluded                461

by reason:
  chain_cancel             42
  frame_link               103
  special_cancel           280
  super_cancel             112

by confidence:
  high                     0
  medium                   67
  low                      452

excluded because the data said no:
  frame_margin_negative    450
  self_pair_without_chain  11

Nothing was excluded for missing data. A gap in the source is recorded as
an unknown and the pair stays a candidate; only a KNOWN negative margin
excludes, and the margin is kept with it.

## Drive Rush Cancel candidates

A -> Drive Rush Cancel -> B. NONE OF THESE CAN BE PRESSED YET: how Drive
Rush is input on this build and which action id a Drive Rush Cancel is
have never been measured. They are not in the route search below, and with
--worklist they go to their own file, which the sweep does not read.

- DRC record              "MPMK or 66": startup 9, recovery 15, drive cost 30000
- starters that can rush  7  (drc_on_hit in the frame data)
- starters nobody knows   0  (no record, or a guessed one: kept, low)
- starters that cannot    7  (record present, no Drive Rush Cancel in it)
    610:manual 中
    611:manual 强
    618:manual 2 + 强
    624:manual 3 + 强
    643:manual 4 + 强
    644:manual 强
    651:manual 6 + 中
- pairs considered        490
- DRC edges               44
- excluded                446

by confidence:
  high                     6
  medium                   20
  low                      18

excluded:
  drc_margin_negative      446

drc_margin_negative is drc_on_hit minus B's startup, known and below zero,
kept with the number. followup_after_drive_rush is structure: a derivation
comes out of its parent with nothing in between, and a rush is in between.
A starter the source lists without a Drive Rush Cancel is counted once above
rather than once per target.

## Route candidates

- routes                  454
- graph nodes             70
- graph edges             519
- folded canonical variants 2825  (same buttons, unresolved action id)
- search complete         true
  length 2               123
  length 3               331

dropped by a search bound (not by the game):
  max_repeat_per_action    3

## Top 10 by predicted damage

Predicted damage is an UNSCALED frame-table sum. Combo scaling appears in no
frame table and neither does Modern's own damage reduction, so this is an
upper bound for ordering, never a damage figure.

#   route                                            dmg~   cost conf    unknowns
1   3 + 强 > 2 + 中 > 214214 + 强                 5400   10.9 low     8
2   3 + 强 > 2 + 中 > 2 + SP + 强                 5400    8.5 low     8
3   2 + 弱 > 3 + 强 > 214214 + 强                 5200   10.9 low     8
4   2 + 弱 > 3 + 强 > 2 + SP + 强                 5200    8.5 low     8
5   3 + 强 > 弱 > 214214 + 强                     5200   10.4 low     8
6   3 + 强 > 弱 > 2 + SP + 强                     5200    8.0 low     8
7   3 + 强 > 2 + 弱 > 214214 + 强                 5200   10.9 low     8
8   3 + 强 > 2 + 弱 > 2 + SP + 强                 5200    8.5 low     8
9   中 > 弱 > 214214 + 强                         5000    9.9 low     7
10  中 > 弱 > 2 + SP + 强                         5000    7.5 low     7

## Top 10 by predicted scaled damage (model)

A MODEL, NOT A DAMAGE FIGURE. Each move's frame-table damage times a
per-move factor from public descriptions of SF6 scaling (sf6-public-scaling-v1,
verified = false): 100/100/80/70.. per move, a light-normal starter
100/80/70.., floor 10%, x0.85 after a Drive Rush, x0.8 on SP moves, and
the Super Art minimum. Not modelled: 9 things, listed in
scaling_model.not_modelled on every route. Used for ordering only.

#   route                                         scaled~     dmg~   cost conf   
1   3 + 强 > 214214 + 强                           4900     4900    8.9 low    
2   3 + 强 > 2 + 中 > 214214 + 强                 4600     5400   10.9 low    
3   2 + 中 > 214214 + 强                           4500     4500    8.9 low    
4   3 + 强 > 弱 > 214214 + 强                     4400     5200   10.4 low    
5   3 + 强 > 2 + 弱 > 214214 + 强                 4400     5200   10.9 low    
6   中 > 弱 > 214214 + 强                         4200     5000    9.9 low    
7   中 > 2 + 弱 > 214214 + 强                     4200     5000   10.4 low    
8   3 + 强 > 2 + SP + 强                           4100     4900    6.5 low    
9   3 + 强 > 2 + 中 > 2 + SP + 强                 3960     5400    8.5 low    
10  2 + 强 > 弱 > 214214 + 强                     3900     4700   10.4 low    

## Top 10 by fewest inputs

#   route                                            dmg~   cost conf   
1   中 > 弱                                        1000    3.0 medium 
2   中 > 2 + 弱                                    1000    3.5 medium 
3   2 + 弱 > 弱                                     600    3.5 medium 
4   2 + 弱 > 中                                    1000    3.5 medium 
5   2 + 弱 > 强                                    1200    3.5 medium 
6   2 + 弱 > 2 + 弱                                 600    3.5 medium 
7   2 + 强 > 弱                                     700    3.5 medium 
8   3 + 强 > 弱                                    1200    3.5 medium 
9   3 + 强 > 中                                    1600    3.5 medium 
10  3 + 强 > 强                                    1800    3.5 medium 

## Pareto frontier: 9 routes nothing beats on both damage and inputs

1   3 + 强 > 2 + 中 > 2 + SP + 强                 5400    8.5
2   3 + 强 > 弱 > 2 + SP + 强                     5200    8.0
3   中 > 弱 > 2 + SP + 强                         5000    7.5
4   3 + 强 > 2 + SP + 强                           4900    6.5
5   弱 > 2 + SP + 强                               4300    6.0
6   2 + 弱 > 3 + 强 > 强                          2100    5.5
7   中 > 2 + 弱 > 强                              1900    5.0
8   3 + 强 > 强                                    1800    3.5
9   中 > 弱                                        1000    3.0

## Why the game still has to answer

- **actual_input_timing**
  the actual input window is what the sweep exists to measure
- **cancel_window_conditions**
  cancel windows into specials and supers have conditions no frame table lists
- **frame_data_variant_ambiguous**
  the frame source lists "236LP" 2 times - Kachousen / Kachousen (Flame) - and the join took whichever came first; which one the input produces depends on something the frame table does not model
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

  601  classic_modern but no Modern command form
  601  simple_command names neither SP nor AUTO
  602  classic_modern but no Modern command form
  602  simple_command names neither SP nor AUTO

## Written

- candidates/mai/modern/candidate-edges.json  (861176 bytes)
- candidates/mai/modern/candidate-routes.json  (3313182 bytes)
- reframework/data/ComboExplorer_data/worklist/mai-modern-drc.json  (21959 bytes)
- reframework/data/ComboExplorer_data/worklist/mai-modern.json  (212519 bytes)

Both documents carry runtime_verified = false and every record in them is
status = theoretical. The next step is the gaming machine: calibration,
then a sweep, then these become confirmed edges or rejected ones.
