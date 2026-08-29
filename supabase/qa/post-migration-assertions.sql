-- Read-only assertions. Run only after an approved schema initialization.
select case when (select count(*) from auth.users) = 0 then 'PASS' else 'FAIL' end as auth_users_empty;
select schemaname, tablename from pg_tables where schemaname = 'public' and not rowsecurity;
select p.oid::regprocedure as routine, r.rolname as grantee
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
join aclexplode(coalesce(p.proacl, acldefault('f',p.proowner))) a on true
join pg_roles r on r.oid=a.grantee
where n.nspname='public' and p.prosecdef and r.rolname in ('anon','authenticated')
order by 1,2;
select has_function_privilege('anon','public.qa_reset(text,text,text)','execute') as anon_qa_reset,
       has_function_privilege('authenticated','public.qa_reset(text,text,text)','execute') as authenticated_qa_reset,
       has_function_privilege('anon','public.fulfill_stripe_candidate_membership_payment(uuid,text,text,text,text,timestamptz,boolean)','execute') as anon_payment,
       has_function_privilege('authenticated','public.fulfill_stripe_candidate_membership_payment(uuid,text,text,text,text,timestamptz,boolean)','execute') as authenticated_payment,
       has_function_privilege('service_role','public.fulfill_stripe_candidate_membership_payment(uuid,text,text,text,text,timestamptz,boolean)','execute') as service_payment;
select id, public from storage.buckets where id in ('kaam-public','kaam-private') order by id;
select count(*) as storage_object_count from storage.objects;
select count(*) as candidate_search_count from public.public_candidate_search;
select count(*) as taxonomy_rows from public.industries
union all select count(*) from public.job_roles
union all select count(*) from public.competency_skills;
select to_regprocedure('public.bootstrap_user_profile(text)') as bootstrap,
       to_regprocedure('public.candidate_membership_active(uuid)') as membership;
select extname from pg_extension where extname in ('pg_cron','pg_net');
select table_schema, table_name from information_schema.tables
where table_schema='public' and table_name='app_config';
select count(*) as production_ref_occurrences
from information_schema.columns
where table_schema='public' and column_default ilike '%bhuhojzqxnvwbsypijac%';
