# SF6 Combo Explorer — 実装計画 v3（上流ソース実地調査 反映版）

## Context

`SF6_Combo_Explorer_implementation_plan_v2_modern_first.md` を唯一の実装計画として、
Wael3rd/SF6_Tools を Fork し、**SF6本体を最終判定機**として Modern Zangief のコンボを自動探索する。

本計画は v2 の置き換えではなく、**上流ソース（pin `0bd1c53`）を実際に読んで判明した事実で v2 を具体化・修正したもの**。
v2 の原則（理論データは候補生成、SF6 本体が真偽を決める / Modern-first / MVP を縦に通す）はそのまま維持する。

v2 からの実質的な変更は 4 点:

1. **入力注入は新規実装しない。** 既存の `nBattle.cPlayer::pl_input_sub` フックに
   コールバックを 1 本足し、P1 の `pl_input_new` / `pl_sw_new` に uint16 マスクを書くだけ。
   これで **エンジンフレーム基準の 1F 粒度**が得られる（実際に成立するかは Phase 1 で実機確認、§1.1）。
2. **Modern のボタンビット割り当てが既にソース内に判明していた。** ただし「表示コードにのみ存在し、
   注入には誰も使っていない」ので、実機キャリブレーションで裏を取ってから使う（§1.2）。
3. **Move Catalog は実機キャリブレーション優先**（ユーザー決定）。
   リポジトリ同梱の `command_display/Zangief.json` を候補源にし、実測で確定させる。
   sf6-sensei はクリティカルパスから外し、後段（delay window の絞り込み）で使う。
4. **開発機と実行機が分かれる**（ユーザー決定）。この PC には Steam/SF6/REFramework が無い。
   コードはここで書いて Git へ push、別のゲーミング PC でセットアップして実行、結果を Git で持ち帰る。

> **調査の注意**: 本計画の記述は upstream `0bd1c53` の実ファイルに基づく。
> 実装開始時は Fork/Clone した実物で行番号を再確認すること（行番号は目安）。

### 承認時の指摘（反映済み）

| # | 指摘 | 反映先 |
|---|---|---|
| 1 | `placeholder` 廃止済み。source は 5 種類。未検証は export しない | §1.7 / Phase 11 / ルール 10 |
| 2 | target combo / follow-up 等の context-dependent Action を MVP 0 から除外 | §1.6 / Phase 2 |
| 3 | link 成立を `combo_cnt 1→2` ではなく **B による combo count 増加**へ一般化 | Phase 3 |
| 4 | 「1F 精度」→ **engine frame 基準の 1F 粒度**として実機確認 | §1.1 / Phase 1-5 |
| 5 | KD advantage は `StunFrame` と直接 actionable 計測をクロスチェック | §1.3b / Phase 9 |
| 6 | `timingWindow` 単体を difficulty にせず **execution leniency** として保持 | Phase 3 / Phase 8 |
| 7 | KO/round フックは既存のライフサイクルを確認し**二重登録しない** | §1.4 / ルール 12 |

---

## 1. 調査で確定した事実

### 1.1 入力注入 — 既存機構をそのまま使う

`reframework/autorun/func/SharedHooks.lua`

- `nBattle.cPlayer::pl_input_sub` を `sdk.hook` 済み（SharedHooks:293-341）。フックはここ 1 箇所だけ。
- 新規スクリプトは `table.insert(_G._shared_input_post, function(p_id, retval) ... end)` で参加する。
  `p_id`: 0=P1 / 1=P2 / -1=不明。**自分で `pl_input_sub` をフックし直さない。**
- pre/post どちらのディスパッチも `RuntimeSafety.can_inject_input()` の内側にある（:321, :332）。
- **1 コールバック = `pl_input_sub` の 1 呼び出し = エンジンフレーム 1 ティック**。
  つまり得られるのは「**エンジンフレーム基準の 1F 粒度**」であって、
  「入力が必ず 1F ズレずに届く」という保証ではない。
  実際に 1F 刻みで意味のある差が出るかは **Phase 1 で実機確認する**
  （同じ delay を繰り返して出る action_id / `get_ActionFrame()` が安定するかを測る）。
  ヒットストップ・ポーズ・`_IsReqRefresh` 中はティックが進まないので、
  掃引の delay は**実フレーム数ではなくエンジンティック数**で数える。

P1 への書き込み実例（`TrainingComboTrials_v1.0.lua` DEMO、:6875-6908）:

```lua
local p1 = GS.p1
local mask = demo_state.raw_buffer[idx]   -- uint16
p1:set_field("pl_input_new", mask)
p1:set_field("pl_sw_new", mask)           -- ★ 両方に書く
```

**OR ではなく SET する。** `TrainingMoveExecution.lua:307-308` と RSM は生パッドの値に OR しているため、
コントローラーに触れると入力が混ざる。総当たり実行では SET（または `_ct_clear_inputs` パターンで 0 クリア後に OR）。

方向ビット（`ComboTrials_D2D.lua:288-297` の `raw_get_numpad` と `SEQ_NUMPAD_DIR` が一致）:

| numpad | 5 | 8 | 2 | 4 | 6 | 7 | 1 | 9 | 3 |
|---|---|---|---|---|---|---|---|---|---|
| mask | 0 | 1 | 2 | 4 | 8 | 5 | 6 | 9 | 10 |

`UP=1, DOWN=2, LEFT=4, RIGHT=8`。
※ RSM の `MASKS = {UP=1,DOWN=2,RIGHT=4,LEFT=8}`（:450、スロット timeline の encode/decode 用）だけが
**逆**。3 対 1 で上表が正。Explorer は slot timeline を使わないので上表を採用し、キャリブレーションで確認する。

向き補正: 3 箇所（RSM:1993 / TrainingMoveExecution:299 / ComboTrials:6843）は
`if not p:get_field("rl_dir") then` = **falsy のとき bit4↔bit8 を入れ替え**。
`SharedHooks.write_p2_input_mask`(:179-186) だけ truthy で入れ替え（P2 用）。
P1 は 3 箇所に合わせ、キャリブレーションで両サイド確認する。

シーケンス組み立ての雛形（`TrainingMoveExecution.lua:274-284` `build_inject_seq`）:
`{f=3,m=0}` → 方向 1 桁ずつ 1F → 最終桁は 3F 保持しつつボタン OR → `{f=5,m=0}`。

### 1.2 Modern のボタンビット（重要・要実測確認）

`ComboTrials_D2D.lua:299-321`（コメントに "probed in-game" とある）:

| bit | Classic | Modern |
|---|---|---|
| 0x10 (16) | LP | **L** |
| 0x20 (32) | MP | **SP** |
| 0x40 (64) | HP | Drive Parry（`0x40\|0x04` = Drive Rush） |
| 0x80 (128) | LK | **M** |
| 0x100 (256) | MK | **H** |
| 0x200 (512) | HK | **Assist (AUTO)** |
| 0x1000 (4096) | — | Drive Impact |
| 0x2000 (8192) | — | Throw |

**この表はソース中で「表示のためだけ」に使われており、注入に使った実績が無い**（recon 確認済み）。
ただし `command_display/Zangief.json` の `routes[].raw_button_mask` が完全に一致する:
弱=16 / 中=128 / 强=256 / SP=32 / 中+强=384 / 弱+中+强=400 / THROW=144(=16|128)。
→ **`raw_button_mask` はそのまま `pl_input_new` のボタンマスクとして使える公算が高い。**
DI(576) と AUTO+SP(8192) は一致しないので、この 2 つは実測で確定させる。

Modern 判定: `TrainingManager._tData.SelectMenu.PlayerDatas[idx].InputType == 1`（`ComboTrials_D2D.lua:339-352`）。

### 1.3 計測 — 必要な値はすべて読める

`nBattle.cPlayer`（= `GS.p1` / `GS.p2` = `gBattle.Player.mcPlayer[0|1]`）のフィールド:

| 値 | アクセス |
|---|---|
| コンボヒット数 | `combo_cnt`（攻撃側）— ComboTrials:1140-1147 |
| 実コンボダメージ | `p.mpTeam.mComboDamage` — ComboTrials:4222-4239 |
| 現在 Action ID | `p.mpActParam.ActionPart._Engine:call("get_ActionID")` / `get_ActionFrame()` |
| Action State | `act_st`（`_G.GameState.p1_act_st`）— ActionID とは別物 |
| HP | `vital_new` / `vital_old` / `heal_new` |
| Drive | `focus_new`（表示値 = raw/10000） |
| SA | `gBattle.Team.mcTeam[idx].mSuperGauge` |
| ガード数（ブロック判定） | `gard_combo_cnt`（fallback `dgard_combo_cnt`） |
| CH / PC | `counter_dm_flag`（CH） / `counter_fw_flag`（PC） |
| ヒットストップ | `hit_stop` |
| 位置 | `p.pos.x.v / 6553600.0`（メートル） |
| 向き | `rl_dir`（true = 右向き） |

**ダメージは `mComboDamage` を採る。** HP デルタは致死でカットされるが `mComboDamage` はされない。
ただしコンボ間で 0 に戻るので、**カウンタが 0 に落ちた時点でピークを積み立てて合算する**（ComboTrials:4217-4239 と同じ）。

**ヒット / ブロック / 空振りの識別**: ステップ中に `victim.gard_combo_cnt` が上がったら **ブロック**、
`combo_cnt` が上がったら **ヒット**、どちらも動かなければ **空振り**（ComboTrials:4201-4215）。

`nBattle.ACT_ID` の静的フィールドを走査すると action_id → エンジン内部名（例 `DGD_STAND_H_DM_M`）の
逆引きが作れる（ComboTrials:705-713）。カタログに無い action_id のラベル付けに使える。

**技の終了判定**: `p1_act_st == 0` が 3 フレーム連続、または `MeatyFrame > 0`
（`TrainingMoveExecution.lua:506-511`）。1 試行の完了シグナルとしてそのまま使える。

**`hit_stop` の間は自前のフレームカウンタを止める**（`TrainingMoveExecution.lua:459-462, 550`）。
これを忘れるとヒットストップ分だけ全計測がずれる。

**最大HP** は `vital_max`（ComboTrials:1569-1580）。ダメージの%表記に使える。

### 1.3b フレームデータは実測できる（v2 §4 の前提を大きく改善）

`TrainingHitConfirm_v1.0.lua` に 2 つの経路がある。

1. **ゲーム内蔵の有利フレーム値をそのまま読む**:
   `_hc_read_frame_adv`（:453-481） = `FrameMeterSSData.MeterDatas:get_Item(0).StunFrame`。
   → 安価だが **ゲームが表示用に計算した値**。KD 後の有利フレームと一致する保証は無い。
   **Phase 9 の最初に経路 2 の直接計測とクロスチェックしてから採用する。**
2. **フレームメーターの生ストリーム**: `FrameNumDatas` リングバッファ（`update_detection`, :502-560）が
   両プレイヤー分の毎フレーム `FrameType` を返す。
   `7 = startup / 8 = recovery / 9 = hitstun / 10 = blockstun`。
   → **startup / active / recovery / 有利フレームを自前で実測できる。**

つまり **フレームデータも「SF6 本体を正」にできる**。
sf6-sensei は「実測前の当たりを付ける」用途に更に格下げしてよい（§3 Phase 6）。
ただし FrameType を有利フレーム数に変換するロジックは自前で書く必要がある（既存関数は無い）。

### 1.4 決定論的リセット — 既存パターンをそのまま踏襲する

- **位置**: 2 段階・非同期。まず `SelectMenu.StartLocation = 3` +
  `SelectMenu.PlayerDatas[0|1].ManualPosX = ±150`（**センチメートル**）+ `tm._IsReqRefresh = true`
  （`TrainingMoveExecution.lua:184-197`）。`_IsReqRefresh` が false に戻ってから
  `POS_SETx(via.sfix.From(raw/65536.0))` で微調整（ComboTrials:4536-4563、リトライ 10 回）。
- **HP / Drive / SA**: `inject_player_vital` / `inject_player_gauges`（ComboTrials:1187-1209）。
  **エンジンが毎フレーム戻すので毎フレーム再注入する**（`reinject_trial_vital`）。
- **ダミーの自動防御を切る**: `apply_trial_defense_cleanup()`（ComboTrials:3537, 呼出:3788）が
  ダミーの自動 Drive Parry / Drive Rush を無効化する。**これをやらないと link 判定が汚染される。**
- **ガード設定**: `tm._tData.GuardSetting.DummyData.GuardType` = ガードなし。
- **ダミー姿勢/行動**: `tm._tData.DummyStatus.DummyData.DummyActionType` / `.JumpType`。
- **カウンター条件**: `set_dummy_counter_type(0|1|2)`（0=通常ヒット）。MVP は 0 固定。
- **KO / ラウンド終了を潰す**: ComboTrials が既に `app.battle.bBattleFlow::updateKO` と
  `updateRoundResult` を `sdk.hook` し `sdk.to_ptr(2)` を返して演出をスキップしている（:4020-4036）。
  **長時間の総当たりでは必須**（ダミーが死んでラウンドが流れると全部止まる）。
  > **二重登録しないこと。** `sdk.hook` は既存フックを置き換えず積み重なるうえ、
  > ComboTrials 側の条件（trial 実行中のみスキップ）と Explorer 側の条件が衝突すると
  > どちらの意図でもない挙動になる。Phase 3 の実装前に必ず次を確認する:
  > 1. ComboTrials のフックが **mode に関係なく常時登録される**のか、mode 4 のときだけか
  > 2. スキップ条件（`trial_state.is_playing` 等）が Explorer 実行中に成立するか
  > 3. `re.on_script_reset` でのライフサイクル（世代カウンタ相当の無効化があるか）
  >
  > 望ましい順に:
  > (a) ComboTrials 側のスキップ条件に Explorer のセッションフラグを **1 行足して共有する**
  > (b) 共有できなければ Explorer 専用フックを登録し、**ComboTrials 側が非アクティブなときだけ**動かす
  > (c) フックを足さず、victim HP を毎フレーム再注入して KO 自体を起こさせない（最も副作用が小さい）
  >
  > MVP 0 は **(c) を第一候補**にする。HP 再注入は §1.4 で既にやるので追加コストがほぼ無い。
- **ユーザー設定を壊さない**: counter type / guard type / dummy action には
  `read_/set_/save_/restore_` の対をなすラッパーが既にある（ComboTrials:2643-2822）。
  セッション開始時に save、終了時に restore する。
- **万能リセット**: `TrainingManager._IsReqRefresh = true` はトレモメニューの内容
  （位置・HP・Drive・SA・固有ストック）を**まとめて再適用する**。これが唯一のリセットレバー。
  専用の round reset / battle restart API は存在しない。
- **Y 座標は設定できない**（`POS_SETy` がリポジトリに無い）。X のみ。空中始動の位置固定は不可。

### 1.5 信頼できる実行ガード（ComboTrials 由来、必ず踏襲）

- `app.PauseManager._CurrentPauseTypeBit` が `64` か `2112` 以外なら **ポーズ中 → 注入しない**
- `TrainingManager._IsReqRefresh == true` の間は **注入しない**（ステージリフレッシュ中の入力は消える）
- `app.BattleFlow::UpdateFrameMain` フックで `tick_done_this_frame` ラッチをリセットし、
  1 エンジンフレームに 1 回だけ進める（ComboTrials:6731-6739）
- リセット直後 **15 フレームは `combo_cnt` を信用しない**（`_reset_grace = 15`, ComboTrials:4611-4615）
- action の確定は **4F のゴーストフィルタで遅延する**（`ghost_filter_frames` 既定 4）。
  タイミング計算は `process_act.engine_frame`（バッファされた開始フレーム）を使う
- 時間の単位は `engine_frame_count`（ポーズ中は進まない）

### 1.6 Move Catalog の一次データ

`reframework/data/TrainingComboTrials_data/command_display/<Char>.json`
（schema `xt.command_display.v1`、Zangief は `generated_at: 2026-08-03` / `fighter_id: 6` / 80 action id）

**31 キャラ分が同梱されている**（AKI 〜 Zangief。Mai も有り = 次点対象に使える）。
`exceptions/` も 32 ファイル。**clone 実物で確認済み。**
※ `bcm_catalog/` と `modern_display/` は README に載っているがリポジトリには実在しない
（レガシー・デッドコードパス）。これも実物で確認済み。

エントリ形（キー = **decimal action id**。これが唯一の主キー。name フィールドは無い）:

```json
"940": {
  "control_support": "classic_modern",          // or "classic_only"
  "classic_command": { "display": "360+HP", "inputs": ["360+HP"] },
  "simple_command":  { "display": "SP", "inputs": ["SP"] },     // null = 簡易入力なし
  "motion_command":  { "display": "360 + 强", ... },            // null = 手動モーション無し
  "ownership": "direct|inherited|rebind|runtime_common|assist_combo|official_semantic|...",
  "routes": [ { "profile": "easy|sprt|supr|norm|...",
                "raw_button_mask": 32, "visible_direction": null, "visible_button": "SP",
                "raw_direction_inputs": [...], "assist_combo_evidence": false, ... } ]
}
```

- `control_support == "classic_only"` → **Modern 探索から除外**。Zangief は 9 件（34, 600, 613, 615, 631, 685, 852, 1015, 1020）
- `profile == "easy"` → Modern 簡易、`"sprt"` → 手動モーション、`"supr"` → SA ショートカット
- `visible_button` に `AUTO` が入る = Assist 必要。`ownership == "assist_combo"`（628, 629）は
  **アシストコンボのステップとしてしか出ない** → MVP からは除外
- 方向は `visible_direction`（numpad 文字列）を使う。`raw_direction_inputs` は
  BCM 内部エンコードで、リポジトリ内にデコーダが無い（例: 360 → `262145`）

**Zangief の Modern 地上通常技（MVP 0 候補）** — `sprt` ルート・地上・非投げ:

| action_id | classic | Modern motion | dir mask | btn mask |
|---|---|---|---|---|
| 601 / 602 | LP | 弱 | 0 | 16 |
| 611 | LK | 弱 | 0 | 16 |
| 604 | MP | 中 | 0 | 128 |
| 637 | HP | 强 | 0 | 256 （※ is_holdable 3-23F） |
| 617 / 618 / 619 | 2+LP | 2 + 弱 | 2 | 16 |
| 621 | 2+MP | 2 + 中 | 2 | 128 |
| 623 | 2+HP | 2 + 强 | 2 | 256 |
| 633 | 2+HK | 3 + 强 | 10 | 256 |
| 655 | 3+MP | 3 + 中 | 10 | 128 |
| 662 | 6+HK | 6 + 强 | 8 | 256 |
| 682 | 6+MK | 6 + 中 | 8 | 128 |

**MVP 0 から除外する context-dependent Action**（下表は探索対象に入れない）:

| action_id | 表示 | 除外理由 |
|---|---|---|
| 605 / 606 | `>MP` / `> 中` | ターゲットコンボ派生。**単独では出せない**（先行 Action が必要） |
| 679 / 680 | `>MK` / `> 中` | 同上 |
| 627 / 660 | `AUTO + 弱` / `AUTO + 强` | Assist ルート。単独入力の意味論が違う |
| 628 / 629 | `AUTO + 弱` | `ownership: assist_combo` = アシストコンボの途中ステップとしてしか出ない |
| 1213 / 1215 | `>6` / `>4` | AC state-direction 派生（exceptions で `force=true`） |

> **理由**: MVP 0 は「ニュートラルから A を出し、次に B を出す」という
> **standalone な A→B 総当たり**である。先行 Action や特定 state を前提にする技は
> この枠組みでは原理的に出せず、「繋がらない」という誤った結論を大量に生む。
> これらは **A の後続としてのみ現れる**ので、MVP 1 で
> 「A が確定したあとに B 候補として試す」文脈依存フェーズを別に立てて扱う。
> Phase 1 のキャリブレーション（ニュートラルからの単発注入）でも、
> これらは「出ない Action」として自然に落ちるはず。落ちなければ分類を見直す。

> **同一表示に複数 action_id が割り当たっている**（601/602、617/618/619 …）。
> データ側に区別の説明が無い。**どれが canonical かはキャリブレーションの実測で決める。**
> これを設計の最初に決めないと、探索行列がキャラの技数の 3 倍近くに膨らむ。

その他の重要な注意:

- `command_display/*.json` は **絶対にハンド編集しない**。`_meta.audit` の 60 以上のカウンタと
  照合する strict loader があり、1 件でも合わないとそのキャラの Modern 表記が丸ごと無効化される
  （`status: "invalid_schema_or_policy"` で静かに落ちる）。拡張は **サイドカーファイル**で行う。
- `_meta.unmapped_action_ids` に 291 件。**実機は日常的にカタログに無い action_id を返す**。
  「未知の action_id」は異常ではなく通常ケースとして扱う。
- フレームデータ（startup / active / recovery / 有利F / damage / cancel 属性）は
  **command_display に一切無い**。grep で確認済み。→ 外部データか実測が必要。
- 「A が B にキャンセルできる」という構造化情報も無い（`followup_relation_count` = 0）。
  → **総当たりでエッジを作る、という v2 の前提は正しい。**
- `exceptions/<Char>.json` は UI が実行時に書き戻すユーザー状態。ビルド入力に使わない。
  Zangief の 26 件のうち Explorer に効くのは 637/647 の `is_holdable`(charge_min/max) と
  1206/1207 の `absorb_ids` ペア。

### 1.7 出力先（sf6-knowledge-db）の契約

`D:\main\sf6-knowledge-db`（別リポジトリ、Nuxt + Supabase）。契約は
`scripts/types.ts` と `shared/types/domain.ts`。**この 2 ファイルが唯一の正。**

- `ComboYaml`: `slug` / `name_ja` / `control_scheme` / `input_style` / `route_group` / `difficulty` /
  `requirements{drive_min,sa_min,position,counter,resources}` /
  `outcomes{damage,drive_spent,drive_gain,sa_gain,resources}` /
  `end_state{advantage_frames,knockdown_type,back_rise_allowed,ends_in_corner,side_switch,distance_class}` /
  `steps[{move,input_method,notes}]` / `result_node` / `source`
- 語彙が Explorer 側と 1:1 で一致する:
  `control_scheme = classic|modern`、`input_method = manual|simple|assist`、
  `input_style = manual|simple|assist|hybrid`、`position = midscreen|corner|anywhere`、
  `counter = none|counter|punish_counter`
- `SOURCE_KINDS` は **5 種類**: `official` / `wiki` / `video` / `community` / `self_tested`。
  **`placeholder` は廃止済み**（`domain.ts:162` で確認）。
  → Explorer が出せるのは `self_tested` のみ。
  **未検証の結果は export しない。** 仮データを置く受け皿はもう存在しない。
  `validate.ts:139` に「トレモ実測にURLは無い」と明記されており `url` は optional なので、
  `self_tested` の source エントリは URL 無しで登録できる。
- `outcomes.damage` は「**トレーニングモードで実測した値**」と型定義のコメントに明記されている
  （`domain.ts:193-200`）。Explorer の `mComboDamage` 実測値がそのまま入る。
- `steps[].move` は `moves.yaml` の `slug` 参照 → Exporter は **action_id → move slug** の対応表を持つ。
- `validate.ts` は `requirements` / `outcomes` の**未知キーを拒否**する。勝手なキーを足さない。

---

## 2. アーキテクチャ決定

### 2.1 2 台構成と Git

```
[開発機 = このPC]                          [ゲーミングPC]
D:\main\sf6-combo-explorer  --- push --->  clone
  Lua / tools / candidates                   ↓ install-dev.ps1
D:\main\sf6-knowledge-db                   Steam\...\Street Fighter 6\reframework\
  (別repo・直接結合しない)                    ↓ 実行
        ^                                  results/*.json
        |  export YAML                       ↓ commit & push
        +---------------- pull -------------+
```

- `origin` = 自分の Fork、`upstream` = `Wael3rd/SF6_Tools`、作業ブランチ `feat/combo-explorer`
- `results/` は **追記型・1 試行 1 行（JSONL）** にして 2 台間の conflict を避ける
- ゲーム非依存ロジック（Catalog / Candidate / Route / Scoring / Export）は
  **開発機で Node からテストできるよう純関数に切る**。SF6 を触るのは Runner / StageControl / Calibration だけ

### 2.2 Training Script Manager の mode 6 として実装する

理由:
- `RuntimeSafety.begin_frame` / `allow_training` の**唯一の呼び出し元が `Training_ScriptManager.lua`**（:850, :910）。
  TSM が動いていないと `can_inject_input()` は永久に false で、注入が**エラーも出さず黙って死ぬ**。
- P1 に書くのは ComboTrials(DEMO) と TrainingMoveExecution も同じ。**同時に走ると壊れる。**
  mode で排他にするのが最も安全。
- `update_guard_logic`（TSM:290-337）が mode ごとにダミーのガード種別を決める。
  ここに mode 6 を足さないと、**ダミーがガードして「繋がらない」と誤記録される**。

編集が必要な箇所（TSM 内、6 か所）: `TSM_MODE_NAMES`(:347-354) / `MODE_CYCLE`・`MODE_CYCLE_ZH`(:356,:363) /
`re.on_draw_ui` のチェックボックス(:1058-1076) / `update_guard_logic`(:290-337) /
`scripts_active`(:972) / `draw_top_floating_bar`(:615)。
**この 6 か所だけを最小差分で触る**。他は変えない。

### 2.3 追加ファイル

```
reframework/autorun/
  ComboExplorer.lua                     -- mode 6 エントリ。require は file scope
reframework/autorun/func/ComboExplorer/
  Config.lua           -- data/ComboExplorer_data/Config.json
  InputMask.lua        -- numpad/Modernトークン ⇔ uint16。rl_dir 補正。純関数
  Catalog.lua          -- command_display 生JSON読み + サイドカー + キャリブ突合
  Calibration.lua      -- Phase 1: ビット同定 + 入力→action_id スイープ
  StageControl.lua     -- 位置/HP/Drive/SA/ダミー設定の決定論的リセット
  Runner.lua           -- 1試行の状態機械（注入・観測・判定）
  Probe.lua            -- combo_cnt / mComboDamage / actionId / gard_combo_cnt の読み出し集約
  FrameProbe.lua       -- FrameNumDatas の FrameType から startup / 有利F を実測（Phase 6a）
  CandidateGenerator.lua
  SequenceCompiler.lua -- テストケース → uint16[]
  ResultCollector.lua  -- JSONL 追記、中断・再開
  GraphStore.lua / RouteSearch.lua / Scoring.lua / Exporter.lua
  UI.lua               -- UIKit / Training_SharedUI の ImGui パネル
```

後半（MVP 4）: `OkiAnalyzer.lua` / `WakeupTester.lua`。
`func/InputSequencerCore.lua` への共通化は **やらない**（v2 §6 のとおり MVP 通過後に判断）。

規約（recon 確認済み）:
- `require("func/ComboExplorer/X")`（拡張子なし・スラッシュ・`autorun/` 起点）
- グローバルは自前プレフィックス `_ce_` を使う。`_G.SF6Tools` のような名前空間は存在しない
- `local GS = require("func/GameState")` を **file scope で最初に**（`re.on_frame` の登録順が効くため）
- `_G._shared_input_post` は script reset で全消去される → **file scope で登録**すること
- 毎フレームのリフレクションはフィールドディスクリプタを hoist する（GameState:45,59 と同じ）

### 2.4 上流の実装規約（合わせる）

- **ライセンス**: MIT `Copyright (c) 2026 Wael Hadjmouldi`。Fork の義務は
  「著作権表示と許諾文を全コピーに含める」だけ。自分の著作権行を併記するのは可。
  share-alike も UI 上の表示義務も無い。
- **UI は d2d 不要**。`re.on_draw_ui` + `imgui.*` の REFramework パネルなら
  `reframework-d2d.dll` に依存しない。ComboExplorer はオーバーレイを作らないので d2d を使わない。
- **UIKit は 4 関数 + 色テーブル 2 つだけ**（`styled_header` / `styled_button` / `COLORS` / `THEME`）。
  レイアウト・グリッド・ウィンドウのヘルパは無い。
  ただし `imgui.begin_table` は使える（`SF6_RecordingSlotManager.lua:1240` に実例）。
  エッジ一覧はこれで組む。
- **i18n**: 言語は `en` と `zh` のみ（`i18n.lua:20` にハードコード）。ロケールファイルは無く、
  各モジュールが file scope で `i18n.register("<scope>", { en = {...}, zh = {...} })` し、
  `local T = i18n.scope("<scope>")` で引く。`ja` を足すには `i18n.lua` の 5 箇所 +
  既存 7 スコープ全部 + TSM のトグルを触ることになる → **MVP では en/zh に合わせる**。
- **ホットキー**: `func/ComboExplorer_Hotkeys.lua` に `M.init(ctx, Hotkeys)` を作り
  `Hotkeys.register_scope("combo_explorer", { title, order, enabled_default = false, actions = {...} })`。
  `enabled` ゲートに `RuntimeSafety.is_training_allowed()` と `_G.CurrentTrainerMode == 6` を入れる。
  ※ `Training_Hotkeys.update()` の呼び出し元は TSM だけ。TSM が無いとホットキーは一切効かない。
- **設定ファイル**: `reframework/data/ComboExplorer_data/Config.json`。
  json/fs のパスは `reframework/data/` からの相対。`pcall(fs.create_dir, "<Dir>")` してから dump。
  読み込みは `_G.safe_load_json` → デフォルト表へ 1 段マージ（後方互換）。
- **モジュール結線**: メインスクリプトが可変の `ctx` テーブルを 1 個作り、各サブモジュールの
  `M.init(ctx)` に渡す。サブモジュールは必要フィールドを file-local に展開する。
- **命名**: バージョンサフィックス（`_v1.0`）は付けない（多数派に合わせ、README 差分も減る）。
  ヘッダは `-- ====` バナー + 何をするか + 状態の受け取り方を 1 行ずつ。
- **`reframework/guides/CORE_UI_SPLIT.md` が事実上の寄稿ガイドライン**:
  ロジックはユーザー向け文字列を持たないコアモジュールへ / 文字列は必ず i18n 経由 /
  JSON データは言語中立。
- **テスト・CI はリポジトリに存在しない**（`.github/` も `tests/` も無い）。
  Explorer 用のテストは新規に立てる（`tools/` 側の Node テストが現実的）。

### 2.5 安全設計（多重ガード）

```lua
Config.enabled == true
  and _G.CurrentTrainerMode == 6
  and _G.TrainingModeActive == true
  and RuntimeSafety.can_inject_input() == true   -- online ハードゲート込み
  and Explorer.session_active == true            -- UI から明示的に開始したときだけ
  and GS.valid and not GS.in_pause_menu
```

`RuntimeSafety.native_context_ok()` は**設計上 fail-open**（SDK エラー時は「許可」を返す）なので、
Explorer 側で上記の AND を独立に持つ。**新しい入力注入経路は作らない。**

---

## 3. 実装フェーズ

### Phase 0 — セットアップ

| # | 作業 | 場所 |
|---|---|---|
| 0-1 | `winget install --id GitHub.cli` → **`! gh auth login`**（対話が要るのでユーザー実行） | 開発機 |
| 0-2 | `gh repo fork Wael3rd/SF6_Tools --clone=false` → clone → `D:\main\sf6-combo-explorer` | 開発機 |
| 0-3 | `upstream` remote 追加 / `feat/combo-explorer` 作成・push | 開発機 |
| 0-4 | `scripts/install-dev.ps1` 作成（repo → SF6 フォルダ同期。`CustomCombos` / `Stats` / `Backups` / recordings / user config を除外。`dinput8.dll` と `plugins/` は初回のみ） | 開発機で作成 |
| 0-5 | **無改造版の動作確認**（v2 §3.1 全項目 + `_G._mod_errors` が空であること） | 実機 |

0-5 が通らないうちは Explorer を書かない。特に
`pl_input_sub hook not installed` エラーが出ていないことを確認する（出ていたら全方針が崩れる）。

### Phase 1 — キャリブレーション（最重要・v2 への追加）

`Calibration.lua`。**「SF6 本体を正とする」を Move Catalog にも適用する。**

1. **ボタンビット同定**: Modern Zangief で `0x10 / 0x20 / 0x40 / 0x80 / 0x100 / 0x200 / 0x1000 / 0x2000`
   を 1 つずつ 3F 単独注入し、`get_ActionID()` を記録 → §1.2 の表を実測で確認/修正
2. **方向ビットと `rl_dir` 極性の確認**: 左右両サイドで `6+H` / `4+H` を注入し、
   期待した action_id が出るか確認。合わなければ極性を反転
3. **入力→action_id スイープ**: `{5,2,4,6,1,3}` × `{L,M,H,SP}`（+ 必要なら 2 ボタン組）を
   ニュートラルから 1 回ずつ注入 → 出た action_id を記録
4. **重複 action_id の canonical 決定**: 601 vs 602、617/618/619 などを実測で分類し、
   「同じ入力で最初に出る id」を canonical、それ以外を variant として記録
5. **1F 粒度の実証**: 同一の A→B ペアで delay を 1 ティックずつ変えて各 20 回試行し、
   `get_ActionFrame()` と出た action_id が **delay に対して単調・再現的に変化するか**を確認する。
   ばらつくなら掃引の刻みを 2F に落とすか、ヒットストップ補正を見直す。
   → 「エンジンフレーム基準の 1F 粒度」が実際に成立しているかをここで確定させる
6. `command_display/Zangief.json` と突合し、一致 / 不一致 / カタログに無い id をレポート。
   §1.6 の「MVP 0 から除外する context-dependent Action」が
   **実際にニュートラルから出ないこと**も併せて確認する
7. 出力: `calibration/Zangief/modern-<gamePatch>.json`（`ac_sha256` / `bcm_sha256` / `gamePatch` を含める）

**完成条件: Modern で実際に出せる技と、それを出す入力マスクの対応表が実測で確定している。**

### Phase 2 — Move Catalog

`Catalog.lua` = キャリブ結果（正） × `command_display` 生 JSON（メタ情報）。

```json
{ "key": "2M", "actionId": 621, "dirMask": 2, "btnMask": 128,
  "control": "modern", "inputMethod": "manual",
  "controlSupport": "classic_modern", "classicEquivalent": "2+MP",
  "modernDisplay": "2 + 中", "category": "normal", "isHoldable": false,
  "variantOf": null, "verifiedBy": "calibration-2026-08-03",
  "startup": null, "onHit": null, "damage": null }
```

frame 系は Phase 6 まで `null`。埋まっていなくても Phase 3-5 は動く（全ペア総当たりになるだけ）。
表示名は自前で持つ（カタログに name フィールドが無いため）。

MVP 0 の対象は §1.6 の表から **Modern 地上通常技 約10種**（実際の採用は Phase 1 の実測で確定）。

除外基準（`Catalog.lua` で機械的に落とす）:

| 条件 | 判定 |
|---|---|
| Modern 不可 | `control_support == "classic_only"` |
| **文脈依存**（MVP 0 の standalone 総当たりでは出せない） | `motion_command.display` が `>` で始まる / `ownership == "assist_combo"` / `ownership` が `ac_state_*` / `visible_button` に `AUTO` を含む |
| 空中技 | `display` に `空中` または `j.` を含む |
| 投げ | `visible_button == "THROW"` または action_id 710-717 |
| システム | dash / backdash / DI / DR / parry（17,18,34,36,37,38,480,489,501,504,850,852,855,1211,1213,1215） |
| 必殺技・SA | MVP 1 以降（900 番台以上） |

除外した Action は捨てずに `catalog/Zangief/excluded.json` に理由付きで残す。
MVP 1 の文脈依存フェーズでそのまま候補になる。

### Phase 3 — A→B 自動接続テスト（MVP 0 の核）

`SequenceCompiler.lua`:

```
[0 を 10F] [A: dir|btn を 2F] [0 を delay F] [B: dir|btn を 2F] [0 を 30F 観測]
```

`Runner.lua` の 1 試行:

```
StageControl.reset()
  ├ SelectMenu.StartLocation=3, ManualPosX ±150, _IsReqRefresh=true
  ├ _IsReqRefresh が false に戻るまで待つ
  ├ POS_SETx で微調整（誤差 0.5 未満になるまで最大 10 回）
  ├ HP / Drive / SA 注入（以後毎フレーム再注入）
  ├ ダミー: 自動 Parry/DR オフ、ガードなし、counter_type=0、立ち
  └ reset_grace = 15F 待つ  ← combo_cnt を信用しない
     ↓
raw_inputs を _G._shared_input_post から 1F ずつ SET
  （pause_bit ∉ {64,2112} / _IsReqRefresh 中は進めない）
     ↓
毎フレーム記録: combo_cnt, mComboDamage, p1 actionId, victim gard_combo_cnt, act_st
     ↓
判定 → ResultCollector（JSONL 1 行 append + flush）
```

**判定（combo_cnt の絶対値ではなく「B による増加」で見る）**

`combo_cnt == 1 → 2` という決め打ちは使わない。多段技（`>MP` 系、OD、SA、Zangief の 623 など）は
A だけで `combo_cnt` が 2 以上になるため、絶対値で判定すると誤判定する。

観測はステップ境界ごとにスナップショットを取る:

```
c0 = combo_cnt          -- B 入力の直前（A のヒットが確定した後）
cA = A 区間の combo_cnt 最大値
cB = B 区間の combo_cnt 最大値
```

| 結果 | 条件 |
|---|---|
| **link 成立** | (1) A がヒットした（`cA > 0`）<br>(2) **B の Action によって combo_cnt が増えた**（`cB > c0`）<br>(3) A→B の間で `combo_cnt` が 0 に落ちていない（コンボ継続）<br>(4) B 区間で観測された action_id が期待した B と一致（または alias） |
| blocked | B 区間で `victim.gard_combo_cnt` が上昇した |
| whiff | B 区間で `combo_cnt` も `gard_combo_cnt` も動かない |
| wrong move | 期待と違う action_id が出た（カタログ外 id も記録する） |
| A 不発 | `cA == 0`（B の評価をせずそのペアの当該 delay を打ち切り） |

- `cB - c0` を **`hitsAdded`** として記録する（B が何段ヒットしたか。多段技の識別に使える）
- 「増加」の帰属は **B の action_id が観測されたフレーム以降の増分**に限る。
  ゴーストフィルタで Action 確定が最大 4F 遅れるので、帰属判定は
  `process_act.engine_frame`（バッファされた開始フレーム）を基準にする（§1.5）
- リセット直後 15F は `combo_cnt` を読まない（`_reset_grace`）

- **タイミング掃引**: delay = 0..12F を総当たり
- **再試行**: 各 delay 3 回。3/3 のみ `stable: true`
- **早期打ち切り**: A が Hit すらしていない delay が続いたらそのペアを打ち切る

```json
{ "from":604, "to":621, "success":true, "successDelays":[3,4,5],
  "executionLeniency": { "windowFrames":3, "firstDelay":3, "lastDelay":5, "unit":"engine_tick" },
  "hitsAdded":1, "attempts":3, "successes":3, "stable":true,
  "gamePatch":"2026-08-03", "calibration":"<sha>" }
```

> **`timingWindow` は difficulty ではない。** 実測できるのは
> 「何フレーム幅で成立したか」= **execution leniency（入力の許容幅）**であって、
> 人間にとっての難しさそのものではない（1F 目押しでも慣れれば易しい技はあるし、
> window が広くても motion が複雑なら難しい）。
> データ上は `executionLeniency` として保持し、difficulty は Phase 8 で
> **他の要素と合成した派生値**として初めて算出する（§Phase 8）。

**スループット**: 10 技 → 順序対 90 × delay 13 × 3 試行 = 3,510 試行。
1 試行 ≒ リセット 30F + grace 15F + シーケンス 60F ≒ 105F ≒ 1.8 秒 → **約 105 分**。
MVP 0 としては許容。ただし **中断・再開を最初から実装する**（JSONL 追記 + 完了済みペアのスキップ）。
KO / ラウンド終了フックを入れていないと途中で必ず止まるので Phase 3 の初回から入れる。

### Phase 4 — Confirmed Edge Graph

`GraphStore.lua`。成功した A→B のみ保存。
`results/Zangief/2026-08-03/modern/midscreen-normal.json`。
各エッジに `verified:true` / `attempts` / `successes` / `timingWindow` / `gamePatch` /
`ac_sha256` / `bcm_sha256` / `calibrationId` を必ず持たせる（パッチで action_id がずれたら無効化できるように）。

### Phase 5 — Route Generator

`RouteSearch.lua`。Confirmed Edge のみで DFS/BFS。
制約: 最大 step 数 / Drive 上限 / SA 上限 / 同一 loop 禁止 / 同一 Action 連打制限 / 無限探索防止。

### Phase 6 — フレームデータ（実測優先 → 外部データは補助）

**6a. 実測（優先）**: `FrameNumDatas` の `FrameType` ストリーム（§1.3b）から
startup / active / recovery / 有利フレームを自前で測る `FrameProbe.lua` を書く。
Move Catalog の `startup` / `onHit` / `onBlock` を実測値で埋める。
→ これで **delay 掃引を 0..12F から「理論値 ±3F」に狭められ、Phase 3 の実行時間が大幅に短くなる**。

**6b. 外部データ（補助）**: `tools/fetch-frame-data.ts`（Node 24 / pnpm 12、開発機）

- `external-data/sf6-sensei/{zangief.json, source.json}`、**commit SHA を pin**、
  `gamePatch` / `fetchedAt` / ライセンス表記を残す
- 用途は **6a の実測値とのクロスチェック**と、未実測分の当たり付けのみ。真偽判定に使わない
- Knowledge DB へ外部データを丸ごと再配布しない

> ライセンスは実装時に upstream の現行ファイルで再確認する（GitHub 上は "Other" 表記）。
> 再配布不可なら「開発機ローカル参照のみ、成果物には数値を持ち込まない」運用に落とす。
> Modern 情報を持たない可能性が高いので、Modern 固有の値は必ず実測を正とする。

### Phase 7 — 完成 Combo の実測

ルート候補を通しで再実行。2 技エッジが全部成功しても長いコンボが成立するとは限らない。
出力は **`xt.combo_trial` v2.0.0 形式**（`docs/COMBO_JSON_SPEC.md`）:
`_xt_meta.control_mode = "modern"`、`raw_inputs`(uint16[])、`scene_state`（開始リソース）、
`combo_stats{damage, drive_used, super_used}`、step ごとに `id` / `motion` / `expected_combo` / `delay_from_prev`。
→ **既存の Combo Trials UI でそのまま再生・練習・共有できる。独自形式を作らない。**

### Phase 8 — Difficulty / Value スコアリング

`Scoring.lua`。v2 §13 のとおり数値化してからランキング。

**`executionLeniency` はそのまま difficulty にしない。** 実測値としては
「入力の許容幅（engine tick）」を保持し、difficulty は次を合成した**派生値**として算出する:

| 入力 | 由来 |
|---|---|
| `executionLeniency.windowFrames` | 実測（Phase 3） |
| step 数 / 同一技の連続 | ルート構造 |
| motion 桁数（360, 720, 63214 等）| Catalog の `motion_command` |
| `inputMethod` の切り替え回数（manual ↔ simple ↔ assist） | ルート |
| charge 保持の有無・長さ | exceptions の `charge_min/max` |
| Drive Rush 回数 / side switch / micro walk | ルート |

difficulty は**単一値にせず**、`executionLeniency` を含む内訳を必ず一緒に残す
（サイトで「なぜ難しいか」を出せるようにするため）。
ランキングも単一スコアにせず Max Damage / Easy / Easy+High Damage / Zero Drive / Zero SA /
Beginner の複数軸 + Pareto frontier。
Knowledge DB の `difficulty`（数値 1 列）へは最後に丸めて出す。

### Phase 9-10 — Result State / Oki Explorer

v2 §15-16 のとおり。`end_state` の 6 フィールドは Knowledge DB のカラムと 1:1 なのでそのまま埋める。

**`advantage_frames` は最初にクロスチェックしてから採用する。**
`_hc_read_frame_adv`（= `FrameMeterSSData.MeterDatas[0].StunFrame`, §1.3b）は
**ゲーム側が表示用に計算した値**であり、ダウン（KD）後の起き上がりまで含めた有利フレームと
一致する保証がない（通常のヒット/ガード硬直差を出すための値である可能性が高い）。

Phase 9 の最初のタスクは **2 経路の突き合わせ**:

| 経路 | 内容 |
|---|---|
| A: 内蔵値 | `StunFrame` をそのまま読む |
| B: 直接計測 | コンボ終了フレームから、**両者が actionable になるまでのエンジンティック数**を数え、その差を取る。actionable の判定は `act_st == 0` が 3F 連続（§1.3）と `FrameNumDatas` の `FrameType` が startup(7)/recovery(8)/hitstun(9)/blockstun(10) のいずれでもなくなること（§1.3b）の AND |

既知のセットプレイ（例: Zangief の SPD 後）で A と B を並べて記録し、

- **一致する** → 以後は A（安価）を使い、B は抜き取り検証に回す
- **一致しない** → **B を正とする**。A は参考値として別フィールドに残す
- **KD 時だけ乖離する** → ノックダウンの有無で経路を切り替える

判定が付くまで `end_state.advantage_frames` は **export しない**（§1.7 のとおり未検証は出さない）。

> **画面端（corner）判定は既存コードに一切無い。** リポジトリ全体を grep しても
> corner / wall / screen_edge / stage bounds のアクセサはゼロ。
> `SF6_Teleport.lua:88` の `max_bound_raw = 47841280`（= 730.0 units）は
> **テレポートのクランプ値であって「壁」だと明記されていない**。
> `ends_in_corner` / `cornerCarry` / `distance_class` は **新規実装 + 実機での検証が必要**。
> MVP 3 のスコープとして扱い、MVP 0-2 は `position: midscreen` 固定で進める。
ダミー側の起き上がり行動は `xt.record_slot` 形式 + Recording Slot Manager。
※ RSM のスロットは **キャラ id で引く**（プレイヤー index ではない）。
`activate_on_load` を true にするとダミーが勝手に動き出すので注意。
`apply_data_to_character` は 5 秒に 1 回バックアップ JSON を書くので、Fork 側で抑止する。

### Phase 11 — Knowledge DB Export

`Exporter.lua`（Lua・内部 JSON） + `tools/export-to-kdb.ts`（開発機・YAML 生成）。

- **Adapter を挟む**。Explorer 内部 JSON を Knowledge DB の永続 Schema にしない
- `action_id → moves.yaml slug` 対応表を持つ。未登録 move は `moves.yaml` 追記候補として別出力
- `sources.yaml` に `kind: self_tested` のエントリを追加し、全 combo の `source` をそこへ向ける
  （`SOURCE_KINDS` は 5 種類、`placeholder` は廃止済み。`url` は optional なので省略可）
- **未検証データは export しない。** Exporter は次を満たすレコードだけを通す:
  `verified == true` かつ `stable == true` かつ `damage` が実測 かつ
  `gamePatch` / `calibrationId` が現行と一致。
  1 つでも欠けたら **YAML に出さず、`exports/_rejected.jsonl` に理由付きで落とす**。
  仮データの受け皿（旧 `placeholder`）はもう存在しないので、
  「とりあえず出しておく」は選択肢に無い
- 表示名（`name_ja`）は Explorer 側の自前テーブルから。Chinese トークン（弱/中/强/空中/任意键）を
  そのまま出さない（`ModernDisplay.MODERN_TOKENS` で変換。ただし `AUTO`/`SP`/`THROW` は非変換なので自前で対応）
- 生成後 `pnpm validate` が通ることを CI で保証

---

## 4. MVP スコープ

| | 内容 |
|---|---|
| **MVP 0** | Phase 0-4。Modern Zangief / 中央 / 通常ヒット / 地上約10技 の A→B 接続表を自動生成 |
| **MVP 1** | 全地上技、Damage 取得、Route Generator、通しコンボ検証（Phase 5-8） |
| **MVP 2** | 2 人目以降の Modern キャラ（Mai は command_display 同梱済み）、CH / PC、Drive Rush、SA |
| **MVP 3** | Juggle、Corner、Projectile、キャラ固有リソース |
| **MVP 4** | KD advantage、distance、corner carry、oki candidate、wakeup test、safe jump |

MVP 0 完成条件:

1. `calibration/Zangief/modern-*.json` が **実測で**生成されている ← 追加
2. **エンジンフレーム基準の 1F 粒度が実証されている**（掃引の刻みが決まっている）← 追加
3. Move Catalog 生成（canonical / variant の区別 + 文脈依存 Action を `excluded.json` へ分離）← 追加
4. theoretical pairs 生成
5. P1 へ自動入力
6. 100 ペア以内を自動テスト
7. **B の Action による combo count 増加**で成功判定（blocked / whiff / wrong move / A 不発 を区別）← 変更
8. `confirmed_edges.json` 保存（`executionLeniency` / `hitsAdded` / gamePatch / カタログ SHA 付き）← 変更
9. UI/ログから進捗確認、**中断・再開できる** ← 追加
10. 既存 5 モードが従来どおり動く。KO/round フックを二重登録していない ← 追加

---

## 5. 検証方法

### 開発機（このPC）

上流には **テストも CI も存在しない**（`.github/` も `tests/` も無い）。Explorer 用に新規に立てる。

```powershell
cd D:\main\sf6-combo-explorer
pnpm test                                   # 新設: tools/ + 純関数ロジックの単体テスト
pnpm exec tsx tools/export-to-kdb.ts --dry-run

cd D:\main\sf6-knowledge-db
pnpm validate                               # 既存: scripts/validate.ts で受け入れ検証
pnpm gen:seed
```

- `InputMask` / `Catalog` / `CandidateGenerator` / `RouteSearch` / `Scoring` / `Exporter` は
  **ゲーム非依存の純関数**にしてフィクスチャ JSON でテストする
- Lua は構文チェック（`luacheck` があれば併用）+ 実機での実行確認

### 実機（ゲーミングPC）

1. `scripts/install-dev.ps1` で SF6 フォルダへ同期
2. SF6 起動 → `Insert` → REFramework menu → Training Script Manager → **mode 6: Combo Explorer**
3. **Phase 1 キャリブレーションを最初に 1 回**走らせ `calibration/*.json` を目視確認
   - §1.2 の Modern ビット表が正しいか（SP / AUTO / DI）
   - 方向ビットと `rl_dir` 極性が左右両サイドで正しいか
   - **1F 粒度が実証できたか**（delay 1 刻みで結果が単調・再現的か）
   - 文脈依存 Action（`>MP` 等）がニュートラルから出ないこと
4. 既知の 1 ペア（例 `2L → 2L`）を単発実行して期待どおりか目視。
   多段技（623 等）を A に置いて **`combo_cnt` の絶対値判定に依存していない**ことも確認
5. フルスイープ実行。進捗ログと `_G._mod_errors` を確認
6. `results/` を commit & push → 開発機で解析

### 回帰の担保（必ず毎回）

- 既存 5 モード（Hit Confirm / Reaction Drills / Post Guard / Custom Combo Trials / Execution Drill）と
  Distance Viewer / Sheldon's Boxes / Slot Manager をそれぞれ起動し従来どおり動くこと
- mode 6 を選んでいないとき、Explorer のコールバックが **何も書かない**こと
- Distance Viewer の Auto-Activate を **必ず切る**（P2 マスクを毎フレーム書くため探索を汚染する）
- **KO / ラウンド終了の挙動**: mode 4（Combo Trials）で従来どおり演出がスキップされ、
  mode 6 でも意図どおりに動くこと。`sdk.hook` を重ねていないこと
- セッション終了後、ダミーの counter type / guard type / action type が
  **開始前の値に戻っている**こと（`save_/restore_` ラッパー）

---

## 6. リスクと対処

| リスク | 対処 |
|---|---|
| Modern の SP / AUTO / DI ビットが表示コード由来で未検証 | Phase 1 で実測。ここが割れないと先へ進めないので最初にやる |
| 方向ビットの流儀が 2 つある（RSM `MASKS` だけ逆） | slot timeline を使わない。Phase 1 で左右両サイド確認 |
| `rl_dir` 極性が P1/P2 で逆に実装されている | P1 は 3 箇所合意の「falsy で反転」を採用し実測確認 |
| ダミーが自動 Parry / ガードして誤判定 | `apply_trial_defense_cleanup` 相当を必ず適用。`update_guard_logic` に mode 6 を追加 |
| KO / ラウンド終了で長時間走行が止まる | `updateKO` / `updateRoundResult` フックで演出スキップ（ComboTrials と同じ） |
| リセット直後の `combo_cnt` が stale | `_reset_grace = 15` を踏襲 |
| ヒットストップ分だけ計測がずれる | `hit_stop > 0` の間は自前カウンタを止める（TrainingMoveExecution:459-462）。delay はエンジンティック数で数える |
| 「1F 精度」を前提に組んだが実際は揺れる | Phase 1-5 で 1F 粒度を実証してから Phase 3 の刻みを決める。ダメなら 2F 刻み |
| 多段技で `combo_cnt` の絶対値判定が破綻 | 「B による増加」で判定（Phase 3）。`hitsAdded` も記録 |
| 文脈依存技を単独で試して誤判定を量産 | Catalog で機械的に除外（Phase 2）。MVP 1 の文脈依存フェーズで扱う |
| KO/round フックの二重登録で意図しない挙動 | 既存 ComboTrials フックのライフサイクルを確認。MVP 0 は HP 再注入で KO 自体を回避 |
| `StunFrame` が KD 有利フレームと食い違う | Phase 9 冒頭で直接 actionable 計測とクロスチェック。判定が付くまで export しない |
| 未検証データがサイトに載る | `placeholder` は廃止済み。Exporter が verified/stable/実測 damage を満たさないものを弾く |
| 画面端判定のアクセサが存在しない | MVP 0-2 は midscreen 固定。corner は MVP 3 で新規実装 + 実機検証 |
| ダメージ補正（始動/コンボ/SA/Modern）は読めない | 予測しない。**必ず実測**（`mComboDamage`）。v2 の原則どおり |
| ポーズ / ステージリフレッシュ中の入力が消える | `pause_bit ∈ {64,2112}` と `_IsReqRefresh == false` を毎フレーム確認 |
| 他モードが同時に P1 へ書いて壊れる | mode で排他。Distance Viewer AA も切る |
| `_G._shared_input_post` が script reset で消える | file scope で登録。長時間走行中のリロードを検知して停止 |
| 同一表示に複数 action_id（601/602 等）で行列が膨らむ | Phase 1 で canonical / variant を実測決定してから探索する |
| カタログに無い action_id が出る（291 件が unmapped） | 通常ケースとして記録。`nBattle.ACT_ID` 逆引きで名前を付ける |
| `command_display` を編集すると strict loader が丸ごと落ちる | 絶対にハンド編集せず、サイドカーファイルで拡張 |
| パッチで action_id がずれる | 全成果物に `gamePatch` + `ac_sha256` / `bcm_sha256` + calibrationId。不一致で無効化 |
| 2 台運用でデータ往復が煩雑 | `results/` を JSONL 追記型にして conflict を回避 |
| 約 105 分の長時間走行 | 中断・再開を最初から実装。進捗を都度 flush |
| TSM を壊すと注入が黙って死ぬ | TSM の編集は 6 か所の最小差分に限定。編集後は必ず 5 モードの回帰確認 |
| sf6-sensei が再配布不可 | 開発機ローカル参照に限定。Knowledge DB へは実測値のみ |
| 実機 PC の環境が未確認 | Phase 0-5 の無改造版動作確認を通過するまで実装を始めない |

---

## 7. Claude Code 実装ルール（v2 §22 + 調査で追加）

1. 既存 SF6_Tools の動作を壊さない
2. 実装前に既存実装を読む
3. **Input Injection をゼロから書かない** — `_G._shared_input_post` + `pl_input_new`/`pl_sw_new`
4. `RuntimeSafety.can_inject_input()` を必ず通す。加えて mode 6 + session_active の AND を持つ
5. MVP 前に大規模 refactor をしない。TSM の編集は 6 か所の最小差分
6. まず Modern Zangief のみで縦に完成させる
7. 外部フレーム値を推測しない
8. サンプル数値を実データ扱いしない（**この計画書内の数値・action_id も同様。実機で確認する**）
9. すべての結果に `gamePatch` / `source` / カタログ SHA を持たせる
10. 実機検証済み / 未検証を明確に分ける。**未検証は export しない**
    （`SOURCE_KINDS` は 5 種類、`placeholder` は廃止済みで仮データの置き場が無い）
11. `command_display/*.json` をハンド編集しない
12. **既存の `sdk.hook` を二重登録しない。** 追加前に必ずライフサイクルを確認する
13. **実測値と派生値を混ぜない。** `executionLeniency` は実測、`difficulty` は派生。
    `StunFrame` は「ゲームの表示値」、直接計測は「実測」として別フィールドに持つ
14. 1 コミット 1 目的
15. 各 Phase で動作確認手順を README へ追記

---

## 8. 参照

- SF6_Tools: https://github.com/Wael3rd/SF6_Tools （pin `0bd1c53e7885f7684d23cf077c4fa9efe0584d98`, MIT）
- `docs/COMBO_JSON_SPEC.md` — `xt.combo_trial` v2.0.0 (FROZEN)
- `docs/RECORD_SLOT_SPEC.md` — `xt.record_slot` v1.0.0 (FROZEN)
- Modern ビット表: `reframework/autorun/func/ComboTrials_D2D.lua:299-321`
- 注入実例: `TrainingComboTrials_v1.0.lua:6875-6908`, `TrainingMoveExecution.lua:274-317`
- 安全ゲート: `reframework/autorun/func/RuntimeSafety.lua`, `func/SharedHooks.lua`
- 実行ガードと安全: `func/RuntimeSafety.lua`, `func/SharedHooks.lua`
- フレーム計測: `TrainingHitConfirm_v1.0.lua:453-481`(`_hc_read_frame_adv`), `:502-560`(`FrameNumDatas`)
- 寄稿ガイドライン: `reframework/guides/CORE_UI_SPLIT.md`
- sf6-sensei: https://github.com/RyoSogawa/sf6-sensei （ライセンス要確認）
- Knowledge DB 契約: `D:\main\sf6-knowledge-db\scripts\types.ts`, `shared\types\domain.ts`

---

## 8b. Clone 実物での確認（Phase 0 実施済み）

`0bd1c53` を clone して確認した結果、**計画の前提はすべて成立**。加えて次を確定させた。

- clone 直後の HEAD = `0bd1c53e7885f7684d23cf077c4fa9efe0584d98`（recon と同一コミット）
- `command_display/` は **31 キャラ**、`exceptions/` は **32 ファイル**（Mai も有り）
- `bcm_catalog/` と `modern_display/` は**実在しない**（レガシー・デッドコードパス）
- 調査中に一部の subagent が「存在しない」と報告した
  `TrainingReactions_v1.0.lua` / `TrainingPostGuard_v0.1.lua` / `SheldonsBoxes.lua` /
  `func/ImGuiCanvas.lua` / `func/ScriptManager_Hotkeys.lua` / `func/Training_SessionRecap.lua` /
  `SF6Distance_Data_Attacks.json` は **すべて実在する**（部分ダウンロードの副作用による誤報）
- 未見だった `HANDOVER_cdjay.md`（上流著者 Wael → cdjay の引き継ぎ文書）を発見

`HANDOVER_cdjay.md` §2.2 は **本計画 §1.1 の前提を著者本人が明言している**:

> My raw DEMO records the literal per-frame input bitmask (`pl_input_new`, one `uint16`
> per engine input tick) and replays it on the **same engine hook** used for recording.
> ... because record and replay are both gated on the same engine input hook,
> **drift is impossible** — during stun / DI / DRC hitstop the hook simply does not fire,
> so recording and replay pause and resume in lockstep.

→ 「エンジンフレーム基準の 1F 粒度」「ヒットストップ中はティックが進まない」は設計上の意図。
Phase 1-5 の実証はこれを追認する位置づけになる。

同文書からの追加の注意:

- **install 系の act_id は BCM から導出できない**（例: E.Honda の Sumo Spirit 中の強化通常技）。
  キャラ exceptions が fallback として必須。Zangief には install が無いので MVP 0 には影響しない
- **DRC / RAW DR の id が資料間で食い違う**: 生データは `500 = RAW DR / 501 = DRC`、
  一方 `exceptions/Common.json` は `500 = DRC` として扱う。30 カタログ中 500/501 を持つのは 10-11 件のみ。
  MVP 2 で Drive Rush を扱うときに**必ず実測で確定させる**
- `command_display` / BCM カタログの生成ツールチェーンは **cdjay 側 (`SF6_TOOLS_CC`) にあり、
  このリポジトリには含まれない**。新キャラのカタログが要るときは上流に依頼するか自前で用意する

---

## 9. この計画の裏取り状況（完了）

上流ソース pin `0bd1c53` に対し、subagent 10 本による分野別の精読と、
主要 6 主張への敵対的検証 6 本（計 16 エージェント / エラー 0）を実行済み。

**結果: REFUTED ゼロ / CONFIRMED 1 / PARTIAL 5。** 計画の土台は崩れなかった。
PARTIAL 5 件はいずれも「主張は成立するが実装条件が付く」もので、
**その条件は §10 に設計修正として反映済み**。§10 が §1-§7 の該当箇所を上書きする。

Phase 0 で clone 実物による確認も完了（§8b）。

> **注意**: 本計画中の action_id・ビット値・行番号は upstream `0bd1c53` 由来の実測値だが、
> **実機で確認するまで本番データとして扱わない**（v2 §22-8 の原則）。
> Phase 1 のキャリブレーションとスパイク A-C（§10.8）がその確認工程。

---

## 10. 敵対的検証の結果と設計修正（Phase 0 完了時点）

主要 6 主張を独立エージェントに **反証させた**結果: **REFUTED ゼロ / CONFIRMED 1 / PARTIAL 5**。
PARTIAL は「主張自体は成立するが、実装上の重要な条件が付く」もの。以下は**確定した設計修正**であり、
Phase 1 以降はこちらを正とする（§1〜§7 の該当箇所を上書きする）。

### 10.1 P1 入力注入 — CONFIRMED（修正なし）

3 つの独立した P1 注入実装が存在し、ネイティブコード不要、UI 非依存で駆動できることが確認された。

### 10.2 タイミング — 「1 コールバック = 1 フレーム」は成り立たない ★最重要修正

- `pl_input_sub` のフックは **1 バトルフレームあたり複数回**発火する
  （pre コールバックは `p_id` でフィルタされていない）。上流著者自身が
  `app.BattleFlow::UpdateFrameMain` に別フックを張り `tick_done_this_frame` ラッチで
  1 フレーム 1 回に落としている（ComboTrials:6731-6740）。
- さらに **ヒットストップ中は hook tick が engine frame から乖離する**。
  上流のコメントが `hitstop frames missed between engine ticks` と明言し、
  `catch_up_missed_engine_frames()` で補正しているが、**その補正は piyo/burnout 限定で通常時は未補正**。
- つまり **2 つの時計がある**: `engine_frame_count`（`re.on_frame`、ポーズで止まる）と
  hook tick。上流は前者で `delay_from_prev` を記録し、後者で再生している。

**修正（必須）**:

1. **自前で `app.BattleFlow::UpdateFrameMain` にフックを張り `explorer_frame` を進め、ラッチをクリアする。**
   スケジューリングの判断はすべて `explorer_frame` に対して行う。
   `pl_input_sub` の post は **マスクを書く場所**としてのみ使い、`p_id == 0` かつラッチ 1 回に限定する。
   `re.on_frame` / `engine_frame_count` をタイミングに使わない。
2. **delay の単位は「input tick」であって「フレーム」ではない。** 対応関係は実測で確定させる。
3. エッジは素の数値ではなく
   `{ delayTicks, tickBasis: "pl_input_sub@UpdateFrameMain", hitstopFramesObserved,
   injectionLatencyFrames, calibrationId }` で保存する。後から再較正できるようにする。

**Phase 1 に追加するキャリブレーション**:

- (a) 600 フレームにわたり `UpdateFrameMain` 1 回あたりの `pl_input_sub` 呼び出し回数を
  `p_id` 別にヒストグラム化。**プレイヤーごとに正確に 1 回**であることを確認する
- (b) 確定ヒット 1 回を挟んで `explorer_frame` / hook tick 数 / `p1.hit_stop` を毎フレーム記録し、
  ヒットストップによる乖離量を実測する
- (c) **注入レイテンシ**: フレーム F でマスクを書き、`get_ActionID()` が変化する最初のフレームを記録。
  定数オフセットとしてメタデータに保存する
- (d) **tick == frame の確定**: 外部フレームデータで窓幅が既知のリンクを 2-3 個掃引し、
  実測窓幅が公表値と一致するか確認する。ずれるならヒットストップ補正を適用して記録する

### 10.3 計測 — 「既存アクセサ」は存在しない / ダメージは二重計測する

- `get_combo_count` / `_ct_read_combo_cnt` / ダメージ集計は **すべて `local`**。
  `_G` にも `ctx` にも出ていない。**呼べる API は無く、あるのは複製すべきパターンだけ。**
  → `func/ComboExplorer/Telemetry.lua` に自前で実装し、**自前の per-frame tick で駆動する**
  （上流のダメージ集計は `trial_state.is_recording` に hard-gate されており流用できない）。
- `combo_cnt` は 2 スクリプト 3 箇所で読まれており **信頼できる**。
- `mpTeam.mComboDamage` は **リポジトリ全体で読み出しが 1 箇所だけ**、しかも `pcall` の中で、
  上流著者自身が「読めなかった(0)ときは HP デルタにフォールバック」と書いている。
  **「読める」ことは実機で確認されるまで仮説として扱う。**

**修正（必須）**:

1. ダメージは **毎試行 2 通りで測って両方保存**する:
   `mComboDamage` の peak-bank 合算 と `vital_new` の最小値デルタ。
   1 ヒット分以上食い違ったらフラグを立てる（上流も :6126-6134 で同じことをしている）
2. **設計を固める前に 10 分のスパイク**: トレモで Zangief の 2 ヒットコンボを当て、
   `GS.p1.mpTeam.mComboDamage` / `GS.p2.mpTeam.mComboDamage` / `combo_cnt` / `GS.p2.vital_new`
   を毎フレーム print し、(a) フィールドが解決するか (b) どちら側が値を持つか
   (c) コンボ間で 0 に戻るか を確認する

### 10.4 Move Catalog — slim map は「嘘をつく」★重要

`CommandDisplay` の slim map は `simple = simple or manual` / `motion = manual or simple` と
**フォールバックしてから元を捨てる**。Zangief の motion-only 50 件が「簡易入力あり」に見える。
これを信じると **50 技に対して存在しない SP/AUTO を押し、全部空振りし、
「リンクしない」という誤ったエッジグラフができる**（しかもエラーは出ない）。

**修正（必須）**:

1. `ModernDisplay` / `CommandDisplay` / `BcmCatalog` を **カタログ生成に使わない**（表示専用）。
   `json.load_file("TrainingComboTrials_data/command_display/Zangief.json")` で **生 JSON を読む**
2. `inputMethod` は **enum ではなく FLAGS**。901/924/945/963 は simple かつ assist。
   - `manual`: `entry.motion_command ~= nil`
   - `simple`: `entry.simple_command ~= nil` かつ display に `SP` を含む
   - `assist`: `entry.simple_command ~= nil` かつ display に `AUTO` を含む
3. **カタログ行は (action_id × inputMethod) の組ごとに 1 行**にし、実行経路ごとに別々に検証する。
   これは Knowledge DB の `move_inputs`（control_scheme × input_method で 1 行）とも一致する
4. 地上通常技の抽出は **action_id レンジではなく表記の形**（`j.` / `空中` プレフィックスの有無）で行い、
   残った Zangief の地上通常技を一度だけ目視確認する

### 10.5 リセット — 関数呼び出しではなく「整定ゲート付き FSM」★重要

`_IsReqRefresh` は **非同期のリクエスト**。HP/Drive/SA は**毎フレーム再注入し続けるサーボ**。
`POS_SETx` は 1 回では入らない（上流は 0.5 単位の許容で最大 15 回リトライ）。
`combo_cnt` はリセット後 15F 信用できない。ゲーム側が勝手に `_IsReqRefresh` を上げることもある。
→ **「リセットして次フレームから試行」は成立しない。整定に 25F 以上かかる。**

**修正（必須）**: `StageControl.lua` を 5 状態の FSM にする（post コールバック駆動 = tick 同期）:

| 状態 | 内容 |
|---|---|
| `REQUEST` | `SelectMenu.StartLocation=3`、`ManualPosX = -150 / +150`、リソース固定フィールド（`Vital_Type=2`, `Is_Vital_No_Recovery=true`, `DG_Type=0`, `Is_DG_Infinity=false`, `SA_Type=0`, `Is_SA_No_Recovery=true`）を書き、`_IsReqRefresh = true` |
| `WAIT_REFRESH` | `_IsReqRefresh == false` になるまでポーリング。**この間は絶対に入力を注入しない** |
| `CORRECT` | `POS_SETx` を両者に適用 → `pos.x.v` を読み直して検証 → 許容 0.5 で最大 15 回リトライ |
| `PIN` | `vital_*` / `focus_new` / `mSuperGauge` を **初弾ヒットまで毎フレーム再注入** |
| `SETTLE` | 位置誤差が許容内・両者 `combo_cnt == 0`・両者 `act_st` が idle、を **N フレーム連続**（初期値 20-30）満たしてから A を注入 |

- 整定にかかったフレーム数を試行ログに記録する（収束しないリセットを「破棄した試行」として可視化）
- **試行中に `_IsReqRefresh` が立ったら、その試行を破棄する**（ゲーム側が上げることがある）
- `POS_SETy` は存在しないので **空中始動は対象外**（MVP 0 は地上のみなので影響なし）

### 10.6 スループット — 見積りを修正し、探索戦略を変える ★重要

- **ゲームの高速化手段は無い**（`TimeScale` / `GameSpeed` / `frame_skip` はリポジトリに 0 ヒット。
  SF6 のシミュレーションループは Time Scale の影響を受けない）。実時間がそのままコストになる
- ソースから確認できる固定オーバーヘッドだけで **約 155 フレーム**
  （表示 120 + 位置補正 10 + reset_grace 15 + countdown 10）＋ 不定長のリフレッシュ
  ＋ 失敗時タイムアウト約 60 フレーム。**正直に見て 1 試行 3-4 秒**（計画の 1.8 秒は楽観的すぎた）
- 上流には **チェックポイント / 再開 / クラッシュ復旧が一切無い**

**修正（必須）**:

1. **`fail_display_frames` を 120 → 5 に落とす**（`d2d_cfg` の設定値。1 試行あたり約 1.9 秒の削減）
2. **掃引は 1 試行、成立したペアだけ 3 回再検証**する。注入は決定論的（SET かつゲート付き）なので
   同一条件は再現する。これだけで 3 分の 1
3. **delay は線形掃引しない。** 粗く 3 点探ってから窓の端を二分探索する（13 点 → 約 5 点）
4. **2 段階リセット**: 通常は 30 フレームの軽いループで回し、
   `|p1.pos.x - p2.pos.x|` が閾値を超えて漂流したときだけ重い `_IsReqRefresh` を払う
5. **最初の長時間実行の前にチェックポイント / 再開を実装する**。
   1 試行ごとに `(pair, delay, attempt, result)` を JSONL で flush
6. **最初の実走は計画の下限に寄せる**: Modern 地上通常技のうち light/medium を A に限定、
   1 試行、粗い delay で **数百試行 ≒ 1 時間**。パイプライン全体を通してから行列を広げる
7. **コスト実測スパイク（20 分）**: 同一試行を 100 回回して壁時計で測る。
   `_IsReqRefresh` 単独の所要フレーム数も別に測る。**この数値が行列サイズを決める**

**研究スパイク（依存にはしない）**: `app.training.TrainingManager` の
`requestSaveState` / `requestLoadState` はフックされているが**どこからも呼ばれていない**。
save→load が 10 フレーム程度で中立位置 + HP + ダミー状態を戻せるなら
`_IsReqRefresh` を置き換えられ、**最大の高速化になる**。

### 10.7 外部データ源の再評価

sf6-sensei 以外に、**Modern 情報を持つより適した候補**が見つかった。Phase 6 で比較検討する。

| 候補 | 内容 | ライセンス |
|---|---|---|
| `alphazolam/MMDK` | 同じ REFramework 基盤。キャラごとに `Names.json` を出力し、**内部 action_id → 名前**（例 `"0600" → "ATK_5LP"`）を対応付ける。**実行中のゲームから再ダンプできる** | MIT |
| `D4RKONION/FAT` | 技ごとに `ezCmd` フィールドを持ち、**その欠如が「Modern で使用不可」を意味する** | 要確認 |
| `RyoSogawa/sf6-sensei` | 2026-08-03 パッチのフレームデータ。Modern 情報は薄い可能性 | "Other"（要確認） |

MMDK は **表示名の欠落（command_display に name フィールドが無い）を埋められる**ため、
Knowledge DB export の `name_ja` 生成にも効く。FAT の `ezCmd` は
`control_support` の**独立したクロスチェック**になる。

### 10.8 Phase 1 の作業順（10.2-10.6 反映後）

1. **スパイク A（計測）**: `mComboDamage` / `combo_cnt` / `vital_new` が読めるか（10.3-2）
2. **スパイク B（時計）**: hook 呼び出し回数のヒストグラム、ヒットストップ乖離、注入レイテンシ（10.2 a-c）
3. **スパイク C（コスト）**: 100 試行の壁時計、`_IsReqRefresh` の所要フレーム（10.6-7）
4. ボタンビット同定 / 方向・`rl_dir` 極性の確認
5. 入力 → action_id スイープ、重複 action_id の canonical 決定
6. tick == frame の確定（10.2-d）
7. `calibration/Zangief/modern-<gamePatch>.json` 出力

**スパイク A-C が終わるまで Runner の本実装を始めない。** 3 つとも「実機でしか分からない」ことであり、
仮定のまま組むと後戻りが大きい。
