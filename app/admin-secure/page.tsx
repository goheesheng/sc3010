import { cookies } from "next/headers";
import { redirect } from "next/navigation";

// /admin-secure demonstrates DEFENSE IN DEPTH.
//
// It is covered by the same middleware as /admin, but it ALSO re-checks the
// session inside the page itself. This server-side check runs during render,
// as part of handling the request — it does NOT depend on middleware having
// run. So even if an attacker bypasses middleware with a forged
// `x-middleware-subrequest` header, this check still fires and redirects them
// to /login.
//
// Lesson: never rely on middleware as your only authorization boundary.
// Enforce authorization at the resource (page / route handler / data layer)
// too.
export default async function AdminSecurePage() {
  const session = (await cookies()).get("session")?.value;

  if (!session) {
    redirect("/login");
  }

  return (
    <main>
      <h1>Welcome, authenticated admin (secure)</h1>
      <p>
        This page re-verifies the <code>session</code> cookie server-side,
        independently of middleware.
      </p>
      <p style={{ color: "#070" }}>
        <strong>
          /admin-secure is guarded by middleware AND an in-page check.
        </strong>
      </p>
    </main>
  );
}
