import { redirect } from "next/navigation";
import { routes } from "@/config/routes";

export default function AccountRecoveryPage() {
  redirect(routes.accountSetup);
}
