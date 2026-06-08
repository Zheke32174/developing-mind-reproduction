// AeSH shell parser — Frankenstein of bash/zsh/fish/elvish line grammar.
// Words are segment lists so single-quoted text stays literal (no $ expansion / no glob),
// while double-quoted and bare text expand. Bare glob metachars mark a word for globbing.

export interface Seg { text: string; expand: boolean } // expand=false => single-quoted literal
export interface Word { segs: Seg[]; glob: boolean }    // glob=true => had a bare * ? [
export interface Redirect { fd: number; op: ">" | ">>" | "<"; target: Word }
export interface SimpleCommand { kind: "cmd"; argv: Word[]; redirects: Redirect[]; }
export interface Pipeline { kind: "pipe"; commands: SimpleCommand[]; }
export interface ListItem { pipeline: Pipeline; op: ";" | "&&" | "||" | "&" | "end"; }
export interface CommandList { kind: "list"; items: ListItem[]; }

export class ShellParseError extends Error {}

type Tok = { t: "word"; word: Word } | { t: "op"; v: string };

function tokenize(line: string): Tok[] {
  const toks: Tok[] = [];
  let i = 0;
  const n = line.length;
  const isOpStart = (c: string) => "|&;<>".includes(c);

  while (i < n) {
    const c = line[i];
    if (c === " " || c === "\t") { i++; continue; }
    if (c === "#") break;
    if (isOpStart(c)) {
      let op = c; i++;
      if ((c === "&" && line[i] === "&") || (c === "|" && line[i] === "|") || (c === ">" && line[i] === ">")) { op += line[i]; i++; }
      toks.push({ t: "op", v: op });
      continue;
    }
    // read a word
    const segs: Seg[] = [];
    let glob = false;
    let started = false;
    let cur = ""; // current expandable run
    const flush = () => { if (cur) { segs.push({ text: cur, expand: true }); cur = ""; } };
    while (i < n) {
      const ch = line[i];
      if (ch === " " || ch === "\t" || isOpStart(ch) || ch === "#") break;
      started = true;
      if (ch === "'") { // single quote: literal segment
        flush(); i++; let s = "";
        while (i < n && line[i] !== "'") s += line[i++];
        if (i >= n) throw new ShellParseError("unterminated single quote");
        i++; segs.push({ text: s, expand: false }); continue;
      }
      if (ch === '"') { // double quote: stays in the expandable run, honors \ escapes
        i++;
        while (i < n && line[i] !== '"') {
          if (line[i] === "\\" && i + 1 < n && '"\\$`'.includes(line[i + 1])) { cur += line[i + 1]; i += 2; }
          else cur += line[i++];
        }
        if (i >= n) throw new ShellParseError("unterminated double quote");
        i++; continue;
      }
      if (ch === "\\") { if (i + 1 < n) { cur += line[i + 1]; i += 2; } else i++; continue; }
      if (ch === "$" && line[i + 1] === "(") {
        // keep a whole $( ... ) / $(( ... )) substitution in the word, spaces and all
        cur += "$("; i += 2; let depth = 1;
        while (i < n && depth > 0) {
          const d = line[i];
          if (d === "(") depth++; else if (d === ")") depth--;
          cur += d; i++;
        }
        continue;
      }
      if (ch === "*" || ch === "?" || ch === "[") glob = true;
      cur += ch; i++;
    }
    flush();
    if (started) toks.push({ t: "word", word: { segs, glob } });
  }
  return toks;
}

export function parse(line: string): CommandList {
  const toks = tokenize(line);
  let p = 0;
  const peek = () => toks[p];
  const eat = () => toks[p++];
  const isWordDigits = (w: Word) => w.segs.length === 1 && w.segs[0].expand && /^\d+$/.test(w.segs[0].text);

  function simpleCommand(): SimpleCommand {
    const argv: Word[] = [];
    const redirects: Redirect[] = [];
    while (p < toks.length) {
      const tk = peek();
      if (tk.t === "op") {
        if (tk.v === ">" || tk.v === ">>" || tk.v === "<") {
          eat();
          const tgt = peek();
          if (!tgt || tgt.t !== "word") throw new ShellParseError(`expected filename after '${tk.v}'`);
          eat();
          redirects.push({ fd: tk.v === "<" ? 0 : 1, op: tk.v as Redirect["op"], target: tgt.word });
          continue;
        }
        break;
      }
      // explicit fd redirect: word "2" followed by > op
      if (tk.t === "word" && isWordDigits(tk.word) && toks[p + 1]?.t === "op" && (toks[p + 1] as any).v?.startsWith(">")) {
        const fd = parseInt(tk.word.segs[0].text, 10); eat(); const op = eat() as any;
        const tgt = peek(); if (!tgt || tgt.t !== "word") throw new ShellParseError("expected filename after redirect");
        eat(); redirects.push({ fd, op: op.v, target: (tgt as any).word }); continue;
      }
      argv.push((eat() as any).word);
    }
    if (argv.length === 0 && redirects.length === 0) throw new ShellParseError("empty command");
    return { kind: "cmd", argv, redirects };
  }

  function pipeline(): Pipeline {
    const commands: SimpleCommand[] = [simpleCommand()];
    while (peek() && peek().t === "op" && (peek() as any).v === "|") { eat(); commands.push(simpleCommand()); }
    return { kind: "pipe", commands };
  }

  const items: ListItem[] = [];
  while (p < toks.length) {
    const pl = pipeline();
    let op: ListItem["op"] = "end";
    const tk = peek();
    if (tk && tk.t === "op") {
      const v = tk.v;
      if (v === "&&") { op = "&&"; eat(); }
      else if (v === "||") { op = "||"; eat(); }
      else if (v === ";") { op = ";"; eat(); }
      else if (v === "&") { op = "&"; eat(); }
      else throw new ShellParseError(`unexpected operator '${v}'`);
    }
    items.push({ pipeline: pl, op });
    if (op === "end") break;
  }
  return { kind: "list", items };
}
