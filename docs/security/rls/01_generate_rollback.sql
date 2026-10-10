-- =====================================================================
-- PHASE 1 — GENERATE THE ROLLBACK SCRIPT (READ-ONLY)
-- =====================================================================
-- Run BEFORE PHASE 3, as the role that will run PHASE 3 (postgres). This
-- SELECT changes nothing: it returns one text value, `rollback_sql`. Save
-- it as docs/security/rls/rollback_<date>.sql and read it before saving.
--
-- The generated file has two clearly separated parts:
--
--   SECTION 1 — REMOVE NUHRIS ADDITIONS (does not re-open anything)
--     * drops the nuhris_* policies PHASE 3 creates (only if the table
--       exists when the rollback runs);
--     * helper functions nuhris_current_employee_id / nuhris_current_user_id:
--         - existed now  -> their CURRENT definition is restored verbatim
--                           (never dropped);
--         - absent now   -> dropped by a guarded block ONLY if, when the
--                           rollback runs, the function still carries the
--                           ownership marker PHASE 3 sets
--                           (COMMENT 'NUHRIS_HARDENING_OBJECT: ...') and
--                           nothing depends on it; otherwise kept + WARNING;
--     * public.mobile_app_versions is NEVER dropped by the generated file.
--       If PHASE 3 created it, a guarded DROP is included as a COMMENT for
--       a separate, reviewed decision (dropping loses its rows; app v1.1.0
--       treats a missing table as "no policy").
--
--   SECTION 2 — SECURITY-REVERTING (re-opens the audited exposure)
--     Every block is labelled '!!! SECURITY-REVERTING'. It restores today's
--     RLS / FORCE flags, today's policies, and today's table, view, column
--     and sequence grants of anon, authenticated and PUBLIC (incl. grant
--     options). It also restores EXECUTE of PUBLIC/anon/authenticated on the
--     SECURITY DEFINER functions PHASE 3.2c restricts, and the table,
--     sequence and function default privileges PHASE 3.2d changes. This
--     is today's excessive access. It exists only to recover from an
--     outage caused by PHASE 3, with approval, followed by a fix forward.
--
-- Safety interlock: the generated file REFUSES to run unless the session
-- setting nuhris.allow_security_revert = 'yes' is set first (see its
-- header). The whole file is one transaction: any error undoes all of it.
--
-- Explicit EXECUTE grants PHASE 3.2c gives back to backend roles (postgres,
-- service_role, Laravel) are left in place: they only restate access those
-- roles already had through PUBLIC.
-- aclexplode() reports PUBLIC as grantee OID 0; it is emitted as the
-- keyword `public`, never as a quoted role name.
-- =====================================================================

with
-- Roles whose default privileges PHASE 3.2d may change (same set as 3.2d).
def_roles as (
  select distinct d.defaclrole as roleid
  from pg_catalog.pg_default_acl d
  left join pg_catalog.pg_namespace n on n.oid = d.defaclnamespace
  cross join lateral pg_catalog.aclexplode(d.defaclacl) a
  where (d.defaclnamespace = 0 or n.nspname = 'public')
    and d.defaclobjtype in ('r','S','f')
    and (a.grantee = 0 or pg_catalog.pg_get_userbyid(a.grantee) in ('anon','authenticated'))
  union
  select oid from pg_catalog.pg_roles where rolname = 'postgres'
),
alterable_roles as (
  select roleid, pg_catalog.pg_get_userbyid(roleid) as rolname
  from def_roles
  where pg_catalog.pg_has_role(current_user, roleid, 'USAGE')
),
-- SECURITY DEFINER functions PHASE 3.2c may restrict (same scope as 3.2c:
-- not the helpers, not extension members, owner the running role acts for).
secdef as (
  select p.oid, p.proacl, p.proowner,
         pg_catalog.format('public.%I(%s)', p.proname,
                           pg_catalog.pg_get_function_identity_arguments(p.oid)) as signature
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prosecdef
    and p.proname not in ('nuhris_current_employee_id', 'nuhris_current_user_id')
    and not exists (select 1 from pg_catalog.pg_depend d
                    where d.classid = 'pg_catalog.pg_proc'::pg_catalog.regclass
                      and d.objid = p.oid and d.deptype = 'e')
    and pg_catalog.pg_has_role(current_user, p.proowner, 'USAGE')
),
-- Objects PHASE 3 creates: do they exist NOW (before PHASE 3)?
helper_names(name, ord) as (values ('nuhris_current_user_id', 1), ('nuhris_current_employee_id', 2)),
helpers as (
  select h.name, h.ord, p.oid, p.proacl, p.proowner
  from helper_names h
  left join (pg_catalog.pg_proc p
             join pg_catalog.pg_namespace n on n.oid = p.pronamespace and n.nspname = 'public')
    on p.proname = h.name and p.pronargs = 0
),
version_table as (
  select pg_catalog.to_regclass('public.mobile_app_versions') as oid
),

-- ------------------------------------------------------------ header
manifest as (
  select 0 as ord, '' as k,
    '-- NUHRIS rollback generated ' || now()::text || ' by role ' || current_user || E'\n'
    || E'-- Pre-apply state recorded at generation time:\n'
    || (select pg_catalog.string_agg('--   public.' || h.name || '(): '
                                     || case when h.oid is null then 'ABSENT (created by PHASE 3; guarded drop below)'
                                             else 'EXISTED (definition restored below; never dropped)' end, E'\n' order by h.ord)
        from helpers h) || E'\n'
    || '--   public.mobile_app_versions: '
    || case when (select oid from version_table) is null
            then 'ABSENT (created by PHASE 3; kept; optional drop is commented out)'
            else 'EXISTED (never dropped)' end || E'\n'
    || E'--\n'
    || E'-- SECTION 2 OF THIS FILE RE-OPENS THE AUDITED EXPOSURE (anon/authenticated/\n'
    || E'-- PUBLIC privileges, RLS off where it was off, default privileges).\n'
    || E'-- Use only to recover from an outage caused by PHASE 3, with approval.\n'
    || E'-- To run it, put this line first, in the same session:\n'
    || E'--   set nuhris.allow_security_revert = ''yes'';\n'
    || E'-- Run as ' || current_user || E'. psql: psql -v ON_ERROR_STOP=1 -f <this file>\n'
    as stmt
),
interlock as (
  select 1 as ord, '' as k,
    E'begin;\n'
    || E'do $$ begin\n'
    || E'  if coalesce(pg_catalog.current_setting(''nuhris.allow_security_revert'', true), '''') <> ''yes'' then\n'
    || E'    raise exception ''REFUSED: this NUHRIS rollback re-opens the audited anon/authenticated/PUBLIC exposure. '
    || E'Run only with approval, after: set nuhris.allow_security_revert = ''''yes'''';'';\n'
    || E'  end if;\n'
    || E'end $$;' as stmt
),

-- ------------------------------------------------------------ SECTION 1
s1_label as (
  select 10 as ord, '' as k,
    E'\n-- =====================================================================\n'
    || E'-- SECTION 1 — REMOVE NUHRIS ADDITIONS (does not re-open anything)\n'
    || E'-- =====================================================================' as stmt
),
drop_new_policies as (
  -- Every policy PHASE 3 / PHASE 6 creates. Checked when the rollback RUNS,
  -- so policies on tables PHASE 3 creates (mobile_app_versions) are covered.
  select 20 as ord, t || '.' || p as k,
         pg_catalog.format(
           'do $$ begin if pg_catalog.to_regclass(%L) is not null then drop policy if exists %I on public.%I; end if; end $$;',
           'public.' || t, p, t) as stmt
  from (values
    ('users','nuhris_self_select'), ('employees','nuhris_self_select'),
    ('departments','nuhris_read'),
    ('attendance_records','nuhris_own_select'), ('leave_balances','nuhris_own_select'),
    ('leave_requests','nuhris_own_select'), ('employee_credentials','nuhris_own_select'),
    ('employee_schedule_submissions','nuhris_own_select'),
    ('employee_schedule_submissions','nuhris_own_insert'),
    ('employee_schedule_days','nuhris_own_select'),
    ('employee_schedule_days','nuhris_own_insert'),
    ('wfh_monitoring_submissions','nuhris_own_select'),
    ('wfh_monitoring_submissions','nuhris_own_insert'),
    ('announcement_notifications','nuhris_own_select'),
    ('announcement_notifications','nuhris_own_update'),
    ('announcement_notifications','nuhris_own_delete'),
    ('announcements','nuhris_notified_select'),
    ('privacy_notice_acknowledgments','nuhris_own_select'),
    ('privacy_notice_acknowledgments','nuhris_own_insert'),
    ('privacy_notice_acknowledgments','nuhris_own_update'),
    ('mobile_app_versions','nuhris_read')
  ) as v(t, p)
),
helper_restore as (
  -- Helper EXISTED before PHASE 3: restore its exact current definition
  -- (PHASE 3 replaces the body). Never dropped. Its ACL is restored in
  -- section 2 (it may include anon/PUBLIC).
  select 30 as ord, h.name as k,
         '-- restore pre-existing public.' || h.name || E'() definition\n'
         || pg_catalog.rtrim(pg_catalog.pg_get_functiondef(h.oid), E'\n') || ';'
         || E'\ncomment on function public.' || pg_catalog.quote_ident(h.name) || '() is '
         || coalesce(pg_catalog.quote_literal(pg_catalog.obj_description(h.oid, 'pg_proc')), 'null') || ';'
         as stmt
  from helpers h where h.oid is not null
),
helper_drop as (
  -- Helper was ABSENT before PHASE 3: drop it only if it is still marked as
  -- created by PHASE 3 and nothing depends on it. Otherwise keep + WARNING.
  select 40 + h.ord as ord, h.name as k,
         pg_catalog.format($t$do $$
declare v_oid oid := pg_catalog.to_regprocedure('public.%1$s()');
begin
  if v_oid is null then
    return;
  end if;
  if coalesce(pg_catalog.obj_description(v_oid, 'pg_proc'), '') not like 'NUHRIS\_HARDENING\_OBJECT:%%' then
    raise warning 'KEPT public.%1$s(): no NUHRIS marker, so it was not created by PHASE 3';
    return;
  end if;
  if exists (select 1 from pg_catalog.pg_depend d
             where d.refclassid = 'pg_catalog.pg_proc'::pg_catalog.regclass
               and d.refobjid = v_oid and d.deptype = 'n') then
    raise warning 'KEPT public.%1$s(): other objects depend on it';
    return;
  end if;
  drop function public.%1$s();
  raise notice 'dropped public.%1$s() (created by PHASE 3)';
end $$;$t$, h.name) as stmt
  from helpers h where h.oid is null
),
table_note as (
  select 50 as ord, 'tbl' as k,
    E'-- public.mobile_app_versions was ABSENT before PHASE 3 and is KEPT (no data loss;\n'
    || E'-- after section 2 it has RLS on and no anon/authenticated grants, i.e. unreachable).\n'
    || E'-- OPTIONAL, separate reviewed decision (deletes its rows):\n'
    || E'--   do $$ begin if pg_catalog.obj_description(pg_catalog.to_regclass(''public.mobile_app_versions''), ''pg_class'')\n'
    || E'--     like ''NUHRIS\\_HARDENING\\_OBJECT:%'' then drop table public.mobile_app_versions; end if; end $$;'
    as stmt
  where (select oid from version_table) is null
),

-- ------------------------------------------------------------ SECTION 2
s2_label as (
  select 100 as ord, '' as k,
    E'\n-- =====================================================================\n'
    || E'-- SECTION 2 — !!! SECURITY-REVERTING !!!\n'
    || E'-- Everything below restores the pre-PHASE-3 access rules, INCLUDING the\n'
    || E'-- audited exposure. Do not run casually. Fix forward afterwards.\n'
    || E'-- =====================================================================' as stmt
),
rls as (
  select 110 as ord, c.relname as k,
         case when not c.relrowsecurity then '-- !!! SECURITY-REVERTING: RLS was OFF on this table' || E'\n' else '' end
         || pg_catalog.format('alter table public.%I %s row level security;',
                c.relname, case when c.relrowsecurity then 'enable' else 'disable' end)
         || pg_catalog.format(' alter table public.%I %s row level security;',
                c.relname, case when c.relforcerowsecurity then 'force' else 'no force' end) as stmt
  from pg_catalog.pg_class c
  join pg_catalog.pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind in ('r', 'p')
),
old_policies_label as (
  select 119 as ord, '' as k,
    '-- !!! SECURITY-REVERTING: re-creates every policy that existed before PHASE 3 (including broad ones dropped in RUNBOOK step 4b)' as stmt
  where exists (select 1 from pg_catalog.pg_policies where schemaname = 'public')
),
old_policies as (
  select 120 as ord, tablename || policyname as k,
         pg_catalog.format('drop policy if exists %I on %I.%I; create policy %I on %I.%I as %s for %s to %s%s%s;',
           policyname, schemaname, tablename,
           policyname, schemaname, tablename, permissive, cmd,
           (select pg_catalog.string_agg(
                     case when r = 'public' then 'public' else pg_catalog.quote_ident(r) end, ', ')
              from pg_catalog.unnest(roles) r),
           case when qual is not null then ' using (' || qual || ')' else '' end,
           case when with_check is not null then ' with check (' || with_check || ')' else '' end) as stmt
  from pg_catalog.pg_policies
  where schemaname = 'public'
),
revoke_api as (
  -- Clears what PHASE 3 set (including its narrow re-grants), so the
  -- snapshot below is restored exactly. (REVOKE on a table also revokes
  -- that grantee's column privileges.)
  select 130 as ord, '' as k,
         E'-- clear PHASE 3 grants before restoring the snapshot\n'
         || 'revoke all on all tables in schema public from anon, authenticated, public;'
         || ' revoke all on all sequences in schema public from anon, authenticated, public;' as stmt
  union all
  select 131, ar.rolname,
         pg_catalog.format(
           'alter default privileges for role %1$I in schema public revoke all on tables from anon, authenticated, public;'
           || ' alter default privileges for role %1$I in schema public revoke all on sequences from anon, authenticated, public;'
           || ' alter default privileges for role %1$I in schema public revoke all on functions from anon, authenticated, public;'
           || ' alter default privileges for role %1$I revoke all on tables from anon, authenticated, public;'
           || ' alter default privileges for role %1$I revoke all on sequences from anon, authenticated, public;'
           || ' alter default privileges for role %1$I revoke all on functions from anon, authenticated, public;',
           ar.rolname)
  from alterable_roles ar
  union all
  select 132, s.signature,
         pg_catalog.format('revoke execute on function %s from public, anon, authenticated;', s.signature)
  from secdef s
),
table_grants_label as (
  select 149 as ord, '' as k,
    '-- !!! SECURITY-REVERTING: restores the original table/view/sequence grants of anon, authenticated and PUBLIC' as stmt
),
table_grants as (
  select 150 as ord,
         c.relname || '|' || a.privilege_type || '|' || a.grantee::text as k,
         pg_catalog.format('grant %s on %s public.%I to %s%s;',
           a.privilege_type,
           case when c.relkind = 'S' then 'sequence' else 'table' end,
           c.relname,
           case when a.grantee = 0 then 'public'
                else pg_catalog.quote_ident(pg_catalog.pg_get_userbyid(a.grantee)) end,
           case when a.is_grantable then ' with grant option' else '' end) as stmt
  from pg_catalog.pg_class c
  join pg_catalog.pg_namespace n on n.oid = c.relnamespace
  cross join lateral pg_catalog.aclexplode(c.relacl) a
  where n.nspname = 'public' and c.relkind in ('r', 'p', 'v', 'm', 'f', 'S')
    and (a.grantee = 0
         or pg_catalog.pg_get_userbyid(a.grantee) in ('anon', 'authenticated'))
),
column_grants_label as (
  select 159 as ord, '' as k,
    '-- !!! SECURITY-REVERTING: restores the original column grants of anon, authenticated and PUBLIC' as stmt
  where exists (select 1 from pg_catalog.pg_attribute att
                join pg_catalog.pg_class c on c.oid = att.attrelid
                join pg_catalog.pg_namespace n on n.oid = c.relnamespace
                where n.nspname = 'public' and att.attacl is not null)
),
column_grants as (
  select 160 as ord,
         c.relname || '|' || att.attname || '|' || a.privilege_type || '|' || a.grantee::text as k,
         pg_catalog.format('grant %s (%I) on table public.%I to %s%s;',
           a.privilege_type, att.attname, c.relname,
           case when a.grantee = 0 then 'public'
                else pg_catalog.quote_ident(pg_catalog.pg_get_userbyid(a.grantee)) end,
           case when a.is_grantable then ' with grant option' else '' end) as stmt
  from pg_catalog.pg_attribute att
  join pg_catalog.pg_class c on c.oid = att.attrelid
  join pg_catalog.pg_namespace n on n.oid = c.relnamespace
  cross join lateral pg_catalog.aclexplode(att.attacl) a
  where n.nspname = 'public' and att.attnum > 0 and not att.attisdropped
    and (a.grantee = 0
         or pg_catalog.pg_get_userbyid(a.grantee) in ('anon', 'authenticated'))
),
default_privs_label as (
  select 169 as ord, '' as k,
    '-- !!! SECURITY-REVERTING: restores default privileges that expose FUTURE tables/sequences/functions to anon, authenticated and PUBLIC' as stmt
),
default_privs as (
  -- Global (defaclnamespace = 0) and schema-public defaults of every
  -- alterable role, for tables, sequences and functions.
  select 170 as ord,
         pg_catalog.pg_get_userbyid(d.defaclrole) || '|' || coalesce(n.nspname, '') || '|'
         || d.defaclobjtype::text || '|' || a.privilege_type || '|' || a.grantee::text as k,
         pg_catalog.format('alter default privileges for role %I%s grant %s on %s to %s%s;',
           pg_catalog.pg_get_userbyid(d.defaclrole),
           case when n.nspname is null then '' else ' in schema public' end,
           a.privilege_type,
           case d.defaclobjtype when 'r' then 'tables' when 'S' then 'sequences' else 'functions' end,
           case when a.grantee = 0 then 'public'
                else pg_catalog.quote_ident(pg_catalog.pg_get_userbyid(a.grantee)) end,
           case when a.is_grantable then ' with grant option' else '' end) as stmt
  from pg_catalog.pg_default_acl d
  join alterable_roles ar on ar.roleid = d.defaclrole
  left join pg_catalog.pg_namespace n on n.oid = d.defaclnamespace
  cross join lateral pg_catalog.aclexplode(d.defaclacl) a
  where (n.nspname is null or n.nspname = 'public')
    and d.defaclobjtype in ('r', 'S', 'f')
    and (a.grantee = 0
         or pg_catalog.pg_get_userbyid(a.grantee) in ('anon', 'authenticated'))
  union all
  -- No GLOBAL function row = PostgreSQL's built-in default (EXECUTE to
  -- PUBLIC). The revoke above removes it, so restore it explicitly.
  select 171, ar.rolname || '|builtin-f',
         pg_catalog.format('alter default privileges for role %I grant execute on functions to public;', ar.rolname)
  from alterable_roles ar
  where not exists (select 1 from pg_catalog.pg_default_acl d
                    where d.defaclrole = ar.roleid and d.defaclnamespace = 0
                      and d.defaclobjtype = 'f')
),
function_grants_label as (
  select 174 as ord, '' as k,
    '-- !!! SECURITY-REVERTING: restores EXECUTE of PUBLIC/anon/authenticated on SECURITY DEFINER functions (they run with their owner''s rights)' as stmt
  where exists (select 1 from secdef)
),
function_grants as (
  select 175 as ord, s.signature || '|' || coalesce(a.grantee::text, '0') as k,
         pg_catalog.format('grant execute on function %s to %s%s;', s.signature,
           case when a.grantee = 0 then 'public'
                else pg_catalog.quote_ident(pg_catalog.pg_get_userbyid(a.grantee)) end,
           case when a.is_grantable then ' with grant option' else '' end) as stmt
  from secdef s
  -- NULL proacl = built-in default (EXECUTE to PUBLIC); acldefault() gives
  -- exactly that, so it is restored as an explicit PUBLIC grant.
  cross join lateral pg_catalog.aclexplode(
    coalesce(s.proacl, pg_catalog.acldefault('f', s.proowner))) a
  where a.privilege_type = 'EXECUTE'
    and (a.grantee = 0 or pg_catalog.pg_get_userbyid(a.grantee) in ('anon', 'authenticated'))
),
helper_acl as (
  -- ACL of helpers that EXISTED before PHASE 3.
  select 176 as ord, h.name as k,
         '-- !!! SECURITY-REVERTING (if anon/PUBLIC appear): original EXECUTE grants of public.' || h.name || E'()\n'
         || pg_catalog.format('revoke all on function public.%I() from public, anon, authenticated;', h.name)
         || coalesce((select pg_catalog.string_agg(
                        pg_catalog.format(' grant execute on function public.%I() to %s;', h.name,
                          case when a.grantee = 0 then 'public'
                               else pg_catalog.quote_ident(pg_catalog.pg_get_userbyid(a.grantee)) end), '')
                      from pg_catalog.aclexplode(coalesce(h.proacl, pg_catalog.acldefault('f', h.proowner))) a
                      where a.privilege_type = 'EXECUTE'
                        and (a.grantee = 0 or pg_catalog.pg_get_userbyid(a.grantee) in ('anon', 'authenticated'))), '')
         as stmt
  from helpers h where h.oid is not null
),
footer as (
  select 999 as ord, '' as k, 'commit;' as stmt
)
select pg_catalog.string_agg(stmt, E'\n' order by ord, k) || E'\n' as rollback_sql
from (
  select ord, k, stmt from manifest
  union all select ord, k, stmt from interlock
  union all select ord, k, stmt from s1_label
  union all select ord, k, stmt from drop_new_policies
  union all select ord, k, stmt from helper_restore
  union all select ord, k, stmt from helper_drop
  union all select ord, k, stmt from table_note
  union all select ord, k, stmt from s2_label
  union all select ord, k, stmt from rls
  union all select ord, k, stmt from old_policies_label
  union all select ord, k, stmt from old_policies
  union all select ord, k, stmt from revoke_api
  union all select ord, k, stmt from table_grants_label
  union all select ord, k, stmt from table_grants
  union all select ord, k, stmt from column_grants_label
  union all select ord, k, stmt from column_grants
  union all select ord, k, stmt from default_privs_label
  union all select ord, k, stmt from default_privs
  union all select ord, k, stmt from function_grants_label
  union all select ord, k, stmt from function_grants
  union all select ord, k, stmt from helper_acl
  union all select ord, k, stmt from footer
) s;
