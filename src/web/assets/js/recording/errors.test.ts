import { describe, expect, it } from "vitest";

import { ERROR_MESSAGES, mapMediaError, type RecorderErrorCode } from "./errors";

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

describe("ERROR_MESSAGES", () => {
  it("has a message for every error", () => {
    const codes: RecorderErrorCode[] = [
      "unsupported",
      "permission-denied",
      "no-device",
      "device-busy",
      "unknown",
    ];

    for (const code of codes) {
      expect(ERROR_MESSAGES[code]).toMatch(/\S/);
    }
  });
});
