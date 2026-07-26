import { describe, expect, it } from "vitest";
import { getClockSnapshot, getIndonesianClocks, pad } from "./clock";

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

describe("getIndonesianClocks", () => {
  it("returns WIB, WITA, and WIT snapshots for the same instant", () => {
    const now = new Date("2026-07-26T05:05:03.000Z");
    const clocks = getIndonesianClocks(now);

    expect(clocks).toHaveLength(3);
    expect(clocks.map((c) => c.id)).toEqual(["WIB", "WITA", "WIT"]);
    expect(clocks.map((c) => c.name)).toEqual([
      "Waktu Indonesia Barat",
      "Waktu Indonesia Tengah",
      "Waktu Indonesia Timur",
    ]);

    expect(clocks[0]).toMatchObject({
      hours: "12",
      minutes: "05",
      seconds: "03",
      offset: "UTC+07:00",
    });
    expect(clocks[1]).toMatchObject({
      hours: "13",
      minutes: "05",
      seconds: "03",
      offset: "UTC+08:00",
    });
    expect(clocks[2]).toMatchObject({
      hours: "14",
      minutes: "05",
      seconds: "03",
      offset: "UTC+09:00",
    });
  });

  it("keeps dates aligned to each zone when crossing midnight", () => {
    const now = new Date("2026-07-26T16:30:00.000Z");
    const clocks = getIndonesianClocks(now);

    expect(clocks[0]).toMatchObject({
      hours: "23",
      minutes: "30",
      datetime: "2026-07-26T23:30:00",
    });
    expect(clocks[0].date).toContain("26");
    expect(clocks[0].date.toLowerCase()).toContain("juli");

    expect(clocks[1]).toMatchObject({
      hours: "00",
      minutes: "30",
      datetime: "2026-07-27T00:30:00",
    });
    expect(clocks[1].date).toContain("27");

    expect(clocks[2]).toMatchObject({
      hours: "01",
      minutes: "30",
      datetime: "2026-07-27T01:30:00",
    });
    expect(clocks[2].date).toContain("27");
  });
});
