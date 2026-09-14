# Offline pipeline survey - 31 character(s)

Catalog -> frame-data join -> candidates -> routes, over every shipped
character. No game, no network. Nothing here has been run on Street Fighter 6:
every edge and every route is a candidate.

## Per character

```
char        rows  start   targ  fups  cvS%  cvT%  cvF%  amb  edges  high   med   low  routes
Ryu          102     14     52     3   100   100   100   23    551   170   121   260     198
Luke          93     11     37    16   100   100    69    4    295   136    72    87     220
Kimberly     123     14     47    11   100    96    45    4    503   243   136   124     169
ChunLi       109     19     49     3   100   100     0    4    619   364   195    60     209
Manon        139     13     80     6   100   100   100    8    655   417   166    72      87
Zangief       88     14     33     4   100   100   100    8    324    88   135   101     170
JP            93     14     53    11   100   100    27    4    631   343   150   138     190
Dhalsim      108     18     54     4   100    98     0   12    664   161   109   394     234
Cammy         93     14     44     1   100   100   100    4    453   187   226    40     233
Ken          110     11     39    36   100   100    56    6    365   158   100   107     177
DeeJay       125     44     77    11   100   100    73   70   1572   142   183  1247     177
Lily         126     13     60     3   100   100    67    8    635   392   134   109     148
AKI           77     15     41     0   100   100     -    6    330   128    98   104     135
Rashid       135     14     54    10   100   100    60    6    495   256   144    95     137
Blanka       112     17     44     2   100    98     0   16    565    60    92   413     265
Juri         182     40    108    12   100   100     8   60   2388   714   254  1420      84
Marisa        89     12     40    16   100   100    94    6    313   132   116    65     200
Guile        144     41     94     3    76    86    33   40   2797   302   149  2346     139
Ed            82     13     41     5   100    98   100    4    336   143   101    92     216
EHonda       122     13     54    22   100   100    91    4    444   267   111    66     152
Jamie        171     16     76    16   100   100    50   43    824   137    91   596     202
Akuma        116     18     56     4    89    96    75    8    822   270   186   366     233
Sagat        100     15     47    16   100   100    94    8    412   171   169    72     179
MBison        94     15     49    11   100   100     0   18    694   149   115   430     175
Terry         87     12     44     7   100   100    86    8    409   216   113    80     183
Mai          137     14     70     0   100   100     -   56    519     0    67   452     102
Elena        126     23     74     4    74   100   100   18   1093   180   105   808     167
CViper       117     12     43     0   100   100     -    4    295   115   108    72     137
Alex          96     22     48     8   100   100    12   19    583   147   188   248     159
Ingrid       158     18     55     3    94    98    67   16    719    78   197   444     276
Yasmine      138     14     56    38    93   100    89    8    733    32    61   640     219
```

- `cvS/cvT/cvF` how many starting moves / target moves / derivations found
  frame data. A miss is an unknown, never an exclusion - the move stays a
  candidate with its gaps named
- `amb`  joins that matched only by guessing between several source
  spellings. Counted apart from a clean match because they are not one

## Was any PAIR dropped for missing data?

**0** of 16056 pair exclusions, across all 31 characters.

Measured by asking each excluded pair whether it carries the thing that
decided it - the margin, the source's own statement that the move does
not chain, or the chains that name a follow-up's parent. An exclusion with
none of them was decided by something nobody wrote down, and missing
information is the only candidate for that.

Which is the answer it has to be. A gap in the frame source is recorded as
an unknown and the pair stays a candidate; only something the source
states - a negative margin, a move that does not chain, a follow-up's
parent - excludes, and it excludes with that statement attached.

### What the number above does not cover

Pairs, and only pairs. A row that never became half of one is not in the
16056, and two of the reasons a row is dropped are about this project's
vocabulary rather than about the move:

```
unclassified     52 rows   the classifier has no word for the notation
any_button      264 rows   the notation names no strength
```

Neither is a statement that the move does not work, and both are listed
per character in catalog-audit.md. They are named here because the
heading above reads wider than the thing it measures, and a reader with
only that number would conclude nothing was lost anywhere.

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
