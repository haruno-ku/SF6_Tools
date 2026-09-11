# Offline pipeline survey - 31 character(s)

Catalog -> frame-data join -> candidates -> routes, over every shipped
character. No game, no network. Nothing here has been run on Street Fighter 6:
every edge and every route is a candidate.

## Per character

```
char        rows  start   targ  fups  cvS%  cvT%  cvF%  amb  edges  high   med   low  routes
Ryu          102     14     52     3   100   100     0   23    590   170   118   302     196
Luke          93     11     37    16   100   100     0    4    398   136    54   208     253
Kimberly     123     14     47    11   100    96     0    4    596   243   131   222     166
ChunLi       109     19     49     3    95    98     0    4    706   338   188   180     195
Manon        139     13     80     6   100   100     0    8    721   417   154   150      87
Zangief       88     14     33     4   100   100     0    7    378    96   136   146     179
JP            93     14     53    11   100   100     0    4    684   343   147   194     190
Dhalsim      108     18     54     4    89    94     0   12    684   161    99   424     228
Cammy         93     14     44     1   100   100     0    4    466   187   225    54     233
Ken          110     11     39    36   100    95     0    4    710   158    98   454     202
DeeJay       125     44     77    11   100   100     0    8   2027   487   788   752      78
Lily         126     13     60     3   100   100     0    8    659   392   132   135     148
AKI           77     15     41     0   100    95     -    4    330   128    98   104     135
Rashid       135     14     54    10   100   100     0    4    635   256   150   229     137
Blanka       112     17     44     2   100    98     0   16    565    60    92   413     265
Juri         182     40    108    12   100   100     0    6   2466  1242   564   660      60
Marisa        89     12     40    16   100   100     0    6    484   132   107   245     248
Guile        144     41     94     3    76    85     0    8   2888   790   433  1665      73
Ed            82     13     41     5   100    98     0    4    396   143    96   157     239
EHonda       122     13     54    22   100   100     0    4    702   267   109   326     150
Jamie        171     16     76    16   100    72    12   30   1044   137    89   818     200
Akuma        116     18     56     4    89    96     0    8    891   270   183   438     233
Sagat        100     15     47    16   100   100     0    8    646   171   163   312     175
MBison        94     15     49    11    87    96     0   18    741   149   115   477     175
Terry         87     12     44     7   100   100     0    8    487   216   107   164     179
Mai          137     14     70     0   100   100     -   56    519     0    67   452     102
Elena        126     23     74     4    74    78     0    8   1176   180   124   872     161
CViper       117     12     43     0   100    86     -    4    307   105   106    96     147
Alex          96     22     48     8   100    98     0    4    766   235   277   254     139
Ingrid       158     18     55     3    94    98     0    8    769    90   260   419     269
Yasmine      138     14     56    38    93    98     0    8   1215    32    61  1122     162
```

- `cvS/cvT/cvF` how many starting moves / target moves / derivations found
  frame data. A miss is an unknown, never an exclusion - the move stays a
  candidate with its gaps named
- `amb`  joins that matched only by guessing between several source
  spellings. Counted apart from a clean match because they are not one

## Was anything dropped for missing data?

**0** of 12448 exclusions, across all 31 characters.

Measured by asking each excluded pair whether it carries the thing that
decided it - the margin, or the source's own statement that the move does
not chain. An exclusion with neither was decided by something nobody wrote
down, and missing information is the only candidate for that.

Which is the answer it has to be. A gap in the frame source is recorded as
an unknown and the pair stays a candidate; only a KNOWN negative margin
excludes, and it excludes with the number attached.

## Where the join is worst

Sorted by how many target moves arrived with no numbers. These characters
produce candidates that are all low confidence for a reason that is about
the join, not about the character.

```
char       unmatched       of   examples
Jamie            21       76   6+P  6+P  6+P  6+P
Elena            16       74   6+LK  6+HK  6+LK  6+HK
Guile            14       94   6+LP  56+LP  56+MP  56+HP
CViper            6       43   6+PP  6+PP  6+PP  6+PP
Dhalsim           3       54   6+PPP  4+PPP  236+MK  6+PPP
AKI               2       41   6+P  6+P
Akuma             2       56   5565+HP  2+LP+MP+HP+LK+MK+HK  5565+HP  2+LP+MP+HP+LK+MK+HK
Ken               2       39   623+K  214+K
Kimberly          2       47   6  6
MBison            2       49   6+PPP  4+PPP  6+PPP  4+PPP
```

## Scope

From: normal,command_normal / manual
To:   normal,command_normal,special,od_special,super / manual,simple
Routes: max 2 steps, beam 400, cap 2000 - present to prove the pipeline runs

A character whose interesting moves fall outside this scope looks thin here,
and that is a fact about the scope rather than about the character.
