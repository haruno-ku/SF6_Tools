// Evaluations over the imported runs, as SQL appended to the lab import
// (haruno-ku/SF6_Tools#38 section 8, Phase B). Called by tools/db/lab-import.mjs;
// connects to nothing.
//
// WHO DOES WHAT
//
// tools/lua/labeval.lua is the policy: which runs count, how a pair folds
// (ConfirmedEdge), how a route is confirmed (SweepReport.combo_status), and the
// result. tools/lua/labeval-cli.lua prints what it decided. This file does what
// the import already does for runs and nothing more: hashes, ids, SQL literals.
//
//   evaluation_policies.id  uuidv8('lab.evaluation_policies', policy_key)
//   evaluations.cohort_hash sha256(cohort_key), an index; cohort_key is stored beside it
//   evidence_set_hash       sha256(the evidence_set text labeval builds: the policy
//                           key and version, then one sorted line per run with its
//                           event_key, inclusion and exclusion reason)
//   evaluations.id          uuidv8('lab.evaluations', policy, subject kind, subject,
//                           cohort_key, evidence_set_hash)
//
// So the same runs under the same policy give the same evaluation id in every
// database, and a run that arrives later, or a flag that changes what counts,
// gives a new evaluation beside the old one. Nothing is updated.
//
// Content comparison, as for runs and calibrations: after inserting, the stored
// policy rules and each stored evaluation's result, counts and summary are
// compared with the incoming ones, and a difference aborts the import. A
// difference under the same id means the Lua rule changed without the policy
// key changing - which is exactly what a new policy key is for.

import { spawnSync } from 'node:child_process'

export const EVAL_TABLES = ['evaluation_policies', 'evaluations', 'evaluation_runs']

// runs    : Map event_key -> run (the lab.runs row being imported, with .row = the labrows row)
// sources : [{ event_key, source_file, line_no, quality_flags }]
export function buildEvaluations({ lua, root, runs, sources, helpers, toolCommit, computedAt, policy = null }) {
  const { sql, uuidFor, sha256, insert } = helpers

  const locations = new Map()
  for (const s of sources) {
    if (!locations.has(s.event_key)) locations.set(s.event_key, [])
    locations.get(s.event_key).push({ source_file: s.source_file, line_no: s.line_no, quality_flags: s.quality_flags })
  }
  const input = [...runs.values()].map((r) => JSON.stringify({
    ...r.row, kind: 'run', event_key: r.event_key, sources: locations.get(r.event_key) ?? [],
  })).join('\n') + '\n'

  const args = ['tools/lua/labeval-cli.lua']
  if (policy) args.push('--policy', policy)
  const cli = spawnSync(lua, args, { cwd: root, input, encoding: 'utf8', maxBuffer: 512 * 1024 * 1024 })
  if (cli.stderr) process.stderr.write(cli.stderr)
  const out = (cli.stdout ?? '').split('\n').filter((l) => l.trim() !== '').map((l, i) => {
    try { return JSON.parse(l) } catch { throw new Error(`labeval-cli line ${i + 1} is not JSON: ${l.slice(0, 200)}`) }
  })
  const problems = out.filter((r) => r.kind === 'problem')
  if (cli.status !== 0 || problems.length > 0) {
    for (const p of problems) console.error('EVALUATION PROBLEM', JSON.stringify(p))
    throw new Error(`labeval-cli exited ${cli.status} with ${problems.length} problem(s); nothing written`)
  }

  const pol = out.find((r) => r.kind === 'policy')
  if (!pol) throw new Error('labeval-cli printed no policy')
  const policyRow = {
    id: uuidFor('lab.evaluation_policies', pol.key),
    policy_key: pol.key, version: pol.version, rules: pol.rules, description: pol.description,
  }

  const evaluations = []
  const evaluationRuns = []
  const seenRuns = new Set()
  for (const ev of out.filter((r) => r.kind === 'evaluation')) {
    const evidenceSetHash = sha256(ev.evidence_set)
    const id = uuidFor('lab.evaluations', [pol.key, ev.subject_kind, ev.subject_id, ev.cohort_key, evidenceSetHash].join('\u0000'))
    // Every run in the evidence set is one this import carries, and every run
    // lands in exactly one evaluation: a subject and a cohort are both a
    // property of the run.
    const routeIds = new Set()
    for (const e of ev.runs) {
      const run = runs.get(e.event_key)
      if (!run) throw new Error(`evaluation ${ev.subject_id} names run ${e.event_key}, which this import does not carry`)
      if (seenRuns.has(e.event_key)) throw new Error(`run ${e.event_key} is in two evaluations`)
      seenRuns.add(e.event_key)
      routeIds.add(run.route_id)
      evaluationRuns.push({ evaluation_id: id, run_id: run.id, inclusion: e.inclusion, exclusion_reason: e.exclusion_reason ?? null, answer: e.answer })
    }
    if (routeIds.size > 1) throw new Error(`evaluation ${ev.subject_id} spans ${routeIds.size} routes`)
    evaluations.push({
      id, policy_id: policyRow.id, subject_kind: ev.subject_kind, subject_id: ev.subject_id,
      route_id: [...routeIds][0] ?? null, character: ev.character, control_scheme: ev.control_scheme,
      cohort_key: ev.cohort_key, cohort_hash: sha256(ev.cohort_key), evidence_set_hash: evidenceSetHash,
      result: ev.result, successful_runs: ev.successful_runs, conclusive_failures: ev.conclusive_failures,
      unanswered_runs: ev.unanswered_runs, excluded_runs: ev.excluded_runs, measured_summary: ev.measured_summary,
      combo: ev.combo,
    })
  }
  if (seenRuns.size !== runs.size) {
    throw new Error(`${runs.size} runs imported but ${seenRuns.size} evaluated: every run belongs to one subject in one cohort`)
  }

  const summary = out.find((r) => r.kind === 'summary')

  const text = []
  text.push(`
-- --- evaluations (${pol.key}: ${evaluations.length} evaluation(s) over ${evaluationRuns.length} run(s)) ---
-- The policy is tools/lua/labeval.lua; its rules are stored whole below.
create temp table _lab_policies (like lab.evaluation_policies including defaults) on commit drop;
`)
  text.push(insert('_lab_policies', ['id', 'policy_key', 'version', 'rules', 'description', 'tool_commit'],
    [[sql.uuid(policyRow.id), sql.text(policyRow.policy_key), sql.int(policyRow.version), sql.jsonb(policyRow.rules), sql.text(policyRow.description), sql.text(toolCommit)]], ''))
  text.push(`insert into lab.evaluation_policies (id, policy_key, version, rules, description, tool_commit)
select id, policy_key, version, rules, description, tool_commit from _lab_policies on conflict do nothing;

do $check$
declare n int;
begin
  select count(*) into n from _lab_policies s join lab.evaluation_policies p using (policy_key)
   where p.id <> s.id or p.version <> s.version or p.rules is distinct from s.rules;
  if n > 0 then
    raise exception 'lab import: policy % is already stored with different rules - a changed rule needs a new policy key', (select policy_key from _lab_policies limit 1);
  end if;
end $check$;

create temp table _lab_evaluations (like lab.evaluations including defaults) on commit drop;
`)
  const evColumns = ['id', 'policy_id', 'subject_kind', 'subject_id', 'route_id', 'character', 'control_scheme', 'cohort_key', 'cohort_hash', 'evidence_set_hash', 'result', 'successful_runs', 'conclusive_failures', 'unanswered_runs', 'excluded_runs', 'measured_summary', 'computed_at', 'tool_commit']
  text.push(insert('_lab_evaluations', evColumns,
    evaluations.map((e) => [sql.uuid(e.id), sql.uuid(e.policy_id), sql.text(e.subject_kind), sql.text(e.subject_id), sql.uuid(e.route_id), sql.text(e.character), sql.text(e.control_scheme), sql.text(e.cohort_key), sql.text(e.cohort_hash), sql.text(e.evidence_set_hash), sql.text(e.result), sql.int(e.successful_runs), sql.int(e.conclusive_failures), sql.int(e.unanswered_runs), sql.int(e.excluded_runs), sql.jsonb(e.measured_summary), sql.ts(computedAt), sql.text(toolCommit)]),
    ''))
  text.push(`insert into lab.evaluations (${evColumns.join(', ')})
select ${evColumns.join(', ')} from _lab_evaluations on conflict do nothing;

do $check$
declare n int;
begin
  select count(*) into n from _lab_evaluations s join lab.evaluations e using (id)
   where (e.result, e.successful_runs, e.conclusive_failures, e.unanswered_runs, e.excluded_runs, e.route_id, e.cohort_key)
         is distinct from (s.result, s.successful_runs, s.conclusive_failures, s.unanswered_runs, s.excluded_runs, s.route_id, s.cohort_key)
      or e.measured_summary is distinct from s.measured_summary;
  if n > 0 then
    raise exception 'lab import: % evaluation(s) already stored under the same evidence set with a different result - a changed rule needs a new policy key', n;
  end if;
end $check$;

create temp table _lab_evaluation_runs (like lab.evaluation_runs including defaults) on commit drop;
`)
  const erColumns = ['evaluation_id', 'run_id', 'inclusion', 'exclusion_reason', 'answer']
  text.push(insert('_lab_evaluation_runs', erColumns,
    evaluationRuns.map((r) => [sql.uuid(r.evaluation_id), sql.uuid(r.run_id), sql.text(r.inclusion), sql.text(r.exclusion_reason), sql.text(r.answer)]),
    ''))
  text.push(`insert into lab.evaluation_runs (${erColumns.join(', ')})
select ${erColumns.join(', ')} from _lab_evaluation_runs on conflict do nothing;

do $check$
declare n int;
begin
  select count(*) into n from _lab_evaluation_runs s join lab.evaluation_runs r using (evaluation_id, run_id)
   where (r.inclusion, r.exclusion_reason, r.answer) is distinct from (s.inclusion, s.exclusion_reason, s.answer);
  if n > 0 then
    raise exception 'lab import: % evaluation run(s) stored with a different inclusion', n;
  end if;
end $check$;
`)

  return { sqlText: text.join('\n'), policy: policyRow, evaluations, evaluationRuns, summary }
}
