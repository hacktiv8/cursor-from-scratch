import { describe, expect, it } from "vitest";
import {
  formatDate,
  formatDateTimeAttr,
  formatTime,
  getClockSnapshot,
} from "./clock";

describe("formatDateTimeAttr", () => {
  it("pads hours, minutes, and seconds to two digits", () => {
    const date = new Date(2026, 6, 9, 9, 5, 3);
    expect(formatDateTimeAttr(date)).toBe("09:05:03");
  });

  it("formats afternoon times in 24-hour form", () => {
    const date = new Date(2026, 6, 9, 14, 30, 45);
    expect(formatDateTimeAttr(date)).toBe("14:30:45");
  });

  it("formats midnight as 00:00:00", () => {
    const date = new Date(2026, 6, 9, 0, 0, 0);
    expect(formatDateTimeAttr(date)).toBe("00:00:00");
  });
});

describe("formatTime", () => {
  it("returns a 24-hour time string with seconds", () => {
    const date = new Date(2026, 6, 9, 14, 30, 45);
    const formatted = formatTime(date);
    expect(formatted).toMatch(/14/);
    expect(formatted).toMatch(/30/);
    expect(formatted).toMatch(/45/);
  });
});

describe("formatDate", () => {
  it("includes weekday, day, month, and year for id-ID", () => {
    const date = new Date(2026, 6, 9, 12, 0, 0);
    const formatted = formatDate(date);
    expect(formatted.toLowerCase()).toContain("juli");
    expect(formatted).toContain("2026");
    expect(formatted).toContain("9");
  });
});

describe("getClockSnapshot", () => {
  it("returns consistent time, date, and datetime fields", () => {
    const date = new Date(2026, 6, 9, 8, 7, 6);
    const snapshot = getClockSnapshot(date);

    expect(snapshot.dateTime).toBe("08:07:06");
    expect(snapshot.time).toBe(formatTime(date));
    expect(snapshot.date).toBe(formatDate(date));
  });
});
