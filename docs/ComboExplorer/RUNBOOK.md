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
# checkout は不要。PR #31 で main にマージ済み（2026-09-11）

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

## Step 6.5 — ステージリセットを1回試す 🆕

> パネルの **STAGE RESET**

**キャリブレーションより先にこれをやる。** 理由は2つ:

1. **入力を1ビットも書かない。** 書くのはリフレッシュ要求だけなので、
   ボタンマップが未測定でも安全に走らせられる。いちばん安全な最初の一歩
2. **リセットが動かないなら試行は動かない。** Step 11-12 はすべてこの上に乗っている

### なぜ今まで無かったか

`core/StageControlFsm.lua`（588行）は最初から完成していてテストも通っていたが、
**`GameAdapter` に書き込み関数が1つも無かった**ので、FSM が出す4つのコマンド
（`request_refresh` / `write_setup` / `correct_position` / `pin_resources`）は
どれも実行できなかった。さらに `snapshot()` が `refreshing` を返さないので、
FSM は **WAIT_REFRESH から永遠に出られなかった。**

### やること

パネル → **STAGE RESET** → `RESET ONCE`。

`outcome: ready` と `ticks to ready` が出れば通っている。
`WRITE REPORT` で `diagnostics/stage_reset-*.json` に書き出してコミットする。

### これが測るもの

`StageControlFsm` は8つの設定値を要求し、**キャリブレーションのスイープは1つも産出しない。**
今は次の値で走っている。画面にも成果物にも、測定値か推測かが書いてある:

| 設定 | 値 | 出所 |
|---|---|---|
| `settle_ticks` | 9 | **実測**（Probe C: 7-9 tick、中央値7） |
| `grace_ticks` | 15 | 推測（上流の `_reset_grace`） |
| `refresh_timeout_ticks` | 600 | 推測（大きめの予算） |
| `settle_timeout_ticks` | 600 | 推測（同上） |
| `target_positions` | `false` | 今回は位置補正をしない |
| `pin` | `false` | 今回は HP/Drive/SA を固定しない |

> **なぜこれが「未測定値を仮に決める」に当たらないか。**
> この8つは**リンクの成否を決めない**。予算と許容差で、外れると
> `reset_failed` で**大声で**落ちる。ボタンビットを仮に決めた場合は逆で、
> 技が出ないまま「繋がらない」という**自信のある否定**が記録される。
> 壊れ方の向きが逆。
>
> それでも推測は推測なので、**この回が8つを測る回**になる。
> レポートの `ticks_to_ready` を見て、次から本物の数字に置き換える。

---

## Step 7-10 — キャリブレーション 🆕 **放置できます**

> **2026-09-11: 人間待ちが無くなりました。**
>
> 方向フェーズの4ステップは `rl_dir` の両側を要求し、合わないと
> `WAITING_FOR_SIDE` で止まって操作者が場所を入れ替えるのを待っていました。
> **キャラごとに覚えていられる手順ではない**、というのがこの変更の理由です。
>
> 今はコマンドに `request_side` が乗り、ランナーがトレーニングメニューの
> 開始位置を書いてエンジンに向きを変えさせます
> （上流の `TrainingMoveExecution.lua:184-197` と同じやり方）。
>
> **信じる相手は変わっていません。** 待ちは今も `rl_dir` を毎 tick 見ていて、
> `rl_dir` が合ったときだけ進みます。入れ替えが効かなければ**今までと同じ**で、
> 操作者が自分で動いても構いません。要求を信じている箇所は1つもありません。
>
> 併せて **3種類のタイムアウト**が入りました（settle / side / gate）。
> 詰まったステップは**そのステップだけ**諦めて次へ進み、理由を記録します。
> **諦めたステップには観測を記録しません** — 「押したが何も出なかった」と
> 「そもそも押せなかった」は違う話で、前者として記録したら
> ビットについての**間違った測定**になります。
>
> **完走すると自動でプロファイルが書かれます。** 以前は `DONE` が何もせず、
> 人間が WRITE PROFILE を押す必要があり、しかも先に STOP を押すと
> run ごと消えていました。放置して戻ってきたら消えている、が以前の仕様です。
>
> **パネルを閉じても凍りません。** 以前は `CalRunner.tick()` が
> 早期 return の後ろにあり、パネルを30フレーム見ないと静かに停止していました。

### やる前に（これだけは人間の仕事）

- **パッドから手を離す。** 押しているものは OR で混ざります
- **Distance Viewer の Auto-Activate を切る。** P2 に毎フレーム入力を書きます
- キャラは**人間が選びます**。`FighterID` への書き込みはリポジトリ全体で0件で、
  プログラムからキャラを変える方法はありません



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

`Calibration.plan` の方向フェーズは **6 ステップ**。LEFT と RIGHT を両サイドで 4回、
UP と DOWN を 1回ずつ（向きは「上が上か」に関係しないので side を持たない）。
UP/DOWN のステップは 2026-09-11 に足した（#28）。それまでは押さずに推測のまま
`verified` と刻まれており、`direction_bits` は**構造的に refuted になれなかった**。

判定は「保持中に action_id がニュートラルから離れ、かつ UP と DOWN が**別の id** を出す」。
これが証明するのは「そのビットは方向入力であり、2つは別物である」まで。
**どちらが上かは証明しない** — スナップショットに高さが無い（`GameAdapter` に
y 座標も空中フラグも無い）ので、しゃがみとジャンプはラベルの無い2つの id でしかない。
上下の取り違えは Step 9 のスイープが捕まえる（`2 + 弱` がジャンプ系 id で返る）。

片方でも出なければ `direction_bits` は `partial` で止まり、
`unwitnessed` にどれを押せていないかが残る。**`verified` にはならない。**

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
`runtime/Injector.lua` が**そのゲートの最初の呼び出し元**で、
3項目が verified になるまで起動を拒否し、**拒否のときに何が足りないかを名前で言う。**

### やること

1. **PROBE D** で `LOAD CATALOG`（試行ペアはカタログから取る）
2. パネル → **TRIAL**。A / B / delay が表示される。
   `NEXT PAIR` で順番に送れる（自己ペアは飛ばす）
3. `Config.allow_injection` を **on** にする（レジスタとは別の、操作者自身のスイッチ）
4. `RUN ONE TRIAL`

`outcome: judged` なら通っている。結果は
`ComboExplorer_data/trials/trials.jsonl` に1行ずつ追記される。

### 見るところ

| | |
|---|---|
| `masks written` | 0 のままなら書けていない。`_shared_input_post` か mirror の問題 |
| `FAILED WRITES` | 赤で出たら中身を読む。黙って失敗するのがいちばん困る |
| `stage` | リセットが READY まで行っているか |

多段技（623 等）を A に置いて、**`combo_cnt` の絶対値判定に依存していない**ことも確認。

### 初回に出てもおかしくないもの

- **`the recorder cannot encode`** — このビルドの REFramework に
  `json.dump_string` が無い。**1試行目より前に**出る（開始時に1回だけ確かめている）
- **`could not open ... for append`** — `io.open` の基準ディレクトリが
  `json.dump_file` と違う。どちらなのかは**まだ測っていない**ので、
  違えば大声で落ちるようにしてある。出たら、それが答え

---

## Step 12 — A→B 総当たりの初回実走

> Issue [#12](https://github.com/haruno-ku/SF6_Tools/issues/12)

### やること 🆕 **放置できます**

開発機で1回（キャラごと）:

```
lua tools/lua/explore.lua --character Zangief --worklist
```

`reframework/data/ComboExplorer_data/worklist/zangief-modern.json` が出ます
（Zangief で 378ペア / 76KB）。**confidence 順**に並んでいるので、
途中で止めてもフレームデータが何か言えたペアから消化されています。

実機で:

```
パネル → SWEEP → START SWEEP
```

**あとは放置。** 1試行およそ3秒:

| キャラ | ペア数 | 1パス |
|---|---|---|
| Zangief | 378 | 約20分 |
| Ryu | 590 | 約30分 |
| Juri | 2466 | 約2時間 |
| Guile | 2888 | 約2.4時間 |

> 観測窓は今 **120 tick（2秒）の推測値**です。実機で測って 30 tick に縮めば
> 1試行1.5秒短縮 = Zangief で9分短くなります。最初のパスがその数字を持ち帰ります。

### 勝手に止まる条件（全部そう設計してあります）

| | |
|---|---|
| ワークリストを回り切った | 正常終了 |
| **連続で**試行を開始できない | 何も測れていないので止まる。理由は Injector のものをそのまま表示 |
| 1ペアが3回とも無結論 | そのペアを諦めて記録し、次へ |

**中断・再開は実装済み**（`core/ResultCollector.lua`）。
1試行ごとに JSONL へ追記され、再開時は完了済みをスキップします。
クラッシュで切れた最終行は「実行したが結果を失った」として扱われ、再実行されます。

### 初回に出てもおかしくないもの

- **`WARNING: no json.load_string on this build`** — 前回の結果を読み戻せないので
  済んだ試行も回し直します。**無駄なだけで、間違いではありません**
- **`the recorder cannot encode`** — こちらは**1試行目より前に**拒否します。
  記録できないまま一晩回すよりは、開始時に止まるほうが安い

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
| 理論エッジ | 378（high 96 / medium 136 / low 146） |
| ルート候補 | 971（3手まで — 2手 179 / 3手 792） |
| 情報不足による除外 | **0件** |

**この971は「繋がるコンボ」ではない。** 全件 `status: theoretical` /
`runtime_verified: false`。全文は `zangief-offline-report.md`。

テスト: **3479 アサーション**（Lua 5.4、SF6 不要）。

### ランタイムの配線（2026-09-11 に完了）

| | |
|---|---|
| `GameAdapter` の書き込み側 | **完了** — `request_refresh` / `set_position` / `pin_resources` / `write_setup`、および `tick_snapshot`（`refreshing` と `can_inject` を合わせる層。これが無いのでリセットは永遠に完了しなかった） |
| `runtime/StageControl.lua` | **完了** — FSM のコマンドをその tick の分だけ実行する。入力は1ビットも書かない |
| `runtime/Injector.lua` | **完了** — park して `_shared_input_post` で spend。`Provenance.can` の最初の呼び出し元。ミラーの持ち主 |
| `runtime/Sweep.lua` | **完了** — 1キャラ分のワークリストを無人で回す。再開・リトライ・空振り検知つき |
| `JsonIO` の append / encode / decode / read | **完了** — JSONL 追記と読み戻し |
| パネル | **完了** — STAGE RESET / CALIBRATION / TRIAL / SWEEP |

## Step 13 — 結果を「繋がるコンボの一覧」にする 🆕 開発機

> スイープが書くのは**試行ログ**です。それを一覧に変えるのがこの手順。

```
lua tools/lua/confirm.lua --character Zangief
```

`confirmed/zangief/modern/confirmed-edges.json` と `report.md` が出ます。

### 何が出るか

| | |
|---|---|
| `verified` | **ゲームが繋がると言った**ペア |
| `rejected` | 繋がらないと言ったペア |
| `pending` | **試行は走ったが何も答えなかった**ペア |
| `stable` | 上のうち、1回ではなく**再現した**もの |

### 読み違えてはいけない2点

**`pending` は失敗ではありません。** `a_failed` / `wrong_move` / `inconclusive` は
「A が当たらなかった」「別の技が出た」で、**リンクは試されていません**。
もう一度走らせる価値があります。`rejected` にはありません。

**1回繋がっただけのものは `stable` になりません。** Schema が
「再現したか、再現していないと承知しているか」を要求するので、
1回だけの結果は `--unstable-ok true` と言わない限り通りません。
**もう一度スイープを流す方が安いです。**

### delay の窓 = 実行猶予フレーム

どの delay で繋がったかが**そのまま猶予フレーム**です。
`core/Scoring.lua` が「掃引しないと測れない」と言って出さない数字がこれ。

ただし報告する幅は**試した値の上での連続**です。
2, 4, 6 を試して全部繋がったなら**測ったのは3点**で、5フレーム幅ではありません。
間を埋めるのは走らせていない試行を捏造することです。

---

### まだ書いていないもの

| | 何待ちか |
|---|---|
| **ルート試行（実機2回目）** | **`ce.verified_combo.v1` は実測ダメージを要求する**ので、ペアではなくルートを走らせる必要がある。ここが繋がるまで公開用の一覧は作れない |
| `KnowledgeDb` の呼び出し元 | 上記の次。1024行のアダプタは書けているが入力が無い |
| 3回再検証 | 1パスが実機で通ってから。今は1ペア1試行 |
| delay の線形掃引 | `SequenceCompiler.M.sweep` は実装済み。`Sweep` から使うのは次 |
| 全キャラの連続実行 | **できません** — `FighterID` への書き込みがどこにも無く、キャラは人間がメニューで選ぶしかない |
| オーバーレイを消す（動画用） | #35。録り方が決まってから |

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
