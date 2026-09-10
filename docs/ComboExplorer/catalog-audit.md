# Catalog audit - 31 character(s)

Catalog.build over the shipped command_display files. No frame data, no
game: this measures the classifier, not the moves.

## Per character

```
char        entr  rows stand  excl unrch  unplc   LOST  perr  prob
AKI           72    77    48    29     8      3      1     4     2
Akuma        108   116    64    52     8      5      1     6    16
Alex          87    96    54    42     6     11      8     5     2
Blanka       138   112    49    63    58     11      8     4     0
CViper       101   117    53    64    17      1      1     4    10
Cammy         92    93    53    40    22      2      1     4     2
ChunLi        96   109    56    53     6      6      2     4     2
DeeJay       121   125    84    41     7     12      1     4    10
Dhalsim      102   108    62    46    17      5      1     4     2
EHonda        95   122    65    57     7     23      3     4     2
Ed            80    82    48    34     6      9      2     4    16
Elena        108   126    91    35     7      5      1     4     4
Guile        117   144   109    35     6      7      2     4     4
Ingrid       130   158    61    97    14      4      1     4    12
JP            83    93    60    33     6     11      7     4     0
Jamie        132   171    89    82     7     15      1     4     2
Juri         121   182   136    46     5      8      1     4     4
Ken           87   110    46    64     7     31      5     4     4
Kimberly     103   123    59    64    11     10      3     4    10
Lily          92   126    73    53     8      4      1     4     0
Luke          80    93    45    48     7     18      4     4     4
MBison        81    94    57    37     8     12      1     4     0
Mai           99   137    83    54     6      1      1     4     4
Manon        105   139   104    35    11      7      1     4     4
Marisa        84    89    47    42    12     17      1     4     4
Rashid       115   135    63    72     4     12      2     4    10
Ryu           87   102    59    43     6      4      1     4     4
Sagat         82   100    55    45     4     17      1     5     2
Terry         81    87    51    36     8     12      1     4     0
Yasmine      120   138    65    73     8     39      4     4    38
Zangief       80    88    37    51     9     12      8     5     0
```

- `unrch` no Modern command form at all, so the row never exists
- `unplc` rows the classifier could not place a category on
- `LOST`  of those, the ones excluded as `unclassified` - dropped for no reason
          other than that the classifier had no vocabulary for the notation
- `perr`  rows whose notation InputMask could not parse
- `prob`  entries Catalog.build reported as problems

## Excluded, by reason

```
char           ac_state          air   any_button assist_combo     followup     no_input       system        throw unclassified
AKI                   0            7            7            1            0            0           11            2            1
Akuma                 0           20            9            2            4            0           13            3            1
Alex                  1            7            5            2            2            1           11            5            8
Blanka                0           26           15            1            0            0           11            2            8
CViper                0           38           11            1            0            0           11            2            1
Cammy                 0           17            6            2            1            0           11            2            1
ChunLi                0           17           17            1            3            0           11            2            2
DeeJay                0            9            5            2           11            0           11            2            1
Dhalsim               2           21            2            2            4            0           11            3            1
EHonda                0           10            9            2           20            0           11            2            3
Ed                    0            6            8            0            5            0           11            2            2
Elena                 0           10            5            2            4            0           11            2            1
Guile                 0            7            7            2            3            0           11            3            2
Ingrid                3           47           20            5            3            0           15            3            1
JP                    0            6            1            1            5            0           11            2            7
Jamie                 0           15           34            1           16            0           13            2            1
Juri                  0           16            5            1           10            0           11            2            1
Ken                   0            7            7            2           30            0           11            2            5
Kimberly              0           18           14            1            9            0           17            2            3
Lily                  0           25            9            2            3            0           11            2            1
Luke                  0            7            7            1           16            0           11            2            4
MBison                0           10            9            1            3            0           11            2            1
Mai                   0           24           14            2            0            0           11            2            1
Manon                 0            6            7            2            6            0           11            2            1
Marisa                0            7            3            2           16            0           11            2            1
Rashid                2           39            4            2           10            0           11            2            2
Ryu                   0           12           12            2            3            0           11            2            1
Sagat                 3            6            3            2           16            0           12            2            1
Terry                 0            6            7            2            7            0           11            2            1
Yasmine               0           12            5            4           35            0           11            2            4
Zangief               2           12            5            2            4            0           12            6            8
```

## Notations the classifier could not place

Sorted by how many characters each one costs. A row here was excluded
as `unclassified`: the category came back unknown, and nothing in the
data says the move is unusable - only that this classifier has no word
for how it is written.

```
chars rows  notation                 characters
31    32    LP+MP+HP+LK+MK+HK        AKI,Akuma,Alex,Blanka,CViper,Cammy,ChunLi,DeeJay,Dhalsim,EHonda,Ed,...
4     4     KK                       ChunLi,Ed,Ken,Rashid
3     8     PP                       Guile,Luke,Zangief
2     4     >22+LP+HP                JP,Yasmine
2     4     >22+MP+HP                JP,Yasmine
2     3     >22+MP                   Blanka,Kimberly
2     2     >22+HP                   Blanka,Yasmine
1     5     P                        Blanka
1     3     >6+K                     Ken
1     3     PPP                      Zangief
1     2     >2+HK                    EHonda
1     2     >HK                      Alex
1     2     >LP                      Alex
1     1     >4                       Alex
1     1     >6                       Alex
```

## Problems, by reason

1. classic_modern but no Modern command form
2. simple_command names neither SP nor AUTO

```
char          #1    #2
AKI            1     1
Akuma          8     8
Alex           1     1
Blanka         0     0
CViper         5     5
Cammy          1     1
ChunLi         1     1
DeeJay         5     5
Dhalsim        1     1
EHonda         1     1
Ed             7     9
Elena          2     2
Guile          2     2
Ingrid         6     6
JP             0     0
Jamie          1     1
Juri           2     2
Ken            2     2
Kimberly       3     7
Lily           0     0
Luke           2     2
MBison         0     0
Mai            2     2
Manon          2     2
Marisa         2     2
Rashid         5     5
Ryu            2     2
Sagat          1     1
Terry          0     0
Yasmine       19    19
Zangief        0     0
```

## Verdict

76 row(s) across 31 of 31 character(s) are excluded as `unclassified`:
dropped for no reason other than that the classifier could not place them.

Zangief, the character the pipeline was built against, loses 8.
The worst case is Alex at 8.

The gap is roughly even across characters, so what is missing is not
specific to how one character's notation is written.

Nothing here says a listed notation IS a special, a normal or anything
else. It says the classifier has no opinion on it and the exclusion chain
defaults to dropping it.
