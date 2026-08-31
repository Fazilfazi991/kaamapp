import { routes } from "./routes";

export function candidateNavigation({ profileComplete = false }: { profileComplete?: boolean } = {}) {
  return [
    { href: routes.candidateDashboard, label: "Dashboard", prefetch: true },
    { href: routes.candidateProfile, label: "Profile", prefetch: false },
    ...(profileComplete ? [] : [{ href: routes.candidateOnboarding, label: "Complete profile", prefetch: true }]),
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
  { href: routes.employerSearch, label: "Search Candidates" },
  { href: routes.employerShortlist, label: "Saved Candidates" },
  { href: routes.employerInterests, label: "Interests" },
  { href: routes.employerMatches, label: "Matches" },
  { href: routes.employerMessages, label: "Messages" },
  { href: routes.employerNotifications, label: "Notifications" },
];
