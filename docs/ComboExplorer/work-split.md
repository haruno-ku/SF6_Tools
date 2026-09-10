# 作業分割 — 実機なしで進める範囲 / 実機待ちで止める範囲

**状況**: SF6 を動かすゲーミング PC がまだ無い。開発 PC には Steam も SF6 も REFramework も無い。

**原則**: **実機でしか確かめられない値を「仮に決めて」先へ進めない。**
未確定のものは値を持たせず、`unverified` 状態として明示的に保留し、
実機導入後にキャリブレーション結果で確定させる。

---

## 進捗（このドキュメント作成後）

| 項目 | 状態 |
|---|---|
| A0 未検証値レジストリ `core/Provenance.lua` | **完了** — 10項目、能力ゲート、キャリブレーション適用 |
| A1 現ビルドのレビューと修正 | **完了** — 5観点 × 敵対的検証。確認された欠陥はすべて修正 |
| A2 実機依存 / 非依存の分離 | **完了** — `core/` は純粋、`runtime/GameAdapter.lua` が `sdk` に触れる唯一のファイル |
| A3 raw JSON loader / slim map 回帰 / 分類 / canonical・variant / Catalog | **完了** — `core/Catalog.lua` |
| A5 `LinkVerdict`（combo count 増加で判定） | **完了** — `core/LinkVerdict.lua` |
| A4 Schema 固定 | 未着手 |
| A5 `StageControlFsm` / `RunnerFsm` / `SequenceCompiler` | 未着手 |
| A6 `ResultCollector` / `GraphStore` / `RouteSearch` / `Scoring` / `Exporter` / KDB adapter | 未着手 |
| A7 Calibration 手順・injection smoke test の確定 | 未着手 |

テスト: **554 アサーション**（Lua 5.4.6、SF6 不要）。

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
