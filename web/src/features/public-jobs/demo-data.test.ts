import { describe, expect, it } from "vitest";

import { demoPublicHiringRequirements } from "@/features/public-jobs/demo-data";

describe("public jobs demo fixtures", () => {
  it("contains ten deterministic, explicitly demo-scoped requirements", () => {
    expect(demoPublicHiringRequirements).toHaveLength(10);
    expect(new Set(demoPublicHiringRequirements.map((job) => job.id)).size).toBe(10);
    expect(demoPublicHiringRequirements.every((job) => job.id.startsWith("demo-"))).toBe(true);
  });

  it("contains complete truthful card fields for QA", () => {
    expect(demoPublicHiringRequirements.every((job) => job.role && job.work_location && job.openings > 0 && job.application_deadline)).toBe(true);
  });
});
