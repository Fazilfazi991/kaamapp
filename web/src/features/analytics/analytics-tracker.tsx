"use client";
import { useEffect, useRef } from "react";
import { usePathname } from "next/navigation";
import { track } from "./tracker";
export function AnalyticsTracker() { const pathname = usePathname(); const last = useRef(""); useEffect(() => { if (pathname && pathname !== last.current) { last.current = pathname; track("page_view"); } }, [pathname]); return null; }
