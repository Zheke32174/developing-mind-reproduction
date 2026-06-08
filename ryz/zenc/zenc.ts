#!/usr/bin/env bun
// zenc — the RYZ/AeSH compiler-bundler. Produces NATIVE single-file binaries
// from the Bun reference sources via `bun build --compile`.
//   zenc build aesh      -> dist/aesh   (the AeSH shell binary)
//   zenc build ryz       -> dist/ryz    (the RYZ interpreter binary)
//   zenc run <file.ryz>  -> run a ryz program
//   zenc version
import * as path from "path";
import * as fs from "fs";

const ZENC_DIR = path.dirname(new URL(import.meta.url).pathname);
const RYZ_HOME = path.resolve(ZENC_DIR, "..");
const DIST = path.join(RYZ_HOME, "dist");
const VERSION = "0.1.0";

const TARGETS: Record<string, { entry: string; outfile: string }> = {
  aesh: { entry: path.join(RYZ_HOME, "aesh", "src", "aesh.ts"), outfile: path.join(DIST, "aesh") },
  ryz: { entry: path.join(RYZ_HOME, "bun", "src", "ryz.ts"), outfile: path.join(DIST, "ryz") },
};

function realBun(): string {
  for (const b of [process.env.HOME + "/.bun/bin/bun", "/home/fixxia/.bun/bin/bun"]) {
    try { if (fs.statSync(b).isFile()) return b; } catch {}
  }
  return "bun";
}

async function compile(name: string): Promise<number> {
  const t = TARGETS[name];
  if (!t) { console.error(`zenc: unknown target '${name}'. known: ${Object.keys(TARGETS).join(", ")}`); return 2; }
  fs.mkdirSync(DIST, { recursive: true });
  console.log(`zenc: compiling ${name} -> ${t.outfile}`);
  const proc = Bun.spawn([realBun(), "build", "--compile", t.entry, "--outfile", t.outfile], { stdout: "inherit", stderr: "inherit" });
  const code = await proc.exited;
  if (code === 0) {
    try { fs.chmodSync(t.outfile, 0o755); } catch {}
    const sz = (fs.statSync(t.outfile).size / 1024 / 1024).toFixed(1);
    console.log(`zenc: built ${name} (${sz} MB native binary) at ${t.outfile}`);
  } else {
    console.error(`zenc: build of ${name} failed (exit ${code})`);
  }
  return code;
}

async function main(): Promise<number> {
  const [cmd, arg] = process.argv.slice(2);
  switch (cmd) {
    case "build": {
      if (!arg || arg === "all") {
        let rc = 0;
        for (const n of Object.keys(TARGETS)) rc = (await compile(n)) || rc;
        return rc;
      }
      return compile(arg);
    }
    case "run": {
      const proc = Bun.spawn([realBun(), TARGETS.ryz.entry, "run", arg], { stdout: "inherit", stderr: "inherit", stdin: "inherit" });
      return proc.exited;
    }
    case "version": case undefined:
      console.log(`zenc ${VERSION} — RYZ/AeSH native compiler (bun-compile backend)`);
      return 0;
    default:
      console.error(`zenc: unknown command '${cmd}'. try: build | run | version`);
      return 2;
  }
}

main().then((c) => process.exit(c));
