import type { Metadata, Viewport } from "next";
import { Suspense } from "react";
import { Geist } from "next/font/google";
import { PwaExperience } from "@/components/pwa/pwa-experience";
import "./globals.css";
import { AnalyticsTracker } from "@/features/analytics/analytics-tracker";
import { GoogleAnalytics } from "@/features/analytics/google-analytics";

const geist = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL ?? "https://www.kaamcareer.com"),
  applicationName: "KAAM",
  title: { default: "KAAM | Mutual-interest recruitment", template: "%s | KAAM" },
  description:
    "KAAM connects workers and employers through skills, requirements and mutual interest.",
  openGraph: { type: "website", siteName: "KAAM", title: "KAAM | Mutual-interest recruitment", description: "Find work and hire workers through mutual interest." },
  twitter: { card: "summary", title: "KAAM | Mutual-interest recruitment", description: "Find work and hire workers through mutual interest." },
  manifest: "/manifest.webmanifest",
  icons: {
    icon: [
      { url: "/icons/icon-192.png", sizes: "192x192", type: "image/png" },
      { url: "/icons/icon-512.png", sizes: "512x512", type: "image/png" },
    ],
    apple: [{ url: "/icons/apple-touch-icon.png", sizes: "180x180", type: "image/png" }],
  },
  appleWebApp: {
    capable: true,
    statusBarStyle: "black-translucent",
    title: "KAAM",
  },
  formatDetection: { telephone: false },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
  themeColor: "#160847",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={`${geist.variable} antialiased`}>
      <body>
        <GoogleAnalytics />
        <Suspense fallback={null}><AnalyticsTracker /></Suspense>
        {children}
        <PwaExperience />
      </body>
    </html>
  );
}
