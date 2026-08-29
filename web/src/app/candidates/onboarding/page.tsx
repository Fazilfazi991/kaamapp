import { redirect } from "next/navigation";
import { routes } from "@/config/routes";

export default function CandidateOnboardingAlias() {
  redirect(routes.candidateOnboarding);
}
