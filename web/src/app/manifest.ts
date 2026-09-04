import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    id: "/",
    name: "KAAM – Jobs & Careers",
    short_name: "KAAM",
    description:
      "Find trusted jobs and connect verified candidates with employers through KAAM.",
    start_url: "/",
    scope: "/",
    display: "standalone",
    display_override: ["standalone", "minimal-ui"],
    background_color: "#160847",
    theme_color: "#160847",
    icons: [
      { src: "/icons/icon-192.png", sizes: "192x192", type: "image/png" },
      { src: "/icons/icon-512.png", sizes: "512x512", type: "image/png" },
      {
        src: "/icons/icon-maskable-512.png",
        sizes: "512x512",
        type: "image/png",
        purpose: "maskable",
      },
    ],
    shortcuts: [
      {
        name: "Candidate login",
        short_name: "Candidate",
        description: "Sign in to your KAAM candidate account",
        url: "/login?role=candidate",
        icons: [{ src: "/icons/icon-192.png", sizes: "192x192", type: "image/png" }],
      },
      {
        name: "Employer login",
        short_name: "Employer",
        description: "Sign in to your KAAM employer account",
        url: "/login?role=employer",
        icons: [{ src: "/icons/icon-192.png", sizes: "192x192", type: "image/png" }],
      },
    ],
  };
}
