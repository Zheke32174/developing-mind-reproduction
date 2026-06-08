// RYZ Parser — recursive descent + Pratt expression parsing.
import { T, type Token } from "./lexer";
import type * as A from "./ast";

export class ParseError extends Error {
  constructor(msg: string, tok: Token) {
    super(`Parse error at ${tok.line}:${tok.col}: ${msg} (got '${tok.value || tok.type}')`);
  }
}

// Binary operator precedence (higher binds tighter).
const PREC: Record<string, number> = {
  "||": 1, "&&": 2,
  "==": 3, "!=": 3,
  "<": 4, ">": 4, "<=": 4, ">=": 4,
  "+": 5, "-": 5,
  "*": 6, "/": 6, "%": 6,
};

export class Parser {
  private p = 0;
  constructor(private toks: Token[]) {}

  private peek(o = 0): Token { return this.toks[Math.min(this.p + o, this.toks.length - 1)]; }
  private at(t: T): boolean { return this.peek().type === t; }
  private next(): Token { return this.toks[this.p++]; }
  private expect(t: T): Token {
    if (!this.at(t)) throw new ParseError(`expected ${t}`, this.peek());
    return this.next();
  }
  private accept(t: T): boolean { if (this.at(t)) { this.p++; return true; } return false; }

  parse(): A.Program {
    const body: A.Node[] = [];
    while (!this.at(T.EOF)) body.push(this.declaration());
    return { kind: "Program", body };
  }

  private declaration(): A.Node {
    if (this.at(T.Import)) return this.importStmt();
    if (this.at(T.Struct)) return this.structDecl();
    let exported = false;
    if (this.at(T.Export)) { this.next(); exported = true; }
    if (this.at(T.Fn)) return this.fnDecl(exported);
    if (exported) throw new ParseError("export must precede fn", this.peek());
    return this.statement();
  }

  private structDecl(): A.StructDecl {
    this.expect(T.Struct);
    const name = this.expect(T.Ident).value;
    this.expect(T.LBrace);
    const fields: string[] = [];
    while (!this.at(T.RBrace) && !this.at(T.EOF)) {
      const fname = this.expect(T.Ident).value;
      if (this.accept(T.Colon)) this.typeName(); // type annotation is parsed but ignored at runtime
      fields.push(fname);
      if (!this.accept(T.Comma)) { /* allow newline-separated; loop continues */ }
    }
    this.expect(T.RBrace);
    return { kind: "StructDecl", name, fields };
  }

  private importStmt(): A.ImportStmt {
    this.expect(T.Import);
    const path = this.expect(T.Str).value;
    this.accept(T.Semi);
    return { kind: "ImportStmt", path };
  }

  private fnDecl(exported: boolean): A.FnDecl {
    this.expect(T.Fn);
    const name = this.expect(T.Ident).value;
    this.expect(T.LParen);
    const params: A.Param[] = [];
    if (!this.at(T.RParen)) {
      do {
        if (this.at(T.RParen)) break;
        const pn = this.expect(T.Ident).value;
        let type: string | undefined;
        if (this.accept(T.Colon)) type = this.typeName();
        params.push({ kind: "Param", name: pn, type });
      } while (this.accept(T.Comma));
    }
    this.expect(T.RParen);
    let retType: string | undefined;
    if (this.accept(T.Arrow)) retType = this.typeName();
    const body = this.block();
    return { kind: "FnDecl", name, params, retType, body, exported };
  }

  // Type name: ident, with optional chan<T> / generic <...> and [] suffix.
  private typeName(): string {
    let name: string;
    if (this.at(T.Chan)) { this.next(); name = "chan"; }
    else name = this.expect(T.Ident).value;
    if (this.accept(T.Lt)) {
      const inner = this.typeName();
      this.expect(T.Gt);
      name += `<${inner}>`;
    }
    while (this.accept(T.LBracket)) { this.expect(T.RBracket); name += "[]"; }
    return name;
  }

  private block(): A.Block {
    this.expect(T.LBrace);
    const body: A.Node[] = [];
    while (!this.at(T.RBrace) && !this.at(T.EOF)) body.push(this.statement());
    this.expect(T.RBrace);
    return { kind: "Block", body };
  }

  private statement(): A.Node {
    if (this.at(T.Let) || this.at(T.Mut)) return this.letStmt();
    if (this.at(T.Return)) return this.returnStmt();
    if (this.at(T.If)) return this.ifStmt();
    if (this.at(T.While)) return this.whileStmt();
    if (this.at(T.For)) return this.forStmt();
    if (this.at(T.Defer)) { this.next(); const e = this.expression(); this.accept(T.Semi); return { kind: "DeferStmt", expr: e }; }
    if (this.at(T.Spawn)) {
      this.next();
      const call = this.expression();
      if (call.kind !== "Call") throw new ParseError("spawn expects a function call", this.peek());
      this.accept(T.Semi);
      return { kind: "SpawnStmt", call };
    }
    if (this.at(T.LBrace)) return this.block();
    const expr = this.expression();
    this.accept(T.Semi);
    return { kind: "ExprStmt", expr };
  }

  private letStmt(): A.LetStmt {
    const mutable = this.peek().type === T.Mut;
    this.next(); // let | mut
    // allow `let mut x`
    let mutable2 = mutable;
    if (!mutable && this.at(T.Mut)) { this.next(); mutable2 = true; }
    const name = this.expect(T.Ident).value;
    let type: string | undefined;
    if (this.accept(T.Colon)) type = this.typeName();
    this.expect(T.Assign);
    const value = this.expression();
    this.accept(T.Semi);
    return { kind: "LetStmt", name, mutable: mutable2, type, value };
  }

  private returnStmt(): A.ReturnStmt {
    this.expect(T.Return);
    let value: A.Node | undefined;
    if (!this.at(T.Semi) && !this.at(T.RBrace)) value = this.expression();
    this.accept(T.Semi);
    return { kind: "ReturnStmt", value };
  }

  private ifStmt(): A.IfStmt {
    this.expect(T.If);
    const cond = this.expression();
    const then = this.block();
    let els: A.Block | A.IfStmt | undefined;
    if (this.accept(T.Else)) els = this.at(T.If) ? this.ifStmt() : this.block();
    return { kind: "IfStmt", cond, then, else: els };
  }

  private whileStmt(): A.WhileStmt {
    this.expect(T.While);
    const cond = this.expression();
    const body = this.block();
    return { kind: "WhileStmt", cond, body };
  }

  private forStmt(): A.ForStmt {
    this.expect(T.For);
    const varName = this.expect(T.Ident).value;
    this.expect(T.In);
    const iter = this.expression();
    const body = this.block();
    return { kind: "ForStmt", varName, iter, body };
  }

  // ---- expressions (Pratt) ----
  private expression(): A.Node { return this.assignment(); }

  private assignment(): A.Node {
    const left = this.binary(0);
    if (this.at(T.Assign)) {
      this.next();
      const value = this.assignment();
      if (left.kind !== "Ident" && left.kind !== "Member" && left.kind !== "Index")
        throw new ParseError("invalid assignment target", this.peek());
      return { kind: "Assign", target: left, value };
    }
    return left;
  }

  private binary(minPrec: number): A.Node {
    let left = this.unary();
    for (;;) {
      const op = this.peek().value;
      const prec = PREC[op];
      if (prec === undefined || prec < minPrec) break;
      this.next();
      const right = this.binary(prec + 1);
      left = { kind: "Binary", op, left, right };
    }
    return left;
  }

  private unary(): A.Node {
    if (this.at(T.Minus) || this.at(T.Not)) {
      const op = this.next().value;
      return { kind: "Unary", op, operand: this.unary() };
    }
    return this.postfix();
  }

  private postfix(): A.Node {
    let e = this.primary();
    for (;;) {
      if (this.accept(T.Dot)) {
        const property = this.expect(T.Ident).value;
        e = { kind: "Member", object: e, property };
      } else if (this.at(T.LParen)) {
        this.next();
        const args: A.Node[] = [];
        if (!this.at(T.RParen)) {
          do { if (this.at(T.RParen)) break; args.push(this.expression()); } while (this.accept(T.Comma));
        }
        this.expect(T.RParen);
        e = { kind: "Call", callee: e, args };
      } else if (this.at(T.LBracket)) {
        this.next();
        const index = this.expression();
        this.expect(T.RBracket);
        e = { kind: "Index", object: e, index };
      } else break;
    }
    return e;
  }

  private primary(): A.Node {
    const t = this.peek();
    switch (t.type) {
      case T.Int: this.next(); return { kind: "IntLit", value: parseInt(t.value, 10) };
      case T.Float: this.next(); return { kind: "FloatLit", value: parseFloat(t.value) };
      case T.Str: this.next(); return { kind: "StrLit", value: t.value };
      case T.Bool: this.next(); return { kind: "BoolLit", value: t.value === "true" };
      case T.Ident: this.next(); return { kind: "Ident", name: t.value };
      case T.LParen: { this.next(); const e = this.expression(); this.expect(T.RParen); return e; }
      case T.LBracket: {
        this.next();
        const elements: A.Node[] = [];
        if (!this.at(T.RBracket)) {
          do { if (this.at(T.RBracket)) break; elements.push(this.expression()); } while (this.accept(T.Comma));
        }
        this.expect(T.RBracket);
        return { kind: "ArrayLit", elements };
      }
      case T.LBrace: {
        // map literal: { key: value, ... }  (blocks are only parsed in statement positions)
        this.next();
        const entries: { key: A.Node; value: A.Node }[] = [];
        if (!this.at(T.RBrace)) {
          do {
            if (this.at(T.RBrace)) break;
            const key = this.expression();
            this.expect(T.Colon);
            const value = this.expression();
            entries.push({ key, value });
          } while (this.accept(T.Comma));
        }
        this.expect(T.RBrace);
        return { kind: "MapLit", entries };
      }
      default: throw new ParseError("expected expression", t);
    }
  }
}

export function parse(toks: Token[]): A.Program {
  return new Parser(toks).parse();
}
