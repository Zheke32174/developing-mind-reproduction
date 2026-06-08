// RYZ test runner — captures interpreter IO and asserts real behavior.
import { lex } from "../src/lexer";
import { parse } from "../src/parser";
import { Interpreter, type IO } from "../src/interpreter";

function runCapture(src: string): { out: string; code: number; error?: string } {
  let out = "";
  const io: IO = { write: (s) => { out += s; } };
  try {
    const interp = new Interpreter(io);
    const code = interp.run(parse(lex(src)));
    return { out, code };
  } catch (e) {
    return { out, code: 1, error: (e as Error).message };
  }
}

let pass = 0, fail = 0;
function test(name: string, fn: () => void) {
  try { fn(); pass++; console.log(`  ok  ${name}`); }
  catch (e) { fail++; console.log(`FAIL  ${name}\n      ${(e as Error).message}`); }
}
function eq(a: unknown, b: unknown, msg = "") {
  if (a !== b) throw new Error(`${msg} expected ${JSON.stringify(b)}, got ${JSON.stringify(a)}`);
}

test("hello world", () => {
  const r = runCapture(`import "std/fmt"; fn main() -> i32 { fmt.println("Hello from RYZ"); return 0; }`);
  eq(r.out, "Hello from RYZ\n", "out"); eq(r.code, 0, "code");
});

test("arithmetic + precedence", () => {
  const r = runCapture(`import "std/fmt"; fn main() -> i32 { fmt.println(2 + 3 * 4 - 1); return 0; }`);
  eq(r.out, "13\n");
});

test("recursion (fib 10)", () => {
  const r = runCapture(`fn fib(n:i64)->i64{ if n<2 {return n;} return fib(n-1)+fib(n-2);} import "std/fmt"; fn main()->i32{ fmt.println(fib(10)); return 0;}`);
  eq(r.out, "55\n");
});

test("mutability: reassign mut ok", () => {
  const r = runCapture(`import "std/fmt"; fn main()->i32{ let mut x:i32=1; x=x+41; fmt.println(x); return 0;}`);
  eq(r.out, "42\n");
});

test("mutability: immutable assign errors", () => {
  const r = runCapture(`fn main()->i32{ let x:i32=1; x=2; return 0;}`);
  eq(r.code, 1, "code"); if (!r.error?.includes("immutable")) throw new Error("expected immutable error, got: " + r.error);
});

test("while loop sum", () => {
  const r = runCapture(`import "std/fmt"; fn main()->i32{ let mut i:i32=0; let mut s:i32=0; while i<=5 { s=s+i; i=i+1; } fmt.println(s); return 0;}`);
  eq(r.out, "15\n");
});

test("if / else if / else", () => {
  const r = runCapture(`import "std/fmt"; fn grade(n:i32)->string{ if n>=90 {return "A";} else if n>=80 {return "B";} else {return "C";}} fn main()->i32{ fmt.println(grade(95), grade(85), grade(50)); return 0;}`);
  eq(r.out, "A B C\n");
});

test("defer runs LIFO at block exit", () => {
  const r = runCapture(`import "std/fmt"; fn main()->i32{ defer fmt.println("first-deferred-runs-last"); defer fmt.println("second-deferred-runs-first"); fmt.println("body"); return 0;}`);
  eq(r.out, "body\nsecond-deferred-runs-first\nfirst-deferred-runs-last\n");
});

test("string concat + bool logic", () => {
  const r = runCapture(`import "std/fmt"; fn main()->i32{ fmt.println("a"+"b", true && false, true || false, !false); return 0;}`);
  eq(r.out, "ab false true true\n");
});

test("math module", () => {
  const r = runCapture(`import "std/math"; import "std/fmt"; fn main()->i32{ fmt.println(math.sqrt(144), math.max(3,7)); return 0;}`);
  eq(r.out, "12 7\n");
});

test("return value becomes process exit code", () => {
  const r = runCapture(`fn main()->i32{ return 7; }`);
  eq(r.code, 7);
});

test("array literal + index + len", () => {
  const r = runCapture(`import "std/fmt"; fn main()->i32{ let a=[10,20,30]; fmt.println(a[0], a[2], len(a)); return 0;}`);
  eq(r.out, "10 30 3\n");
});

test("negative index", () => {
  const r = runCapture(`import "std/fmt"; fn main()->i32{ let a=[1,2,3]; fmt.println(a[-1]); return 0;}`);
  eq(r.out, "3\n");
});

test("for-in over array sums", () => {
  const r = runCapture(`import "std/fmt"; fn main()->i32{ let mut s:i32=0; for x in [1,2,3,4] { s = s + x; } fmt.println(s); return 0;}`);
  eq(r.out, "10\n");
});

test("for-in over range", () => {
  const r = runCapture(`import "std/fmt"; fn main()->i32{ let mut s:i32=0; for i in range(5) { s = s + i; } fmt.println(s); return 0;}`);
  eq(r.out, "10\n");
});

test("push mutates array", () => {
  const r = runCapture(`import "std/fmt"; fn main()->i32{ let mut a=[1]; push(a,2); push(a,3); fmt.println(a, len(a)); return 0;}`);
  eq(r.out, "[1, 2, 3] 3\n");
});

test("str module: upper/split/join", () => {
  const r = runCapture(`import "std/str"; import "std/fmt"; fn main()->i32{ let parts = str.split("a,b,c", ","); fmt.println(str.upper("hi"), parts[1], str.join(parts, "-")); return 0;}`);
  eq(r.out, "HI b a-b-c\n");
});

test("index assignment", () => {
  const r = runCapture(`import "std/fmt"; fn main()->i32{ let mut a=[1,2,3]; a[1]=99; fmt.println(a); return 0;}`);
  eq(r.out, "[1, 99, 3]\n");
});

test("for-in over string chars", () => {
  const r = runCapture(`import "std/fmt"; fn main()->i32{ let mut n:i32=0; for c in "hello" { n = n + 1; } fmt.println(n); return 0;}`);
  eq(r.out, "5\n");
});

test("CSP: spawn producer + recv (channel)", () => {
  const r = runCapture(`
    import "std/fmt";
    fn producer(c) { send(c, 1); send(c, 2); send(c, 3); }
    fn main()->i32{
      let c = channel();
      spawn producer(c);
      let mut sum:i32 = 0;
      let mut i:i32 = 0;
      while i < 3 { sum = sum + recv(c); i = i + 1; }
      fmt.println(sum);
      return 0;
    }`);
  eq(r.out, "6\n");
});

test("CSP: spawned task runs by program exit", () => {
  const r = runCapture(`
    import "std/fmt";
    fn worker(c) { send(c, 42); }
    fn main()->i32{
      let c = channel();
      spawn worker(c);
      fmt.println(recv(c));
      return 0;
    }`);
  eq(r.out, "42\n");
});

test("CSP: recv_any fan-in picks a ready channel", () => {
  const r = runCapture(`
    import "std/fmt";
    fn fill(c, v) { send(c, v); }
    fn main()->i32{
      let a = channel();
      let b = channel();
      spawn fill(b, 99);
      let res = recv_any([a, b]);
      fmt.println(res[0], res[1]);
      return 0;
    }`);
  eq(r.out, "1 99\n");
});

test("CSP: multiple producers fan-in sum", () => {
  const r = runCapture(`
    import "std/fmt";
    fn prod(c, v) { send(c, v); }
    fn main()->i32{
      let c = channel();
      spawn prod(c, 10);
      spawn prod(c, 20);
      spawn prod(c, 30);
      let mut sum:i32 = 0;
      let mut i:i32 = 0;
      while i < 3 { sum = sum + recv(c); i = i + 1; }
      fmt.println(sum);
      return 0;
    }`);
  eq(r.out, "60\n");
});

console.log(`\nRYZ tests: ${pass} passed, ${fail} failed`);
process.exit(fail === 0 ? 0 : 1);
