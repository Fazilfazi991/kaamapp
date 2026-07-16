export const employerDocumentTypes = [
  {
    type: "trade-license",
    label: "Trade licence",
    required: true,
    publicFile: false,
  },
  {
    type: "authorization-letter",
    label: "Authorization letter",
    required: false,
    publicFile: false,
  },
] as const;

export const employerLogoType = "company-logo";
export const employerDocumentMaxBytes = 10 * 1024 * 1024;
export const employerLogoMaxBytes = 4 * 1024 * 1024;
const allowedDocumentTypes = ["image/jpeg", "image/png", "image/webp", "application/pdf"];
const allowedLogoTypes = ["image/jpeg", "image/png", "image/webp"];

export function documentTypeConfig(type: string) {
  return employerDocumentTypes.find((document) => document.type === type) ?? null;
}

export function validateEmployerDocumentFile(type: string, mimeType: string, size: number) {
  if (!documentTypeConfig(type)) return { ok: false as const, error: "Unsupported document type." };
  if (!size) return { ok: false as const, error: "Choose a document file first." };
  if (size > employerDocumentMaxBytes) return { ok: false as const, error: "Document must be 10 MB or smaller." };
  if (!allowedDocumentTypes.includes(mimeType)) return { ok: false as const, error: "Use a JPG, PNG, WebP, or PDF file." };
  return { ok: true as const };
}

export function validateEmployerLogoFile(mimeType: string, size: number) {
  if (!size) return { ok: false as const, error: "Choose a logo file first." };
  if (size > employerLogoMaxBytes) return { ok: false as const, error: "Logo must be 4 MB or smaller." };
  if (!allowedLogoTypes.includes(mimeType)) return { ok: false as const, error: "Logo must be a JPG, PNG, or WebP image." };
  return { ok: true as const };
}

export function safeUploadPath({ userId, folder, fileName, now = Date.now() }: { userId: string; folder: string; fileName: string; now?: number }) {
  const extension = fileName.includes(".") ? fileName.split(".").pop()?.toLowerCase() ?? "bin" : "bin";
  const safeFolder = folder.replace(/[^A-Za-z0-9_-]/g, "-");
  const safeName = `${safeFolder}_${now}.${extension.replace(/[^a-z0-9]/g, "") || "bin"}`;
  return `${userId}/${safeFolder}/${now}_${safeName}`;
}
