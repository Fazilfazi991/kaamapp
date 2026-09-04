import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  experimental: {
    // Passport uploads are accepted by the Edge Function up to 10 MB. Leave
    // room for the Server Action multipart envelope without widening it beyond
    // the function's own file-size enforcement.
    serverActions: {
      bodySizeLimit: "11mb",
    },
  },
  async headers() {
    return [
      {
        source: "/sw.js",
        headers: [
          { key: "Cache-Control", value: "public, max-age=0, must-revalidate" },
          { key: "Service-Worker-Allowed", value: "/" },
        ],
      },
      {
        source: "/:privateArea(candidate|candidates|employer|employers|admin|account|auth|api)/:path*",
        headers: [{ key: "Cache-Control", value: "private, no-store, max-age=0" }],
      },
      {
        source: "/:authPage(login|register)",
        headers: [{ key: "Cache-Control", value: "private, no-store, max-age=0" }],
      },
    ];
  },
};

export default nextConfig;
