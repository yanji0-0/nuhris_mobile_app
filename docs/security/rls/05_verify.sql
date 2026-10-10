-- =====================================================================
-- PHASE 5 — VERIFY (after supabase_rls_hardening.sql; re-run after EVERY
-- Laravel migration, dashboard table change or Supabase platform upgrade)
-- =====================================================================
-- V (main query) is ONE read-only SELECT. It returns:
--   section = '1 OVERALL'  one row: the verdict
--   section = '2 SUMMARY'  one row per check: PASS / FAIL / BLOCKED /
--                          UNVERIFIED / EXCEPTION / REVIEW / INFO and the
--                          finding count
--   section = '3 DETAIL'   one row per finding (object + explanation)
--
-- Verdict rules (a script that merely RUNS proves nothing; only this does):
--   FAIL                          any FAIL check has findings
--   NOT SECURE: BLOCKED           no FAIL, but excess privileges remain that
--                                 the running role cannot remove (e.g.
--                                 supabase_admin default privileges)
--   NOT VERIFIED                  no FAIL / BLOCKED, but a required check
--                                 is UNVERIFIED (storage buckets/policies
--                                 not reviewed yet); not a pass
--   PASS WITH DOCUMENTED EXCEPTIONS  only EXCEPTION / REVIEW / INFO findings,
--                                 each justified in RLS_RUNBOOK.md
--   PASS                          no findings except INFO
--
-- Run as postgres (the role that ran PHASE 3). Set the Laravel role in
-- `cfg` below if preflight 0f showed a different one.
-- 5e (simulation, at the end) is optional and always rolls back.
-- Also run: bash docs/security/retest_anon_access.sh (API view of anon).
-- =====================================================================

with
-- laravel_role: confirmed by preflight 0f.
-- hr_buckets: buckets holding HR documents (app: _filesBucket; web:
--   SUPABASE_STORAGE_BUCKET). They must never be public (V23).
-- reviewed_public_buckets: public buckets a documented review found to
--   hold no personal data (RLS_RUNBOOK.md, storage). Empty until then.
cfg(laravel_role, hr_buckets, reviewed_public_buckets) as (values
  ('postgres'::name, array['credentials']::text[], array[]::text[])),
-- BEGIN-ALLOWLIST-COPY (identical rows in supabase_rls_hardening.sql 3.00
-- and rls/03a; checked by tool/check_rls_allowlists.sh)
table_allow(role_name, table_name, privilege) as (values
-- BEGIN NUHRIS TABLE ALLOWLIST
  ('anon','mobile_app_versions','SELECT'),
  ('authenticated','mobile_app_versions','SELECT'),
  ('authenticated','attendance_records','SELECT'),
  ('authenticated','leave_balances','SELECT'),
  ('authenticated','leave_requests','SELECT'),
  ('authenticated','employee_credentials','SELECT'),
  ('authenticated','employee_schedule_submissions','SELECT'),
  ('authenticated','employee_schedule_days','SELECT'),
  ('authenticated','wfh_monitoring_submissions','SELECT'),
  ('authenticated','announcement_notifications','SELECT'),
  ('authenticated','announcement_notifications','DELETE'),
  ('authenticated','announcements','SELECT')
-- END NUHRIS TABLE ALLOWLIST
),
column_allow(role_name, table_name, privilege, columns) as (values
-- BEGIN NUHRIS COLUMN ALLOWLIST
  ('authenticated','users','SELECT', array['id','name','email','user_type']),
  ('authenticated','employees','SELECT', array['id','employee_id','first_name',
     'last_name','email','department_id','position','employment_type','ranking',
     'status','hire_date','official_time_in','official_time_out','auth_id',
     'profilephoto_path','deleted_at']),
  ('authenticated','departments','SELECT', array['id','name']),
  ('authenticated','privacy_notice_acknowledgments','SELECT',
     array['id','user_id','privacy_notice_version','acknowledged_at']),
  ('authenticated','employee_schedule_submissions','INSERT', array['employee_id',
     'submitted_by','semester_label','term_label','status','submitted_at','is_current']),
  ('authenticated','employee_schedule_days','INSERT', array['schedule_submission_id',
     'day_name','day_index','has_work','time_in','time_out']),
  ('authenticated','wfh_monitoring_submissions','INSERT', array['employee_id',
     'submitted_by','wfh_date','time_in','time_out','file_path','original_filename',
     'status','submitted_at','created_at','updated_at']),
  ('authenticated','privacy_notice_acknowledgments','INSERT', array['user_id',
     'privacy_notice_version','acknowledged_at','created_at','updated_at']),
  ('authenticated','announcement_notifications','UPDATE', array['is_read','read_at']),
  ('authenticated','privacy_notice_acknowledgments','UPDATE',
     array['acknowledged_at','updated_at'])
-- END NUHRIS COLUMN ALLOWLIST
),
sequence_allow(role_name, table_name, privilege) as (values
-- BEGIN NUHRIS SEQUENCE ALLOWLIST
  ('authenticated','employee_schedule_submissions','USAGE'),
  ('authenticated','employee_schedule_days','USAGE'),
  ('authenticated','wfh_monitoring_submissions','USAGE'),
  ('authenticated','privacy_notice_acknowledgments','USAGE')
-- END NUHRIS SEQUENCE ALLOWLIST
),
-- END-ALLOWLIST-COPY
seq_allow as (
  select sa.role_name, sa.privilege,
         pg_catalog.to_regclass(pg_catalog.pg_get_serial_sequence('public.' || sa.table_name, 'id'))::oid as seq_oid
  from sequence_allow sa
  where pg_catalog.to_regclass('public.' || sa.table_name) is not null
),
api(role_name, roleid) as (
  select rolname, oid from pg_catalog.pg_roles where rolname in ('anon', 'authenticated')
),
rels as (
  select c.oid, c.relname, c.relkind, c.relowner, c.relacl, c.relrowsecurity, c.relforcerowsecurity
  from pg_catalog.pg_class c
  join pg_catalog.pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind in ('r','p','v','m','f','S')
),
tprivs as (
  select v.privilege
  from (values ('SELECT'),('INSERT'),('UPDATE'),('DELETE'),('TRUNCATE'),
               ('REFERENCES'),('TRIGGER'),('MAINTAIN')) v(privilege)
  where v.privilege <> 'MAINTAIN'
     or pg_catalog.current_setting('server_version_num')::int >= 170000
),
fns as (
  select p.oid, p.proname, p.prosecdef, p.proowner, p.proacl, p.proconfig, p.prokind,
         pg_catalog.format('public.%I(%s)', p.proname,
                           pg_catalog.pg_get_function_identity_arguments(p.oid)) as signature,
         (select s from pg_catalog.unnest(p.proconfig) s where s like 'search\_path=%') as search_path
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
),
-- Roles whose future objects can land in public.
creators as (
  select r.oid, r.rolname from pg_catalog.pg_roles r
  where exists (select 1 from pg_catalog.pg_default_acl d where d.defaclrole = r.oid)
     or exists (select 1 from rels t where t.relowner = r.oid)
     or exists (select 1 from fns f where f.proowner = r.oid)
     or (pg_catalog.has_schema_privilege(r.oid, 'public', 'CREATE') and r.rolname not like 'pg\_%')
     or r.rolname in ('postgres', 'supabase_admin')
),
def_entries as (
  select d.defaclrole as roleid, d.defaclnamespace = 0 as is_global,
         coalesce(n.nspname, '(all schemas)') as scope, d.defaclobjtype as objtype,
         a.grantee, a.privilege_type, 'configured'::text as source
  from pg_catalog.pg_default_acl d
  left join pg_catalog.pg_namespace n on n.oid = d.defaclnamespace
  cross join lateral pg_catalog.aclexplode(d.defaclacl) a
  where (d.defaclnamespace = 0 or n.nspname = 'public')
    and d.defaclobjtype in ('r','S','f')
    and (a.grantee = 0 or a.grantee in (select roleid from api))
  union all
  select c.oid, true, '(all schemas)', 'f'::"char", 0::oid, 'EXECUTE', 'built-in'
  from creators c
  where not exists (select 1 from pg_catalog.pg_default_acl d
                    where d.defaclrole = c.oid and d.defaclnamespace = 0 and d.defaclobjtype = 'f')
),
helpers as (
  select f.* from fns f
  where f.proname in ('nuhris_current_employee_id', 'nuhris_current_user_id')
),

-- ------------------------------------------------------------------ checks
checks(check_id, fail_status, title) as (values
  ('V01','FAIL','Explicit table/view ACL entries for PUBLIC/anon/authenticated outside the allowlist (incl. grant options)'),
  ('V02','FAIL','Explicit column ACL entries for PUBLIC/anon/authenticated outside the allowlist'),
  ('V03','FAIL','Explicit sequence ACL entries for PUBLIC/anon/authenticated outside the allowlist'),
  ('V04','FAIL','EFFECTIVE table/view privileges of anon/authenticated outside the allowlist (direct, PUBLIC, inherited, owner)'),
  ('V05','FAIL','EFFECTIVE column privileges of anon/authenticated outside the allowlist'),
  ('V06','FAIL','EFFECTIVE sequence privileges of anon/authenticated outside the allowlist'),
  ('V07','FAIL','anon/authenticated own objects in public or are members of another role'),
  ('V08','FAIL','CREATE on schema public for anon/authenticated/PUBLIC'),
  ('V09','FAIL','Default privileges (alterable owners) exposing FUTURE tables/sequences/functions'),
  ('V10','BLOCKED','Default privileges of owners the running role cannot alter (e.g. supabase_admin)'),
  ('V11','EXCEPTION','Built-in global PUBLIC EXECUTE on FUTURE functions (PostgreSQL default)'),
  ('V12','FAIL','RLS disabled on a public table'),
  ('V13','FAIL','Non-NUHRIS permissive policy for public/anon/authenticated'),
  ('V14','FAIL','SECURITY DEFINER function executable by anon/authenticated (except NUHRIS helpers for authenticated)'),
  ('V15','FAIL','SECURITY DEFINER function without a pinned search_path'),
  ('V16','REVIEW','SECURITY DEFINER function whose search_path does not end with pg_temp (temp-table shadowing)'),
  ('V17','FAIL','NUHRIS identity helpers missing or not as designed'),
  ('V18','FAIL','Backend access: Laravel role or service_role would be restricted'),
  ('V19','EXCEPTION','Email identity fallback still active (unlinked employees)'),
  ('V20','INFO','SECURITY INVOKER functions callable by API roles (run with the caller''s own privileges)'),
  ('V21','INFO','Tables that are deny-all for API roles (RLS on, no policy)'),
  ('V22','FAIL','Storage: RLS disabled on storage.objects or storage.buckets'),
  ('V23','FAIL','Storage: HR document bucket is public (files readable by anyone with the URL, policies bypassed)'),
  ('V24','UNVERIFIED','Storage: other public bucket not yet reviewed for personal data'),
  ('V25','FAIL','Storage: permissive policy for public/anon (anonymous users need no storage access)'),
  ('V26','UNVERIFIED','Storage: permissive policy for authenticated not yet reviewed (replace with reviewed nuhris_* policies, rls/07)')
),
findings(check_id, object, detail) as (
  -- V01
  select 'V01', t.relname::text,
         case when a.grantee = 0 then 'PUBLIC' else pg_catalog.pg_get_userbyid(a.grantee) end
         || ' ' || a.privilege_type || case when a.is_grantable then ' WITH GRANT OPTION' else '' end
         || ' (grantor ' || pg_catalog.pg_get_userbyid(a.grantor) || ')'
  from rels t cross join lateral pg_catalog.aclexplode(t.relacl) a
  where t.relkind <> 'S'
    and (a.grantee = 0 or a.grantee in (select roleid from api))
    and (a.grantee = 0 or a.is_grantable
         or not exists (select 1 from table_allow ta
                        where ta.role_name = pg_catalog.pg_get_userbyid(a.grantee)
                          and ta.table_name = t.relname and ta.privilege = a.privilege_type))
  union all
  -- V02
  select 'V02', t.relname || '.' || att.attname,
         case when a.grantee = 0 then 'PUBLIC' else pg_catalog.pg_get_userbyid(a.grantee) end
         || ' ' || a.privilege_type || case when a.is_grantable then ' WITH GRANT OPTION' else '' end
         || ' (grantor ' || pg_catalog.pg_get_userbyid(a.grantor) || ')'
  from rels t
  join pg_catalog.pg_attribute att on att.attrelid = t.oid and att.attnum > 0 and not att.attisdropped
  cross join lateral pg_catalog.aclexplode(att.attacl) a
  where (a.grantee = 0 or a.grantee in (select roleid from api))
    and (a.grantee = 0 or a.is_grantable
         or not exists (select 1 from column_allow ca
                        where ca.role_name = pg_catalog.pg_get_userbyid(a.grantee)
                          and ca.table_name = t.relname and ca.privilege = a.privilege_type
                          and att.attname::text = any (ca.columns)))
  union all
  -- V03
  select 'V03', t.relname::text,
         case when a.grantee = 0 then 'PUBLIC' else pg_catalog.pg_get_userbyid(a.grantee) end
         || ' ' || a.privilege_type || case when a.is_grantable then ' WITH GRANT OPTION' else '' end
         || ' (grantor ' || pg_catalog.pg_get_userbyid(a.grantor) || ')'
  from rels t cross join lateral pg_catalog.aclexplode(t.relacl) a
  where t.relkind = 'S'
    and (a.grantee = 0 or a.grantee in (select roleid from api))
    and (a.grantee = 0 or a.is_grantable
         or not exists (select 1 from seq_allow sa
                        where sa.role_name = pg_catalog.pg_get_userbyid(a.grantee)
                          and sa.seq_oid = t.oid and sa.privilege = a.privilege_type))
  union all
  -- V04
  select 'V04', t.relname::text, r.role_name || ' ' || p.privilege
  from api r cross join rels t cross join tprivs p
  where t.relkind <> 'S'
    and pg_catalog.has_table_privilege(r.role_name, t.oid, p.privilege)
    and not exists (select 1 from table_allow ta
                    where ta.role_name = r.role_name and ta.table_name = t.relname
                      and ta.privilege = p.privilege)
  union all
  -- V05 (column privileges NOT already implied by a table-level privilege)
  select 'V05', t.relname || '.' || att.attname, r.role_name || ' ' || p.privilege
  from api r cross join rels t
  join pg_catalog.pg_attribute att on att.attrelid = t.oid and att.attnum > 0 and not att.attisdropped
  cross join (values ('SELECT'),('INSERT'),('UPDATE'),('REFERENCES')) p(privilege)
  where t.relkind <> 'S'
    and pg_catalog.has_column_privilege(r.role_name, t.oid, att.attnum, p.privilege)
    and not pg_catalog.has_table_privilege(r.role_name, t.oid, p.privilege)
    and not exists (select 1 from column_allow ca
                    where ca.role_name = r.role_name and ca.table_name = t.relname
                      and ca.privilege = p.privilege and att.attname::text = any (ca.columns))
  union all
  -- V06
  select 'V06', t.relname::text, r.role_name || ' ' || p.privilege
  from api r cross join rels t
  cross join (values ('USAGE'),('SELECT'),('UPDATE')) p(privilege)
  where t.relkind = 'S'
    and pg_catalog.has_sequence_privilege(r.role_name, t.oid, p.privilege)
    and not exists (select 1 from seq_allow sa
                    where sa.role_name = r.role_name and sa.seq_oid = t.oid
                      and sa.privilege = p.privilege)
  union all
  -- V07 ownership
  select 'V07', t.relname::text, 'owned by ' || pg_catalog.pg_get_userbyid(t.relowner)
         || ' (an API role has its privileges)'
  from rels t
  where exists (select 1 from api r where pg_catalog.pg_has_role(r.roleid, t.relowner, 'USAGE'))
  union all
  select 'V07', f.signature, 'owned by ' || pg_catalog.pg_get_userbyid(f.proowner)
  from fns f
  where exists (select 1 from api r where pg_catalog.pg_has_role(r.roleid, f.proowner, 'USAGE'))
  union all
  -- V07 memberships (MEMBER covers inheriting and SET-only memberships)
  select 'V07', r.role_name || ' -> ' || o.rolname,
         'member of ' || o.rolname
         || case when pg_catalog.pg_has_role(r.roleid, o.oid, 'USAGE')
                 then ' (inherits its privileges)' else ' (SET ROLE only)' end
  from api r cross join pg_catalog.pg_roles o
  where o.oid <> r.roleid and pg_catalog.pg_has_role(r.roleid, o.oid, 'MEMBER')
  union all
  -- V08
  select 'V08', 'schema public', r.role_name || ' CREATE'
  from api r where pg_catalog.has_schema_privilege(r.role_name, 'public', 'CREATE')
  union all
  select 'V08', 'schema public', 'PUBLIC CREATE'
  from pg_catalog.pg_namespace n
  cross join lateral pg_catalog.aclexplode(coalesce(n.nspacl, pg_catalog.acldefault('n', n.nspowner))) a
  where n.nspname = 'public' and a.grantee = 0 and a.privilege_type = 'CREATE'
  union all
  -- V09 / V10 / V11 default privileges
  select case
           when d.objtype = 'f' and d.grantee = 0 and d.is_global then 'V11'
           when pg_catalog.pg_has_role(current_user, d.roleid, 'USAGE') then 'V09'
           else 'V10'
         end,
         pg_catalog.pg_get_userbyid(d.roleid) || ' @ ' || d.scope,
         case d.objtype when 'r' then 'tables' when 'S' then 'sequences' else 'functions' end
         || ': ' || case when d.grantee = 0 then 'PUBLIC' else pg_catalog.pg_get_userbyid(d.grantee) end
         || ' ' || d.privilege_type || ' (' || d.source || ')'
         || case when pg_catalog.pg_has_role(current_user, d.roleid, 'USAGE') then ''
                 else '; ' || current_user || ' cannot alter this owner''s defaults' end
  from def_entries d
  union all
  -- V12
  select 'V12', t.relname::text, 'RLS disabled'
  from rels t where t.relkind in ('r','p') and not t.relrowsecurity
  union all
  -- V13
  select 'V13', p.tablename || '.' || p.policyname,
         p.cmd || ' to ' || p.roles::text || ' using ' || coalesce(p.qual, '-')
  from pg_catalog.pg_policies p
  where p.schemaname = 'public' and p.permissive = 'PERMISSIVE'
    and p.policyname not like 'nuhris\_%'
    and p.roles && array['public','anon','authenticated']::name[]
  union all
  -- V14
  select 'V14', f.signature, r.role_name || ' EXECUTE; runs as ' || pg_catalog.pg_get_userbyid(f.proowner)
  from fns f cross join api r
  where f.prosecdef and pg_catalog.has_function_privilege(r.role_name, f.oid, 'EXECUTE')
    and not (r.role_name = 'authenticated'
             and f.proname in ('nuhris_current_employee_id', 'nuhris_current_user_id'))
  union all
  -- V15
  select 'V15', f.signature, 'search_path not set; name resolution follows the caller'
  from fns f where f.prosecdef and f.search_path is null
  union all
  -- V16
  select 'V16', f.signature, f.search_path || ' (proposal in rls/03a R3)'
  from fns f
  where f.prosecdef and f.search_path is not null
    and f.search_path <> 'search_path=""' and f.search_path not like '%pg\_temp'
  union all
  -- V17 helpers
  select 'V17', h.name, 'missing'
  from (values ('nuhris_current_employee_id'), ('nuhris_current_user_id')) h(name)
  where not exists (select 1 from helpers x where x.proname = h.name)
  union all
  select 'V17', h.signature,
         pg_catalog.concat_ws('; ',
           case when not h.prosecdef then 'not SECURITY DEFINER' end,
           case when h.search_path is distinct from 'search_path=""' then 'search_path is not empty' end,
           case when pg_catalog.has_function_privilege('anon', h.oid, 'EXECUTE') then 'anon can EXECUTE' end,
           case when not pg_catalog.has_function_privilege('authenticated', h.oid, 'EXECUTE')
                then 'authenticated cannot EXECUTE (all own-row policies would deny)' end)
  from helpers h
  where not h.prosecdef or h.search_path is distinct from 'search_path=""'
     or pg_catalog.has_function_privilege('anon', h.oid, 'EXECUTE')
     or not pg_catalog.has_function_privilege('authenticated', h.oid, 'EXECUTE')
  union all
  -- V18 backend access
  select 'V18', t.relname::text,
         l.laravel_role || ' lacks ' || p.privilege
  from cfg l cross join rels t
  cross join (values ('SELECT'),('INSERT'),('UPDATE'),('DELETE')) p(privilege)
  where t.relkind in ('r','p')
    and pg_catalog.to_regrole(l.laravel_role) is not null
    and not pg_catalog.has_table_privilege(l.laravel_role, t.oid, p.privilege)
  union all
  select 'V18', t.relname::text, l.laravel_role || ' is subject to RLS here (not owner, no BYPASSRLS)'
  from cfg l cross join rels t
  where t.relkind in ('r','p') and t.relrowsecurity
    and pg_catalog.to_regrole(l.laravel_role) is not null
    and not exists (select 1 from pg_catalog.pg_roles r
                    where r.rolname = l.laravel_role and (r.rolsuper or r.rolbypassrls))
    and not (pg_catalog.pg_has_role(l.laravel_role, t.relowner, 'USAGE') and not t.relforcerowsecurity)
  union all
  select 'V18', l.laravel_role::text, 'role does not exist (fix cfg)'
  from cfg l where pg_catalog.to_regrole(l.laravel_role) is null
  union all
  select 'V18', 'service_role', 'does not bypass RLS'
  from pg_catalog.pg_roles r where r.rolname = 'service_role' and not (r.rolbypassrls or r.rolsuper)
  union all
  -- V19 email fallback (allowed until every employee is linked; RUNBOOK step 8/9)
  select 'V19', h.signature,
         'email fallback present; active employees without auth_id: '
         || (select count(*) from public.employees e where e.deleted_at is null and e.auth_id is null)
         || ' (remove with rls/06 once this is 0 and rls/02 shows LINKED_OK for all)'
  from helpers h
  where h.proname = 'nuhris_current_employee_id'
    and pg_catalog.pg_get_functiondef(h.oid) ~* 'auth\.users'
  union all
  -- V20
  select 'V20', f.signature,
         'SECURITY INVOKER; executable by '
         || pg_catalog.concat_ws(', ',
              case when pg_catalog.has_function_privilege('anon', f.oid, 'EXECUTE') then 'anon' end,
              case when pg_catalog.has_function_privilege('authenticated', f.oid, 'EXECUTE') then 'authenticated' end)
  from fns f
  where not f.prosecdef and f.prokind in ('f','p')
    and (pg_catalog.has_function_privilege('anon', f.oid, 'EXECUTE')
         or pg_catalog.has_function_privilege('authenticated', f.oid, 'EXECUTE'))
  union all
  -- V21
  select 'V21', t.relname::text, 'RLS on, no policy: API roles see/write nothing'
  from rels t
  where t.relkind in ('r','p') and t.relrowsecurity
    and not exists (select 1 from pg_catalog.pg_policy p where p.polrelid = t.oid)
  union all
  -- V22 storage RLS (Supabase enables it; disabling it exposes every file)
  select 'V22', 'storage.' || c.relname, 'RLS disabled'
  from pg_catalog.pg_class c
  join pg_catalog.pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'storage' and c.relname in ('objects', 'buckets') and not c.relrowsecurity
  union all
  -- V23 / V24 public buckets (served to anyone with the URL)
  select case when b.id = any (l.hr_buckets) or b.name = any (l.hr_buckets) then 'V23' else 'V24' end,
         'bucket ' || b.id, 'public = true'
  from storage.buckets b cross join cfg l
  where b.public
    and not (b.id = any (l.reviewed_public_buckets) and not b.id = any (l.hr_buckets))
  union all
  -- V25 / V26 permissive storage policies. Restrictive policies only narrow
  -- access and are not reported.
  select case when p.roles && array['public','anon']::name[] then 'V25' else 'V26' end,
         p.tablename || '.' || p.policyname,
         p.cmd || ' to ' || p.roles::text || ' using ' || coalesce(p.qual, '-')
         || coalesce(' check ' || p.with_check, '')
  from pg_catalog.pg_policies p
  where p.schemaname = 'storage' and p.permissive = 'PERMISSIVE'
    and (p.roles && array['public','anon']::name[]
         or (p.roles && array['authenticated']::name[] and p.policyname not like 'nuhris\_%'))
),
summary as (
  select c.check_id, c.title, count(f.check_id) as n,
         case when count(f.check_id) = 0 and c.fail_status <> 'INFO' then 'PASS'
              else c.fail_status end as status
  from checks c left join findings f on f.check_id = c.check_id
  group by c.check_id, c.title, c.fail_status
)
select '1 OVERALL' as section, '-' as check_id,
       case
         when exists (select 1 from summary where status = 'FAIL') then 'FAIL'
         when exists (select 1 from summary where status = 'BLOCKED') then 'NOT SECURE: BLOCKED'
         when exists (select 1 from summary where status = 'UNVERIFIED') then 'NOT VERIFIED'
         when exists (select 1 from summary where status in ('EXCEPTION','REVIEW'))
           then 'PASS WITH DOCUMENTED EXCEPTIONS'
         else 'PASS'
       end as status,
       (select string_agg(check_id || '=' || status, ' ' order by check_id)
        from summary where status not in ('PASS','INFO')) as title,
       null::bigint as findings, null::text as object, null::text as detail
union all
select '2 SUMMARY', s.check_id, s.status, s.title, s.n, null, null from summary s
union all
select '3 DETAIL', f.check_id, c.fail_status, c.title, null, f.object, f.detail
from findings f join checks c on c.check_id = f.check_id
order by 1, 2, 6, 7;


-- 5b. Column grants now held by authenticated (no password, remember_token,
--     phone or address may appear).
select table_name, privilege_type, string_agg(column_name, ', ' order by column_name) as columns
from information_schema.column_privileges
where table_schema = 'public' and grantee = 'authenticated'
group by 1, 2 order by 1, 2;


-- 5d. Policies now in place, per table (expect only nuhris_* on public
--     tables, plus any RESTRICTIVE policies you intentionally kept).
select tablename, policyname, permissive, roles, cmd, qual, with_check
from pg_catalog.pg_policies where schemaname = 'public'
order by 1, 2;


-- 5e. OPTIONAL simulation as employee A (always rolled back).
--     Replace <AUTH_UUID_A> with A's auth.users.id and <EMPLOYEE_PK_B> with
--     another employee's employees.id. Run the block as a whole.
--
-- begin;
--   set local role authenticated;
--   select pg_catalog.set_config('request.jwt.claims',
--     '{"sub":"<AUTH_UUID_A>","role":"authenticated"}', true);
--
--   select public.nuhris_current_employee_id();          -- A's employees.id
--   select count(*) from public.employees;               -- expect 1
--   select count(*) from public.employees
--    where id = <EMPLOYEE_PK_B>;                         -- expect 0
--   select count(*) from public.attendance_records
--    where employee_id = <EMPLOYEE_PK_B>;                -- expect 0
--   select count(*) from public.sessions;                -- expect ERROR: permission denied
-- rollback;
--
-- Rejected-write checks (each must fail; ROLLBACK after each error):
-- begin;
--   set local role authenticated;
--   select pg_catalog.set_config('request.jwt.claims',
--     '{"sub":"<AUTH_UUID_A>","role":"authenticated"}', true);
--   insert into public.employee_schedule_submissions
--     (employee_id, submitted_by, semester_label, term_label, status, submitted_at, is_current)
--   values (<EMPLOYEE_PK_B>, 1, 'x', 'x', 'pending', now(), false);
--   -- expect: new row violates row-level security policy
-- rollback;
-- begin;
--   set local role authenticated;
--   select pg_catalog.set_config('request.jwt.claims',
--     '{"sub":"<AUTH_UUID_A>","role":"authenticated"}', true);
--   update public.attendance_records set status = 'present';
--   -- expect: permission denied for table attendance_records
-- rollback;
-- begin;
--   set local role anon;
--   select public.enqueue_announcement_notifications();
--   -- expect: permission denied for function (or "trigger functions can
--   -- only be called as triggers" if EXECUTE were still granted)
-- rollback;
