-- =====================================================================
-- PHASE 2 — employees.auth_id LINKING REPORT (READ-ONLY)
-- =====================================================================
-- Goal: every active employee is linked to exactly one Supabase Auth
-- account through employees.auth_id, so PHASE 6 can drop the email-based
-- identity fallback.
--
-- Facts at review time (count-only API check, 2026-10-09): 3 employees,
-- 2 without auth_id. The web portal creates Auth accounts (Admin API) but
-- never writes employees.auth_id; only the old mobile app (v1.0.0) did, from
-- the client. That client write was removed in v1.1.0.
--
-- Nothing in this file links accounts automatically. A link is a manual,
-- per-employee decision after HR verifies the person (see the template).
-- =====================================================================


-- 2a. Link status of every active employee.
with emp as (
  select e.id, e.employee_id, e.email, e.auth_id::text as auth_id
  from public.employees e
  where e.deleted_at is null
),
by_email as (   -- Auth accounts whose email equals the employee's email
  select emp.id as emp_id,
         count(u.id)                                        as email_matches,
         count(u.id) filter (where u.email_confirmed_at is not null) as confirmed_matches,
         min(u.id::text)                                    as candidate_auth_id
  from emp
  left join auth.users u on lower(u.email) = lower(emp.email)
  group by emp.id
),
dup as (
  select auth_id, count(*) as n from emp where auth_id is not null group by auth_id
)
select emp.id                         as employee_pk,
       emp.employee_id                as employee_no,
       emp.email                      as employee_email,
       emp.auth_id                    as current_auth_id,
       linked.email                   as linked_auth_email,
       linked.email_confirmed_at      as linked_confirmed_at,
       linked.last_sign_in_at         as linked_last_sign_in,
       b.email_matches, b.confirmed_matches, b.candidate_auth_id,
       exists (select 1 from public.users pu
               where lower(pu.email) = lower(emp.email)) as has_users_row,
       case
         when emp.auth_id is not null and coalesce(d.n, 0) > 1 then 'DUPLICATE_AUTH_ID'
         when emp.auth_id is not null and linked.id is null    then 'LINKED_TO_MISSING_ACCOUNT'
         when emp.auth_id is not null
              and lower(linked.email) <> lower(emp.email)      then 'LINKED_EMAIL_MISMATCH'
         when emp.auth_id is not null
              and linked.email_confirmed_at is null            then 'LINKED_UNCONFIRMED'
         when emp.auth_id is not null                          then 'LINKED_OK'
         when b.confirmed_matches = 1                          then 'UNLINKED_ONE_CANDIDATE'
         when b.email_matches = 0                              then 'UNLINKED_NO_AUTH_ACCOUNT'
         else                                                       'UNLINKED_NEEDS_REVIEW'
       end as status
from emp
left join auth.users linked on linked.id::text = emp.auth_id
left join by_email b on b.emp_id = emp.id
left join dup d on d.auth_id = emp.auth_id
order by status, emp.id;

-- What each status means / what to do:
--   LINKED_OK                  nothing.
--   LINKED_EMAIL_MISMATCH      HR confirms which account belongs to the
--                              employee (email may have changed); fix by hand.
--   LINKED_TO_MISSING_ACCOUNT  account deleted; web must recreate it, then link.
--   LINKED_UNCONFIRMED         account must be confirmed before PHASE 6.
--   DUPLICATE_AUTH_ID          two employees share one account: must be
--                              resolved before anything else.
--   UNLINKED_ONE_CANDIDATE     exactly one confirmed account has the same
--                              email. HR verifies it is this employee (e.g.
--                              last_sign_in, created by the web), then links
--                              it with the template below.
--   UNLINKED_NO_AUTH_ACCOUNT   employee has no login yet; create it from the
--                              web portal, then re-run this report.
--   UNLINKED_NEEDS_REVIEW      several / unconfirmed candidates: manual review.


-- 2b. Auth accounts that match NO employee (e.g. created by the former open
--     sign-up). Review and remove unknown accounts from the dashboard.
select u.id, u.email, u.created_at, u.last_sign_in_at, u.email_confirmed_at,
       u.raw_app_meta_data ->> 'provider' as provider
from auth.users u
where not exists (select 1 from public.employees e
                  where lower(e.email) = lower(u.email))
  and not exists (select 1 from public.users pu
                  where lower(pu.email) = lower(u.email))
order by u.created_at;


-- 2c. MANUAL LINK TEMPLATE — one employee at a time, ONLY after HR has
--     verified the person. Commented out on purpose. It changes only
--     employees.auth_id for one row, and only if that row is still unlinked
--     and the account's confirmed email equals the employee's email.
--
-- update public.employees e
--    set auth_id = '<auth-user-uuid>'
--  where e.id = <employee_pk>
--    and e.auth_id is null
--    and e.deleted_at is null
--    and exists (select 1 from auth.users u
--                where u.id::text = '<auth-user-uuid>'
--                  and lower(u.email) = lower(e.email)
--                  and u.email_confirmed_at is not null);
-- -- expect: UPDATE 1. Anything else -> stop and review.
--
-- Permanent fix (web portal, outside this repository): when
-- SupabaseAuthSyncService creates an Auth user, store the returned user id
-- in employees.auth_id, so new employees are linked at creation.
