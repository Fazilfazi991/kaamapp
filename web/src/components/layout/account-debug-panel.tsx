import { accountDebugEnabled } from "@/lib/account-debug";

export function AccountDebugPanel({
  userId,
  email,
  role,
  hasCandidateProfile,
}: {
  userId: string;
  email: string | null;
  role: string;
  hasCandidateProfile: boolean;
}) {
  if (!accountDebugEnabled()) return null;
  const projectRef = process.env.NEXT_PUBLIC_SUPABASE_URL
    ? new URL(process.env.NEXT_PUBLIC_SUPABASE_URL).hostname.split(".")[0]
    : "not configured";
  const shortId = `${userId.slice(0, 8)}…`;
  const maskedEmail = email ? email.replace(/^(.{2}).*(@.*)$/, "$1…$2") : "Unavailable";
  return (
    <aside className="mb-4 rounded-lg border border-dashed border-[#d6b9c7] bg-[#fff7fa] p-3 text-xs text-[#514856]" aria-label="Account diagnostics">
      <p className="font-bold text-[#bc1f55]">Account diagnostics</p>
      <p>Supabase project: {projectRef}</p>
      <p>Auth email: {maskedEmail}</p>
      <p>Auth user ID: {shortId}</p>
      <p>Role: {role}</p>
      <p>Candidate profile ID: {hasCandidateProfile ? shortId : "missing"}</p>
    </aside>
  );
}
