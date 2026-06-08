#!/usr/bin/env bun
// RYZ CLI — `ryz run file.ryz`, `ryz eval '<src>'`, `ryz tokens file.ryz`, `ryz ast file.ryz`
import { lex } from "./lexer";
import { parse } from "./parser";
import { Interpreter } from "./interpreter";

const VERSION = "0.2.0";

function runSource(src: string): number {
  const toks = lex(src);
  const program = parse(toks);
  const interp = new Interpreter();
  return interp.run(program);
}

async function main() {
  const [cmd, ...rest] = process.argv.slice(2);
  try {
    switch (cmd) {
      case undefined:
      case "--version":
      case "version":
        console.log(`ryz ${VERSION} (Frankenstein: zig/rust/go/ts+bun/lua/java influences)`);
        return 0;
      case "run": {
        const file = rest[0];
        if (!file) { console.error("usage: ryz run <file.ryz>"); return 2; }
        const src = await Bun.file(file).text();
        return runSource(src);
      }
      case "eval": {
        const src = rest.join(" ");
        return runSource(src);
      }
      case "tokens": {
        const src = await Bun.file(rest[0]).text();
        console.log(JSON.stringify(lex(src), null, 2));
        return 0;
      }
      case "ast": {
        const src = await Bun.file(rest[0]).text();
        console.log(JSON.stringify(parse(lex(src)), null, 2));
        return 0;
      }
      default: {
        // treat as a path if it ends in .ryz
        if (cmd.endsWith(".ryz")) {
          const src = await Bun.file(cmd).text();
          return runSource(src);
        }
        console.error(`unknown command '${cmd}'. try: run | eval | tokens | ast | version`);
        return 2;
      }
    }
  } catch (e) {
    console.error(`ryz: ${(e as Error).message}`);
    return 1;
  }
}

main().then((code) => process.exit(code));
