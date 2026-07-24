import { describe, expect, it } from "vitest";
import { isStoredPhotoPath, photoInitials } from "./candidate-photo-utils";

describe("candidate photo values", () => {
  it("recognizes the mobile private Storage path convention", () => {
    expect(isStoredPhotoPath("candidate-1/candidate-profile-photos/profile.jpg")).toBe(true);
  });

  it("does not treat legacy public URLs as Storage paths", () => {
    expect(isStoredPhotoPath("https://project.supabase.co/storage/v1/object/public/kaam-public/a.jpg")).toBe(false);
  });

  it("uses a safe fallback initial when no candidate name exists", () => {
    expect(photoInitials(" ")).toBe("K");
    expect(photoInitials("Abdul Hadi Mehthash")).toBe("AH");
  });
});
