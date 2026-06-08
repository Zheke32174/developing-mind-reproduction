// RYZ Interpreter — tree-walking evaluator.
// Runtime ingredients: Rust-style binding mutability checks, Go-style channels
// (via RyzChannel), Zig-style explicit blocks, TS/Bun host for builtins.
import type * as A from "./ast";

export type Value =
  | number | string | boolean | null
  | RyzFn | NativeFn | RyzModule | RyzChannel | Value[];

export class RyzFn { constructor(public decl: A.FnDecl, public closure: Env) {} }
export class NativeFn { constructor(public name: string, public fn: (...args: Value[]) => Value) {} }
export class RyzModule { constructor(public name: string, public members: Map<string, Value>) {} }
export class RyzChannel {
  buf: Value[] = [];
  send(v: Value) { this.buf.push(v); }
  recv(): Value { return this.buf.length ? this.buf.shift()! : null; }
}

export class RyzError extends Error {}
class ReturnSignal { constructor(public value: Value) {} }

interface Binding { value: Value; mutable: boolean; }

export class Env {
  private vars = new Map<string, Binding>();
  constructor(public parent?: Env) {}
  define(name: string, value: Value, mutable: boolean) {
    this.vars.set(name, { value, mutable });
  }
  get(name: string): Value {
    let e: Env | undefined = this;
    while (e) { const b = e.vars.get(name); if (b) return b.value; e = e.parent; }
    throw new RyzError(`undefined variable '${name}'`);
  }
  set(name: string, value: Value) {
    let e: Env | undefined = this;
    while (e) {
      const b = e.vars.get(name);
      if (b) {
        if (!b.mutable) throw new RyzError(`cannot assign to immutable binding '${name}' (use 'mut')`);
        b.value = value; return;
      }
      e = e.parent;
    }
    throw new RyzError(`undefined variable '${name}'`);
  }
}

export interface IO { write(s: string): void; }

export class Interpreter {
  global = new Env();
  constructor(private io: IO = { write: (s) => process.stdout.write(s) }, private args: string[] = []) {}

  private modules(): Map<string, RyzModule> {
    const fmt = new RyzModule("fmt", new Map<string, Value>([
      ["println", new NativeFn("println", (...a) => { this.io.write(a.map(rstr).join(" ") + "\n"); return null; })],
      ["print", new NativeFn("print", (...a) => { this.io.write(a.map(rstr).join(" ")); return null; })],
      ["sprintf", new NativeFn("sprintf", (...a) => a.map(rstr).join(""))],
    ]));
    const math = new RyzModule("math", new Map<string, Value>([
      ["sqrt", new NativeFn("sqrt", (x) => Math.sqrt(Number(x)))],
      ["abs", new NativeFn("abs", (x) => Math.abs(Number(x)))],
      ["max", new NativeFn("max", (a, b) => Math.max(Number(a), Number(b)))],
      ["min", new NativeFn("min", (a, b) => Math.min(Number(a), Number(b)))],
      ["floor", new NativeFn("floor", (x) => Math.floor(Number(x)))],
    ]));
    const str = new RyzModule("str", new Map<string, Value>([
      ["upper", new NativeFn("upper", (s) => rstr(s).toUpperCase())],
      ["lower", new NativeFn("lower", (s) => rstr(s).toLowerCase())],
      ["trim", new NativeFn("trim", (s) => rstr(s).trim())],
      ["split", new NativeFn("split", (s, sep) => rstr(s).split(rstr(sep)) as Value[])],
      ["join", new NativeFn("join", (a, sep) => (a as Value[]).map(rstr).join(rstr(sep)))],
      ["contains", new NativeFn("contains", (s, sub) => rstr(s).includes(rstr(sub)))],
      ["replace", new NativeFn("replace", (s, a, b) => rstr(s).split(rstr(a)).join(rstr(b)))],
      ["len", new NativeFn("len", (s) => rstr(s).length)],
    ]));
    const fsm = new RyzModule("fs", new Map<string, Value>([
      ["read", new NativeFn("read", (p) => { const fs = require("fs"); return fs.readFileSync(rstr(p), "utf8"); })],
      ["write", new NativeFn("write", (p, c) => { const fs = require("fs"); fs.writeFileSync(rstr(p), rstr(c)); return null; })],
      ["exists", new NativeFn("exists", (p) => { const fs = require("fs"); return fs.existsSync(rstr(p)); })],
      ["lines", new NativeFn("lines", (p) => { const fs = require("fs"); return fs.readFileSync(rstr(p), "utf8").split("\n") as Value[]; })],
    ]));
    const os = new RyzModule("os", new Map<string, Value>([
      ["args", new NativeFn("args", () => [...this.args] as Value[])],
      ["getenv", new NativeFn("getenv", (k) => process.env[rstr(k)] ?? "")],
    ]));
    return new Map([
      ["fmt", fmt], ["math", math], ["str", str], ["fs", fsm], ["os", os],
      ["std/fmt", fmt], ["std/math", math], ["std/str", str], ["std/fs", fsm], ["std/os", os],
    ]);
  }

  private registerGlobals() {
    const g = this.global;
    g.define("len", new NativeFn("len", (x) => Array.isArray(x) ? x.length : rstr(x).length), false);
    g.define("push", new NativeFn("push", (a, v) => { if (!Array.isArray(a)) throw new RyzError("push expects an array"); a.push(v as Value); return a; }), false);
    // `str` cast is convenient but collides with `import "std/str"` (module also named str).
    // `string` is the collision-free cast (matches the grammar's `string` type name).
    g.define("str", new NativeFn("str", (x) => rstr(x)), false);
    g.define("string", new NativeFn("string", (x) => rstr(x)), false);
    g.define("int", new NativeFn("int", (x) => Math.trunc(Number(x))), false);
    g.define("float", new NativeFn("float", (x) => Number(x)), false);
    g.define("range", new NativeFn("range", (n) => Array.from({ length: Math.max(0, Math.trunc(Number(n))) }, (_v, i) => i) as Value[]), false);
  }

  run(program: A.Program): number {
    this.registerGlobals();
    const mods = this.modules();
    // hoist imports + fn decls
    for (const node of program.body) {
      if (node.kind === "ImportStmt") {
        const m = mods.get(node.path) ?? mods.get(node.path.replace(/^std\//, ""));
        if (!m) throw new RyzError(`unknown module '${node.path}'`);
        this.global.define(m.name, m, false);
      } else if (node.kind === "FnDecl") {
        this.global.define(node.name, new RyzFn(node, this.global), false);
      }
    }
    // top-level non-fn statements execute in order
    for (const node of program.body) {
      if (node.kind !== "ImportStmt" && node.kind !== "FnDecl") this.exec(node, this.global);
    }
    // entry point
    const main = this.global.get.bind(this.global);
    let mainFn: Value;
    try { mainFn = main("main"); } catch { return 0; }
    if (mainFn instanceof RyzFn) {
      const r = this.callFn(mainFn, []);
      return typeof r === "number" ? r : 0;
    }
    return 0;
  }

  private execBlock(block: A.Block, env: Env) {
    const deferred: A.Node[] = [];
    try {
      for (const s of block.body) {
        if (s.kind === "DeferStmt") { deferred.push(s.expr); continue; }
        this.exec(s, env);
      }
    } finally {
      for (let k = deferred.length - 1; k >= 0; k--) this.eval(deferred[k], env);
    }
  }

  private exec(node: A.Node, env: Env): void {
    switch (node.kind) {
      case "LetStmt": env.define(node.name, this.eval(node.value, env), node.mutable); return;
      case "ReturnStmt": throw new ReturnSignal(node.value ? this.eval(node.value, env) : null);
      case "ExprStmt": this.eval(node.expr, env); return;
      case "Block": this.execBlock(node, new Env(env)); return;
      case "DeferStmt": this.eval(node.expr, env); return; // bare defer outside block
      case "IfStmt": {
        if (truthy(this.eval(node.cond, env))) this.execBlock(node.then, new Env(env));
        else if (node.else) {
          if (node.else.kind === "Block") this.execBlock(node.else, new Env(env));
          else this.exec(node.else, env);
        }
        return;
      }
      case "WhileStmt":
        while (truthy(this.eval(node.cond, env))) this.execBlock(node.body, new Env(env));
        return;
      case "ForStmt": {
        const iter = this.eval(node.iter, env);
        const seq: Value[] = Array.isArray(iter) ? iter : typeof iter === "string" ? iter.split("") : [];
        if (!Array.isArray(iter) && typeof iter !== "string")
          throw new RyzError("for-in expects an array or string");
        for (const item of seq) {
          const loopEnv = new Env(env);
          loopEnv.define(node.varName, item, true);
          this.execBlock(node.body, loopEnv);
        }
        return;
      }
      case "FnDecl": env.define(node.name, new RyzFn(node, env), false); return;
      default: this.eval(node, env); return;
    }
  }

  private callFn(fn: RyzFn, args: Value[]): Value {
    const env = new Env(fn.closure);
    fn.decl.params.forEach((p, idx) => env.define(p.name, args[idx] ?? null, true));
    try { this.execBlock(fn.decl.body, env); }
    catch (e) { if (e instanceof ReturnSignal) return e.value; throw e; }
    return null;
  }

  private eval(node: A.Node, env: Env): Value {
    switch (node.kind) {
      case "IntLit": case "FloatLit": return node.value;
      case "StrLit": return node.value;
      case "BoolLit": return node.value;
      case "Ident": return env.get(node.name);
      case "ArrayLit": return node.elements.map((e) => this.eval(e, env));
      case "Index": {
        const obj = this.eval(node.object, env);
        const idx = this.eval(node.index, env);
        if (Array.isArray(obj)) { const i = Number(idx); return i < 0 ? (obj[obj.length + i] ?? null) : (obj[i] ?? null); }
        if (typeof obj === "string") { const i = Number(idx); return obj[i < 0 ? obj.length + i : i] ?? ""; }
        throw new RyzError("cannot index non-array/string");
      }
      case "Assign": {
        const v = this.eval(node.value, env);
        if (node.target.kind === "Ident") env.set(node.target.name, v);
        else if (node.target.kind === "Index") {
          const obj = this.eval(node.target.object, env);
          const idx = Number(this.eval(node.target.index, env));
          if (!Array.isArray(obj)) throw new RyzError("cannot index-assign non-array");
          obj[idx < 0 ? obj.length + idx : idx] = v;
        } else throw new RyzError("invalid assignment target");
        return v;
      }
      case "Unary": {
        const v = this.eval(node.operand, env);
        if (node.op === "-") return -Number(v);
        if (node.op === "!") return !truthy(v);
        throw new RyzError(`bad unary ${node.op}`);
      }
      case "Binary": return this.binop(node, env);
      case "Member": {
        const obj = this.eval(node.object, env);
        if (obj instanceof RyzModule) {
          const m = obj.members.get(node.property);
          if (m === undefined) throw new RyzError(`module '${obj.name}' has no member '${node.property}'`);
          return m;
        }
        throw new RyzError(`cannot access '.${node.property}' on non-module`);
      }
      case "Call": {
        const callee = this.eval(node.callee, env);
        const args = node.args.map((a) => this.eval(a, env));
        if (callee instanceof NativeFn) return callee.fn(...args);
        if (callee instanceof RyzFn) return this.callFn(callee, args);
        throw new RyzError("attempted to call a non-function");
      }
      default: throw new RyzError(`cannot evaluate node '${(node as A.Node).kind}'`);
    }
  }

  private binop(node: A.Binary, env: Env): Value {
    const op = node.op;
    if (op === "&&") return truthy(this.eval(node.left, env)) ? this.eval(node.right, env) : false;
    if (op === "||") { const l = this.eval(node.left, env); return truthy(l) ? l : this.eval(node.right, env); }
    const l = this.eval(node.left, env), r = this.eval(node.right, env);
    switch (op) {
      case "+": return (typeof l === "string" || typeof r === "string") ? rstr(l) + rstr(r) : Number(l) + Number(r);
      case "-": return Number(l) - Number(r);
      case "*": return Number(l) * Number(r);
      case "/": return Number(l) / Number(r);
      case "%": return Number(l) % Number(r);
      case "<": return Number(l) < Number(r);
      case ">": return Number(l) > Number(r);
      case "<=": return Number(l) <= Number(r);
      case ">=": return Number(l) >= Number(r);
      case "==": return l === r;
      case "!=": return l !== r;
      default: throw new RyzError(`bad operator ${op}`);
    }
  }
}

function truthy(v: Value): boolean {
  if (v === null || v === false) return false;
  if (v === 0 || v === "") return false;
  return true;
}

export function rstr(v: Value): string {
  if (v === null) return "null";
  if (Array.isArray(v)) return "[" + v.map(rstr).join(", ") + "]";
  if (typeof v === "string") return v;
  if (typeof v === "boolean") return v ? "true" : "false";
  if (typeof v === "number") return Number.isInteger(v) ? String(v) : String(v);
  if (v instanceof RyzFn) return `<fn ${v.decl.name}>`;
  if (v instanceof NativeFn) return `<native ${v.name}>`;
  if (v instanceof RyzModule) return `<module ${v.name}>`;
  if (v instanceof RyzChannel) return `<chan>`;
  return String(v);
}
