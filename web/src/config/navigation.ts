import { routes } from "./routes";

export function candidateNavigation({ profileComplete = false, onboarding = false }: { profileComplete?: boolean; onboarding?: boolean } = {}) {
  return [
    { href: routes.candidateDashboard, label: "Dashboard", prefetch: onboarding ? false : true },
    { href: routes.candidateProfile, label: "Profile", prefetch: false },
    ...(profileComplete ? [] : [{ href: routes.candidateOnboarding, label: "Complete profile", prefetch: onboarding ? false : true }]),
    { href: routes.candidateInterests, label: "Interests", prefetch: false },
    { href: routes.candidateMatches, label: "Matches", prefetch: false },
    { href: routes.candidateMessages, label: "Messages", prefetch: false },
    { href: routes.candidateNotifications, label: "Notifications", prefetch: false },
    { href: routes.candidateDocuments, label: "Documents", prefetch: false },
    { href: routes.candidateMembership, label: "Membership", prefetch: false },
  ];
}

export const employerNavigation = [
  { href: routes.employerDashboard, label: "Dashboard" },
  { href: routes.employerSearch, label: "Search Candidates", prefetch: false },
  { href: routes.employerShortlist, label: "Saved Candidates", prefetch: false },
  { href: routes.employerInterests, label: "Interests", prefetch: false },
  { href: routes.employerMatches, label: "Matches", prefetch: false },
  { href: routes.employerMessages, label: "Messages", prefetch: false },
  { href: routes.employerNotifications, label: "Notifications", prefetch: false },
];
