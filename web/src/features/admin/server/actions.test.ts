import { beforeEach, describe, expect, it, vi } from "vitest";
import { initialAdminActionState } from "@/features/admin/validation/review";
import { approveEmployerCompany, approveEmployerDocument, verifyCandidate } from "./actions";

const mockSupabase = {
  from: vi.fn(),
  rpc: vi.fn(),
};

vi.mock("next/cache", () => ({
  revalidatePath: vi.fn(),
}));

vi.mock("@/features/admin/auth/require-admin", () => ({
  requireAdmin: vi.fn(async () => ({
    userId: "admin-1",
    email: "admin@example.com",
    role: "admin",
    profileStatus: "active",
  })),
}));

vi.mock("@/lib/supabase/server", () => ({
  createServerSupabaseClient: vi.fn(async () => mockSupabase),
}));

function maybeSingleQuery<T>(result: { data: T | null; error: unknown }) {
  const query = {
    select: vi.fn(() => query),
    eq: vi.fn(() => query),
    maybeSingle: vi.fn(async () => result),
  };
  return query;
}

function listQuery<T>(result: { data: T[] | null; error: unknown }) {
  const query = {
    select: vi.fn(() => query),
    eq: vi.fn(async () => result),
  };
  return query;
}

describe("admin employer review actions", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("already approved document approval is an idempotent safe result", async () => {
    mockSupabase.from.mockReturnValue(
      maybeSingleQuery({
        data: {
          id: "doc-1",
          owner_id: "employer-1",
          company_id: "company-1",
          document_type: "trade-license",
          status: "approved",
          bucket_id: "kaam-private",
          file_path: "private/path.pdf",
          created_at: null,
          updated_at: null,
        },
        error: null,
      }),
    );
    const formData = new FormData();
    formData.set("documentId", "doc-1");

    const result = await approveEmployerDocument(initialAdminActionState, formData);

    expect(result).toEqual({ ok: true, message: "This document has already been approved." });
    expect(mockSupabase.from).toHaveBeenCalledTimes(1);
  });

  it("repeated company approval returns a safe no-op", async () => {
    mockSupabase.from
      .mockReturnValueOnce(
        maybeSingleQuery({
          data: {
            id: "company-1",
            owner_id: "employer-1",
            company_name: "Kaam Test",
            trade_license_number: "TL-1",
            industry: "Facilities",
            company_size: "11-50",
            country: "UAE",
            city: "Dubai",
            office_area: null,
            contact_person: "Nadia",
            contact_role: "HR",
            hiring_needs: [],
            website: null,
            logo_url: null,
            description: null,
            is_verified: true,
            status: "active",
            created_at: null,
            updated_at: null,
          },
          error: null,
        }),
      )
      .mockReturnValueOnce(listQuery({ data: [{ document_type: "trade-license", status: "approved" }], error: null }));
    const formData = new FormData();
    formData.set("companyId", "company-1");

    const result = await approveEmployerCompany(initialAdminActionState, formData);

    expect(result).toEqual({ ok: true, message: "Company is already approved." });
    expect(mockSupabase.from).toHaveBeenCalledTimes(2);
  });

  it("missing document returns safe not-found instead of a server crash", async () => {
    mockSupabase.from.mockReturnValue(maybeSingleQuery({ data: null, error: null }));
    const formData = new FormData();
    formData.set("documentId", "missing-doc");

    const result = await approveEmployerDocument(initialAdminActionState, formData);

    expect(result).toEqual({ ok: false, message: "Document was not found." });
  });
});

describe("candidate verification notification action", () => {
  beforeEach(() => vi.clearAllMocks());

  it("uses the transactional RPC and reports queued push feedback", async () => {
    mockSupabase.rpc.mockResolvedValue({ data: { notification_created: true, push_queued: true }, error: null });
    const formData = new FormData();
    formData.set("candidateId", "candidate-1");
    formData.set("internalNotes", "Checked by staff");

    const result = await verifyCandidate(initialAdminActionState, formData);

    expect(mockSupabase.rpc).toHaveBeenCalledWith("review_candidate_manual_verification", {
      p_candidate_id: "candidate-1",
      p_next_status: "verified",
      p_internal_notes: "Checked by staff",
      p_candidate_message: null,
    });
    expect(result).toEqual({ ok: true, message: "Candidate verified successfully. In-app notification created and push notification queued." });
  });

  it("reports idempotent retries without creating a duplicate notification", async () => {
    mockSupabase.rpc.mockResolvedValue({ data: { already_processed: true, notification_created: false, push_queued: false }, error: null });
    const formData = new FormData();
    formData.set("candidateId", "candidate-1");
    const result = await verifyCandidate(initialAdminActionState, formData);
    expect(result.message).toContain("No duplicate notification was created");
  });
});

