import { NextRequest, NextResponse } from "next/server";

// ---------------------------------------------------------------------------
// Edge middleware: the ONLY thing guarding /admin here.
//
// It checks for a `session` cookie and bounces unauthenticated users to
// /login. This is a very common real-world pattern: "put the auth check in
// middleware so every protected route is covered in one place."
//
// CVE-2025-29927 is exactly why that pattern alone is not enough on an
// unpatched Next.js: an attacker can make Next skip this file entirely by
// sending a forged `x-middleware-subrequest` header, so none of the code
// below ever runs for their request.
// ---------------------------------------------------------------------------

export function middleware(request: NextRequest) {
  const session = request.cookies.get("session")?.value;

  if (!session) {
    const loginUrl = new URL("/login", request.url);
    loginUrl.searchParams.set("from", request.nextUrl.pathname);
    return NextResponse.redirect(loginUrl);
  }

  // Authenticated: let the request through, and tag the response so we can
  // prove in the demo whether middleware actually executed for this request.
  const response = NextResponse.next();
  response.headers.set("x-demo-middleware", "executed");
  return response;
}

export const config = {
  // Guard the admin route with middleware.
  matcher: ["/admin/:path*"],
};
