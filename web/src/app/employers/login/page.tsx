import type { Metadata } from "next";
import { AuthJourneyPage } from "@/features/auth/auth-journey-page";

export const metadata: Metadata = {
  title: "Employer Login",
  description: "Sign in to your KAAM Employer account to manage hiring, candidates, and matches.",
};

export default function EmployerLoginPage() {
  return <AuthJourneyPage role="employer" mode="login" />;
}
