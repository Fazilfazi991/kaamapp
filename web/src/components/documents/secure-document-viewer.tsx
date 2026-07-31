"use client";

import { useState } from "react";
import { Button, ButtonLink } from "@/components/ui/button";
import type { SecureDocumentPreviewKind } from "./preview-kind";
import {
  defaultSecureDocumentViewerState,
  resetViewerState,
  rotateLeft,
  rotateRight,
  zoomIn,
  zoomOut,
} from "./secure-document-viewer-state";

export function SecureDocumentViewer({
  previewUrl,
  kind,
  title,
  documentKey,
}: {
  previewUrl?: string | null;
  kind: SecureDocumentPreviewKind;
  title: string;
  documentKey: string;
}) {
  return (
    <SecureDocumentViewerBody
      key={`${documentKey}:${previewUrl ?? ""}:${kind}`}
      previewUrl={previewUrl}
      kind={kind}
      title={title}
    />
  );
}

function SecureDocumentViewerBody({
  previewUrl,
  kind,
  title,
}: {
  previewUrl?: string | null;
  kind: SecureDocumentPreviewKind;
  title: string;
}) {
  const [state, setState] = useState(defaultSecureDocumentViewerState);
  const [failed, setFailed] = useState(false);
  const [reloadKey, setReloadKey] = useState(0);

  if (!previewUrl || kind === "unavailable") {
    return <PreviewFallback message="Preview unavailable" />;
  }

  if (kind === "unsupported") {
    return (
      <PreviewFallback
        message="This file type cannot be previewed inline."
        previewUrl={previewUrl}
      />
    );
  }

  if (kind === "pdf") {
    return (
      <div className="grid gap-3">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <p className="text-sm font-medium text-[#66616f]">PDF preview</p>
          <ButtonLink href={previewUrl} target="_blank" rel="noreferrer" variant="secondary" className="min-h-10 px-3 py-2">
            Open secure preview
          </ButtonLink>
        </div>
        <div className="overflow-hidden rounded-lg border border-[#eadde3] bg-[#f7f2f5]">
          {failed ? (
            <PreviewFallback
              message="Preview unavailable"
              previewUrl={previewUrl}
              onRetry={() => {
                setFailed(false);
                setReloadKey((value) => value + 1);
              }}
            />
          ) : (
            <iframe
              key={reloadKey}
              title={title}
              src={previewUrl}
              onError={() => setFailed(true)}
              className="h-[70vh] min-h-[420px] w-full bg-white"
            />
          )}
        </div>
      </div>
    );
  }

  const fitMode = state.mode === "fit";

  return (
    <div className="grid gap-3">
      <div className="flex flex-wrap items-center gap-2">
        <Button type="button" variant={fitMode ? "primary" : "secondary"} className="min-h-10 px-3 py-2" aria-label="Fit document to screen" onClick={() => setState((current) => ({ ...current, mode: "fit", zoom: 1 }))}>
          Fit to screen
        </Button>
        <Button type="button" variant={!fitMode ? "primary" : "secondary"} className="min-h-10 px-3 py-2" aria-label="Show document at actual size" onClick={() => setState((current) => ({ ...current, mode: "actual", zoom: 1 }))}>
          Actual size
        </Button>
        <Button type="button" variant="secondary" className="min-h-10 px-3 py-2" aria-label="Zoom out" onClick={() => setState(zoomOut)}>
          Zoom out
        </Button>
        <span className="min-w-14 text-center text-sm font-semibold text-[#3b3340]">{Math.round(state.zoom * 100)}%</span>
        <Button type="button" variant="secondary" className="min-h-10 px-3 py-2" aria-label="Zoom in" onClick={() => setState(zoomIn)}>
          Zoom in
        </Button>
        <Button type="button" variant="secondary" className="min-h-10 px-3 py-2" aria-label="Rotate document left" onClick={() => setState(rotateLeft)}>
          Rotate left
        </Button>
        <Button type="button" variant="secondary" className="min-h-10 px-3 py-2" aria-label="Rotate document right" onClick={() => setState(rotateRight)}>
          Rotate right
        </Button>
        <Button type="button" variant="ghost" className="min-h-10 px-3 py-2" aria-label="Reset document preview" onClick={() => setState(resetViewerState)}>
          Reset
        </Button>
        <ButtonLink href={previewUrl} target="_blank" rel="noreferrer" variant="secondary" className="min-h-10 px-3 py-2">
          Open secure preview
        </ButtonLink>
      </div>

      <div
        className={`relative flex h-[70vh] min-h-[420px] max-h-[760px] w-full items-center justify-center rounded-lg border border-[#eadde3] bg-[#f7f2f5] p-3 ${
          fitMode ? "overflow-hidden" : "overflow-auto"
        }`}
      >
        {failed ? (
          <PreviewFallback
            message="Preview unavailable"
            previewUrl={previewUrl}
            onRetry={() => {
              setFailed(false);
              setReloadKey((value) => value + 1);
            }}
          />
        ) : (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            key={reloadKey}
            src={previewUrl}
            alt={title}
            onError={() => setFailed(true)}
            className={fitMode ? "max-h-full max-w-full object-contain" : "max-w-none object-contain"}
            style={{
              transform: `rotate(${state.rotation}deg) scale(${fitMode ? 1 : state.zoom})`,
              transformOrigin: "center center",
            }}
            draggable={false}
          />
        )}
      </div>
    </div>
  );
}

function PreviewFallback({
  message,
  previewUrl,
  onRetry,
}: {
  message: string;
  previewUrl?: string | null;
  onRetry?: () => void;
}) {
  return (
    <div className="grid min-h-[260px] place-items-center rounded-lg border border-dashed border-[#d8c8d1] bg-[#fffafc] p-6 text-center">
      <div>
        <p className="text-base font-semibold text-[#201925]">{message}</p>
        <p className="mt-2 text-sm text-[#66616f]">Document metadata and review actions remain available.</p>
        <div className="mt-4 flex flex-wrap justify-center gap-2">
          {onRetry ? (
            <Button type="button" variant="secondary" className="min-h-10 px-3 py-2" onClick={onRetry}>
              Retry
            </Button>
          ) : null}
          {previewUrl ? (
            <ButtonLink href={previewUrl} target="_blank" rel="noreferrer" variant="secondary" className="min-h-10 px-3 py-2">
              Open secure preview
            </ButtonLink>
          ) : null}
        </div>
      </div>
    </div>
  );
}
