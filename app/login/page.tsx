import { cookies } from "next/headers";
import { redirect } from "next/navigation";

// Stub login. No real credential check — this is about the middleware bypass,
// not about authentication logic. Submitting the form just sets the session
// cookie that the middleware looks for.
async function login() {
  "use server";
  (await cookies()).set("session", "demo-admin-session", {
    httpOnly: true,
    path: "/",
    sameSite: "lax",
  });
  redirect("/admin");
}

export default function LoginPage() {
  return (
    <main>
      <h1>Login</h1>
      <p style={{ color: "#666" }}>
        Stub login — any values work. Submitting sets the <code>session</code>{" "}
        cookie.
      </p>
      <form action={login} style={{ display: "grid", gap: 12, maxWidth: 320 }}>
        <label>
          Username
          <input name="username" defaultValue="admin" style={inputStyle} />
        </label>
        <label>
          Password
          <input
            name="password"
            type="password"
            defaultValue="password"
            style={inputStyle}
          />
        </label>
        <button type="submit" style={buttonStyle}>
          Log in
        </button>
      </form>
    </main>
  );
}

const inputStyle = {
  display: "block",
  width: "100%",
  padding: "8px 10px",
  marginTop: 4,
  border: "1px solid #ccc",
  borderRadius: 6,
} as const;

const buttonStyle = {
  padding: "10px 14px",
  background: "#1a1a1a",
  color: "#fff",
  border: "none",
  borderRadius: 6,
  cursor: "pointer",
} as const;
