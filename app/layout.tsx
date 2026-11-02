import type { Metadata } from "next";
import type { ReactNode } from "react";

export const metadata: Metadata = {
  title: "CVE-2025-29927 Demo",
  description: "Local-only educational demo of the Next.js middleware auth bypass.",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body
        style={{
          fontFamily:
            "ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, sans-serif",
          maxWidth: 720,
          margin: "40px auto",
          padding: "0 20px",
          lineHeight: 1.6,
          color: "#1a1a1a",
        }}
      >
        {children}
      </body>
    </html>
  );
}
