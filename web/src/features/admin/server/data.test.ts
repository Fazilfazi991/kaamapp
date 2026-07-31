import { beforeEach, describe, expect, it, vi } from "vitest";
import { loadCandidateDocuments, loadCandidates, normalizeCandidateDocumentRows } from "./data";

const mockSupabase = {
  from: vi.fn(),
};

vi.mock("@/lib/supabase/server", () => ({
  createServerSupabaseClient: vi.fn(async () => mockSupabase),
}));

function profileQuery(result: { data: unknown[] | null; error: unknown }) {
  const query = {
    select: vi.fn(() => query),
    eq: vi.fn(() => query),
    order: vi.fn(() => query),
    limit: vi.fn(async () => result),
  };
  return query;
}

function listQuery(result: { data: unknown[] | null; error: unknown }) {
  const query = {
    select: vi.fn(() => query),
    order: vi.fn(() => query),
    limit: vi.fn(async () => result),
  };
  return query;
}

describe("admin candidate data loader", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("starts from candidate-role profiles so employers and admins are excluded", async () => {
    const profiles = profileQuery({ data: [], error: null });
    mockSupabase.from.mockReturnValue(profiles);

    await loadCandidates({});

    expect(mockSupabase.from).toHaveBeenCalledWith("profiles");
    expect(profiles.eq).toHaveBeenCalledWith("role", "candidate");
  });

  it("returns an error state instead of converting query failure into an empty match state", async () => {
    const profiles = profileQuery({ data: null, error: { message: "permission denied" } });
    mockSupabase.from.mockReturnValue(profiles);

    const result = await loadCandidates({});

    expect(result.rows).toEqual([]);
    expect(result.errorMessage).toBe("Candidate accounts could not be loaded. Please try again.");
    expect(result.error).toBeTruthy();
  });
});

describe("admin candidate document queue", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("keeps active pending passport versions in the queue", () => {
    const result = normalizeCandidateDocumentRows({
      versions: [
        {
          id: "version-1",
          candidate_document_id: "summary-1",
          candidate_id: "candidate-1",
          document_type: "passport",
          file_path: "candidate-1/passport.pdf",
          version_number: 1,
          status: "pending_verification",
          is_active: true,
          created_at: "2026-01-01T00:00:00Z",
        },
      ],
      summaries: [
        {
          id: "summary-1",
          candidate_id: "candidate-1",
          passport_file_url: "candidate-1/passport.pdf",
          visa_file_url: null,
          passport_status: "pending_verification",
          visa_status: "not_uploaded",
          passport_uploaded_at: "2026-01-01T00:00:00Z",
          visa_uploaded_at: null,
          passport_expiry_date: "2030-01-01",
          visa_expiry_date: null,
          passport_version: 1,
          visa_version: 0,
          updated_at: "2026-01-01T00:00:00Z",
        },
      ],
      profiles: [{ id: "candidate-1", role: "candidate", full_name: "Masked Candidate", email: "masked@example.com", status: "active" }],
    });

    expect(result.rows).toHaveLength(1);
    expect(result.rows[0]).toMatchObject({
      id: "version-1",
      document_type: "passport",
      status: "pending_verification",
      expiry_date: "2030-01-01",
      source: "version",
    });
  });

  it("creates a safe summary row when version history is missing", () => {
    const result = normalizeCandidateDocumentRows({
      versions: [],
      summaries: [
        {
          id: "summary-1",
          candidate_id: "candidate-1",
          passport_file_url: "candidate-1/passport.pdf",
          visa_file_url: null,
          passport_status: "pending",
          visa_status: "not_uploaded",
          passport_uploaded_at: "2026-01-01T00:00:00Z",
          visa_uploaded_at: null,
          passport_expiry_date: "2030-01-01",
          visa_expiry_date: null,
          passport_version: 1,
          visa_version: 0,
          updated_at: "2026-01-01T00:00:00Z",
        },
      ],
      profiles: [],
    });

    expect(result.rows[0]).toMatchObject({
      id: "summary-1",
      source: "summary",
      status: "pending_verification",
      version_number: 1,
    });
  });

  it("keeps version-only rows visible and does not replace active rows with historical rows", () => {
    const result = normalizeCandidateDocumentRows({
      versions: [
        {
          id: "old-version",
          candidate_document_id: null,
          candidate_id: "candidate-1",
          document_type: "passport",
          file_path: "candidate-1/passport-old.pdf",
          version_number: 1,
          status: "rejected",
          is_active: false,
          created_at: "2026-01-01T00:00:00Z",
        },
        {
          id: "active-version",
          candidate_document_id: null,
          candidate_id: "candidate-1",
          document_type: "passport",
          file_path: "candidate-1/passport-new.pdf",
          version_number: 2,
          status: "pending-review",
          is_active: true,
          created_at: "2026-02-01T00:00:00Z",
        },
      ],
      summaries: [],
      profiles: [],
    });

    expect(result.rows).toHaveLength(1);
    expect(result.rows[0]).toMatchObject({ id: "active-version", status: "pending_verification" });
  });

  it("returns an error state instead of an empty queue when the version query fails", async () => {
    const versionQuery = listQuery({ data: null, error: { message: "bad relationship" } });
    const summaryQuery = listQuery({ data: [], error: null });
    mockSupabase.from.mockImplementation((table: string) => {
      if (table === "candidate_document_versions") return versionQuery;
      if (table === "candidate_documents") return summaryQuery;
      return listQuery({ data: [], error: null });
    });

    const result = await loadCandidateDocuments({});

    expect(result.rows).toEqual([]);
    expect(result.errorMessage).toBe("Candidate documents could not be loaded. Please try again.");
    expect(result.error).toBeTruthy();
  });
});

