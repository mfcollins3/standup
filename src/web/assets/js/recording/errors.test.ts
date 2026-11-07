import { describe, expect, it } from "vitest";

import type { BrowserFamily } from "./browser";
import {
  describeBlocked,
  describeError,
  describeWarning,
  mapMediaError,
  type RecorderErrorCode,
} from "./errors";

const BROWSERS: BrowserFamily[] = ["chrome", "edge", "safari", "other"];
const ERRORS: RecorderErrorCode[] = [
  "unsupported",
  "permission-denied",
  "no-device",
  "device-busy",
  "unknown",
];

describe("mapMediaError", () => {
  it.each<[string, RecorderErrorCode]>([
    ["NotAllowedError", "permission-denied"],
    ["SecurityError", "permission-denied"],
    ["NotFoundError", "no-device"],
    ["OverconstrainedError", "no-device"],
    ["NotReadableError", "device-busy"],
    ["AbortError", "unknown"],
    ["SomethingElse", "unknown"],
  ])("maps %s to %s", (name, code) => {
    expect(mapMediaError({ name })).toBe(code);
  });

  it("reads the name of a real DOMException", () => {
    expect(mapMediaError(new DOMException("denied", "NotAllowedError"))).toBe("permission-denied");
  });

  it.each([undefined, null, "NotAllowedError", 42])("treats %s as unknown", (value) => {
    expect(mapMediaError(value)).toBe("unknown");
  });
});

describe("describeError", () => {
  it.each(ERRORS.flatMap((code) => BROWSERS.map((browser) => [code, browser] as const)))(
    "says what happened and what to do for %s in %s",
    (code, browser) => {
      const help = describeError(code, browser);

      expect(help.title).toMatch(/\S/);
      expect(help.steps.length).toBeGreaterThan(0);
      for (const step of help.steps) expect(step).toMatch(/\S/);
    },
  );

  it.each<[RecorderErrorCode, boolean]>([
    ["permission-denied", true],
    ["no-device", true],
    ["device-busy", true],
    ["unknown", true],
    ["unsupported", false],
  ])("says whether trying again can work for %s", (code, canRetry) => {
    expect(describeError(code, "chrome").canRetry).toBe(canRetry);
  });

  it("tells the user to try again when that can work", () => {
    for (const code of ERRORS.filter((code) => code !== "unsupported")) {
      const steps = describeError(code, "chrome").steps.join(" ");
      expect(steps).toMatch(/Try again/);
    }
  });

  it("names the app or the situation for each case", () => {
    expect(describeError("no-device", "chrome").title).toMatch(/No camera or microphone/);
    expect(describeError("device-busy", "chrome").title).toMatch(/another app/);
    expect(describeError("unsupported", "chrome").steps.join(" ")).toMatch(/Chrome, Edge or Safari/);
    expect(describeError("unsupported", "chrome").steps.join(" ")).toMatch(/https/);
  });
});

describe("describeBlocked", () => {
  it("is what a denied permission says", () => {
    expect(describeError("permission-denied", "safari")).toEqual(describeBlocked("safari"));
  });

  it("explains how to allow the camera in each browser", () => {
    const steps = (browser: BrowserFamily) => describeBlocked(browser).steps.join(" ");

    expect(steps("chrome")).toMatch(/address bar/);
    expect(steps("edge")).toMatch(/lock icon/);
    expect(steps("safari")).toMatch(/Settings for This Website/);
    expect(steps("other")).toMatch(/browser's settings/);
  });

  it("does not give one browser's menus to another", () => {
    expect(describeBlocked("chrome").steps.join(" ")).not.toMatch(/Safari/);
    expect(describeBlocked("safari").steps.join(" ")).not.toMatch(/address bar/);
  });

  it("mentions the system's privacy settings, which can block an allowed browser", () => {
    for (const browser of BROWSERS) {
      expect(describeBlocked(browser).steps.join(" ")).toMatch(/privacy settings/);
    }
  });
});

describe("describeWarning", () => {
  it("says that the recording ended early and that it was kept", () => {
    const help = describeWarning("device-lost");

    expect(help.title).toMatch(/ended early/);
    expect(help.steps.join(" ")).toMatch(/kept/);
  });
});
