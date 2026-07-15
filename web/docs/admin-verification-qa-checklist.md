# Admin Verification QA Checklist

## Access control
- Candidate login cannot open `/admin`
- Employer login cannot open `/admin`
- Admin login can open dashboard
- Logout blocks browser-back access

## Candidate review
- Open pending candidate document
- Preview private file
- Approve
- Confirm candidate status updates
- Reject another document with public reason
- Confirm candidate sees only public reason

## Employer review
- Open pending company
- Review profile and trade licence
- Approve valid document
- Confirm company approval follows prerequisites
- Reject invalid document
- Confirm employer can resubmit

## Privacy
- Inspect network/page source
- Confirm storage path and signed URL are not exposed unnecessarily
- Confirm non-admin account cannot use preview route

## User management
- Open user
- Block test user
- Confirm access restriction
- Unblock
- Confirm access restored
- Confirm admin cannot block self
