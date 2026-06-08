// AeSH executor — runs the command AST.
// bash: pipelines/redirects/logic/$(())/$()/globs. zsh/fish: history. elvish: structured builtins.
import { parse, type CommandList, type Pipeline, type SimpleCommand, type Word } from "./parser";
import * as fs from "fs";
import * as path from "path";

export interface ShellState {
  cwd: string;
  env: Record<string, string>;
  lastExit: number;
  history: string[];
  shouldExit: boolean;
  exitCode: number;
}

export function newState(): ShellState {
  return {
    cwd: process.cwd(),
    env: { ...process.env } as Record<string, string>,
    lastExit: 0, history: [], shouldExit: false, exitCode: 0,
  };
}

export interface IOHandles { out: (s: string) => void; err: (s: string) => void; capture?: boolean; }

// ---- expansion ----
function evalArith(expr: string): number {
  let i = 0; const s = expr;
  const skip = () => { while (i < s.length && /\s/.test(s[i])) i++; };
  function prim(): number {
    skip();
    if (s[i] === "(") { i++; const v = add(); skip(); if (s[i] === ")") i++; return v; }
    if (s[i] === "-") { i++; return -prim(); }
    if (s[i] === "+") { i++; return prim(); }
    let num = ""; while (i < s.length && /[0-9]/.test(s[i])) num += s[i++];
    return num ? parseInt(num, 10) : 0;
  }
  function mul(): number { let v = prim(); for (;;) { skip(); const o = s[i];
    if (o === "*") { i++; v *= prim(); } else if (o === "/") { i++; const d = prim(); v = d ? Math.trunc(v / d) : 0; }
    else if (o === "%") { i++; const d = prim(); v = d ? v % d : 0; } else break; } return v; }
  function add(): number { let v = mul(); for (;;) { skip(); const o = s[i];
    if (o === "+") { i++; v += mul(); } else if (o === "-") { i++; v -= mul(); } else break; } return v; }
  return add();
}

// Expand a single expandable string: $((arith)), $(cmd-subst), ${VAR}, $?, $VAR, leading ~.
async function expandStr(text: string, st: ShellState, sub: (line: string) => Promise<string>): Promise<string> {
  let out = text;
  if (out.startsWith("~")) out = (st.env.HOME ?? "") + out.slice(1);

  // arithmetic $(( ... )) — innermost-first via simple scan
  out = out.replace(/\$\(\((.*?)\)\)/g, (_, e: string) => {
    const inner = e.replace(/\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?/g, (_m, n) => st.env[n] ?? "0");
    try { return String(evalArith(inner)); } catch { return "0"; }
  });

  // command substitution $( ... ) — handle balanced parens, left-to-right
  for (;;) {
    const start = out.indexOf("$(");
    if (start < 0) break;
    let depth = 0, j = start + 1, end = -1;
    for (; j < out.length; j++) { if (out[j] === "(") depth++; else if (out[j] === ")") { depth--; if (depth === 0) { end = j; break; } } }
    if (end < 0) break; // unbalanced; leave as-is
    const cmd = out.slice(start + 2, end);
    const captured = (await sub(cmd)).replace(/\n+$/,"");
    out = out.slice(0, start) + captured + out.slice(end + 1);
  }

  out = out.replace(/\$\{([A-Za-z_][A-Za-z0-9_]*)\}/g, (_, n) => st.env[n] ?? "");
  out = out.replace(/\$\?/g, () => String(st.lastExit));
  out = out.replace(/\$([A-Za-z_][A-Za-z0-9_]*)/g, (_, n) => st.env[n] ?? "");
  return out;
}

function globToRegex(g: string): RegExp {
  let re = "^";
  for (let k = 0; k < g.length; k++) {
    const c = g[k];
    if (c === "*") re += "[^/]*";
    else if (c === "?") re += "[^/]";
    else if (c === "[") { let cls = "["; k++; while (k < g.length && g[k] !== "]") cls += g[k++]; cls += "]"; re += cls; }
    else re += c.replace(/[.+^${}()|\\]/g, "\\$&");
  }
  return new RegExp(re + "$");
}

function globExpand(pattern: string, cwd: string): string[] {
  const dir = pattern.includes("/") ? path.dirname(pattern) : ".";
  const base = pattern.includes("/") ? path.basename(pattern) : pattern;
  const absDir = path.resolve(cwd, dir);
  let entries: string[];
  try { entries = fs.readdirSync(absDir); } catch { return [pattern]; }
  const rx = globToRegex(base);
  const hits = entries.filter((e) => !e.startsWith(".") && rx.test(e)).sort()
    .map((e) => (pattern.includes("/") ? path.join(dir, e) : e));
  return hits.length ? hits : [pattern]; // nullglob off (bash default): leave pattern literal
}

// Expand one Word into zero+ argv strings (globbing may yield several).
async function expandWord(word: Word, st: ShellState, sub: (l: string) => Promise<string>): Promise<string[]> {
  let s = "";
  for (const seg of word.segs) s += seg.expand ? await expandStr(seg.text, st, sub) : seg.text;
  if (word.glob && /[*?[]/.test(s)) return globExpand(s, st.cwd);
  return [s];
}

async function expandArgv(words: Word[], st: ShellState, sub: (l: string) => Promise<string>): Promise<string[]> {
  const out: string[] = [];
  for (const w of words) out.push(...await expandWord(w, st, sub));
  return out;
}

// ---- builtins ----
type BuiltinFn = (args: string[], st: ShellState, io: IOHandles) => number | Promise<number>;
export const BUILTINS: Record<string, BuiltinFn> = {
  cd: (args, st, io) => {
    const target = args[0] ?? st.env.HOME ?? st.cwd;
    const p = path.resolve(st.cwd, target);
    try { if (!fs.statSync(p).isDirectory()) { io.err(`cd: not a directory: ${target}\n`); return 1; } st.cwd = p; st.env.PWD = p; return 0; }
    catch { io.err(`cd: no such directory: ${target}\n`); return 1; }
  },
  pwd: (_a, st, io) => { io.out(st.cwd + "\n"); return 0; },
  exit: (args, st) => { st.shouldExit = true; st.exitCode = args[0] ? parseInt(args[0], 10) || 0 : st.lastExit; return st.exitCode; },
  export: (args, st) => { for (const a of args) { const eq = a.indexOf("="); if (eq >= 0) st.env[a.slice(0, eq)] = a.slice(eq + 1); else if (!(a in st.env)) st.env[a] = ""; } return 0; },
  unset: (args, st) => { for (const a of args) delete st.env[a]; return 0; },
  set: (_a, st, io) => { for (const k of Object.keys(st.env).sort()) io.out(`${k}=${st.env[k]}\n`); return 0; },
  history: (_a, st, io) => { st.history.forEach((h, i) => io.out(`${String(i + 1).padStart(5)}  ${h}\n`)); return 0; },
  echo: (args, _st, io) => { io.out(args.join(" ") + "\n"); return 0; },
  true: () => 0, false: () => 1, ":": () => 0,
  help: (_a, _st, io) => { io.out("aesh builtins: cd pwd exit export unset set history echo true false help type\n"); io.out("features: | && || ; > >> <  $(())  $(...)  globs(* ? [])  'literal'  \"expand\"\n"); return 0; },
  type: (args, _st, io) => { for (const a of args) io.out(`${a} is ${a in BUILTINS ? "a shell builtin" : "external"}\n`); return 0; },
};

// subshell: run a line capturing stdout, return it (for $( ... )).
async function subshell(line: string, st: ShellState): Promise<string> {
  let buf = "";
  const io: IOHandles = { out: (s) => (buf += s), err: () => {}, capture: true };
  try { await execList(parse(line.trim()), st, io); } catch { /* leave partial */ }
  return buf;
}

async function runSimple(cmd: SimpleCommand, st: ShellState, io: IOHandles): Promise<number> {
  const sub = (l: string) => subshell(l, st);
  const argv = await expandArgv(cmd.argv, st, sub);
  if (argv.length === 0) return 0;
  const name = argv[0];
  if (name in BUILTINS && cmd.redirects.length === 0) return await BUILTINS[name](argv.slice(1), st, io);
  return await spawnExternal([{ cmd, argv }], st, io);
}

async function spawnExternal(stages: { cmd: SimpleCommand; argv: string[] }[], st: ShellState, io: IOHandles): Promise<number> {
  const sub = (l: string) => subshell(l, st);
  const procs: { proc: any; isLast: boolean; redirectedOut: boolean }[] = [];
  let prevStdout: any = "inherit";
  for (let idx = 0; idx < stages.length; idx++) {
    const { cmd } = stages[idx];
    const argv = stages[idx].argv;
    const isLast = idx === stages.length - 1;
    let redirectedOut = false;
    let stdin: any = idx === 0 ? "inherit" : prevStdout;
    let stdout: any = isLast ? (io.capture ? "pipe" : "inherit") : "pipe";
    let stderr: any = io.capture ? "pipe" : "inherit";
    for (const r of cmd.redirects) {
      const tgt = (await expandWord(r.target, st, sub))[0];
      if (r.op === "<") stdin = fs.openSync(tgt, "r");
      else if (r.op === ">") { stdout = fs.openSync(tgt, "w"); redirectedOut = true; }
      else if (r.op === ">>") { stdout = fs.openSync(tgt, "a"); redirectedOut = true; }
    }
    let proc: any;
    try { proc = Bun.spawn(argv, { cwd: st.cwd, env: st.env, stdin, stdout, stderr }); }
    catch (e) { io.err(`aesh: ${argv[0]}: ${(e as Error).message}\n`); return 127; }
    procs.push({ proc, isLast, redirectedOut });
    prevStdout = proc.stdout;
  }
  const drains: Promise<void>[] = [];
  for (const { proc, isLast, redirectedOut } of procs) {
    if (io.capture && proc.stderr && typeof proc.stderr !== "number") drains.push(new Response(proc.stderr).text().then((t) => { if (t) io.err(t); }));
    if (io.capture && isLast && !redirectedOut && proc.stdout && typeof proc.stdout !== "number") drains.push(new Response(proc.stdout).text().then((t) => { if (t) io.out(t); }));
  }
  let code = 0;
  for (const { proc } of procs) code = await proc.exited;
  await Promise.all(drains);
  return code;
}

async function runPipeline(pl: Pipeline, st: ShellState, io: IOHandles): Promise<number> {
  if (pl.commands.length === 1) return runSimple(pl.commands[0], st, io);
  const sub = (l: string) => subshell(l, st);
  const stages = [];
  for (const c of pl.commands) stages.push({ cmd: c, argv: await expandArgv(c.argv, st, sub) });
  return spawnExternal(stages, st, io);
}

export async function execList(list: CommandList, st: ShellState, io: IOHandles): Promise<number> {
  let code = st.lastExit;
  let skip = false;
  for (const item of list.items) {
    if (!skip) {
      code = await runPipeline(item.pipeline, st, io);
      st.lastExit = code;
      if (st.shouldExit) return st.exitCode;
    }
    if (item.op === "&&") skip = code !== 0;
    else if (item.op === "||") skip = code === 0;
    else skip = false;
  }
  return code;
}

export async function runLine(line: string, st: ShellState, io: IOHandles): Promise<number> {
  const trimmed = line.trim();
  if (!trimmed) return st.lastExit;
  if (trimmed !== st.history[st.history.length - 1]) st.history.push(trimmed);
  let list: CommandList;
  try { list = parse(trimmed); }
  catch (e) { io.err(`aesh: parse error: ${(e as Error).message}\n`); st.lastExit = 2; return 2; }
  return execList(list, st, io);
}
