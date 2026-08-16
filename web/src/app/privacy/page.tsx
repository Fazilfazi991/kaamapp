import { permanentRedirect } from "next/navigation";

const canonicalPrivacyPolicy = "https://www.fusionventuresglobal.com/kaam/privacy-policy";

export default function PrivacyPage() {
  permanentRedirect(canonicalPrivacyPolicy);
}
