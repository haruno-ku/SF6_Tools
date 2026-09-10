// Locates a Lua 5.4 interpreter and runs the Explorer's Lua checks with it.
//
// Two jobs:
//   node tools/lua-runner.mjs test     -- run the unit tests
//   node tools/lua-runner.mjs syntax   -- luac -p every Explorer Lua file
//
// The syntax pass matters more than it looks. Most of the game-side code
// (hooks, sdk reads, imgui) cannot be unit-tested off the machine running SF6,
// so a parse error would otherwise be discovered by REFramework at load time on
// the other PC -- a slow round trip for a typo.
//
// winget puts lua.exe on the user PATH, but a shell started before the install
// will not see it, so the known install location is tried as a fallback.

import { spawnSync } from 'node:child_process'
import { existsSync, readdirSync, statSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { homedir } from 'node:os'

const CANDIDATES = [
  'lua',
  'lua5.4',
  'lua54',
  join(homedir(), 'AppData', 'Local', 'Programs', 'Lua', 'bin', 'lua.exe'),
  'C:\\Program Files\\Lua\\bin\\lua.exe',
]

function resolve(binary) {
  for (const c of CANDIDATES) {
    const exe = c.endsWith('lua.exe') ? c.replace(/lua\.exe$/, `${binary}.exe`) : c.replace(/lua$/, binary)
    const probe = spawnSync(exe, ['-v'], { encoding: 'utf8' })
    if (probe.status === 0 || (probe.stdout ?? '').startsWith('Lua') || (probe.stderr ?? '').startsWith('Lua')) {
      return exe
    }
  }
  return null
}

function walk(dir, out = []) {
  if (!existsSync(dir)) return out
  for (const name of readdirSync(dir)) {
    const p = join(dir, name)
    if (statSync(p).isDirectory()) walk(p, out)
    else if (name.endsWith('.lua')) out.push(p)
  }
  return out
}

const mode = process.argv[2] ?? 'test'

if (mode === 'syntax') {
  const luac = resolve('luac')
  if (!luac) {
    console.error('luac not found. Install Lua 5.4:  winget install --id DEVCOM.Lua')
    process.exit(2)
  }
  // Only our own files: upstream's are not ours to police, and several are
  // large enough that checking them on every run is pure latency.
  const files = [
    'reframework/autorun/ComboExplorer.lua',
    ...walk('reframework/autorun/func/ComboExplorer'),
    ...walk('tests/lua'),
  ].filter((f) => existsSync(f))
  if (files.length === 0) {
    console.error('no Lua files found - wrong working directory? Run from the repo root.')
    process.exit(2)
  }
  let bad = 0
  for (const f of files) {
    const r = spawnSync(luac, ['-p', f], { encoding: 'utf8' })
    if (r.status !== 0) {
      bad++
      console.error(`SYNTAX  ${f}\n        ${(r.stderr ?? '').trim()}`)
    }
  }

  // luac -p parses; it does not resolve requires. A typo in a require path is
  // therefore invisible here and surfaces as a load failure on the machine
  // running the game - the slowest possible place to find it, given that
  // machine is somewhere else.
  //
  // REFramework resolves require("func/X/Y") relative to reframework/autorun,
  // so the check is a file-existence test against that root.
  // Comments are stripped first: these files explain the require convention in
  // prose, and a require inside a comment is not a require. Block comments go,
  // then everything from the first `--` on a line. A `--` inside a string
  // literal would truncate that line early, which can only cause a require to
  // be MISSED, never falsely reported - and no require in this codebase follows
  // a string on the same line.
  const strip_comments = (src) =>
    src.replace(/--\[\[[\s\S]*?\]\]/g, '')
       .split('\n')
       .map((line) => {
         const i = line.indexOf('--')
         return i === -1 ? line : line.slice(0, i)
       })
       .join('\n')

  let unresolved = 0
  let checked = 0
  for (const f of files) {
    const src = strip_comments(readFileSync(f, 'utf8'))
    for (const m of src.matchAll(/require\s*\(\s*(['"])([^'"]+)\1\s*\)/g)) {
      const target = m[2]
      if (!target.startsWith('func/')) continue   // stdlib or REFramework-provided
      checked++
      const path = join('reframework', 'autorun', `${target}.lua`)
      if (!existsSync(path)) {
        unresolved++
        console.error(`REQUIRE ${f}\n        require("${target}") does not resolve to ${path}`)
      }
    }
  }

  if (bad === 0 && unresolved === 0) {
    console.log(`syntax ok: ${files.length} Lua files, ${checked} require targets resolve`)
  } else {
    if (bad) console.error(`${bad} of ${files.length} files failed to parse`)
    if (unresolved) console.error(`${unresolved} of ${checked} require targets do not resolve`)
  }
  process.exit(bad === 0 && unresolved === 0 ? 0 : 1)
}

const lua = resolve('lua')
if (!lua) {
  console.error('lua not found. Install Lua 5.4:  winget install --id DEVCOM.Lua')
  console.error('(a shell opened before the install will not have it on PATH yet)')
  process.exit(2)
}

const r = spawnSync(lua, ['tests/lua/run.lua'], { stdio: 'inherit' })
process.exit(r.status ?? 1)
