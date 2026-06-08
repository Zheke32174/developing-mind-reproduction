// AeSH tests — drive the executor directly (deterministic, no TTY).
import { newState, runLine } from "../src/exec";

function capture(): { io: { out: (s: string) => void; err: (s: string) => void }; get: () => string; geterr: () => string } {
  let out = "", err = "";
  return { io: { out: (s) => (out += s), err: (s) => (err += s), capture: true }, get: () => out, geterr: () => err };
}

let pass = 0, fail = 0;
async function test(name: string, fn: () => Promise<void>) {
  try { await fn(); pass++; console.log(`  ok  ${name}`); }
  catch (e) { fail++; console.log(`FAIL  ${name}\n      ${(e as Error).message}`); }
}
function eq(a: unknown, b: unknown, m = "") { if (a !== b) throw new Error(`${m} expected ${JSON.stringify(b)}, got ${JSON.stringify(a)}`); }

await test("echo builtin", async () => {
  const c = capture(); const st = newState();
  await runLine("echo hello world", st, c.io);
  eq(c.get(), "hello world\n");
});

await test("pipeline echo|tr (external)", async () => {
  const c = capture(); const st = newState();
  const code = await runLine("echo hi there | tr a-z A-Z", st, c.io);
  eq(c.get(), "HI THERE\n"); eq(code, 0, "code");
});

await test("&& runs on success, || skips", async () => {
  const c = capture(); const st = newState();
  await runLine("true && echo yes || echo no", st, c.io);
  eq(c.get(), "yes\n");
});

await test("|| runs on failure", async () => {
  const c = capture(); const st = newState();
  await runLine("false && echo yes || echo no", st, c.io);
  eq(c.get(), "no\n");
});

await test("variable expansion + export", async () => {
  const c = capture(); const st = newState();
  await runLine("export NAME=ryz", st, c.io);
  await runLine("echo hello $NAME", st, c.io);
  eq(c.get(), "hello ryz\n");
});

await test("$? reflects last exit", async () => {
  const c = capture(); const st = newState();
  await runLine("false", st, c.io);
  await runLine("echo $?", st, c.io);
  eq(c.get(), "1\n");
});

await test("cd + pwd builtin", async () => {
  const c = capture(); const st = newState();
  await runLine("cd /tmp", st, c.io);
  await runLine("pwd", st, c.io);
  eq(c.get(), "/tmp\n");
});

await test("redirect > then read back via cat", async () => {
  const c = capture(); const st = newState();
  await runLine("echo persisted > /tmp/aesh_test_out.txt", st, c.io);
  const c2 = capture();
  await runLine("cat /tmp/aesh_test_out.txt", st, c2.io);
  eq(c2.get(), "persisted\n");
});

await test("semicolon sequence", async () => {
  const c = capture(); const st = newState();
  await runLine("echo a ; echo b", st, c.io);
  eq(c.get(), "a\nb\n");
});

await test("quoting keeps spaces", async () => {
  const c = capture(); const st = newState();
  await runLine('echo "one   two"', st, c.io);
  eq(c.get(), "one   two\n");
});

await test("history records commands", async () => {
  const c = capture(); const st = newState();
  await runLine("echo x", st, c.io);
  await runLine("echo y", st, c.io);
  eq(st.history.length, 2);
});

await test("single-quote is literal (no $ expansion)", async () => {
  const c = capture(); const st = newState();
  await runLine("export NAME=ryz", st, c.io);
  await runLine("echo '$NAME and $((1+1))'", st, c.io);
  eq(c.get(), "$NAME and $((1+1))\n");
});

await test("double-quote expands", async () => {
  const c = capture(); const st = newState();
  await runLine("export NAME=ryz", st, c.io);
  await runLine('echo "hi $NAME"', st, c.io);
  eq(c.get(), "hi ryz\n");
});

await test("command substitution $(...)", async () => {
  const c = capture(); const st = newState();
  await runLine("echo start-$(echo mid)-end", st, c.io);
  eq(c.get(), "start-mid-end\n");
});

await test("nested-ish command substitution with pipe", async () => {
  const c = capture(); const st = newState();
  await runLine('echo "[$(echo hello | tr a-z A-Z)]"', st, c.io);
  eq(c.get(), "[HELLO]\n");
});

await test("globbing expands * against cwd", async () => {
  const os = await import("os"); const fsm = await import("fs"); const pth = await import("path");
  const dir = fsm.mkdtempSync(pth.join(os.tmpdir(), "aeshglob-"));
  fsm.writeFileSync(pth.join(dir, "a.glb"), ""); fsm.writeFileSync(pth.join(dir, "b.glb"), ""); fsm.writeFileSync(pth.join(dir, "c.other"), "");
  const c = capture(); const st = newState(); st.cwd = dir;
  await runLine("echo *.glb", st, c.io);
  eq(c.get(), "a.glb b.glb\n");
  fsm.rmSync(dir, { recursive: true, force: true });
});

await test("glob with no match stays literal (nullglob off)", async () => {
  const os = await import("os"); const fsm = await import("fs"); const pth = await import("path");
  const dir = fsm.mkdtempSync(pth.join(os.tmpdir(), "aeshnoglob-"));
  const c = capture(); const st = newState(); st.cwd = dir;
  await runLine("echo *.nope", st, c.io);
  eq(c.get(), "*.nope\n");
  fsm.rmSync(dir, { recursive: true, force: true });
});

console.log(`\nAeSH tests: ${pass} passed, ${fail} failed`);
process.exit(fail === 0 ? 0 : 1);
