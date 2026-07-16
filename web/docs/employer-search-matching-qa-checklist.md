# Employer Search And Matching QA Checklist

## Search

- Log in as an eligible employer.
- Open `/employer/search` and search without filters.
- Filter by category.
- Filter by skill.
- Filter by UAE and Dubai.
- Change country to India and confirm Dubai is not submitted.
- Filter by an Indian state.
- Refresh and confirm filters remain in the URL.
- Navigate to page 2 and back.

## Candidate Privacy

- Open a candidate before matching.
- Confirm phone, WhatsApp, email, DOB, passport details, OCR fields, and documents are hidden.
- Inspect page source and network payloads.
- Confirm hidden contact values are not present before match/contact reveal.

## Shortlist

- Add a candidate to shortlist.
- Refresh and confirm the candidate remains shortlisted.
- Open `/employer/shortlist`.
- Remove the candidate.
- Confirm removal persists.

## Interest

- Send interest.
- Confirm status becomes pending.
- Attempt duplicate interest.
- Confirm duplicate is blocked.
- Confirm no contact details appear immediately.
- Confirm no match is created immediately.

## Match

- Accept interest from the candidate side using the existing Flutter app or supported backend flow.
- Refresh employer web.
- Confirm match appears on `/employer/matches`.
- Confirm contact access follows candidate membership/contact reveal settings.
- Confirm chat action appears only when `match_chat_enabled` allows it.

## Role Isolation

- Log out employer.
- Log in as a candidate.
- Attempt employer routes.
- Confirm redirect or access block.
- Confirm previous employer shortlist/search state does not leak.
