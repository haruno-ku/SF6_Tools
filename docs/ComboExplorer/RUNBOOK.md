# ゲーミングPC ブリングアップ手順書

**この文書だけ読めば進められる**ように書いてある。GitHub の Issue は同じ内容を
チェックリストにしたもので、どちらか読みやすい方を使えばよい。

入口: **[#18 \[START HERE\]](https://github.com/haruno-ku/SF6_Tools/issues/18)**（ピン留め済み）

---

## 全体像 — なぜこの順番なのか

```
Step 1   無改造版が動く                     ← ここが通らないと以降すべて無意味
  ↓
Step 2-6 読み取り専用の計測（注入しない）    ← 未知の4項目に答える
  ↓
Step 7-10 キャリブレーション                 ← 「どのビットが何のボタンか」を実測で確定
  ↓
Step 11  注入 smoke test                     ← 初めてボタンを押す
  ↓
Step 12  A→B 総当たり                        ← 本番
```

**Step 2-6 を飛ばして Step 11 に行かないこと。** 現在のビルドは
**入力を一切注入しない**（`0.3.0-diagnostics`）。これは慎重さではなく設計で、
未検証のボタンビットで注入すると*存在しないボタンを押して技が出ず、
「この2技は繋がらない」という誤ったデータが静かに記録される*。エラーは出ない。

`core/Provenance.lua` が未計測の値を10項目登録していて、
**注入系はそれらが `verified` になるまで構造的に起動しない。**
Step 7-10 がその昇格作業にあたる。

---

## Step 0 — 環境を作る

```powershell
git clone https://github.com/haruno-ku/SF6_Tools.git sf6-combo-explorer
cd sf6-combo-explorer
git checkout feat/combo-explorer

# 何がコピーされるか見るだけ（書き込まない）
.\scripts\install-dev.ps1 -WhatIf

# このPCで初回のみ。REFramework(dinput8.dll) と D2D プラグインも置く
.\scripts\install-dev.ps1 -Bootstrap
```

以降の更新は `git pull` → `.\scripts\install-dev.ps1`（`-Bootstrap` 無し）。

- SF6 が起動中は実行を拒否する
- 録画コンボ / スロット / セッション統計 / 自分の Config は**上書きしない**
- ゲームが見つからないときは `-GameDir "...\steamapps\common\StreetFighter6"`

**開発機側で候補を再生成したいとき**（ゲーム不要、Lua 5.4 だけ要る）:

```
lua tools/lua/explore.lua
node tools/lua-runner.mjs test
```

---

## Step 1 — 無改造版の動作確認 🔴 これが通るまで何もしない

> Issue [#1](https://github.com/haruno-ku/SF6_Tools/issues/1)

1. SF6 起動 → トレーニングモード
2. `Insert` で REFramework メニューが開く
3. Training Script Manager が出る
4. **既存5モードが従来どおり動く**
   Hit Confirm / Reaction Drills / Post Guard / Custom Combo Trials / Execution Drill
5. REFramework の **Script Errors が空**

### 判定

`pl_input_sub hook not installed` が出ていたら**全方針が崩れる**ので、
そこで止めて報告する。この計画は既存の入力フックに相乗りする前提で組まれている。

---

## Step 2-6 — 読み取り専用の計測

### 共通の入り方

1. トレーニングモード、P1 = **ジーフ / モダン**
2. `Insert` → REFramework メニュー
3. **Training Script Manager → TRAINING MODES → COMBO EXPLORER**
   （上部バーにも `SWITCH` 巡回にも入れていない。1時間走る無人モードなので、
   パッドで巡回中に事故で乗るのを避けている）
4. REFramework メニューの **SF6 COMBO EXPLORER** を開く

> **Distance Viewer の Auto-Activate を必ず切る。**
> 毎フレーム P2 のマスクを書くので計測が汚れる。

---

### Step 2 — LIVE READOUT の目視

> Issue [#2](https://github.com/haruno-ku/SF6_Tools/issues/2)

**LIVE READOUT** を開いてダミーを何回か殴る。全行が動くこと:

| 行 | 期待 |
|---|---|
| `P1 control` | **MODERN** |
| `P1 action id` | ボタンを押すと変わる |
| `P1 combo_cnt` | ヒット数を数える |
| `P2 gard_combo_cnt` | ダミーがガードすると数える |
| `mComboDamage P1 / P2` | コンボ中、少なくとも片側に数字が出る |

> `mComboDamage` が `-- / --` のままでも**バグではなく重要な発見**。
> その場合は Explorer が HP からダメージを測る設計に切り替わる。
> Step 3 はそのまま実行してレポートを送ること。

---

### Step 3 — Probe A: `mComboDamage` は読めるか

> Issue [#3](https://github.com/haruno-ku/SF6_Tools/issues/3)

**なぜブロッカーか**: 上流全体で読み出しが1箇所しかなく、`pcall` の中で、
作者自身が「0 が返ることがある」と書いてフォールバックを用意している。
ここで 0 なら**全エッジの damage が 0 になり、スコアリングが破綻する**。
しかも見た目は正常に見える。

**やること**: コンボを **5本以上**当てる。単発ではなく多段も混ぜる。

**成果物**: `reframework/data/ComboExplorer_data/diagnostics/` の JSON

---

### Step 4 — Probe B: 1 input tick = 1 engine frame か

> Issue [#4](https://github.com/haruno-ku/SF6_Tools/issues/4)

**なぜブロッカーか**: フックは1フレームに複数回発火しうる。上流は
`app.BattleFlow::UpdateFrameMain` に別フックを張ってラッチで1回に落としている。
さらに**ヒットストップ中は hook tick が engine frame から乖離する**と
上流のコメントが明言している。ここが決まらないと**「delay 5」に単位が無い**。

**やること**: 30秒ほど放置 → その後**ヒットを含む**操作を30秒。
ヒットストップを跨いだサンプルが要る。

---

### Step 5 — Probe C: リセット1回の実コスト

> Issue [#5](https://github.com/haruno-ku/SF6_Tools/issues/5)

**なぜ重要か**: **総当たり行列の上限を決める唯一の数値。**
ゲームを高速化する手段は無い（`TimeScale` 等はリポジトリに存在しない）。
実時間がそのままコストになる。

**やること**: トレモメニューから**手動でリセットを10回以上**繰り返す。
（P1/P2 の位置リセット。Probe C は操作者のリセットを観測して測る）

---

### Step 6 — Probe D: 同梱カタログはこのビルドを記述しているか

> Issue [#6](https://github.com/haruno-ku/SF6_Tools/issues/6)

**なぜブロッカーか**: 下流すべてが action_id をキーにしている。
パッチで id がずれていたら、記録した全エッジが**誰も意図していない技**の話になる。
しかも**失敗は静か**。

**やること**: ジーフの技を**一通り出す**。地上通常技、必殺技、SA。
カタログに無い id が出るのは異常ではなく通常ケース（`_meta.unmapped_action_ids` に291件ある）。

**判定**: 「観測した action_id が**1つもカタログに無い**」なら赤信号。

---

### Step 2-6 の結果を開発機に返す

```powershell
# ゲームフォルダから
Copy-Item "<SF6>\reframework\data\ComboExplorer_data\diagnostics\*" `
          ".\reframework\data\ComboExplorer_data\diagnostics\" -Force
git add reframework/data/ComboExplorer_data/diagnostics
git commit -m "diagnostics: probes A-D on <日付>"
git push
```

---

## Step 7-10 — キャリブレーション

**道具は揃っている。** `core/Calibration.lua` / `core/CalibrationFsm.lua` /
`runtime/CalibrationRunner.lua` が実装済みで、207エージェントの敵対的レビューで
**スイープが嘘をつく4件**を潰してある。Step 4（時計）が結論に達したので、
掃引の刻みも engine frame と 1:1 で決まっている。

> 🔴 **ここから先はボタンが押される。** Step 2-6 のプローブは1つも注入しないが、
> キャリブレーションのスイープは P1 の `pl_input_new` に書く。
>
> - **パッドから手を離す**（書き手は同フレームの他の入力に OR する）
> - **Distance Viewer の Auto-Activate を切る**
>
> `Provenance` のゲートは生きたまま。スイープが通れるのは、暫定のボタンマップを
> **使って**いるのではなく**試して**いるから — ビットを押して技が出ないこと自体が
> そのビットについての測定結果で、ゲートが防いでいる失敗（存在しないボタンを押して
> 「繋がらない」と記録する）はここでは起きない。

### Step 7 — Modern ボタンビットの同定

> Issue [#7](https://github.com/haruno-ku/SF6_Tools/issues/7)

**現状の暫定値**（`core/Provenance.lua` の `modern_button_bits`）:

| bit | Modern |
|---|---|
| 0x10 | L |
| 0x20 | SP |
| 0x40 | Drive Parry |
| 0x80 | M |
| 0x100 | H |
| 0x200 | AUTO (Assist) |
| 0x1000 | Drive Impact |
| 0x2000 | Throw |

**この表は上流の「表示コード」にしか存在せず、注入に使われた実績が無い。**
ただし `command_display/Zangief.json` の `raw_button_mask` と一致する
（弱=16 / 中=128 / 强=256 / SP=32）。DI(576) と AUTO+SP(8192) だけ不一致なので、
**この2つは特に実測が要る。**

**やること**: 各ビットを1つずつ3フレーム単独注入し `get_ActionID()` を記録。

### Step 8 — 方向ビットと `rl_dir` 極性

> Issue [#8](https://github.com/haruno-ku/SF6_Tools/issues/8)

暫定: `UP=1 DOWN=2 LEFT=4 RIGHT=8`、`rl_dir` が **falsy のとき反転**。

根拠: P1 側の実装3箇所が一致している（P2 用の1箇所だけ逆）。
RSM の `MASKS` だけ LEFT/RIGHT が逆なので注意。

**やること**: **左右両サイド**で `6+H` / `4+H` を注入し、期待した action_id が出るか。
合わなければ極性を反転。360 系が特に壊れやすい。

### Step 9 — 入力→action_id スイープ / canonical 確定

> Issue [#9](https://github.com/haruno-ku/SF6_Tools/issues/9)

**なぜ必要か**: 同じ表記に複数の action_id が割り当たっている
（601/602 が「弱」、617/618/619 が「2+弱」…）。データ側に区別の説明が無い。
**確定しないと探索行列がキャラの技数の3倍近くに膨らむ。**

現在の状態: `13 グループ / 31 行` が `canonical_status: unverified`。

**やること**: `{5,2,4,6,1,3}` × `{L,M,H,SP}` をニュートラルから1回ずつ注入。
出た action_id を記録。「同じ入力で最初に出る id」を canonical とする。

> **注意**: 一度 `conflicting`（同じ入力が2つの id を出した）になったグループは、
> あとで一致する観測が来ても `verified` に戻らない仕様にしてある。
> サンプルは撤回ではないので。

### Step 10 — 1F 粒度の実証

> Issue [#10](https://github.com/haruno-ku/SF6_Tools/issues/10)

**やること**: 同一の A→B ペアで delay を1ティックずつ変えて各20回試行。
`get_ActionFrame()` と出た action_id が **delay に対して単調・再現的**に変化するか。

**判定**: ばらつくなら掃引の刻みを2Fに落とすか、ヒットストップ補正を見直す。

**出力**: `calibration/Zangief/modern-<gamePatch>.json`
（`ac_sha256` / `bcm_sha256` / `gamePatch` を必ず含める）

---

## Step 11 — 注入 smoke test

> Issue [#11](https://github.com/haruno-ku/SF6_Tools/issues/11)

Step 7-10 が終わって初めて `Provenance` が注入を許可する。

**やること**: 既知の1ペア（例 `2L → 2L`）を単発実行して目視。
多段技（623 等）を A に置いて、**`combo_cnt` の絶対値判定に依存していない**ことも確認。

---

## Step 12 — A→B 総当たりの初回実走

> Issue [#12](https://github.com/haruno-ku/SF6_Tools/issues/12)

**最初から欲張らない。** Probe C のコスト実測を見てから行列サイズを決める。

初回の推奨スコープ:
- A は Modern 地上通常技のうち **light / medium のみ**
- 1試行（3回再検証は成立したペアだけ）
- delay は粗く（線形掃引しない）

**中断・再開は実装済み**（`core/ResultCollector.lua`）。
1試行ごとに JSONL へ追記され、再開時は完了済みをスキップする。
クラッシュで切れた最終行は「実行したが結果を失った」として扱われ、再実行される。

---

## 今どこまで出来ているか

**オフライン側は縦に通っている。** ゲーム無しで候補生成が端から端まで動く。

```
lua tools/lua/explore.lua
```

現在の Zangief / Modern / 中央 / 通常ヒットの出力:

| | |
|---|---|
| 始動技 | 14 |
| 理論エッジ | 387（high 88 / medium 133 / low 166） |
| ルート候補 | 1037（3手まで） |
| 情報不足による除外 | **0件** |

**この1037は「繋がるコンボ」ではない。** 全件 `status: theoretical` /
`runtime_verified: false`。全文は `zangief-offline-report.md`。

テスト: **2656 アサーション**（Lua 5.4、SF6 不要）。

### 未実装（実機の結果を見てから書くもの）

| | 何が決まってから書けるか |
|---|---|
| `runtime/Injector.lua` | Step 7-10 が `verified` になってから |
| `runtime/StageControl.lua` | `StageControlFsm` は実装済み、`GameAdapter` との配線が残り |
| Runner の実機結線 | `RunnerFsm` は実装済み、同上 |

`Calibration.lua` は**実装済み**（Step 4 の結果が出たので書けた）。

### 開発機で回せる道具

ゲーム不要、Lua 5.4 だけ。

```
lua tools/lua/audit.lua      # 31キャラ: 分類器は通用するか（数秒）
lua tools/lua/survey.lua     # 31キャラ: frame-data join は通用するか（4秒）
lua tools/lua/explore.lua    # 1キャラの候補を全部出す
```

キャラ名は `data/characters.json` が正。`Zangief` / `zangief` / `6` のどれでも通る。
知らない名前は**推測せず拒否する**（3キャラは単純な小文字化では届かない）。

---

## 迷ったときに読むもの

| ファイル | 何が書いてあるか |
|---|---|
| `core/Provenance.lua` | **最初に読む。** 未計測の10項目と、それが違うと何が壊れるか |
| `docs/ComboExplorer/work-split.md` | 実機なしで進む作業 / 実機待ちの作業の一覧 |
| `docs/ComboExplorer/plan-v3-implementation.md` | 全体計画。§10 が敵対的検証後の設計修正 |
| `docs/ComboExplorer/README.md` | プローブの操作手順 |
| `docs/NOTICE.md` | フレームデータは CC-BY-SA-4.0（MIT ではない） |

## まだ答えが出ていない設計判断

実機のデータを見ないと決められないもの。忘れないように Issue にしてある。

| | |
|---|---|
| [#14](https://github.com/haruno-ku/SF6_Tools/issues/14) | `Schema.KIND.TRIAL` の `edge_id` 契約（ルート試行には edge_id が無い） |
| [#15](https://github.com/haruno-ku/SF6_Tools/issues/15) | 「実行したが答えが出なかった」試行の status 語彙 |
| [#16](https://github.com/haruno-ku/SF6_Tools/issues/16) | 63214+KK の距離バリアント（(Close) 10F / (Mid) 23F / (Far) 54F） |
| [#17](https://github.com/haruno-ku/SF6_Tools/issues/17) | Knowledge DB へ渡す実測ブロックの形状 |

## 絶対にやらないこと

1. **未検証の値を「仮に決めて」先へ進めない。** これが全体の設計原則
2. `command_display/*.json` をハンド編集しない（strict loader が丸ごと落ちる）
3. 既存の `sdk.hook` を二重登録しない
4. 未検証データを Knowledge DB へ export しない（`placeholder` は廃止済みで置き場が無い）
5. 「情報不足 = 接続不可」と判定しない
