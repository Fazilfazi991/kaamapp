"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { requireRole } from "@/lib/auth/session";
import { routes } from "@/config/routes";
import {
  validateLocationSelection,
  validateSkillIds,
} from "@/features/candidate/validation";
import type { SkillCategoryRow, SkillRow } from "@/types/domain";

function text(formData: FormData, key: string) {
  return String(formData.get(key) ?? "").trim();
}

function intOrNull(value: string) {
  if (!value.trim()) return null;
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : null;
}

function numberOrNull(value: string) {
  if (!value.trim()) return null;
  const parsed = Number.parseFloat(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function safeError(message: string): never {
  throw new Error(message);
}

async function candidateClient() {
  const account = await requireRole("candidate");
  const supabase = await createServerSupabaseClient();
  return { account, supabase };
}

async function ensureCandidateRow() {
  const { account, supabase } = await candidateClient();
  const { error } = await supabase
    .from("candidate_profiles")
    .upsert({ id: account.userId }, { onConflict: "id" });
  if (error) safeError("Could not initialize your candidate profile.");
  return { account, supabase };
}

function revalidateCandidatePages() {
  revalidatePath(routes.candidateDashboard);
  revalidatePath(routes.candidateProfile);
  revalidatePath(routes.candidateProfileEdit);
  revalidatePath(routes.candidateOnboarding);
}

export async function savePersonalDetails(formData: FormData) {
  const fullName = text(formData, "fullName");
  const phone = text(formData, "phone");
  const nationality = text(formData, "nationality");
  const bio = text(formData, "bio");
  const photo = formData.get("profilePhoto");

  if (!fullName) safeError("Full name is required.");
  if (!phone || !/^[0-9+ ]{7,20}$/.test(phone)) {
    safeError("Enter a valid mobile number.");
  }
  if (!nationality) safeError("Nationality is required.");

  const { account, supabase } = await ensureCandidateRow();
  let profilePhotoPath: string | null | undefined;
  if (photo instanceof File && photo.size > 0) {
    const allowedTypes = ["image/jpeg", "image/png", "image/webp"];
    if (!allowedTypes.includes(photo.type)) {
      safeError("Profile photo must be a JPG, PNG, or WebP image.");
    }
    if (photo.size > 4 * 1024 * 1024) {
      safeError("Profile photo must be 4 MB or smaller.");
    }
    const extension = photo.name.split(".").pop()?.toLowerCase() || "jpg";
    const safeName = `profile-photo-${Date.now()}.${extension.replace(/[^a-z0-9]/g, "")}`;
    // Matches the mobile contract: the database stores a private Storage path,
    // never a public URL, and RLS scopes the first path segment to auth.uid().
    const path = `${account.userId}/candidate-profile-photos/${safeName}`;
    const { error: uploadError } = await supabase.storage
      .from("kaam-private")
      .upload(path, await photo.arrayBuffer(), {
        contentType: photo.type,
        upsert: false,
      });
    if (uploadError) safeError("Could not upload profile photo.");
    profilePhotoPath = path;
  }

  const candidateValues: Record<string, string | null> = {
    nationality,
    bio: bio || null,
  };
  if (profilePhotoPath) candidateValues.profile_photo_url = profilePhotoPath;

  const [{ error: profileError }, { error: candidateError }] = await Promise.all([
    supabase
      .from("profiles")
      .update({ full_name: fullName, phone, status: "active" })
      .eq("id", account.userId),
    supabase
      .from("candidate_profiles")
      .update(candidateValues)
      .eq("id", account.userId),
  ]);
  if (profileError || candidateError) safeError("Could not save personal details.");

  revalidateCandidatePages();
  redirect(String(formData.get("next") ?? routes.candidateOnboardingSkills));
}

export async function saveLocationDetails(formData: FormData) {
  const currentCountry = text(formData, "currentCountry");
  const currentRegion = text(formData, "currentRegion");
  const preferredCountry = text(formData, "preferredCountry");
  const preferredRegion = text(formData, "preferredRegion");
  const currentLocation = validateLocationSelection(currentCountry, currentRegion);
  const preferredLocation = validateLocationSelection(preferredCountry, preferredRegion);

  if (!currentLocation.ok) safeError(currentLocation.error);
  if (!preferredLocation.ok) safeError(preferredLocation.error);

  const { account, supabase } = await ensureCandidateRow();
  const { error } = await supabase
    .from("candidate_profiles")
    .update({
      current_country: currentLocation.value.country,
      current_city: currentLocation.value.region,
      preferred_country: preferredLocation.value.country,
      preferred_city: preferredLocation.value.region,
    })
    .eq("id", account.userId);
  if (error) safeError("Could not save location details.");

  revalidateCandidatePages();
  redirect(String(formData.get("next") ?? routes.candidateOnboardingExperience));
}

export async function saveExperienceDetails(formData: FormData) {
  const availability = text(formData, "availability");
  const experienceYears = numberOrNull(text(formData, "experienceYears"));
  const expectedSalaryMin = intOrNull(text(formData, "expectedSalaryMin"));
  const expectedSalaryMax = intOrNull(text(formData, "expectedSalaryMax"));
  const visaStatus = text(formData, "visaStatus");
  const languages = formData.getAll("languages").map(String).filter(Boolean);
  const hidePhoneBeforeMatch = formData.get("hidePhoneBeforeMatch") === "on";
  const hideEmailBeforeMatch = formData.get("hideEmailBeforeMatch") === "on";
  const isVisible = formData.get("isVisible") === "on";

  if (!availability) safeError("Availability is required.");
  if (experienceYears !== null && (experienceYears < 0 || experienceYears > 60)) {
    safeError("Enter a valid experience value.");
  }
  if (
    expectedSalaryMin !== null &&
    expectedSalaryMax !== null &&
    expectedSalaryMin > expectedSalaryMax
  ) {
    safeError("Minimum salary cannot be higher than maximum salary.");
  }

  const { account, supabase } = await ensureCandidateRow();
  const { error } = await supabase
    .from("candidate_profiles")
    .update({
      availability,
      experience_years: experienceYears,
      expected_salary_min: expectedSalaryMin,
      expected_salary_max: expectedSalaryMax,
      currency: "AED",
      visa_status: visaStatus || null,
      languages: [...new Set(languages)],
      hide_phone_before_match: hidePhoneBeforeMatch,
      hide_email_before_match: hideEmailBeforeMatch,
      is_visible: isVisible,
    })
    .eq("id", account.userId);
  if (error) safeError("Could not save experience details.");

  revalidateCandidatePages();
  redirect(String(formData.get("next") ?? routes.candidateOnboardingReview));
}

export async function saveCandidateSkills(formData: FormData) {
  const selectedIds = formData
    .getAll("skillIds")
    .flatMap((value) => String(value).split(","))
    .map((value) => value.trim())
    .filter(Boolean);
  const validation = validateSkillIds(selectedIds);
  if (!validation.ok) safeError(validation.error);
  const uniqueIds = validation.value;

  const { account, supabase } = await ensureCandidateRow();
  const { data: skillRows, error: skillError } = await supabase
    .from("skills")
    .select("id, category_id, name, skill_categories!inner(id,name,slug,icon_name)")
    .in("id", uniqueIds)
    .returns<Array<SkillRow & { skill_categories: SkillCategoryRow }>>();
  if (skillError || !skillRows || skillRows.length !== uniqueIds.length) {
    safeError("One or more selected skills are unavailable.");
  }

  const primaryId = uniqueIds[0];
  await supabase
    .from("candidate_skills")
    .update({ is_primary: false })
    .eq("candidate_id", account.userId);

  const upsertRows = skillRows.map((skill) => ({
    candidate_id: account.userId,
    skill_id: skill.id,
    is_primary: skill.id === primaryId,
  }));
  const { error: upsertError } = await supabase
    .from("candidate_skills")
    .upsert(upsertRows, { onConflict: "candidate_id,skill_id" });
  if (upsertError) safeError("Could not save selected skills.");

  const { data: existingSkills } = await supabase
    .from("candidate_skills")
    .select("skill_id")
    .eq("candidate_id", account.userId)
    .returns<Array<{ skill_id: string }>>();
  for (const existing of existingSkills ?? []) {
    if (!uniqueIds.includes(existing.skill_id)) {
      await supabase
        .from("candidate_skills")
        .delete()
        .eq("candidate_id", account.userId)
        .eq("skill_id", existing.skill_id);
    }
  }

  const orderedSkills = uniqueIds
    .map((id) => skillRows.find((skill) => skill.id === id))
    .filter((skill): skill is SkillRow & { skill_categories: SkillCategoryRow } => Boolean(skill));
  const primary = orderedSkills[0];
  const { error: profileError } = await supabase
    .from("candidate_profiles")
    .update({
      headline: primary.name,
      job_categories: [...new Set(orderedSkills.map((skill) => skill.skill_categories.name))],
      skills: orderedSkills.map((skill) => skill.name),
    })
    .eq("id", account.userId);
  if (profileError) safeError("Could not update your work profile.");

  revalidateCandidatePages();
  redirect(String(formData.get("next") ?? routes.candidateOnboardingLocation));
}

export async function finishCandidateOnboarding() {
  revalidateCandidatePages();
  redirect(routes.candidateDashboard);
}
