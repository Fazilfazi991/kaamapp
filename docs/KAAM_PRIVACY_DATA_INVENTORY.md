# KAAM privacy data inventory (Step 4A)

Developer: **FUSION VENTURES FZ-LLC**  
Application: **KAAM**  
Package: `com.kaamperfectmatch.kaam_perfect_match`

This is a technical data inventory, not the final privacy policy. It describes the current implemented data flows and the verified account-deletion behavior.

## Account architecture

Candidate and employer accounts both use Supabase Auth. Email OTP is implemented through Supabase Auth; Google Sign-In authenticates with Google and then exchanges its credential with Supabase Auth. `public.profiles.id` is a one-to-one foreign key to `auth.users.id`, and records the user role. Candidate-specific fields are stored in `public.candidate_profiles`; employer company data is stored in `public.employer_companies`.

## Data collected and generated

| Category | Data and purpose | Primary storage | Processors / sharing | Current deletion behavior |
| --- | --- | --- | --- | --- |
| Account identity | Name, email, phone, role, authentication metadata; account access and matching | Supabase Auth; `profiles` | Supabase; Google for Google Sign-In | **Deleted**: verified for Candidate and Employer QA accounts |
| Candidate profile | Headline, gender, nationality, country/city, skills, languages, experience, salary, availability, preferences, photo/resume paths | `candidate_profiles`, `candidate_skills`, `candidate_privacy_settings` | Supabase; selected profile data is shared with employers according to application rules | **Deleted**: verified Candidate profile and direct child records cascade with Auth deletion |
| Employer profile | Company/contact details, trade license data, hiring needs, logo and requirements | `employer_companies`, `employer_hiring_requirements`, taxonomy mapping tables | Supabase; selected company/hiring data is shown to candidates | **Deleted when Employer is deleted**; **retained** when a related Candidate is deleted (verified) |
| Identity documents | Passport/visa images, numbers, dates, OCR fields, validation and review state | `candidate_documents`, versions, validations, review/audit/notification tables; `kaam-private` Storage | Supabase Storage; configured OCR Edge Function / Azure OCR integration where used | **Deleted**: metadata cascades and account deletion removes user-prefixed Storage objects before Auth deletion |
| Employer verification files | Verification document metadata and uploaded files | `verification_documents`; KAAM Storage | Supabase Storage | Metadata cascades; account deletion removes user-prefixed Storage objects first |
| Matching and communication | Interest requests, matches, chat messages, saved candidates, recently viewed candidates | `interest_requests`, `matches`, `chat_messages`, `saved_candidates`, `employer_candidate_views` | Supabase; shared with the matched participant | **Deleted**: verified after Candidate deletion for interest, match, messages, Employer saved/recent links; no orphan rows remained |
| Notifications and devices | FCM token, device/install identifiers, preferences, notification records and delivery status | `user_push_devices`, `notification_preferences`, `notifications`, push-outbox/delivery tables | Firebase Cloud Messaging and Supabase | **Deleted**: Candidate-owned records cascade. Shared-record source notifications for the remaining Employer are explicitly deleted by `delete-account` before shared rows cascade; verified post-fix with no dangling source IDs. Firebase may retain provider operational metadata outside KAAM control |
| Technical data | Server/auth metadata and operational logs as provided by Supabase/Firebase | Provider-managed infrastructure | Supabase, Firebase, Google | Provider retention is outside the mobile app; requires provider-policy review |

## Storage and security evidence

KAAM uses `kaam-private` for private documents and `kaam-public` for user-owned public media. Upload paths are constructed as `<auth.users.id>/<folder>/<file>`. The deletion Edge Function verifies the calling JWT, lists and removes objects only under that authenticated user ID in both buckets, then deletes the Auth user with a service-role client. No service-role key is included in Flutter.

## Account deletion behavior

The in-app path is Settings → Delete account. It requires typing `DELETE` and a second confirmation. The Flutter client invokes the authenticated `delete-account` Supabase Edge Function. The function does not accept a target user ID, prevents cross-user deletion, cleans user-owned Storage objects, then deletes `auth.users` last. Existing `ON DELETE CASCADE` foreign keys remove user-scoped profile, document, notification, FCM device, matching, and chat data. The app signs out after success.

The Edge Function additionally removes notifications whose source is one of the deleting Candidate's interest, match, or chat-message records before those shared records cascade. This prevents remaining participants from receiving orphaned notification links. This behavior was verified against production with disposable QA accounts on 2026-08-12.

The Edge Function must be deployed before this feature is enabled in a production release:

```powershell
supabase functions deploy delete-account
```

## Third-party processing and deletion limits

KAAM directly controls Supabase database rows and Storage objects. Firebase Cloud Messaging receives device tokens to deliver push notifications; deleting KAAM's stored token stops KAAM targeting it, but Firebase/Google operational retention is provider-controlled. Google Sign-In is an identity provider and does not give KAAM authority to delete a user's Google account. OCR providers may retain request telemetry according to their service configuration; confirm the configured Azure/OCR retention and data-processing terms before publishing the final policy.

## External deletion page plan

Google Play requires a public URL independent of app installation. Use an official KAAM/Fusion Ventures-controlled URL such as `https://<kaam-domain>/delete-account`. The page should ask for the account email, send a Supabase Auth OTP or magic-link verification, and invoke the same authenticated `delete-account` function only after the verified session is established. Do not implement a free-form request that can delete another person's account.

## Retention decisions required from Fusion Ventures

1. Whether shared chat/match records should remain fully removed (current verified implementation) or be anonymised for the remaining participant in a future product change.
2. Any required retention of employer verification, contractual, fraud-prevention, or support records.
3. Provider retention/configuration for Supabase logs, Firebase/FCM, Google authentication, and Azure/OCR.
4. The official deletion-page domain and support contact for users who cannot complete OTP verification.
