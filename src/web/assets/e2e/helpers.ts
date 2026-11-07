import { expect, type Browser, type CDPSession, type Page } from "@playwright/test";

/**
 * Helpers that the end-to-end tests share.
 */

export interface TrackedWindow extends Window {
  __streams: MediaStream[];
  __recorders: MediaRecorder[];
  __displayMediaCalls: number;
}

/**
 * Watches the media APIs, so the tests can look at what the page did with them:
 * the streams that it was given, the recorders that it made, and whether it ever
 * asked to capture the screen.
 */
export async function watchMedia(page: Page) {
  await page.addInitScript(() => {
    const tracked = window as unknown as TrackedWindow;
    tracked.__streams = [];
    tracked.__recorders = [];
    tracked.__displayMediaCalls = 0;

    const devices = navigator.mediaDevices;
    const getUserMedia = devices.getUserMedia.bind(devices);
    devices.getUserMedia = async (constraints) => {
      const stream = await getUserMedia(constraints);
      tracked.__streams.push(stream);
      return stream;
    };

    devices.getDisplayMedia = () => {
      tracked.__displayMediaCalls += 1;
      return Promise.reject(new DOMException("not allowed", "NotAllowedError"));
    };

    const NativeRecorder = window.MediaRecorder;
    window.MediaRecorder = class extends NativeRecorder {
      constructor(stream: MediaStream, options?: MediaRecorderOptions) {
        super(stream, options);
        tracked.__recorders.push(this);
      }
    };
  });
}

/** Makes the camera and microphone fail to start with this kind of error. */
export async function failToStartWith(page: Page, name: string) {
  await page.addInitScript((errorName) => {
    navigator.mediaDevices.getUserMedia = () =>
      Promise.reject(new DOMException("test", errorName));
  }, name);
}

/**
 * Opens the page, and waits until LiveView is connected and the recorder is on
 * the page. A choice made before that is lost: the server has not heard about it,
 * and its first render puts the page back to the start.
 */
export async function openRecordPage(page: Page) {
  await page.goto("/record");
  await expect(page.locator("[data-phx-main].phx-connected")).toBeAttached();
  // There can be more than one status on the page, such as help for a blocked camera.
  await expect(page.getByRole("status").first()).toBeVisible();
}

export const project = (page: Page) => page.getByLabel("Project");
export const enableButton = (page: Page) =>
  page.getByRole("button", { name: "Enable camera and microphone" });

// The permissions are only in effect while the DevTools session that set them is
// open, so one session is kept for each browser, until the browser closes.
const sessions = new WeakMap<Browser, CDPSession>();

/**
 * Sets what the browser has decided about the camera and microphone for the app,
 * as if the user had clicked Block or Allow in the address bar. The browser then
 * behaves for real: `navigator.permissions` reports the state, `getUserMedia`
 * is denied, and a change fires the permission's `change` event.
 *
 * It uses the Chrome DevTools Protocol, so it only works in Chromium.
 */
export async function setCameraPermission(
  browser: Browser,
  setting: "granted" | "denied" | "prompt",
  origin = "http://localhost:4000",
) {
  let cdp = sessions.get(browser);
  if (!cdp) {
    cdp = await browser.newBrowserCDPSession();
    sessions.set(browser, cdp);
  }

  const { browserContextIds } = await cdp.send("Target.getBrowserContexts");

  for (const browserContextId of browserContextIds) {
    for (const name of ["camera", "microphone"]) {
      await cdp.send("Browser.setPermission", {
        permission: { name },
        setting,
        origin,
        browserContextId,
      });
    }
  }
}
