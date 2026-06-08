// RYZ Lexer — Frankenstein language frontend (Bun/TypeScript ingredient)
// Tokenizes RYZ source per GRAMMAR.md v0.1.0.
// Influences: Rust/Zig literal forms, Go/TS operators, Lua/TS ergonomics.

export enum T {
  // literals
  Int = "Int",
  Float = "Float",
  Str = "Str",
  Bool = "Bool",
  Ident = "Ident",
  // keywords
  Let = "let",
  Mut = "mut",
  Fn = "fn",
  Return = "return",
  If = "if",
  Else = "else",
  While = "while",
  For = "for",
  In = "in",
  Import = "import",
  Export = "export",
  Defer = "defer",
  Spawn = "spawn",
  Chan = "chan",
  Select = "select",
  Struct = "struct",
  Extern = "extern",
  True = "true",
  False = "false",
  // punctuation / operators
  LParen = "(",
  RParen = ")",
  LBrace = "{",
  RBrace = "}",
  LBracket = "[",
  RBracket = "]",
  Comma = ",",
  Semi = ";",
  Colon = ":",
  Dot = ".",
  Arrow = "->",
  Assign = "=",
  Plus = "+",
  Minus = "-",
  Star = "*",
  Slash = "/",
  Percent = "%",
  Lt = "<",
  Gt = ">",
  Le = "<=",
  Ge = ">=",
  EqEq = "==",
  NotEq = "!=",
  And = "&&",
  Or = "||",
  Not = "!",
  EOF = "EOF",
}

export interface Token {
  type: T;
  value: string;
  line: number;
  col: number;
}

const KEYWORDS: Record<string, T> = {
  let: T.Let, mut: T.Mut, fn: T.Fn, return: T.Return, if: T.If, else: T.Else,
  while: T.While, for: T.For, in: T.In, import: T.Import, export: T.Export, defer: T.Defer,
  spawn: T.Spawn, chan: T.Chan, select: T.Select, struct: T.Struct, extern: T.Extern, true: T.True, false: T.False,
};

export class LexError extends Error {
  constructor(msg: string, public line: number, public col: number) {
    super(`Lex error at ${line}:${col}: ${msg}`);
  }
}

export function lex(src: string): Token[] {
  const toks: Token[] = [];
  let i = 0, line = 1, col = 1;
  const peek = (o = 0) => src[i + o];
  const adv = () => { const c = src[i++]; if (c === "\n") { line++; col = 1; } else col++; return c; };
  const push = (type: T, value: string, l = line, c = col) => toks.push({ type, value, line: l, col: c });

  while (i < src.length) {
    const c = peek();
    // whitespace
    if (c === " " || c === "\t" || c === "\r" || c === "\n") { adv(); continue; }
    // line comments: // ... and # ...
    if (c === "/" && peek(1) === "/") { while (i < src.length && peek() !== "\n") adv(); continue; }
    if (c === "#") { while (i < src.length && peek() !== "\n") adv(); continue; }
    // block comments /* */
    if (c === "/" && peek(1) === "*") {
      adv(); adv();
      while (i < src.length && !(peek() === "*" && peek(1) === "/")) adv();
      adv(); adv(); continue;
    }
    const startLine = line, startCol = col;
    // strings
    if (c === '"') {
      adv(); let s = "";
      while (i < src.length && peek() !== '"') {
        let ch = adv();
        if (ch === "\\") {
          const e = adv();
          ch = e === "n" ? "\n" : e === "t" ? "\t" : e === "r" ? "\r" : e === "\\" ? "\\" : e === '"' ? '"' : e === "0" ? "\0" : e;
        }
        s += ch;
      }
      if (peek() !== '"') throw new LexError("unterminated string", startLine, startCol);
      adv();
      push(T.Str, s, startLine, startCol); continue;
    }
    // numbers
    if (c >= "0" && c <= "9") {
      let n = ""; let isFloat = false;
      while (i < src.length && /[0-9_]/.test(peek())) n += adv();
      if (peek() === "." && /[0-9]/.test(peek(1) ?? "")) { isFloat = true; n += adv(); while (i < src.length && /[0-9_]/.test(peek())) n += adv(); }
      push(isFloat ? T.Float : T.Int, n.replace(/_/g, ""), startLine, startCol); continue;
    }
    // identifiers / keywords
    if (/[A-Za-z_]/.test(c)) {
      let id = "";
      while (i < src.length && /[A-Za-z0-9_]/.test(peek())) id += adv();
      const kw = KEYWORDS[id];
      if (kw === T.True || kw === T.False) push(T.Bool, id, startLine, startCol);
      else if (kw) push(kw, id, startLine, startCol);
      else push(T.Ident, id, startLine, startCol);
      continue;
    }
    // multi-char operators
    const two = c + (peek(1) ?? "");
    const twoMap: Record<string, T> = {
      "->": T.Arrow, "<=": T.Le, ">=": T.Ge, "==": T.EqEq, "!=": T.NotEq, "&&": T.And, "||": T.Or,
    };
    if (twoMap[two]) { adv(); adv(); push(twoMap[two], two, startLine, startCol); continue; }
    // single-char
    const oneMap: Record<string, T> = {
      "(": T.LParen, ")": T.RParen, "{": T.LBrace, "}": T.RBrace, "[": T.LBracket, "]": T.RBracket,
      ",": T.Comma, ";": T.Semi, ":": T.Colon, ".": T.Dot, "=": T.Assign, "+": T.Plus, "-": T.Minus,
      "*": T.Star, "/": T.Slash, "%": T.Percent, "<": T.Lt, ">": T.Gt, "!": T.Not,
    };
    if (oneMap[c]) { adv(); push(oneMap[c], c, startLine, startCol); continue; }
    throw new LexError(`unexpected character '${c}'`, startLine, startCol);
  }
  push(T.EOF, "");
  return toks;
}
