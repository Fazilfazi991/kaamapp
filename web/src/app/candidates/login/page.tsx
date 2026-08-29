import type { Metadata } from "next";
import { AuthJourneyPage } from "@/features/auth/auth-journey-page";

export const metadata: Metadata = {
  title: "Candidate Login",
  description: "Sign in to your KAAM Candidate account to manage your profile, opportunities, and matches.",
};

export default function CandidateLoginPage() {
  return <AuthJourneyPage role="candidate" mode="login" />;
}
