type AccountDebugDetails = {
  userId: string;
  email: string | null;
  role: string | null;
  profileId: string | null;
  candidateId: string | null;
  candidateName: string | null;
};

export function accountDebugEnabled() {
  return process.env.NODE_ENV !== "production" || process.env.KAAM_ACCOUNT_DEBUG === "true";
}

export function accountDebug(details: AccountDebugDetails) {
  if (!accountDebugEnabled()) return;
  const projectRef = process.env.NEXT_PUBLIC_SUPABASE_URL
    ? new URL(process.env.NEXT_PUBLIC_SUPABASE_URL).hostname.split(".")[0]
    : "not configured";
  const id = (value: string | null) => (value ? `${value.slice(0, 8)}…` : "missing");
  const email = details.email ? details.email.replace(/^(.{2}).*(@.*)$/, "$1…$2") : "missing";
  console.debug("[ACCOUNT DEBUG]", {
    supabase_project: projectRef,
    "auth.uid": id(details.userId),
    "auth.email": email,
    role: details.role ?? "missing",
    "profile.id": id(details.profileId),
    "candidate_profile.id": id(details.candidateId),
    candidate_name: details.candidateName ?? "missing",
  });
}
