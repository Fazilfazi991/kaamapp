-- Read-only, fail-fast catalog checks for QA post-init security patch 35.
do $$
begin
  if (select count(*) from auth.users) <> 0 then
    raise exception 'Unexpected auth users exist';
  end if;
  if exists (
    select 1 from information_schema.role_table_grants
    where table_schema = 'public' and grantee = 'authenticated'
      and privilege_type in ('TRUNCATE', 'TRIGGER', 'REFERENCES')
  ) then
    raise exception 'Authenticated retains owner-like relation privileges';
  end if;
  if exists (
    select 1 from information_schema.role_table_grants
    where table_schema = 'public' and grantee in ('PUBLIC', 'anon')
  ) then
    raise exception 'PUBLIC or anon retains a public-schema relation grant';
  end if;
  if (select string_agg(privilege_type, ',' order by privilege_type)
      from information_schema.role_table_grants
      where table_schema = 'public' and table_name = 'public_candidate_search'
        and grantee = 'authenticated') is distinct from 'SELECT' then
    raise exception 'public_candidate_search is not authenticated SELECT-only';
  end if;
  if has_function_privilege('anon', 'public.qa_reset(text,text,text)', 'execute')
     or not has_function_privilege('authenticated', 'public.qa_reset(text,text,text)', 'execute') then
    raise exception 'qa_reset ACL mismatch';
  end if;
  if has_function_privilege('anon', 'public.fulfill_stripe_candidate_membership_payment(uuid,text,text,text,text,timestamptz,boolean)', 'execute')
     or has_function_privilege('authenticated', 'public.fulfill_stripe_candidate_membership_payment(uuid,text,text,text,text,timestamptz,boolean)', 'execute')
     or not has_function_privilege('service_role', 'public.fulfill_stripe_candidate_membership_payment(uuid,text,text,text,text,timestamptz,boolean)', 'execute') then
    raise exception 'Payment fulfillment ACL mismatch';
  end if;
end
$$;

select table_name, grantee, string_agg(privilege_type, ',' order by privilege_type) privileges
from information_schema.role_table_grants
where table_schema = 'public' and grantee in ('PUBLIC', 'anon', 'authenticated', 'service_role')
group by table_name, grantee order by table_name, grantee;
