#!/bin/sh
# Parses every JavaScript file the Jac compiler generated for the mobile app
# with Babel, so a bad emit (e.g. a state variable shadowing a style key) fails
# here with a readable message instead of inside Metro minutes later.
set -eu
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RN_DIR="${PROJECT_DIR}/.jac/mobile-rn"
BUN="$(ls /opt/jac/state/rt/*/site/jaclang/client/_bun/bun 2>/dev/null | head -1 || true)"
if [ -z "${BUN}" ]; then BUN="$(command -v bun || command -v node || true)"; fi
if [ -z "${BUN}" ] || [ ! -d "${RN_DIR}/node_modules/@babel/parser" ]; then
  echo "check_mobile_js: bun/node or @babel/parser not found; skipping syntax check"
  exit 0
fi
cd "${RN_DIR}"
"${BUN}" -e '
const fs = require("fs"), path = require("path");
const { parse } = require("@babel/parser");
const root = path.join(process.cwd(), "jac-src");
let bad = 0;
const walk = (d) => { for (const f of fs.readdirSync(d)) { const p = path.join(d, f);
  if (fs.statSync(p).isDirectory()) walk(p);
  else if (/\.(js|jsx|ts|tsx)$/.test(f)) {
    try { parse(fs.readFileSync(p, "utf8"), { sourceType: "module", plugins: ["jsx", "typescript"] }); }
    catch (e) { bad++; console.error("✖ " + path.relative(root, p) + ": " + e.message); }
  } } };
walk(root);
if (bad) { console.error(bad + " generated file(s) failed to parse."); process.exit(1); }
console.log("Generated mobile JavaScript parses cleanly.");
'
