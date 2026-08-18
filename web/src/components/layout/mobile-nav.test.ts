import { describe, expect, it } from "vitest";
import { mobileMenuLabel, mobileMenuNavigationLabel } from "./mobile-nav";

describe("mobile navigation labels", () => {
  it("uses a neutral menu label for every authenticated role", () => {
    expect(mobileMenuLabel).toBe("Menu");
    expect(mobileMenuNavigationLabel).toBe("Menu navigation");
  });
});
