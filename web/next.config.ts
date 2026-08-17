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
};

export default nextConfig;
