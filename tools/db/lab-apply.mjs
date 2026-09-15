// Sends one generated lab import file to a database (haruno-ku/SF6_Tools#38).
//
//   npm run lab:apply -- [--dry-run] [db/out/lab-import-<stamp>.sql]
//
// With no file, the newest db/out/lab-import-*.sql. With --dry-run (or when the
// file named is a .dryrun.sql), the .dryrun.sql beside it: that file ends in an
// exception carrying the row report, so here the exception IS the success, and
// anything else is a failure.
//
// THE CONNECTION
//
// LAB_DB_URL, e.g. for Supabase the session pooler (port 5432) as the import login:
//   postgresql://lab_importer.<project-ref>:<password>@aws-0-<region>.pooler.supabase.com:5432/postgres
// The password is never printed; only host, port, user and database are.
//
// Why this and not the Supabase CLI (docs/ComboExplorer/LAB-DB.md): the
// Management API refuses a multi-megabyte body (413), the direct host is
// IPv6-only, and the CLI sends the file over the extended protocol, which
// refuses more than one statement. `pg`'s client.query(text) with no parameters
// is the simple query protocol, so the whole file goes in one round trip. The
// transaction pooler (6543) is refused here: the import needs temp tables that
// live for the session.
//
// TLS: to a non-local host the connection is encrypted. With LAB_DB_CA_FILE
// (Supabase's server root certificate, from the dashboard's database settings)
// the server certificate is verified; without it the connection is encrypted
// but not verified, and this says so. `sslmode=disable` in the URL turns TLS off
// (for a local database).

import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs'
import { basename, dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..')
const OUT_DIR = join(ROOT, 'db', 'out')
const DRY_RUN_MARK = /^DRY RUN, nothing kept\./

function die(msg, code = 1) {
  console.error(`lab-apply: ${msg}`)
  process.exit(code)
}

export function pickFile(argFile, dryRun) {
  let file = argFile
  if (!file) {
    const latest = existsSync(OUT_DIR)
      ? readdirSync(OUT_DIR).filter((n) => /^lab-import-.*\.sql$/.test(n) && !n.endsWith('.dryrun.sql')).sort().pop()
      : null
    if (!latest) die('no db/out/lab-import-*.sql - run npm run lab:sql first')
    file = join(OUT_DIR, latest)
  }
  file = resolve(file)
  const isDry = file.endsWith('.dryrun.sql')
  if (dryRun && !isDry) file = file.replace(/\.sql$/, '.dryrun.sql')
  if (!existsSync(file)) die(`${file} does not exist`)
  return { file, dryRun: dryRun || isDry }
}

// Everything but the password, for printing.
export function describeUrl(raw) {
  const u = new URL(raw)
  return { host: u.hostname, port: u.port || '5432', user: decodeURIComponent(u.username), database: u.pathname.replace(/^\//, '') || 'postgres' }
}

export function clientConfig(raw, env = process.env) {
  let u
  try { u = new URL(raw) } catch { die('LAB_DB_URL is not a URL (postgresql://user:password@host:port/database)') }
  if (!/^postgres(ql)?:$/.test(u.protocol)) die('LAB_DB_URL must start with postgresql://')
  const d = describeUrl(raw)
  if (d.port === '6543') die('port 6543 is the transaction pooler; the import needs session temp tables - use the session pooler on 5432')
  const local = ['localhost', '127.0.0.1', '::1', '[::1]'].includes(d.host)
  const sslmode = u.searchParams.get('sslmode')
  let ssl = false
  let tls = 'off'
  if (sslmode !== 'disable' && !local) {
    if (env.LAB_DB_CA_FILE) {
      ssl = { ca: readFileSync(env.LAB_DB_CA_FILE, 'utf8'), rejectUnauthorized: true }
      tls = `verified against ${basename(env.LAB_DB_CA_FILE)}`
    } else {
      ssl = { rejectUnauthorized: false }
      tls = 'encrypted, server certificate NOT verified (set LAB_DB_CA_FILE to verify)'
    }
  }
  return {
    config: {
      host: d.host.replace(/^\[|\]$/g, ''), port: Number(d.port), user: d.user, database: d.database,
      password: decodeURIComponent(u.password), ssl, application_name: 'sf6-lab-apply',
    },
    described: d,
    tls,
  }
}

async function main() {
  const args = process.argv.slice(2)
  const dryFlag = args.includes('--dry-run')
  const rest = args.filter((a) => a !== '--dry-run')
  if (rest.length > 1) die('one file at a time')
  const { file, dryRun } = pickFile(rest[0], dryFlag)

  const url = process.env.LAB_DB_URL
  if (!url) die('LAB_DB_URL is not set (see docs/ComboExplorer/LAB-DB.md)', 2)
  const { config, described, tls } = clientConfig(url)

  let pg
  try { pg = (await import('pg')).default } catch { die('the pg package is missing - run npm install in SF6_Tools', 2) }

  const sqlText = readFileSync(file, 'utf8')
  console.log(`file     ${file} (${statSync(file).size} bytes)${dryRun ? '  [DRY RUN]' : ''}`)
  console.log(`database ${described.user}@${described.host}:${described.port}/${described.database}  tls: ${tls}`)

  const client = new pg.Client(config)
  client.on('notice', (n) => console.log(`NOTICE   ${n.message}`))
  const started = Date.now()
  try {
    await client.connect()
  } catch (e) {
    die(`could not connect: ${e.message}`)
  }

  let exit = 0
  let failed = true
  try {
    const result = await client.query(sqlText)   // no parameters: simple query protocol
    if (dryRun) {
      console.error('lab-apply: the dry run did not end in its DRY RUN exception - something in the file is wrong; rolling back')
      exit = 1
    } else {
      const results = Array.isArray(result) ? result : [result]
      const report = [...results].reverse().find((r) => r.rows && r.rows.length > 0 && 'lab_table' in r.rows[0])
      if (report) {
        console.log('\nrows before -> after')
        for (const r of report.rows) console.log(`  ${r.lab_table.padEnd(22)} ${String(r.rows_before).padStart(6)} -> ${r.rows_after}`)
      }
      console.log(`\napplied in ${((Date.now() - started) / 1000).toFixed(1)} s`)
      failed = false
    }
  } catch (e) {
    if (dryRun && DRY_RUN_MARK.test(e.message)) {
      const [head, list] = e.message.split(': ')
      console.log(`\n${head}:`)
      for (const part of (list ?? '').split(', ')) console.log(`  ${part}`)
      console.log(`\ndry run finished in ${((Date.now() - started) / 1000).toFixed(1)} s`)
    } else {
      console.error(`lab-apply: ${e.message}${e.where ? `\n  where: ${e.where}` : ''}`)
      exit = 1
    }
  } finally {
    // A failed statement inside the file's BEGIN leaves the session in an
    // aborted transaction (the dry run always does); end it before disconnecting.
    if (failed) await client.query('rollback').catch(() => {})
    await client.end().catch(() => {})
  }
  process.exit(exit)
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main()
}
