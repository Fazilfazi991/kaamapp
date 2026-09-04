"use client";

import { useEffect, useState } from "react";
import { usePathname } from "next/navigation";
import { isSafeUpdateRoute, isStableInstallRoute } from "./install-policy";

type InstallPromptEvent = Event & {
  prompt: () => Promise<void>;
  userChoice: Promise<{ outcome: "accepted" | "dismissed" }>;
};

const dismissalKey = "kaam:pwa-install-dismissed-at";
const dismissalWindow = 30 * 24 * 60 * 60 * 1000;

function isStandalone() {
  return window.matchMedia("(display-mode: standalone)").matches ||
    ("standalone" in window.navigator &&
      (window.navigator as Navigator & { standalone?: boolean }).standalone === true);
}

function isIosSafari() {
  const ua = window.navigator.userAgent;
  const ios = /iPad|iPhone|iPod/.test(ua) ||
    (window.navigator.platform === "MacIntel" && window.navigator.maxTouchPoints > 1);
  return ios && /Safari/.test(ua) && !/CriOS|FxiOS|EdgiOS/.test(ua);
}

export function PwaExperience() {
  const pathname = usePathname();
  const [installPrompt, setInstallPrompt] = useState<InstallPromptEvent | null>(null);
  const [showInstall, setShowInstall] = useState(false);
  const [showIosHelp, setShowIosHelp] = useState(false);
  const [iosSafari, setIosSafari] = useState(false);
  const [offline, setOffline] = useState(false);
  const [waitingWorker, setWaitingWorker] = useState<ServiceWorker | null>(null);

  useEffect(() => {
    const detectInitialState = window.setTimeout(() => {
      setOffline(!window.navigator.onLine);
      setIosSafari(isIosSafari());
    }, 0);
    const handleOnline = () => setOffline(false);
    const handleOffline = () => setOffline(true);
    window.addEventListener("online", handleOnline);
    window.addEventListener("offline", handleOffline);
    return () => {
      window.clearTimeout(detectInitialState);
      window.removeEventListener("online", handleOnline);
      window.removeEventListener("offline", handleOffline);
    };
  }, []);

  useEffect(() => {
    if (!("serviceWorker" in navigator) || process.env.NODE_ENV !== "production") return;

    let refreshing = false;
    const onControllerChange = () => {
      if (refreshing) return;
      refreshing = true;
      window.location.reload();
    };
    navigator.serviceWorker.addEventListener("controllerchange", onControllerChange);

    void navigator.serviceWorker.register("/sw.js", { scope: "/", updateViaCache: "none" })
      .then((registration) => {
        if (registration.waiting) setWaitingWorker(registration.waiting);
        registration.addEventListener("updatefound", () => {
          const worker = registration.installing;
          worker?.addEventListener("statechange", () => {
            if (worker.state === "installed" && navigator.serviceWorker.controller) {
              setWaitingWorker(worker);
            }
          });
        });
      })
      .catch(() => {
        // The website remains fully usable when service-worker registration is unavailable.
      });

    return () => navigator.serviceWorker.removeEventListener("controllerchange", onControllerChange);
  }, []);

  useEffect(() => {
    if (isStandalone()) return;
    const rawDismissedAt = window.localStorage.getItem(dismissalKey);
    const dismissedAt = rawDismissedAt ? Number(rawDismissedAt) : 0;
    if (Date.now() - dismissedAt < dismissalWindow) return;

    if (!isStableInstallRoute(pathname)) return;

    const timer = window.setTimeout(() => {
      const activeElement = document.activeElement;
      const userIsEnteringData = activeElement instanceof HTMLElement &&
        activeElement.matches("input, textarea, select, [contenteditable='true']");
      if (!userIsEnteringData) setShowInstall(true);
    }, 30_000);
    return () => window.clearTimeout(timer);
  }, [pathname]);

  useEffect(() => {
    const onBeforeInstall = (event: Event) => {
      event.preventDefault();
      setInstallPrompt(event as InstallPromptEvent);
    };
    const onInstalled = () => {
      setInstallPrompt(null);
      setShowInstall(false);
      window.localStorage.removeItem(dismissalKey);
    };
    window.addEventListener("beforeinstallprompt", onBeforeInstall);
    window.addEventListener("appinstalled", onInstalled);
    return () => {
      window.removeEventListener("beforeinstallprompt", onBeforeInstall);
      window.removeEventListener("appinstalled", onInstalled);
    };
  }, []);

  async function install() {
    if (installPrompt) {
      await installPrompt.prompt();
      const choice = await installPrompt.userChoice;
      if (choice.outcome === "accepted") setShowInstall(false);
      setInstallPrompt(null);
      return;
    }
    if (isIosSafari()) setShowIosHelp(true);
  }

  function dismissInstall() {
    window.localStorage.setItem(dismissalKey, String(Date.now()));
    setShowInstall(false);
    setShowIosHelp(false);
  }

  const canOfferInstall = installPrompt || iosSafari;

  return (
    <>
      {offline ? (
        <div className="pwa-connection" role="status">
          <span>You’re offline. Live KAAM features are unavailable.</span>
          <button type="button" onClick={() => window.location.reload()}>Retry</button>
        </div>
      ) : null}
      {waitingWorker && isSafeUpdateRoute(pathname) ? (
        <div className="pwa-update" role="status">
          <span>A new version of KAAM is available.</span>
          <button type="button" onClick={() => waitingWorker.postMessage({ type: "SKIP_WAITING" })}>
            Update
          </button>
          <button type="button" aria-label="Dismiss update" onClick={() => setWaitingWorker(null)}>×</button>
        </div>
      ) : null}
      {showInstall && canOfferInstall ? (
        <aside className="pwa-install" aria-label="Install KAAM">
          <div>
            <strong>Keep KAAM within reach</strong>
            <p>{showIosHelp ? "In Safari, tap Share, then Add to Home Screen." : "Install KAAM for a focused, app-like experience."}</p>
          </div>
          {!showIosHelp ? <button type="button" onClick={() => void install()}>Install KAAM</button> : null}
          <button type="button" className="pwa-dismiss" aria-label="Dismiss install suggestion" onClick={dismissInstall}>×</button>
        </aside>
      ) : null}
    </>
  );
}
