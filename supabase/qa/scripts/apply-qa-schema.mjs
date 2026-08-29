import { spawnSync } from "node:child_process";
import { appendFileSync, readFileSync } from "node:fs";
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
  const startedAt = new Date().toISOString();
  const result = spawnSync("psql", [connection, "-v", "ON_ERROR_STOP=1", "-f", file], { stdio: "inherit" });
  appendFileSync(logPath, `${JSON.stringify({ order: entry.order, source: entry.source, sha256: entry.sha256, startedAt, finishedAt: new Date().toISOString(), success: result.status === 0 })}\n`);
  if (result.status !== 0) throw new Error(`Stopped after failure in ${entry.source}`);
}
