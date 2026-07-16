# Kaam Web Auth QA Checklist

## Candidate to Logout to Employer

1. Log in with a candidate email.
2. Confirm the candidate dashboard opens.
3. Confirm the dashboard account header shows the candidate email and `candidate` role.
4. Log out.
5. Confirm `/login` opens.
6. Log in with an employer email.
7. Confirm the employer dashboard opens.
8. Confirm the dashboard account header shows the employer email and `employer` role.
9. Confirm candidate data is absent.

## Employer to Logout to Candidate

1. Log in with an employer email.
2. Confirm the employer dashboard opens.
3. Confirm the dashboard account header shows the employer email and `employer` role.
4. Log out.
5. Confirm `/login` opens.
6. Log in with a candidate email.
7. Confirm the candidate dashboard opens.
8. Confirm the dashboard account header shows the candidate email and `candidate` role.
9. Confirm employer data is absent.

## Wrong Role Selection

1. Select Employer login with a candidate email.
2. Verify OTP.
3. Confirm Kaam redirects to the candidate dashboard with a role-redirect notice.
4. Select Candidate login with an employer email.
5. Verify OTP.
6. Confirm Kaam redirects to the employer dashboard with a role-redirect notice.

## Refresh and Browser Restart

1. Refresh a protected dashboard route.
2. Confirm the same backend role and account email are restored.
3. Close and reopen the browser.
4. Open the protected dashboard route.
5. Confirm Supabase restores the correct session or redirects to `/login` if expired.
