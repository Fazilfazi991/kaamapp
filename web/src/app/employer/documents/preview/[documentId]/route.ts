import { NextResponse } from "next/server";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { getOwnedVerificationDocument } from "@/features/employer/server/profile-data";

export async function GET(_request: Request, { params }: { params: Promise<{ documentId: string }> }) {
  const { documentId } = await params;
  const document = await getOwnedVerificationDocument(documentId);
  if (!document) return NextResponse.json({ error: "Not found" }, { status: 404 });
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.storage.from(document.bucket_id).createSignedUrl(document.file_path, 60 * 10);
  if (error || !data?.signedUrl) return NextResponse.json({ error: "Preview unavailable" }, { status: 404 });
  const file = await fetch(data.signedUrl);
  if (!file.ok || !file.body) return NextResponse.json({ error: "Preview unavailable" }, { status: 404 });
  return new Response(file.body, {
    headers: {
      "content-type": file.headers.get("content-type") ?? "application/octet-stream",
      "cache-control": "private, max-age=0, no-store",
      "x-robots-tag": "noindex",
    },
  });
}
