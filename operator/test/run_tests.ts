// Operator v0 tests — verify HITL gating: propose takes no action; execute refuses
// without approval; approval + --i-am-the-operator authorizes (stub, still no outward action).
import * as fs from "fs";
import * as os from "os";
import * as path from "path";

const HERE = path.dirname(new URL(import.meta.url).pathname);
const OP = path.join(HERE, "..", "operator.ts");
const BUN = process.env.HOME + "/.bun/bin/bun";

// fixture schedule: #1 done, #2 pending (dep #1 -> ready), #3 pending (dep #2 -> blocked)
const fixture = {
  master: { tasks: [
    { id: 1, title: "alpha", status: "done", dependencies: [] },
    { id: 2, title: "beta", status: "pending", dependencies: [1], priority: "high", description: "do beta" },
    { id: 3, title: "gamma", status: "pending", dependencies: [2], priority: "high" },
  ] },
};

const dir = fs.mkdtempSync(path.join(os.tmpdir(), "op-"));
const TM = path.join(dir, "tasks.json");
const LED = path.join(dir, "ledger.jsonl");
fs.writeFileSync(TM, JSON.stringify(fixture));

function run(args: string[]): { out: string; err: string; code: number } {
  const p = Bun.spawnSync([BUN, OP, ...args], { env: { ...process.env, TASKMASTER_FILE: TM, OPERATOR_LEDGER: LED, OPERATOR_TS: "TEST" } });
  return { out: p.stdout.toString(), err: p.stderr.toString(), code: p.exitCode };
}

let pass = 0, fail = 0;
function test(name: string, fn: () => void) { try { fn(); pass++; console.log(`  ok  ${name}`); } catch (e) { fail++; console.log(`FAIL  ${name}\n      ${(e as Error).message}`); } }
function assert(c: boolean, m: string) { if (!c) throw new Error(m); }

test("propose picks the ready task (#2), not the blocked one (#3)", () => {
  const r = run(["propose"]);
  assert(r.out.includes("#2 beta"), "should propose #2: " + r.out);
  assert(!r.out.includes("#3 gamma"), "must not propose blocked #3");
  assert(r.code === 0, "exit 0");
});

test("propose takes NO outward action (only a proposal receipt)", () => {
  const led = fs.existsSync(LED) ? fs.readFileSync(LED, "utf8") : "";
  assert(led.includes('"kind":"proposal"'), "proposal logged");
  assert(!led.includes("execute-authorized"), "no execution from propose");
});

test("execute REFUSED without approval", () => {
  const r = run(["execute", "2", "--i-am-the-operator"]);
  assert(r.code === 3, "should refuse (exit 3): " + r.code);
  assert(r.err.includes("no human approval"), "refusal reason: " + r.err);
});

test("execute REFUSED without --i-am-the-operator even after approval", () => {
  run(["approve", "2"]);
  const r = run(["execute", "2"]);
  assert(r.code === 3, "should refuse without human flag");
  assert(r.err.includes("HITL gate"), "HITL refusal: " + r.err);
});

test("execute AUTHORIZED only with approval + human flag (stub, no outward action)", () => {
  const r = run(["execute", "2", "--i-am-the-operator"]);
  assert(r.code === 0, "authorized: " + r.err);
  assert(r.out.includes("AUTHORIZED"), "authorized msg");
  const led = fs.readFileSync(LED, "utf8");
  assert(led.includes("execute-authorized"), "execute receipt logged");
  assert(led.includes("no outward action"), "stub: still no outward action");
});

fs.rmSync(dir, { recursive: true, force: true });
console.log(`\nOperator tests: ${pass} passed, ${fail} failed`);
process.exit(fail === 0 ? 0 : 1);
