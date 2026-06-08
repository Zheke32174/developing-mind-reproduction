#!/usr/bin/env bun
// Factory Operator v0 — gradual, self-orchestrating, HUMAN-IN-THE-LOOP.
// Reads the Task Master schedule, proposes the next actionable brick, and BLOCKS on
// explicit human approval before any outward/destructive action. Leaves receipts.
//
// Modes (safe by default):
//   operator propose            -> print the next actionable task; take NO action (default)
//   operator status             -> schedule summary
//   operator approve <id>       -> record approval for task <id> in the ledger (still no exec)
//   operator execute <id>       -> ONLY runs if an approval receipt for <id> exists AND
//                                  --i-am-the-operator is passed; otherwise refuses (HITL gate).
//
// "Gradual": v0 proposes + gates + logs. Dispatch to the hive is stubbed behind the gate so
// no unapproved/outward action can occur. This is the seed of the self-orchestrated operator.
import * as fs from "fs";
import * as path from "path";

const TM = process.env.TASKMASTER_FILE ?? "/workspaces/gentoo/.taskmaster/tasks/tasks.json";
const HERE = path.dirname(new URL(import.meta.url).pathname);
const LEDGER = process.env.OPERATOR_LEDGER ?? path.join(HERE, "operator_ledger.jsonl");

interface Task { id: number; title: string; status: string; dependencies?: number[]; priority?: string; description?: string; }

function loadTasks(): Task[] {
  const j = JSON.parse(fs.readFileSync(TM, "utf8"));
  return (j.master?.tasks ?? j.tasks ?? []) as Task[];
}
function isDone(s: string) { return s === "done"; }
function nextActionable(tasks: Task[]): Task | null {
  const byId = new Map(tasks.map((t) => [t.id, t]));
  const pending = tasks.filter((t) => t.status !== "done" && t.status !== "cancelled");
  // prefer in-progress, then pending whose deps are all done; order by priority then id
  const rank = (p?: string) => (p === "high" ? 0 : p === "medium" ? 1 : 2);
  const ready = pending.filter((t) => (t.dependencies ?? []).every((d) => isDone(byId.get(d)?.status ?? "")));
  ready.sort((a, b) => (a.status === "in-progress" ? -1 : 0) - (b.status === "in-progress" ? -1 : 0) || rank(a.priority) - rank(b.priority) || a.id - b.id);
  return ready[0] ?? null;
}
function ledgerAppend(entry: object) {
  // NOTE: timestamp injected by caller env to keep the program deterministic/testable.
  fs.appendFileSync(LEDGER, JSON.stringify({ ts: process.env.OPERATOR_TS ?? "", ...entry }) + "\n");
}
function approvals(): Set<number> {
  if (!fs.existsSync(LEDGER)) return new Set();
  const ids = new Set<number>();
  for (const line of fs.readFileSync(LEDGER, "utf8").split("\n").filter(Boolean)) {
    try { const e = JSON.parse(line); if (e.kind === "approval") ids.add(e.id); } catch {}
  }
  return ids;
}

function main(): number {
  const [cmd, arg] = process.argv.slice(2);
  const tasks = loadTasks();

  switch (cmd) {
    case "status": {
      const counts: Record<string, number> = {};
      for (const t of tasks) counts[t.status] = (counts[t.status] ?? 0) + 1;
      console.log("Task Master:", JSON.stringify(counts));
      const n = nextActionable(tasks);
      console.log("next actionable:", n ? `#${n.id} ${n.title}` : "(none — schedule clear)");
      return 0;
    }
    case "propose":
    case undefined: {
      const n = nextActionable(tasks);
      if (!n) { console.log("PROPOSAL: schedule is clear — no actionable task. Operator idle."); return 0; }
      console.log("=== OPERATOR PROPOSAL (no action taken) ===");
      console.log(`task:     #${n.id} ${n.title}`);
      console.log(`priority: ${n.priority ?? "normal"}   status: ${n.status}`);
      if (n.description) console.log(`what:     ${n.description}`);
      console.log(`deps:     ${(n.dependencies ?? []).join(", ") || "none"} (all satisfied)`);
      console.log("HITL gate: requires `operator approve " + n.id + "` then `operator execute " + n.id +
        " --i-am-the-operator`. No outward/destructive action without that.");
      ledgerAppend({ kind: "proposal", id: n.id, title: n.title });
      return 0;
    }
    case "approve": {
      const id = parseInt(arg ?? "", 10);
      if (Number.isNaN(id)) { console.error("usage: operator approve <taskId>"); return 2; }
      ledgerAppend({ kind: "approval", id });
      console.log(`recorded human approval for task #${id}. (execution still requires --i-am-the-operator)`);
      return 0;
    }
    case "execute": {
      const id = parseInt(arg ?? "", 10);
      const human = process.argv.includes("--i-am-the-operator");
      if (Number.isNaN(id)) { console.error("usage: operator execute <taskId> --i-am-the-operator"); return 2; }
      if (!approvals().has(id)) { console.error(`REFUSED: no human approval on record for #${id}. Run 'operator approve ${id}' first.`); return 3; }
      if (!human) { console.error(`REFUSED: HITL gate — pass --i-am-the-operator to confirm a human authorized this.`); return 3; }
      // v0: dispatch is intentionally a stub. A future version routes to the hive
      // (parallel_hive_orchestrator / an agent). We DO NOT perform outward actions here.
      ledgerAppend({ kind: "execute-authorized", id, note: "v0 stub — dispatch not yet wired; no outward action" });
      console.log(`AUTHORIZED execute for #${id}. v0: dispatch is stubbed (no outward action). Receipt logged.`);
      return 0;
    }
    default:
      console.error(`unknown command '${cmd}'. try: status | propose | approve <id> | execute <id> --i-am-the-operator`);
      return 2;
  }
}

process.exit(main());
