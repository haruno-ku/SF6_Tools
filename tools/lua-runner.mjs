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
import { existsSync, readdirSync, statSync } from 'node:fs'
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
    ...walk('reframework/autorun/func/ComboExplorer'),
    ...walk('tests/lua'),
  ]
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
  console.log(bad === 0 ? `syntax ok: ${files.length} Lua files` : `${bad} of ${files.length} files failed to parse`)
  process.exit(bad === 0 ? 0 : 1)
}

const lua = resolve('lua')
if (!lua) {
  console.error('lua not found. Install Lua 5.4:  winget install --id DEVCOM.Lua')
  console.error('(a shell opened before the install will not have it on PATH yet)')
  process.exit(2)
}

const r = spawnSync(lua, ['tests/lua/run.lua'], { stdio: 'inherit' })
process.exit(r.status ?? 1)
