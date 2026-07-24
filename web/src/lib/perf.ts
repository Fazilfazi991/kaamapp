export function webPerf(label: string, startedAt = performance.now()) {
  if (process.env.NODE_ENV !== "production") {
    console.debug(`[WEB PERF] ${label} completed in ${(performance.now() - startedAt).toFixed(0)}ms`);
  }
}
