-- Allow profile-photo previews for candidates who are already visible to
-- authenticated employers. The kaam-private bucket remains private, and this
-- does not grant access to CVs, passports, identity documents, or other files.

drop policy if exists "kaam_private_visible_candidate_photo_read"
on storage.objects;

create policy "kaam_private_visible_candidate_photo_read"
on storage.objects for select
to authenticated
using (
  bucket_id = 'kaam-private'
  and (storage.foldername(name))[2] = 'candidate-profile-photos'
  and (storage.foldername(name))[1] ~*
    '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  and (
    (storage.foldername(name))[1] = auth.uid()::text
    or public.is_admin()
    or public.candidate_visible_to_employers(
      ((storage.foldername(name))[1])::uuid
    )
  )
);
