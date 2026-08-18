-- KAAM APP - PASSPORT FRONT/BACK DOCUMENT SUPPORT
-- Additive migration for storing both passport sides without weakening checks.

begin;

alter table public.candidate_documents
  add column if not exists passport_back_file_url text;

alter table public.candidate_document_versions
  add column if not exists file_paths jsonb not null default '{}'::jsonb;

update public.candidate_document_versions
set file_paths = jsonb_build_object('front', file_path)
where document_type = 'passport'
  and coalesce(file_paths, '{}'::jsonb) = '{}'::jsonb
  and coalesce(btrim(file_path), '') <> '';

notify pgrst, 'reload schema';

commit;
