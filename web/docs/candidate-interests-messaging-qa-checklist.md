# Candidate Interests And Messaging QA Checklist

## Candidate Interest Inbox

- Log in as candidate.
- Open `/candidate/interests`.
- Confirm only the candidate's interests appear.
- Open a pending employer interest.
- Confirm employer/company details are shown safely.
- Confirm private employer data is absent.

## Accept Interest

- Accept pending interest.
- Confirm success by landing on matches.
- Confirm interest becomes accepted.
- Confirm match appears.
- Confirm duplicate acceptance is blocked.
- Confirm employer web shows accepted status and match.

## Reject Interest

- Reject another pending interest.
- Confirm it becomes rejected.
- Confirm no match is created.
- Confirm employer web shows rejected status.

## Contact Privacy

- Open match.
- Confirm contact details follow backend privacy rules.
- Inspect network and page source.
- Confirm hidden contact values are absent.

## Messaging

- Open a valid match.
- Start or open conversation.
- Send candidate message.
- Confirm employer receives it in web or Flutter.
- Send employer reply.
- Confirm candidate receives it.
- Refresh both sides.
- Confirm history remains.
- Confirm unread count updates.
- Confirm old messages load correctly.

## Role Isolation

- Log out candidate.
- Log in employer.
- Confirm candidate inbox is inaccessible.
- Log out employer.
- Log in another candidate.
- Confirm previous candidate messages and interests do not leak.

## Realtime

- Open candidate and employer chat in separate sessions.
- Send a message.
- Confirm whether it appears after refresh.
- Realtime is not enabled in this phase unless Supabase realtime policies are confirmed.
