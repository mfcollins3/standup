import { expect, test, type Page } from "@playwright/test";

import {
  enableButton,
  failToStartWith,
  openRecordPage,
  project,
  watchMedia,
  type TrackedWindow,
} from "./helpers";

/**
 * Recording a status report in the browser (NS-010, first criterion): the user
 * chooses a project and records with the camera and microphone after allowing
 * the browser to use them.
 *
 * Chromium is started with a fake camera and microphone, and with the permission
 * prompt accepted (see playwright.config.ts).
 */

test.describe("recording a status report", () => {
  test.beforeEach(async ({ page }) => {
    await watchMedia(page);
    await openRecordPage(page);
  });

  test("records with the camera and microphone after a project is chosen", async ({ page }) => {
    // Nothing can be turned on until a project is chosen.
    await expect(page.getByRole("status")).toContainText("Choose a project to start.");
    await expect(enableButton(page)).toBeDisabled();

    await project(page).selectOption({ label: "Website redesign" });
    await expect(enableButton(page)).toBeEnabled();

    // The browser is not asked for the camera until the user clicks.
    expect(await page.evaluate(() => (window as unknown as TrackedWindow).__streams.length)).toBe(0);

    await enableButton(page).click();

    // A live preview shows the camera.
    const preview = page.getByLabel("Camera preview");
    await expect(preview).toBeVisible();
    await expect
      .poll(() => preview.evaluate((video: HTMLVideoElement) => video.videoWidth))
      .toBeGreaterThan(0);
    expect(
      await page.evaluate(() =>
        (window as unknown as TrackedWindow).__streams[0]?.getTracks().map((t) => t.readyState),
      ),
    ).toEqual(["live", "live"]);

    await page.getByRole("button", { name: "Start recording" }).click();
    await expect(page.getByRole("status")).toContainText("Recording.");

    // The project cannot be changed in the middle of a recording.
    await expect(project(page)).toBeDisabled();

    // Record for a couple of seconds.
    await expect
      .poll(() => preview.evaluate((video: HTMLVideoElement) => video.currentTime), {
        timeout: 15_000,
      })
      .toBeGreaterThan(2);

    await page.getByRole("button", { name: "Stop recording" }).click();

    // The server is told that the recording is ready, with its project, size and length.
    const ready = page.locator("#recording-ready");
    await expect(ready).toContainText("Website redesign");
    await expect(ready).toContainText(/\d+(\.\d+)? (KB|MB)/);

    const seconds = Number((await ready.innerText()).match(/(\d+(\.\d+)?) seconds/)?.[1]);
    expect(seconds).toBeGreaterThan(1.5);
    expect(seconds).toBeLessThan(15);

    // The project can be changed again.
    await expect(project(page)).toBeEnabled();

    // The camera and microphone are off, and the preview is gone.
    await expect(preview).toHaveCount(0);
    expect(
      await page.evaluate(() =>
        (window as unknown as TrackedWindow).__streams[0]?.getTracks().map((t) => t.readyState),
      ),
    ).toEqual(["ended", "ended"]);

    // The browser recorded a video format that can be played back.
    const mimeType = await page.evaluate(
      () => (window as unknown as TrackedWindow).__recorders[0]?.mimeType,
    );
    expect(mimeType).toMatch(/^video\/(mp4|webm)/);
  });

  test("reviews a recording, discards it with confirmation, and records again", async ({ page }) => {
    await project(page).selectOption({ label: "Mobile app" });
    await enableButton(page).click();
    await page.getByRole("button", { name: "Start recording" }).click();
    await page.getByRole("button", { name: "Stop recording" }).click();
    await expect(page.locator("#recording-ready")).toContainText("Mobile app");

    // The recording can be played back before anything else.
    const player = page.getByLabel("Your recording");
    await expect(player).toBeVisible();
    await expect(player).toHaveAttribute("controls", "");
    await expect
      .poll(() => player.evaluate((video: HTMLVideoElement) => video.readyState))
      .toBeGreaterThan(0);
    const url = await player.getAttribute("src");
    expect(url).toMatch(/^blob:/);

    // Cancelling the confirmation keeps the recording.
    await page.getByRole("button", { name: "Discard" }).click();
    await expect(page.getByRole("alertdialog", { name: "Discard this recording?" })).toBeVisible();
    await expect(page.getByRole("button", { name: "Keep recording" })).toBeFocused();
    await page.keyboard.press("Escape");
    await expect(page.getByRole("alertdialog")).toHaveCount(0);
    await expect(player).toBeVisible();
    await expect(page.locator("#recording-ready")).toBeVisible();

    // Leaving the page while the recording is kept asks the browser to confirm.
    const asked = await page.evaluate(() => {
      const event = new Event("beforeunload", { cancelable: true });
      window.dispatchEvent(event);
      return event.defaultPrevented;
    });
    expect(asked).toBe(true);

    // Discarding throws it away, and the page stops saying it is ready.
    await page.getByRole("button", { name: "Discard" }).click();
    await page.getByRole("button", { name: "Discard recording" }).click();
    await expect(page.getByLabel("Your recording")).toHaveCount(0);
    await expect(page.locator("#recording-ready")).toHaveCount(0);
    await expect(enableButton(page)).toBeEnabled();
    expect(
      await page.evaluate(() => {
        const event = new Event("beforeunload", { cancelable: true });
        window.dispatchEvent(event);
        return event.defaultPrevented;
      }),
    ).toBe(false);

    // Recording again, for the same project, goes back to the camera preview.
    await enableButton(page).click();
    await page.getByRole("button", { name: "Start recording" }).click();
    await page.getByRole("button", { name: "Stop recording" }).click();
    await expect(page.locator("#recording-ready")).toContainText("Mobile app");

    await page.getByRole("button", { name: "Record again" }).click();
    await page.getByRole("button", { name: "Delete and record again" }).click();
    await expect(page.getByLabel("Camera preview")).toBeVisible();
    await expect(page.locator("#recording-ready")).toHaveCount(0);
    await page.getByRole("button", { name: "Start recording" }).click();
    await page.getByRole("button", { name: "Stop recording" }).click();

    await expect(page.getByLabel("Your recording")).toBeVisible();
    await expect(page.locator("#recording-ready")).toContainText("Mobile app");
    expect(await page.evaluate(() => (window as unknown as TrackedWindow).__streams.length)).toBe(3);
  });

  test("clears the finished recording when another project is chosen", async ({ page }) => {
    await project(page).selectOption({ label: "Website redesign" });
    await enableButton(page).click();
    await page.getByRole("button", { name: "Start recording" }).click();
    await page.getByRole("button", { name: "Stop recording" }).click();
    await expect(page.locator("#recording-ready")).toBeVisible();

    await project(page).selectOption({ label: "Platform migration" });

    await expect(page.locator("#recording-ready")).toHaveCount(0);
  });

  test("never captures the screen", async ({ page }) => {
    await project(page).selectOption({ index: 1 });
    await enableButton(page).click();
    await page.getByRole("button", { name: "Start recording" }).click();
    await page.getByRole("button", { name: "Stop recording" }).click();
    await expect(page.locator("#recording-ready")).toBeVisible();

    expect(
      await page.evaluate(() => (window as unknown as TrackedWindow).__displayMediaCalls),
    ).toBe(0);
    await expect(page.getByText(/screen/i)).toHaveCount(0);
  });
});

test.describe("the recording limit", () => {
  // The server is started with a limit of 8 seconds (see playwright.config.ts).
  const LIMIT_SECONDS = 8;
  const stoppedMessage = `Recording stopped at the ${LIMIT_SECONDS} second limit.`;

  async function startRecording(page: Page) {
    await openRecordPage(page);
    await project(page).selectOption({ label: "Website redesign" });
    await enableButton(page).click();
    await page.getByRole("button", { name: "Start recording" }).click();
  }

  async function expectStoppedAtTheLimit(page: Page) {
    // The user is told, in the status and on the page that the server renders.
    await expect(page.getByRole("status").first()).toContainText(stoppedMessage, {
      timeout: 15_000,
    });
    const ready = page.locator("#recording-ready");
    await expect(ready).toContainText("Website redesign");
    await expect(ready).toContainText(stoppedMessage);

    // It stopped by itself within a second of the limit, and kept the recording.
    const seconds = Number((await ready.innerText()).match(/(\d+(\.\d+)?) seconds/)?.[1]);
    expect(seconds).toBeGreaterThanOrEqual(LIMIT_SECONDS - 0.5);
    expect(seconds).toBeLessThanOrEqual(LIMIT_SECONDS + 1);
    await expect(ready).toContainText(/\d+(\.\d+)? (KB|MB)/);

    await expect(page.getByRole("button", { name: "Stop recording" })).toHaveCount(0);
    await expect(project(page)).toBeEnabled();
    expect(
      await page.evaluate(() =>
        (window as unknown as TrackedWindow).__streams[0]?.getTracks().map((t) => t.readyState),
      ),
    ).toEqual(["ended", "ended"]);
  }

  test("shows the elapsed and remaining time, and stops by itself at the limit", async ({
    page,
  }) => {
    await watchMedia(page);
    await startRecording(page);

    const timer = page.getByRole("timer");
    await expect(timer).toContainText("Elapsed 0:00");
    await expect(timer).toContainText(`Remaining 0:0${LIMIT_SECONDS}`);

    // The clock moves every second.
    await expect(timer).toContainText("Elapsed 0:02");
    await expect(timer).toContainText(`Remaining 0:0${LIMIT_SECONDS - 2}`);

    // The clock is not read out: the status does not carry it.
    await expect(page.getByRole("status").first()).not.toContainText("Elapsed");

    await expectStoppedAtTheLimit(page);
  });

  test("stops at the limit when the tab is in the background", async ({ page, context }) => {
    await watchMedia(page);
    await startRecording(page);

    // Bring another tab to the front, so the recorder's tab is behind it.
    const other = await context.newPage();
    await other.goto("about:blank");
    await other.bringToFront();

    await expectStoppedAtTheLimit(page);

    await other.close();
  });
});

test.describe("when the camera cannot be used", () => {
  test("tells the user that the browser blocked it, with steps, and lets them try again", async ({
    page,
  }) => {
    await failToStartWith(page, "NotAllowedError");
    await openRecordPage(page);

    await project(page).selectOption({ index: 1 });
    await enableButton(page).click();

    const alert = page.getByRole("alert");
    await expect(alert).toContainText("blocked the camera and microphone");
    await expect(alert.getByRole("listitem")).not.toHaveCount(0);
    await expect(page.getByLabel("Camera preview")).toHaveCount(0);
    await expect(page.getByRole("button", { name: "Try again" })).toBeEnabled();
  });

  test("tells the user that there is no camera", async ({ page }) => {
    await failToStartWith(page, "NotFoundError");
    await openRecordPage(page);

    await project(page).selectOption({ index: 1 });
    await enableButton(page).click();

    await expect(page.getByRole("alert")).toContainText("No camera or microphone was found");
    await expect(page.getByRole("button", { name: "Try again" })).toBeEnabled();
  });
});

test.describe("the page in development", () => {
  // The page is not always on http://localhost:4000. Aspire serves the app
  // through a proxy on a random port, and http://127.0.0.1:4000 is a different
  // origin than http://localhost:4000. The Vite dev server, which serves the
  // page's JavaScript from another port, has to allow all of them, or the page
  // loads with no JavaScript and the recorder never appears.
  for (const origin of ["http://127.0.0.1:4000", "http://localhost:4000"]) {
    test(`loads its JavaScript when opened from ${origin}`, async ({ page }) => {
      const errors: string[] = [];
      page.on("console", (message) => {
        if (message.type() === "error") errors.push(message.text());
      });

      await page.goto(`${origin}/record`);

      // The recorder is a React component, so it only appears when the scripts load.
      await expect(page.getByRole("status")).toBeVisible();
      expect(errors.filter((error) => /CORS/i.test(error))).toEqual([]);
    });
  }
});
