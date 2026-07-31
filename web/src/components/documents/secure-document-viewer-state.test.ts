import { describe, expect, it } from "vitest";
import {
  defaultSecureDocumentViewerState,
  resetViewerState,
  rotateLeft,
  rotateRight,
  zoomIn,
  zoomOut,
} from "./secure-document-viewer-state";

describe("secure document viewer state", () => {
  it("defaults to fit mode", () => {
    expect(defaultSecureDocumentViewerState).toEqual({
      mode: "fit",
      zoom: 1,
      rotation: 0,
    });
  });

  it("zooms in and out within sensible limits", () => {
    let state = defaultSecureDocumentViewerState;
    for (let index = 0; index < 20; index += 1) state = zoomIn(state);
    expect(state.zoom).toBe(3);
    expect(state.mode).toBe("actual");
    for (let index = 0; index < 20; index += 1) state = zoomOut(state);
    expect(state.zoom).toBe(0.5);
  });

  it("rotates in 90 degree steps", () => {
    expect(rotateRight(defaultSecureDocumentViewerState).rotation).toBe(90);
    expect(rotateLeft(defaultSecureDocumentViewerState).rotation).toBe(270);
  });

  it("reset restores fit mode and zero rotation", () => {
    const changed = rotateRight(zoomIn(defaultSecureDocumentViewerState));
    expect(changed).not.toEqual(defaultSecureDocumentViewerState);
    expect(resetViewerState()).toEqual(defaultSecureDocumentViewerState);
  });
});
