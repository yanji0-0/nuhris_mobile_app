-- =====================================================================
-- PHASE 0b — OBJECT CREATORS, DEFAULT PRIVILEGES, FUNCTIONS (READ-ONLY)
-- =====================================================================
-- SELECT only. Run each numbered query on its own (the Supabase SQL editor
-- shows only the LAST result of a multi-statement run).
--
-- Facts established (2026-10-09):
--   * The mobile app makes no .rpc() calls (lib/services/api_client.dart).
--     The web portal was reported not to call /rest/v1/rpc; its source is
--     not in this repository, so that is unverified here.
--   * The live audit found one SECURITY DEFINER function,
--     public.enqueue_announcement_notifications() (trigger function, owner
--     postgres, search_path=public, EXECUTE to PUBLIC/anon/authenticated),
--     with NO trigger using it and no reference from other public
--     functions. Its origin (migration or dashboard) is unknown. PHASE 3.2c
--     revokes EXECUTE from PUBLIC/anon/authenticated; it is NOT dropped.
--   * No legitimate API caller needs any SECURITY DEFINER function in
--     public, except the nuhris_* helpers PHASE 3 creates (authenticated
--     must be able to EXECUTE them, because the policies call them).
--   * Set the Laravel role below (confirmed by preflight 0f) where marked.
-- =====================================================================


-- C1. Every role that OWNS objects in schema public (= created them) and
--     every non-system role that is ABLE to create there.
--     Expect: Laravel's role owns the HR tables/sequences. Any other owner
--     of tables is a finding (RLS does not apply to owners).
with owned as (
  select c.relowner as owner_oid,
         case c.relkind when 'r' then 'table' when 'p' then 'table' when 'v' then 'view'
              when 'm' then 'matview' when 'S' then 'sequence'
              else 'foreign table' end as kind
  from pg_catalog.pg_class c
  join pg_catalog.pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind in ('r','p','v','m','S','f')
  union all
  select p.proowner,
         case p.prokind when 'p' then 'procedure' when 'a' then 'aggregate'
                        when 'w' then 'window' else 'function' end
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
  union all
  select t.typowner, 'type'
  from pg_catalog.pg_type t
  join pg_catalog.pg_namespace n on n.oid = t.typnamespace
  where n.nspname = 'public' and t.typtype in ('c','d','e','r','m')
    and not exists (select 1 from pg_catalog.pg_class c where c.reltype = t.oid)
)
select r.rolname as role,
       r.rolsuper, r.rolbypassrls, r.rolcanlogin,
       pg_catalog.has_schema_privilege(r.oid, 'public', 'CREATE') as can_create_in_public,
       coalesce((select pg_catalog.string_agg(k.kind || ':' || k.cnt, ', ' order by k.kind)
                 from (select o.kind, count(*) as cnt from owned o
                       where o.owner_oid = r.oid group by o.kind) k), '-') as owns_in_public
from pg_catalog.pg_roles r
where exists (select 1 from owned o where o.owner_oid = r.oid)
   or (pg_catalog.has_schema_privilege(r.oid, 'public', 'CREATE')
       and r.rolname not like 'pg\_%')
order by (select count(*) from owned o where o.owner_oid = r.oid) desc, r.rolname;


-- C2. EFFECTIVE default privileges a NEW object in schema public receives,
--     per creating role and object type: the role's GLOBAL default (or
--     PostgreSQL's built-in default via acldefault() when none is set)
--     plus its schema-public default (additive). Only grants to PUBLIC,
--     anon and authenticated are listed.
--     Built-ins: functions -> EXECUTE to PUBLIC, types -> USAGE to PUBLIC,
--     tables/sequences -> nothing.
with creators as (
  select r.oid, r.rolname
  from pg_catalog.pg_roles r
  where exists (select 1 from pg_catalog.pg_class c
                join pg_catalog.pg_namespace n on n.oid = c.relnamespace
                where n.nspname = 'public' and c.relowner = r.oid)
     or exists (select 1 from pg_catalog.pg_proc p
                join pg_catalog.pg_namespace n on n.oid = p.pronamespace
                where n.nspname = 'public' and p.proowner = r.oid)
     or (pg_catalog.has_schema_privilege(r.oid, 'public', 'CREATE')
         and r.rolname not like 'pg\_%')
     -- Always inspect these two, even if they own nothing in public yet:
     -- postgres = Laravel / SQL editor; supabase_admin = Supabase platform.
     or r.rolname in ('postgres', 'supabase_admin')
),
objtypes(defacl_type, acldefault_type, label) as (values
  ('r'::"char", 'r'::"char", 'tables'),
  ('S'::"char", 's'::"char", 'sequences'),
  ('f'::"char", 'f'::"char", 'functions'),
  ('T'::"char", 'T'::"char", 'types')
),
effective as (
  select cr.rolname, o.label, 'global' as level,
         (g.defaclacl is null) as built_in, a.grantee, a.privilege_type
  from creators cr
  cross join objtypes o
  left join pg_catalog.pg_default_acl g
    on g.defaclrole = cr.oid and g.defaclnamespace = 0 and g.defaclobjtype = o.defacl_type
  cross join lateral pg_catalog.aclexplode(
    coalesce(g.defaclacl, pg_catalog.acldefault(o.acldefault_type, cr.oid))) a
  union all
  select cr.rolname, o.label, 'schema public', false, a.grantee, a.privilege_type
  from creators cr
  cross join objtypes o
  join pg_catalog.pg_default_acl d
    on d.defaclrole = cr.oid
   and d.defaclnamespace = 'public'::regnamespace
   and d.defaclobjtype = o.defacl_type
  cross join lateral pg_catalog.aclexplode(d.defaclacl) a
)
select rolname as creating_role, label as object_type, level,
       case when built_in then 'built-in' else 'configured' end as source,
       case when grantee = 0 then 'PUBLIC'
            else pg_catalog.pg_get_userbyid(grantee) end as grantee,
       privilege_type,
       case
         when label in ('tables','sequences')
           then 'Removed by PHASE 3.2d if the running role can alter creating_role '
                '(see rls/03a R4); otherwise BLOCKED'
         when label = 'functions' and grantee = 0 and level = 'global'
           then 'Built-in/global PUBLIC EXECUTE: documented exception unless '
                'nuhris_cfg.revoke_public_function_default = true'
         when label = 'functions'
           then 'Every new function becomes callable through /rest/v1/rpc; '
                'removed by PHASE 3.2d if creating_role can be altered'
         else 'Low: type usage'
       end as meaning
from effective
where grantee = 0 or pg_catalog.pg_get_userbyid(grantee) in ('anon', 'authenticated')
order by 1, 2, 3, 5, 6;


-- F1. Every function in schema public: who can call it through the API,
--     with whose rights it runs, and a narrowly scoped proposed fix.
--     PROPOSALS ONLY — nothing here is executed.
with
cfg(laravel_role) as (values ('postgres'::name)),        -- confirm with 0f
laravel as (select r.oid, r.rolsuper from pg_catalog.pg_roles r
            join cfg on r.rolname = cfg.laravel_role),
hr_tables(t) as (values ('users'),('employees'),('attendance_records'),
  ('leave_balances'),('leave_requests'),('employee_credentials'),
  ('wfh_monitoring_submissions'),('employee_schedule_submissions'),
  ('employee_schedule_days'),('announcement_notifications'),('announcements'),
  ('privacy_notice_acknowledgments'),('sessions'),('password_reset_tokens'),
  ('admin_audit_logs'),('admin_configs'),('cache')),
fn as (
  select p.oid, p.proname,
         pg_catalog.pg_get_function_identity_arguments(p.oid) as args,
         p.prosecdef, p.proowner, p.provolatile, p.proacl, p.prokind,
         l.lanname,
         p.prorettype = 'pg_catalog.trigger'::pg_catalog.regtype as is_trigger,
         coalesce(exists (select 1 from pg_catalog.unnest(p.proconfig) s
                          where s like 'search\_path=%'), false) as search_path_pinned,
         (select e.extname from pg_catalog.pg_depend d
          join pg_catalog.pg_extension e on e.oid = d.refobjid
          where d.classid = 'pg_catalog.pg_proc'::pg_catalog.regclass
            and d.objid = p.oid and d.deptype = 'e' limit 1) as extension,
         (select pg_catalog.string_agg(h.t, ', ') from hr_tables h
          where p.prosrc ~* ('\m' || h.t || '\M')) as mentions_tables
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  join pg_catalog.pg_language l on l.oid = p.prolang
  where n.nspname = 'public'
),
a as (
  select f.*,
    pg_catalog.pg_get_userbyid(f.proowner) as owner,
    (select o.rolsuper or o.rolbypassrls from pg_catalog.pg_roles o
     where o.oid = f.proowner) as owner_bypasses_rls,
    exists (select 1 from pg_catalog.aclexplode(
              coalesce(f.proacl, pg_catalog.acldefault('f', f.proowner))) x
            where x.grantee = 0 and x.privilege_type = 'EXECUTE') as public_exec,
    pg_catalog.has_function_privilege('anon', f.oid, 'EXECUTE')          as anon_exec,
    pg_catalog.has_function_privilege('authenticated', f.oid, 'EXECUTE') as auth_exec,
    -- Does Laravel keep EXECUTE without PUBLIC/anon/authenticated grants?
    coalesce((select l.rolsuper from laravel l)
      or pg_catalog.pg_has_role((select l.oid from laravel l), f.proowner, 'USAGE')
      or exists (select 1 from pg_catalog.aclexplode(f.proacl) x
                 where x.grantee <> 0 and x.privilege_type = 'EXECUTE'
                   and pg_catalog.pg_get_userbyid(x.grantee) not in ('anon','authenticated')
                   and pg_catalog.pg_has_role((select l.oid from laravel l), x.grantee, 'USAGE')),
      false) as laravel_keeps_exec,
    pg_catalog.format('public.%I(%s)', f.proname,
                      pg_catalog.pg_get_function_identity_arguments(f.oid)) as signature
  from fn f
)
select proname, args,
       case prokind when 'p' then 'procedure' when 'a' then 'aggregate'
                    when 'w' then 'window' else 'function' end as kind,
       prosecdef as security_definer, owner, owner_bypasses_rls,
       search_path_pinned, lanname as language,
       case provolatile when 'v' then 'volatile' when 's' then 'stable' else 'immutable' end as volatility,
       is_trigger, extension, mentions_tables,
       public_exec, anon_exec, auth_exec, laravel_keeps_exec,
       case
         when proname in ('nuhris_current_employee_id','nuhris_current_user_id')
           then 'EXPECTED: NUHRIS policy helper (authenticated must execute; anon must not)'
         when is_trigger
           then 'LOW: trigger function (not callable via /rpc; EXECUTE is checked only when the trigger is created)'
         when prosecdef and (anon_exec or auth_exec) and not search_path_pinned
           then 'CRITICAL: SECURITY DEFINER callable via /rpc, runs as ' || owner
                || ', search_path not pinned (hijackable)'
         when prosecdef and anon_exec
           then 'HIGH: SECURITY DEFINER callable by anon via /rpc; runs as ' || owner
                || case when owner_bypasses_rls then ' (bypasses RLS)' else '' end
         when prosecdef and auth_exec
           then 'HIGH: SECURITY DEFINER callable by any signed-in user via /rpc; runs as ' || owner
         when prosecdef and not search_path_pinned
           then 'MEDIUM: SECURITY DEFINER with unpinned search_path (not API-callable now)'
         when extension is not null and (anon_exec or auth_exec)
           then 'LOW: extension function (' || extension || '), runs with caller rights'
         when (anon_exec or auth_exec) and provolatile = 'v'
           then 'MEDIUM: callable via /rpc, runs with caller rights but may write'
         when anon_exec or auth_exec
           then 'LOW: callable via /rpc, read-only, runs with caller rights'
         else 'OK: not callable by the API roles'
       end as risk,
       case
         when proname in ('nuhris_current_employee_id','nuhris_current_user_id')
           then 'none'
         when is_trigger or not (anon_exec or auth_exec or public_exec)
           then case when prosecdef and not search_path_pinned
                     then pg_catalog.format('alter function %s set search_path = '''';  -- review body: names must be schema-qualified', signature)
                     else 'none' end
         when not laravel_keeps_exec
           then 'BLOCKED: Laravel may rely on PUBLIC EXECUTE; grant EXECUTE to the Laravel role first'
         when extension is not null
           then 'REVIEW: extension-owned; check column defaults/policies that call it before revoking: '
                || pg_catalog.format('revoke execute on function %s from public, anon, authenticated;', signature)
         else pg_catalog.format('revoke execute on function %s from public, anon, authenticated;', signature)
              || case when prosecdef and not search_path_pinned
                      then pg_catalog.format(' alter function %s set search_path = '''';  -- review body first', signature)
                      else '' end
       end as proposed_fix_not_applied
from a
-- Most dangerous first: SECURITY DEFINER, then callable by anon, then by
-- authenticated (plain output-column names; expressions on aliases are
-- not allowed in ORDER BY).
order by security_definer desc, anon_exec desc, auth_exec desc, proname, args;


-- F2. Full definitions of SECURITY DEFINER functions in schema public, for
--     manual review of what they read/write and whether every name in the
--     body is schema-qualified (needed before pinning search_path = '').
--     Expect today: enqueue_announcement_notifications (see header); after
--     PHASE 3 also the two nuhris_* helpers.
select p.proname,
       pg_catalog.pg_get_userbyid(p.proowner) as owner,
       pg_catalog.pg_get_functiondef(p.oid)   as definition
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.prosecdef and p.prokind in ('f', 'p')
order by p.proname;


-- ---------------------------------------------------------------------
-- FUTURE functions: Supabase's defaults make every new function in public
-- executable by anon/authenticated (plus PostgreSQL's built-in PUBLIC
-- EXECUTE). PHASE 3.2d now revokes the anon/authenticated defaults (global
-- and schema public) and the schema-public PUBLIC default for every role
-- the running role may alter. The GLOBAL built-in PUBLIC EXECUTE is kept by
-- default (nuhris_cfg.revoke_public_function_default = false) because it
-- also affects every other schema; see RLS_RUNBOOK.md, exception E2.
-- ---------------------------------------------------------------------
