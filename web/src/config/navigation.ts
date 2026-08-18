import { routes } from "./routes";

export function candidateNavigation({ profileComplete = false }: { profileComplete?: boolean } = {}) {
  return [
    { href: routes.candidateDashboard, label: "Dashboard" },
    { href: routes.candidateProfile, label: "Profile" },
    ...(profileComplete ? [] : [{ href: routes.candidateOnboarding, label: "Complete profile" }]),
    { href: routes.candidateInterests, label: "Interests" },
    { href: routes.candidateMatches, label: "Matches" },
    { href: routes.candidateMessages, label: "Messages" },
    { href: routes.candidateNotifications, label: "Notifications" },
    { href: routes.candidateDocuments, label: "Documents" },
    { href: routes.candidateMembership, label: "Membership" },
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
