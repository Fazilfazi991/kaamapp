import { redirect } from "next/navigation";
import { routes } from "@/config/routes";

export default async function RegisterPage({ searchParams }: { searchParams: Promise<{ role?: string }> }) {
  const requestedRole = (await searchParams).role;
  redirect(requestedRole === "employer" ? routes.employerRegister : routes.candidateRegister);
}
