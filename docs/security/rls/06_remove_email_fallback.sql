-- =====================================================================
-- PHASE 6 — REMOVE THE EMAIL IDENTITY FALLBACK (later, separate change)
-- =====================================================================
-- Run only when rls/02_auth_id_linking.sql reports LINKED_OK for EVERY
-- active employee. The transaction verifies that itself and aborts
-- otherwise, so no employee is locked out by this step.
-- Rollback: re-run section 3.1 of supabase_rls_hardening.sql.
-- =====================================================================

begin;

do $$
declare v_bad text;
begin
  select string_agg(e.id::text, ', ') into v_bad
  from public.employees e
  left join auth.users u on u.id::text = e.auth_id::text
  where e.deleted_at is null
    and (e.auth_id is null
         or u.id is null
         or u.email_confirmed_at is null
         or pg_catalog.lower(u.email) <> pg_catalog.lower(e.email));
  if v_bad is not null then
    raise exception 'ABORT: employees not cleanly linked (employees.id): %', v_bad;
  end if;

  select string_agg(auth_id::text, ', ') into v_bad
  from (select auth_id from public.employees
        where deleted_at is null and auth_id is not null
        group by auth_id having count(*) > 1) d;
  if v_bad is not null then
    raise exception 'ABORT: auth_id shared by several employees: %', v_bad;
  end if;
end $$;

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
    and e.auth_id::text = (select auth.uid())::text
  limit 1
$$;

commit;

-- Note: NEW employees must then be linked at account creation (web portal
-- stores the Auth user id in employees.auth_id), otherwise they cannot use
-- the mobile app.
