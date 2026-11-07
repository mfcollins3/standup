import { describe, expect, it } from "vitest";

import { detectBrowser, type BrowserFamily } from "./browser";

const USER_AGENTS: [string, BrowserFamily, string][] = [
  [
    "Chrome on a Mac",
    "chrome",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36",
  ],
  [
    "Chrome on Windows",
    "chrome",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36",
  ],
  [
    "Chrome on Android",
    "chrome",
    "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36",
  ],
  [
    "headless Chrome, as in the automated tests",
    "chrome",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/158.0.0.0 Safari/537.36",
  ],
  [
    "Edge on Windows",
    "edge",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 Edg/130.0.0.0",
  ],
  [
    "Edge on a Mac",
    "edge",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 Edg/130.0.0.0",
  ],
  [
    "Safari on a Mac",
    "safari",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15",
  ],
  [
    "Safari on an iPhone",
    "other",
    "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
  ],
  [
    "Chrome on an iPhone",
    "other",
    "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/130.0.0.0 Mobile/15E148 Safari/604.1",
  ],
  [
    "Firefox",
    "other",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:131.0) Gecko/20100101 Firefox/131.0",
  ],
  [
    "Opera",
    "other",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 OPR/115.0.0.0",
  ],
];

describe("detectBrowser", () => {
  it.each(USER_AGENTS)("recognizes %s as %s", (_name, family, userAgent) => {
    expect(detectBrowser(userAgent)).toBe(family);
  });

  it("is `other` for an empty user agent", () => {
    expect(detectBrowser("")).toBe("other");
  });

  it("reads the browser's own user agent by default", () => {
    expect(detectBrowser()).toBe(detectBrowser(navigator.userAgent));
  });
});
