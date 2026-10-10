-- =====================================================================
-- PHASE 7 — STORAGE REVIEW (READ-ONLY) — no policies are created here
-- =====================================================================
-- Storage policies are deliberately NOT part of the hardening script:
-- they cannot be written safely without the output below.
--
-- Known access requirements (from code, 2026-10-09):
--   * Web portal: uploads/reads/deletes with SUPABASE_SERVICE_ROLE_KEY
--     (bypasses storage RLS) in bucket SUPABASE_STORAGE_BUCKET
--     (default 'credentials'); object keys 'employee-<id>/<time>_<hex>.<ext>'
--     and 'employee-<id>/degrees/...'.
--   * Mobile app (authenticated role):
--       - createSignedUrl on 'credentials' for keys stored in
--         employee_credentials.file_path / wfh_monitoring_submissions.file_path
--         and employees.profilephoto_path (needs SELECT on storage.objects);
--       - legacy profile photo '<auth uid>/avatar.jpg';
--       - upload (INSERT) to 'employee-<id>/wfh-monitoring/<time>_<hex>.<ext>'
--         (tablet-width WFH screen only).
--   * Anonymous: no access needed. (Observed: anon cannot list buckets or
--     objects in 'credentials'.)
-- =====================================================================

-- 7a. Buckets and whether they are public (a public bucket serves files to
--     anyone with the URL, regardless of policies).
select id, name, public, file_size_limit, allowed_mime_types, created_at
from storage.buckets order by name;

-- 7b. Existing storage policies.
select policyname, permissive, roles, cmd, qual, with_check
from pg_catalog.pg_policies
where schemaname = 'storage'
order by tablename, policyname;

-- 7c. Folder layout (first path segment pattern) per bucket — object COUNTS
--     only, no file names, to confirm the key structure above.
select bucket_id,
       case
         when name ~ '^employee-[0-9]+/wfh-monitoring/' then 'employee-<id>/wfh-monitoring/*'
         when name ~ '^employee-[0-9]+/degrees/'        then 'employee-<id>/degrees/*'
         when name ~ '^employee-[0-9]+/[^/]+$'          then 'employee-<id>/<file>'
         when name ~ '^[0-9a-f-]{36}/'                  then '<auth uid>/*'
         else 'other'
       end as key_pattern,
       count(*)
from storage.objects
group by 1, 2
order by 1, 2;

-- Decide with this output, then write storage policies in a separate,
-- reviewed change:
--   * which buckets must be private (all HR documents: yes);
--   * whether employees may read every file under employee-<own id>/
--     (degrees, credentials, WFH) or only some sub-folders;
--   * whether mobile WFH upload stays (the web now uses monitoring links).
