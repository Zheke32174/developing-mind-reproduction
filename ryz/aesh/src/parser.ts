// AeSH shell parser — Frankenstein of bash/zsh/fish/elvish line grammar.
// Produces a small command AST: lists -> pipelines -> simple commands (+redirects).

export interface Redirect { fd: number; op: ">" | ">>" | "<"; target: string; }
export interface SimpleCommand { kind: "cmd"; argv: string[]; redirects: Redirect[]; }
export interface Pipeline { kind: "pipe"; commands: SimpleCommand[]; }
export interface ListItem { pipeline: Pipeline; op: ";" | "&&" | "||" | "&" | "end"; }
export interface CommandList { kind: "list"; items: ListItem[]; }

export class ShellParseError extends Error {}

type Tok = { t: "word" | "op"; v: string };

// Tokenize honoring single/double quotes, escapes, and operators | & ; && || > >> <
function tokenize(line: string): Tok[] {
  const toks: Tok[] = [];
  let i = 0;
  const n = line.length;
  const isOpStart = (c: string) => "|&;<>".includes(c);
  while (i < n) {
    const c = line[i];
    if (c === " " || c === "\t") { i++; continue; }
    if (c === "#") break; // comment to EOL
    if (isOpStart(c)) {
      let op = c; i++;
      if ((c === "&" && line[i] === "&") || (c === "|" && line[i] === "|") || (c === ">" && line[i] === ">")) { op += line[i]; i++; }
      toks.push({ t: "op", v: op });
      continue;
    }
    // a word: accumulate, handling quotes/escapes; redirects like 2> handled by leading digit+>
    let w = "";
    let quotedEmpty = false;
    while (i < n) {
      const ch = line[i];
      if (ch === " " || ch === "\t" || isOpStart(ch) || ch === "#") {
        // allow digit directly before > to be part of redirect op: handled by caller via fd parse
        break;
      }
      if (ch === "'") {
        i++; quotedEmpty = true;
        while (i < n && line[i] !== "'") { w += line[i++]; }
        if (i >= n) throw new ShellParseError("unterminated single quote");
        i++; continue;
      }
      if (ch === '"') {
        i++; quotedEmpty = true;
        while (i < n && line[i] !== '"') {
          if (line[i] === "\\" && i + 1 < n && "\"\\$`".includes(line[i + 1])) { w += line[i + 1]; i += 2; }
          else w += line[i++];
        }
        if (i >= n) throw new ShellParseError("unterminated double quote");
        i++; continue;
      }
      if (ch === "\\") { if (i + 1 < n) { w += line[i + 1]; i += 2; continue; } else { i++; break; } }
      w += ch; i++;
    }
    if (w.length || quotedEmpty) toks.push({ t: "word", v: w });
  }
  return toks;
}

export function parse(line: string): CommandList {
  const toks = tokenize(line);
  let p = 0;
  const peek = () => toks[p];
  const eat = () => toks[p++];

  function simpleCommand(): SimpleCommand {
    const argv: string[] = [];
    const redirects: Redirect[] = [];
    while (p < toks.length) {
      const tk = peek();
      if (tk.t === "op") {
        if (tk.v === ">" || tk.v === ">>" || tk.v === "<") {
          eat();
          const tgt = peek();
          if (!tgt || tgt.t !== "word") throw new ShellParseError(`expected filename after '${tk.v}'`);
          eat();
          redirects.push({ fd: tk.v === "<" ? 0 : 1, op: tk.v as Redirect["op"], target: tgt.v });
          continue;
        }
        break; // pipeline/list operator
      }
      // redirect with explicit fd e.g. "2>" arrived as word "2" then op ">" — handle: word that is pure digits followed by > op
      if (tk.t === "word" && /^\d+$/.test(tk.v) && toks[p + 1]?.t === "op" && (toks[p + 1].v === ">" || toks[p + 1].v === ">>")) {
        const fd = parseInt(tk.v, 10); eat(); const op = eat().v as ">" | ">>";
        const tgt = peek(); if (!tgt || tgt.t !== "word") throw new ShellParseError("expected filename after redirect");
        eat(); redirects.push({ fd, op, target: tgt.v }); continue;
      }
      argv.push(eat().v);
    }
    if (argv.length === 0 && redirects.length === 0) throw new ShellParseError("empty command");
    return { kind: "cmd", argv, redirects };
  }

  function pipeline(): Pipeline {
    const commands: SimpleCommand[] = [simpleCommand()];
    while (peek() && peek().t === "op" && peek().v === "|") { eat(); commands.push(simpleCommand()); }
    return { kind: "pipe", commands };
  }

  const items: ListItem[] = [];
  while (p < toks.length) {
    const pl = pipeline();
    let op: ListItem["op"] = "end";
    const tk = peek();
    if (tk && tk.t === "op") {
      if (tk.v === "&&") { op = "&&"; eat(); }
      else if (tk.v === "||") { op = "||"; eat(); }
      else if (tk.v === ";") { op = ";"; eat(); }
      else if (tk.v === "&") { op = "&"; eat(); }
      else throw new ShellParseError(`unexpected operator '${tk.v}'`);
    }
    items.push({ pipeline: pl, op });
    if (op === "end") break;
  }
  return { kind: "list", items };
}
