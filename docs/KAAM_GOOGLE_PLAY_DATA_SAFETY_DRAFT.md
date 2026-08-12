# KAAM Google Play Data Safety Draft

Status: internal working draft for the first Play submission. This is not a submitted Data safety form or legal advice. Evidence is the verified inventory in `KAAM_PRIVACY_DATA_INVENTORY.md`, current Flutter/Supabase/Firebase/OCR code, and the deployed deletion workflow.

| Google Play category | Collected | Shared | Required / optional | Purpose | Deletion available | Encryption in transit | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Name | YES | NEEDS CLASSIFICATION | Required for relevant account/profile flows | Account, profile, matching | YES | YES | Account and Candidate profile inventory; HTTPS |
| Email address | YES | NEEDS CLASSIFICATION | Required for email OTP accounts | Account authentication, support | YES | YES | Supabase Auth email OTP |
| Phone number | YES, where provided | NEEDS CLASSIFICATION | Optional / flow-dependent | Account/profile and matching | YES | YES | Inventory account identity |
| User IDs and authentication identifiers | YES | NEEDS CLASSIFICATION | Required | Authentication, account operation, security | YES | YES | Supabase Auth and `profiles` |
| Address / user-entered location | YES | NEEDS CLASSIFICATION | Profile-flow dependent | Matching and hiring | YES | YES | Candidate profile inventory |
| Personal information: gender, nationality, date of birth | YES | NEEDS CLASSIFICATION | Candidate-flow dependent | Candidate profile, verification/eligibility | YES | YES | Candidate and document inventory |
| Photos / documents | YES | NEEDS CLASSIFICATION | Optional for profile media; required where identity verification is used | Profile, verification and eligibility | YES | YES | `kaam-public`, `kaam-private`, document flow |
| Government ID / passport and visa data | YES | NEEDS CLASSIFICATION | Required where Candidate verification is used | Identity verification and eligibility | YES | YES | `candidate_documents`, private storage, OCR flow |
| Employment information | YES | NEEDS CLASSIFICATION | Profile-flow dependent | Matching, hiring and requirements | YES | YES | Candidate/employer inventory |
| Messages | YES | NEEDS CLASSIFICATION | Optional feature use | Chat between matched participants | YES | YES | Chat inventory and deletion verification |
| App activity: interests, matches, saved/recently viewed | YES | NEEDS CLASSIFICATION | Optional feature use | Matching and hiring workflows | YES | YES | Matching inventory |
| Device or other IDs: FCM token/device-install identifiers | YES | NEEDS CLASSIFICATION | Optional; notification permission and setup dependent | Notification delivery | YES for KAAM records | YES | `user_push_devices`, Firebase Cloud Messaging |
| App info and performance / operational metadata | YES | NEEDS CLASSIFICATION | Service-operation dependent | Security, error diagnosis and operation | Provider retention outside KAAM direct control | YES | Supabase/Firebase provider-managed infrastructure |

## Classification decisions still required

1. Google Play’s **shared** classification must be reviewed for each category. The current technical record confirms service-provider processing by Supabase, Google/Firebase, and Azure Document Intelligence when OCR is used, but does not itself decide the Play taxonomy answer.
2. Confirm which fields are mandatory in every released Candidate and Employer flow versus conditionally required for a selected feature or verification status.
3. Confirm the legal/business position on sale or other disclosures; do not infer it from code.
4. Confirm provider retention and processor terms for Supabase, Google/Firebase and Azure before finalising any policy or Play-form retention statement.
5. Decide and publish KAAM’s minimum intended age before the Play target-audience declaration.
