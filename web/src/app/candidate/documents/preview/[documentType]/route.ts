import { NextResponse } from "next/server";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { getCandidateDocumentFilePath } from "@/features/candidate/documents/server/data";
import type { CandidateDocumentType } from "@/features/candidate/documents/types";

function safeDocumentType(value: string): CandidateDocumentType | null {
  return value === "passport" || value === "visa" ? value : null;
}

export async function GET(
  _request: Request,
  { params }: { params: Promise<{ documentType: string }> },
) {
  const { documentType } = await params;
  const type = safeDocumentType(documentType);
  if (!type) return NextResponse.json({ error: "Not found" }, { status: 404 });

  const path = await getCandidateDocumentFilePath(type);
  if (!path) return NextResponse.json({ error: "Not found" }, { status: 404 });

  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.storage.from("kaam-private").createSignedUrl(path, 60 * 10);
  if (error || !data?.signedUrl) {
    return NextResponse.json({ error: "Preview unavailable" }, { status: 404 });
  }

  const file = await fetch(data.signedUrl);
  if (!file.ok || !file.body) {
    return NextResponse.json({ error: "Preview unavailable" }, { status: 404 });
  }

  return new Response(file.body, {
    headers: {
      "content-type": file.headers.get("content-type") ?? "application/octet-stream",
      "cache-control": "private, max-age=0, no-store",
      "x-robots-tag": "noindex",
    },
  });
}
