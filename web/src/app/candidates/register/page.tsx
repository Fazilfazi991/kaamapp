import type { Metadata } from "next";
import { AuthJourneyPage } from "@/features/auth/auth-journey-page";

export const metadata: Metadata = {
  title: "Register as Candidate",
  description: "Create your KAAM Candidate account and start building your job-seeker profile.",
};

export default function CandidateRegisterPage() {
  return <AuthJourneyPage role="candidate" mode="register" />;
}
