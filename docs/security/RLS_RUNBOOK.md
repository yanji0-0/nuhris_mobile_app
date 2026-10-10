# NUHRIS Supabase privilege and RLS hardening: runbook

Fixes the finding that the public anon key (and any signed-in user) can read
and change HR data through excessive PostgreSQL privileges held by `anon`,
`authenticated` and `PUBLIC`.

**Status: nothing in this repository has been executed against the live
database. The live database is NOT fixed until steps 6 and 7 below are done
and `05_verify.sql` reports the result required in "Definition of fixed".**

## Root cause

1. **Supabase default privileges.** The `postgres` role (and
   `supabase_admin`) carry default ACLs such as
   `alter default privileges ... in schema public grant all on tables/sequences/functions to anon, authenticated`.
   Every table, sequence and function Laravel's migrations created
   therefore received *explicit* grants of all privileges (`SELECT`,
   `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, `REFERENCES`, `TRIGGER`,
   `MAINTAIN`; sequences `SELECT`, `UPDATE`, `USAGE`) to both API roles.
   Confirmed live: 25 table objects and 20 sequences per role.
2. **RLS was not relied on / not complete**, so those grants were the only
   gate, and they were wide open.
3. **No `PUBLIC` relation grants were involved** (confirmed live). Earlier
   checks that expanded `acldefault()` could make built-in defaults look like
   grants; the scripts now report only stored ACL entries as "explicit" and
   label built-in defaults separately.
4. **`enqueue_announcement_notifications()`** is `SECURITY DEFINER`, owned by
   `postgres`, `search_path=public`, executable by `PUBLIC`/anon/authenticated.
   No trigger or function uses it (live check). Secondary finding.
5. **The previous apply script could not have succeeded.** Its self-check
   aborted on any `SECURITY DEFINER` function the API roles could execute,
   but nothing revoked that `EXECUTE`. It also changed only `postgres`'s
   table/sequence defaults (not functions). It also did not account for the
   *grantor*: a non-superuser `REVOKE` silently leaves entries granted by
   another role (for example `supabase_admin`).

## Files

| File | Phase | Changes the database? |
|---|---|---|
| `rls/00_preflight_checks.sql` | 0. Preflight | No (SELECT only) |
| `rls/00b_creators_and_functions.sql` | 0b. Owners, defaults, functions | No |
| `rls/01_generate_rollback.sql` | 1. Rollback snapshot | No (returns rollback SQL as text) |
| `rls/02_auth_id_linking.sql` | 2. `auth_id` report | No (manual template is commented out) |
| `rls/03a_public_grants_remediation.sql` | 2b. **Review of every planned privilege change** (R1–R6) | No |
| `supabase_rls_hardening.sql` | 3. Apply | **Yes**: one transaction, preconditions, self-check |
| (Supabase dashboard) | 4. Auth settings | **Yes**: settings only |
| `rls/05_verify.sql` + `retest_anon_access.sh` | 5. Verify (PASS/FAIL) | No (simulation block always rolls back) |
| `rls/06_remove_email_fallback.sql` | 6. Later | **Yes**: one function; self-checks first |
| `rls/07_storage_review.sql` | 7. Storage | No |
| `../../tool/check_rls_allowlists.sh` | Repository check | No (compares the allowlist in 3 files) |
| `supabase_rls_hardening.v1.backup.sql` | Previous revision | Kept for reference only; do not run |

## What the apply script does (revision 3)

| Section | Change |
|---|---|
| 3.00 | Temporary config (`nuhris_cfg`: Laravel role, opt-in toggle), the allowlist, a baseline of the backend roles' current privileges, and the list of `SECURITY DEFINER` functions to restrict |
| 3.0 a–g | Existing checks: columns exist, no FORCE RLS, Laravel role is owner or BYPASSRLS, `auth.users` readable, no foreign permissive policies, no duplicate `auth_id`, no `PUBLIC` relation grants |
| 3.0 h | **New.** Aborts if any anon/authenticated ACL entry outside the allowlist cannot be revoked by the running role (grantor check). Also aborts if a `SECURITY DEFINER` function to restrict is owned by a role it cannot act for |
| 3.0 i | **New.** `service_role` must bypass RLS |
| 3.0 j | **New.** anon/authenticated own nothing in `public` and are members of no role. Memberships are reported, never revoked |
| 3.0 k | **New.** Laravel role is not an API role |
| 3.0 l | **New.** No policy, column default, view or API-callable function depends on a function whose `EXECUTE` is restricted (triggers are fine) |
| 3.0 m | **New.** Aborts if a helper function or `mobile_app_versions` exists **without** the `NUHRIS_HARDENING_OBJECT` marker, so the script never overwrites someone else's object |
| 3.0 n | **New (2026-10-10).** Aborts if an alterable owner has a *configured* default privilege granting tables/sequences (any scope) or functions (schema `public`) to `PUBLIC`. Nothing is revoked from `PUBLIC` before someone has established who relies on it (03a R4 `BLOCKER (3.0n)` gives the manual statement). The built-in global PUBLIC `EXECUTE` stays governed by the toggle (E2) |
| 3.0 o | **New (2026-10-10).** Aborts if a SECURITY DEFINER function that can be *called* (not a trigger/event-trigger function) is executable by PUBLIC/anon/authenticated. 03a R3 lists `roles_relying_on_public_execute`; revoke it manually after review. Trigger functions stay in 3.2c: no role can call them, so no role can rely on their `EXECUTE` |
| 3.1 | Identity helpers; marked with `COMMENT 'NUHRIS_HARDENING_OBJECT: ...'` (3.5 marks `mobile_app_versions` the same way) |
| 3.7 | **New.** Final result row after `commit`: `NOT APPLIED` / `APPLIED, NOT SECURE: BLOCKED (owners)` / `APPLIED: run 05_verify` |
| 3.2a | RLS on every public table (only where it is off; each change reported) |
| 3.2b | **Revokes every table, view, column and sequence privilege** of anon/authenticated, per object, then any leftover column entries |
| 3.2c | **Revokes `EXECUTE` from PUBLIC/anon/authenticated** on in-scope `SECURITY DEFINER` **trigger** functions (3.0o leaves nothing else in scope). Re-grants it only to backend roles (Laravel, postgres, service_role) that held it. No `DROP` |
| 3.2d | **Default privileges**: for every owner role with offending defaults that the running role may alter (plus `postgres`), revokes tables/sequences/functions from anon/authenticated/PUBLIC (schema `public` and global). Built-in global PUBLIC `EXECUTE` on functions is kept unless the toggle is on. Non-alterable owners → `WARNING` |
| 3.3–3.5 | Grant back only the allowlist, own-row policies, `mobile_app_versions` (unchanged) |
| 3.6 | Self-check on **effective** privileges (inherited, PUBLIC, owner) against the allowlist, no grant options, no `CREATE`, no executable `SECURITY DEFINER`, **backend roles lost nothing**, RLS on, no alterable default exposing new objects |

No `CASCADE`, no `DROP TABLE`/`DROP FUNCTION`, no data change except one
`mobile_app_versions` row, no role-membership change.

## Execution order

1. **Roll out app v1.1.0** to every employee (uninstall v1.0.0 first; the
   signing key changed). v1.0.0 uses `select('*')` and stops working after
   step 6. *Status 2026-10-10: v1.1.0+2 exists only as uncommitted source
   (the committed `HEAD` is 1.0.0+1 with 8 `select('*')` calls); no
   v1.1.0 APK has been built or distributed.* v1.1.0 also works against the
   current, unhardened database (narrower column lists; a missing
   `mobile_app_versions` table is treated as "no policy"), so it can and
   must ship **before** step 6. Review of these scripts can finish first;
   the database change cannot.
2. **Preflight**: run `rls/00_preflight_checks.sql` and
   `rls/00b_creators_and_functions.sql` one query at a time. Required:
   - 0a: `service_role.rolbypassrls = true`.
   - 0b / 0u: `force_rls = false` everywhere; every table owned by Laravel's
     role, **or** that role has `rolbypassrls = true` (0a).
   - 0f: confirm Laravel's role. The web portal source is **not in this
     repository**, so it is unverified here. Run
     `php artisan tinker --execute="dump(DB::select('select current_user, session_user'))"`
     in the web project. If it is not `postgres`, set it in `nuhris_cfg`
     (3.00) and in `cfg` of `03a` R5 and `05_verify.sql`.
   - 0d / 0e: every row `revocable_by_current_role = true`.
   - 0g: no rows. 0i: `true`. 0j: note unconfirmed accounts.
   - 0o: first query: no row with direction `API role is member of X`;
     second query: no rows.
   - 0p: every row has a non-empty `sources` value.
   - 0c: list every non-`nuhris_*` policy on public tables.
3. **Rollback snapshot**: run `rls/01_generate_rollback.sql` **as the role
   that will run step 6, immediately before step 6** (regenerate it if
   anything changed in between). Save the single `rollback_sql` value as
   `docs/security/rls/rollback_<YYYY-MM-DD>.sql`. Check:
   - the header manifest lists each helper and `mobile_app_versions` as
     `ABSENT` or `EXISTED`, matching preflight 0k;
   - there is no statement-level `drop function` / `drop table`. Helpers
     are dropped only inside guarded `do $$` blocks, and the table drop
     appears only as a comment;
   - SECTION 2 (`!!! SECURITY-REVERTING`) contains the `grant` lines for
     anon/authenticated on tables and sequences, `grant execute on function
     public.enqueue_announcement_notifications()`, and
     `alter default privileges ... grant` lines (proof the snapshot is
     complete).
   Do not continue without this file. **Never run it except under
   "Rollback" below.**
4. **Review the proposed changes**: run `rls/03a_public_grants_remediation.sql`
   (R1–R6, one at a time). Required:
   - No `planned_action` starting with `BLOCKER` in R2, R3 or R4. Each has a
     stated fix (the grantor or owner must revoke it, or a manual decision).
     For R3 `BLOCKER (3.0o)`, check every role in
     `roles_relying_on_public_execute`. Supabase system roles appear there
     because they hold PUBLIC's privileges; that alone does not make them
     callers. **Exception: if the function is configured as an Auth hook**
     (Dashboard → Authentication → Hooks, e.g. a custom access token hook),
     `supabase_auth_admin` *is* its caller, and revoking PUBLIC without
     `grant execute on function … to supabase_auth_admin` first breaks
     sign-in. The same applies to functions called by Storage or Realtime
     policies, or by column defaults. Grant `EXECUTE` explicitly to every
     real caller, then revoke from PUBLIC/anon/authenticated. For R4 `BLOCKER (3.0n)`, find what creates objects as
     that owner and needs PUBLIC access to them; then run the
     `equivalent_statement` or record why the entry stays (3.0n then keeps
     the apply blocked, by design).
   - R4: note every `BLOCKED` row (expected: `supabase_admin`). These remain
     after step 6.
   - R5: no rows (confirmed today).
   - R6: counts match the audit (≈25 tables, ≈20 sequences per role).
   - Decide the R3 `search_path_proposal` for
     `enqueue_announcement_notifications` (optional, separate change).
4b. **Review the policies from 0c.** For each permissive policy on a public
   table that targets `public`, `anon` or `authenticated`, decide whether it
   is still needed and drop it explicitly
   (`drop policy "<name>" on public.<table>;`). Step 6 refuses to run while
   one exists. Its definition is preserved in the rollback file.
5. **Supabase Auth settings** (Dashboard → Authentication):
   - Sign In / Providers → Email → **Allow new users to sign up: OFF**.
   - **Confirm email: ON**. **Secure email change: ON**.
   Verify:
   `curl -s https://xzirvadcrgqnvrzhekmj.supabase.co/auth/v1/settings -H "apikey: <anon key>"`
   shows `"disable_signup":true` and `"mailer_autoconfirm":false`. Confirm
   secure email change in the dashboard.
6. **Apply**: run `bash tool/check_rls_allowlists.sh` (must print `OK`), then
   run `supabase_rls_hardening.sql` as a whole. Any failed precondition
   raises `ABORT: ...` and nothing is applied. The last result row
   (`hardening_result`) reads `NOT APPLIED`, `APPLIED, NOT SECURE: BLOCKED
   (...)` or `APPLIED: run rls/05_verify.sql`. With today's
   `supabase_admin` defaults, **expect `APPLIED, NOT SECURE: BLOCKED`**; that
   is a partial fix, not a successful one. Keep the `NOTICE`/`WARNING`
   output and that row with the change record.
7. **Verify** (again after **every** Laravel migration, dashboard table
   change or Supabase platform upgrade):
   - `rls/05_verify.sql` main query: read `1 OVERALL`, then every
     `2 SUMMARY` row that is not `PASS`, then the matching `3 DETAIL` rows.
     Verdicts, worst first: `FAIL`, `NOT SECURE: BLOCKED`, `NOT VERIFIED`
     (storage V24/V26 not reviewed), `PASS WITH DOCUMENTED EXCEPTIONS`,
     `PASS`. Until step 10 is done, expect `NOT VERIFIED` at best if the
     project has non-`nuhris_*` storage policies for `authenticated`.
   - 5e simulation with two real employees (A must not see B), plus the
     rejected-write and anon `EXECUTE` checks.
   - `bash docs/security/retest_anon_access.sh`: every table `*/0` or
     401/403 except `mobile_app_versions`; PATCH probe 401/403, not 204.
   - Mobile app, real employee: login, dashboard, DTR, leave, notifications
     (mark read and clear), Privacy Notice, degrees PDF, schedule submit,
     WFH upload (tablet).
   - Web portal: HR and Admin log in and open employees, DTR, leave, WFH,
     schedules, announcements (create one: notifications must still be
     produced) and audit logs; an employee logs in to the web portal.
8. **Link `auth_id`** with `rls/02_auth_id_linking.sql`: review statuses and
   link manually, per employee, after HR verification. Re-run until every
   row is `LINKED_OK`.
9. **Later: `rls/06_remove_email_fallback.sql`.** It aborts unless every
   active employee is cleanly linked. Before this step the web portal must
   store `employees.auth_id` when it creates Auth accounts.
10. **Storage**: `rls/07_storage_review.sql`, then a separate reviewed change.
   `05_verify.sql` checks storage from 2026-10-10 (V22–V26):
   - V22 `FAIL`: RLS off on `storage.objects` / `storage.buckets`.
   - V23 `FAIL`: a bucket in `cfg.hr_buckets` (default `credentials`) is
     public. Public buckets bypass storage policies entirely.
   - V24 `UNVERIFIED`: any other public bucket. After a documented review
     that it holds no personal data, add it to `cfg.reviewed_public_buckets`
     (never accepted for an HR bucket).
   - V25 `FAIL`: any permissive storage policy for `public`/`anon`
     (anonymous users need no storage access).
   - V26 `UNVERIFIED`: any permissive storage policy for `authenticated` not
     named `nuhris_*`. The reviewed storage change must name its policies
     `nuhris_*` (own `employee-<id>/` folder only, matching the key layout
     in 07) and drop the unreviewed ones. Restrictive policies are not
     reported.

## Definition of fixed

The audit finding may be declared fixed only when **all** of these hold, on
the live database, after step 6:

1. `05_verify.sql` `1 OVERALL` is `PASS` or `PASS WITH DOCUMENTED EXCEPTIONS`.
   `NOT SECURE: BLOCKED`, `NOT VERIFIED` or `FAIL` is not fixed, even if
   every script ran without error.
2. V22–V26 are `PASS` (storage: RLS on, no public HR bucket, no
   unreviewed public bucket, no anon storage policy, only reviewed
   `nuhris_*` storage policies for authenticated).
3. V01–V09, V12–V15, V17, V18 are `PASS`: no explicit or effective table,
   view, column or sequence privilege outside the allowlist; no grant
   options; no API-role ownership or membership; no `CREATE`; no alterable
   default exposing new objects; RLS on everywhere; no foreign permissive
   policy; no `SECURITY DEFINER` function executable by the API roles (except
   the two helpers for authenticated); helpers as designed; Laravel and
   `service_role` keep full access.
4. V10 has **no findings**: the `supabase_admin` default ACLs were removed
   by a role that can alter them (see Blockers).
5. Every remaining `EXCEPTION`/`REVIEW` finding is one of E1–E3 below.
6. 5e simulation, `retest_anon_access.sh`, and the mobile and web smoke
   tests in step 7 pass.

## Blockers (cannot be fixed from this repository or as `postgres`)

| # | Blocker | Who resolves it | Action |
|---|---|---|---|
| B1 | **`supabase_admin` default privileges** grant future tables/sequences/functions in `public` to anon/authenticated (V10) | **Supabase support** (only `supabase_admin` itself or a superuser can change them) | See "B1 in detail" below. Not resolved until V10 has no findings |
| B2 | Laravel's DB role unverified here | **Web portal developer** (web project is not in this repository) | Preflight 0f + `php artisan tinker`. Guarded by 3.0c/3.0k, the backend baseline check in 3.6, and V18 |
| B3 | App v1.1.0 not built or distributed (2026-10-10: source only, uncommitted) | **Mobile developer / release owner** | Commit, build, sign and distribute v1.1.0; confirm every employee has it before step 6 (v1.0.0 `select('*')` fails on users/employees/departments/privacy) |
| B4 | Any `BLOCKER` row in 03a R2, R3 or R4 | **Grantor/owner role** (R2 `3.0h`), or **DBA + application owners** (3.0n, 3.0o decisions) | Have the grantor/owner revoke it, or make the reviewed manual change; then re-run 03a |
| B5 | Storage not reviewed (V24/V26 `UNVERIFIED`, or V22/V23/V25 `FAIL`) | **DBA + web portal developer** (web uploads with the service role) | Step 10: run 07, then a separate reviewed storage change with `nuhris_*` policies |
| B6 | Laravel web portal accepts `http://` WFH monitoring links | **Web portal developer** | Server-side validation (the mobile app now refuses to open non-HTTPS links; not a database change) |

### B1 in detail

**Facts established:**
- `ALTER DEFAULT PRIVILEGES FOR ROLE r` requires the privileges of `r`.
  `postgres` on Supabase is not a superuser and is not a member of
  `supabase_admin`. 3.2d therefore skips it (`WARNING ... BLOCKED`) and 05
  reports V10.
- The defaults only affect objects that **`supabase_admin` creates later**
  in `public`. Objects that exist today are covered by 3.2b and by V01–V06.
  An existing `supabase_admin`-owned object with an API grant makes 3.0h
  abort instead.
- No self-service route (dashboard, SQL editor, CLI migration, all of which
  run as `postgres`) was found that can change another role's defaults.
  This repository holds no evidence of a supported route other than
  Supabase support. Do not try to work around it (for example by
  re-owning objects or editing catalogs).

**Evidence to collect before contacting support:**
- 00_preflight 0l and 03a R4: every `supabase_admin` row (scope, object
  type, grantee, privilege).
- 00b C1: whether `supabase_admin` owns any object in `public` today.

**Request to Supabase support** (one object type per statement; the
combined form is a syntax error). Run as `supabase_admin` for project
`xzirvadcrgqnvrzhekmj`:

```sql
alter default privileges for role supabase_admin in schema public revoke all on tables    from public, anon, authenticated;
alter default privileges for role supabase_admin in schema public revoke all on sequences from public, anon, authenticated;
alter default privileges for role supabase_admin in schema public revoke all on functions from public, anon, authenticated;
```

These three statements change only schema-level (`in schema public`)
entries. Grants to `service_role` and existing objects are untouched
(tested on the mock: `{anon=…, authenticated=…, service_role=…}` became
`{service_role=…}`). Including `public` is a no-op unless such an entry
exists. PostgreSQL's built-in global PUBLIC `EXECUTE` is not affected (E2).

**Do not ask for the global form** (`alter default privileges for role
supabase_admin revoke …` without `in schema public`). Global defaults apply
to objects `supabase_admin` creates in **every** schema, including `auth`,
`storage` and `realtime`, where the platform may rely on anon/authenticated
grants (for example, storage relies on RLS, not grants). If 03a R4 shows
`(all schemas)` rows for `supabase_admin`, attach them and ask support for
their recommended remediation instead.

Ask support to confirm that this does not conflict with how the platform
manages `public`. Their answer is part of the change record.

**Read-only check** (support runs it after the change; you can run it
before, to attach):

```sql
select coalesce(n.nspname, '(all schemas)') as scope,
       case d.defaclobjtype when 'r' then 'tables' when 'S' then 'sequences'
            when 'f' then 'functions' when 'T' then 'types' when 'n' then 'schemas' end as object_type,
       d.defaclacl::text as acl
from pg_catalog.pg_default_acl d
left join pg_catalog.pg_namespace n on n.oid = d.defaclnamespace
where d.defaclrole = 'supabase_admin'::regrole
order by 1, 2;
```

After the change, no `scope = public` row may contain `anon=`,
`authenticated=` or an entry starting with `=` (PUBLIC). `service_role=`
entries remain.

**Until support confirms** (these reduce the risk; they do **not** resolve B1):
- Install extensions only into the `extensions` schema, never `public`.
- Re-run `05_verify.sql` after every Supabase platform upgrade or
  extension install. A new `supabase_admin` object in `public` appears in
  V04–V06 (effective privileges) as well as V10.

## Privileges deliberately retained

| Privilege | Why |
|---|---|
| authenticated `SELECT` on attendance_records, leave_balances, leave_requests, employee_credentials, employee_schedule_submissions, employee_schedule_days, wfh_monitoring_submissions, announcement_notifications, announcements | Read by the app (`api_client.dart`); rows limited to the employee's own by `nuhris_*` policies |
| authenticated column `SELECT` on users (id, name, email, user_type), employees (16 columns, no phone/address), departments (id, name), privacy_notice_acknowledgments (4 columns) | Exactly the columns the app selects; password, remember_token, phone and address withheld |
| authenticated column `INSERT` on employee_schedule_submissions, employee_schedule_days, wfh_monitoring_submissions, privacy_notice_acknowledgments | App writes; review fields cannot be supplied; policies re-check ownership and status |
| authenticated `UPDATE (is_read, read_at)` and `DELETE` on announcement_notifications; `UPDATE (acknowledged_at, updated_at)` on privacy_notice_acknowledgments | Mark read / clear / re-acknowledge, own rows only |
| authenticated `USAGE` on the 4 id sequences of those tables | `nextval()` from the id default during the app's inserts. Not `SELECT`/`UPDATE` (no `currval`/`setval`) |
| anon + authenticated `SELECT` on mobile_app_versions | Minimum-version check before login; contains no personal data |
| authenticated `EXECUTE` on `nuhris_current_employee_id()` / `nuhris_current_user_id()` | Called by every own-row policy |
| `EXECUTE` on `enqueue_announcement_notifications()` for postgres / service_role / Laravel role | Only if they held it before (via PUBLIC); restated explicitly so backend behaviour is unchanged |
| Default privileges granting to `service_role` | Backend role (BYPASSRLS); not an API exposure |
| Role memberships (authenticator → anon/authenticated, postgres → anon/authenticated) | Standard Supabase; they do not widen anon/authenticated. Not changed |

## Documented exceptions (allowed in "PASS WITH DOCUMENTED EXCEPTIONS")

| # | Check | Exception | Justification / mitigation |
|---|---|---|---|
| E1 | V19 | Email identity fallback in `nuhris_current_employee_id()` | Only for employees with `auth_id IS NULL`, only via the Auth account's **confirmed** email (not a client-supplied value, not the JWT claim), only with sign-up OFF and secure email change ON (step 5). A linked employee can never be claimed by email. Remove with `rls/06` once rls/02 is all `LINKED_OK` (1 of 3 linked at last audit) |
| E2 | V11 | PostgreSQL's built-in global `PUBLIC EXECUTE` on future functions | It can only be removed globally: a schema-level (`in schema public`) revoke cannot remove a global or built-in grant. Revoking it changes every function the role creates in every schema. Mock test 2026-10-10: with the toggle on, an `authenticated` insert whose column default calls a function created later failed (`permission denied for function`). It would equally break future Auth hooks, Storage/Realtime policy functions and extension functions installed by that role, unless each gets an explicit `grant execute`. With the toggle off, a new `SECURITY DEFINER` function is executable by anon until `05_verify` V14 reports it (detection, not prevention). Invoker functions run with the caller's own (now minimal) privileges. The toggle (`nuhris_cfg.revoke_public_function_default = true`) only affects roles the running role can alter (`postgres`); `supabase_admin`'s built-in default stays and is not part of the B1 request |
| E3 | V16 | `enqueue_announcement_notifications` has `search_path=public` without `pg_temp` last | No API role can execute it after 3.2c, and it is a trigger function. The proposal in 03a R3 (`... set search_path = public, pg_temp`) is a separate, reviewed change. The function is **not** deleted (its purpose is not established) |

## Application compatibility risks

- **Mobile v1.0.0** stops working (by design) on tables with column-level
  grants. Enforce v1.1.0 via `mobile_app_versions` (versionCode 2).
- **Laravel**: unaffected only if it connects as an owner or BYPASSRLS role
  (3.0c). 3.6 aborts if Laravel, `postgres` or `service_role` would lose any
  privilege they have today, but that cannot prove which role the web uses.
  Confirm with 0f.
- **Web front-end using the anon key** (for example Supabase JS realtime in
  the browser): not visible from this repository. If it exists, it loses
  access. Check the web project for `SUPABASE_ANON_KEY` / `supabase-js` use.
- **Realtime**: the app's subscriptions on `announcement_notifications` and
  `announcements` respect the new policies (employees receive only their own
  rows).
- **Future tables** created by Laravel get no API access until a reviewed
  grant + policy is added. Tables created by `supabase_admin` stay exposed
  until B1 is resolved.
- **Announcements**: the trigger function keeps working for any trigger
  that uses it (`EXECUTE` is not checked when a trigger fires). Tested on a
  mock database.

## Rollback

- **Before commit:** any error inside `supabase_rls_hardening.sql` rolls the
  whole transaction back automatically.
- **After commit, preferred: fix forward.** Most failures (a missing
  column grant, a policy too strict) are fixed by one reviewed `grant` or
  policy change, without re-opening anything.
- **After commit, last resort: the `rollback_<date>.sql` file from step 3.**
  It refuses to run unless the session first runs
  `set nuhris.allow_security_revert = 'yes';`, and it is one transaction.
  - *SECTION 1* removes NUHRIS additions without re-opening anything:
    - drops the `nuhris_*` policies;
    - restores the original definition of any helper that **existed**
      before;
    - drops a helper only if it was **absent** at generation time **and**
      still carries the `NUHRIS_HARDENING_OBJECT` marker **and** nothing
      depends on it; otherwise it is kept with a WARNING;
    - **never drops `mobile_app_versions`**; the table stays, unreachable.
      An optional guarded drop is included as a comment for a separate
      decision.
  - *SECTION 2* is labelled `!!! SECURITY-REVERTING`. It re-opens the audited
    exposure: RLS/FORCE flags, original policies, and anon/authenticated/
    PUBLIC table, column, sequence and `SECURITY DEFINER` `EXECUTE` grants.
    It also restores the default privileges. Run it only with approval to
    recover from an outage, then fix forward and re-apply.
- **Ownership marker:** the apply comments the objects it creates with
  `NUHRIS_HARDENING_OBJECT: ...`. Precondition 3.0m aborts if an
  **unmarked** object with the same name exists, so the apply never
  overwrites, and the rollback never drops, an object it did not create.
- **2026-10-10 additions need no rollback content:** 3.0n and 3.0o only
  abort (nothing is applied), 03a R3/R4 and 05 V22–V26 are read-only, and
  3.2c's scope only became narrower. The manual revokes that 3.0n/3.0o ask
  for (step 4) are separate reviewed changes. Record each one with its
  inverse statement (`grant ...` / `alter default privileges ... grant ...`)
  in the change record. They happen before step 6, so step 3's rule
  (regenerate the rollback if anything changed) applies: the regenerated
  rollback does not undo them; their recorded inverses do.
- **Phase 6 only:** re-run section 3.1 of `supabase_rls_hardening.sql`.
- **Auth settings:** revert in the dashboard (re-enabling sign-up re-opens
  the self-registration risk).

## How the scripts were tested

On a disposable PGlite (PostgreSQL 18, WASM) mock with Supabase-like roles,
**not** the live database. The mock had a non-superuser BYPASSRLS owner
standing in for `postgres`, Supabase-style default ACLs for it and for
`supabase_admin`, all HR tables, a view, a column grant, a grant option, and
the `SECURITY DEFINER` trigger function. Results:

- Preflight, 00b, 02 and 03a changed nothing.
- Verify reported FAIL before the apply, and `NOT SECURE: BLOCKED` (V10
  only) after it.
- Every app read/write path worked; cross-employee reads and writes, anon
  reads, `TRUNCATE`, `setval`, `users.password` and `employees.phone` were
  denied.
- The email fallback worked only for a confirmed, unlinked account.
- The trigger still fired, `service_role` kept `EXECUTE`, and new
  tables/sequences were not exposed.
- The generated rollback restored every ACL, default ACL, RLS flag and
  policy exactly.
- A non-revocable `supabase_admin` grant made the apply abort with nothing
  changed.

Re-run on 2026-10-10 after the 3.0n/3.0o/V22–V26 changes (same mock plus a
Supabase-like `storage` schema; PGlite 0.5.8 = PostgreSQL 18.3):

- All four earlier scenarios still pass (main, blocked `supabase_admin`
  grant, foreign helper, adopted helper), including the exact rollback
  restore. Storage V22–V26 `PASS` on a clean storage schema.
- A configured PUBLIC table default made the apply abort (3.0n) with nothing
  changed. 03a R4 showed `BLOCKER (3.0n)` and the exact manual statement.
  After that statement, the apply succeeded.
- A callable `SECURITY DEFINER` function with PUBLIC `EXECUTE` made the
  apply abort (3.0o) with nothing changed, while the trigger function stayed
  in 3.2c. 03a R3 listed the login role relying on it. After an explicit
  grant to that role and a manual revoke, the apply succeeded, and the role
  kept `EXECUTE`.
- Public HR bucket, RLS off on `storage.buckets`, and an anon storage policy
  each gave `FAIL`. Another public bucket and an unreviewed authenticated
  policy gave `UNVERIFIED`. A restrictive policy was not reported.
  `reviewed_public_buckets` excluded a reviewed bucket but never the HR
  bucket.
- With the `supabase_admin` defaults removed by the mock superuser
  (simulating Supabase support): V10 `PASS`; overall `NOT VERIFIED` while
  the authenticated storage policy was unreviewed; `PASS WITH DOCUMENTED
  EXCEPTIONS` (E1–E3) once it was a `nuhris_*` policy; 3.7 no longer
  `BLOCKED`.
- Every script and every generated rollback parses with the PostgreSQL 17
  parser (libpg-query 17.7). `tool/check_rls_allowlists.sh` prints `OK`.

Supabase specifics (pooler, real `supabase_admin` as superuser, the real
storage schema, PostgreSQL 15/17 differences) can still differ.
PostgreSQL 15 was not tested. Steps 2–4 and 7 are mandatory.
