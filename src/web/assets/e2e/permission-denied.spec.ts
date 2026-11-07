import { expect, test } from "@playwright/test";

import {
  enableButton,
  openRecordPage,
  project,
  setCameraPermission,
  watchMedia,
  type TrackedWindow,
} from "./helpers";

/**
 * What the user sees when the browser really blocks the camera and microphone.
 *
 * Nothing is stubbed here. The browser's permission for the camera and microphone
 * is set to "denied", as if the user had clicked Block, and Chromium behaves as
 * it does for a real person: it reports the state, it refuses `getUserMedia` with
 * a real `NotAllowedError`, and it tells the page when the permission changes.
 *
 * This file runs in its own Playwright project (see playwright.config.ts), in the
 * full Chromium that handles permissions. The old headless Chromium has no
 * permission handling, and answers "not supported" instead of "denied".
 */
test.describe("when the browser has blocked the camera", () => {
  test.beforeEach(async ({ browser, page }) => {
    await setCameraPermission(browser, "denied");
    await watchMedia(page);
    await openRecordPage(page);
  });

  const blockedHelp = (page: import("@playwright/test").Page) =>
    page.getByText("Your browser has blocked the camera and microphone for this site.");

  test("explains how to allow it before the user clicks anything", async ({ page }) => {
    const help = blockedHelp(page);

    await expect(help).toBeVisible();
    const panel = page.locator("[role=status]", { has: help });
    await expect(panel.getByRole("listitem")).not.toHaveCount(0);
    await expect(panel).toContainText("Press Try again");
    expect(await page.evaluate(() => (window as unknown as TrackedWindow).__streams.length)).toBe(0);
  });

  test("shows the browser's real error after a click, and the camera never turns on", async ({
    page,
  }) => {
    await project(page).selectOption({ index: 1 });
    await enableButton(page).click();

    const alert = page.getByRole("alert");
    await expect(alert).toContainText("blocked the camera and microphone");
    await expect(alert.getByRole("listitem")).not.toHaveCount(0);
    await expect(page.getByLabel("Camera preview")).toHaveCount(0);
    await expect(page.getByRole("button", { name: "Try again" })).toBeEnabled();

    // The explanation is shown once: the error replaces the early help.
    await expect(blockedHelp(page)).toHaveCount(1);
    expect(await page.evaluate(() => (window as unknown as TrackedWindow).__streams.length)).toBe(0);
  });

  test("lets the user record once they allow the camera in the browser", async ({
    browser,
    page,
  }) => {
    await project(page).selectOption({ index: 1 });
    await enableButton(page).click();
    await expect(page.getByRole("alert")).toBeVisible();

    // The user follows the steps: allow the camera and microphone for this site.
    await setCameraPermission(browser, "granted");

    // The browser tells the page, and the out-of-date error goes away.
    await expect(page.getByRole("alert")).toHaveCount(0);
    await expect(blockedHelp(page)).toHaveCount(0);

    await enableButton(page).click();
    await expect(page.getByLabel("Camera preview")).toBeVisible();
    await page.getByRole("button", { name: "Start recording" }).click();
    await page.getByRole("button", { name: "Stop recording" }).click();
    await expect(page.locator("#recording-ready")).toBeVisible();
  });
});
