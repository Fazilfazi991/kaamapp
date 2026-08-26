export const GA_MEASUREMENT_ID = process.env.NEXT_PUBLIC_GA_MEASUREMENT_ID?.trim() ?? "";

export type GoogleAnalyticsEvent =
  | "registration_started" | "otp_requested" | "otp_verified" | "google_auth_started"
  | "login_success" | "logout" | "account_type_selected"
  | "candidate_onboarding_started" | "candidate_onboarding_completed"
  | "employer_onboarding_started" | "employer_onboarding_completed"
  | "membership_page_viewed" | "membership_checkout_started" | "membership_payment_success"
  | "candidate_profile_viewed" | "employer_profile_viewed" | "interest_sent" | "interest_accepted";

export type SafeAnalyticsParameters = {
  account_type?: "candidate" | "employer";
  auth_method?: "otp" | "google";
};

type Gtag = (...args: unknown[]) => void;

declare global {
  interface Window {
    dataLayer?: unknown[];
    gtag?: Gtag;
    __kaamGa4Configured?: boolean;
  }
}

export function ga4Enabled() { return Boolean(GA_MEASUREMENT_ID); }

function gtag(...args: unknown[]) {
  if (typeof window === "undefined" || !ga4Enabled()) return;
  window.dataLayer = window.dataLayer ?? [];
  if (!window.gtag) window.gtag = (...queued) => window.dataLayer?.push(queued);
  if (!window.__kaamGa4Configured) {
    window.gtag("js", new Date());
    window.gtag("config", GA_MEASUREMENT_ID, { send_page_view: false });
    window.__kaamGa4Configured = true;
  }
  window.gtag(...args);
}

export function trackGoogleAnalyticsEvent(eventName: GoogleAnalyticsEvent, parameters: SafeAnalyticsParameters = {}) {
  gtag("event", eventName, { send_to: GA_MEASUREMENT_ID, ...parameters });
}

export function trackGoogleAnalyticsPageView(pathname: string) {
  if (typeof window === "undefined") return;
  // Search/hash values are excluded because URLs can contain user input.
  gtag("event", "page_view", {
    send_to: GA_MEASUREMENT_ID,
    page_path: pathname,
    page_location: `${window.location.origin}${pathname}`,
    page_title: document.title,
  });
}
