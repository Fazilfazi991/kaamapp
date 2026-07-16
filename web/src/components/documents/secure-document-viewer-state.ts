export type SecureDocumentViewerMode = "fit" | "actual";

export type SecureDocumentViewerState = {
  mode: SecureDocumentViewerMode;
  zoom: number;
  rotation: number;
};

export const defaultSecureDocumentViewerState: SecureDocumentViewerState = {
  mode: "fit",
  zoom: 1,
  rotation: 0,
};

export function zoomIn(state: SecureDocumentViewerState): SecureDocumentViewerState {
  return { ...state, mode: "actual", zoom: Math.min(3, Number((state.zoom + 0.25).toFixed(2))) };
}

export function zoomOut(state: SecureDocumentViewerState): SecureDocumentViewerState {
  return { ...state, mode: "actual", zoom: Math.max(0.5, Number((state.zoom - 0.25).toFixed(2))) };
}

export function rotateRight(state: SecureDocumentViewerState): SecureDocumentViewerState {
  return { ...state, rotation: normalizeRotation(state.rotation + 90) };
}

export function rotateLeft(state: SecureDocumentViewerState): SecureDocumentViewerState {
  return { ...state, rotation: normalizeRotation(state.rotation - 90) };
}

export function resetViewerState(): SecureDocumentViewerState {
  return defaultSecureDocumentViewerState;
}

function normalizeRotation(value: number) {
  return ((value % 360) + 360) % 360;
}
