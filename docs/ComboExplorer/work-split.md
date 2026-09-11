# 作業分割 — 実機なしで進める範囲 / 実機待ちで止める範囲

**状況**: SF6 を動かすゲーミング PC がまだ無い。開発 PC には Steam も SF6 も REFramework も無い。

**原則**: **実機でしか確かめられない値を「仮に決めて」先へ進めない。**
未確定のものは値を持たせず、`unverified` 状態として明示的に保留し、
実機導入後にキャリブレーション結果で確定させる。

---

## 進捗（このドキュメント作成後）

| 項目 | 状態 |
|---|---|
| A0 未検証値レジストリ `core/Provenance.lua` | **完了** — 10項目、能力ゲート（injection と probing を分離）、キャリブレーション適用 |
| A1 現ビルドのレビューと修正 | **完了** — 5観点 × 敵対的検証（31エージェント / 60件提起 / 38件維持）。維持されたもののうち現行ツリーに該当する分はすべて対応 |
| A2 実機依存 / 非依存の分離 | **完了** — `core/` は純粋、`runtime/GameAdapter.lua` が `sdk` に、`runtime/JsonIO.lua` が `json`/`fs` に触れる唯一のファイル |
| A3 raw JSON loader / slim map 回帰 / 分類 / canonical・variant / Catalog | **完了** — `core/Catalog.lua` |
| A5 `LinkVerdict`（combo count 増加で判定） | **完了** — `core/LinkVerdict.lua` |
| A7 読み取り専用プローブ（A/B/C/D） | **完了** — 注入なしで4つの未知すべてに答えられる |
| A4 Schema 固定 | **完了** — `core/Schema.lua`。8 レコード種別、状態語彙は `theoretical / runtime_pending / verified / rejected` の 4 値に閉じている |
| A6 外部フレームデータの接続 | **完了** — `core/FrameData.lua`。classic 表記 ↔ numpad の join を**どの規則で一致したか記録して**返す。不一致は「不明」であって「不可」ではない |
| A6 `CandidateGenerator` | **完了** — 理由を構造化して持つ。**情報不足で除外しない**。既知の負マージンのみ、数値付きで除外 |
| A6 `GraphStore` | **完了** — 実測は理論を上書きするが逆はしない。AC/BCM/patch が違う結果は**併合を拒否**する |
| A6 `RouteSearch` | **完了** — step 上限 / 同一 action 反復 / 連続反復 / 同一 edge 反復 / beam 幅 / OD・SA 予算。**打ち切ったら必ず報告**する |
| A6 `Scoring` | **完了** — オフラインは予測値のみ。`damage` / `execution_leniency_frames` / `difficulty` は**フィールドごと存在しない** |
| A5 `SequenceCompiler` | **完了** — delay を**発明しない**（未指定はエラー）。未検証プロファイルは拒否 |
| A6 `Exporter` + オフライン CLI | **完了** — `lua tools/lua/explore.lua` でゲーム無しに端から端まで通る |
| A5 `StageControlFsm` / `RunnerFsm` | **完了** — 純関数の状態機械。未計測の tick 数が未設定なら起動を拒否する |
| A6 `ResultCollector` / KDB adapter | **完了** — JSONL 追記と再開、切れた最終行は「実行したが結果を失った」として再実行。KDB は実測 damage が無ければ通さない |
| A7 プローブ A-D 実機実行 | **完了**（2026-09-10、SF6 build 24176760）— 4件すべて結論に到達 |
| `Calibration` / `CalibrationFsm` / `CalibrationRunner` | **完了** — 実機投入待ち |
| 全31キャラのカタログ監査 / 分類器の汎用化 | **完了** — `tools/lua/audit.lua` |
| 全31キャラのフレームデータと join 計測 | **完了** — `tools/lua/survey.lua` |

テスト: **2853 アサーション**（Lua 5.4.6、SF6 不要）。
`node tools/lua-runner.mjs syntax` は構文＋**require 解決**もチェックする
（実機でしか出ないロードエラーを開発機で捕まえる）。

### オフライン Explorer は縦に通っている

```
command_display/Zangief.json ─┐
                              ├─→ Catalog ─→ CandidateGenerator ─→ GraphStore
data/frame-data/zangief.lua ──┘                                        │
   (CC-BY-SA-4.0, commit pin 付き)                                     ↓
                                                                  RouteSearch
                                                                       ↓
                                          Exporter ←── Scoring ←───────┘
                                              ↓
                        candidates/zangief/modern/{candidate-edges,candidate-routes}.json
```

一発で再生成できる:

```
lua tools/lua/explore.lua
```

出力（`docs/ComboExplorer/zangief-offline-report.md` に全文）:

| | |
|---|---|
| 始動技 | 14（Modern 地上通常技 / manual） |
| 対象技 | 33（通常・必殺・SA / manual + simple） |
| 検討したペア | 518 |
| 理論エッジ | **378**（high 96 / medium 136 / low 146） |
| 除外 | 140 — うち 131 は**既知の**負マージン（数値付き）、9 は連打不可の自己ペア |
| 情報不足による除外 | **0 件** |
| ルート候補 | **971**（3 手まで。同一入力で action_id だけ違う 2303 件を畳んだ後） |

> high が 128 から 88 に下がっているのは品質劣化ではない。曖昧な frame-data join
> （`63214+KK` が距離バリアント3つのどれか決まらない等）に乗っていた40件が、
> 根拠を失って low に落ちた結果。**測っていなかったものを測った。**

### 全31キャラの状態（2026-09-11）

`lua tools/lua/audit.lua` と `lua tools/lua/survey.lua` で測る。ゲーム不要。

| | |
|---|---|
| カタログ行 | 3592 |
| 理論エッジ | **25646**（high 7731 / medium 5471 / low 12444） |
| ルート候補 | 5404（2手まで、survey のスコープ） |
| **情報不足による除外** | **0 件** / 12448 除外（31キャラ全部で） |
| 分類器が置けなかった行 | 52（監査開始時 187 → #21 で 76 → 派生の修正で 52） |
| 対象技の frame-data join | **1643 / 1719**（#23 の修正前は 1554） |
| 曖昧な frame-data join | 302 |

**join が弱いキャラ**（#23 で修正済み。以下は修正**後**の残り）:

| キャラ | 対象技の結合率 | 残っている理由 |
|---|---|---|
| Jamie | 72% | `6+P` — **ソースにエントリが無い**（#32） |
| Elena | 78% | `6+LK` `6+HK` — 同上 |
| Guile | 85% | `56+LP` — 同上 |

修正前に効いていた形は2つあり、どちらもソースの綴りを読んで根拠を立てた:

- **強さを名乗らないボタン**（`6+P` / `6+PP` / `6+PPP`）— ソースが強さ別の
  レコードを持たない技は、そもそも強さで分かれていない。JP 55% → 100%
- **`"X or Y"` 綴り** — 1レコードが2つの入力を持つ。両方を鍵にする

残る3キャラの数行は、綴りの問題ではなく**ソース側にその技が無い**。
推測で埋めるのではなく #32 に分けてある。

**派生技は30/31キャラで結合率0%。** ソースは派生を直前の技からの連鎖
（`5MP~MP`）で綴るが、`>MP` は何の派生かを言わない。単純な変換では解けない。

**この 971 は「繋がるコンボ」ではない。** 全レコードが `status: theoretical` /
`runtime_verified: false` で、1 件残らず SF6 本体の判定待ちである。

### カタログ監査 — このパイプラインは Zangief 専用か（#19）

```
lua tools/lua/audit.lua                 # 全31キャラ
lua tools/lua/audit.lua --character Guile
```

31キャラの `command_display/*.json` に `Catalog.build` を回すだけ。
**フレームデータ不要・ゲーム不要**。全文は
[`docs/ComboExplorer/catalog-audit.md`](catalog-audit.md)、
action_id 単位の内訳は `catalog-audit.json`。

**答えは「Zangief 専用になっていた」。#21 で直した。**

`core/Catalog.lua` の `category_from_classic` が置けなかった行は、除外チェーンの
最後で `system` として落ちていた。落ちた行は「技が落ちた」という痕跡を残さない。

#21 で2つ直した:

**1. `unknown` が `system` に化けるのをやめた。**
「分類できなかった」と「これはダッシュだ」は違う主張である。両方が `system` に
なっていたので、語彙の穴が技についての事実に化け、しかも**数えられなかった**。
`unclassified` という自分の名前で除外するようにしたので、
`by_exclusion.unclassified` が「語彙がどれだけ足りないか」を言うようになった。

**2. 溜め表記と 623 を分類器に足した。**
`[4]6` / `[2]8` / `[4]646`（溜め。`[` の後の方向が3つ以上なら SA）と `623`（昇竜）。
`623` は `unknown` にすらなっていなかった — 数字で始まるので
`command_normal` に落ちていて、**18キャラ147行の必殺技が通常技として探索されていた。**

| | 修正前 | 修正後 |
|---|---|---|
| `unclassified` 落ち（全体） | **187** | **76** |
| Guile | 53 | **2** |
| Guile の standalone | 58 | **109** |
| Blanka / EHonda / DeeJay / MBison / ChunLi | 20/16/15/13/11 | 8/3/1/1/2 |
| Zangief | 8 | 8（溜め技も昇竜も無いので当然） |

監査の判定も「キャラ間で偏っていない」に変わった（最悪 Alex 8 = Zangief 8）。

**残る76行はモーション語彙の穴ではない**別クラス:
全ボタン同時押し（`LP+MP+HP+LK+MK+HK`、31キャラ全部）、
強さを名乗らない `PP` / `KK` / `P` / `PPP`、
classic 側にだけ `>` があって Modern 側に無い派生（Alex など）。
分類器に正規表現を足しても届かない。

> **注意**: 修正直後、監査の `LOST` 列が全キャラ 0 になった。問題が消えたのではなく、
> 数えていた条件（`unknown` かつ `system` 落ち）が改名で成立しなくなっただけだった。
> 監査側を `unclassified` を数えるよう追随させてある。**改名で静かになる指標は、
> 指標が無いより悪い** — 問題が解決したと報告するので。

### まだゲームにしか答えられないこと（全候補が抱えている）

| | |
|---|---|
| `pushback_range` | フレームデータの pushback は**全件 null**。1 発目の後に届くかは実機でしか分からない |
| `modern_specific_scaling` | Modern のダメージ補正はどのフレーム表にも無い |
| `actual_input_timing` | 入力受付幅こそがスイープで測るもの |
| `knockdown_vs_link_advantage` | +36 が起き攻め有利かリンク有利か、データに区別が無い |
| `cancel_window_conditions` | キャンセル受付の特殊条件はどの表にも無い |
| `hitbox_hurtbox` | 同一表記に複数 action_id。どれが出るか未確定 |
| `juggle_behaviour` | juggle 状態が後続を決める |

### 読み取り専用プローブが答えるもの

| プローブ | 質問 | 注入 |
|---|---|---|
| A | `mComboDamage` は読めるか | 不要 |
| B | 1 input tick = 1 battle frame か / ヒットストップで止まるか | 不要 |
| C | リセット1回の実コスト（= 総当たり行列の上限） | 不要 |
| D | 同梱カタログはこのビルドを記述しているか | 不要 |

**C は当初「注入後」の予定だったが、操作者のリセットを観測すれば測れると分かったため前倒しした。**
結果として、実機初日に未知の4項目すべてを埋められる。

---

## A. 実機なしで進める作業

上から順に依存している。上が終わらないと下が正しく書けない。

### A0. 基盤 — 未検証値レジストリ（最優先）

`core/Provenance.lua`。§C の 9 項目を **1 箇所に集約**し、各項目に
`value` / `source` / `status` / `blocks` を持たせる。

- `status = "unverified"` の値を使う処理は、**使う前に必ず状態を確認できる**
- 注入に関わる項目が 1 つでも `unverified` なら **Injector は起動を拒否する**
- キャリブレーション結果 JSON を読み込むと該当項目が `verified` に昇格し、値が上書きされる

これが無いと、以下すべてのモジュールが「知らない値を知っているふりで」書かれてしまう。

### A1. 現ビルドのコードレビューと修正

`Clock` / `Telemetry` / `InputMask` / `Config` / `ComboExplorer.lua` を、
5 観点（未検証値の混入 / Lua・REFramework 正しさ / 実機依存と純粋の分離 /
プローブの妥当性 / 上流への影響）でレビューし、指摘を反映する。

とくに **`InputMask.lua` は現状 Modern ビット表を定数として埋め込んでいる**。
これは §C-5 そのものなので、レジストリからプロファイルとして受け取る形に変える。

### A2. 実機依存 / 非依存の分離

```
実機依存（開発機でテスト不可）        開発機でテスト可能（純粋 or I/O注入）
────────────────────────────         ──────────────────────────────────
runtime/GameAdapter.lua              core/Provenance.lua
runtime/Clock.lua                    core/InputMask.lua
runtime/Probe.lua                    core/Catalog.lua
runtime/Injector.lua                 core/Classify.lua
runtime/StageControl.lua             core/CandidateGenerator.lua
UI.lua                               core/SequenceCompiler.lua
                                     core/RunnerFsm.lua
                                     core/StageControlFsm.lua
                                     core/LinkVerdict.lua
                                     core/ResultCollector.lua
                                     core/GraphStore.lua
                                     core/RouteSearch.lua
                                     core/Scoring.lua
                                     core/Exporter.lua
                                     core/Schema.lua
```

**`GameAdapter` が `sdk` に触れる唯一のファイル**にする。
テストでは同じインターフェースの偽物を渡す。
`json.load_file` も REFramework 専用なので、Catalog は**読み込み関数を注入**で受け取る。

### A3. データ層

| 作業 | 内容 |
|---|---|
| raw JSON loader | `command_display/<Char>.json` を**生のまま**読む。`CommandDisplay` / `BcmCatalog` / `ModernDisplay` を経由しない |
| slim map 回帰テスト | slim map は `simple = simple or manual` にフォールバックする。**motion-only の技が「簡易入力あり」に化ける**ことを再現し、生 JSON なら化けないことを固定する |
| 分類 | `standalone` / `context_dependent` の判定。`>` 派生 / `assist_combo` / `ac_state_*` / `AUTO` を context_dependent に落とす |
| canonical / variant | 601 vs 602、617/618/619 などを**確定させない**。同一表記グループとして束ね、`canonicalStatus = "unverified"` のまま持つ。実機スイープ結果を後から流し込んで確定できる形にする |
| Catalog | 上記を統合し、**未検証状態のまま**成立するカタログを出す |

### A4. スキーマ固定

`core/Schema.lua`。バージョン付きで固定し、以降の全モジュールがこれに従う。

- **Result schema** — 1 試行 1 レコード（JSONL）
- **Edge schema** — 確定エッジ
- **Diagnostics schema** — プローブ報告（プローブ A/B は既に書式が決まっている）
- **Calibration schema** — 実機で確定した値の受け皿

`delay` は**素の数値にしない**。`{ delayTicks, tickBasis, calibrationId }` として単位を持たせる。
`executionLeniencyFrames` は **difficulty と別フィールド**で保持する。

### A5. 状態機械（ゲーム非依存部分）

| 作業 | 内容 |
|---|---|
| `StageControlFsm` | `REQUEST → WAIT_REFRESH → CORRECT → PIN → SETTLE → READY` の**遷移だけ**。I/O は呼び出し側 |
| `RunnerFsm` | 1 試行の状態機械。観測値を入力、注入指示を出力とし、**ゲームに触らない** |
| `LinkVerdict` | 「B の action によって combo count が増えたか」で判定。**`1→2` 固定にしない** |
| `SequenceCompiler` | テストケース → tick 列。`InputMask` の上に載る |

FSM を純粋にしておくと、実機が来る前に**遷移とタイムアウトを全部テストできる**。

### A6. 収集・探索・出力

| 作業 | 内容 |
|---|---|
| `ResultCollector` | JSONL 追記、flush、**中断・再開**（完了済みペアのスキップ） |
| `GraphStore` | 確定エッジの保存と読み出し。`gamePatch` / `calibrationId` 不一致で無効化 |
| `RouteSearch` | 確定エッジのみで DFS/BFS。step 上限 / Drive / SA / ループ禁止 |
| `Scoring` | difficulty は**派生値**。`executionLeniencyFrames` は実測値として別に残す |
| `Exporter` | dry-run。**未検証は出さない** |
| Knowledge DB adapter | `scripts/types.ts` / `domain.ts` に対する**契約テスト**。5 種の source、`self_tested` のみ許可 |

### A7. 実機投入直後に走らせるものの準備

- `Calibration.lua` の**手順と出力形式**を先に固定（実行は実機）
- injection smoke test の**内容を確定**（何を注入して何を確認すれば「注入が効いた」と言えるか）
- カタログ自己診断（実機で生 JSON を読み、パース成功率を報告）

---

## B. 実機待ちで止める作業

**着手しない。仮定で埋めない。**

| # | 作業 | 何が確定するまで待つか |
|---|---|---|
| 1 | Phase 0-5 無改造版の実機確認 | ゲーミング PC |
| 2 | LIVE READOUT の実機確認 | 同上 |
| 3 | Probe A（ダメージ可読性） | 同上 |
| 4 | Probe B（時計） | 同上 |
| 5 | Modern ボタンビット キャリブレーション | 同上 |
| 6 | 方向ビット / `rl_dir` 極性の確認 | 同上 |
| 7 | 入力→action_id スイープ | 同上 |
| 8 | canonical / variant の確定 | #7 |
| 9 | 1F 粒度の実証 | Probe B |
| 10 | 入力注入（Injector の実装完了と有効化） | #3-#6 が verified |
| 11 | injection smoke test | #10 |
| 12 | リセット整定時間の実測 | #11 |
| 13 | コスト実測スパイク（1 試行の壁時計） | #11 |
| 14 | A→B 総当たり | #12, #13 |
| 15 | フレームメーター実挙動 | #1 |
| 16 | 画面端の実座標 | #1（MVP 3 スコープ） |

---

## C. 未検証値レジストリ（保留リスト）

`core/Provenance.lua` に載せる 9 項目。**すべて `status: "unverified"`** で開始する。

| # | key | 暫定値 | 出所 | これが違うと何が壊れるか |
|---|---|---|---|---|
| 1 | `input_hook_calls_per_frame` | 1（プレイヤーごと） | 上流がラッチを入れている事実からの推測 | 2 なら delay が全部半分になり、最初のデータセットが 2 倍ずれる |
| 2 | `tick_equals_frame` | 未定 | — | delay に単位が無くなる。外部フレームデータと突き合わせ不能 |
| 3 | `hitstop_advances_tick` | false（進まない） | 上流コメント「hitstop frames missed between engine ticks」 | ヒットストップを挟む全リンクの窓がずれる |
| 4 | `combo_damage_readable` | 未定 | 上流 1 箇所・pcall・HP フォールバック付き | 全エッジの damage が 0 になり、スコアリングが破綻する |
| 5 | `modern_button_bits` | L=0x10 M=0x80 H=0x100 SP=0x20 AUTO=0x200 | `ComboTrials_D2D.lua:299-321`（表示専用・注入実績なし）+ `raw_button_mask` 一致 | 存在しないボタンを押し、全技が空振りし「リンクしない」という誤データが残る |
| 6 | `rl_dir_polarity` | falsy で反転 | P1 の 3 箇所が一致（P2 の 1 箇所は逆） | 片側だけ前後が逆になる。360 系が特に壊れる |
| 7 | `action_id_canonical` | 未定 | 同一表記に複数 id、データに区別の説明なし | 探索行列が 3 倍に膨らむ／別 id を同じ技として混同する |
| 8 | `reset_settle_ticks` | 25（暫定） | 上流の 10 リトライ + 15 grace の合算 | 整定前に試行が始まり、幻のエッジと偽陰性が混ざる |
| 9 | `frame_meter_semantics` | FrameType 7/8/9/10 | `TrainingHitConfirm_v1.0.lua:502-560` | 有利フレームの実測値が誤る |

**方向ビット（UP=1 DOWN=2 LEFT=4 RIGHT=8）は #6 と別項目**として扱う。
2 つの独立した読み手が一致しているので #5 より確度は高いが、これも実機で確認する。

---

## D. 実機が来た瞬間の最短経路

A の作業がすべて終わっていれば、実機側は**この順に一度ずつ**でよい。

```
1. install        scripts/install-dev.ps1 -Bootstrap
                  → 無改造版の動作確認（Script Errors が空）

2. read-only診断  mode 6 → LIVE READOUT 目視
                  → Probe A（コンボ 5 本以上）
                  → Probe B（30 秒、ヒット込み）
                  → カタログ自己診断
                  → diagnostics/*.json を commit

3. calibration    ボタンビット同定 → 方向・rl_dir 極性
                  → 入力→action_id スイープ → canonical 確定
                  → 1F 粒度の実証
                  → calibration/*.json を commit
                  → レジストリの 9 項目が verified に昇格

4. smoke test     1 ペアだけ注入して期待通りか目視
                  → リセット整定時間・1 試行コストを実測

5. A→B探索        light/medium 始動に絞って数百試行（約 1 時間）
                  → パイプライン全体を通してから行列を広げる
```

**3 が終わるまで 4 は起動しない**（Injector がレジストリを見て拒否する）。
仕組みとして拒否させるので、手順を忘れても事故にならない。
