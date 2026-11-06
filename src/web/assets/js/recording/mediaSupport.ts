/**
 * The video formats to record with, in order of preference.
 *
 * MP4 with H.264 and AAC comes first, because that is what Safari records and
 * what most players handle. Chrome and Edge also record MP4 in current versions,
 * and use WebM (VP9, then VP8, with Opus) when they do not.
 */
export const MIME_TYPE_CANDIDATES = [
  "video/mp4;codecs=avc1.42E01E,mp4a.40.2",
  "video/mp4",
  "video/webm;codecs=vp9,opus",
  "video/webm;codecs=vp8,opus",
  "video/webm",
] as const;

/**
 * Whether this browser can record the camera and microphone.
 *
 * `navigator.mediaDevices` only exists on secure pages (HTTPS or localhost), so
 * this is also false for a page served over plain HTTP.
 */
export function isRecordingSupported(): boolean {
  return (
    typeof navigator !== "undefined" &&
    typeof navigator.mediaDevices?.getUserMedia === "function" &&
    typeof MediaRecorder === "function"
  );
}

/**
 * The first format in {@link MIME_TYPE_CANDIDATES} that this browser can record,
 * or `undefined` when it supports none of them and should choose its own.
 */
export function pickMimeType(): string | undefined {
  if (typeof MediaRecorder === "undefined" || typeof MediaRecorder.isTypeSupported !== "function") {
    return undefined;
  }

  return MIME_TYPE_CANDIDATES.find((type) => MediaRecorder.isTypeSupported(type));
}
