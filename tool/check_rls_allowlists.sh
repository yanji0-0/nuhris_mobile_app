#!/usr/bin/env bash
# Checks that the NUHRIS API-role allowlist is identical everywhere it is
# used: the apply script (supabase_rls_hardening.sql 3.00), the review
# (rls/03a) and the verification (rls/05_verify.sql). A drift would make
# verification PASS on privileges the apply script never intended.
#
#   bash tool/check_rls_allowlists.sh
set -euo pipefail
cd "$(dirname "$0")/.."

files=(
  docs/security/supabase_rls_hardening.sql
  docs/security/rls/03a_public_grants_remediation.sql
  docs/security/rls/05_verify.sql
)
status=0
for block in TABLE COLUMN SEQUENCE; do
  ref=""
  for f in "${files[@]}"; do
    body="$(sed -n "/-- BEGIN NUHRIS $block ALLOWLIST/,/-- END NUHRIS $block ALLOWLIST/p" "$f" \
            | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    if [[ -z "$body" ]]; then
      echo "MISSING: $block allowlist in $f"; status=1; continue
    fi
    if [[ -z "$ref" ]]; then
      ref="$body"; ref_file="$f"
    elif [[ "$body" != "$ref" ]]; then
      echo "DRIFT: $block allowlist in $f differs from $ref_file"
      diff <(echo "$ref") <(echo "$body") || true
      status=1
    fi
  done
done
[[ $status -eq 0 ]] && echo "OK: table, column and sequence allowlists match in ${#files[@]} files."
exit $status
