import type { Metadata } from "next";
import { AuthJourneyPage } from "@/features/auth/auth-journey-page";

export const metadata: Metadata = {
  title: "Register as Employer",
  description: "Create your KAAM Employer account and set up your company hiring workspace.",
};

export default function EmployerRegisterPage() {
  return <AuthJourneyPage role="employer" mode="register" />;
}
