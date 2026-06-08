#!/usr/bin/env bun
// zenc — the RYZ/AeSH compiler-bundler. Produces NATIVE single-file binaries
// from the Bun reference sources via `bun build --compile`.
//   zenc build aesh      -> dist/aesh   (the AeSH shell binary)
//   zenc build ryz       -> dist/ryz    (the RYZ interpreter binary)
//   zenc run <file.ryz>  -> run a ryz program
//   zenc version
import * as path from "path";
import * as fs from "fs";
import { ryzToC } from "./ryzc";

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

async function gcc(args: string[]): Promise<number> {
  const proc = Bun.spawn(["gcc", ...args], { stdout: "inherit", stderr: "inherit" });
  return proc.exited;
}

// ryz -> C -> native ELF (executable). No bun/node at runtime.
// libs: ryz shared libraries (by base name) to link, e.g. ["mathlib"] -> -lmathlib from DIST.
async function buildNative(file: string, libs: string[] = []): Promise<number> {
  const src = await Bun.file(file).text();
  const base = path.basename(file).replace(/\.ryz$/, "");
  fs.mkdirSync(DIST, { recursive: true });
  const cFile = path.join(DIST, base + ".c");
  const outBin = path.join(DIST, base);
  fs.writeFileSync(cFile, ryzToC(src, "exec"));
  console.log(`zenc: ryz -> C: ${cFile}`);
  const linkArgs: string[] = [];
  if (libs.length) { linkArgs.push("-L", DIST, "-Wl,-rpath," + DIST); for (const l of libs) linkArgs.push("-l" + l); }
  const code = await gcc(["-O2", "-std=c11", "-o", outBin, cFile, ...linkArgs]);
  if (code === 0) { fs.chmodSync(outBin, 0o755); console.log(`zenc: native ELF -> ${outBin}${libs.length ? " (linked: " + libs.join(", ") + ")" : ""}`); }
  return code;
}

// ryz -> C -> shared library (.so). Exports `export fn`s as C-ABI symbols. LIBS.
async function buildLib(file: string): Promise<number> {
  const src = await Bun.file(file).text();
  const base = path.basename(file).replace(/\.ryz$/, "");
  fs.mkdirSync(DIST, { recursive: true });
  const cFile = path.join(DIST, "lib" + base + ".c");
  const outSo = path.join(DIST, "lib" + base + ".so");
  fs.writeFileSync(cFile, ryzToC(src, "lib"));
  console.log(`zenc: ryz -> C (lib): ${cFile}`);
  const code = await gcc(["-O2", "-std=c11", "-shared", "-fPIC", "-o", outSo, cFile]);
  if (code === 0) console.log(`zenc: shared library -> ${outSo}`);
  return code;
}

async function main(): Promise<number> {
  const [cmd, arg] = process.argv.slice(2);
  switch (cmd) {
    case "native": {
      if (!arg) { console.error("usage: zenc native <file.ryz> [--lib NAME ...]"); return 2; }
      const rest = process.argv.slice(2);
      const libs: string[] = [];
      for (let i = 0; i < rest.length; i++) if (rest[i] === "--lib" && rest[i + 1]) libs.push(rest[++i]);
      return buildNative(arg, libs);
    }
    case "lib": {
      if (!arg) { console.error("usage: zenc lib <file.ryz>"); return 2; }
      return buildLib(arg);
    }
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
