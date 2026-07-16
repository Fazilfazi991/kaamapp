import { beforeEach, describe, expect, it, vi } from "vitest";
import { initialAdminActionState } from "@/features/admin/validation/review";
import { approveEmployerCompany, approveEmployerDocument } from "./actions";

const mockSupabase = {
  from: vi.fn(),
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

