-- =====================================================================
-- NUHRIS Supabase hardening: Row Level Security + least-privilege grants
-- =====================================================================
-- Fixes MASVS-AUTH findings from the mobile security assessment:
--   * the public anon key could read employees, attendance, leave,
--     credentials, Laravel sessions (541 rows), password_reset_tokens,
--     admin_audit_logs, cache, admin_configs, migrations ...
--   * anon held UPDATE privileges on users/employees/attendance/leave.
--
-- NOT APPLIED AUTOMATICALLY. Review, then run in the Supabase SQL editor
-- (or psql as the project owner). It changes access rules only; it does not
-- modify or delete any rows. Run STEP 0 first and read its output.
--
-- Who is affected:
--   * anon (public key)       -> no table access except mobile_app_versions.
--   * authenticated (mobile)  -> only the signed-in employee's own rows,
--                                only the columns the app uses.
--   * Laravel web portal      -> unaffected IF it connects as the table owner
--                                / a BYPASSRLS role (`postgres`), which
--                                bypasses RLS. Verify in STEP 0.
--   * service_role key        -> unaffected (bypasses RLS).
-- =====================================================================


-- ---------------------------------------------------------------------
-- STEP 0 (read-only checks) — run these first, separately.
-- ---------------------------------------------------------------------
-- 0a. Table owners: Laravel's DB user must own these tables (or have
--     BYPASSRLS), otherwise enabling RLS would also restrict the web portal.
--   select tablename, tableowner, rowsecurity from pg_tables
--   where schemaname = 'public' order by tablename;
--   select rolname, rolbypassrls from pg_roles where rolname = 'postgres';
--
-- 0b. Existing policies (policies are OR-ed: an old permissive policy would
--     defeat the new ones — drop such policies after reviewing them):
--   select schemaname, tablename, policyname, roles, cmd, qual, with_check
--   from pg_policies where schemaname in ('public', 'storage')
--   order by schemaname, tablename;
--
-- 0c. Type of employees.auth_id (the helper compares it as text):
--   select data_type from information_schema.columns
--   where table_schema = 'public' and table_name = 'employees'
--     and column_name = 'auth_id';


begin;

-- ---------------------------------------------------------------------
-- STEP 1. Identity helpers (SECURITY DEFINER: read users/employees without
-- recursing into their own RLS). Identity comes only from the verified
-- Supabase Auth JWT (auth.uid() / auth.jwt()), never from client input.
-- ---------------------------------------------------------------------
create or replace function public.nuhris_current_user_id()
returns bigint
language sql stable security definer
set search_path = public
as $$
  select u.id
  from public.users u
  where lower(u.email) = lower(auth.jwt() ->> 'email')
  limit 1
$$;

-- Prefers the explicit employees.auth_id link; falls back to the Auth email
-- (accounts are provisioned by the web portal through the Admin API — this
-- is only safe once public sign-up is disabled, see STEP 6).
create or replace function public.nuhris_current_employee_id()
returns bigint
language sql stable security definer
set search_path = public
as $$
  select e.id
  from public.employees e
  where e.deleted_at is null
    and (e.auth_id::text = auth.uid()::text
         or lower(e.email) = lower(auth.jwt() ->> 'email'))
  order by (e.auth_id::text = auth.uid()::text) desc nulls last, e.id
  limit 1
$$;

revoke all on function public.nuhris_current_user_id() from public, anon;
revoke all on function public.nuhris_current_employee_id() from public, anon;
grant execute on function public.nuhris_current_user_id() to authenticated;
grant execute on function public.nuhris_current_employee_id() to authenticated;


-- ---------------------------------------------------------------------
-- STEP 2. Default deny: RLS on every public table, no blanket grants.
-- Tables without a policy below (sessions, cache, jobs, failed_jobs,
-- job_batches, cache_locks, password_reset_tokens, migrations,
-- admin_configs, admin_audit_logs, academic_calendar_entries, ...) become
-- unreachable through the Supabase API for anon and authenticated.
-- ---------------------------------------------------------------------
do $$
declare t record;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I enable row level security', t.tablename);
  end loop;
end $$;

revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
-- Future tables created by the owner are not exposed automatically.
alter default privileges in schema public revoke all on tables from anon, authenticated;
alter default privileges in schema public revoke all on sequences from anon, authenticated;


-- ---------------------------------------------------------------------
-- STEP 3. Least-privilege read access for the signed-in employee.
-- Column lists match lib/services/api_client.dart (no password,
-- remember_token, phone or address).
-- ---------------------------------------------------------------------
grant select (id, name, email, user_type) on public.users to authenticated;
drop policy if exists nuhris_self_select on public.users;
create policy nuhris_self_select on public.users
  for select to authenticated
  using (id = public.nuhris_current_user_id());

grant select (id, employee_id, first_name, last_name, email, department_id,
              position, employment_type, ranking, status, hire_date,
              official_time_in, official_time_out, auth_id,
              profilephoto_path, deleted_at)
  on public.employees to authenticated;
drop policy if exists nuhris_self_select on public.employees;
create policy nuhris_self_select on public.employees
  for select to authenticated
  using (id = public.nuhris_current_employee_id());

grant select on public.departments to authenticated;
drop policy if exists nuhris_read on public.departments;
create policy nuhris_read on public.departments
  for select to authenticated using (true);

-- Tables owned by one employee through employee_id (read-only on mobile).
do $$
declare t text;
begin
  foreach t in array array[
    'attendance_records', 'leave_balances', 'leave_requests',
    'employee_credentials', 'employee_schedule_submissions',
    'wfh_monitoring_submissions'
  ] loop
    execute format('grant select on public.%I to authenticated', t);
    execute format('drop policy if exists nuhris_own_select on public.%I', t);
    execute format(
      'create policy nuhris_own_select on public.%I for select to authenticated
         using (employee_id = public.nuhris_current_employee_id())', t);
  end loop;
end $$;

grant select on public.employee_schedule_days to authenticated;
drop policy if exists nuhris_own_select on public.employee_schedule_days;
create policy nuhris_own_select on public.employee_schedule_days
  for select to authenticated
  using (exists (
    select 1 from public.employee_schedule_submissions s
    where s.id = schedule_submission_id
      and s.employee_id = public.nuhris_current_employee_id()));


-- ---------------------------------------------------------------------
-- STEP 4. The only writes the mobile app performs. Employees can create
-- their own *pending* submissions; they can never approve, edit or delete.
-- ---------------------------------------------------------------------
grant insert on public.employee_schedule_submissions to authenticated;
drop policy if exists nuhris_own_insert on public.employee_schedule_submissions;
create policy nuhris_own_insert on public.employee_schedule_submissions
  for insert to authenticated
  with check (employee_id = public.nuhris_current_employee_id()
              and submitted_by = public.nuhris_current_user_id()
              and status = 'pending'
              and reviewed_at is null);

grant insert on public.employee_schedule_days to authenticated;
drop policy if exists nuhris_own_insert on public.employee_schedule_days;
create policy nuhris_own_insert on public.employee_schedule_days
  for insert to authenticated
  with check (exists (
    select 1 from public.employee_schedule_submissions s
    where s.id = schedule_submission_id
      and s.employee_id = public.nuhris_current_employee_id()
      and s.status = 'pending'));

grant insert on public.wfh_monitoring_submissions to authenticated;
drop policy if exists nuhris_own_insert on public.wfh_monitoring_submissions;
create policy nuhris_own_insert on public.wfh_monitoring_submissions
  for insert to authenticated
  with check (employee_id = public.nuhris_current_employee_id()
              and submitted_by = public.nuhris_current_user_id()
              and status = 'pending'
              and reviewed_by is null
              and reviewed_at is null);

-- Notifications: read, mark read (only these two columns), clear own.
grant select on public.announcement_notifications to authenticated;
grant update (is_read, read_at) on public.announcement_notifications to authenticated;
grant delete on public.announcement_notifications to authenticated;
drop policy if exists nuhris_own_select on public.announcement_notifications;
drop policy if exists nuhris_own_update on public.announcement_notifications;
drop policy if exists nuhris_own_delete on public.announcement_notifications;
create policy nuhris_own_select on public.announcement_notifications
  for select to authenticated using (user_id = public.nuhris_current_user_id());
create policy nuhris_own_update on public.announcement_notifications
  for update to authenticated
  using (user_id = public.nuhris_current_user_id())
  with check (user_id = public.nuhris_current_user_id());
create policy nuhris_own_delete on public.announcement_notifications
  for delete to authenticated using (user_id = public.nuhris_current_user_id());

-- Announcements the employee was notified about.
grant select on public.announcements to authenticated;
drop policy if exists nuhris_notified_select on public.announcements;
create policy nuhris_notified_select on public.announcements
  for select to authenticated
  using (exists (
    select 1 from public.announcement_notifications n
    where n.announcement_id = announcements.id
      and n.user_id = public.nuhris_current_user_id()));

-- Privacy Notice acknowledgment (same record the web writes).
grant select, insert on public.privacy_notice_acknowledgments to authenticated;
grant update (acknowledged_at, updated_at) on public.privacy_notice_acknowledgments to authenticated;
drop policy if exists nuhris_own_select on public.privacy_notice_acknowledgments;
drop policy if exists nuhris_own_insert on public.privacy_notice_acknowledgments;
drop policy if exists nuhris_own_update on public.privacy_notice_acknowledgments;
create policy nuhris_own_select on public.privacy_notice_acknowledgments
  for select to authenticated using (user_id = public.nuhris_current_user_id());
create policy nuhris_own_insert on public.privacy_notice_acknowledgments
  for insert to authenticated with check (user_id = public.nuhris_current_user_id());
create policy nuhris_own_update on public.privacy_notice_acknowledgments
  for update to authenticated
  using (user_id = public.nuhris_current_user_id())
  with check (user_id = public.nuhris_current_user_id());

-- Sequences needed by the inserts above.
do $$
declare t text; seq text;
begin
  foreach t in array array[
    'employee_schedule_submissions', 'employee_schedule_days',
    'wfh_monitoring_submissions', 'privacy_notice_acknowledgments'
  ] loop
    seq := pg_get_serial_sequence('public.' || t, 'id');
    if seq is not null then
      execute format('grant usage, select on sequence %s to authenticated', seq);
    end if;
  end loop;
end $$;


-- ---------------------------------------------------------------------
-- STEP 5. Minimum-version policy for update enforcement (MASVS-CODE-2).
-- Readable before login; only the owner/service role can change it.
-- ---------------------------------------------------------------------
create table if not exists public.mobile_app_versions (
  platform            text primary key,
  min_version_code    integer not null,
  latest_version_name text,
  update_url          text check (update_url is null or update_url like 'https://%'),
  message             text,
  updated_at          timestamptz not null default now()
);
alter table public.mobile_app_versions enable row level security;
grant select on public.mobile_app_versions to anon, authenticated;
drop policy if exists nuhris_read on public.mobile_app_versions;
create policy nuhris_read on public.mobile_app_versions
  for select to anon, authenticated using (true);

-- Require the security release (versionCode 2 = 1.1.0+2). Set update_url to
-- the HTTPS page where employees download the official APK.
insert into public.mobile_app_versions (platform, min_version_code, latest_version_name, update_url)
values ('android', 2, '1.1.0', null)
on conflict (platform) do update
  set min_version_code = excluded.min_version_code,
      latest_version_name = excluded.latest_version_name,
      updated_at = now();

commit;


-- ---------------------------------------------------------------------
-- STEP 6. Supabase Auth settings (Dashboard → Authentication), not SQL:
--   * Sign In / Providers → Email: turn OFF "Allow new users to sign up".
--     Accounts are created by the web portal through the Admin API.
--     (Currently disable_signup=false and mailer_autoconfirm=true: anyone can
--     self-register a confirmed account with any email.)
--   * Keep "Confirm email" ON for any remaining sign-up path.
-- ---------------------------------------------------------------------


-- ---------------------------------------------------------------------
-- STEP 7. Storage bucket "credentials" (review STEP 0b output first).
-- Employees may sign URLs for their own folder and upload WFH files only
-- under employee-<id>/wfh-monitoring/. Drop any broader existing policy
-- for anon/authenticated on this bucket after review.
-- ---------------------------------------------------------------------
-- drop policy if exists nuhris_own_read on storage.objects;
-- create policy nuhris_own_read on storage.objects
--   for select to authenticated
--   using (bucket_id = 'credentials'
--          and ((storage.foldername(name))[1] = 'employee-' || public.nuhris_current_employee_id()
--               or (storage.foldername(name))[1] = auth.uid()::text));
-- drop policy if exists nuhris_own_wfh_upload on storage.objects;
-- create policy nuhris_own_wfh_upload on storage.objects
--   for insert to authenticated
--   with check (bucket_id = 'credentials'
--               and name like 'employee-' || public.nuhris_current_employee_id() || '/wfh-monitoring/%');


-- ---------------------------------------------------------------------
-- Emergency rollback (restores API access; reintroduces the exposure):
--   do $$ declare t record; begin
--     for t in select tablename from pg_tables where schemaname='public' loop
--       execute format('alter table public.%I disable row level security', t.tablename);
--     end loop; end $$;
-- ---------------------------------------------------------------------
