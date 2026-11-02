// /admin is protected ONLY by middleware (see ../../middleware.ts).
//
// There is deliberately NO server-side session check in this page. On an
// unpatched Next.js, forging `x-middleware-subrequest` skips the middleware,
// so this page renders for an attacker with no session cookie at all.
//
// Compare with /admin-secure, which adds the missing check.
export default function AdminPage() {
  return (
    <main>
      <h1>Welcome, authenticated admin</h1>
      <p>
        This is the protected admin area. If you can read this without a{" "}
        <code>session</code> cookie, the middleware was bypassed.
      </p>
      <p style={{ color: "#b00" }}>
        <strong>/admin is guarded by middleware only.</strong>
      </p>
    </main>
  );
}
