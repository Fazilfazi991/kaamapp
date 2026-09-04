export type PublicHiringRequirement = {
  id: string;
  role: string;
  custom_role: string | null;
  openings: number;
  work_location: string;
  application_deadline: string;
  created_at: string;
};

export function publicRequirementTitle(requirement: Pick<PublicHiringRequirement, "role" | "custom_role">) {
  return requirement.custom_role?.trim() || requirement.role.trim();
}
