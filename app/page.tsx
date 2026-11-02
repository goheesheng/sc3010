import Link from "next/link";

export default function Home() {
  return (
    <main>
      <h1>CVE-2025-29927 — Next.js Middleware Auth Bypass</h1>
      <p>
        Local-only classroom demonstration. Two protected pages are wired up:
      </p>
      <ul>
        <li>
          <Link href="/admin">/admin</Link> — protected <strong>only</strong> by
          middleware. Vulnerable to the header bypass on unpatched Next.js.
        </li>
        <li>
          <Link href="/admin-secure">/admin-secure</Link> — protected by
          middleware <strong>and</strong> an in-page server-side session check
          (defense-in-depth). Survives the bypass.
        </li>
        <li>
          <Link href="/login">/login</Link> — stub login that sets the session
          cookie.
        </li>
      </ul>
      <p>
        See <code>README.md</code> for the before/after <code>curl</code>{" "}
        walkthrough.
      </p>
    </main>
  );
}
