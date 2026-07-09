import { describe, expect, it, vi } from "vitest";
import {
  formatDate,
  formatDateTimeAttr,
  formatTime,
  getClockSnapshot,
  getIndonesiaClocksSnapshot,
  startIndonesiaClocks,
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
  it("returns the id-ID 24-hour time string with seconds", () => {
    const date = new Date(2026, 6, 9, 14, 30, 45);
    expect(formatTime(date)).toBe("14.30.45");
  });

  it("formats the same instant in WIB, WITA, and WIT", () => {
    // 07:00 UTC → 14:00 WIB, 15:00 WITA, 16:00 WIT
    const instant = new Date("2026-07-09T07:00:00.000Z");

    expect(formatTime(instant, "Asia/Jakarta")).toBe("14.00.00");
    expect(formatTime(instant, "Asia/Makassar")).toBe("15.00.00");
    expect(formatTime(instant, "Asia/Jayapura")).toBe("16.00.00");
  });
});

describe("formatDate", () => {
  it("returns the id-ID weekday, day, month, and year", () => {
    const date = new Date(2026, 6, 9, 12, 0, 0);
    expect(formatDate(date)).toBe("Kamis, 9 Juli 2026");
  });

  it("can show different calendar days across Indonesian zones", () => {
    // 16:30 UTC → 23:30 WIB (9 Jul), 00:30 WITA (10 Jul), 01:30 WIT (10 Jul)
    const instant = new Date("2026-07-09T16:30:00.000Z");

    expect(formatDate(instant, "Asia/Jakarta")).toBe("Kamis, 9 Juli 2026");
    expect(formatDate(instant, "Asia/Makassar")).toBe("Jumat, 10 Juli 2026");
    expect(formatDate(instant, "Asia/Jayapura")).toBe("Jumat, 10 Juli 2026");
  });
});

describe("getClockSnapshot", () => {
  it("returns consistent time, date, and datetime fields", () => {
    const date = new Date(2026, 6, 9, 8, 7, 6);
    const snapshot = getClockSnapshot(date);

    expect(snapshot).toEqual({
      time: formatTime(date),
      date: formatDate(date),
      dateTime: "08:07:06",
    });
  });

  it("returns values for a specific Indonesian time zone", () => {
    const instant = new Date("2026-07-09T07:00:00.000Z");
    const snapshot = getClockSnapshot(instant, "Asia/Makassar");

    expect(snapshot).toEqual({
      time: "15.00.00",
      date: "Kamis, 9 Juli 2026",
      dateTime: "15:00:00",
    });
  });
});

describe("getIndonesiaClocksSnapshot", () => {
  it("returns WIB, WITA, and WIT snapshots for comparison", () => {
    const instant = new Date("2026-07-09T07:00:00.000Z");
    const snapshots = getIndonesiaClocksSnapshot(instant);

    expect(snapshots).toEqual([
      {
        id: "Asia/Jakarta",
        label: "WIB",
        name: "Waktu Indonesia Barat",
        time: "14.00.00",
        date: "Kamis, 9 Juli 2026",
        dateTime: "14:00:00",
      },
      {
        id: "Asia/Makassar",
        label: "WITA",
        name: "Waktu Indonesia Tengah",
        time: "15.00.00",
        date: "Kamis, 9 Juli 2026",
        dateTime: "15:00:00",
      },
      {
        id: "Asia/Jayapura",
        label: "WIT",
        name: "Waktu Indonesia Timur",
        time: "16.00.00",
        date: "Kamis, 9 Juli 2026",
        dateTime: "16:00:00",
      },
    ]);
  });
});

describe("startIndonesiaClocks", () => {
  const createZoneElements = () =>
    ["Asia/Jakarta", "Asia/Makassar", "Asia/Jayapura"].map((id) => ({
      id,
      clockEl: { textContent: "", dateTime: "" } as HTMLTimeElement,
      dateEl: { textContent: "" } as HTMLElement,
    }));

  it("renders all three Indonesian zones immediately", () => {
    const zones = createZoneElements();
    const now = () => new Date("2026-07-09T07:00:00.000Z");
    const setInterval = vi.fn(
      () => 1 as unknown as ReturnType<typeof globalThis.setInterval>,
    );
    const clearInterval = vi.fn();

    const stop = startIndonesiaClocks(zones, { now, setInterval, clearInterval });

    expect(zones[0]?.clockEl.textContent).toBe("14.00.00");
    expect(zones[0]?.clockEl.dateTime).toBe("14:00:00");
    expect(zones[0]?.dateEl.textContent).toBe("Kamis, 9 Juli 2026");
    expect(zones[1]?.clockEl.textContent).toBe("15.00.00");
    expect(zones[2]?.clockEl.textContent).toBe("16.00.00");
    expect(setInterval).toHaveBeenCalledWith(expect.any(Function), 1000);

    stop();
    expect(clearInterval).toHaveBeenCalledWith(1);
  });

  it("updates every zone on each scheduled tick", () => {
    const zones = createZoneElements();
    let instant = new Date("2026-07-09T07:00:00.000Z");
    let tick: (() => void) | undefined;

    const stop = startIndonesiaClocks(zones, {
      now: () => instant,
      setInterval: (fn) => {
        tick = fn as () => void;
        return 7 as unknown as ReturnType<typeof globalThis.setInterval>;
      },
      clearInterval: vi.fn(),
    });

    instant = new Date("2026-07-09T07:00:01.000Z");
    tick?.();

    expect(zones[0]?.clockEl.dateTime).toBe("14:00:01");
    expect(zones[1]?.clockEl.dateTime).toBe("15:00:01");
    expect(zones[2]?.clockEl.dateTime).toBe("16:00:01");

    stop();
  });
});
