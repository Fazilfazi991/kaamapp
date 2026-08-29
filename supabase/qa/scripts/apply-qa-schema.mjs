import { spawnSync } from "node:child_process";
import { appendFileSync, readFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { assertQaSupabaseTarget } from "../../../scripts/assert-qa-supabase-target.mjs";
import { patches, productionRef, qaRef, qaUrl, sources } from "./bundle-config.mjs";

const args = new Set(process.argv.slice(2));
const value = (flag) => process.argv[process.argv.indexOf(flag) + 1];
const projectRef = value("--project-ref");
const supabaseUrl = value("--supabase-url");
assertQaSupabaseTarget({ projectRef, supabaseUrl });
if (projectRef !== qaRef || supabaseUrl !== qaUrl) throw new Error("This bundle is locked to the verified Kaam QA project.");
console.log("TARGET PROJECT: Kaam QA");
console.log(`TARGET PROJECT REF: ${qaRef}`);
console.log(`PRODUCTION PROJECT REF: ${productionRef}`);
console.log("SAFE TO CONTINUE: YES");

const qaDir = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const supabaseDir = resolve(qaDir, "..");
const manifest = JSON.parse(readFileSync(resolve(qaDir, "checksums.json"), "utf8"));
console.log(`PLAN: ${sources.length} canonical sources followed by ${patches.length} hardening patches`);
for (const entry of manifest.entries) console.log(`${String(entry.order).padStart(2, "0")} ${entry.source} ${entry.sha256}`);

if (!args.has("--execute")) {
  console.log("DRY RUN ONLY: no database connection opened and no SQL executed.");
  process.exit(0);
}
const connection = process.env.QA_DATABASE_URL;
if (!connection || !connection.includes(qaRef)) throw new Error("QA_DATABASE_URL must be set and must identify the verified QA ref.");
const logPath = resolve(qaDir, "qa-schema-apply.log.jsonl");
for (const entry of manifest.entries) {
  const file = resolve(supabaseDir, entry.source.replace(/^supabase\//, ""));
  const actualSha256 = createHash("sha256").update(readFileSync(file)).digest("hex");
  if (actualSha256 !== entry.sha256) throw new Error(`Checksum mismatch before execution: ${entry.source}`);
  const startedAt = new Date().toISOString();
  const startedMs = Date.now();
  const npxCli = resolve(dirname(process.execPath), "node_modules", "npm", "bin", "npx-cli.js");
  const result = spawnSync(process.execPath, [npxCli, "supabase", "db", "query", "--db-url", connection, "--file", file], { encoding: "utf8" });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr.replaceAll(connection, "[REDACTED_QA_DATABASE_URL]"));
  const errorText = result.status === 0 ? null : `${result.stderr || result.stdout || result.error || "unknown error"}`.replaceAll(connection, "[REDACTED_QA_DATABASE_URL]");
  const sqlstate = errorText?.match(/(?:SQLSTATE|code)[^0-9A-Z]*([0-9A-Z]{5})/i)?.[1] ?? null;
  appendFileSync(logPath, `${JSON.stringify({ order: entry.order, source: entry.source, expectedSha256: entry.sha256, actualSha256, startedAt, finishedAt: new Date().toISOString(), durationMs: Date.now() - startedMs, success: result.status === 0, sqlstate, error: errorText })}\n`);
  if (result.status !== 0) throw new Error(`Stopped after failure in ${entry.source}`);
}
