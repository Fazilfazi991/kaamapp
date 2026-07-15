export const routes = {
  home: "/",
  login: "/login",
  register: "/register",
  candidate: "/candidate",
  candidateDashboard: "/candidate/dashboard",
  candidateProfile: "/candidate/profile",
  candidateJobs: "/candidate/jobs",
  candidateMatches: "/candidate/matches",
  candidateMessages: "/candidate/messages",
  candidateDocuments: "/candidate/documents",
  candidateMembership: "/candidate/membership",
  employer: "/employer",
  employerDashboard: "/employer/dashboard",
  employerProfile: "/employer/profile",
  employerSearch: "/employer/search",
  employerShortlist: "/employer/shortlist",
  employerMessages: "/employer/messages",
  employerJobPosts: "/employer/job-posts",
  admin: "/admin",
} as const;

export type AppRoute = (typeof routes)[keyof typeof routes];
