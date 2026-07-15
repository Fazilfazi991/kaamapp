import { NextResponse } from "next/server";
import { requireAdmin } from "@/features/admin/auth/require-admin";
import { createSignedPreview, loadEmployerDocument } from "@/features/admin/server/data";

export async function GET(_request: Request, { params }: { params: Promise<{ documentId: string }> }) {
  await requireAdmin();
  const { documentId } = await params;
  const document = await loadEmployerDocument(documentId);
  if (!document || !document.file_path) {
    return NextResponse.json({ error: "Preview unavailable" }, { status: 404 });
  }

  const signedUrl = await createSignedPreview(document);
  if (!signedUrl) return NextResponse.json({ error: "Preview unavailable" }, { status: 404 });
  return NextResponse.redirect(signedUrl);
}
