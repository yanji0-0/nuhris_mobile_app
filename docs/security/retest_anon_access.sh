#!/usr/bin/env bash
# Re-tests what the public anon key can reach through the Supabase REST API.
# Read-only: HEAD requests with `Prefer: count=exact` return row COUNTS only,
# never row data. The PATCH probe targets id = -1, which matches no row.
#
#   bash docs/security/retest_anon_access.sh
#
# Expected after supabase_rls_hardening.sql:
#   every table -> 401/403, or 200 with "*/0" (no rows visible),
#   except mobile_app_versions (readable by design);
#   PATCH probe  -> 401/403 (no UPDATE privilege), not 204.
set -uo pipefail
cd "$(dirname "$0")/../.."

URL="https://xzirvadcrgqnvrzhekmj.supabase.co"
KEY="$(grep -oE 'eyJ[A-Za-z0-9._-]+' lib/config/app_config.dart)"
H=(-H "apikey: $KEY" -H "Authorization: Bearer $KEY")

printf '%-32s %-5s %s\n' TABLE HTTP 'ROWS VISIBLE TO ANON'
for t in users employees departments attendance_records leave_balances \
         leave_requests employee_credentials wfh_monitoring_submissions \
         employee_schedule_submissions employee_schedule_days \
         announcement_notifications announcements privacy_notice_acknowledgments \
         sessions password_reset_tokens cache admin_configs admin_audit_logs \
         migrations academic_calendar_entries mobile_app_versions; do
  hdr="$(mktemp)"
  code="$(curl -s -o /dev/null -I -w '%{http_code}' -D "$hdr" "${H[@]}" \
    -H 'Prefer: count=exact' "$URL/rest/v1/$t?select=*")"
  printf '%-32s %-5s %s\n' "$t" "$code" \
    "$(grep -i '^content-range' "$hdr" | tr -d '\r' | cut -d' ' -f2)"
  rm -f "$hdr"
done

echo
echo "UPDATE privilege probe (zero-row PATCH):"
for t in users employees attendance_records leave_requests leave_balances; do
  code="$(curl -s -o /dev/null -w '%{http_code}' -X PATCH "${H[@]}" \
    -H 'Content-Type: application/json' -H 'Prefer: return=minimal' \
    -d '{"updated_at":null}' "$URL/rest/v1/$t?id=eq.-1")"
  echo "  $t -> $code"
done

echo
echo "Auth settings:"
curl -s "$URL/auth/v1/settings" -H "apikey: $KEY" \
  | grep -oE '"(disable_signup|mailer_autoconfirm)":(true|false)'
