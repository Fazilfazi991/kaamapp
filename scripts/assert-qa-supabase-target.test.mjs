import assert from "node:assert/strict";
import test from "node:test";
import { assertQaSupabaseTarget, projectRefFromUrl } from "./assert-qa-supabase-target.mjs";

const productionRef = "bhuhojzqxnvwbsypijac";
const qaRef = "skswbbcimwvwmuiapjnd";

test("refuses a missing target", () => {
  assert.throws(() => assertQaSupabaseTarget(), /explicit project ref is required/);
});

test("refuses the KAAM Production project", () => {
  assert.throws(
    () => assertQaSupabaseTarget({ projectRef: productionRef }),
    /KAAM Production project/,
  );
});

test("refuses malformed and mismatched targets", () => {
  assert.throws(() => assertQaSupabaseTarget({ projectRef: "qa" }), /malformed/);
  assert.throws(
    () => assertQaSupabaseTarget({ projectRef: qaRef }),
    /explicit Supabase URL is required/,
  );
  assert.throws(
    () => assertQaSupabaseTarget({
      projectRef: qaRef,
      supabaseUrl: "https://zyxwvutsrqponmlkjihg.supabase.co",
    }),
    /identify different projects/,
  );
});

test("accepts a matching non-production project and URL", () => {
  assert.equal(
    assertQaSupabaseTarget({
      projectRef: qaRef,
      supabaseUrl: `https://${qaRef}.supabase.co`,
    }),
    qaRef,
  );
  assert.equal(projectRefFromUrl(`https://${qaRef}.supabase.co`), qaRef);
});
