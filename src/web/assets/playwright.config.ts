import { defineConfig, devices } from "@playwright/test";

/**
 * End-to-end tests of the web app in a real browser. The tests are in
 * `src/web/assets/e2e`.
 *
 * Playwright starts the development server (`mix phx.server`) if it is not
 * already running. The page's JavaScript comes from the Vite dev server that
 * Phoenix starts, so `e2e/global-setup.ts` waits for that too. The server needs
 * the development database, like `mix phx.server` does.
 *
 * Chromium runs with a fake camera and microphone that produce a test pattern
 * and a beep, and with the permission prompt accepted, so the tests do not need
 * a real device or a person. One project uses the full Chromium and lets the tests
 * set the camera permission to "denied", for the tests of a real denial.
 */
export default defineConfig({
  testDir: "./e2e",
  outputDir: "../tmp/e2e-results",
  globalSetup: "./e2e/global-setup.ts",

  fullyParallel: true,
  forbidOnly: Boolean(process.env.CI),
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI
    ? [["github"], ["html", { open: "never", outputFolder: "../tmp/playwright-report" }]]
    : "list",

  use: {
    baseURL: "http://localhost:4000",
    trace: "retain-on-failure",
  },

  projects: [
    {
      name: "chromium",
      testIgnore: /permission-denied\.spec\.ts/,
      use: {
        ...devices["Desktop Chrome"],
        launchOptions: {
          args: ["--use-fake-device-for-media-stream", "--use-fake-ui-for-media-stream"],
        },
      },
    },
    {
      // For the tests of a camera that the browser has blocked. It is the full
      // Chromium, in headless mode, because the older headless Chromium has no
      // permission handling and answers "not supported" instead of "denied". The
      // permission prompt is not accepted here: the tests set the permission.
      name: "chromium-camera-denied",
      testMatch: /permission-denied\.spec\.ts/,
      use: {
        ...devices["Desktop Chrome"],
        channel: "chromium",
        launchOptions: { args: ["--use-fake-device-for-media-stream"] },
      },
    },
  ],

  webServer: {
    command: "mix phx.server",
    cwd: "..",
    url: "http://localhost:4000/healthz",
    reuseExistingServer: !process.env.CI,
    timeout: 180_000,
    stdout: "pipe",
    stderr: "pipe",
  },
});
