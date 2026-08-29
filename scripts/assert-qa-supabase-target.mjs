import { pathToFileURL } from "node:url";

const PRODUCTION_PROJECT_REF = "bhuhojzqxnvwbsypijac";
const PROJECT_REF_PATTERN = /^[a-z]{20}$/;

export function projectRefFromUrl(value) {
  if (!value) return null;

  let hostname;
  try {
    hostname = new URL(value).hostname;
  } catch {
    throw new Error("The supplied Supabase URL is not a valid URL.");
  }

  const match = hostname.match(/^([a-z]{20})\.supabase\.co$/);
  if (!match) {
    throw new Error("The supplied URL is not a standard Supabase project URL.");
  }
  return match[1];
}

export function assertQaSupabaseTarget({ projectRef, supabaseUrl } = {}) {
  if (!projectRef) {
    throw new Error("Refusing QA write: an explicit project ref is required.");
  }
  if (!PROJECT_REF_PATTERN.test(projectRef)) {
    throw new Error("Refusing QA write: the project ref is malformed.");
  }
  if (projectRef === PRODUCTION_PROJECT_REF) {
    throw new Error(`Refusing QA write: ${PRODUCTION_PROJECT_REF} is the KAAM Production project.`);
  }

  if (!supabaseUrl) {
    throw new Error("Refusing QA write: an explicit Supabase URL is required.");
  }

  const urlProjectRef = projectRefFromUrl(supabaseUrl);
  if (urlProjectRef && urlProjectRef !== projectRef) {
    throw new Error("Refusing QA write: the project ref and Supabase URL identify different projects.");
  }

  return projectRef;
}

function argumentValue(name) {
  const index = process.argv.indexOf(name);
  return index === -1 ? undefined : process.argv[index + 1];
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const projectRef = assertQaSupabaseTarget({
      projectRef: argumentValue("--project-ref"),
      supabaseUrl: argumentValue("--supabase-url"),
    });
    console.log(`TARGET PROJECT REF: ${projectRef}`);
    console.log("QA TARGET VERIFIED: project ref differs from KAAM Production.");
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  }
}
