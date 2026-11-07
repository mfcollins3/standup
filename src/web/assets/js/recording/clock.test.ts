import { describe, expect, it } from "vitest";

import { describeLimit, formatClock, milestoneMessage } from "./clock";

describe("formatClock", () => {
  it.each([
    [0, "0:00"],
    [5, "0:05"],
    [59, "0:59"],
    [60, "1:00"],
    [300, "5:00"],
    [-3, "0:00"],
  ])("formats %i seconds as %s", (seconds, expected) => {
    expect(formatClock(seconds)).toBe(expected);
  });
});

describe("milestoneMessage", () => {
  it("is null before the first milestone", () => {
    expect(milestoneMessage(300, 300)).toBeNull();
    expect(milestoneMessage(61, 300)).toBeNull();
  });

  it.each([
    [60, "1 minute left."],
    [31, "1 minute left."],
    [30, "30 seconds left."],
    [11, "30 seconds left."],
    [10, "10 seconds left."],
    [0, "10 seconds left."],
  ])("with %i seconds left says %s", (remaining, expected) => {
    expect(milestoneMessage(remaining, 300)).toBe(expected);
  });

  it("skips milestones that are not shorter than the limit", () => {
    expect(milestoneMessage(30, 30)).toBeNull();
    expect(milestoneMessage(29, 30)).toBeNull();
    expect(milestoneMessage(10, 30)).toBe("10 seconds left.");
  });
});

describe("describeLimit", () => {
  it("uses minutes for whole minutes and seconds otherwise", () => {
    expect(describeLimit(300_000)).toBe("5 minute");
    expect(describeLimit(60_000)).toBe("1 minute");
    expect(describeLimit(8_000)).toBe("8 second");
  });
});
