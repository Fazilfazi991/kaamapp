import { describe, expect, it } from "vitest";
import { otpErrorPresentation } from "./otp-errors";

describe("otpErrorPresentation", () => {
  it("only labels an explicitly expired verification code as expired", () => {
    expect(otpErrorPresentation("verify", { code: "otp_expired" }).message).toBe("This OTP has expired. Request a new code.");
  });
  it("labels invalid codes without calling them expired", () => {
    expect(otpErrorPresentation("verify", { code: "invalid_token" }).message).toBe("That OTP is incorrect. Please check the code and try again.");
  });
  it("offers registration without revealing that an address is unregistered", () => {
    expect(otpErrorPresentation("request", { code: "user_not_found" })).toMatchObject({ suggestRegistration: true });
  });
});
