import { createServerSupabaseClient } from "@/lib/supabase/server";
import { requireRole } from "@/lib/auth/session";
import type {
  CandidateMembershipRow,
  CandidateProfileRow,
  CandidateSkillRow,
  ProfileRow,
  SkillCategoryRow,
  SkillRow,
} from "@/types/domain";

export type CandidateBundle = {
  userId: string;
  profile: ProfileRow | null;
  candidate: CandidateProfileRow | null;
  categories: SkillCategoryRow[];
  skills: SkillRow[];
  selectedSkills: CandidateSkillRow[];
  membership: CandidateMembershipRow | null;
};

export async function loadCandidateBundle(): Promise<CandidateBundle> {
  const account = await requireRole("candidate");
  const supabase = await createServerSupabaseClient();
  const [
    { data: profile },
    { data: candidate },
    { data: categories },
    { data: skills },
    { data: selectedSkills },
    { data: membership },
  ] = await Promise.all([
    supabase
      .from("profiles")
      .select("id, role, full_name, phone, email, status")
      .eq("id", account.userId)
      .maybeSingle<ProfileRow>(),
    supabase.from("candidate_profiles").select("*").eq("id", account.userId).maybeSingle<CandidateProfileRow>(),
    supabase
      .from("skill_categories")
      .select("id, name, slug, icon_name")
      .eq("is_active", true)
      .order("sort_order")
      .returns<SkillCategoryRow[]>(),
    supabase
      .from("skills")
      .select("id, category_id, name, slug")
      .eq("is_active", true)
      .eq("is_approved", true)
      .order("sort_order")
      .returns<SkillRow[]>(),
    supabase
      .from("candidate_skills")
      .select(
        "skill_id,is_primary,experience_range,skill_level,availability,skills!inner(id,name,slug,category_id,skill_categories!inner(id,name,slug,icon_name))",
      )
      .eq("candidate_id", account.userId)
      .returns<CandidateSkillRow[]>(),
    supabase
      .from("candidate_memberships")
      .select("status, plan_code, starts_at, expires_at")
      .eq("candidate_id", account.userId)
      .order("expires_at", { ascending: false })
      .limit(1)
      .maybeSingle<CandidateMembershipRow>(),
  ]);

  return {
    userId: account.userId,
    profile,
    candidate,
    categories: categories ?? [],
    skills: skills ?? [],
    selectedSkills: selectedSkills ?? [],
    membership,
  };
}
