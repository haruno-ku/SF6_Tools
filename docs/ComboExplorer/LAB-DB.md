# lab データベース — 実機の試行ログを Supabase に入れる

実機で回した試行（`reframework/data/ComboExplorer_data/trials/*.jsonl`）を、
knowledge-db の Supabase にある **`lab` スキーマ**へ入れ（#38 Phase A）、
品質フラグで除外して畳んだ**評価**を並べて置く（#38 §8 Phase B）手順です。

- DDL: `sf6-knowledge-db/supabase/migrations/20260914000003_lab_schema.sql`（runs ほか）、
  `20260915000001_lab_evaluations.sql`（評価）
- 行と品質フラグ: `tools/lua/labrows.lua`（規則は冒頭のコメント）
- 評価ポリシー: `tools/lua/labeval.lua`（規則は冒頭のコメント。`ce-eval-v1`）
- SQL の生成: `tools/db/lab-import.mjs` + `tools/db/lab-eval.mjs`（`npm run lab:sql`）
- DB への適用: `tools/db/lab-apply.mjs`（`npm run lab:apply`）

`lab` は **公開しません**。anon / authenticated からは schema ごと遮断され（REVOKE と RLS）、
公開用の `public` には一切触りません。JSONL がログの正本で、`lab` はそこから何度でも
同じ件数に再構築できる写しです。

## いま入っているもの（2026-09-14）

| 表 | 行 |
|---|---:|
| runs | 856（1000 行。同一内容の重複は 1 観測として数える） |
| run_sources | 1000（観測が見つかったすべての場所） |
| routes / route_steps | 218 / 437 |
| import_batches | 12 |
| calibration_profiles / catalog_snapshots / test_contexts / route_definitions | 2 / 1 / 1 / 2 |

品質フラグ（`lab.run_quality`、観測単位）: evidence_missing 544 / superseded_rerun 246 /
motion_button_late 231 / legacy_route_subject 222 / fixed_delay_4 202 / unplayable_input 156 /
link_timing_on_cancel_pair 146。フラグは削除ではなくデータで、評価のときに除外に使います。

## 評価（Phase B、本番未適用）

| 表・ビュー | 中身 |
|---|---|
| `evaluation_policies` | ポリシー 1 行（`ce-eval-v1`）。規則は `rules` に JSON で丸ごと |
| `evaluations` | ポリシー × 対象（ペアのエッジ / ルート）× cohort × 証拠集合 で 1 行。追記のみ |
| `evaluation_runs` | 評価ごとの試行と `counted` / `excluded`（除外は理由付き） |
| `current_evaluations` | ポリシー × 対象 × cohort ごとに最新の評価 |
| `confirmed_combos` | 最新の評価のうち `reproduced`。技の並び（`moves_key`）と表記の鎖、成功数、ダメージ範囲 |

`ce-eval-v1` の規則（詳しくは `labeval.lua` 冒頭）:

- `superseded_rerun` の試行は、繋がったもの以外を除外（撮り直しの原因は期待 id の不具合で、偽の wrong_move は作れても link は作れない）
- link は数える（タイミングが悪くても繋がったものは繋がった）
- 否定は `fixed_delay_4` / `unplayable_input` / `link_timing_on_cancel_pair` / `motion_button_late`
  のどれかがあれば除外（正しいタイミング・押せる入力で問えていない）
- 未回答は未回答として数える。`legacy_route_subject` と `evidence_missing` は除外しない
- ペアは cohort ごとに ConfirmedEdge で畳み、stable なら `reproduced`。ルートは cohort ごとに
  コンボ一覧と同じ規則（数えた link が 2 回以上、隙間は問わない）で `reproduced`
- それ以外: 答えた試行なし `pending` / 成功と失敗 `mixed`（ペアでは多くは遅延の窓）/
  成功のみ `observed_success` / 失敗のみ `no_success_observed`

既存ログ（1000 行）での結果: 評価 420（edge pending 365 / no_success_observed 41 /
observed_success 8 / reproduced 4、route reproduced 2）。除外 352（superseded_rerun 242 /
link_timing_on_cancel_pair 44 / fixed_delay_4 37 / motion_button_late 29）。

**確定コンボ（`lab.confirmed_combos`）は 6 件**: ground-truth の 3 手ルート（19 回）、ab の 2 手ルート（2 回）、
ペア 4 件（2+弱 → 236236+中 / 2+弱 → 4+SP+强 @22、2+中 → 4+SP+强 @35、3+强 → 4+SP+强 @53、いずれも同じ遅延で 2 回）。
`combos-zangief-modern.md` の「確定 7」と数が違うのは、コンボ一覧が「技が同じなら入力方式も cohort
（delay4 は別の校正）も隙間もまとめて 2 回」と数えるのに対し、評価は
**エッジ（入力方式込み）× cohort ごとに、同じ遅延で 2 回**を要求するためです。
delay4 の 1 回だけのリンク（弱 → SA2 など 8 件）は `observed_success` で、確定にするには同じ遅延で撮り直す。

同じ id の評価が内容違いで入っていれば取り込みは中断します（規則を変えたら policy_key を変える）。

## 実機のあとで追加分を入れる

1. ログをコミットする
2. SQL を作る（SF6_Tools で）

   ```
   npm run lab:sql
   ```

   `db/out/lab-import-<時刻>.sql` と `.dryrun.sql`（最後に必ず巻き戻す版）ができます。
   runs のあとに評価（ポリシー・evaluations・evaluation_runs）が同じファイルに入ります。
   どれも `ON CONFLICT DO NOTHING` なので、全ファイルを毎回入れ直して構いません。
   すでに入っている観測・評価は増えず、内容が食い違う同じキーは取り込み全体を中断します。
   新しい試行やフラグで証拠集合が変わった評価だけが、新しい行として足されます。

3. 流す

   ```
   npm install                                  # 初回だけ（pg）
   export LAB_DB_URL='postgresql://lab_importer.<project-ref>:<password>@aws-0-<region>.pooler.supabase.com:5432/postgres'
   npm run lab:apply -- --dry-run               # 最新の .dryrun.sql。件数 before -> after を表示
   npm run lab:apply                            # 最新の本体。もう一度流して全表 before = after なら冪等
   npm run lab:apply -- db/out/lab-import-<時刻>.sql   # ファイルを指定する場合
   ```

   - `LAB_DB_URL` は **Supabase のセッションプーラー（5432）** の URL。ユーザー名はプーラーの形式
     `<ロール>.<project-ref>`。ホスト名は `supabase/.temp/pooler-url`（`supabase link` 済みの環境）と同じ。
     トランザクションモード（6543）は一時表が使えないので `lab-apply` が拒否します
   - ロールは下の `lab_importer`（取り込み専用）。`postgres` では流さない
   - パスワードは表示しません（host / port / user / database だけ）。
     `LAB_DB_CA_FILE` に Supabase のサーバー証明書（ダッシュボードの Database 設定からダウンロード）を
     指定すると証明書を検証します。無ければ暗号化はするが未検証、と表示します
   - `--dry-run` は最後の `DRY RUN, nothing kept.` 例外を成功として扱い、それ以外のエラーは失敗（exit 1）

   **ここに書いた 3 つの落とし穴を踏まないこと。** 2026-09-14 の初回投入で全部踏みました:

   | 方法 | 結果 |
   |---|---|
   | `supabase db query -f … --linked` | **413 request entity too large**（Management API 経由。数 MB の SQL は通らない） |
   | `--db-url` に `SUPABASE_DB_URL`（直接接続） | **名前解決できない**（直接接続のホストは IPv6 専用。この回線は IPv4） |
   | `--db-url` にプーラー URL | **cannot insert multiple commands into a prepared statement**（CLI は拡張プロトコルで送るので複数文を流せない） |

   通った方法: **プーラーのセッションモード（5432）に、単純クエリプロトコルのクライアントで流す。**
   `lab-apply.mjs` がそれです（Node の `pg` の `client.query(sql)` はパラメータ無しなら単純クエリ
   プロトコルなので、ファイル全体を 1 回で渡せる）。

## 取り込み用ログイン lab_importer を作る（1 回だけ、運用者が手で）

migration はパスワードを持たないので、ログインロールは手で作ります（`postgres` で、SQL エディタか psql から）:

```sql
create role lab_importer login password '<長いランダム文字列>' in role explorer_ingest;
-- 確認（全部 true）
select has_database_privilege('lab_importer', current_database(), 'TEMPORARY'),
       has_schema_privilege('lab_importer', 'lab', 'USAGE'),
       has_table_privilege('lab_importer', 'lab.evaluations', 'INSERT'),
       has_language_privilege('lab_importer', 'plpgsql', 'USAGE');
```

`explorer_ingest` が持つもの: lab の USAGE、全表の SELECT / INSERT（UPDATE / DELETE は無し）、
ドメイン `lab.quality_flags` の USAGE（一時表 `like lab.runs` が使う）、ビューの SELECT、
データベースの TEMPORARY（Phase B の migration が明示的に付与。PUBLIC から取り消されていても取り込める）。
DO ブロックに要る plpgsql の USAGE は既定で PUBLIC にあり、migration では付与しない（上の確認で見る）。
INHERIT は既定なので、`lab_importer` には explorer_ingest の権限と RLS ポリシーがそのまま効きます。

PGlite（PG 18.3）で、PUBLIC の TEMPORARY を取り消した状態から migration 2 本 → `SET ROLE explorer_ingest` で
dry run・本体・本体（2 回目は全表 before = after）→ anon / authenticated で評価の表・ビューが
`permission denied for schema lab`、explorer_ingest の UPDATE / DELETE が拒否、まで確認済み。

## 新しい表を lab に足すとき

- マイグレーションは knowledge-db の `supabase/migrations/` に置く（1 つの DB に 1 本の履歴）
- `ALTER DEFAULT PRIVILEGES IN SCHEMA lab` はスキーマ指定なしの既定権限を取り消せないので、
  **新しい表・ビューごとに REVOKE と RLS を書き直す**（Phase A・B の migration の末尾と同じもの）
- 取り込み SQL が新しい表に書くなら `explorer_ingest` に SELECT / INSERT とポリシーを付ける
- `supabase db push --linked --dry-run` で適用対象を確認してから `--yes`

## まだ無いもの

- 実測ダメージ: 既存ログには無い（`measured_damage` は全行 null、`confirmed_combos.damage_min/max` も null）。
  次の実機セッションから入る
- 評価の公開（`ce.verified_combo.v1` への書き出し・release）: Phase B の範囲外
