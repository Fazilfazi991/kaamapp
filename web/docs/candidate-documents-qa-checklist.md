# Candidate Documents QA Checklist

## Auth and routing

- Visit `/candidate/documents` while signed out and confirm the route redirects to login.
- Sign in as a candidate and confirm `/candidate/documents`, `/candidate/documents/upload`, `/candidate/documents/passport`, `/candidate/documents/passport/review`, and `/candidate/documents/passport` load safely.
- Confirm employer/admin accounts are not allowed into candidate document routes.

## Upload sources

- On passport upload, choose **Take Photo** and confirm the browser opens the device camera when supported.
- On passport upload, choose **Choose from Device** and confirm JPG, PNG, and WebP images are accepted.
- Confirm passport PDF upload is rejected with a clear validation message.
- On supporting visa upload, confirm JPG, PNG, WebP, and PDF files are accepted.
- Confirm files over 10 MB are rejected.

## Passport OCR and review

- Upload a real passport image using a candidate test account.
- Confirm the file is uploaded to `kaam-private` under `candidate-documents/passport`.
- Confirm the configured Supabase Edge Function receives `document_type`, `bucket`, `path`, and `file_name`.
- Confirm OCR success populates the review form.
- Confirm OCR failure still opens manual passport review.
- Confirm Save draft and Submit for review do not mark the document approved.
- Confirm the saved status is `pending_verification`.

## Privacy and storage

- Confirm rendered pages do not show raw storage paths.
- Confirm document previews use `/candidate/documents/preview/{documentType}` rather than public Supabase URLs.
- Confirm signed preview URLs expire after 10 minutes and are not logged.

## Details and versions

- Confirm the dashboard card shows uploaded date, expiry date, version, and status.
- Replace a passport and confirm a new active version is created while the prior version is archived.
- Open `/candidate/documents/passport` and confirm fields, preview, status, and version history are visible.
