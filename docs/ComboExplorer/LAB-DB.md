# lab データベース — 実機の試行ログを Supabase に入れる

実機で回した試行（`reframework/data/ComboExplorer_data/trials/*.jsonl`）を、
knowledge-db の Supabase にある **`lab` スキーマ**へ入れる手順です（#38 Phase A）。

- DDL: `sf6-knowledge-db/supabase/migrations/20260914000003_lab_schema.sql`
- 行と品質フラグ: `tools/lua/labrows.lua`（規則は冒頭のコメント）
- SQL の生成: `tools/db/lab-import.mjs`（`npm run lab:sql`）

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

## 実機のあとで追加分を入れる

1. ログをコミットする
2. SQL を作る（SF6_Tools で）

   ```
   npm run lab:sql
   ```

   `db/out/lab-import-<時刻>.sql` と `.dryrun.sql`（最後に必ず巻き戻す版）ができます。
   どちらも `ON CONFLICT DO NOTHING` なので、全ファイルを毎回入れ直して構いません。
   すでに入っている観測は増えず、内容が食い違う同じキーは取り込み全体を中断します。

3. 流す（knowledge-db の `.env` の接続情報を使う）

   **ここに書いた 3 つの落とし穴を踏まないこと。** 2026-09-14 の初回投入で全部踏みました:

   | 方法 | 結果 |
   |---|---|
   | `supabase db query -f … --linked` | **413 request entity too large**（Management API 経由。数 MB の SQL は通らない） |
   | `--db-url` に `SUPABASE_DB_URL`（直接接続） | **名前解決できない**（直接接続のホストは IPv6 専用。この回線は IPv4） |
   | `--db-url` にプーラー URL | **cannot insert multiple commands into a prepared statement**（CLI は拡張プロトコルで送るので複数文を流せない） |

   通った方法: **プーラーのセッションモード（5432）に、単純クエリプロトコルのクライアントで流す。**
   プーラーの URL は `supabase/.temp/pooler-url`（`supabase link` 済みの環境にある。gitignore）、
   パスワードは `.env` の `SUPABASE_DB_PASSWORD`。Node の `pg` の `client.query(sql)` は
   パラメータ無しなら単純クエリプロトコルなので、ファイル全体を 1 回で渡せます。
   トランザクションモード（6543）は一時表が使えないので不可。

   先に `.dryrun.sql` を流し、`DRY RUN, nothing kept. Rows before -> after: …` の件数を確認してから
   本体を流す。本体をもう一度流して全表の before = after になれば冪等性の確認になります。

## 新しい表を lab に足すとき

- マイグレーションは knowledge-db の `supabase/migrations/` に置く（1 つの DB に 1 本の履歴）
- `ALTER DEFAULT PRIVILEGES IN SCHEMA lab` はスキーマ指定なしの既定権限を取り消せないので、
  **新しい表ごとに REVOKE と RLS を書き直す**（初回マイグレーションの末尾と同じもの）
- `supabase db push --linked --dry-run` で適用対象を確認してから `--yes`

## まだ無いもの

- 評価（ConfirmedEdge を品質フラグで除外して畳んだ結果）: Phase B
- 取り込み専用のログインロール: `explorer_ingest`（NOLOGIN）はあるが、ログイン用ロールは未作成。
  今は `postgres` で流している
- 実測ダメージ: 既存ログには無い（`measured_damage` は全行 null）。次の実機セッションから入る
