# Employer Onboarding Documents QA Checklist

## New Employer

- Log in with employer account without company profile.
- Confirm `/employer/onboarding` opens safely.
- Complete company details.
- Refresh midway and confirm saved progress remains.
- Complete location and contact.
- Confirm review page displays entered values.

## UAE And India Location

- Select UAE and Dubai.
- Save and refresh.
- Change to India.
- Confirm Dubai is not accepted as a hidden stale value.
- Select an Indian state.
- Save and refresh.

## Logo

- Upload supported logo.
- Confirm profile shows logo.
- Replace logo.
- Test oversized or invalid file.

## Documents

- Upload trade licence image.
- Upload supported PDF.
- Test unsupported file.
- Confirm private preview works through `/employer/documents/preview/{documentId}`.
- Confirm raw storage path is not visible.
- Replace draft document.

## Review Submission

- Attempt submission with missing required data.
- Confirm clear validation.
- Complete all requirements.
- Submit.
- Confirm status remains pending/admin review, not approved.

## Rejection / Resubmission

- Open rejected document or company review.
- Confirm safe reason is visible where supported.
- Correct information.
- Resubmit.
- Confirm prior document rows remain as history.

## Role Isolation

- Log out employer.
- Log in candidate.
- Confirm employer profile and document routes are inaccessible.
- Confirm no employer data leaks.
