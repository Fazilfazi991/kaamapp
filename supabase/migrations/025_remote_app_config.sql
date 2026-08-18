-- Public runtime flags only. Do not place credentials, keys, tokens, or private URLs here.
create table if not exists public.app_config (
  id bigint generated always as identity primary key,
  environment text not null check (environment in ('development', 'staging', 'production')),
  platform text not null default 'all' check (platform in ('android', 'ios', 'all')),
  config_key text not null check (config_key ~ '^[a-z][a-z0-9_]{1,99}$'),
  config_value jsonb not null,
  enabled boolean not null default true,
  description text,
  effective_starts_at timestamptz,
  effective_ends_at timestamptz,
  updated_by uuid references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  check (effective_ends_at is null or effective_starts_at is null or effective_ends_at > effective_starts_at),
  unique (environment, platform, config_key)
);

create index if not exists app_config_public_lookup_idx
  on public.app_config (environment, platform, config_key)
  where enabled;

create or replace function public.set_app_config_updated_at()
returns trigger language plpgsql security invoker set search_path = public as $$
begin new.updated_at = now(); return new; end;
$$;
drop trigger if exists app_config_set_updated_at on public.app_config;
create trigger app_config_set_updated_at before update on public.app_config
for each row execute function public.set_app_config_updated_at();

alter table public.app_config enable row level security;
grant select on public.app_config to anon, authenticated;
grant insert, update, delete on public.app_config to authenticated;

create policy "app_config_public_read_effective_enabled"
on public.app_config for select to anon, authenticated
using (
  environment = 'production' and enabled
  and (effective_starts_at is null or effective_starts_at <= now())
  and (effective_ends_at is null or effective_ends_at > now())
);
create policy "app_config_admin_manage"
on public.app_config for all to authenticated
using (public.is_admin()) with check (public.is_admin());

insert into public.app_config (environment, platform, config_key, config_value, description) values
('production','all','maintenance_mode','false','Enable only for mandatory maintenance.'),
('production','all','maintenance_title','"We’ll be back soon"','Maintenance screen title.'),
('production','all','maintenance_message','"KAAM is undergoing scheduled maintenance. Please try again shortly."','Maintenance screen message.'),
('production','all','minimum_supported_version','""','SemVer floor; leave empty until a store version exists.'),
('production','all','latest_available_version','""','Informational latest store SemVer.'),
('production','android','force_update_enabled','false','Use only with a valid minimum version and a published Play update.'),
('production','android','flexible_update_enabled','true','Allows optional Google Play flexible updates.'),
('production','all','feature_google_sign_in','true','Public feature flag.'),
('production','all','feature_push_notifications','true','Public feature flag.'),
('production','all','feature_candidate_registration','true','Public feature flag.'),
('production','all','feature_employer_registration','true','Public feature flag.'),
('production','all','maximum_candidate_skills','20','Maximum skills allowed in the UI.'),
('production','all','candidate_membership_price_aed','0','Displayed membership price only.'),
('production','all','support_whatsapp_number','""','Support contact without a secret.'),
('production','all','announcement_enabled','false','Public announcement toggle.'),
('production','all','announcement_title','""','Public announcement title.'),
('production','all','announcement_message','""','Public announcement message.')
on conflict (environment, platform, config_key) do nothing;
