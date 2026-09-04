import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";
import manifest from "@/app/manifest";

describe("PWA assets", () => {
  it("keeps the shared-role KAAM manifest contract", () => {
    const value = manifest();

    expect(value).toMatchObject({
      name: "KAAM – Jobs & Careers",
      short_name: "KAAM",
      start_url: "/",
      scope: "/",
      display: "standalone",
      background_color: "#160847",
      theme_color: "#160847",
    });
    expect(value.icons).toEqual(expect.arrayContaining([
      expect.objectContaining({ src: "/icons/icon-192.png", sizes: "192x192" }),
      expect.objectContaining({ src: "/icons/icon-512.png", sizes: "512x512" }),
      expect.objectContaining({ src: "/icons/icon-maskable-512.png", purpose: "maskable" }),
    ]));
  });

  it("restricts persistent caching to explicit public static assets", () => {
    const source = readFileSync(resolve(process.cwd(), "public/sw.js"), "utf8");

    expect(source).toContain('if (request.method !== "GET") return');
    expect(source).toContain('if (request.mode === "navigate")');
    expect(source).toContain("fetch(request).catch(() => caches.match(OFFLINE_URL))");
    expect(source).toContain("url.origin !== self.location.origin");
    expect(source).toContain('pathname.startsWith("/_next/static/")');
    expect(source).toContain("return PRECACHE.includes(pathname)");
    expect(source).not.toMatch(/caches\.open\([^)]*\)[\s\S]*\/candidate\//);
    expect(source).not.toMatch(/caches\.open\([^)]*\)[\s\S]*\/employer\//);
    expect(source).not.toMatch(/caches\.open\([^)]*\)[\s\S]*\/admin\//);
    expect(source).not.toMatch(/caches\.open\([^)]*\)[\s\S]*\/api\//);
  });
});
