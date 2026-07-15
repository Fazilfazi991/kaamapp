# KAAM OCR Setup

The Flutter app now calls a Supabase Edge Function for passport OCR when `OCR_EDGE_FUNCTION` is configured.

Expected flow:

```text
Flutter uploads passport to kaam-private
Flutter sends bucket/path/document_type/file_name to Edge Function
Edge Function reads the private file securely
Edge Function calls the OCR provider using server-side secrets
Edge Function returns normalized JSON
Flutter parses and pre-fills Review Extracted Details
Candidate confirms and saves to profiles + candidate_documents
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
  "document_type": "passport",
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
  "confidence": {
    "passport_number": 0.98
  }
}
```

The Flutter parser also accepts common alternate keys and MRZ text (`mrz`, `mrz_text`, `raw_text`).

If `OCR_EDGE_FUNCTION` is empty or the OCR request fails, the app opens the same review screen in manual-entry mode and marks `ocr_completed=false`.
