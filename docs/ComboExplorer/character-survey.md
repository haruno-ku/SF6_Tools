# Offline pipeline survey - 31 character(s)

Catalog -> frame-data join -> candidates -> routes, over every shipped
character. No game, no network. Nothing here has been run on Street Fighter 6:
every edge and every route is a candidate.

## Per character

```
char        rows  start   targ  fups  cvS%  cvT%  cvF%  amb  edges  high   med   low  routes
Ryu          102     14     52     3   100   100     0   23    590   170   118   302     196
Luke          93     11     37    16   100   100     0    4    398   136    54   208     253
Kimberly     123     14     47    11   100    89     0    4    608   216   128   264     169
ChunLi       109     19     49     3    95    98     0    4    706   338   188   180     195
Manon        139     13     80     6   100   100     0    8    721   417   154   150      87
Zangief       88     14     33     4   100    91     0    5    387    88   133   166     188
JP            93     14     53    11   100    55     0    4    768   121   117   530     218
Dhalsim      108     18     54     4    78    69     0   12    778    77    79   622     242
Cammy         93     14     44     1   100    86     0    4    490   145   207   138     219
Ken          110     11     39    36   100    95     0    4    710   158    98   454     202
DeeJay       125     44     77    11   100   100     0    8   2027   487   788   752      78
Lily         126     13     60     3   100    93     0    8    667   352   128   187     164
AKI           77     15     41     0   100    90     -    4    340   112    96   132     143
Rashid       135     14     54    10   100    93     0    4    655   228   146   281     144
Blanka       112     17     44     2   100    95     0   16    571    55    92   424     265
Juri         182     40    108    12   100   100     0    6   2466  1242   564   660      60
Marisa        89     12     40    16   100   100     0    6    484   132   107   245     248
Guile        144     41     94     3    71    83     0    8   3082   790   409  1883      73
Ed            82     13     41     5   100    88     0    4    416   119    92   205     232
EHonda       122     13     54    22   100   100     0    4    702   267   109   326     150
Jamie        171     16     76    16   100    72    12   30   1044   137    89   818     200
Akuma        116     18     56     4    89    95     0    8    894   261   181   452     229
Sagat        100     15     47    16   100    98     0    8    652   164   161   327     177
MBison        94     15     49    11    87    88     0   18    753   113   111   529     180
Terry         87     12     44     7   100   100     0    8    487   216   107   164     179
Mai          137     14     70     0   100   100     -   56    519     0    67   452     102
Elena        126     23     74     4    74    78     0    8   1176   180   124   872     161
CViper       117     12     43     0   100    72     -    4    343    75   100   168     177
Alex          96     22     48     8   100    98     0    4    766   235   277   254     139
Ingrid       158     18     55     3    94    91     0    8    836   108   225   503     256
Yasmine      138     14     56    38    93    88     0    8   1215    32    61  1122     162
```

- `cvS/cvT/cvF` how many starting moves / target moves / derivations found
  frame data. A miss is an unknown, never an exclusion - the move stays a
  candidate with its gaps named
- `amb`  joins that matched only by guessing between several source
  spellings. Counted apart from a clean match because they are not one

## Was anything dropped for missing data?

**0** rows, across all 31 characters.

Which is the answer it has to be. A gap in the frame source is recorded as
an unknown and the pair stays a candidate; only a KNOWN negative margin
excludes, and it excludes with the number attached.

## Where the join is worst

Sorted by how many target moves arrived with no numbers. These characters
produce candidates that are all low confidence for a reason that is about
the join, not about the character.

```
char       unmatched       of   examples
JP               24       53   214+LP  214+MP  214+HP  214+LP+MP
Jamie            21       76   6+P  6+P  6+P  6+P
Dhalsim          17       54   6+PPP  4+PPP  2+KK  3+KK
Elena            16       74   6+LK  6+HK  6+LK  6+HK
Guile            16       94   4+MK  6+MK  6+LP  56+LP
CViper           12       43   6+PP  6+PP  6+PP  6+PP
Yasmine           7       56   4+KK  22+LP  22+MP  22+LP+MP
Cammy             6       44   236+LP  236+MP  236+HP  236+LP+MP
MBison            6       49   6+PPP  4+PPP  [2]8+LK  [2]8+MK
Ed                5       41   6+MP  214214+LP  214214+LP  214214+MP
```

## Scope

From: normal,command_normal / manual
To:   normal,command_normal,special,od_special,super / manual,simple
Routes: max 2 steps, beam 400, cap 2000 - present to prove the pipeline runs

A character whose interesting moves fall outside this scope looks thin here,
and that is a fact about the scope rather than about the character.
