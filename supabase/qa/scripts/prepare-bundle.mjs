import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { duplicateGroups, excluded, patches, sources } from "./bundle-config.mjs";

const qaDir = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const supabaseDir = resolve(qaDir, "..");
const selected = [...sources, ...patches];
const failures = [];
for (const group of duplicateGroups) {
  const hits = group.filter((file) => selected.includes(file));
  if (hits.length > 1) failures.push(`duplicate mutation selected: ${hits.join(" + ")}`);
}
for (const file of excluded) if (selected.includes(file)) failures.push(`excluded file selected: ${file}`);

const externalPattern = /\b(?:net\.http|http_(?:get|post)|pg_net|cron\.schedule|https?:\/\/|webhook|firebase|azure|smtp)\b/i;
// Business functions legitimately contain INSERT statements. Reject fixture-like literals instead:
// auth-user mutation, Storage object seeds, emails, the Production ref, or explicit fixture markers.
const prohibitedSeedPattern = /(?:insert\s+into\s+auth\.users|insert\s+into\s+storage\.objects|[\w.+-]+@[\w.-]+\.[a-z]{2,}|bhuhojzqxnvwbsypijac|\b(?:real|production)[_-]?(?:user|candidate|employer|payment|fixture)\b)/i;
const entries = [];
for (const [index, file] of selected.entries()) {
  const path = resolve(supabaseDir, file);
  const bytes = await readFile(path);
  const sql = bytes.toString("utf8");
  const executableSql = sql.replace(/--.*$/gm, "");
  if (sources.includes(file) && externalPattern.test(sql)) failures.push(`external side-effect token in selected source: ${file}`);
  if (prohibitedSeedPattern.test(executableSql)) failures.push(`prohibited application-data seed in: ${file}`);
  entries.push({
    order: index + 1,
    source: `supabase/${file.replaceAll("\\", "/")}`,
    sha256: createHash("sha256").update(bytes).digest("hex"),
    classification: index < sources.length ? "canonical-schema-source" : "qa-hardening-patch",
    canonicalStatus: file.startsWith("migrations/02") ? "canonical-duplicate-choice" : "canonical",
  });
}
if (failures.length) throw new Error(failures.join("\n"));
await writeFile(resolve(qaDir, "checksums.json"), `${JSON.stringify({ algorithm: "SHA-256", canonicalSourceCount: sources.length, totalSqlUnits: selected.length, entries }, null, 2)}\n`);
console.log(`BUNDLE VALID: ${sources.length} canonical sources + ${patches.length} patches = ${selected.length} SQL units`);
console.log("DUPLICATES: none selected together");
console.log("EXTERNAL SIDE EFFECTS: none detected in selected historical sources");
console.log("PROHIBITED APPLICATION SEEDS: none detected");
