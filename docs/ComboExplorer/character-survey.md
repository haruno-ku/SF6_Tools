# Offline pipeline survey - 31 character(s)

Catalog -> frame-data join -> candidates -> routes, over every shipped
character. No game, no network. Nothing here has been run on Street Fighter 6:
every edge and every route is a candidate.

## Per character

```
char        rows  start   targ  fups  cvS%  cvT%  cvF%  amb  edges  high   med   low  routes
Ryu          102     14     52     3   100   100   100   23    590   170   121   299     198
Luke          93     11     37    16   100   100    69    4    398   136    72   190     253
Kimberly     123     14     47    11   100    96    45    4    596   243   136   217     169
ChunLi       109     19     49     3   100   100     0    4    676   364   195   117     209
Manon        139     13     80     6   100   100   100    8    721   417   166   138      87
Zangief       88     14     33     4   100   100   100    8    378    88   135   155     179
JP            93     14     53    11   100   100    27    4    684   343   150   191     190
Dhalsim      108     18     54     4   100    98     0   12    664   161   109   394     234
Cammy         93     14     44     1   100   100   100    4    466   187   226    53     233
Ken          110     11     39    36   100   100    56    6    704   158   100   446     200
DeeJay       125     44     77    11   100   100    73   70   2027   142   183  1702     177
Lily         126     13     60     3   100   100    67    8    659   392   134   133     148
AKI           77     15     41     0   100   100     -    6    330   128    98   104     135
Rashid       135     14     54    10   100   100    60    6    635   256   144   235     137
Blanka       112     17     44     2   100    98     0   16    565    60    92   413     265
Juri         182     40    108    12   100   100     8   60   2466   714   254  1498      84
Marisa        89     12     40    16   100   100    94    6    484   132   116   236     248
Guile        144     41     94     3    76    86    33   40   2878   302   149  2427     139
Ed            82     13     41     5   100    98   100    4    396   143   101   152     239
EHonda       122     13     54    22   100   100    91    4    702   267   111   324     152
Jamie        171     16     76    16   100   100    50   43   1038   137    91   810     200
Akuma        116     18     56     4    89    96    75    8    891   270   186   435     233
Sagat        100     15     47    16   100   100    94    8    646   171   169   306     179
MBison        94     15     49    11   100   100     0   18    739   149   115   475     175
Terry         87     12     44     7   100   100    86    8    487   216   113   158     183
Mai          137     14     70     0   100   100     -   56    519     0    67   452     102
Elena        126     23     74     4    74   100   100   18   1176   180   105   891     167
CViper       117     12     43     0   100   100     -    4    295   115   108    72     137
Alex          96     22     48     8   100   100    12   19    757   147   188   422     159
Ingrid       158     18     55     3    94    98    67   16    769    78   197   494     276
Yasmine      138     14     56    38    93   100    89    8   1215    32    61  1122     162
```

- `cvS/cvT/cvF` how many starting moves / target moves / derivations found
  frame data. A miss is an unknown, never an exclusion - the move stays a
  candidate with its gaps named
- `amb`  joins that matched only by guessing between several source
  spellings. Counted apart from a clean match because they are not one

## Was anything dropped for missing data?

**0** of 12543 exclusions, across all 31 characters.

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
Guile            13       94   6+LP  56+LP  56+MP  56+HP
Akuma             2       56   5565+HP  2+LP+MP+HP+LK+MK+HK  5565+HP  2+LP+MP+HP+LK+MK+HK
Kimberly          2       47   6  6
Blanka            1       44   214+LP+LK+MK
Dhalsim           1       54   236+MK
Ed                1       41   6+MP
Ingrid            1       55   5545+HK  5545+HK
AKI               0       41   
Alex              0       48   
CViper            0       43   
```

## Scope

From: normal,command_normal / manual
To:   normal,command_normal,special,od_special,super / manual,simple
Routes: max 2 steps, beam 400, cap 2000 - present to prove the pipeline runs

A character whose interesting moves fall outside this scope looks thin here,
and that is a fact about the scope rather than about the character.
