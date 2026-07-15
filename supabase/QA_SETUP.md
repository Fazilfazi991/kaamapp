# KAAM QA Reset Setup

Run `007_qa_reset_tools.sql` in Supabase SQL Editor after the existing Kaam schema patches.

## Flutter environment

Set these only for debug or internal QA builds:

```env
QA_MODE=true
QA_CANDIDATE_EMAIL=
QA_EMPLOYER_EMAIL=
QA_ADMIN_EMAIL=
EMAIL_OTP_LENGTH=6
```

Kaam uses Supabase email OTP. The app expects six digits by default because Supabase supports 6-10 digit email OTPs. Do not fake, truncate, or bypass OTPs in Flutter.

For internal QA release builds:

```text
flutter build apk --flavor qa --release --dart-define=KAAM_INTERNAL_QA=true --dart-define=KAAM_ENV_FILE=.env.qa
```

For production release builds:

```text
flutter build apk --flavor production --release --dart-define=KAAM_ENV_FILE=.env.production
```

## QA allowlist

The SQL patch creates `qa_allowed_accounts`. Add the same real test inboxes that you put in `.env.qa`:

```sql
insert into public.qa_allowed_accounts(email, role)
values ('your-real-candidate-test@example.com', 'candidate')
on conflict (email) do update set enabled = true;
```

Every reset is restricted to the currently authenticated user. The client cannot pass another user ID.

## Full candidate test

1. Enable QA mode in a debug/internal QA build.
2. Open Candidate login.
3. Tap `Candidate QA`.
4. Request the real email OTP and verify.
5. Complete Welcome, Passport, personal details, category, experience/preferences, dashboard.
6. Open candidate Settings -> QA Tools.
7. Run `Full QA Reset`.
8. Login again and repeat onboarding.

## Full employer test

1. Enable QA mode in a debug/internal QA build.
2. Open Employer login.
3. Tap `Employer QA`.
4. Request the real email OTP and verify.
5. Complete employer onboarding.
6. Test Search, Hiring Requirements, Interests, Matches, Company.
7. Open Company -> Settings -> QA Tools.
8. Run `Full QA Reset`.
9. Login again and repeat onboarding.
