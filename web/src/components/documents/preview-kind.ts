export type SecureDocumentPreviewKind = "image" | "pdf" | "unsupported" | "unavailable";

export function secureDocumentPreviewKind(filePath?: string | null): SecureDocumentPreviewKind {
  const extension = filePath?.split("?")[0]?.split(".").pop()?.toLowerCase();
  if (!extension) return "unavailable";
  if (["jpg", "jpeg", "png", "webp"].includes(extension)) return "image";
  if (extension === "pdf") return "pdf";
  return "unsupported";
}
