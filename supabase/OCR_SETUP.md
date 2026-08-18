# KAAM OCR Setup

The Flutter app calls a Supabase Edge Function for server-side identity-document validation and OCR when `OCR_EDGE_FUNCTION` is configured.

Expected flow:

```text
Flutter uploads passport to kaam-private
Flutter sends bucket/path/document_type/file_name to Edge Function
Edge Function reads the private file securely
Edge Function calls the OCR provider using server-side secrets
Edge Function validates file ownership/type, performs document recognition, and stores a hash-bound validation record
Flutter only opens Review Extracted Details after an accepted validation
Candidate submits through a server RPC that consumes the validation record and creates the document version
```

Required Flutter env:

```env
OCR_EDGE_FUNCTION=passport-ocr
```

Do not put OCR API keys, service-role keys, or provider secrets in Flutter.

Expected Edge Function response:

```json
{
  "success": true,
  "document_type": "passport_front",
  "data": {
    "full_name": "Example Name",
    "passport_number": "N1234567",
    "nationality": "IND",
    "date_of_birth": "1996-05-12",
    "gender": "M",
    "issue_date": "2026-05-10",
    "expiry_date": "2036-05-09",
    "place_of_birth": "KERALA",
    "country_of_issue": "IND"
  },
  "confidence": { "overall": 0.98 },
  "validation": {
    "id": "validation UUID",
    "status": "accepted",
    "expires_at": "2026-08-01T12:30:00Z",
    "reasons": [],
    "quality": { "page_width": 8.2, "page_height": 5.8 }
  }
}
```

The Flutter parser also accepts common alternate keys and MRZ text (`mrz`, `mrz_text`, `raw_text`).

If the function or document-recognition provider is unavailable, Flutter fails closed: it does not open review and asks the candidate to retry.

Deployment order:

1. Run `supabase/027_identity_document_validation.sql` in the linked project after the already-applied 019/020/023 and `20260731000400` changes.
2. Deploy `supabase/functions/passport-ocr` with `AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT`, `AZURE_DOCUMENT_INTELLIGENCE_KEY`, `SUPABASE_URL`, and `SUPABASE_SERVICE_ROLE_KEY` configured as Edge Function secrets.
3. Keep `OCR_EDGE_FUNCTION=passport-ocr` in the Flutter environment. Never expose the Edge Function secrets in Flutter.

Do not run or deploy `supabase/migrations/025_remote_app_config.sql` as part of this change.
