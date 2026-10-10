-- =====================================================================
-- PHASE 2b — PRIVILEGE REMEDIATION REVIEW for PUBLIC, anon, authenticated
--            (READ-ONLY: this file only SELECTs and returns text)
-- =====================================================================
-- Shows, BEFORE anything is applied, exactly what supabase_rls_hardening.sql
-- (PHASE 3) will do to every explicit privilege held by PUBLIC, anon and
-- authenticated in schema public, and what it CANNOT do:
--
--   R1  owners of objects in public; which ones the running role can act for
--   R2  explicit table / view / column / sequence ACL entries, with grantor,
--       whether the running role can revoke them, and the planned action
--   R3  functions: EXECUTE source (explicit ACL vs built-in default),
--       SECURITY DEFINER, search_path, dependents, roles that would lose
--       EXECUTE without PUBLIC, planned action
--   R4  default privileges for FUTURE objects, per owner, with can_alter
--   R5  PUBLIC grants: risk and Laravel impact (expected: no rows)
--   R6  summary counts per planned action
--
-- Run each query on its own (the Supabase SQL editor shows only the LAST
-- result) as the role that will run PHASE 3 (postgres). Any row whose
-- planned action starts with BLOCKER must be resolved first: PHASE 3
-- aborts on it (3.0g / 3.0h / 3.0l / 3.0n / 3.0o) rather than skipping it.
-- PHASE 3 never revokes anything from PUBLIC on its own initiative except
-- EXECUTE on SECURITY DEFINER trigger functions (no role can call those).
--
-- Why explicit grants matter even with RLS on:
--   * RLS filters ROWS. A table-level SELECT lets authenticated read columns
--     PHASE 3 withholds (users.password, employees.phone/address) of its own
--     row, defeating the column-level grants.
--   * Views / materialized views run with their owner's rights and bypass
--     the base tables' RLS (unless security_invoker): any grant exposes all
--     rows.
--   * TRUNCATE, REFERENCES, TRIGGER and MAINTAIN are not limited by RLS.
--   * Sequences are not subject to RLS: UPDATE allows setval() (can break
--     inserts), USAGE allows nextval(), SELECT reveals last_value.
--   * SECURITY DEFINER functions run as their owner (bypassing RLS when the
--     owner owns the tables or has BYPASSRLS).
-- =====================================================================


-- R1. Owners of objects in schema public. "acts_as_owner" = the running
--     role has the owner's privileges, so it can revoke the owner's grants
--     and alter the owner's default privileges. Expect: Laravel's role
--     (postgres) owns every HR table/sequence; any other owner is reviewed.
with owned as (
  select c.relowner as owner_oid,
         case c.relkind when 'r' then 'table' when 'p' then 'partitioned table'
              when 'v' then 'view' when 'm' then 'matview' when 'S' then 'sequence'
              when 'f' then 'foreign table' end as kind
  from pg_catalog.pg_class c
  join pg_catalog.pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind in ('r','p','v','m','S','f')
  union all
  select p.proowner, case when p.prosecdef then 'function (SECURITY DEFINER)' else 'function' end
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
)
select pg_catalog.pg_get_userbyid(o.owner_oid) as owner,
       pg_catalog.string_agg(o.kind || ':' || o.cnt, ', ' order by o.kind) as owns_in_public,
       r.rolsuper, r.rolbypassrls,
       pg_catalog.pg_has_role(current_user, o.owner_oid, 'USAGE') as acts_as_owner,
       pg_catalog.pg_has_role(current_user, o.owner_oid, 'USAGE') as can_alter_default_privileges
from (select owner_oid, kind, count(*) as cnt from owned group by 1, 2) o
join pg_catalog.pg_roles r on r.oid = o.owner_oid
group by o.owner_oid, r.rolsuper, r.rolbypassrls
order by 1;


-- R2. Every explicit ACL entry held by PUBLIC, anon or authenticated on a
--     public-schema table, view, matview, foreign table, partitioned table,
--     column or sequence. Only entries stored in relacl / attacl are listed
--     (a NULL ACL means "owner only" for relations: nothing to report;
--     acldefault() is never used here, so there are no false positives).
--     revocable_by_current_role: a non-superuser REVOKE removes only entries
--     whose grantor it acts as (the owner if it has the owner's privileges,
--     otherwise a grantor role it has privileges of).
with
-- BEGIN-ALLOWLIST-COPY (identical rows in supabase_rls_hardening.sql 3.00
-- and 05_verify.sql; checked by tool/check_rls_allowlists.sh)
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
ents as (
  select 'object'::text as level, c.oid as relid, c.relname, c.relkind, c.relowner,
         null::name as attname, a.grantor, a.grantee, a.privilege_type, a.is_grantable
  from pg_catalog.pg_class c
  join pg_catalog.pg_namespace n on n.oid = c.relnamespace
  cross join lateral pg_catalog.aclexplode(c.relacl) a
  where n.nspname = 'public' and c.relkind in ('r','p','v','m','f','S')
    and (a.grantee = 0 or pg_catalog.pg_get_userbyid(a.grantee) in ('anon','authenticated'))
  union all
  select 'column', c.oid, c.relname, c.relkind, c.relowner,
         att.attname, a.grantor, a.grantee, a.privilege_type, a.is_grantable
  from pg_catalog.pg_attribute att
  join pg_catalog.pg_class c on c.oid = att.attrelid
  join pg_catalog.pg_namespace n on n.oid = c.relnamespace
  cross join lateral pg_catalog.aclexplode(att.attacl) a
  where n.nspname = 'public' and att.attnum > 0 and not att.attisdropped
    and (a.grantee = 0 or pg_catalog.pg_get_userbyid(a.grantee) in ('anon','authenticated'))
),
classified as (
  select e.*,
         case when e.grantee = 0 then 'PUBLIC' else pg_catalog.pg_get_userbyid(e.grantee) end as grantee_name,
         case when pg_catalog.pg_has_role(current_user, e.relowner, 'USAGE')
              then e.grantor = e.relowner
              else pg_catalog.pg_has_role(current_user, e.grantor, 'USAGE') end as revocable,
         case
           when e.relkind = 'S' then exists (
             select 1 from seq_allow sa
             where sa.role_name = pg_catalog.pg_get_userbyid(e.grantee)
               and sa.seq_oid = e.relid and sa.privilege = e.privilege_type)
           else exists (
             select 1 from table_allow ta
             where ta.role_name = pg_catalog.pg_get_userbyid(e.grantee)
               and ta.table_name = e.relname and ta.privilege = e.privilege_type)
             or (e.attname is not null and exists (
             select 1 from column_allow ca
             where ca.role_name = pg_catalog.pg_get_userbyid(e.grantee)
               and ca.table_name = e.relname and ca.privilege = e.privilege_type
               and e.attname::text = any (ca.columns)))
         end as allowlisted
  from ents e
)
select * from (
select level,
       case relkind when 'S' then 'sequence' when 'v' then 'view' when 'm' then 'matview'
                    when 'f' then 'foreign table' when 'p' then 'partitioned table'
                    else 'table' end as kind,
       relname as object, attname as column_name, grantee_name as grantee,
       privilege_type, is_grantable,
       pg_catalog.pg_get_userbyid(grantor)  as grantor,
       pg_catalog.pg_get_userbyid(relowner) as owner,
       'explicit ACL entry' as source,
       revocable as revocable_by_current_role,
       allowlisted as retained_after_phase3,
       case
         when grantee = 0
           then 'BLOCKER (3.0g): PUBLIC grant; review the R5 row, then revoke it manually'
         when not revocable and not allowlisted
           then 'BLOCKER (3.0h): granted by ' || pg_catalog.pg_get_userbyid(grantor)
                || '; only that role (or the owner, with CASCADE) can revoke it'
         when not revocable
           then 'KEEP: outside the running role''s control, but within the allowlist'
         when allowlisted and not is_grantable
           then 'REVOKE (3.2b), then RE-GRANT (3.3/3.4: the app needs it)'
         when allowlisted
           then 'REVOKE (3.2b), then RE-GRANT without grant option (3.3/3.4)'
         else 'REVOKE (3.2b)'
       end as planned_action
from classified
) r
order by (planned_action like 'BLOCKER%') desc, grantee, object, column_name, privilege_type;


-- R3. Functions in schema public that PUBLIC, anon or authenticated can
--     EXECUTE, and every SECURITY DEFINER function. PostgREST exposes
--     callable functions as /rest/v1/rpc/<name>.
--     acl_source distinguishes a stored ACL ("explicit ACL") from proacl
--     IS NULL ("built-in default": EXECUTE to PUBLIC implied, not granted).
with fn as (
  select p.oid, p.proname, p.prosecdef, p.proowner, p.proacl, p.proconfig, p.prorettype,
         pg_catalog.format('public.%I(%s)', p.proname,
                           pg_catalog.pg_get_function_identity_arguments(p.oid)) as signature,
         p.prorettype = 'pg_catalog.trigger'::pg_catalog.regtype as is_trigger,
         (select e.extname from pg_catalog.pg_depend d
          join pg_catalog.pg_extension e on e.oid = d.refobjid
          where d.classid = 'pg_catalog.pg_proc'::pg_catalog.regclass
            and d.objid = p.oid and d.deptype = 'e' limit 1) as extension
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
),
a as (
  select f.*,
    case when f.proacl is null then 'built-in default (proacl NULL): PUBLIC EXECUTE implied'
         else 'explicit ACL' end as acl_source,
    (select pg_catalog.string_agg(
              case when x.grantee = 0 then 'PUBLIC' else pg_catalog.pg_get_userbyid(x.grantee) end
              || case when x.is_grantable then '*' else '' end
              || ' (by ' || pg_catalog.pg_get_userbyid(x.grantor) || ')', ', ')
     from pg_catalog.aclexplode(f.proacl) x
     where x.privilege_type = 'EXECUTE') as explicit_execute_grantees,
    pg_catalog.has_function_privilege('anon', f.oid, 'EXECUTE')          as anon_exec,
    pg_catalog.has_function_privilege('authenticated', f.oid, 'EXECUTE') as auth_exec,
    (select s from pg_catalog.unnest(f.proconfig) s where s like 'search\_path=%') as search_path,
    pg_catalog.pg_has_role(current_user, f.proowner, 'USAGE') as acts_as_owner,
    (select pg_catalog.string_agg(t.tgrelid::pg_catalog.regclass::text || '.' || t.tgname, ', ')
     from pg_catalog.pg_trigger t where t.tgfoid = f.oid and not t.tgisinternal) as used_by_triggers,
    (select pg_catalog.string_agg(pg_catalog.pg_describe_object(d.classid, d.objid, d.objsubid), ', ')
     from pg_catalog.pg_depend d
     where d.refclassid = 'pg_catalog.pg_proc'::pg_catalog.regclass and d.refobjid = f.oid
       and d.classid <> 'pg_catalog.pg_trigger'::pg_catalog.regclass and d.deptype = 'n') as used_by_other_objects,
    (select pg_catalog.string_agg(p2.proname, ', ')
     from pg_catalog.pg_proc p2
     join pg_catalog.pg_namespace n2 on n2.oid = p2.pronamespace
     where n2.nspname = 'public' and p2.oid <> f.oid
       and p2.prosrc ~ ('\m' || f.proname || '\M')) as mentioned_in_functions,
    -- Non-superuser roles (other than anon/authenticated) that can EXECUTE
    -- the function today ONLY through PUBLIC / anon / authenticated: they
    -- would lose it if those grants were revoked. postgres, service_role and
    -- the Laravel role are re-granted by 3.2c; any other role listed here is
    -- a caller to confirm or rule out before a manual revoke.
    (select pg_catalog.string_agg(r.rolname, ', ' order by r.rolname)
     from pg_catalog.pg_roles r
     where r.rolname not in ('anon', 'authenticated')
       and r.rolname not like 'pg\_%'
       and not r.rolsuper
       and pg_catalog.has_function_privilege(r.oid, f.oid, 'EXECUTE')
       and not pg_catalog.pg_has_role(r.oid, f.proowner, 'USAGE')
       and not exists (select 1 from pg_catalog.aclexplode(f.proacl) x
                       where x.grantee <> 0 and x.privilege_type = 'EXECUTE'
                         and pg_catalog.pg_get_userbyid(x.grantee) not in ('anon', 'authenticated')
                         and pg_catalog.pg_has_role(r.oid, x.grantee, 'USAGE'))) as roles_relying_on_public_execute
  from fn f
)
select * from (
select signature, prosecdef as security_definer,
       pg_catalog.pg_get_userbyid(proowner) as owner, acts_as_owner,
       is_trigger, extension, search_path, acl_source, explicit_execute_grantees,
       anon_exec, auth_exec, used_by_triggers, used_by_other_objects, mentioned_in_functions,
       roles_relying_on_public_execute,
       case
         when proname in ('nuhris_current_employee_id','nuhris_current_user_id')
           then 'MANAGED (3.1): authenticated EXECUTE only; anon and PUBLIC revoked'
         when prosecdef and extension is not null and (anon_exec or auth_exec)
           then 'BLOCKER (3.6): extension-owned SECURITY DEFINER callable by API roles; decide manually'
         when prosecdef and not acts_as_owner
           then 'BLOCKER (3.0h): owned by ' || pg_catalog.pg_get_userbyid(proowner)
                || '; the running role cannot restrict it'
         when prosecdef and used_by_other_objects is not null
           then 'BLOCKER (3.0l): referenced by ' || used_by_other_objects
         when prosecdef and not is_trigger and prorettype <> 'pg_catalog.event_trigger'::pg_catalog.regtype
              and (anon_exec or auth_exec or acl_source like 'built-in%'
                   or explicit_execute_grantees ~ '(^|, )PUBLIC')
           then 'BLOCKER (3.0o): callable SECURITY DEFINER function; confirm the callers in '
                || 'roles_relying_on_public_execute, then revoke manually: '
                || pg_catalog.format('revoke execute on function %s from public, anon, authenticated;', signature)
         when prosecdef
           then 'REVOKE EXECUTE from PUBLIC, anon, authenticated (3.2c); backend roles that '
                'held it keep it' || case when is_trigger
                  then ' (trigger function: firing is unaffected)' else '' end
         when anon_exec or auth_exec
           then 'KEEP (INFO): SECURITY INVOKER, runs with the caller''s own privileges'
         else 'none'
       end as planned_action,
       -- Proposal only (not applied by PHASE 3): pg_temp is searched FIRST
       -- for tables unless listed; listing it last stops temp-table
       -- shadowing without changing how any other name resolves.
       case
         when prosecdef and search_path is null
           then pg_catalog.format('PROPOSAL: alter function %s set search_path = ''''; -- schema-qualify every name in the body first', signature)
         when prosecdef and search_path not like '%pg\_temp%' and search_path <> 'search_path=""'
           then pg_catalog.format('PROPOSAL: alter function %s set search_path = %s, pg_temp;', signature,
                                  pg_catalog.substr(search_path, 13))
       end as search_path_proposal
from a
where prosecdef or anon_exec or auth_exec
) r
order by security_definer desc, (planned_action like 'BLOCKER%') desc, signature;


-- R4. Default privileges for FUTURE tables, sequences and functions that
--     reach PUBLIC, anon or authenticated, per owner role, globally
--     ("(all schemas)") or in schema public.
--     source: 'configured' = a pg_default_acl row; 'built-in' = no global
--     row, PostgreSQL's built-in default applies (functions: EXECUTE to
--     PUBLIC; tables/sequences: nothing). A schema-level REVOKE cannot
--     remove a global grant, so both levels are listed.
--     can_alter = the running role has that owner's privileges (needed for
--     ALTER DEFAULT PRIVILEGES FOR ROLE ...).
with
creators as (
  select r.oid, r.rolname from pg_catalog.pg_roles r
  where exists (select 1 from pg_catalog.pg_default_acl d where d.defaclrole = r.oid)
     or exists (select 1 from pg_catalog.pg_class c
                join pg_catalog.pg_namespace n on n.oid = c.relnamespace
                where n.nspname = 'public' and c.relowner = r.oid)
     or exists (select 1 from pg_catalog.pg_proc p
                join pg_catalog.pg_namespace n on n.oid = p.pronamespace
                where n.nspname = 'public' and p.proowner = r.oid)
     or r.rolname in ('postgres', 'supabase_admin')
),
configured as (
  select d.defaclrole as roleid, coalesce(n.nspname, '(all schemas)') as scope,
         d.defaclobjtype as objtype, a.grantee, a.privilege_type, 'configured'::text as source
  from pg_catalog.pg_default_acl d
  left join pg_catalog.pg_namespace n on n.oid = d.defaclnamespace
  cross join lateral pg_catalog.aclexplode(d.defaclacl) a
  where (d.defaclnamespace = 0 or n.nspname = 'public')
    and d.defaclobjtype in ('r','S','f')
    and (a.grantee = 0 or pg_catalog.pg_get_userbyid(a.grantee) in ('anon','authenticated'))
),
builtin as (
  select c.oid as roleid, '(all schemas)'::text as scope, 'f'::"char" as objtype,
         0::oid as grantee, 'EXECUTE'::text as privilege_type, 'built-in'::text as source
  from creators c
  where not exists (select 1 from pg_catalog.pg_default_acl d
                    where d.defaclrole = c.oid and d.defaclnamespace = 0 and d.defaclobjtype = 'f')
),
rows_ as (select * from configured union all select * from builtin)
select pg_catalog.pg_get_userbyid(roleid) as owner_role, scope,
       case objtype when 'r' then 'tables' when 'S' then 'sequences' else 'functions' end as object_type,
       case when grantee = 0 then 'PUBLIC' else pg_catalog.pg_get_userbyid(grantee) end as grantee,
       privilege_type, source,
       pg_catalog.pg_has_role(current_user, roleid, 'USAGE') as can_alter,
       case
         when objtype = 'f' and grantee = 0 and scope = '(all schemas)'
           then 'EXCEPTION (V11): built-in PUBLIC EXECUTE kept unless nuhris_cfg.revoke_public_function_default = true'
                || case when not pg_catalog.pg_has_role(current_user, roleid, 'USAGE')
                        then ' (and owner not alterable)' else '' end
         when not pg_catalog.pg_has_role(current_user, roleid, 'USAGE')
           then 'BLOCKED: ' || current_user || ' cannot alter defaults of '
                || pg_catalog.pg_get_userbyid(roleid)
                || '; only that role or a superuser can (Supabase support for supabase_admin)'
         when grantee = 0
           then 'BLOCKER (3.0n): configured PUBLIC default; establish which role creating objects '
                || 'as ' || pg_catalog.pg_get_userbyid(roleid) || ' relies on it, then run the '
                || 'equivalent_statement manually (or record why it stays)'
         else 'REVOKE (3.2d)'
       end as planned_action,
       pg_catalog.format('alter default privileges for role %I%s revoke %s on %s from %s;',
         pg_catalog.pg_get_userbyid(roleid),
         case when scope = '(all schemas)' then '' else ' in schema public' end,
         privilege_type,
         case objtype when 'r' then 'tables' when 'S' then 'sequences' else 'functions' end,
         case when grantee = 0 then 'public' else pg_catalog.quote_ident(pg_catalog.pg_get_userbyid(grantee)) end)
         as equivalent_statement
from rows_
order by can_alter, owner_role, scope, object_type, grantee, privilege_type;


-- R5. PUBLIC grants on public-schema relations and columns: risk and
--     whether the Laravel web portal keeps access without them.
--     Confirmed 2026-10-09: no rows. PHASE 3 aborts (3.0g) if one appears.
with
cfg(laravel_role) as (values ('postgres'::name)),   -- confirm with preflight 0f
laravel as (
  select r.oid, r.rolname, r.rolsuper
  from pg_catalog.pg_roles r join cfg on r.rolname = cfg.laravel_role
),
public_grants as (
  select 'object'::text as level, c.oid as relid, c.relname, c.relkind, c.relowner,
         c.relrowsecurity as rls_on,
         null::name as attname, a.privilege_type, c.relacl as obj_acl,
         null::aclitem[] as col_acl
  from pg_catalog.pg_class c
  join pg_catalog.pg_namespace n on n.oid = c.relnamespace
  cross join lateral pg_catalog.aclexplode(c.relacl) a
  where n.nspname = 'public' and c.relkind in ('r','p','v','m','f','S') and a.grantee = 0
  union all
  select 'column', c.oid, c.relname, c.relkind, c.relowner, c.relrowsecurity,
         att.attname, a.privilege_type, c.relacl, att.attacl
  from pg_catalog.pg_attribute att
  join pg_catalog.pg_class c on c.oid = att.attrelid
  join pg_catalog.pg_namespace n on n.oid = c.relnamespace
  cross join lateral pg_catalog.aclexplode(att.attacl) a
  where n.nspname = 'public' and att.attnum > 0 and not att.attisdropped and a.grantee = 0
),
explicit as (
  select g.relid, g.attname, g.privilege_type, x.grantee
  from public_grants g
  cross join lateral (
    select e.grantee, e.privilege_type from pg_catalog.aclexplode(g.obj_acl) e
    union all
    -- aclexplode() is strict: a NULL column ACL simply yields no rows.
    select e.grantee, e.privilege_type from pg_catalog.aclexplode(g.col_acl) e
  ) x
  where x.grantee <> 0 and x.privilege_type = g.privilege_type
),
analysed as (
  select g.*,
    -- Laravel keeps the privilege without PUBLIC if it is superuser, owns the
    -- object (or inherits the owner role), or holds an explicit grant.
    coalesce(
      (select l.rolsuper from laravel l)
      or pg_catalog.pg_has_role((select l.oid from laravel l), g.relowner, 'USAGE')
      or exists (select 1 from explicit e
                 where e.relid = g.relid and e.attname is not distinct from g.attname
                   and e.privilege_type = g.privilege_type
                   and pg_catalog.pg_has_role((select l.oid from laravel l), e.grantee, 'USAGE')),
      false) as laravel_unaffected,
    ( select pg_catalog.string_agg(r.rolname, ', ' order by r.rolname)
      from pg_catalog.pg_roles r
      where r.rolcanlogin and not r.rolsuper
        and r.rolname not in ('anon', 'authenticated')
        and r.rolname not like 'pg\_%'
        and not pg_catalog.pg_has_role(r.oid, g.relowner, 'USAGE')
        and not exists (select 1 from explicit e
                        where e.relid = g.relid and e.attname is not distinct from g.attname
                          and e.privilege_type = g.privilege_type
                          and pg_catalog.pg_has_role(r.oid, e.grantee, 'USAGE'))
    ) as roles_relying_on_public
  from public_grants g
)
select level, relname as object,
       case relkind when 'S' then 'sequence' when 'v' then 'view' when 'm' then 'matview'
                    when 'f' then 'foreign table' else 'table' end as kind,
       attname as column_name, privilege_type,
       case
         when relkind in ('v','m') and privilege_type = 'SELECT'
           then 'CRITICAL: view runs with owner rights; base-table RLS bypassed for anon'
         when relkind in ('r','p') and not rls_on
              and privilege_type in ('SELECT','INSERT','UPDATE','DELETE')
           then 'CRITICAL now: RLS is off on this table, so anon can ' || lower(privilege_type)
                || ' every row through the REST API'
         when relkind = 'S' and privilege_type = 'UPDATE'
           then 'HIGH: setval() by any role can break id generation'
         when relkind = 'S'
           then 'MEDIUM: sequence values usable/visible (not covered by RLS)'
         when privilege_type in ('TRUNCATE','MAINTAIN','TRIGGER','REFERENCES')
           then 'HIGH: ' || privilege_type || ' is not limited by RLS'
         when privilege_type in ('INSERT','UPDATE','DELETE')
           then 'HIGH: write privilege for anon; bypasses column-level write restrictions'
         else 'HIGH: defeats column-level SELECT limits'
       end as risk,
       laravel_unaffected, roles_relying_on_public,
       case
         when not laravel_unaffected
           then 'BLOCKED: grant the privilege to the Laravel role explicitly first, then re-run'
         when roles_relying_on_public is not null
           then 'REVIEW: decide per listed role whether it really needs this; then revoke'
         else 'REVOKE'
       end as action,
       case when laravel_unaffected then
         case when level = 'column'
              then pg_catalog.format('revoke %s (%I) on table public.%I from public;',
                                     privilege_type, attname, relname)
              else pg_catalog.format('revoke %s on %s public.%I from public;', privilege_type,
                                     case when relkind = 'S' then 'sequence' else 'table' end, relname)
         end
       end as revoke_statement
from analysed
order by laravel_unaffected, object, column_name, privilege_type;


-- R6. Summary: number of explicit ACL entries per category and planned
--     effect. Use these counts in the change record. Compare with the
--     confirmed audit (2026-10-09): 25 table objects and 20 sequences per
--     API role; 0 PUBLIC relation grants.
select category, grantee, privilege_type,
       count(*) as acl_entries, count(distinct object) as objects,
       count(*) filter (where not revocable) as not_revocable_by_current_role
from (
  select case when c.relkind = 'S' then 'sequence'
              when c.relkind in ('v','m') then 'view/matview'
              else 'table' end as category,
         case when a.grantee = 0 then 'PUBLIC' else pg_catalog.pg_get_userbyid(a.grantee) end as grantee,
         a.privilege_type, c.relname::text as object,
         case when pg_catalog.pg_has_role(current_user, c.relowner, 'USAGE')
              then a.grantor = c.relowner
              else pg_catalog.pg_has_role(current_user, a.grantor, 'USAGE') end as revocable
  from pg_catalog.pg_class c
  join pg_catalog.pg_namespace n on n.oid = c.relnamespace
  cross join lateral pg_catalog.aclexplode(c.relacl) a
  where n.nspname = 'public' and c.relkind in ('r','p','v','m','f','S')
    and (a.grantee = 0 or pg_catalog.pg_get_userbyid(a.grantee) in ('anon','authenticated'))
  union all
  select 'column', case when a.grantee = 0 then 'PUBLIC' else pg_catalog.pg_get_userbyid(a.grantee) end,
         a.privilege_type, c.relname || '.' || att.attname,
         case when pg_catalog.pg_has_role(current_user, c.relowner, 'USAGE')
              then a.grantor = c.relowner
              else pg_catalog.pg_has_role(current_user, a.grantor, 'USAGE') end
  from pg_catalog.pg_attribute att
  join pg_catalog.pg_class c on c.oid = att.attrelid
  join pg_catalog.pg_namespace n on n.oid = c.relnamespace
  cross join lateral pg_catalog.aclexplode(att.attacl) a
  where n.nspname = 'public' and att.attnum > 0 and not att.attisdropped
    and (a.grantee = 0 or pg_catalog.pg_get_userbyid(a.grantee) in ('anon','authenticated'))
  union all
  select 'function (EXECUTE, explicit)',
         case when a.grantee = 0 then 'PUBLIC' else pg_catalog.pg_get_userbyid(a.grantee) end,
         a.privilege_type, p.proname::text,
         pg_catalog.pg_has_role(current_user, p.proowner, 'USAGE')
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  cross join lateral pg_catalog.aclexplode(p.proacl) a
  where n.nspname = 'public'
    and (a.grantee = 0 or pg_catalog.pg_get_userbyid(a.grantee) in ('anon','authenticated'))
) s
group by 1, 2, 3
order by 1, 2, 3;
