# 次に実機が使えるときの手順

ゲーミング PC が使えるときに、**上から順に**やれば良いようにしたもの。
どれも「1回やれば、開発機側の詰まりが1つ外れる」作業です。所要時間は目安。

準備は全部できています（2026-09-16 時点）。当日に開発機で作るものはありません。

---

## 0. 持っていくもの（開発機で1回）

```
pwsh scripts/install-dev.ps1        # reframework/ をゲームフォルダへ同期
```

同期されるもの（すでにコミット済み）:

| | |
|---|---|
| ワークリスト | `worklist/ryu-modern*.json`（本体・DRC・プラン6本）、`zangief-modern*.json`、他29キャラ |
| ルート実走ファイル | `route/ryu-modern-{easy-damage,hit-confirm,no-gauge-3}-{1,2,3}.json` と Zangief の9本 |
| Lua 一式 | 掃引・キャリブレーション・パネル |

---

## 1. 動くことの確認（5分）

1. SF6 を起動 → REFramework の Script Errors が空
2. パネル → LIVE READOUT が全行動く
3. パネル → SWEEP → worklist のドロップダウンに Ryu のプランが並ぶ

**ここで止まったら、以降は全部やらない。**

---

## 2. Ryu のキャリブレーション（15分）🔴 これが無いと Ryu は掃引できない

いまの校正は **Zangief で測ったもの**です（`calibration/latest.json` の
`action_id_canonical` が `manual|2 + 弱` のような Zangief の表記で入っている）。
ボタンのビットと方向は共通ですが、**「どの表記がどの action_id を出すか」はキャラごと**なので、
Ryu で1回測り直します。

1. トレーニングで Ryu を選ぶ（操作方法は **モダン**）
2. パネル → CALIBRATION → キャラが Ryu になっていることを確認 → 実行
3. 終わったら WRITE PROFILE

**得られるもの:** Ryu の canonical マップ。これが無いまま掃引すると、#44 と同じ
「別の id が出た」で大量に未回答になります。

---

## 3. Ryu の練習プランを掃引（各5〜10分）

パネル → SWEEP → ドロップダウンから選ぶ → START SWEEP。3つとも回して構いません。

| プラン | ペア | 何が分かるか |
|---|---:|---|
| `ryu-modern-plan-easy-damage` | 22 | 入力が軽くてダメージが出るルートの繋ぎ |
| `ryu-modern-plan-hit-confirm` | 19 | 弱・中始動からのヒット確認ルート |
| `ryu-modern-plan-no-gauge-3` | 25 | ノーゲージ3段 |

キャンセルのペアは隙間を数点試すので、1ペアあたり数試行です（22ペアで5分前後）。
**放置して構いません。** 途中で止めても、次回は答え済みのペアを飛ばして再開します。

---

## 4. Ryu のルート実走（10分）🔴 これがダメージの出どころ

パネル → ROUTE RUN → ドロップダウンから `ryu-modern-easy-damage-1` などを選ぶ → 実行。9本あります。

**得られるもの:** `evidence.damage`（実測ダメージ）と `evidence.gauges`。
公開用の記録（`ce.verified_combo.v1`）は実測ダメージが無いと作れないので、
**ここを通さないと「サイトに載せる」まで進みません**（#51）。

---

## 5. クラシックのボタンビット（10分）

1. トレーニングの操作タイプを **クラシック** にする
2. パネル → CALIBRATION → `[x] classic` を押す（既定は modern）。両方の scheme の
   現在のビットが並んで表示され、ゲーム側の設定と食い違っていれば赤字で出ます
3. パッドから手を離して START SWEEP → 放置

ボタンの推測値を持たないので、全ビットを1つずつ押して確かめます（12ステップ）。
書き込み先は `calibration/latest-classic.json` で、**モダンの校正には触りません**。

**得られるもの:** LP/MP/HP/LK/MK/HK の6ビット。これが入ると
`explore.lua --scheme classic` の出力が掃引できるようになり、
「Ryu はクラシックとモダンどちらが練習しやすいか」を実測で比べられます。
いまはクラシックのペアは全部「押せない」として除外されています。

---

## 6. DRC を測る（15分、#50）

1. 2中P → DRC を手で出し、LIVE READOUT で action id の並びを見る（500 / 501 / 504 のどれか）
2. その最中に `combo_count` が 0 を挟むか見る
3. モダンのパリィボタン（DP）のビットを PAD WATCH で目撃する

**得られるもの:** DRC 候補 145件（Zangief）/ 全キャラ 12,337件 が掃引可能になります。

---

## 7. 時間が余ったら: Zangief の取り直し（30分）

`zangief-modern.json`（159ペア）をもう一度。前回のログには
**タイミングが間違っていた試行**（キャンセル専用のペアをリンクの間合いで押した 74ペア分）が
入っていて、いまはそれらを「答えになっていない」として扱っています。
取り直すと、その 74ペアに本当の答えが付きます。

---

## 8. 帰ってきたら（開発機）

```
# 1. ログをコミット（reframework/data/ComboExplorer_data/trials/ と calibration/）
# 2. 集計とページを作り直す
lua tools/lua/all.lua

# 3. lab DB へ入れる（評価も一緒に入る）
npm run lab:sql
set -a; . ../sf6-knowledge-db/.env; set +a
npm run lab:apply -- --dry-run
npm run lab:apply

# 4. 公開できるものが出たか見る
lua tools/lua/publish.lua --character Ryu
```

`publish.lua` が「実測ダメージが無い」以外の理由だけを並べるようになったら、
残りは技スラッグの対応表（#17）と release の形（#38 §9）だけです。

---

## やらないこと

- **ゲージのピン留めをしたままダメージを測らない。** ピン中は消費が測れません（#50 の 5）
- **溜め技・`22` 系・投げを2手目に置いたペアを手で試さない。** 掃引側で除外済みです
- **`wsl --shutdown` はこの PC では runner が止まります**（容量整理の話。実機作業とは無関係）
