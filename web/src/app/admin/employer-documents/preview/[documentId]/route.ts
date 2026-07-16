import { NextResponse } from "next/server";
import { requireAdmin } from "@/features/admin/auth/require-admin";
import { createSignedPreview, loadEmployerDocument } from "@/features/admin/server/data";

function previewUnavailable(status = 404) {
  return new NextResponse(
    "<!doctype html><html><body style=\"font-family: system-ui, sans-serif; padding: 24px; color: #4f4652;\">Document preview is temporarily unavailable.</body></html>",
    {
      status,
      headers: { "content-type": "text/html; charset=utf-8" },
    },
  );
}

export async function GET(_request: Request, { params }: { params: Promise<{ documentId: string }> }) {
  await requireAdmin();
  const { documentId } = await params;
  const document = await loadEmployerDocument(documentId);
  if (!document || !document.file_path) {
    return previewUnavailable();
  }

  const signedUrl = await createSignedPreview(document);
  if (!signedUrl) return previewUnavailable();
  return NextResponse.redirect(signedUrl);
}
