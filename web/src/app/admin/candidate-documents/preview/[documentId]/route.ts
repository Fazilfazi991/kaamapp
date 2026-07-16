import { NextResponse } from "next/server";
import { requireAdmin } from "@/features/admin/auth/require-admin";
import { createSignedPreview, loadCandidateDocument } from "@/features/admin/server/data";

export async function GET(_request: Request, { params }: { params: Promise<{ documentId: string }> }) {
  await requireAdmin();
  const { documentId } = await params;
  const document = await loadCandidateDocument(documentId);
  if (!document || !document.file_path) {
    return NextResponse.json({ error: "Preview unavailable" }, { status: 404 });
  }

  const signedUrl = await createSignedPreview({ bucket_id: "kaam-private", file_path: document.file_path });
  if (!signedUrl) return NextResponse.json({ error: "Preview unavailable" }, { status: 404 });
  return NextResponse.redirect(signedUrl);
}
