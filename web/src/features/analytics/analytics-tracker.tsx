"use client";
import { useEffect, useRef } from "react";
import { usePathname, useSearchParams } from "next/navigation";
import { track } from "./tracker";
import { trackGoogleAnalyticsEvent, trackGoogleAnalyticsEventOnce, trackGoogleAnalyticsPageView } from "./ga4";

export function AnalyticsTracker() {
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const last = useRef("");
  useEffect(() => {
    if (!pathname || pathname === last.current) return;
    const previous = last.current;
    last.current = pathname;
    track("page_view");
    trackGoogleAnalyticsPageView(pathname);
    if (pathname === "/account/setup") trackGoogleAnalyticsEventOnce("account-setup-viewed", "account_setup_viewed");
    if (pathname.startsWith("/candidate/onboarding")) trackGoogleAnalyticsEventOnce("candidate-onboarding-started", "candidate_onboarding_started");
    if (pathname.startsWith("/employer/onboarding")) trackGoogleAnalyticsEventOnce("employer-onboarding-started", "employer_onboarding_started");
    if (pathname === "/candidate/membership") trackGoogleAnalyticsEvent("membership_page_viewed");
    if (pathname === "/employer/search") trackGoogleAnalyticsEvent("candidate_search_viewed");
    if (pathname.startsWith("/employer/candidates/")) trackGoogleAnalyticsEvent("candidate_profile_viewed", { viewer_type: "employer" });
    if (pathname.startsWith("/candidate/employers/")) trackGoogleAnalyticsEvent("employer_profile_viewed", { viewer_type: "candidate" });
    if (pathname === "/candidate/dashboard" && previous.startsWith("/candidate/onboarding")) trackGoogleAnalyticsEventOnce("candidate-onboarding-completed", "candidate_onboarding_completed");
    if (pathname === "/employer/dashboard" && previous.startsWith("/employer/onboarding")) trackGoogleAnalyticsEventOnce("employer-onboarding-completed", "employer_onboarding_completed");
    const conversion = searchParams.get("analytics");
    if (conversion === "interest_sent" || conversion === "interest_accepted" || conversion === "logout") {
      trackGoogleAnalyticsEvent(conversion);
      const url = new URL(window.location.href);
      url.searchParams.delete("analytics");
      window.history.replaceState(window.history.state, "", url);
    }
  }, [pathname, searchParams]);
  return null;
}
