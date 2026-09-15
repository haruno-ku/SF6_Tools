// Turns every committed trial log, calibration and route definition into one
// idempotent SQL file for knowledge-db's `lab` schema (haruno-ku/SF6_Tools#38,
// Phase A), followed by the evaluations over those runs (Phase B,
// tools/db/lab-eval.mjs).
//
//   node tools/db/lab-import.mjs            (from the repo root; npm run lab:sql)
//
// Writes, and never connects to anything:
//   db/out/lab-import-<UTC timestamp>.sql         BEGIN ... COMMIT
//   db/out/lab-import-<UTC timestamp>.dryrun.sql  the same statements, ROLLBACK
//
// Both report rows per table before and after, so the dry run against the real
// database says what the real run would add - and a second real run adds
// nothing. The dry run's report is the message of the exception it ends in.
// The schema is knowledge-db's supabase/migrations/*_lab_schema.sql and
// *_lab_evaluations.sql, which must be applied first. tools/db/lab-apply.mjs
// (npm run lab:apply) sends either file to a database.
//
// WHO DOES WHAT
//
// tools/lua/labrows-cli.lua decides what each trial line means: its subject,
// its route, its conditions, its quality flags. This file only does what Lua
// should not: hashing (node:crypto), reading directories, and SQL literals.
// Lua never builds SQL, so a quoting bug can only live here, in one function
// per literal type.
//
// THE IDEMPOTENCY KEY
//
// lab.runs.event_key = "sha256:" + sha256 of the record's canonical JSON
// (RFC 8785 style: keys sorted by UTF-16 code unit, no whitespace, ECMAScript
// number form). Not the record's `id`: that is ResultCollector's resume key,
// and it repeats - 563 distinct ids over the first 1000 lines, because a re-run
// reuses its subject, delays and attempt. Not the file and line: the same
// observation is committed in two files (the 144 gap2to28 lines are also inside
// the pre-group file) and would import twice.
//
// Identical content means the same observation. The content includes
// recorded_at to the second, the calibration, and - on every answered row - the
// tick-by-tick evidence; one trial takes over 200 ticks, and the collector
// refuses to run a key twice in a session, so two different trials cannot
// produce the same line. The run imports once; every place it was found is a
// lab.run_sources row. The SQL still compares the stored payload with the
// incoming one after inserting and aborts on a difference: the hash is the
// index, never the thing a decision rests on (#38 §3).

import { spawnSync } from 'node:child_process'
import { createHash } from 'node:crypto'
import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from 'node:fs'
import { homedir } from 'node:os'
import { dirname, join, relative, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { buildEvaluations, EVAL_TABLES } from './lab-eval.mjs'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..')
const DATA = 'reframework/data/ComboExplorer_data'
const OUT_DIR = join(ROOT, 'db', 'out')

// --- lua, found the way tools/lua-runner.mjs finds it --------------------------

const LUA_CANDIDATES = [
  'lua',
  'lua5.4',
  'lua54',
  join(homedir(), 'AppData', 'Local', 'Programs', 'Lua', 'bin', 'lua.exe'),
  'C:\\Program Files\\Lua\\bin\\lua.exe',
]

function findLua() {
  for (const exe of LUA_CANDIDATES) {
    const probe = spawnSync(exe, ['-v'], { encoding: 'utf8' })
    if (probe.status === 0 || (probe.stdout ?? '').startsWith('Lua') || (probe.stderr ?? '').startsWith('Lua')) {
      return exe
    }
  }
  return null
}

// --- hashing and ids -------------------------------------------------------------

export const sha256 = (data) => createHash('sha256').update(data).digest('hex')

export function canonicalJson(v) {
  if (v === null || typeof v !== 'object') {
    if (typeof v === 'number' && !Number.isFinite(v)) throw new Error(`not JSON: ${v}`)
    return JSON.stringify(v)
  }
  if (Array.isArray(v)) return '[' + v.map(canonicalJson).join(',') + ']'
  return '{' + Object.keys(v).sort().map((k) => JSON.stringify(k) + ':' + canonicalJson(v[k])).join(',') + '}'
}

// A UUID derived from the row's natural key (version 8, "custom": the first 122
// bits of a SHA-256). The same data gives the same id in every database it is
// imported into, so a foreign key can be written as a literal and a re-import
// meets its own rows.
export function uuidFor(table, key) {
  const h = createHash('sha256').update(`${table}\u0000${key}`).digest()
  h[6] = (h[6] & 0x0f) | 0x80
  h[8] = (h[8] & 0x3f) | 0x80
  const x = h.subarray(0, 16).toString('hex')
  return `${x.slice(0, 8)}-${x.slice(8, 12)}-${x.slice(12, 16)}-${x.slice(16, 20)}-${x.slice(20, 32)}`
}

// --- SQL literals ----------------------------------------------------------------

// Dollar quoting: nothing inside is an escape, so quotes, backslashes and
// 強/中/弱 go through byte for byte. The one thing that could end the literal is
// the tag itself, and a value containing it is refused rather than mangled.
const TAG = '$lab_q$'

export const sql = {
  text(v) {
    if (v === null || v === undefined) return 'null'
    const s = String(v)
    if (s.includes(TAG)) throw new Error(`a value contains the quote tag ${TAG}`)
    if (s.includes('\u0000')) throw new Error('a value contains NUL, which Postgres text cannot hold')
    return TAG + s + TAG
  },
  jsonb(v) {
    if (v === null || v === undefined) return 'null'
    const s = JSON.stringify(v)
    // JSON.stringify writes a NUL as \u0000, which jsonb refuses on input.
    if (s.includes('\\u0000')) throw new Error('a JSON value contains \\u0000, which jsonb refuses')
    return sql.text(s) + '::jsonb'
  },
  int(v) {
    if (v === null || v === undefined) return 'null'
    if (!Number.isSafeInteger(v)) throw new Error(`not an integer: ${v}`)
    return String(v)
  },
  bool(v) {
    if (v === null || v === undefined) return 'null'
    if (typeof v !== 'boolean') throw new Error(`not a boolean: ${v}`)
    return v ? 'true' : 'false'
  },
  uuid(v) {
    if (v === null || v === undefined) return 'null'
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(v)) throw new Error(`not a uuid: ${v}`)
    return `'${v}'::uuid`
  },
  ts(v) {
    if (v === null || v === undefined) return 'null'
    return sql.text(v) + '::timestamptz'
  },
  textArray(a) {
    if (!a || a.length === 0) return `'{}'::text[]`
    return 'array[' + a.map(sql.text).join(',') + ']::text[]'
  },
  intArray(a) {
    if (!a) return 'null'
    return 'array[' + a.map(sql.int).join(',') + ']::int[]'
  },
}

export function insert(table, columns, rows, conflict) {
  if (rows.length === 0) return `-- ${table}: nothing to insert\n`
  const values = rows.map((r) => '  (' + r.join(', ') + ')').join(',\n')
  return `insert into ${table} (${columns.join(', ')}) values\n${values}\n${conflict};\n`
}

// --- reading -------------------------------------------------------------------------

function listFiles(dir, ext) {
  const abs = join(ROOT, dir)
  if (!existsSync(abs)) return []
  return readdirSync(abs).filter((n) => n.endsWith(ext)).sort().map((n) => `${dir}/${n}`)
}

// The same split ResultCollector.scan makes, so line numbers agree with Lua's.
function splitLines(text) {
  const lines = text.split('\n').map((l) => l.replace(/\r$/, ''))
  if (lines.length > 0 && lines[lines.length - 1] === '') lines.pop()
  return lines
}

function git(args) {
  const r = spawnSync('git', ['-C', ROOT, ...args], { encoding: 'utf8' })
  return r.status === 0 ? r.stdout.trim() : null
}

function main() {
  const lua = findLua()
  if (!lua) {
    console.error('lua not found. Install Lua 5.4:  winget install --id DEVCOM.Lua')
    process.exit(2)
  }

  const trialFiles = listFiles(`${DATA}/trials`, '.jsonl')
  const calibrationFiles = listFiles(`${DATA}/calibration`, '.json')
  const routeFiles = listFiles(`${DATA}/route`, '.json')
  if (trialFiles.length === 0) {
    console.error(`no trial logs under ${DATA}/trials - run from the repo root of SF6_Tools`)
    process.exit(2)
  }

  const cli = spawnSync(lua, ['tools/lua/labrows-cli.lua', '--trials', trialFiles.join(','), '--routes', routeFiles.join(',')], {
    cwd: ROOT, encoding: 'utf8', maxBuffer: 512 * 1024 * 1024,
  })
  if (cli.stderr) process.stderr.write(cli.stderr)
  const out = (cli.stdout ?? '').split('\n').filter((l) => l.trim() !== '').map((l, i) => {
    try { return JSON.parse(l) } catch (e) { throw new Error(`labrows-cli line ${i + 1} is not JSON: ${l.slice(0, 200)}`) }
  })
  const problems = out.filter((r) => r.kind === 'problem')
  if (cli.status !== 0 || problems.length > 0) {
    for (const p of problems) console.error('PROBLEM', JSON.stringify(p))
    console.error(`labrows-cli exited ${cli.status} with ${problems.length} problem row(s); nothing written`)
    process.exit(1)
  }

  const toolCommit = git(['rev-parse', 'HEAD'])
  const toolDirty = (git(['status', '--porcelain']) ?? '') !== ''
  const summary = out.find((r) => r.kind === 'summary')
  const labrowsVersion = summary?.labrows_version ?? null

  // --- import batches: one per source file, by path and content -------------------
  const batches = new Map() // path -> batch
  function batchFor(path, kind, bytes, extra = {}) {
    const hash = sha256(bytes)
    const b = {
      id: uuidFor('lab.import_batches', `${path}\u0000${hash}`),
      source_kind: kind, source_file: path, file_sha256: hash, byte_size: bytes.length,
      line_count: null, rows_emitted: 0, ...extra,
    }
    batches.set(path, b)
    return b
  }

  // --- catalog snapshots -------------------------------------------------------------
  const snapshots = new Map()
  function snapshotFor(character, ac, bcm, seenIn) {
    if (!character || !ac || !bcm) return null
    const key = `${character}\u0000${ac}\u0000${bcm}`
    if (!snapshots.has(key)) {
      snapshots.set(key, { id: uuidFor('lab.catalog_snapshots', key), character, ac_sha256: ac, bcm_sha256: bcm, first_seen_in: seenIn })
    }
    return snapshots.get(key).id
  }
  const catalogByScope = new Map()
  for (const c of out.filter((r) => r.kind === 'catalog')) {
    catalogByScope.set(`${c.character}|${c.control_scheme}`, snapshotFor(c.character, c.ac_sha256, c.bcm_sha256, c.source_file))
  }

  // --- calibration profiles --------------------------------------------------------------
  const calibrations = new Map() // calibration_id -> row
  for (const path of calibrationFiles) {
    const bytes = readFileSync(join(ROOT, path))
    const doc = JSON.parse(bytes.toString('utf8'))
    const b = batchFor(path, 'calibration', bytes)
    if (doc.schema !== 'ce.calibration.v1' || typeof doc.calibration_id !== 'string') {
      throw new Error(`${path} is not a ce.calibration.v1 with a calibration_id`)
    }
    const payloadHash = sha256(canonicalJson(doc))
    const prior = calibrations.get(doc.calibration_id)
    if (prior) {
      // latest.json is a copy of a dated file. A copy is the same profile; a
      // different body under the same id is two profiles claiming one name.
      if (prior.payload_sha256 !== payloadHash) {
        throw new Error(`${path} and ${prior.source_path} both claim calibration ${doc.calibration_id} with different content`)
      }
      b.notes = { duplicate_of: prior.source_path }
      continue
    }
    b.rows_emitted = 1
    calibrations.set(doc.calibration_id, {
      id: uuidFor('lab.calibration_profiles', doc.calibration_id),
      calibration_id: doc.calibration_id, character: doc.character ?? null, control_scheme: doc.control_scheme ?? null,
      game_patch: doc.game_patch ?? null,
      catalog_snapshot_id: snapshotFor(doc.character, doc.ac_sha256, doc.bcm_sha256, path),
      generated_at: doc.generated_at ?? null, values: doc.values ?? {}, payload: doc,
      payload_sha256: payloadHash, source_path: path, import_batch_id: b.id,
    })
  }

  // --- routes and their definitions ------------------------------------------------------
  const routes = new Map()
  function routeFor(character, scheme, route, snapshotId) {
    if (!route || !character || !scheme) return null
    const key = `${character}\u0000${scheme}\u0000${route.shape_key}`
    if (!routes.has(key)) {
      routes.set(key, { id: uuidFor('lab.routes', key), character, control_scheme: scheme, shape_key: route.shape_key, steps: route.steps, catalog_snapshot_id: snapshotId })
    }
    return routes.get(key).id
  }
  const definitions = []
  for (const d of out.filter((r) => r.kind === 'route_definition')) {
    const bytes = readFileSync(join(ROOT, d.source_file))
    const b = batchFor(d.source_file, 'route', bytes, { rows_emitted: 1 })
    const routeId = routeFor(d.character, d.control_scheme, d.route, null)
    if (!routeId) throw new Error(`${d.source_file}: route definition has no shape`)
    definitions.push({
      id: uuidFor('lab.route_definitions', `${d.definition_id}\u0000${b.file_sha256}`),
      definition_id: d.definition_id, character: d.character, control_scheme: d.control_scheme,
      route_id: routeId, source_path: d.source_file, file_sha256: b.file_sha256,
      payload: JSON.parse(bytes.toString('utf8')), import_batch_id: b.id,
    })
  }

  // --- runs --------------------------------------------------------------------------------
  const fileLines = new Map()
  for (const path of trialFiles) {
    const bytes = readFileSync(join(ROOT, path))
    const lines = splitLines(bytes.toString('utf8'))
    fileLines.set(path, lines)
    batchFor(path, 'trials', bytes, { line_count: lines.length })
  }

  const contexts = new Map()
  const runs = new Map()       // event_key -> run
  const locations = new Map()  // "path\0line" -> event_key
  const sources = []
  for (const row of out.filter((r) => r.kind === 'run')) {
    const lines = fileLines.get(row.source_file)
    const raw = lines?.[row.line_no - 1]
    if (raw === undefined) throw new Error(`labrows-cli named ${row.source_file}:${row.line_no}, which does not exist`)
    const rec = JSON.parse(raw)
    if (rec.id !== row.record_id) throw new Error(`${row.source_file}:${row.line_no}: Lua and Node disagree about which record this is`)

    const payloadHash = sha256(canonicalJson(rec))
    const eventKey = `sha256:${payloadHash}`
    const batch = batches.get(row.source_file)
    batch.rows_emitted += 1
    locations.set(`${row.source_file}\u0000${row.line_no}`, eventKey)
    sources.push({ event_key: eventKey, import_batch_id: batch.id, source_file: row.source_file, file_sha256: batch.file_sha256, line_no: row.line_no, quality_flags: row.quality_flags })

    const existing = runs.get(eventKey)
    if (existing) {
      existing.quality_flags = [...new Set([...existing.quality_flags, ...row.quality_flags])].sort()
      continue
    }

    let contextId = null
    if (row.context) {
      const c = row.context
      if (!contexts.has(c.canonical)) {
        contexts.set(c.canonical, { id: uuidFor('lab.test_contexts', c.canonical), ...c, payload: rec.conditions })
      }
      contextId = contexts.get(c.canonical).id
    }

    const routeId = routeFor(row.character, row.control_scheme, row.route,
      row.subject_kind === 'edge' ? (catalogByScope.get(`${row.character}|${row.control_scheme}`) ?? null) : null)

    runs.set(eventKey, {
      id: uuidFor('lab.runs', eventKey), event_key: eventKey, payload_hash: payloadHash,
      source_file: row.source_file, line_no: row.line_no, import_batch_id: batch.id,
      record_id: row.record_id, schema: row.schema, character: row.character, control_scheme: row.control_scheme,
      game_patch: row.game_patch ?? null, calibration_id: row.calibration_id ?? null,
      calibration_profile_id: calibrations.get(row.calibration_id)?.id ?? null,
      context_id: contextId, route_id: routeId, test_kind: row.test_kind,
      subject_kind: row.subject_kind, subject_id: row.subject_id,
      recorded_subject_kind: row.recorded_subject_kind, recorded_subject_id: row.recorded_subject_id,
      attempt: row.attempt, delays: row.delays, swept_gap: row.swept_gap ?? null,
      verdict: row.verdict, answers: row.answers, status: row.status ?? null, conclusive: row.conclusive,
      runtime_verified: row.runtime_verified ?? null, measured_damage: row.measured_damage ?? null,
      evidence: rec.evidence ?? null, timing: rec.timing ?? null, reason: row.reason ?? null,
      recorded_at: row.recorded_at ?? null, started_at_frame: row.started_at_frame ?? null,
      quality_flags: row.quality_flags, supersedes: row.supersedes ?? null, supersedes_id: null,
      derived: row.derived ?? {}, payload: rec,
      row, // the labrows row the evaluation reads; not a column
    })
  }
  for (const run of runs.values()) {
    if (!run.supersedes) continue
    const key = locations.get(`${run.supersedes.source_file}\u0000${run.supersedes.line_no}`)
    if (!key) throw new Error(`${run.source_file}:${run.line_no} supersedes a line that produced no run`)
    run.supersedes_id = runs.get(key).id
  }

  // --- the SQL -------------------------------------------------------------------------------
  const generatedAt = new Date()
  const stamp = generatedAt.toISOString().replace(/[-:]/g, '').replace(/\.\d+Z$/, 'Z')
  const tables = ['import_batches', 'catalog_snapshots', 'calibration_profiles', 'test_contexts', 'routes', 'route_steps', 'route_definitions', 'runs', 'run_sources', ...EVAL_TABLES]
  const report = tables.map((t) => `select '${t}' as lab_table, (select n from _lab_before where t = '${t}') as rows_before, (select count(*) from lab.${t}) as rows_after`).join('\nunion all\n')

  const body = []
  body.push(`-- lab import generated by tools/db/lab-import.mjs at ${stamp}
-- tool commit ${toolCommit ?? 'unknown'}${toolDirty ? ' (working tree had uncommitted changes)' : ''}; ${labrowsVersion}
-- ${trialFiles.length} trial file(s), ${[...runs.values()].length} distinct run(s) from ${sources.length} line(s),
-- ${calibrations.size} calibration profile(s), ${definitions.length} route definition(s).
--
-- Every insert is ON CONFLICT DO NOTHING on a key derived from content, so
-- running this file again adds nothing. Needs knowledge-db's lab schema
-- migration. Generated; do not edit by hand - regenerate with npm run lab:sql.

set client_encoding = 'UTF8';
drop table if exists pg_temp._lab_before;
begin;

-- Kept past COMMIT (dropped with the session) so the report after it can read it.
create temp table _lab_before as
${tables.map((t) => `select '${t}'::text as t, count(*) as n from lab.${t}`).join('\nunion all\n')};
`)

  body.push(insert('lab.import_batches',
    ['id', 'source_kind', 'source_file', 'file_sha256', 'byte_size', 'line_count', 'rows_emitted', 'tool', 'tool_commit', 'tool_dirty', 'labrows_version', 'notes'],
    [...batches.values()].map((b) => [sql.uuid(b.id), sql.text(b.source_kind), sql.text(b.source_file), sql.text(b.file_sha256), sql.int(b.byte_size), sql.int(b.line_count), sql.int(b.rows_emitted), sql.text('tools/db/lab-import.mjs'), sql.text(toolCommit), sql.bool(toolDirty), sql.text(labrowsVersion), sql.jsonb(b.notes ?? null)]),
    'on conflict do nothing'))

  body.push(insert('lab.catalog_snapshots', ['id', 'character', 'ac_sha256', 'bcm_sha256', 'first_seen_in'],
    [...snapshots.values()].map((s) => [sql.uuid(s.id), sql.text(s.character), sql.text(s.ac_sha256), sql.text(s.bcm_sha256), sql.text(s.first_seen_in)]),
    'on conflict do nothing'))

  body.push(`create temp table _lab_calibrations (like lab.calibration_profiles including defaults) on commit drop;\n`)
  body.push(insert('_lab_calibrations',
    ['id', 'calibration_id', 'character', 'control_scheme', 'game_patch', 'catalog_snapshot_id', 'generated_at', 'values_json', 'payload', 'payload_sha256', 'source_path', 'import_batch_id'],
    [...calibrations.values()].map((c) => [sql.uuid(c.id), sql.text(c.calibration_id), sql.text(c.character), sql.text(c.control_scheme), sql.text(c.game_patch), sql.uuid(c.catalog_snapshot_id), sql.ts(c.generated_at), sql.jsonb(c.values), sql.jsonb(c.payload), sql.text(c.payload_sha256), sql.text(c.source_path), sql.uuid(c.import_batch_id)]),
    ''))
  body.push(`insert into lab.calibration_profiles select * from _lab_calibrations on conflict (calibration_id) do nothing;

do $check$
declare n int;
begin
  select count(*) into n from _lab_calibrations s join lab.calibration_profiles p using (calibration_id)
   where p.payload is distinct from s.payload;
  if n > 0 then
    raise exception 'lab import: % calibration profile(s) already stored under the same calibration_id with different content', n;
  end if;
end $check$;
`)

  body.push(insert('lab.test_contexts',
    ['id', 'schema', 'canonical', 'context_hash', 'counter_state', 'positions_controlled', 'resources_pinned', 'screen_position', 'opponent_character', 'payload'],
    [...contexts.values()].map((c) => [sql.uuid(c.id), sql.text(c.schema), sql.text(c.canonical), sql.text(c.context_hash), sql.text(c.counter_state), sql.bool(c.positions_controlled), sql.bool(c.resources_pinned), sql.text(c.screen_position), sql.text(c.opponent_character ?? null), sql.jsonb(c.payload)]),
    'on conflict do nothing'))

  body.push(insert('lab.routes', ['id', 'character', 'control_scheme', 'shape_key', 'step_count', 'steps', 'catalog_snapshot_id'],
    [...routes.values()].map((r) => [sql.uuid(r.id), sql.text(r.character), sql.text(r.control_scheme), sql.text(r.shape_key), sql.int(r.steps.length), sql.jsonb(r.steps), sql.uuid(r.catalog_snapshot_id)]),
    'on conflict do nothing'))

  body.push(insert('lab.route_steps', ['route_id', 'step_no', 'kind', 'action_id', 'input_method', 'notation'],
    [...routes.values()].flatMap((r) => r.steps.map((s) => [sql.uuid(r.id), sql.int(s.step_no), sql.text(s.kind), sql.int(s.action_id ?? null), sql.text(s.input_method ?? null), sql.text(s.notation ?? null)])),
    'on conflict do nothing'))

  body.push(insert('lab.route_definitions', ['id', 'definition_id', 'character', 'control_scheme', 'route_id', 'source_path', 'file_sha256', 'payload', 'import_batch_id'],
    definitions.map((d) => [sql.uuid(d.id), sql.text(d.definition_id), sql.text(d.character), sql.text(d.control_scheme), sql.uuid(d.route_id), sql.text(d.source_path), sql.text(d.file_sha256), sql.jsonb(d.payload), sql.uuid(d.import_batch_id)]),
    'on conflict do nothing'))

  const runColumns = ['id', 'event_key', 'payload_hash', 'source_file', 'line_no', 'import_batch_id', 'record_id', 'schema', 'character', 'control_scheme', 'game_patch', 'calibration_id', 'calibration_profile_id', 'context_id', 'route_id', 'test_kind', 'subject_kind', 'subject_id', 'recorded_subject_kind', 'recorded_subject_id', 'attempt', 'delays', 'swept_gap', 'verdict', 'answers', 'status', 'conclusive', 'runtime_verified', 'measured_damage', 'evidence', 'timing', 'reason', 'recorded_at', 'started_at_frame', 'quality_flags', 'supersedes_id', 'derived', 'payload']
  body.push(`create temp table _lab_runs (like lab.runs including defaults) on commit drop;\n`)
  body.push(insert('_lab_runs', runColumns,
    [...runs.values()].map((r) => [sql.uuid(r.id), sql.text(r.event_key), sql.text(r.payload_hash), sql.text(r.source_file), sql.int(r.line_no), sql.uuid(r.import_batch_id), sql.text(r.record_id), sql.text(r.schema), sql.text(r.character), sql.text(r.control_scheme), sql.text(r.game_patch), sql.text(r.calibration_id), sql.uuid(r.calibration_profile_id), sql.uuid(r.context_id), sql.uuid(r.route_id), sql.text(r.test_kind), sql.text(r.subject_kind), sql.text(r.subject_id), sql.text(r.recorded_subject_kind), sql.text(r.recorded_subject_id), sql.int(r.attempt), sql.intArray(r.delays), sql.int(r.swept_gap), sql.text(r.verdict), sql.text(r.answers), sql.text(r.status), sql.bool(r.conclusive), sql.bool(r.runtime_verified), sql.int(r.measured_damage), sql.jsonb(r.evidence), sql.jsonb(r.timing), sql.text(r.reason), sql.ts(r.recorded_at), sql.int(r.started_at_frame), sql.textArray(r.quality_flags), sql.uuid(r.supersedes_id), sql.jsonb(r.derived), sql.jsonb(r.payload)]),
    ''))
  body.push(`-- The rows nothing supersedes first, so a superseding row's reference exists.
insert into lab.runs select * from _lab_runs where supersedes_id is null on conflict (event_key) do nothing;
insert into lab.runs select * from _lab_runs where supersedes_id is not null on conflict (event_key) do nothing;

do $check$
declare n int;
begin
  select count(*) into n from _lab_runs s join lab.runs r using (event_key)
   where r.payload is distinct from s.payload;
  if n > 0 then
    raise exception 'lab import: % run(s) share an event_key with a stored run but not its content', n;
  end if;
end $check$;
`)

  body.push(insert('lab.run_sources', ['run_id', 'import_batch_id', 'source_file', 'file_sha256', 'line_no', 'quality_flags'],
    sources.map((s) => [sql.uuid(runs.get(s.event_key).id), sql.uuid(s.import_batch_id), sql.text(s.source_file), sql.text(s.file_sha256), sql.int(s.line_no), sql.textArray(s.quality_flags)]),
    'on conflict do nothing'))

  // Evaluations last: they reference the runs above, and they are computed over
  // exactly the runs this file carries. computed_at is when this file was
  // generated, not when it is applied, so applying an older file later does not
  // make its evaluations the current ones.
  const evaluated = buildEvaluations({
    lua, root: ROOT, runs, sources, toolCommit, computedAt: generatedAt.toISOString(),
    helpers: { sql, uuidFor, sha256, insert },
  })
  body.push(evaluated.sqlText)

  const sqlText = body.join('\n')
  // `supabase db query` shows the LAST statement's result. So the real file
  // reports after COMMIT, and the dry run ends in an exception whose message is
  // the report - the error rolls the transaction back by itself, whatever the
  // client does with the ROLLBACK after it.
  const realEnd = `\ncommit;\n\n-- What this import changed.\n${report}\norder by 1;\n`
  const dryEnd = `
do $dry$
declare msg text;
begin
  select string_agg(format('%s %s -> %s', lab_table, rows_before, rows_after), ', ' order by lab_table) into msg
    from (
${report}
    ) as r;
  raise exception 'DRY RUN, nothing kept. Rows before -> after: %', msg;
end $dry$;
rollback;
`

  mkdirSync(OUT_DIR, { recursive: true })
  const realPath = join(OUT_DIR, `lab-import-${stamp}.sql`)
  const dryPath = join(OUT_DIR, `lab-import-${stamp}.dryrun.sql`)
  writeFileSync(realPath, sqlText + realEnd, 'utf8')
  writeFileSync(dryPath, sqlText.replace('set client_encoding', '-- DRY RUN: ends in an exception carrying the report, then ROLLBACK. Nothing is kept.\nset client_encoding') + dryEnd, 'utf8')

  const flagCounts = {}
  for (const r of runs.values()) for (const f of r.quality_flags) flagCounts[f] = (flagCounts[f] ?? 0) + 1
  console.log(`trial lines ${sources.length}, distinct runs ${runs.size}, contexts ${contexts.size}, routes ${routes.size}, calibrations ${calibrations.size}, route definitions ${definitions.length}, batches ${batches.size}`)
  console.log('quality flags over distinct runs:', JSON.stringify(flagCounts))
  const ev = evaluated.summary
  console.log(`evaluations (${evaluated.policy.policy_key}): ${evaluated.evaluations.length} over ${evaluated.evaluationRuns.length} run(s)`)
  console.log('  by subject kind and result:', JSON.stringify(ev.by_kind_result))
  console.log('  excluded runs by reason:', JSON.stringify(ev.excluded_by_reason))
  console.log(`wrote ${relative(ROOT, realPath)} (${Buffer.byteLength(sqlText + realEnd)} bytes)`)
  console.log(`wrote ${relative(ROOT, dryPath)}`)
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main()
}
