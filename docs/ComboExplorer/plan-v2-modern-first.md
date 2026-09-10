# SF6 Combo Explorer — セットアップ〜コンボ自動探索・作成 実装計画

更新日: 2026-09-10  
対象: Street Fighter 6 / Windows / REFramework / SF6_Tools  
実装担当: Claude Code を前提  
初期対象: **Modern中心**  
MVP対象キャラ: **Zangief / Modern**  
次点対象: Mai / Modern など、Modernで実戦運用したいキャラ  
初期対象バージョン: 2026-08-03 バランスパッチ基準

---

## 0. この計画の結論

`sf6-knowledge-db` とは **別Gitプロジェクト** にする。

最初はゼロから新規作成せず、以下を採用する。

- Upstream: `Wael3rd/SF6_Tools`
- 自分のGitHubアカウントへ **Fork**
- Forkしたリポジトリ内に `ComboExplorer` 機能を追加
- `SF6_Tools` を「SF6内部への入力・状態取得・実測・リプレイエンジン」として利用
- フレームデータは外部の構造化データを候補生成に利用
- 最終的な「繋がる / 繋がらない」「実ダメージ」は **SF6本体を正** とする
- 完成した結果だけを JSON/YAML で `sf6-knowledge-db` に渡す

サイト本体と探索機は直接結合しない。

```text
sf6-combo-explorer
        |
        | verified JSON / YAML
        v
sf6-knowledge-db
```

こうすることで、SF6側のMOD・REFramework更新でサイト本体が巻き込まれない。

---

# 1. Git / Repository 方針

## 1.1 推奨構成

### Repo A: 既存

```text
sf6-knowledge-db
```

役割:

- Webサイト
- コンボ・起き攻め・状況判断DB
- 公開API
- 動画
- ユーザー向けUI

### Repo B: 新規

最初は GitHub で以下を Fork する。

```text
https://github.com/Wael3rd/SF6_Tools
```

Fork後、ローカルでは分かりやすく:

```text
D:\main\sf6-combo-explorer
```

としてCloneする。

GitHub上のFork名は最初は `SF6_Tools` のままでよい。必要なら後で `sf6-combo-explorer` にRenameする。

---

## 1.2 Forkを使う理由

SF6_Toolsには既に以下がある。

- REFramework連携
- SF6内部状態取得
- Input Injection
- Raw Input Replay
- Input Sequencer
- Combo Trial
- Combo Counter取得
- 実ダメージ取得
- キャラクターAction ID
- Classic / Modern notation
- Modern control / simple input / assist系表示
- キャラクター固有リソース対応
- Training Mode限定のRuntimeSafety

これを新規C#アプリから再実装するメリットは薄い。

Forkにすれば upstream の修正も取り込める。

---

## 1.3 Git branch運用

初期:

```text
upstream/main
    |
    +-- 自分の main
          |
          +-- feat/combo-explorer
```

ルール:

- `main` はなるべく upstream に近い状態を維持
- 独自実装は `feat/combo-explorer`
- 安定後 `main` にmergeしてもよい
- 大規模な独自化はMVP成功後に判断

Upstream同期:

```bash
git fetch upstream
git checkout main
git merge upstream/main
git push origin main

git checkout feat/combo-explorer
git merge main
```

最初はrebaseよりmergeでよい。履歴の綺麗さより事故防止優先。

---

# 2. 初回セットアップ

## 2.1 必要環境

必須:

- Street Fighter 6 Steam版
- Git
- GitHubアカウント
- Claude Code
- PowerShell
- Node.js 20+ または 22+ 推奨
- pnpm または npm
- SF6_Toolsが要求するREFramework環境

---

## 2.2 Fork

GitHubで:

```text
Wael3rd/SF6_Tools
↓
Fork
↓
自分のアカウント
```

---

## 2.3 Clone

例:

```bash
cd /d D:\main

git clone git@github.com:<YOUR_GITHUB_ID>/SF6_Tools.git sf6-combo-explorer

cd sf6-combo-explorer
```

SSH未設定ならHTTPSでもよい。

---

## 2.4 upstream追加

```bash
git remote add upstream https://github.com/Wael3rd/SF6_Tools.git
git remote -v
```

期待:

```text
origin    自分のFork
upstream  Wael3rd/SF6_Tools
```

---

## 2.5 開発branch

```bash
git checkout -b feat/combo-explorer
git push -u origin feat/combo-explorer
```

---

# 3. SF6への開発版導入

## 3.1 最初に「無改造版」を動かす

Combo Explorerを触る前に必ず以下を確認する。

- SF6起動
- REFramework menu表示
- Training Script Manager表示
- Combo Trials起動
- Recording Slot Manager起動
- Zangief選択
- コンボ録画
- Demo再生
- JSON保存
- Game crash / FPS問題が許容範囲

これが動かない状態でCombo Explorerを作らない。

---

## 3.2 開発版の同期スクリプト

作成:

```text
scripts/install-dev.ps1
```

目的:

```text
repo/reframework
    ↓ sync
Steam/Street Fighter 6/reframework
```

要件:

- `reframework/autorun`
- `reframework/data` の静的定義
- 必要なplugin

を同期。

ただしユーザー生成データを不用意に消さない。

除外候補:

```text
CustomCombos
Stats
user config
recordings
```

`dinput8.dll` は初回のみセットアップ対象。毎回上書きしない。

---

# 4. 外部フレームデータ

## 4.1 第一候補

探索候補の絞り込みには構造化済みのフレームデータを使う。

候補:

```text
RyoSogawa/sf6-sensei
```

2026-08-03パッチのフレームデータを構造化しているため、MVPのパッチ基準と一致しやすい。Modernで使える技の絞り込みはSF6_Tools側のcommand_display / control_supportを併用する。

用途:

- startup
- active
- recovery
- hit advantage
- block advantage
- damage
- cancel属性
- move category

ただし、これを「最終真偽」には使わない。

---

## 4.2 外部データの扱い

直接コードへコピペしない。

以下を作る。

```text
tools/fetch-frame-data.ts
```

出力:

```text
external-data/
  sf6-sensei/
    mai.json
    source.json
```

`source.json`:

```json
{
  "repository": "RyoSogawa/sf6-sensei",
  "commit": "<PINNED_SHA>",
  "gamePatch": "2026-08-03",
  "fetchedAt": "ISO8601",
  "licenseNote": "retain upstream attribution"
}
```

重要:

- 必ずCommit SHAをpinする
- 更新時に差分が分かるようにする
- データライセンスと帰属表示を残す
- Knowledge DBへ外部データを丸ごと再配布しない

---

# 5. Combo Explorer アーキテクチャ

追加予定:

```text
reframework/
  autorun/
    ComboExplorer.lua

  autorun/func/
    ComboExplorer/
      Config.lua
      MoveCatalog.lua
      CandidateGenerator.lua
      SequenceCompiler.lua
      Runner.lua
      ResultCollector.lua
      GraphStore.lua
      RouteSearch.lua
      Scoring.lua
      Exporter.lua
```

後半:

```text
      OkiAnalyzer.lua
      WakeupTester.lua
      ModernRouteResolver.lua
```

---

# 6. 既存SF6_Toolsから再利用するもの

優先的に再利用:

- `RuntimeSafety.lua`
- `GameState.lua`
- `SharedHooks.lua`
- `SF6_RecordingSlotManager.lua`
- `TrainingComboTrials_v1.0.lua`
- Combo Trial validation modules
- command_display
- ModernDisplay
- ModernDisplay / command_display / control_support
- キャラクター固有resource定義
- Combo damage取得ロジック

原則:

**最初から既存コードを大規模リファクタしない。**

まずMVPを通す。

必要になったらInput Sequencerの共通部分を:

```text
func/InputSequencerCore.lua
```

として切り出す。

---

# 7. Phase 1 — Move Catalog

最初の対象:

```text
Zangief
Modern
地上
Normal Hit
Midscreen
```

設計自体はModern-first・multi-characterとする。MVPでZangiefを縦に通した後、Maiなどへ横展開する。

Move Catalogを統合する。

入力元:

```text
SF6_Tools command_display
+
external frame data
```

内部形:

```json
{
  "key": "5MP",
  "actionId": 123,
  "startup": 6,
  "onHit": 4,
  "damage": 600,
  "cancel": ["special", "super", "drive_rush"],
  "controlSupport": ["modern"],
  "inputMethod": "simple",
  "command": "5M",
  "classicEquivalent": "5MP",
  "category": "normal"
}
```

実値はデータから取得すること。この例の数値を本番データとして使用しない。

---

# 8. Phase 2 — 理論候補生成

## 8.0 Modern候補フィルタ

Candidate Generatorは最初に現在の操作方式で実行可能な技だけへ絞る。

Modernでは以下を区別する。

```text
manual   : 方向 + L/M/H等で直接出す通常技・コマンド技
simple   : SP等の簡易入力
assist   : Assistを伴う派生 / アシストコンボ系
hybrid   : 同じ技をmanual/simpleのどちらでも出せる場合
```

探索Routeは「技名」だけでなく **入力方法** まで保持する。

例:

```json
{
  "move": "SPD",
  "inputMethod": "simple",
  "control": "modern"
}
```

同一技でもmanual版とsimple版で実測ダメージ・成立条件が異なる可能性があるため、
Explorer側で別Routeとして扱い、ダメージ補正値を決め打ちしない。
最終DamageはSF6本体の実測値を採用する。

---

## 8.1 Ground Link

基本候補:

```text
A hit advantage >= B startup
```

ただしあくまで候補。

結果:

```json
{
  "from": "5MP",
  "to": "2LP",
  "type": "link",
  "theoretical": true
}
```

---

## 8.2 Cancel

Aのcancel属性を使う。

例:

```text
Normal
  → Special
  → Super
  → Drive Rush Cancel
```

「キャンセル可能だから必ずその必殺技へ繋がる」とは判定しない。候補だけ生成する。

---

## 8.3 初期除外

MVPでは除外:

- Throw
- Taunt
- Jump-only
- Air-only
- install特殊遷移
- command grab
- projectile追跡が複雑なもの
- Juggle専用
- stance分岐
- charge複雑系

後で追加。

---

# 9. Phase 3 — A → B 自動接続テスト

ここがMVPの核。

## 9.1 Test Case

```json
{
  "from": "5MP",
  "to": "2MP",
  "condition": {
    "control": "modern",
    "counter": "normal",
    "position": "midscreen"
  }
}
```

---

## 9.2 実行

```text
Reset
↓
位置固定
↓
リソース固定
↓
A入力
↓
B入力
↓
Combo Counter確認
↓
Result保存
```

成功条件:

- AがHit
- BがHit
- Combo Counterが継続
- Action IDが期待値に近い
- RuntimeSafetyがTraining Modeを許可している

---

## 9.3 タイミング探索

固定delay一本にしない。

候補window:

```text
0F
1F
2F
...
N F
```

を試す。または理論値から狭いwindowを決める。

記録:

```json
{
  "from": "5MP",
  "to": "2MP",
  "success": true,
  "successDelays": [3, 4, 5],
  "timingWindow": 3
}
```

この `timingWindow` が難易度判定に使える。

---

## 9.4 再試行

最低3回、同条件で試す。

```json
{
  "attempts": 3,
  "successes": 3,
  "stable": true
}
```

1/3しか通らないなら不安定として扱う。

---

# 10. Phase 4 — Confirmed Edge Graph

成功したA→Bだけ保存。

```text
5MP
 ├─ 2LP
 ├─ 2MP
 └─ 236LP
```

保存:

```text
reframework/data/ComboExplorer/results/
  Zangief/
    2026-08-03/
      modern/
        midscreen-normal.json
```

Edge:

```json
{
  "from": "5MP",
  "to": "2MP",
  "type": "link",
  "verified": true,
  "timingWindow": 3,
  "attempts": 3,
  "successes": 3
}
```

---

# 11. Phase 5 — Route Generator

Confirmed EdgeのみでDFS/BFSする。

制約:

- 最大step数
- Drive上限
- SA上限
- 同一loop禁止
- 同じAction連打制限
- combo終了を検出
- 明らかな無限探索防止

例:

```text
5MP
→ 2MP
→ Special
→ SA
```

---

# 12. Phase 6 — 完成Comboの実測

ルート候補ごとに通しで再実行。

2技Edgeが全部成功していても、長いCombo全体が成立するとは限らない。必ず最終実機検証する。

取得:

```json
{
  "combo": ["5MP", "2MP", "236HP"],
  "verified": true,
  "damage": 2780,
  "driveUsed": 0,
  "superUsed": 0,
  "timing": {},
  "gamePatch": "2026-08-03"
}
```

DamageはSF6内部の実測値を優先。

---

# 13. Phase 7 — 「簡単 × 高火力」ランキング

AIへ丸投げしない。まず数値化する。

## 13.1 Difficulty

候補:

- step数
- command数
- motion command数
- charge有無
- Drive Rush回数
- manual delay有無
- side switch
- micro walk
- timing windowの狭さ
- exact-frame入力要求
- Modern simple / manual / assist入力の使い分け
- 同一技のsimple/manual差
- Assistを押し続ける必要がある区間

特に `timingWindow` は実測値なので強い。

例:

```text
5F window = easy
3F = medium
1F = hard
```

閾値は後で調整。

---

## 13.2 Value

単純な一つの点数だけにしない。

複数ランキング:

```text
Max Damage
Easy
Easy + High Damage
Zero Drive
Zero SA
Drive Efficiency
Beginner
```

Pareto frontierも使う。

---

# 14. Phase 8 — AI選別

AIが見るのは **検証済みJSONだけ**。

AIの役割:

- Beginner向け候補選定
- 実戦用途の分類
- 類似コンボの重複除去
- 人間向け説明生成
- Knowledge DB用metadata案生成

AIにやらせないもの:

- コンボ成立判定
- Damageの推測
- Frame値の推測
- ゲージ消費の推測

---

# 15. Phase 9 — Result State / Oki計測

Combo終了後に追加で測る。

```text
Knockdown?
KD Advantage
Distance
Corner distance
Side
Corner carry
Resource delta
```

例:

```json
{
  "result": {
    "knockdown": true,
    "advantage": 38,
    "distance": 1.42,
    "cornerCarry": 3.8,
    "sideSwitch": false,
    "flameStockDelta": 1
  }
}
```

---

# 16. Phase 10 — Oki Explorer

Combo後の状況から候補行動を生成。

例:

```text
forward dash
walk
throw
5LP
5MP
2MP
jump
neutral jump
shimmy movement
```

## 16.1 Dummy Wakeup Test

相手側Recording Slotに:

```text
4F mash
throw
jump
back walk
block
parry
DI
OD reversal
```

などを設定。

Oki Candidateを実行し:

```text
beats
loses_to
trades
whiffs
```

を記録。

## 16.2 Safe Jump

判定条件:

- jump attackが起き上がりに重なる
- 無敵reversal時には着地ガード可能

SF6実機で判定。

---

# 17. Phase 11 — Knowledge DB Export

Explorer → Knowledge DB変換。

出力:

```text
exports/
  mai/
    combos.yaml
    knowledge-nodes.yaml
    knowledge-edges.yaml
```

Combo例:

```yaml
- slug: ...
  control_scheme: classic
  damage: 2870
  difficulty_score: 12
  requirements:
    drive: 3
  outcomes:
    knockdown_advantage: 38
    flame_stock_delta: 1
```

最終的には既存Knowledge DB Schemaに合わせて変換する。

Explorer側の内部JSONをKnowledge DBの永続Schemaに直接しない。Adapterを挟む。

---

# 18. 動画作成

検証済みComboに対して:

```text
Replay
↓
OBS / capture
↓
trim
↓
WebM
↓
Knowledge DB media
```

MVPでは録画自動化しない。

最初は:

```text
[Replay Selected Combo]
```

まで。

動画切り抜き自動化は後。

---

# 19. パッチ更新

理想フロー:

```text
SF6 patch
↓
External frame data refresh
↓
Old edge graph re-test
↓
Broken edges検出
↓
Affected routes抽出
↓
Re-run
↓
Knowledge DB更新候補
```

比較結果:

```json
{
  "brokenEdges": 12,
  "newEdges": 7,
  "affectedCombos": 23
}
```

---

# 20. Safety

必須。

既存 `RuntimeSafety.lua` を必ず利用する。

Combo Explorerは:

```text
Training Mode
```

以外ではInput Injection禁止。

追加で:

```text
ComboExplorer.enabled == true
AND RuntimeSafety.can_inject_input() == true
```

を満たさなければ実行しない。

オンライン対戦・Custom Room・Online Training等では動作させない。

---

# 21. 初期MVPのScope

最初から全部やらない。

## MVP 0

目的:

**Modern ZangiefのA→B接続表を自動生成する。**

条件:

```text
Zangief
Modern
Midscreen
Normal Hit
Ground
10 moves前後
```

最初からModernで実際に使用可能な技だけを対象にする。
Classic専用技は候補生成段階で除外する。
simple / manual / assist は別入力Routeとして保持する。

完成条件:

1. Move Catalog生成
2. theoretical pairs生成
3. P1へ自動入力
4. 100ペア以内を自動テスト
5. Combo Counterで成功判定
6. `confirmed_edges.json`保存
7. UI/ログから進捗確認

ここが成功したら次へ。

## MVP 1

- 全地上技
- Normal Hit
- link
- cancel
- Damage取得
- Route Generator
- 完成combo通し検証

## MVP 2

- 2人目以降のModernキャラ（Maiなど）
- CH
- PC
- Drive Rush
- SA

## MVP 3

- Juggle
- Corner
- Projectile
- Flame stock

## MVP 4

- KD advantage
- distance
- corner carry
- oki candidate
- wakeup test
- safe jump

---

# 22. Claude Code 実装ルール

Claude Codeには以下を厳守させる。

1. 既存SF6_Toolsの動作を壊さない
2. 最初に既存実装を読む
3. Input Injectionを新規にゼロから書かない
4. RuntimeSafetyを必ず通す
5. 大規模refactorをMVP前にしない
6. まずModern Zangiefのみで縦に完成させる
7. 外部フレーム値は推測しない
8. サンプル数値を実データ扱いしない
9. すべての結果にgame patch/sourceを持たせる
10. 自動探索結果はSF6実機検証済み/未検証を明確に分ける
11. 1コミット1目的
12. 各Phaseで動作確認手順をREADMEへ追記

---

# 23. Claude Codeへの最初の指示

以下をそのまま渡す。

```text
このリポジトリは Wael3rd/SF6_Tools のForkです。

添付の「SF6 Combo Explorer — セットアップ〜コンボ自動探索・作成 実装計画」を唯一の実装計画として扱ってください。

まず実装を始める前に、以下を行ってください。

1. SF6_Toolsの既存構造を調査する
2. Recording Slot Manager の Input Sequencer がどのようにP1/P2 inputを注入しているか確認する
3. TrainingComboTrials の raw_inputs / timeline replay の仕組みを確認する
4. RuntimeSafety の制約を確認する
5. Combo Counter / mComboDamage の取得箇所を確認する
6. Zangief の command_display と Modern入力対応を確認する
7. ModernDisplay / control_support / simple・manual・assist入力の扱いを確認する
8. MVP 0に必要な最小変更案を出す

重要:
- まだ大規模refactorしない
- 既存コードを壊さない
- Input Injectionを別方式で再実装しない
- Training Mode以外への入力注入を絶対に許可しない
- サンプルのフレーム値やAction IDを本番データとして使わない
- まず「Zangief / Modern / Ground / Normal Hit / 約10 moves」のA→B自動接続テストを完成させる
- Classic専用技をModern探索に混ぜない
- 同一技でもsimple/manual/assist入力を別Routeとして扱える設計にする
- 最初の返答ではコードを書き始めず、調査結果・変更予定ファイル・MVP 0の具体的実装順・リスクを提示する

調査後、私の承認を待ってから実装を開始してください。
```

---

# 24. 最終完成イメージ

```text
       External Frame Data
                |
                v
        Candidate Generator
                |
                v
     +----------------------+
     |   Combo Explorer     |
     +----------------------+
                |
        SF6_Tools Engine
                |
                v
       Street Fighter 6
                |
      +---------+---------+
      |                   |
Combo Counter          Game State
Damage                 KD / distance
      |                   |
      +---------+---------+
                |
                v
       Verified Graph
                |
         Route Search
                |
     +----------+----------+
     |                     |
Easy+Damage            Oki Search
     |                     |
     +----------+----------+
                |
                v
          AI Selection
                |
                v
       Knowledge DB Export
                |
                v
        sf6-knowledge-db
```

---

# 25. Done Definition

最終的に以下ができれば完成。

```text
「Zangief / Modern / 任意の始動 / Drive 3以下 / SAなし / 中央」
```

と条件を指定すると:

```text
1. 候補を理論生成
2. SF6で自動検証
3. Damage取得
4. Difficulty評価
5. Combo結果状況取得
6. Oki候補検証
7. おすすめ順にランキング
8. Replay
9. Knowledge DB用YAML出力
```

まで一連で動く。

最重要原則:

**理論データは候補生成に使い、SF6本体を最終判定機にする。**

---

# 26. 参照元

- SF6_Tools: https://github.com/Wael3rd/SF6_Tools
- SF6_Tools Combo JSON Spec: https://github.com/Wael3rd/SF6_Tools/blob/main/docs/COMBO_JSON_SPEC.md
- sf6-sensei: https://github.com/RyoSogawa/sf6-sensei

MITライセンス、外部データのライセンス、帰属表示は実装時に各Upstreamの現行ファイルを再確認すること。
