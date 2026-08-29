import { spawnSync } from "node:child_process";
import { appendFileSync, readFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { existsSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { assertQaSupabaseTarget } from "../../../scripts/assert-qa-supabase-target.mjs";
import { patches, productionRef, qaRef, qaUrl, sources } from "./bundle-config.mjs";

const args = new Set(process.argv.slice(2));
const value = (flag) => process.argv[process.argv.indexOf(flag) + 1];
const projectRef = value("--project-ref");
const supabaseUrl = value("--supabase-url");
const startOrder = Number(value("--start-order") || "1");
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
const databaseUrl = new URL(connection);
const databaseUsername = decodeURIComponent(databaseUrl.username);
const isApprovedDirect = databaseUrl.hostname === `db.${qaRef}.supabase.co` && databaseUsername === "postgres";
const isApprovedSessionPooler = databaseUrl.hostname === "aws-0-ap-southeast-1.pooler.supabase.com" && databaseUsername === `postgres.${qaRef}`;
if ((!isApprovedDirect && !isApprovedSessionPooler) || databaseUrl.hostname.includes(productionRef) || databaseUsername.includes(productionRef)) {
  throw new Error("QA_DATABASE_URL is not an approved Kaam QA direct or Session Pooler identity.");
}
const psqlPath = process.env.PSQL_PATH || "C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe";
if (!existsSync(psqlPath)) throw new Error("A trusted psql executable was not found. Set PSQL_PATH explicitly.");
const psqlEnvironment = {
  ...process.env,
  PGHOST: databaseUrl.hostname,
  PGPORT: databaseUrl.port || "5432",
  PGDATABASE: decodeURIComponent(databaseUrl.pathname.replace(/^\//, "") || "postgres"),
  PGUSER: databaseUsername,
  PGPASSWORD: decodeURIComponent(databaseUrl.password),
  PGSSLMODE: "require",
};
delete psqlEnvironment.QA_DATABASE_URL;
const logPath = resolve(qaDir, "qa-schema-apply.log.jsonl");
if (!Number.isInteger(startOrder) || startOrder < 1 || startOrder > manifest.entries.length) throw new Error("--start-order is invalid.");
if (startOrder > 1) {
  const ledger = readFileSync(logPath, "utf8").trim().split(/\r?\n/).filter(Boolean).map((line) => JSON.parse(line));
  for (let order = 1; order < startOrder; order += 1) {
    if (!ledger.some((row) => row.order === order && row.success === true)) throw new Error(`Cannot resume: unit ${order} has no successful ledger entry.`);
  }
}
for (const entry of manifest.entries.filter((item) => item.order >= startOrder)) {
  const file = resolve(supabaseDir, entry.source.replace(/^supabase\//, ""));
  const actualSha256 = createHash("sha256").update(readFileSync(file)).digest("hex");
  if (actualSha256 !== entry.sha256) throw new Error(`Checksum mismatch before execution: ${entry.source}`);
  const startedAt = new Date().toISOString();
  const startedMs = Date.now();
  const result = spawnSync(psqlPath, ["-X", "-v", "ON_ERROR_STOP=1", "-v", "VERBOSITY=verbose", "-f", file], { encoding: "utf8", env: psqlEnvironment });
  if (result.stdout) process.stdout.write(result.stdout);
  const redact = (value) => `${value ?? ""}`
    .replaceAll(connection, "[REDACTED_QA_DATABASE_URL]")
    .replaceAll(psqlEnvironment.PGPASSWORD, "[REDACTED_PASSWORD]");
  if (result.stderr) process.stderr.write(redact(result.stderr));
  const errorText = result.status === 0 ? null : redact(result.stderr || result.stdout || result.error || "unknown error");
  const sqlstate = errorText?.match(/(?:SQLSTATE|code)[^0-9A-Z]*([0-9A-Z]{5})/i)?.[1] ?? null;
  appendFileSync(logPath, `${JSON.stringify({ order: entry.order, source: entry.source, expectedSha256: entry.sha256, actualSha256, startedAt, finishedAt: new Date().toISOString(), durationMs: Date.now() - startedMs, success: result.status === 0, sqlstate, error: errorText })}\n`);
  if (result.status !== 0) throw new Error(`Stopped after failure in ${entry.source}`);
}
