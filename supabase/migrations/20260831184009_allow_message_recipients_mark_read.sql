begin;

-- Message recipients need to acknowledge unread messages, but they must not be
-- able to edit message content or ownership fields.
revoke update on public.chat_messages from authenticated;
grant update (is_read) on public.chat_messages to authenticated;

drop policy if exists "chat_update_sender_or_admin" on public.chat_messages;
drop policy if exists "chat_update_recipient_read_or_admin" on public.chat_messages;
create policy "chat_update_recipient_read_or_admin"
on public.chat_messages for update
to authenticated
using (
  public.is_admin()
  or (
    sender_id <> (select auth.uid())
    and exists (
      select 1
      from public.matches m
      where m.id = chat_messages.match_id
        and (m.employer_id = (select auth.uid()) or m.candidate_id = (select auth.uid()))
    )
  )
)
with check (
  public.is_admin()
  or (
    sender_id <> (select auth.uid())
    and exists (
      select 1
      from public.matches m
      where m.id = chat_messages.match_id
        and (m.employer_id = (select auth.uid()) or m.candidate_id = (select auth.uid()))
    )
  )
);

commit;
