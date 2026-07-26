import { describe, expect, it } from "vitest";
import { getClockSnapshot, pad } from "./clock";

describe("pad", () => {
  it("pads single-digit numbers", () => {
    expect(pad(0)).toBe("00");
    expect(pad(9)).toBe("09");
  });

  it("leaves two-digit numbers unchanged", () => {
    expect(pad(10)).toBe("10");
    expect(pad(59)).toBe("59");
  });
});

describe("getClockSnapshot", () => {
  it("returns padded time parts and a local datetime attribute", () => {
    const now = new Date(2026, 6, 26, 9, 5, 3);
    const snap = getClockSnapshot(now);

    expect(snap.hours).toBe("09");
    expect(snap.minutes).toBe("05");
    expect(snap.seconds).toBe("03");
    expect(snap.datetime).toBe("2026-07-26T09:05:03");
  });

  it("formats afternoon times in 24-hour form", () => {
    const snap = getClockSnapshot(new Date(2026, 6, 26, 14, 30, 45));

    expect(snap.hours).toBe("14");
    expect(snap.minutes).toBe("30");
    expect(snap.seconds).toBe("45");
    expect(snap.datetime).toBe("2026-07-26T14:30:45");
  });

  it("formats the date in id-ID and includes a UTC offset zone label", () => {
    const now = new Date(2026, 6, 26, 12, 0, 0);
    const snap = getClockSnapshot(now);

    expect(snap.date.toLowerCase()).toContain("juli");
    expect(snap.date).toContain("2026");
    expect(snap.date).toContain("26");
    expect(snap.zone).toMatch(/UTC[+-]\d{2}:\d{2}$/);
  });
});
