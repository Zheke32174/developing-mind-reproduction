#!/usr/bin/env bun
// AeSH — Advanced embedded Shell. Frankenstein of bash/zsh/fish/elvish.
// Modes: `aesh -c "<cmd>"` | `aesh script.aesh` | interactive REPL.
import { newState, runLine, BUILTINS, type ShellState } from "./exec";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";

const VERSION = "0.1.0";
const HISTORY_FILE = path.join(os.homedir(), ".aesh_history");

const io = {
  out: (s: string) => process.stdout.write(s),
  err: (s: string) => process.stderr.write(s),
};

function loadHistory(st: ShellState) {
  try { st.history = fs.readFileSync(HISTORY_FILE, "utf8").split("\n").filter(Boolean); } catch {}
}
function saveHistory(st: ShellState) {
  try { fs.writeFileSync(HISTORY_FILE, st.history.slice(-2000).join("\n") + "\n"); } catch {}
}

function listPathExecutables(): string[] {
  const out = new Set<string>(Object.keys(BUILTINS));
  for (const dir of (process.env.PATH ?? "").split(":")) {
    try { for (const f of fs.readdirSync(dir)) out.add(f); } catch {}
  }
  return [...out];
}

async function repl(st: ShellState) {
  loadHistory(st);
  const readline = await import("readline");
  const allCmds = listPathExecutables();

  const completer = (line: string): [string[], string] => {
    const parts = line.split(/\s+/);
    const word = parts[parts.length - 1] ?? "";
    // first word → command completion; else → file completion
    if (parts.length <= 1) {
      const hits = allCmds.filter((c) => c.startsWith(word)).sort();
      return [hits.length ? hits : allCmds.sort(), word];
    }
    try {
      const dir = word.includes("/") ? path.dirname(word) : st.cwd;
      const base = path.basename(word);
      const entries = fs.readdirSync(dir).filter((e) => e.startsWith(base));
      return [entries, base];
    } catch { return [[], word]; }
  };

  const rl = readline.createInterface({
    input: process.stdin, output: process.stdout, completer, history: [...st.history].reverse(),
  });

  // fish-style autosuggest: ghost-complete from history on Right-arrow at line end.
  const findSuggestion = (line: string): string => {
    if (!line) return "";
    for (let i = st.history.length - 1; i >= 0; i--) {
      if (st.history[i].startsWith(line) && st.history[i] !== line) return st.history[i];
    }
    return "";
  };
  process.stdin.on("keypress", (_c, key) => {
    if (!key) return;
    const line = (rl as any).line ?? "";
    const cursor = (rl as any).cursor ?? 0;
    if (key.name === "right" && cursor >= line.length) {
      const sug = findSuggestion(line);
      if (sug) { (rl as any).line = sug; (rl as any).cursor = sug.length; (rl as any)._refreshLine?.(); }
    }
  });

  const prompt = () => {
    const cwdShort = st.cwd.replace(st.env.HOME ?? "~", "~");
    const mark = st.lastExit === 0 ? "\x1b[32m❯\x1b[0m" : "\x1b[31m❯\x1b[0m";
    rl.setPrompt(`\x1b[36maesh\x1b[0m ${cwdShort} ${mark} `);
    rl.prompt();
  };

  io.out(`AeSH v${VERSION} — bash·zsh·fish·elvish recombination. 'help' for builtins, Ctrl-D to exit.\n`);
  prompt();
  rl.on("line", async (line) => {
    await runLine(line, st, io);
    saveHistory(st);
    if (st.shouldExit) { rl.close(); return; }
    prompt();
  });
  rl.on("close", () => { saveHistory(st); process.exit(st.shouldExit ? st.exitCode : st.lastExit); });
}

async function main() {
  const args = process.argv.slice(2);
  const st = newState();

  if (args[0] === "--version" || args[0] === "version") {
    io.out(`aesh ${VERSION}\n`); return 0;
  }
  const capIo = { ...io, capture: true }; // non-interactive: funnel external output through io
  if (args[0] === "-c") {
    const code = await runLine(args.slice(1).join(" "), st, capIo);
    return st.shouldExit ? st.exitCode : code;
  }
  if (args[0] && args[0] !== "-i" && fs.existsSync(args[0])) {
    const script = fs.readFileSync(args[0], "utf8");
    for (const line of script.split("\n")) {
      if (line.trim().startsWith("#") || !line.trim()) continue;
      await runLine(line, st, capIo);
      if (st.shouldExit) return st.exitCode;
    }
    return st.lastExit;
  }
  // interactive
  if (process.stdin.isTTY) { await repl(st); return 0; }
  // piped stdin: run each line
  const input = fs.readFileSync(0, "utf8");
  for (const line of input.split("\n")) { if (line.trim()) await runLine(line, st, capIo); if (st.shouldExit) break; }
  return st.shouldExit ? st.exitCode : st.lastExit;
}

main().then((code) => process.exit(typeof code === "number" ? code : 0));
