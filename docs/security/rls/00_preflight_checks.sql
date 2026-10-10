-- =====================================================================
-- PHASE 0 — PREFLIGHT CHECKS (READ-ONLY)
-- =====================================================================
-- Run in the Supabase SQL editor (role: postgres). Every statement is a
-- SELECT; nothing is created, changed or deleted. Run them one at a time
-- and keep the output: it decides whether PHASE 3 may run.
-- =====================================================================


-- 0a. Who is running this, and the attributes of the roles involved.
--     Laravel connects through the Supabase pooler as "postgres.<ref>",
--     which maps to the database role `postgres`. Confirm in 0f.
select current_user, session_user;

select rolname, rolsuper, rolbypassrls, rolinherit
from pg_catalog.pg_roles
where rolname in ('postgres', 'anon', 'authenticated', 'service_role',
                  'supabase_admin', 'authenticator')
order by rolname;


-- 0b. Owner, RLS and FORCE RLS for every public table.
--     PASS when: every table is owned by Laravel's role (or that role has
--     rolbypassrls = true in 0a) AND force_rls = false everywhere.
--     FORCE RLS would subject even the owner (the web portal) to RLS.
select c.relname                  as table_name,
       pg_catalog.pg_get_userbyid(c.relowner) as owner,
       c.relrowsecurity           as rls_enabled,
       c.relforcerowsecurity      as force_rls
from pg_catalog.pg_class c
join pg_catalog.pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind in ('r', 'p')
order by c.relname;


-- 0c. Every existing policy in public and storage.
--     Policies are OR-ed: any permissive policy for anon / authenticated /
--     public that is broader than "own rows" keeps data exposed. PHASE 3
--     ABORTS if such policies exist on public tables; review and drop them
--     explicitly first (see RUNBOOK, step 4).
select schemaname, tablename, policyname, permissive, roles, cmd,
       qual, with_check
from pg_catalog.pg_policies
where schemaname in ('public', 'storage')
order by schemaname, tablename, policyname;


-- 0d. Explicit table/view/matview/foreign/partitioned table and sequence
--     ACL entries for anon, authenticated and PUBLIC (relacl only: a NULL
--     ACL means "owner only" and is not expanded with acldefault(), so
--     nothing here is a built-in default reported as a grant).
--     aclexplode() reports PUBLIC as grantee OID 0, which pg_get_userbyid()
--     cannot name, so it is decoded explicitly.
--     revocable_by_current_role: a non-superuser REVOKE removes only entries
--     whose grantor it acts as (the owner, if it has the owner's privileges;
--     otherwise a grantor role it has privileges of). False = the entry
--     survives PHASE 3's REVOKE (PHASE 3 aborts in 3.0h instead).
select c.relname as object,
       case c.relkind when 'S' then 'sequence' when 'v' then 'view'
                      when 'm' then 'matview' when 'f' then 'foreign table'
                      when 'p' then 'partitioned table' else 'table' end as kind,
       case when a.grantee = 0 then 'PUBLIC'
            else pg_catalog.pg_get_userbyid(a.grantee) end as grantee,
       a.privilege_type, a.is_grantable,
       pg_catalog.pg_get_userbyid(a.grantor)    as grantor,
       pg_catalog.pg_get_userbyid(c.relowner)   as owner,
       case when pg_catalog.pg_has_role(current_user, c.relowner, 'USAGE')
            then a.grantor = c.relowner
            else pg_catalog.pg_has_role(current_user, a.grantor, 'USAGE') end
         as revocable_by_current_role
from pg_catalog.pg_class c
join pg_catalog.pg_namespace n on n.oid = c.relnamespace
cross join lateral pg_catalog.aclexplode(c.relacl) a
where n.nspname = 'public' and c.relkind in ('r', 'p', 'v', 'm', 'f', 'S')
  and (a.grantee = 0
       or pg_catalog.pg_get_userbyid(a.grantee) in ('anon', 'authenticated'))
order by 2, 1, 3, 4;


-- 0e. Explicit COLUMN-level ACL entries for anon, authenticated and PUBLIC
--     (read from pg_attribute.attacl, so table-level grants are not
--     double-counted).
select c.relname as table_name, att.attname as column_name,
       case when a.grantee = 0 then 'PUBLIC'
            else pg_catalog.pg_get_userbyid(a.grantee) end as grantee,
       a.privilege_type, a.is_grantable,
       pg_catalog.pg_get_userbyid(a.grantor) as grantor,
       case when pg_catalog.pg_has_role(current_user, c.relowner, 'USAGE')
            then a.grantor = c.relowner
            else pg_catalog.pg_has_role(current_user, a.grantor, 'USAGE') end
         as revocable_by_current_role
from pg_catalog.pg_attribute att
join pg_catalog.pg_class c on c.oid = att.attrelid
join pg_catalog.pg_namespace n on n.oid = c.relnamespace
cross join lateral pg_catalog.aclexplode(att.attacl) a
where n.nspname = 'public' and att.attnum > 0 and not att.attisdropped
  and (a.grantee = 0
       or pg_catalog.pg_get_userbyid(a.grantee) in ('anon', 'authenticated'))
order by 1, 3, 2, 4;


-- 0f. Laravel's actual database role. Two independent checks:
--   (1) Live connections — the web portal's connections and their role:
select usename, application_name, client_addr, state, count(*)
from pg_catalog.pg_stat_activity
where datname = current_database()
group by 1, 2, 3, 4
order by 1, 2;
--   (2) From the web project (read-only), record the output:
--       php artisan tinker --execute="dump(DB::select('select current_user, session_user'))"


-- 0g. Every table/column referenced by PHASE 3 exists (expect no rows).
with expected(table_name, column_name) as (values
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
  ('wfh_monitoring_submissions','monitoring_link'),
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
  ('privacy_notice_acknowledgments','updated_at'))
select e.table_name, e.column_name as missing_column
from expected e
left join information_schema.columns c
  on c.table_schema = 'public'
 and c.table_name = e.table_name
 and c.column_name = e.column_name
where c.column_name is null;


-- 0h. Data type of employees.auth_id (helpers compare it as text).
select data_type, udt_name
from information_schema.columns
where table_schema = 'public' and table_name = 'employees' and column_name = 'auth_id';


-- 0i. The helper functions read auth.users; postgres must be able to.
select pg_catalog.has_table_privilege('postgres', 'auth.users', 'SELECT') as postgres_reads_auth_users;


-- 0j. Unconfirmed Auth accounts (they cannot sign in once "Confirm email"
--     is enforced). Web-created accounts use email_confirm = true.
select count(*) filter (where email_confirmed_at is null) as unconfirmed,
       count(*)                                           as total
from auth.users;


-- 0k. Do the helper functions / version table already exist?
--     (Recorded so the rollback only drops what PHASE 3 created.)
select p.proname from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname like 'nuhris\_%';
select pg_catalog.to_regclass('public.mobile_app_versions') as version_table;


-- 0l. Default privileges: what FUTURE tables/sequences/functions receive,
--     per creating role, globally (schema = '(all schemas)') or in a schema.
--     Rows granting to anon / authenticated / PUBLIC expose new objects.
--     CONFIGURED entries only (pg_default_acl rows). The built-in function
--     default (EXECUTE to PUBLIC when no global row exists) is shown by
--     rls/00b C2 and rls/03a R4 with source = 'built-in'.
--     can_alter: the running role has the owner's privileges, which ALTER
--     DEFAULT PRIVILEGES FOR ROLE requires. false = PHASE 3 cannot fix it.
select pg_catalog.pg_get_userbyid(d.defaclrole) as for_role,
       coalesce(n.nspname, '(all schemas)')      as schema,
       case d.defaclobjtype when 'r' then 'tables' when 'S' then 'sequences'
            when 'f' then 'functions' when 'T' then 'types'
            when 'n' then 'schemas' end          as object_type,
       case when a.grantee = 0 then 'PUBLIC'
            else pg_catalog.pg_get_userbyid(a.grantee) end as grantee,
       a.privilege_type,
       pg_catalog.pg_has_role(current_user, d.defaclrole, 'USAGE') as can_alter
from pg_catalog.pg_default_acl d
left join pg_catalog.pg_namespace n on n.oid = d.defaclnamespace
cross join lateral pg_catalog.aclexplode(d.defaclacl) a
where a.grantee = 0
   or pg_catalog.pg_get_userbyid(a.grantee) in ('anon', 'authenticated')
order by 1, 2, 3, 4, 5;


-- 0m. Realtime publication (the app subscribes to these two tables).
select pubname, schemaname, tablename
from pg_catalog.pg_publication_tables
where tablename in ('announcement_notifications', 'announcements');


-- 0n. PUBLIC privileges on public-schema objects (summary; every row is
--     inherited by anon and authenticated). Full risk analysis and the
--     reviewed remediation statements: rls/03a_public_grants_remediation.sql
select 'table/sequence' as level, c.relname as object, null::name as column_name,
       a.privilege_type
from pg_catalog.pg_class c
join pg_catalog.pg_namespace n on n.oid = c.relnamespace
cross join lateral pg_catalog.aclexplode(c.relacl) a
where n.nspname = 'public' and c.relkind in ('r','p','v','m','f','S') and a.grantee = 0
union all
select 'column', c.relname, att.attname, a.privilege_type
from pg_catalog.pg_attribute att
join pg_catalog.pg_class c on c.oid = att.attrelid
join pg_catalog.pg_namespace n on n.oid = c.relnamespace
cross join lateral pg_catalog.aclexplode(att.attacl) a
where n.nspname = 'public' and att.attnum > 0 and not att.attisdropped and a.grantee = 0
order by 1, 2, 3, 4;


-- 0o. Role memberships that involve anon / authenticated, in BOTH
--     directions, with what each membership actually confers.
--     direction = 'API role is member of X': the API role gains X's
--       privileges (inherits = true) or can SET ROLE X (settable = true).
--       Expect NO such rows; PHASE 3 aborts (3.0j) if one exists.
--     direction = 'X is member of API role': X gains the API role's
--       privileges, not the reverse. Standard Supabase rows are
--       authenticator (NOINHERIT, used by PostgREST to SET ROLE) and
--       postgres. They do not widen what anon/authenticated can do and are
--       NOT changed by PHASE 3. Only privileges X holds SOLELY through the
--       API role would change; PHASE 3 verifies postgres / service_role /
--       Laravel keep everything they have (3.6).
--     inherit_option / set_option / admin_option come from pg_auth_members
--     on PostgreSQL 16+ (NULL on older versions; then use rolinherit).
select case when api.oid = m.member then 'API role is member of X'
            else 'X is member of API role' end as direction,
       pg_catalog.pg_get_userbyid(m.member) as member,
       pg_catalog.pg_get_userbyid(m.roleid) as of_role,
       (pg_catalog.to_jsonb(m) ->> 'inherit_option') as inherit_option,
       (pg_catalog.to_jsonb(m) ->> 'set_option')     as set_option,
       (pg_catalog.to_jsonb(m) ->> 'admin_option')   as admin_option,
       mr.rolinherit as member_rolinherit,
       pg_catalog.pg_has_role(m.member, m.roleid, 'USAGE') as inherits,
       pg_catalog.pg_has_role(m.member, m.roleid, 'MEMBER') as member_or_settable
from pg_catalog.pg_auth_members m
join pg_catalog.pg_roles api on api.rolname in ('anon', 'authenticated')
                            and api.oid in (m.member, m.roleid)
join pg_catalog.pg_roles mr on mr.oid = m.member
order by 1, 2, 3;
--     Indirect (multi-level) membership of the API roles, expect no rows:
select a.rolname as api_role, r.rolname as member_of_or_inherits
from pg_catalog.pg_roles a
cross join pg_catalog.pg_roles r
where a.rolname in ('anon', 'authenticated')
  and r.oid <> a.oid
  and pg_catalog.pg_has_role(a.oid, r.oid, 'MEMBER')
order by 1, 2;


-- 0p. EFFECTIVE privileges of anon and authenticated on EVERY table, view,
--     matview, foreign/partitioned table, sequence and column in schema
--     public, and WHERE EACH ONE COMES FROM. has_*_privilege() resolves
--     direct grants, PUBLIC grants, inherited memberships and ownership;
--     the `sources` column then attributes the privilege from the catalog:
--       direct ACL         explicit entry for the API role itself
--       PUBLIC ACL         explicit entry for PUBLIC
--       inherited via R    explicit entry for a role R the API role inherits
--       owner (via R)      the API role has the owner's privileges
--       predefined role    pg_read_all_data / pg_write_all_data / pg_maintain
--     Every source shows the grantor. An empty `sources` would mean an
--     unexplained privilege: investigate before PHASE 3.
--     Columns are listed only where the column privilege is NOT already
--     implied by a table-level privilege.
--     Run 05_verify.sql for the same data compared with the allowlist.
with
api(role_name, roleid) as (
  select rolname, oid from pg_catalog.pg_roles where rolname in ('anon', 'authenticated')
),
rels as (
  select c.oid, c.relname, c.relkind, c.relowner, c.relacl
  from pg_catalog.pg_class c
  join pg_catalog.pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind in ('r','p','v','m','f','S')
),
privs(privilege, for_seq) as (
  select v.privilege, v.for_seq
  from (values ('SELECT',false),('INSERT',false),('UPDATE',false),('DELETE',false),
               ('TRUNCATE',false),('REFERENCES',false),('TRIGGER',false),('MAINTAIN',false),
               ('USAGE',true),('SELECT',true),('UPDATE',true)) v(privilege, for_seq)
  -- MAINTAIN exists from PostgreSQL 17; only tested where the server has it.
  where v.privilege <> 'MAINTAIN'
     or pg_catalog.current_setting('server_version_num')::int >= 170000
),
eff as (
  select r.role_name, r.roleid, t.oid, t.relname, t.relkind, t.relowner, t.relacl,
         null::name as attname, null::aclitem[] as attacl, p.privilege
  from api r cross join rels t
  join privs p on p.for_seq = (t.relkind = 'S')
  where case when t.relkind = 'S'
             then pg_catalog.has_sequence_privilege(r.role_name, t.oid, p.privilege)
             else pg_catalog.has_table_privilege(r.role_name, t.oid, p.privilege) end
  union all
  select r.role_name, r.roleid, t.oid, t.relname, t.relkind, t.relowner, t.relacl,
         att.attname, att.attacl, p.privilege
  from api r cross join rels t
  join pg_catalog.pg_attribute att on att.attrelid = t.oid and att.attnum > 0 and not att.attisdropped
  cross join (values ('SELECT'),('INSERT'),('UPDATE'),('REFERENCES')) p(privilege)
  where t.relkind <> 'S'
    and pg_catalog.has_column_privilege(r.role_name, t.oid, att.attnum, p.privilege)
    and not pg_catalog.has_table_privilege(r.role_name, t.oid, p.privilege)
)
select e.role_name, e.relname as object,
       case e.relkind when 'S' then 'sequence' when 'v' then 'view' when 'm' then 'matview'
                      when 'f' then 'foreign table' when 'p' then 'partitioned table'
                      else 'table' end as kind,
       e.attname as column_name, e.privilege,
       pg_catalog.concat_ws('; ',
         -- explicit ACL entries (object level, plus column level for columns)
         (select pg_catalog.string_agg(
                   case when x.grantee = e.roleid then 'direct ACL'
                        when x.grantee = 0 then 'PUBLIC ACL'
                        else 'inherited via ' || pg_catalog.pg_get_userbyid(x.grantee) end
                   || case when x.lvl = 'column' then ' (column)' else '' end
                   || ' (grantor ' || pg_catalog.pg_get_userbyid(x.grantor) || ')', '; ')
          from (select 'object' as lvl, a.* from pg_catalog.aclexplode(e.relacl) a
                union all
                select 'column', a.* from pg_catalog.aclexplode(e.attacl) a) x
          where x.privilege_type = e.privilege
            and (x.grantee = 0 or pg_catalog.pg_has_role(e.roleid, x.grantee, 'USAGE'))),
         case when pg_catalog.pg_has_role(e.roleid, e.relowner, 'USAGE')
              then 'owner (via ' || pg_catalog.pg_get_userbyid(e.relowner) || ')' end,
         case when e.privilege = 'SELECT' and pg_catalog.to_regrole('pg_read_all_data') is not null
                   and pg_catalog.pg_has_role(e.roleid, 'pg_read_all_data', 'USAGE')
              then 'predefined role pg_read_all_data' end,
         case when e.privilege in ('INSERT','UPDATE','DELETE') and pg_catalog.to_regrole('pg_write_all_data') is not null
                   and pg_catalog.pg_has_role(e.roleid, 'pg_write_all_data', 'USAGE')
              then 'predefined role pg_write_all_data' end,
         case when e.privilege = 'MAINTAIN' and pg_catalog.to_regrole('pg_maintain') is not null
                   and pg_catalog.pg_has_role(e.roleid, 'pg_maintain', 'USAGE')
              then 'predefined role pg_maintain' end
       ) as sources
from eff e
order by kind, object, column_name, role_name, privilege;


-- 0t. Functions in schema public: who can EXECUTE and why.
--     acl_source: 'explicit ACL' (proacl stored) or 'built-in default'
--     (proacl NULL: PostgreSQL's implicit EXECUTE to PUBLIC; not a grant
--     anyone issued). Once any GRANT/REVOKE touches a function, its ACL is
--     stored and the former default PUBLIC entry appears in it explicitly.
--     Full risk analysis and planned action: rls/03a R3 and rls/00b F1.
select pg_catalog.format('public.%I(%s)', p.proname,
                         pg_catalog.pg_get_function_identity_arguments(p.oid)) as signature,
       p.prosecdef as security_definer,
       pg_catalog.pg_get_userbyid(p.proowner) as owner,
       (select s from pg_catalog.unnest(p.proconfig) s where s like 'search\_path=%') as search_path,
       p.prorettype = 'pg_catalog.trigger'::pg_catalog.regtype as is_trigger,
       case when p.proacl is null then 'built-in default' else 'explicit ACL' end as acl_source,
       (select pg_catalog.string_agg(
                 case when x.grantee = 0 then 'PUBLIC' else pg_catalog.pg_get_userbyid(x.grantee) end
                 || ' (grantor ' || pg_catalog.pg_get_userbyid(x.grantor) || ')', ', ')
        from pg_catalog.aclexplode(p.proacl) x where x.privilege_type = 'EXECUTE') as explicit_execute,
       pg_catalog.has_function_privilege('anon', p.oid, 'EXECUTE')          as anon_exec,
       pg_catalog.has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_exec,
       (select pg_catalog.string_agg(t.tgrelid::pg_catalog.regclass::text || '.' || t.tgname, ', ')
        from pg_catalog.pg_trigger t where t.tgfoid = p.oid and not t.tgisinternal) as used_by_triggers
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
order by p.prosecdef desc, 1;


-- 0u. Per public table: RLS state, policies, and whether the API roles can
--     reach it today. Decides whether enabling RLS (PHASE 3.2a) changes
--     anything for a table and which tables become deny-all.
select c.relname as table_name,
       pg_catalog.pg_get_userbyid(c.relowner) as owner,
       c.relrowsecurity as rls_enabled, c.relforcerowsecurity as force_rls,
       (select count(*) from pg_catalog.pg_policy p where p.polrelid = c.oid) as policies,
       (select pg_catalog.string_agg(p.polname || case when p.polpermissive then '' else ' (restrictive)' end, ', ')
        from pg_catalog.pg_policy p where p.polrelid = c.oid) as policy_names,
       pg_catalog.has_table_privilege('anon', c.oid, 'SELECT,INSERT,UPDATE,DELETE')          as anon_any_dml,
       pg_catalog.has_table_privilege('authenticated', c.oid, 'SELECT,INSERT,UPDATE,DELETE') as auth_any_dml,
       exists (select 1 from pg_catalog.pg_publication_rel pr where pr.prrelid = c.oid) as in_publication
from pg_catalog.pg_class c
join pg_catalog.pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind in ('r', 'p')
order by c.relname;


-- 0r. COUNT of explicit ACL entries held by anon / authenticated / PUBLIC,
--     per object kind and privilege (object and column level). Use it to
--     report affected-object counts.
select level, kind, grantee, privilege_type,
       count(*) as acl_entries, count(distinct object) as objects
from (
  select 'object' as level,
         case c.relkind when 'S' then 'sequence' when 'v' then 'view' when 'm' then 'matview'
              when 'f' then 'foreign table' when 'p' then 'partitioned table'
              else 'table' end as kind,
         case when a.grantee = 0 then 'PUBLIC'
              else pg_catalog.pg_get_userbyid(a.grantee) end as grantee,
         a.privilege_type, c.relname::text as object
  from pg_catalog.pg_class c
  join pg_catalog.pg_namespace n on n.oid = c.relnamespace
  cross join lateral pg_catalog.aclexplode(c.relacl) a
  where n.nspname = 'public' and c.relkind in ('r','p','v','m','f','S')
    and (a.grantee = 0 or pg_catalog.pg_get_userbyid(a.grantee) in ('anon','authenticated'))
  union all
  select 'column', 'column',
         case when a.grantee = 0 then 'PUBLIC'
              else pg_catalog.pg_get_userbyid(a.grantee) end,
         a.privilege_type, c.relname || '.' || att.attname
  from pg_catalog.pg_attribute att
  join pg_catalog.pg_class c on c.oid = att.attrelid
  join pg_catalog.pg_namespace n on n.oid = c.relnamespace
  cross join lateral pg_catalog.aclexplode(att.attacl) a
  where n.nspname = 'public' and att.attnum > 0 and not att.attisdropped
    and (a.grantee = 0 or pg_catalog.pg_get_userbyid(a.grantee) in ('anon','authenticated'))
) s
group by 1, 2, 3, 4
order by 1, 2, 3, 4;


-- 0s. Schema-level privileges on public. Expect anon/authenticated:
--     usage = true, can_create = false; PUBLIC: can_create = false
--     (the PostgreSQL 15+ default).
select r.role_name,
       pg_catalog.has_schema_privilege(r.role_name, 'public', 'USAGE')  as usage,
       pg_catalog.has_schema_privilege(r.role_name, 'public', 'CREATE') as can_create
from (values ('anon'), ('authenticated')) r(role_name)
union all
select 'PUBLIC',
       exists (select 1 from pg_catalog.pg_namespace n
               cross join lateral pg_catalog.aclexplode(
                 coalesce(n.nspacl, pg_catalog.acldefault('n', n.nspowner))) a
               where n.nspname = 'public' and a.grantee = 0 and a.privilege_type = 'USAGE'),
       exists (select 1 from pg_catalog.pg_namespace n
               cross join lateral pg_catalog.aclexplode(
                 coalesce(n.nspacl, pg_catalog.acldefault('n', n.nspowner))) a
               where n.nspname = 'public' and a.grantee = 0 and a.privilege_type = 'CREATE');


-- 0q. Functions in schema public the API roles can EXECUTE (PostgREST
--     exposes them as /rest/v1/rpc/<name>). Functions get EXECUTE for
--     PUBLIC by default. Review SECURITY DEFINER ones in particular.
select p.proname, pg_catalog.pg_get_function_identity_arguments(p.oid) as args,
       p.prosecdef as security_definer,
       pg_catalog.has_function_privilege('anon', p.oid, 'EXECUTE')          as anon_exec,
       pg_catalog.has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_exec
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
order by p.prosecdef desc, p.proname;
