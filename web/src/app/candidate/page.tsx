import { redirect } from "next/navigation";
import { routes } from "@/config/routes";

export default function CandidateIndexPage() {
  redirect(routes.candidateDashboard);
}
