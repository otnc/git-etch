#!/usr/bin/env node
// SPDX-License-Identifier: MIT OR Apache-2.0

/**
 * コミットする pincree-sounds.b64 と、.gitignore で除外している JSON Lines の pincree-sounds.jsonl を相互に変換する。
 * @example
 * node scripts/pincree-sounds.mjs decode  # pincree-sounds.b64 -> pincree-sounds.jsonl
 * node scripts/pincree-sounds.mjs encode  # pincree-sounds.jsonl -> pincree-sounds.b64
 */

import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const repoRoot = fileURLToPath(new URL("..", import.meta.url));
const encodedPath = `${repoRoot}pincree-sounds.b64`;
const decodedPath = `${repoRoot}pincree-sounds.jsonl`;

// install.sh がデコードの代替手段に使う openssl base64 -d は、64文字を超える行を受け付けない。
const base64LineLength = 64;

function decode() {
  const jsonLines = Buffer.from(readFileSync(encodedPath, "utf8"), "base64").toString("utf8");
  writeFileSync(decodedPath, jsonLines);
  console.log(`Wrote ${decodedPath}`);
}

function encode() {
  const jsonLines = readFileSync(decodedPath, "utf8").replace(/\r\n/g, "\n");
  const text = jsonLines.endsWith("\n") ? jsonLines : `${jsonLines}\n`;
  const encoded = Buffer.from(text, "utf8").toString("base64");
  const lines = encoded.match(new RegExp(`.{1,${base64LineLength}}`, "g")) ?? [];
  writeFileSync(encodedPath, `${lines.join("\n")}\n`);
  console.log(`Wrote ${encodedPath}`);
}

const commands = { decode, encode };
const command = commands[process.argv[2] ?? "decode"];
if (!command) {
  console.error("Usage: node scripts/pincree-sounds.mjs [decode|encode]");
  process.exit(1);
}
command();
