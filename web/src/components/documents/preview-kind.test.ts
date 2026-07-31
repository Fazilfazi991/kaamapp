import { describe, expect, it } from "vitest";
import { secureDocumentPreviewKind } from "./preview-kind";

describe("secureDocumentPreviewKind", () => {
  it("detects supported image formats", () => {
    expect(secureDocumentPreviewKind("private/passport.JPG")).toBe("image");
    expect(secureDocumentPreviewKind("private/passport.jpeg")).toBe("image");
    expect(secureDocumentPreviewKind("private/passport.png")).toBe("image");
    expect(secureDocumentPreviewKind("private/passport.webp")).toBe("image");
  });

  it("detects PDFs and unsupported files", () => {
    expect(secureDocumentPreviewKind("private/document.pdf")).toBe("pdf");
    expect(secureDocumentPreviewKind("private/document.docx")).toBe("unsupported");
    expect(secureDocumentPreviewKind(null)).toBe("unavailable");
  });
});
