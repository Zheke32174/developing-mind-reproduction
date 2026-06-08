// AeSH executor — runs the command AST.
// bash: pipelines/redirects/logic. zsh/fish: history. elvish: structured builtins.
import { parse, type CommandList, type Pipeline, type SimpleCommand } from "./parser";

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
    lastExit: 0,
    history: [],
    shouldExit: false,
    exitCode: 0,
  };
}

// Minimal safe integer arithmetic evaluator for $(( ... )) — no eval/Function.
function evalArith(expr: string): number {
  let i = 0;
  const s = expr;
  const skip = () => { while (i < s.length && /\s/.test(s[i])) i++; };
  function parsePrimary(): number {
    skip();
    if (s[i] === "(") { i++; const v = parseAdd(); skip(); if (s[i] === ")") i++; return v; }
    if (s[i] === "-") { i++; return -parsePrimary(); }
    if (s[i] === "+") { i++; return parsePrimary(); }
    let num = "";
    while (i < s.length && /[0-9]/.test(s[i])) num += s[i++];
    return num ? parseInt(num, 10) : 0;
  }
  function parseMul(): number {
    let v = parsePrimary();
    for (;;) { skip(); const op = s[i];
      if (op === "*") { i++; v *= parsePrimary(); }
      else if (op === "/") { i++; const d = parsePrimary(); v = d === 0 ? 0 : Math.trunc(v / d); }
      else if (op === "%") { i++; const d = parsePrimary(); v = d === 0 ? 0 : v % d; }
      else break;
    }
    return v;
  }
  function parseAdd(): number {
    let v = parseMul();
    for (;;) { skip(); const op = s[i];
      if (op === "+") { i++; v += parseMul(); }
      else if (op === "-") { i++; v -= parseMul(); }
      else break;
    }
    return v;
  }
  return parseAdd();
}

// Expand $((arith)), $VAR, ${VAR}, $?, and leading ~ (HOME).
export function expand(word: string, st: ShellState): string {
  let out = word;
  if (out.startsWith("~")) out = (st.env.HOME ?? "") + out.slice(1);
  // arithmetic first (its inner $vars expand against env)
  out = out.replace(/\$\(\((.*?)\)\)/g, (_, e: string) => {
    const inner = e
      .replace(/\$\{([A-Za-z_][A-Za-z0-9_]*)\}/g, (_m, n) => st.env[n] ?? "0")
      .replace(/\$([A-Za-z_][A-Za-z0-9_]*)/g, (_m, n) => st.env[n] ?? "0");
    try { return String(evalArith(inner)); } catch { return "0"; }
  });
  out = out.replace(/\$\{([A-Za-z_][A-Za-z0-9_]*)\}/g, (_, n) => st.env[n] ?? "");
  out = out.replace(/\$\?/g, () => String(st.lastExit));
  out = out.replace(/\$([A-Za-z_][A-Za-z0-9_]*)/g, (_, n) => st.env[n] ?? "");
  return out;
}

type BuiltinFn = (args: string[], st: ShellState, io: IOHandles) => number | Promise<number>;
interface IOHandles { out: (s: string) => void; err: (s: string) => void; capture?: boolean; }

export const BUILTINS: Record<string, BuiltinFn> = {
  cd: (args, st, io) => {
    const target = args[0] ?? st.env.HOME ?? st.cwd;
    const path = require("path").resolve(st.cwd, target);
    try {
      const fs = require("fs");
      if (!fs.statSync(path).isDirectory()) { io.err(`cd: not a directory: ${target}\n`); return 1; }
      st.cwd = path; st.env.PWD = path; return 0;
    } catch { io.err(`cd: no such directory: ${target}\n`); return 1; }
  },
  pwd: (_a, st, io) => { io.out(st.cwd + "\n"); return 0; },
  exit: (args, st) => { st.shouldExit = true; st.exitCode = args[0] ? parseInt(args[0], 10) || 0 : st.lastExit; return st.exitCode; },
  export: (args, st, io) => {
    for (const a of args) {
      const eq = a.indexOf("=");
      if (eq >= 0) st.env[a.slice(0, eq)] = a.slice(eq + 1);
      else if (!(a in st.env)) st.env[a] = "";
    }
    return 0;
  },
  unset: (args, st) => { for (const a of args) delete st.env[a]; return 0; },
  set: (_a, st, io) => { for (const k of Object.keys(st.env).sort()) io.out(`${k}=${st.env[k]}\n`); return 0; },
  history: (_a, st, io) => { st.history.forEach((h, i) => io.out(`${String(i + 1).padStart(5)}  ${h}\n`)); return 0; },
  echo: (args, _st, io) => { io.out(args.join(" ") + "\n"); return 0; },
  true: () => 0,
  false: () => 1,
  ":": () => 0,
  help: (_a, _st, io) => {
    io.out("aesh builtins: cd pwd exit export unset set history echo true false help type\n");
    io.out("operators: | && || ; > >> <   (bash) | tab-completion + history (zsh/fish)\n");
    return 0;
  },
  type: (args, _st, io) => {
    for (const a of args) io.out(`${a} is ${a in BUILTINS ? "a shell builtin" : "external"}\n`);
    return 0;
  },
};

async function runSimple(cmd: SimpleCommand, st: ShellState, io: IOHandles): Promise<number> {
  const argv = cmd.argv.map((w) => expand(w, st)).filter((s) => s !== "" || cmd.argv.length === 1);
  if (argv.length === 0) return 0;
  const name = argv[0];
  // builtins (only meaningful outside a multi-stage pipe; handled here for single commands)
  if (name in BUILTINS && cmd.redirects.length === 0) {
    return await BUILTINS[name](argv.slice(1), st, io);
  }
  // external — single command, inherit stdio, honor redirects
  return await spawnExternal([cmd], st, io);
}

// Spawn a pipeline of external commands; connect stdout->stdin; apply redirects on ends.
async function spawnExternal(cmds: SimpleCommand[], st: ShellState, io: IOHandles): Promise<number> {
  const fs = require("fs");
  const procs: any[] = [];
  let prevStdout: any = "inherit";
  for (let idx = 0; idx < cmds.length; idx++) {
    const c = cmds[idx];
    const argv = c.argv.map((w) => expand(w, st)).filter((s, i) => s !== "" || (i === 0));
    const isLast = idx === cmds.length - 1;

    // In capture mode we pipe the final stdout/stderr and forward through io
    // (so -c/script/test output is observable). Interactive REPL uses inherit
    // so full-screen TTY programs keep working.
    let redirectedOut = false;
    let stdin: any = idx === 0 ? "inherit" : prevStdout;
    let stdout: any = isLast ? (io.capture ? "pipe" : "inherit") : "pipe";
    let stderr: any = io.capture ? "pipe" : "inherit";

    // redirects (a file redirect overrides capture for that stream)
    for (const r of c.redirects) {
      if (r.op === "<") stdin = fs.openSync(expand(r.target, st), "r");
      else if (r.op === ">") { stdout = fs.openSync(expand(r.target, st), "w"); redirectedOut = true; }
      else if (r.op === ">>") { stdout = fs.openSync(expand(r.target, st), "a"); redirectedOut = true; }
    }

    let proc: any;
    try {
      proc = Bun.spawn(argv, { cwd: st.cwd, env: st.env, stdin, stdout, stderr });
    } catch (e) {
      io.err(`aesh: ${argv[0]}: ${(e as Error).message}\n`);
      return 127;
    }
    procs.push({ proc, isLast, redirectedOut });
    prevStdout = proc.stdout; // ReadableStream for next stage
  }

  // Drain captured streams concurrently to avoid deadlock, then await exits.
  const drains: Promise<void>[] = [];
  for (const { proc, isLast, redirectedOut } of procs) {
    if (io.capture && proc.stderr && typeof proc.stderr !== "number") {
      drains.push(new Response(proc.stderr).text().then((t) => { if (t) io.err(t); }));
    }
    if (io.capture && isLast && !redirectedOut && proc.stdout && typeof proc.stdout !== "number") {
      drains.push(new Response(proc.stdout).text().then((t) => { if (t) io.out(t); }));
    }
  }
  let code = 0;
  for (const { proc } of procs) code = await proc.exited;
  await Promise.all(drains);
  return code;
}

async function runPipeline(pl: Pipeline, st: ShellState, io: IOHandles): Promise<number> {
  if (pl.commands.length === 1) return runSimple(pl.commands[0], st, io);
  // multi-stage: run all as external (echo/printf exist as /bin too)
  return spawnExternal(pl.commands, st, io);
}

export async function execList(list: CommandList, st: ShellState, io: IOHandles): Promise<number> {
  let code = st.lastExit;
  let skipUntilNext = false;
  for (let i = 0; i < list.items.length; i++) {
    const item = list.items[i];
    if (!skipUntilNext) {
      code = await runPipeline(item.pipeline, st, io);
      st.lastExit = code;
      if (st.shouldExit) return st.exitCode;
    }
    // decide whether to run the next based on this op
    if (item.op === "&&") skipUntilNext = code !== 0;
    else if (item.op === "||") skipUntilNext = code === 0;
    else skipUntilNext = false;
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
