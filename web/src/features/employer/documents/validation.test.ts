import { describe, expect, it } from "vitest";
import { employerDocumentMaxBytes, safeUploadPath, validateEmployerDocumentFile, validateEmployerLogoFile } from "./validation";

describe("employer document validation", () => {
  it("accepts trade licence PDF", () => {
    expect(validateEmployerDocumentFile("trade-license", "application/pdf", 1000).ok).toBe(true);
  });

  it("rejects unsupported document type", () => {
    expect(validateEmployerDocumentFile("passport", "application/pdf", 1000).ok).toBe(false);
  });

  it("rejects oversized business document", () => {
    expect(validateEmployerDocumentFile("trade-license", "application/pdf", employerDocumentMaxBytes + 1).ok).toBe(false);
  });

  it("rejects unsupported business document MIME", () => {
    expect(validateEmployerDocumentFile("trade-license", "text/plain", 1000).ok).toBe(false);
  });

  it("accepts valid logo image", () => {
    expect(validateEmployerLogoFile("image/png", 1000).ok).toBe(true);
  });

  it("rejects invalid logo", () => {
    expect(validateEmployerLogoFile("application/pdf", 1000).ok).toBe(false);
  });

  it("creates storage path without original personal filename", () => {
    const path = safeUploadPath({ userId: "employer-1", folder: "trade-license", fileName: "My Company License.pdf", now: 123 });
    expect(path).toBe("employer-1/trade-license/123_trade-license_123.pdf");
    expect(path).not.toContain("My Company");
  });
});
