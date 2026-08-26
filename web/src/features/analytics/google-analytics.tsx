import Script from "next/script";
import { GA_MEASUREMENT_ID, ga4Enabled } from "./ga4";

export function GoogleAnalytics() {
  if (!ga4Enabled()) return null;
  return <>
    <Script id="kaam-ga4-library" src={`https://www.googletagmanager.com/gtag/js?id=${encodeURIComponent(GA_MEASUREMENT_ID)}`} strategy="afterInteractive" />
    <Script id="kaam-ga4-config" strategy="afterInteractive">
      {`window.dataLayer = window.dataLayer || []; function gtag(){dataLayer.push(arguments);} window.gtag = window.gtag || gtag; if (!window.__kaamGa4Configured) { gtag('js', new Date()); gtag('config', '${GA_MEASUREMENT_ID}', { send_page_view: false }); window.__kaamGa4Configured = true; }`}
    </Script>
  </>;
}
