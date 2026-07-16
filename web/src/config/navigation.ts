import { routes } from "./routes";

export const candidateNavigation = [
  { href: routes.candidateDashboard, label: "Dashboard" },
  { href: routes.candidateProfile, label: "Profile" },
  { href: routes.candidateOnboarding, label: "Onboarding" },
  { href: routes.candidateInterests, label: "Interests" },
  { href: routes.candidateJobs, label: "Jobs" },
  { href: routes.candidateMatches, label: "Matches" },
  { href: routes.candidateMessages, label: "Messages" },
  { href: routes.candidateDocuments, label: "Documents" },
  { href: routes.candidateMembership, label: "Membership" },
];

export const employerNavigation = [
  { href: routes.employerDashboard, label: "Dashboard" },
  { href: routes.employerProfile, label: "Company Profile" },
  { href: routes.employerDocuments, label: "Documents" },
  { href: routes.employerSearch, label: "Search Candidates" },
  { href: routes.employerShortlist, label: "Shortlist" },
  { href: routes.employerInterests, label: "Interests" },
  { href: routes.employerMatches, label: "Matches" },
  { href: routes.employerMessages, label: "Messages" },
  { href: routes.employerJobPosts, label: "Job Posts" },
];
