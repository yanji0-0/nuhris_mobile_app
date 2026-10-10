-- =====================================================================
-- PHASE 3 — NUHRIS Supabase RLS hardening (APPLY)            revision 3
-- =====================================================================
-- Previous revision kept unchanged in supabase_rls_hardening.v1.backup.sql.
-- Execution order, verification and rollback: docs/security/RLS_RUNBOOK.md
--
-- DO NOT RUN until ALL of these are done (RUNBOOK steps 1–6):
--   1. App v1.1.0 installed by every employee. v1.0.0 uses select('*'),
--      which the column-level grants below reject, so it will stop working.
--   2. rls/00_preflight_checks.sql and rls/00b reviewed.
--   3. rls/01_generate_rollback.sql output saved as a file.
--   4. rls/03a_public_grants_remediation.sql reviewed: no BLOCKER rows.
--   5. Supabase Auth settings changed and verified:
--        Allow new users to sign up = OFF, Confirm email = ON,
--        Secure email change = ON.
--   6. Any non-NUHRIS permissive policy on public tables reviewed and
--      dropped explicitly (this script refuses to run while one exists).
--
-- What this script changes (revision 3):
--   * revokes EVERY table, view, column and sequence privilege of anon and
--     authenticated in schema public (only entries the running role can
--     revoke; anything else aborts in 3.0h before a change is made), then
--     grants back only the allowlist the mobile app needs (3.3–3.4);
--   * revokes EXECUTE from PUBLIC, anon and authenticated on SECURITY
--     DEFINER trigger functions in public (e.g.
--     enqueue_announcement_notifications) and re-grants it only to the
--     backend roles that held it (3.2c). Callable SECURITY DEFINER
--     functions and configured PUBLIC default privileges are NOT revoked
--     automatically: 3.0n / 3.0o abort until they are reviewed (rls/03a);
--   * removes default privileges that would expose FUTURE tables, sequences
--     and functions to anon / authenticated / PUBLIC, for every owner role
--     the running role is allowed to alter; others are reported (3.2d);
--   * RLS on every public table, own-row policies, mobile_app_versions.
--
-- What this script does NOT do:
--   * no DELETE / UPDATE / TRUNCATE of any existing table; no DROP TABLE,
--     DROP FUNCTION, no CASCADE, no role-membership changes;
--   * does not revoke PUBLIC grants on tables/sequences (none exist today;
--     3.0g aborts if one appears; reviewed with rls/03a);
--   * does not change default privileges of roles it cannot alter (e.g.
--     supabase_admin): WARNING here, BLOCKED in 05_verify;
--   * does not link employees.auth_id (manual: rls/02_auth_id_linking.sql);
--   * no storage policies (reviewed separately: rls/07_storage_review.sql).
-- Only data written: one row in the new table public.mobile_app_versions.
--
-- Everything runs in ONE transaction. Any failed precondition or
-- statement aborts it and nothing is applied. Temporary tables used for
-- the checks are dropped at commit / rollback. With psql, run it with
-- `psql -v ON_ERROR_STOP=1 -f ...`. The last result (3.7) states whether
-- it was applied and whether owners remain BLOCKED.
--
-- Objects it creates (two helpers, mobile_app_versions) get a COMMENT
-- 'NUHRIS_HARDENING_OBJECT: ...'. 3.0m refuses to overwrite an unmarked
-- object with the same name; the generated rollback drops only objects that
-- were absent when it was generated AND carry the marker.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 3.00 CONFIGURATION, ALLOWLIST AND BASELINE (temporary, this transaction)
-- ---------------------------------------------------------------------
create temp table nuhris_cfg (
  -- The role Laravel connects as, confirmed by preflight 0f.
  -- (DB_USERNAME "postgres.<ref>" on the Supabase pooler = role postgres.)
  laravel_role name not null,
  -- PostgreSQL gives EXECUTE on every NEW function to PUBLIC by default
  -- (built-in, global for the creating role). Revoking that default
  -- affects functions the role creates in EVERY schema, including
  -- extension functions installed by it; column defaults or policies that
  -- call such a function would then fail for the API roles. Kept false
  -- until reviewed (documented exception, 05_verify V11).
  revoke_public_function_default boolean not null
) on commit drop;
insert into nuhris_cfg values ('postgres', false);

-- What anon / authenticated may hold after this script. Derived from the
-- queries in lib/services/api_client.dart (v1.1.0). The SAME rows appear in
-- rls/03a and rls/05_verify; tool/check_rls_allowlists.sh checks they match.
create temp table nuhris_table_allow (role_name name, table_name name, privilege text) on commit drop;
insert into nuhris_table_allow values
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
;

create temp table nuhris_column_allow (role_name name, table_name name, privilege text, columns text[]) on commit drop;
insert into nuhris_column_allow values
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
;

-- Sequences: USAGE (nextval through the id column default) on the id
-- sequence of each table the app INSERTs into. Nothing else.
create temp table nuhris_sequence_allow (role_name name, table_name name, privilege text) on commit drop;
insert into nuhris_sequence_allow values
-- BEGIN NUHRIS SEQUENCE ALLOWLIST
  ('authenticated','employee_schedule_submissions','USAGE'),
  ('authenticated','employee_schedule_days','USAGE'),
  ('authenticated','wfh_monitoring_submissions','USAGE'),
  ('authenticated','privacy_notice_acknowledgments','USAGE')
-- END NUHRIS SEQUENCE ALLOWLIST
;

-- Backend roles whose CURRENT access must survive this script unchanged:
-- Laravel's role, postgres (SQL editor / migrations) and service_role
-- (web portal storage calls, Supabase admin API). Their effective
-- privileges on every public relation, column, sequence and function are
-- recorded here and compared in 3.6.
create temp table nuhris_protected_before on commit drop as
with prot as (
  select r.rolname from pg_catalog.pg_roles r
  where r.rolname in (select laravel_role from nuhris_cfg)
     or r.rolname in ('postgres', 'service_role')
),
rels as (
  select c.oid, c.relkind from pg_catalog.pg_class c
  join pg_catalog.pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind in ('r','p','v','m','f','S')
),
tprivs as (
  select v.privilege
  from (values ('SELECT'),('INSERT'),('UPDATE'),('DELETE'),('TRUNCATE'),
               ('REFERENCES'),('TRIGGER'),('MAINTAIN')) v(privilege)
  where v.privilege <> 'MAINTAIN'
     or pg_catalog.current_setting('server_version_num')::int >= 170000
)
select p.rolname as role_name, 'table'::text as kind, t.oid as obj, 0::int2 as attnum, tp.privilege
from prot p cross join rels t cross join tprivs tp
where t.relkind <> 'S' and pg_catalog.has_table_privilege(p.rolname, t.oid, tp.privilege)
union all
select p.rolname, 'column', t.oid, att.attnum, cp.privilege
from prot p cross join rels t
join pg_catalog.pg_attribute att on att.attrelid = t.oid and att.attnum > 0 and not att.attisdropped
cross join (values ('SELECT'),('INSERT'),('UPDATE'),('REFERENCES')) cp(privilege)
where t.relkind <> 'S'
  and pg_catalog.has_column_privilege(p.rolname, t.oid, att.attnum, cp.privilege)
  and not pg_catalog.has_table_privilege(p.rolname, t.oid, cp.privilege)
union all
select p.rolname, 'sequence', t.oid, 0, sp.privilege
from prot p cross join rels t
cross join (values ('USAGE'),('SELECT'),('UPDATE')) sp(privilege)
where t.relkind = 'S' and pg_catalog.has_sequence_privilege(p.rolname, t.oid, sp.privilege)
union all
select p.rolname, 'function', pr.oid, 0, 'EXECUTE'
from prot p cross join pg_catalog.pg_proc pr
join pg_catalog.pg_namespace pn on pn.oid = pr.pronamespace
where pn.nspname = 'public'
  and pg_catalog.has_function_privilege(p.rolname, pr.oid, 'EXECUTE');

-- SECURITY DEFINER functions whose EXECUTE is restricted in 3.2c: in
-- schema public, not part of an extension, not the two NUHRIS helpers
-- (managed in 3.1), and currently executable by PUBLIC, anon or
-- authenticated (explicitly or through the built-in default).
create temp table nuhris_secdef_scope on commit drop as
select p.oid, p.proowner,
       pg_catalog.format('public.%I(%s)', p.proname,
                         pg_catalog.pg_get_function_identity_arguments(p.oid)) as signature
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.prosecdef
  and p.proname not in ('nuhris_current_employee_id', 'nuhris_current_user_id')
  and not exists (select 1 from pg_catalog.pg_depend d
                  where d.classid = 'pg_catalog.pg_proc'::pg_catalog.regclass
                    and d.objid = p.oid and d.deptype = 'e')
  and (pg_catalog.has_function_privilege('anon', p.oid, 'EXECUTE')
       or pg_catalog.has_function_privilege('authenticated', p.oid, 'EXECUTE')
       or exists (select 1 from pg_catalog.aclexplode(
                    coalesce(p.proacl, pg_catalog.acldefault('f', p.proowner))) a
                  where a.grantee = 0 and a.privilege_type = 'EXECUTE'));


-- ---------------------------------------------------------------------
-- 3.0 PRECONDITIONS (abort if not met)
-- ---------------------------------------------------------------------
do $$
declare
  v_laravel_role constant text := (select laravel_role from nuhris_cfg);
  v_missing text;
  v_bad text;
begin
  if pg_catalog.to_regrole('anon') is null or pg_catalog.to_regrole('authenticated') is null then
    raise exception 'ABORT: roles anon / authenticated not found (not a Supabase database?)';
  end if;

  -- a) every referenced column exists
  select string_agg(e.t || '.' || e.c, ', ') into v_missing
  from (values
    ('users','id'),('users','name'),('users','email'),('users','user_type'),
    ('employees','id'),('employees','employee_id'),('employees','first_name'),
    ('employees','last_name'),('employees','email'),('employees','department_id'),
    ('employees','position'),('employees','employment_type'),('employees','ranking'),
    ('employees','status'),('employees','hire_date'),('employees','official_time_in'),
    ('employees','official_time_out'),('employees','auth_id'),
    ('employees','profilephoto_path'),('employees','deleted_at'),
    ('departments','id'),('departments','name'),
    ('attendance_records','employee_id'),('leave_balances','employee_id'),
    ('leave_requests','employee_id'),('employee_credentials','employee_id'),
    ('employee_schedule_submissions','employee_id'),
    ('employee_schedule_submissions','submitted_by'),
    ('employee_schedule_submissions','reviewed_by'),
    ('employee_schedule_submissions','reviewed_at'),
    ('employee_schedule_submissions','review_notes'),
    ('employee_schedule_submissions','status'),
    ('employee_schedule_submissions','is_current'),
    ('employee_schedule_submissions','semester_label'),
    ('employee_schedule_submissions','term_label'),
    ('employee_schedule_submissions','submitted_at'),
    ('employee_schedule_days','schedule_submission_id'),
    ('employee_schedule_days','day_name'),('employee_schedule_days','day_index'),
    ('employee_schedule_days','has_work'),('employee_schedule_days','time_in'),
    ('employee_schedule_days','time_out'),
    ('wfh_monitoring_submissions','employee_id'),
    ('wfh_monitoring_submissions','submitted_by'),
    ('wfh_monitoring_submissions','reviewed_by'),
    ('wfh_monitoring_submissions','reviewed_at'),
    ('wfh_monitoring_submissions','review_notes'),
    ('wfh_monitoring_submissions','status'),
    ('wfh_monitoring_submissions','wfh_date'),
    ('wfh_monitoring_submissions','time_in'),
    ('wfh_monitoring_submissions','time_out'),
    ('wfh_monitoring_submissions','file_path'),
    ('wfh_monitoring_submissions','original_filename'),
    ('wfh_monitoring_submissions','submitted_at'),
    ('wfh_monitoring_submissions','created_at'),
    ('wfh_monitoring_submissions','updated_at'),
    ('announcement_notifications','user_id'),
    ('announcement_notifications','announcement_id'),
    ('announcement_notifications','is_read'),
    ('announcement_notifications','read_at'),
    ('announcements','id'),
    ('privacy_notice_acknowledgments','user_id'),
    ('privacy_notice_acknowledgments','privacy_notice_version'),
    ('privacy_notice_acknowledgments','acknowledged_at'),
    ('privacy_notice_acknowledgments','created_at'),
    ('privacy_notice_acknowledgments','updated_at')) as e(t, c)
  where not exists (
    select 1 from information_schema.columns ic
    where ic.table_schema = 'public' and ic.table_name = e.t and ic.column_name = e.c);
  if v_missing is not null then
    raise exception 'ABORT: missing columns: %', v_missing;
  end if;

  -- b) no FORCE RLS (it would subject the table owner, i.e. Laravel, to RLS)
  select string_agg(c.relname, ', ') into v_bad
  from pg_catalog.pg_class c
  join pg_catalog.pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind in ('r','p') and c.relforcerowsecurity;
  if v_bad is not null then
    raise exception 'ABORT: FORCE RLS is set on: %', v_bad;
  end if;

  -- c) Laravel's role must keep full access: superuser, BYPASSRLS, or owner
  --    of every public table. Otherwise enabling RLS would lock out the web.
  if not exists (select 1 from pg_catalog.pg_roles where rolname = v_laravel_role) then
    raise exception 'ABORT: role % does not exist', v_laravel_role;
  end if;
  if not exists (select 1 from pg_catalog.pg_roles
                 where rolname = v_laravel_role and (rolsuper or rolbypassrls)) then
    select string_agg(c.relname, ', ') into v_bad
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r','p')
      and pg_catalog.pg_get_userbyid(c.relowner) <> v_laravel_role;
    if v_bad is not null then
      raise exception 'ABORT: % neither bypasses RLS nor owns: %', v_laravel_role, v_bad;
    end if;
  end if;

  -- d) the identity helpers read auth.users
  if not pg_catalog.has_table_privilege(current_user, 'auth.users', 'SELECT') then
    raise exception 'ABORT: % cannot read auth.users', current_user;
  end if;

  -- e) no other permissive policy may grant rows to API roles: policies are
  --    OR-ed, so it would silently override the ownership rules below.
  select string_agg(p.tablename || '.' || p.policyname, ', ') into v_bad
  from pg_catalog.pg_policies p
  where p.schemaname = 'public'
    and p.permissive = 'PERMISSIVE'
    and p.policyname not like 'nuhris\_%'
    and p.roles && array['public','anon','authenticated']::name[];
  if v_bad is not null then
    raise exception 'ABORT: review and drop these policies first: %', v_bad;
  end if;

  -- f) one Auth account may not be linked to two employees
  select string_agg(auth_id::text, ', ') into v_bad
  from (select auth_id from public.employees
        where auth_id is not null and deleted_at is null
        group by auth_id having count(*) > 1) d;
  if v_bad is not null then
    raise exception 'ABORT: auth_id linked to several employees: %', v_bad;
  end if;

  -- g) no PUBLIC privileges on any public-schema table, view, column or
  --    sequence. Everything granted to PUBLIC is also held by anon and
  --    authenticated, and this script does NOT revoke from PUBLIC blindly:
  --    review and remediate with rls/03a_public_grants_remediation.sql.
  --    (aclexplode reports PUBLIC as grantee OID 0.)
  select string_agg(x, ', ') into v_bad from (
    select c.relname || ':' || a.privilege_type as x
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    cross join lateral pg_catalog.aclexplode(c.relacl) a
    where n.nspname = 'public' and c.relkind in ('r','p','v','m','f','S')
      and a.grantee = 0
    union all
    select c.relname || '.' || att.attname || ':' || a.privilege_type
    from pg_catalog.pg_attribute att
    join pg_catalog.pg_class c on c.oid = att.attrelid
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    cross join lateral pg_catalog.aclexplode(att.attacl) a
    where n.nspname = 'public' and att.attnum > 0 and not att.attisdropped
      and a.grantee = 0
  ) s;
  if v_bad is not null then
    raise exception 'ABORT: PUBLIC privileges exist (review with rls/03a): %', v_bad;
  end if;
  --    (PUBLIC entries in DEFAULT privileges affect only future objects and
  --    are removed by 3.2d for every owner the running role may alter.)

  -- h) every anon / authenticated ACL entry that 3.2 must remove can be
  --    removed by the running role. A non-superuser REVOKE only removes
  --    entries whose grantor it acts as: the owner (when the running role
  --    has the owner's privileges) or otherwise a role it has privileges
  --    of. Entries granted by anyone else (e.g. supabase_admin) would
  --    silently survive. Entries that stay within the allowlist are
  --    tolerated. Listed in advance by rls/03a (R2, BLOCKER rows).
  with ents as (
    select c.oid as relid, c.relname::text as obj, null::text as col, c.relkind, c.relowner,
           a.grantor, a.grantee, a.privilege_type
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    cross join lateral pg_catalog.aclexplode(c.relacl) a
    where n.nspname = 'public' and c.relkind in ('r','p','v','m','f','S')
      and a.grantee in ('anon'::regrole::oid, 'authenticated'::regrole::oid)
    union all
    select c.oid, c.relname, att.attname, c.relkind, c.relowner, a.grantor, a.grantee, a.privilege_type
    from pg_catalog.pg_attribute att
    join pg_catalog.pg_class c on c.oid = att.attrelid
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    cross join lateral pg_catalog.aclexplode(att.attacl) a
    where n.nspname = 'public' and att.attnum > 0 and not att.attisdropped
      and a.grantee in ('anon'::regrole::oid, 'authenticated'::regrole::oid)
  )
  select string_agg(e.obj || coalesce('.' || e.col, '') || ':'
                    || pg_catalog.pg_get_userbyid(e.grantee) || ':' || e.privilege_type
                    || ' (grantor ' || pg_catalog.pg_get_userbyid(e.grantor) || ')', ', ')
    into v_bad
  from ents e
  where not (case when pg_catalog.pg_has_role(current_user, e.relowner, 'USAGE')
                  then e.grantor = e.relowner
                  else pg_catalog.pg_has_role(current_user, e.grantor, 'USAGE') end)
    and not exists (select 1 from nuhris_table_allow ta
                    where e.relkind <> 'S' and ta.role_name = pg_catalog.pg_get_userbyid(e.grantee)
                      and ta.table_name = e.obj and ta.privilege = e.privilege_type)
    and not exists (select 1 from nuhris_column_allow ca
                    where e.col is not null and ca.role_name = pg_catalog.pg_get_userbyid(e.grantee)
                      and ca.table_name = e.obj and ca.privilege = e.privilege_type
                      and e.col = any (ca.columns))
    and not exists (select 1 from nuhris_sequence_allow sa
                    where e.relkind = 'S' and sa.role_name = pg_catalog.pg_get_userbyid(e.grantee)
                      and sa.privilege = e.privilege_type
                      and pg_catalog.to_regclass('public.' || sa.table_name) is not null
                      and pg_catalog.to_regclass(pg_catalog.pg_get_serial_sequence(
                            'public.' || sa.table_name, 'id'))::oid = e.relid);
  if v_bad is not null then
    raise exception 'ABORT: % cannot revoke these grants (ask the grantor / owner): %',
      current_user, v_bad;
  end if;

  --    ... and the same for EXECUTE on the SECURITY DEFINER functions 3.2c
  --    restricts: the running role must be able to act as their owner.
  select string_agg(s.signature || ' (owner ' || pg_catalog.pg_get_userbyid(s.proowner) || ')', ', ')
    into v_bad
  from nuhris_secdef_scope s
  where not pg_catalog.pg_has_role(current_user, s.proowner, 'USAGE');
  if v_bad is not null then
    raise exception 'ABORT: % cannot restrict EXECUTE on SECURITY DEFINER functions it does not own: %',
      current_user, v_bad;
  end if;

  -- i) enabling RLS on every table must not lock out service_role (web
  --    portal / admin API). In Supabase it bypasses RLS; verify it.
  if exists (select 1 from pg_catalog.pg_roles
             where rolname = 'service_role' and not (rolbypassrls or rolsuper)) then
    raise exception 'ABORT: service_role does not bypass RLS; enabling RLS would block it';
  end if;

  -- j) the API roles must not own objects in public, nor inherit or be
  --    able to SET ROLE to any other role. Ownership and memberships are
  --    not removed by REVOKE, so the effective-privilege check in 3.6
  --    could never pass. Memberships are NOT changed by this script: the
  --    standard Supabase memberships (authenticator -> anon/authenticated,
  --    postgres -> anon/authenticated) run the other way and are fine.
  select string_agg(api.rolname || ' -> ' || r.rolname, ', ') into v_bad
  from pg_catalog.pg_roles api
  cross join pg_catalog.pg_roles r
  where api.rolname in ('anon', 'authenticated')
    and r.oid <> api.oid
    and pg_catalog.pg_has_role(api.oid, r.oid, 'MEMBER');
  if v_bad is not null then
    raise exception 'ABORT: API roles are members of other roles (review, do not auto-revoke): %', v_bad;
  end if;

  select string_agg(x, ', ') into v_bad from (
    select c.relname::text as x
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and pg_catalog.pg_get_userbyid(c.relowner) in ('anon', 'authenticated')
    union all
    select p.proname::text
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and pg_catalog.pg_get_userbyid(p.proowner) in ('anon', 'authenticated')
  ) s;
  if v_bad is not null then
    raise exception 'ABORT: objects in public owned by anon/authenticated: %', v_bad;
  end if;

  -- k) the Laravel role must not depend on the API roles for its access.
  if v_laravel_role in ('anon', 'authenticated', 'authenticator') then
    raise exception 'ABORT: Laravel role % is an API role; this plan does not apply', v_laravel_role;
  end if;

  -- l) no API-reachable object depends on a SECURITY DEFINER function 3.2c
  --    restricts. Triggers are fine (EXECUTE is checked only when a trigger
  --    is created, never when it fires). Policies, column defaults, views
  --    and other public functions that API roles can call are not.
  select string_agg(s.signature || ' used by ' || x.what, ', ') into v_bad
  from nuhris_secdef_scope s
  cross join lateral (
    select pg_catalog.pg_describe_object(d.classid, d.objid, d.objsubid) as what
    from pg_catalog.pg_depend d
    where d.refclassid = 'pg_catalog.pg_proc'::pg_catalog.regclass
      and d.refobjid = s.oid
      and d.classid <> 'pg_catalog.pg_trigger'::pg_catalog.regclass
      and d.deptype = 'n'
    union all
    select 'function ' || p2.proname
    from pg_catalog.pg_proc p2
    join pg_catalog.pg_namespace n2 on n2.oid = p2.pronamespace
    where n2.nspname = 'public' and p2.oid <> s.oid
      and p2.prosrc ~ ('\m' || (select proname from pg_catalog.pg_proc where oid = s.oid) || '\M')
      and (pg_catalog.has_function_privilege('anon', p2.oid, 'EXECUTE')
           or pg_catalog.has_function_privilege('authenticated', p2.oid, 'EXECUTE'))
  ) x;
  if v_bad is not null then
    raise exception 'ABORT: restricting EXECUTE would break API access paths: %', v_bad;
  end if;

  -- m) Objects this script creates must either not exist yet or carry the
  --    NUHRIS ownership marker (COMMENT 'NUHRIS_HARDENING_OBJECT: ...', set
  --    in 3.1 / 3.5 by a previous run). An unmarked object with the same
  --    name belongs to someone else: CREATE OR REPLACE would silently
  --    overwrite it, and a rollback could later drop it. Not done.
  --    To adopt an object after confirming it is the NUHRIS one:
  --      comment on function public.<name>() is 'NUHRIS_HARDENING_OBJECT: adopted';
  select string_agg(x, ', ') into v_bad from (
    select pg_catalog.format('public.%I(%s)', p.proname,
                             pg_catalog.pg_get_function_identity_arguments(p.oid)) as x
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('nuhris_current_employee_id', 'nuhris_current_user_id')
      and coalesce(pg_catalog.obj_description(p.oid, 'pg_proc'), '') not like 'NUHRIS\_HARDENING\_OBJECT:%'
    union all
    select 'public.mobile_app_versions'
    where pg_catalog.to_regclass('public.mobile_app_versions') is not null
      and coalesce(pg_catalog.obj_description(pg_catalog.to_regclass('public.mobile_app_versions'), 'pg_class'), '')
          not like 'NUHRIS\_HARDENING\_OBJECT:%'
  ) s;
  if v_bad is not null then
    raise exception 'ABORT: objects with NUHRIS names exist but were not created by this script (would be overwritten): %', v_bad;
  end if;

  -- n) Configured default privileges granting to PUBLIC (tables or
  --    sequences in any scope, functions in schema public) of an owner the
  --    running role can alter. 3.2d would revoke them, and, as in 3.0g, this
  --    script does not revoke from PUBLIC before someone has established
  --    which role relies on it. Review rls/03a R4 (BLOCKER 3.0n rows), then
  --    revoke the entry manually or record why it stays. PostgreSQL's
  --    built-in global PUBLIC EXECUTE on functions is governed by nuhris_cfg
  --    (05_verify V11) and is not affected by this check.
  select string_agg(distinct pg_catalog.pg_get_userbyid(d.defaclrole) || '@'
                    || coalesce(n.nspname, '(all schemas)') || ':'
                    || case d.defaclobjtype when 'r' then 'tables' when 'S' then 'sequences'
                            else 'functions' end
                    || ':' || a.privilege_type, ', ') into v_bad
  from pg_catalog.pg_default_acl d
  left join pg_catalog.pg_namespace n on n.oid = d.defaclnamespace
  cross join lateral pg_catalog.aclexplode(d.defaclacl) a
  where a.grantee = 0
    and (d.defaclnamespace = 0 or n.nspname = 'public')
    and d.defaclobjtype in ('r','S','f')
    and not (d.defaclnamespace = 0 and d.defaclobjtype = 'f')
    and pg_catalog.pg_has_role(current_user, d.defaclrole, 'USAGE');
  if v_bad is not null then
    raise exception 'ABORT: default privileges grant to PUBLIC (review rls/03a R4, revoke manually): %', v_bad;
  end if;

  -- o) 3.2c restricts EXECUTE only on trigger / event-trigger functions.
  --    Those cannot be called directly ("trigger functions can only be
  --    called as triggers") and EXECUTE is not checked when they fire, so
  --    no role can rely on that EXECUTE. Any other SECURITY DEFINER function
  --    executable through PUBLIC / anon / authenticated may have a caller
  --    that relies on PUBLIC EXECUTE: rls/03a R3 lists the roles that would
  --    lose it. Revoke it manually after that review.
  select string_agg(s.signature, ', ') into v_bad
  from nuhris_secdef_scope s
  join pg_catalog.pg_proc p on p.oid = s.oid
  where p.prorettype not in ('pg_catalog.trigger'::pg_catalog.regtype,
                             'pg_catalog.event_trigger'::pg_catalog.regtype);
  if v_bad is not null then
    raise exception 'ABORT: callable SECURITY DEFINER functions are executable by PUBLIC/anon/authenticated (review rls/03a R3, revoke manually): %', v_bad;
  end if;
end $$;


-- ---------------------------------------------------------------------
-- 3.1 IDENTITY HELPERS
-- SECURITY DEFINER (they must read employees/users/auth.users regardless of
-- RLS) with an EMPTY search_path and fully qualified names, so a caller
-- cannot hijack resolution with objects in another schema.
-- Identity comes only from auth.uid() (the verified JWT subject) and the
-- auth.users row — never from values sent by the client, and not from the
-- JWT email claim (which can be stale for up to the token lifetime).
-- ---------------------------------------------------------------------
create or replace function public.nuhris_current_employee_id()
returns bigint
language sql
stable
security definer
set search_path = ''
as $$
  select e.id
  from public.employees e
  where e.deleted_at is null
    and (
      -- Primary: explicit link.
      e.auth_id::text = (select auth.uid())::text
      -- Transitional fallback (removed by rls/06_remove_email_fallback.sql):
      -- only for employees that are NOT linked yet, and only via the
      -- account's CONFIRMED email. A linked employee can never be claimed
      -- by another account through email.
      or (e.auth_id is null and exists (
            select 1
            from auth.users u
            where u.id = (select auth.uid())
              and u.email_confirmed_at is not null
              and pg_catalog.lower(u.email) = pg_catalog.lower(e.email)))
    )
  order by (e.auth_id is not null) desc, e.id
  limit 1
$$;

-- The users row is derived from the resolved employee (users.email =
-- employees.email is how the web portal links them, e.g.
-- Employee::where('email', $user->email)).
create or replace function public.nuhris_current_user_id()
returns bigint
language sql
stable
security definer
set search_path = ''
as $$
  select pu.id
  from public.users pu
  join public.employees e
    on pg_catalog.lower(e.email) = pg_catalog.lower(pu.email)
  where e.id = public.nuhris_current_employee_id()
  limit 1
$$;

revoke all on function public.nuhris_current_employee_id() from public, anon;
revoke all on function public.nuhris_current_user_id() from public, anon;
grant execute on function public.nuhris_current_employee_id() to authenticated;
grant execute on function public.nuhris_current_user_id() to authenticated;

-- Ownership marker: the generated rollback drops a helper only when it was
-- absent before this script ran AND still carries this marker (3.0m
-- guarantees it is never put on someone else's function).
comment on function public.nuhris_current_employee_id() is
  'NUHRIS_HARDENING_OBJECT: created by docs/security/supabase_rls_hardening.sql';
comment on function public.nuhris_current_user_id() is
  'NUHRIS_HARDENING_OBJECT: created by docs/security/supabase_rls_hardening.sql';


-- ---------------------------------------------------------------------
-- 3.2 DEFAULT DENY for the API roles
-- ---------------------------------------------------------------------

-- 3.2a RLS on every public table. Preconditions 3.0b/c/e/i established
-- that this cannot lock out Laravel (owner / BYPASSRLS) or service_role
-- (BYPASSRLS) and that no foreign permissive policy is left. Tables that
-- get no policy below (sessions, password_reset_tokens, cache, jobs,
-- migrations, admin_configs, admin_audit_logs, academic_calendar_entries,
-- and any other) become deny-all for anon and authenticated.
do $$
declare t record;
begin
  for t in
    select c.relname, c.relrowsecurity
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r','p')
  loop
    if not t.relrowsecurity then
      execute pg_catalog.format('alter table public.%I enable row level security', t.relname);
      raise notice 'RLS enabled on public.%', t.relname;
    end if;
  end loop;
end $$;

-- 3.2b Remove EVERY table, view, column and sequence privilege of anon and
-- authenticated (all 8 table privileges incl. TRUNCATE/REFERENCES/TRIGGER/
-- MAINTAIN, grant options, and column grants). Explicit per object so each
-- one is reported; 3.0h guaranteed every entry outside the allowlist is
-- revocable by the running role. The allowlist is granted back in 3.3–3.4.
do $$
declare r record; v_n int := 0;
begin
  for r in
    select c.relname, c.relkind
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r','p','v','m','f','S')
      and (exists (select 1 from pg_catalog.aclexplode(c.relacl) a
                   where a.grantee in ('anon'::regrole::oid, 'authenticated'::regrole::oid))
           or exists (select 1 from pg_catalog.pg_attribute att
                      cross join lateral pg_catalog.aclexplode(att.attacl) a
                      where att.attrelid = c.oid and att.attnum > 0 and not att.attisdropped
                        and a.grantee in ('anon'::regrole::oid, 'authenticated'::regrole::oid)))
    order by c.relname
  loop
    execute pg_catalog.format('revoke all on %s public.%I from anon, authenticated',
                              case when r.relkind = 'S' then 'sequence' else 'table' end, r.relname);
    v_n := v_n + 1;
  end loop;
  raise notice '3.2b: revoked all anon/authenticated privileges on % relations/sequences', v_n;

  -- Column grants are normally removed with the table-level REVOKE above.
  -- Any column entry still present was granted by another grantor; remove
  -- it column by column (it is reported; 3.6 aborts if one survives).
  for r in
    select distinct c.relname, att.attname
    from pg_catalog.pg_attribute att
    join pg_catalog.pg_class c on c.oid = att.attrelid
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    cross join lateral pg_catalog.aclexplode(att.attacl) a
    where n.nspname = 'public' and att.attnum > 0 and not att.attisdropped
      and a.grantee in ('anon'::regrole::oid, 'authenticated'::regrole::oid)
  loop
    execute pg_catalog.format('revoke all (%I) on table public.%I from anon, authenticated',
                              r.attname, r.relname);
    raise notice '3.2b: column-level revoke on public.%.%', r.relname, r.attname;
  end loop;
end $$;

-- 3.2c SECURITY DEFINER trigger functions (e.g.
-- enqueue_announcement_notifications, owned by postgres, granted to
-- PUBLIC/anon/authenticated): revoke EXECUTE from PUBLIC, anon and
-- authenticated. Nothing is dropped or redefined. 3.0o limited the scope
-- to trigger / event-trigger functions, which no role can call directly,
-- so no caller can rely on this EXECUTE; they keep firing because EXECUTE
-- is not checked when a trigger fires (3.0l also proved no policy, default,
-- view or API-callable function uses them). Backend roles that held EXECUTE (Laravel's role, postgres,
-- service_role — baseline 3.00) get it back explicitly if they lost it.
do $$
declare f record; p record;
begin
  for f in select * from nuhris_secdef_scope order by signature loop
    execute pg_catalog.format('revoke execute on function %s from public, anon, authenticated',
                              f.signature);
    raise notice '3.2c: EXECUTE revoked from public, anon, authenticated on %', f.signature;
    for p in
      select distinct b.role_name from nuhris_protected_before b
      where b.kind = 'function' and b.obj = f.oid
    loop
      if not pg_catalog.has_function_privilege(p.role_name, f.oid, 'EXECUTE') then
        execute pg_catalog.format('grant execute on function %s to %I', f.signature, p.role_name);
        raise notice '3.2c: EXECUTE preserved for backend role % on %', p.role_name, f.signature;
      end if;
    end loop;
  end loop;
end $$;

-- 3.2d Default privileges for FUTURE objects. For every role that has
-- default ACL entries for anon / authenticated / PUBLIC (globally or in
-- schema public) for tables, sequences or functions — plus postgres
-- (Laravel migrations, SQL editor) always — remove them, if the running
-- role may alter that role's defaults (it needs that role's privileges).
-- Schema-level entries and global entries are both removed: a schema-level
-- REVOKE cannot remove a global grant. Grants to service_role are kept.
-- Owners that cannot be altered (e.g. supabase_admin) are NOT changed and
-- are reported as a WARNING; 05_verify reports them as BLOCKED.
do $$
declare
  r record;
  v_blocked text;
  v_public_fn constant boolean := (select revoke_public_function_default from nuhris_cfg);
begin
  for r in
    select distinct d.defaclrole as roleid, pg_catalog.pg_get_userbyid(d.defaclrole) as rolname
    from pg_catalog.pg_default_acl d
    left join pg_catalog.pg_namespace n on n.oid = d.defaclnamespace
    cross join lateral pg_catalog.aclexplode(d.defaclacl) a
    where (d.defaclnamespace = 0 or n.nspname = 'public')
      and d.defaclobjtype in ('r','S','f')
      and a.grantee in (0, 'anon'::regrole::oid, 'authenticated'::regrole::oid)
    union
    select oid, rolname from pg_catalog.pg_roles where rolname = 'postgres'
    order by 2
  loop
    if not pg_catalog.pg_has_role(current_user, r.roleid, 'USAGE') then
      v_blocked := coalesce(v_blocked || ', ', '') || r.rolname;
      continue;
    end if;
    execute pg_catalog.format('alter default privileges for role %I in schema public revoke all on tables from anon, authenticated, public', r.rolname);
    execute pg_catalog.format('alter default privileges for role %I in schema public revoke all on sequences from anon, authenticated, public', r.rolname);
    execute pg_catalog.format('alter default privileges for role %I in schema public revoke all on functions from anon, authenticated, public', r.rolname);
    execute pg_catalog.format('alter default privileges for role %I revoke all on tables from anon, authenticated, public', r.rolname);
    execute pg_catalog.format('alter default privileges for role %I revoke all on sequences from anon, authenticated, public', r.rolname);
    execute pg_catalog.format('alter default privileges for role %I revoke all on functions from anon, authenticated', r.rolname);
    if v_public_fn then
      -- Opt-in (nuhris_cfg): removes PostgreSQL's built-in PUBLIC EXECUTE
      -- for every function this role creates, in every schema.
      execute pg_catalog.format('alter default privileges for role %I revoke execute on functions from public', r.rolname);
    end if;
    raise notice '3.2d: default privileges of % no longer expose new tables/sequences/functions to anon/authenticated%',
      r.rolname, case when v_public_fn then '/PUBLIC' else ' (built-in PUBLIC EXECUTE on functions kept)' end;
  end loop;
  if v_blocked is not null then
    raise warning '3.2d BLOCKED, NOT FIXED: % cannot alter the default privileges of: %. Every future table/sequence/function they create in public is still granted to anon/authenticated. The audit stays open until that owner (Supabase support for supabase_admin) revokes them (05_verify V10).',
      current_user, v_blocked;
  end if;
end $$;


-- ---------------------------------------------------------------------
-- 3.3 READ ACCESS — own rows, only the columns the app uses
-- (column lists = lib/services/api_client.dart; never password,
-- remember_token, phone, address)
-- `(select fn())` lets Postgres evaluate the helper once per query.
-- ---------------------------------------------------------------------
grant select (id, name, email, user_type) on public.users to authenticated;
drop policy if exists nuhris_self_select on public.users;
create policy nuhris_self_select on public.users
  for select to authenticated
  using (id = (select public.nuhris_current_user_id()));

grant select (id, employee_id, first_name, last_name, email, department_id,
              position, employment_type, ranking, status, hire_date,
              official_time_in, official_time_out, auth_id,
              profilephoto_path, deleted_at)
  on public.employees to authenticated;
drop policy if exists nuhris_self_select on public.employees;
create policy nuhris_self_select on public.employees
  for select to authenticated
  using (id = (select public.nuhris_current_employee_id()));

-- Department names are not personal data.
grant select (id, name) on public.departments to authenticated;
drop policy if exists nuhris_read on public.departments;
create policy nuhris_read on public.departments
  for select to authenticated using (true);

do $$
declare t text;
begin
  foreach t in array array[
    'attendance_records', 'leave_balances', 'leave_requests',
    'employee_credentials', 'employee_schedule_submissions',
    'wfh_monitoring_submissions'
  ] loop
    execute pg_catalog.format('grant select on public.%I to authenticated', t);
    execute pg_catalog.format('drop policy if exists nuhris_own_select on public.%I', t);
    execute pg_catalog.format(
      'create policy nuhris_own_select on public.%I for select to authenticated
         using (employee_id = (select public.nuhris_current_employee_id()))', t);
  end loop;
end $$;

grant select on public.employee_schedule_days to authenticated;
drop policy if exists nuhris_own_select on public.employee_schedule_days;
create policy nuhris_own_select on public.employee_schedule_days
  for select to authenticated
  using (exists (
    select 1 from public.employee_schedule_submissions s
    where s.id = employee_schedule_days.schedule_submission_id
      and s.employee_id = (select public.nuhris_current_employee_id())));


-- ---------------------------------------------------------------------
-- 3.4 WRITES — exactly what the app sends, nothing more.
-- Column-level INSERT grants make review fields (reviewed_by, reviewed_at,
-- review_notes, monitoring_link, ...) impossible to supply; the policies
-- re-check them anyway (defence in depth). No UPDATE/DELETE on records.
-- ---------------------------------------------------------------------

-- Schedule submission header (app: submitEmployeeSchedule).
grant insert (employee_id, submitted_by, semester_label, term_label,
              status, submitted_at, is_current)
  on public.employee_schedule_submissions to authenticated;
drop policy if exists nuhris_own_insert on public.employee_schedule_submissions;
create policy nuhris_own_insert on public.employee_schedule_submissions
  for insert to authenticated
  with check (
    employee_id  = (select public.nuhris_current_employee_id())
    and submitted_by = (select public.nuhris_current_user_id())
    and status = 'pending'
    and is_current = false
    and reviewed_by is null
    and reviewed_at is null
    and review_notes is null);

-- Schedule days: only into the employee's own, still-pending, unreviewed
-- submission; Monday–Saturday (ISO 1–6) like the web's `between:1,6`.
grant insert (schedule_submission_id, day_name, day_index, has_work,
              time_in, time_out)
  on public.employee_schedule_days to authenticated;
drop policy if exists nuhris_own_insert on public.employee_schedule_days;
create policy nuhris_own_insert on public.employee_schedule_days
  for insert to authenticated
  with check (
    day_index between 1 and 6
    and exists (
      select 1 from public.employee_schedule_submissions s
      where s.id = employee_schedule_days.schedule_submission_id
        and s.employee_id = (select public.nuhris_current_employee_id())
        and s.status = 'pending'
        and s.reviewed_at is null));

-- WFH submission (app: submitWfhMonitoring). The file must be one the
-- employee uploaded to their own folder, in the exact layout the app and
-- web generate: employee-<id>/wfh-monitoring/<unix time>_<8 hex>.<ext>.
grant insert (employee_id, submitted_by, wfh_date, time_in, time_out,
              file_path, original_filename, status, submitted_at,
              created_at, updated_at)
  on public.wfh_monitoring_submissions to authenticated;
drop policy if exists nuhris_own_insert on public.wfh_monitoring_submissions;
create policy nuhris_own_insert on public.wfh_monitoring_submissions
  for insert to authenticated
  with check (
    employee_id  = (select public.nuhris_current_employee_id())
    and submitted_by = (select public.nuhris_current_user_id())
    and status = 'pending'
    and reviewed_by is null
    and reviewed_at is null
    and review_notes is null
    and time_in is not null and time_out is not null and time_out > time_in
    and file_path ~ ('^employee-' || (select public.nuhris_current_employee_id())::text
                     || '/wfh-monitoring/[0-9]{9,11}_[0-9a-f]{8}\.(pdf|jpg|png)$'));

-- Notifications: read own, mark read (two columns only), clear own.
grant select on public.announcement_notifications to authenticated;
grant update (is_read, read_at) on public.announcement_notifications to authenticated;
grant delete on public.announcement_notifications to authenticated;
drop policy if exists nuhris_own_select on public.announcement_notifications;
drop policy if exists nuhris_own_update on public.announcement_notifications;
drop policy if exists nuhris_own_delete on public.announcement_notifications;
create policy nuhris_own_select on public.announcement_notifications
  for select to authenticated
  using (user_id = (select public.nuhris_current_user_id()));
create policy nuhris_own_update on public.announcement_notifications
  for update to authenticated
  using (user_id = (select public.nuhris_current_user_id()))
  with check (user_id = (select public.nuhris_current_user_id()));
create policy nuhris_own_delete on public.announcement_notifications
  for delete to authenticated
  using (user_id = (select public.nuhris_current_user_id()));

-- Announcements the employee received a notification for (the app reads
-- announcements only through its notifications).
grant select on public.announcements to authenticated;
drop policy if exists nuhris_notified_select on public.announcements;
create policy nuhris_notified_select on public.announcements
  for select to authenticated
  using (exists (
    select 1 from public.announcement_notifications n
    where n.announcement_id = announcements.id
      and n.user_id = (select public.nuhris_current_user_id())));

-- Privacy Notice acknowledgment (same record the web writes).
grant select (id, user_id, privacy_notice_version, acknowledged_at)
  on public.privacy_notice_acknowledgments to authenticated;
grant insert (user_id, privacy_notice_version, acknowledged_at, created_at, updated_at)
  on public.privacy_notice_acknowledgments to authenticated;
grant update (acknowledged_at, updated_at)
  on public.privacy_notice_acknowledgments to authenticated;
drop policy if exists nuhris_own_select on public.privacy_notice_acknowledgments;
drop policy if exists nuhris_own_insert on public.privacy_notice_acknowledgments;
drop policy if exists nuhris_own_update on public.privacy_notice_acknowledgments;
create policy nuhris_own_select on public.privacy_notice_acknowledgments
  for select to authenticated
  using (user_id = (select public.nuhris_current_user_id()));
create policy nuhris_own_insert on public.privacy_notice_acknowledgments
  for insert to authenticated
  with check (user_id = (select public.nuhris_current_user_id()));
create policy nuhris_own_update on public.privacy_notice_acknowledgments
  for update to authenticated
  using (user_id = (select public.nuhris_current_user_id()))
  with check (user_id = (select public.nuhris_current_user_id()));

-- Id sequences used by those inserts.
do $$
declare t text; seq text;
begin
  foreach t in array array[
    'employee_schedule_submissions', 'employee_schedule_days',
    'wfh_monitoring_submissions', 'privacy_notice_acknowledgments'
  ] loop
    seq := pg_catalog.pg_get_serial_sequence('public.' || t, 'id');
    if seq is null then
      raise exception 'ABORT: no id sequence found for %', t;
    end if;
    execute pg_catalog.format('grant usage on sequence %s to authenticated', seq);
  end loop;
end $$;


-- ---------------------------------------------------------------------
-- 3.5 MINIMUM-VERSION POLICY (app update enforcement)
-- Readable before login; writable only by the owner / service_role.
-- ---------------------------------------------------------------------
create table if not exists public.mobile_app_versions (
  platform            text primary key,
  min_version_code    integer not null check (min_version_code > 0),
  latest_version_name text,
  update_url          text check (update_url is null or update_url like 'https://%'),
  message             text,
  updated_at          timestamptz not null default now()
);
comment on table public.mobile_app_versions is
  'NUHRIS_HARDENING_OBJECT: created by docs/security/supabase_rls_hardening.sql';
alter table public.mobile_app_versions enable row level security;
grant select on public.mobile_app_versions to anon, authenticated;
drop policy if exists nuhris_read on public.mobile_app_versions;
create policy nuhris_read on public.mobile_app_versions
  for select to anon, authenticated using (true);

-- versionCode 2 = app 1.1.0+2 (first release with these fixes). Set
-- update_url to the HTTPS page where employees get the official APK.
insert into public.mobile_app_versions (platform, min_version_code, latest_version_name, update_url)
values ('android', 2, '1.1.0', null)
on conflict (platform) do nothing;


-- ---------------------------------------------------------------------
-- 3.6 SELF-CHECK before commit (abort if the result is not as intended)
-- Covers EVERY table, view, column, sequence and function in schema
-- public, using the EFFECTIVE privileges of anon and authenticated:
-- has_table_privilege / has_column_privilege / has_sequence_privilege /
-- has_function_privilege resolve direct grants, PUBLIC grants, inherited
-- role memberships and ownership. Anything beyond the allowlist in 3.00
-- (same rows as rls/03a and 05_verify) aborts. So does any backend role
-- (Laravel, postgres, service_role) losing a privilege it had at 3.00.
-- ---------------------------------------------------------------------
do $$
declare v_bad text;
begin
  with
  api_roles(role_name) as (values ('anon'::name), ('authenticated'::name)),
  rels as (
    select c.oid, c.relname from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r','p','v','m','f')
  ),
  seqs as (
    select c.oid, c.relname from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'S'
  ),
  sequence_allow as (
    select sa.role_name,
           pg_catalog.to_regclass(pg_catalog.pg_get_serial_sequence('public.' || sa.table_name, 'id'))::oid as seq_oid,
           sa.privilege
    from nuhris_sequence_allow sa
  ),
  tprivs as (
    -- MAINTAIN exists from PostgreSQL 17; only tested where the server has it.
    select v.privilege
    from (values ('SELECT'),('INSERT'),('UPDATE'),('DELETE'),('TRUNCATE'),
                 ('REFERENCES'),('TRIGGER'),('MAINTAIN')) v(privilege)
    where v.privilege <> 'MAINTAIN'
       or pg_catalog.current_setting('server_version_num')::int >= 170000
  ),
  violations as (
    select r.role_name || ' ' || p.privilege || ' on ' || t.relname as v
    from api_roles r cross join rels t cross join tprivs p
    where pg_catalog.has_table_privilege(r.role_name, t.oid, p.privilege)
      and not exists (select 1 from nuhris_table_allow a
                      where a.role_name = r.role_name and a.table_name = t.relname
                        and a.privilege = p.privilege)
    union all
    select r.role_name || ' ' || p.privilege || ' on ' || t.relname || '.' || att.attname
    from api_roles r cross join rels t
    join pg_catalog.pg_attribute att
      on att.attrelid = t.oid and att.attnum > 0 and not att.attisdropped
    cross join (values ('SELECT'),('INSERT'),('UPDATE'),('REFERENCES')) p(privilege)
    where pg_catalog.has_column_privilege(r.role_name, t.oid, att.attnum, p.privilege)
      and not exists (select 1 from nuhris_table_allow a
                      where a.role_name = r.role_name and a.table_name = t.relname
                        and a.privilege = p.privilege)
      and not exists (select 1 from nuhris_column_allow ca
                      where ca.role_name = r.role_name and ca.table_name = t.relname
                        and ca.privilege = p.privilege
                        and att.attname::text = any (ca.columns))
    union all
    select r.role_name || ' ' || p.privilege || ' on sequence ' || s.relname
    from api_roles r cross join seqs s
    cross join (values ('USAGE'),('SELECT'),('UPDATE')) p(privilege)
    where pg_catalog.has_sequence_privilege(r.role_name, s.oid, p.privilege)
      and not exists (select 1 from sequence_allow sa
                      where sa.role_name = r.role_name and sa.seq_oid = s.oid
                        and sa.privilege = p.privilege)
    union all
    -- No API role may hold a grant option (it could re-grant).
    select pg_catalog.pg_get_userbyid(a.grantee) || ' ' || a.privilege_type
           || ' WITH GRANT OPTION on ' || c.relname
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    cross join lateral pg_catalog.aclexplode(c.relacl) a
    where n.nspname = 'public' and a.is_grantable
      and a.grantee in ('anon'::regrole::oid, 'authenticated'::regrole::oid)
    union all
    select r.role_name || ' CREATE on schema public'
    from api_roles r
    where pg_catalog.has_schema_privilege(r.role_name, 'public', 'CREATE')
    union all
    -- SECURITY DEFINER functions run as their owner (RLS does not apply to
    -- the owner): no API role may execute one, except authenticated on the
    -- two NUHRIS policy helpers.
    select r.role_name || ' EXECUTE on SECURITY DEFINER function ' || pr.proname
           || '(' || pg_catalog.pg_get_function_identity_arguments(pr.oid) || ')'
    from api_roles r
    cross join pg_catalog.pg_proc pr
    join pg_catalog.pg_namespace pn on pn.oid = pr.pronamespace
    where pn.nspname = 'public' and pr.prosecdef
      and pg_catalog.has_function_privilege(r.role_name, pr.oid, 'EXECUTE')
      and not (r.role_name = 'authenticated'
               and pr.proname in ('nuhris_current_employee_id', 'nuhris_current_user_id'))
  )
  select string_agg(v, '; ' order by v) into v_bad from violations;
  if v_bad is not null then
    raise exception 'ABORT: API roles hold privileges beyond the allowlist: %', v_bad;
  end if;

  -- Backend roles keep every privilege they had before this script.
  select string_agg(b.role_name || ' ' || b.privilege || ' on ' || b.kind || ' '
                    || case when b.kind = 'function' then b.obj::pg_catalog.regprocedure::text
                            else b.obj::pg_catalog.regclass::text end
                    || case when b.kind = 'column'
                            then '.' || (select attname from pg_catalog.pg_attribute
                                         where attrelid = b.obj and attnum = b.attnum)
                            else '' end, '; ') into v_bad
  from nuhris_protected_before b
  where not case b.kind
              when 'table'    then pg_catalog.has_table_privilege(b.role_name, b.obj, b.privilege)
              when 'column'   then pg_catalog.has_column_privilege(b.role_name, b.obj, b.attnum::int2, b.privilege)
              when 'sequence' then pg_catalog.has_sequence_privilege(b.role_name, b.obj, b.privilege)
              when 'function' then pg_catalog.has_function_privilege(b.role_name, b.obj, b.privilege)
            end;
  if v_bad is not null then
    raise exception 'ABORT: backend roles would lose access they have today: %', v_bad;
  end if;

  -- Every public table has RLS on.
  select string_agg(c.relname, ', ') into v_bad
  from pg_catalog.pg_class c
  join pg_catalog.pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind in ('r','p') and not c.relrowsecurity;
  if v_bad is not null then
    raise exception 'ABORT: RLS disabled on: %', v_bad;
  end if;

  -- Future objects: for every role whose defaults the running role may
  -- alter, no default may grant tables, sequences or functions to anon /
  -- authenticated / PUBLIC (globally or in public). Only exception: the
  -- GLOBAL PUBLIC EXECUTE on functions while nuhris_cfg keeps it (V11).
  select string_agg(pg_catalog.pg_get_userbyid(d.defaclrole) || '@'
                    || coalesce(n.nspname, '(all schemas)') || ':' || d.defaclobjtype::text
                    || ':' || case when a.grantee = 0 then 'PUBLIC'
                                   else pg_catalog.pg_get_userbyid(a.grantee) end
                    || ':' || a.privilege_type, ', ') into v_bad
  from pg_catalog.pg_default_acl d
  left join pg_catalog.pg_namespace n on n.oid = d.defaclnamespace
  cross join lateral pg_catalog.aclexplode(d.defaclacl) a
  where pg_catalog.pg_has_role(current_user, d.defaclrole, 'USAGE')
    and (d.defaclnamespace = 0 or n.nspname = 'public')
    and d.defaclobjtype in ('r','S','f')
    and a.grantee in (0, 'anon'::regrole::oid, 'authenticated'::regrole::oid)
    and not (d.defaclnamespace = 0 and d.defaclobjtype = 'f' and a.grantee = 0
             and not (select revoke_public_function_default from nuhris_cfg));
  if v_bad is not null then
    raise exception 'ABORT: default privileges still expose new objects: %', v_bad;
  end if;

  -- Information: tables that are now deny-all for the API roles (RLS on,
  -- no policy). Expected for Laravel-only tables (sessions, jobs, ...).
  select string_agg(c.relname, ', ' order by c.relname) into v_bad
  from pg_catalog.pg_class c
  join pg_catalog.pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind in ('r','p') and c.relrowsecurity
    and not exists (select 1 from pg_catalog.pg_policy p where p.polrelid = c.oid);
  if v_bad is not null then
    raise notice '3.6: deny-all for anon/authenticated (RLS on, no policy): %', v_bad;
  end if;
end $$;

commit;


-- ---------------------------------------------------------------------
-- 3.7 RESULT (read-only, after commit). The Supabase SQL editor shows only
-- the last result, so this row — not "Success" — is what the operator sees.
-- It is computed from the catalog, so it also reads NOT APPLIED when the
-- transaction above was rolled back (e.g. psql without ON_ERROR_STOP).
-- Committing is NOT proof of security: only rls/05_verify.sql decides.
-- ---------------------------------------------------------------------
with
applied as (
  select exists (
           select 1 from pg_catalog.pg_proc p
           join pg_catalog.pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname = 'nuhris_current_employee_id'
             and pg_catalog.obj_description(p.oid, 'pg_proc') like 'NUHRIS\_HARDENING\_OBJECT:%')
     and exists (select 1 from pg_catalog.pg_policy p
                 where p.polrelid = pg_catalog.to_regclass('public.employees')
                   and p.polname = 'nuhris_self_select')
     and not exists (select 1 from pg_catalog.pg_class c
                     join pg_catalog.pg_namespace n on n.oid = c.relnamespace
                     where n.nspname = 'public' and c.relkind in ('r','p')
                       and not c.relrowsecurity) as ok
),
blocked as (
  select pg_catalog.string_agg(distinct pg_catalog.pg_get_userbyid(d.defaclrole), ', ') as owners
  from pg_catalog.pg_default_acl d
  left join pg_catalog.pg_namespace n on n.oid = d.defaclnamespace
  cross join lateral pg_catalog.aclexplode(d.defaclacl) a
  where (d.defaclnamespace = 0 or n.nspname = 'public')
    and d.defaclobjtype in ('r','S','f')
    and not pg_catalog.pg_has_role(current_user, d.defaclrole, 'USAGE')
    and (a.grantee in ('anon'::regrole::oid, 'authenticated'::regrole::oid)
         or (a.grantee = 0 and not (d.defaclnamespace = 0 and d.defaclobjtype = 'f')))
)
select case
         when not applied.ok then 'NOT APPLIED: the transaction was rolled back; see the ABORT message'
         when blocked.owners is not null
           then 'APPLIED, NOT SECURE: BLOCKED (default privileges of ' || blocked.owners || ' still expose future objects)'
         else 'APPLIED: run rls/05_verify.sql; only its OVERALL row decides whether the audit is fixed'
       end as hardening_result,
       blocked.owners as blocked_default_privilege_owners
from applied, blocked;
