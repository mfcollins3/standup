/** Why the recorder could not start or continue. */
export type RecorderErrorCode =
  | "unsupported"
  | "permission-denied"
  | "no-device"
  | "device-busy"
  | "unknown";

/**
 * Turns the error from `getUserMedia` into one of the {@link RecorderErrorCode}s.
 * The browsers report these as a `DOMException` with a standard name.
 */
export function mapMediaError(error: unknown): RecorderErrorCode {
  const name =
    typeof error === "object" && error !== null && "name" in error
      ? String((error as { name: unknown }).name)
      : "";

  switch (name) {
    case "NotAllowedError":
    case "SecurityError":
      return "permission-denied";
    case "NotFoundError":
    case "OverconstrainedError":
      return "no-device";
    case "NotReadableError":
      return "device-busy";
    default:
      return "unknown";
  }
}

/**
 * A short message for each error. They are placeholders for the plain-language
 * messages with next steps that NS-010's last criterion calls for.
 */
export const ERROR_MESSAGES: Record<RecorderErrorCode, string> = {
  unsupported:
    "This browser can't record video here. Use a current version of Chrome, Edge or Safari on a secure (HTTPS) page.",
  "permission-denied": "Access to your camera and microphone was denied.",
  "no-device": "No camera or microphone was found.",
  "device-busy": "Your camera or microphone is being used by another app.",
  unknown: "The camera and microphone could not be started.",
};
