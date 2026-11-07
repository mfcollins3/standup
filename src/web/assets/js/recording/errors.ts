import type { BrowserFamily } from "./browser";

/** Why the recorder could not start. */
export type RecorderErrorCode =
  | "unsupported"
  | "permission-denied"
  | "no-device"
  | "device-busy"
  | "unknown";

/** Something that went wrong during a recording, which is kept. */
export type RecorderWarningCode = "device-lost";

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

/** What is shown to the user: what happened, and what to do about it. */
export interface Help {
  /** What happened, in one sentence. */
  title: string;
  /** What to do, in order. */
  steps: string[];
}

/** Help for an error, and whether trying again can work. */
export interface ErrorHelp extends Help {
  canRetry: boolean;
}

/**
 * The steps to allow the camera and microphone again. Each browser has its own
 * menus. The last step is for the system settings, which can block a browser that
 * the site settings allow.
 */
const ALLOW_STEPS: Record<BrowserFamily, string[]> = {
  chrome: [
    "Select the camera icon or the settings icon at the left of the address bar.",
    "Allow the camera and microphone for this site.",
  ],
  edge: [
    "Select the lock icon or the camera icon at the left of the address bar.",
    "Allow the camera and microphone for this site.",
  ],
  safari: [
    "In the menu bar, choose Safari, then Settings for This Website.",
    "Set Camera and Microphone to Allow.",
  ],
  other: ["Open your browser's settings for this site, and allow the camera and microphone."],
};

const SYSTEM_SETTINGS_STEP =
  "If it still does not work, check that your computer's privacy settings let your browser use the camera and microphone, and reload this page.";

/** The help shown when the browser has blocked the camera and microphone. */
export function describeBlocked(browser: BrowserFamily): ErrorHelp {
  return {
    title: "Your browser has blocked the camera and microphone for this site.",
    steps: [...ALLOW_STEPS[browser], "Press Try again.", SYSTEM_SETTINGS_STEP],
    canRetry: true,
  };
}

/** The help for an error, for the browser that is being used. */
export function describeError(code: RecorderErrorCode, browser: BrowserFamily): ErrorHelp {
  switch (code) {
    case "permission-denied":
      return describeBlocked(browser);

    case "no-device":
      return {
        title: "No camera or microphone was found.",
        steps: [
          "Check that a camera and a microphone are connected and turned on.",
          "Press Try again.",
        ],
        canRetry: true,
      };

    case "device-busy":
      return {
        title: "Your camera or microphone is being used by another app.",
        steps: [
          "Close other apps and browser tabs that use the camera, such as a meeting app.",
          "Press Try again.",
        ],
        canRetry: true,
      };

    case "unsupported":
      return {
        title: "This browser can't record video on this page.",
        steps: [
          "Use the latest version of Chrome, Edge or Safari.",
          "Open the page at its https:// address. Recording does not work on a page that is not secure.",
        ],
        canRetry: false,
      };

    case "unknown":
      return {
        title: "The camera and microphone could not be started.",
        steps: ["Press Try again.", "If it keeps happening, reload this page."],
        canRetry: true,
      };
  }
}

/** The help for something that went wrong during a recording. */
export function describeWarning(code: RecorderWarningCode): Help {
  switch (code) {
    case "device-lost":
      return {
        title: "Your camera or microphone stopped during the recording, so it ended early.",
        steps: [
          "The part that was recorded is kept.",
          "Check that the camera and microphone are connected and allowed, then record again if you need to.",
        ],
      };
  }
}
