import { Header } from "@/components/layout/header";
import { Footer } from "@/components/layout/footer";
import { AccountSetup } from "@/features/auth/account-setup";
import { requireAccountSetup } from "@/lib/auth/session";

export default async function AccountSetupPage() {
  const account = await requireAccountSetup();

  return (
    <>
      <Header />
      <main className="mx-auto grid min-h-[calc(100dvh-82px)] max-w-xl place-items-center px-4 py-10 sm:px-6">
        <AccountSetup email={account.email} />
      </main>
      <Footer />
    </>
  );
}
