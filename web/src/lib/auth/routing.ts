import { routes } from "@/config/routes";
import type { UserRole } from "@/types/domain";

export type AppAccountRole = Exclude<UserRole, "admin">;

export type AccountStatus =
  | "unauthenticated"
  | "ready"
  | "blocked"
  | "missing_profile"
  | "conflicting_records"
  | "unsupported_role";

export type AccountSnapshot = {
  userId: string | null;
  email: string | null;
  role: UserRole | null;
  profileStatus?: string | null;
  hasCandidateProfile: boolean;
  hasEmployerProfile: boolean;
};

export type RouteDecision = {
  allowed: boolean;
  redirectTo?: string;
  message?: string;
  status: AccountStatus;
};

const roleDashboard: Record<UserRole, string> = {
  candidate: routes.candidateDashboard,
  employer: routes.employerDashboard,
  admin: routes.admin,
};

export function dashboardForRole(role: UserRole) {
  return roleDashboard[role];
}

export function normalizeOtp(value: string) {
  return value.replace(/\D/g, "");
}

export function isValidEmail(value: string) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value.trim());
}

export const blockedAccountMessage =
  "Your Kaam account has been blocked. Please contact support if you believe this is a mistake.";

export function isBlockedStatus(status: string | null | undefined) {
  return status === "blocked";
}

export function safeReturnPath(value: string | null | undefined) {
  if (!value) return null;
  if (!value.startsWith("/") || value.startsWith("//")) return null;
  if (
    value.startsWith("/login") ||
    value.startsWith("/register") ||
    value.startsWith(routes.accountBlocked)
  ) {
    return null;
  }
  return value;
}

export function roleMismatchMessage(role: UserRole) {
  return `This account is registered as a ${role}. We redirected you to the correct dashboard.`;
}

export function profileRecoveryDecision(account: AccountSnapshot): RouteDecision | null {
  if (!account.userId) {
    return { allowed: false, redirectTo: routes.login, status: "unauthenticated" };
  }

  if (isBlockedStatus(account.profileStatus)) {
    return {
      allowed: false,
      redirectTo: routes.accountBlocked,
      status: "blocked",
      message: blockedAccountMessage,
    };
  }

  if (!account.role) {
    return {
      allowed: false,
      redirectTo: routes.accountRecovery,
      status: "missing_profile",
      message: "Your account setup is incomplete. Please choose how you want to use Kaam.",
    };
  }

  if (account.role === "admin") {
    return {
      allowed: false,
      redirectTo: routes.admin,
      status: "unsupported_role",
    };
  }

  if (account.hasCandidateProfile && account.hasEmployerProfile) {
    return {
      allowed: false,
      redirectTo: routes.accountConflict,
      status: "conflicting_records",
      message:
        "We found conflicting account records. Please contact Kaam support before continuing.",
    };
  }

  return null;
}

export function protectedRouteDecision(
  account: AccountSnapshot,
  requestedRole: AppAccountRole,
  currentPath: string,
): RouteDecision {
  const recovery = profileRecoveryDecision(account);
  if (recovery) return recovery;

  if (account.role !== requestedRole) {
    return {
      allowed: false,
      redirectTo: dashboardForRole(account.role as UserRole),
      status: "ready",
      message: roleMismatchMessage(account.role as UserRole),
    };
  }

  if (
    account.role === "candidate" &&
    !account.hasCandidateProfile &&
    !currentPath.startsWith(routes.candidateOnboarding)
  ) {
    return {
      allowed: false,
      redirectTo: routes.candidateOnboarding,
      status: "ready",
      message: "Complete your candidate profile to continue.",
    };
  }

  if (
    account.role === "employer" &&
    !account.hasEmployerProfile &&
    currentPath !== routes.employerProfile
  ) {
    return {
      allowed: false,
      redirectTo: routes.employerProfile,
      status: "ready",
      message: "Complete your company profile to continue.",
    };
  }

  return { allowed: true, status: "ready" };
}

export function authPageDecision(account: AccountSnapshot): RouteDecision {
  const recovery = profileRecoveryDecision(account);
  if (recovery?.status === "unauthenticated") {
    return { allowed: true, status: "unauthenticated" };
  }
  if (recovery) return recovery;

  return {
    allowed: false,
    redirectTo: dashboardForRole(account.role as UserRole),
    status: "ready",
  };
}

export function postOtpDestination(
  account: AccountSnapshot,
  selectedRole: AppAccountRole,
  returnPath?: string | null,
) {
  const recovery = profileRecoveryDecision(account);
  if (recovery) return recovery;

  const role = account.role as UserRole;
  const safePath = safeReturnPath(returnPath);
  const destination =
    safePath && safePath.startsWith(`/${role}`) ? safePath : dashboardForRole(role);
  const selectedWrongRole = role !== selectedRole;

  return {
    allowed: false,
    redirectTo: destination,
    status: "ready" as const,
    message: selectedWrongRole ? roleMismatchMessage(role) : undefined,
  };
}

export function canCreateProfile(account: AccountSnapshot) {
  return Boolean(account.userId && !account.role);
}
