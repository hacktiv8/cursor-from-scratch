import { describe, expect, it, vi } from "vitest";
import {
  applyLocalZoneHighlight,
  formatDate,
  formatDateTimeAttr,
  formatTime,
  getClockSnapshot,
  getIndonesiaClocksSnapshot,
  resolveIndonesiaZone,
  startIndonesiaClocks,
} from "./clock";

describe("resolveIndonesiaZone", () => {
  it("maps known IANA ids to WIB, WITA, and WIT", () => {
    expect(resolveIndonesiaZone("Asia/Jakarta")).toBe("Asia/Jakarta");
    expect(resolveIndonesiaZone("Asia/Pontianak")).toBe("Asia/Jakarta");
    expect(resolveIndonesiaZone("Asia/Makassar")).toBe("Asia/Makassar");
    expect(resolveIndonesiaZone("Asia/Ujung_Pandang")).toBe("Asia/Makassar");
    expect(resolveIndonesiaZone("Asia/Jayapura")).toBe("Asia/Jayapura");
  });

  it("matches by UTC offset when the IANA id is an alias outside the list", () => {
    // Asia/Bangkok is UTC+7 year-round, same as WIB
    expect(resolveIndonesiaZone("Asia/Bangkok")).toBe("Asia/Jakarta");
  });

  it("returns undefined when the offset matches none of the Indonesian zones", () => {
    expect(resolveIndonesiaZone("America/New_York")).toBeUndefined();
  });
});

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

describe("applyLocalZoneHighlight", () => {
  const createRoots = () =>
    ["Asia/Jakarta", "Asia/Makassar", "Asia/Jayapura"].map((id) => {
      const classList = {
        values: new Set<string>(),
        toggle(token: string, force?: boolean) {
          if (force === undefined) {
            if (this.values.has(token)) this.values.delete(token);
            else this.values.add(token);
            return;
          }
          if (force) this.values.add(token);
          else this.values.delete(token);
        },
        contains(token: string) {
          return this.values.has(token);
        },
      };
      const attrs = new Map<string, string>();
      return {
        id,
        rootEl: {
          classList,
          setAttribute: (name: string, value: string) => attrs.set(name, value),
          removeAttribute: (name: string) => attrs.delete(name),
          getAttribute: (name: string) => attrs.get(name) ?? null,
        } as unknown as HTMLElement,
      };
    });

  it("marks only the matching zone as local", () => {
    const zones = createRoots();

    applyLocalZoneHighlight(zones, "Asia/Makassar");

    expect(zones[0]?.rootEl.classList.contains("zone--local")).toBe(false);
    expect(zones[1]?.rootEl.classList.contains("zone--local")).toBe(true);
    expect(zones[2]?.rootEl.classList.contains("zone--local")).toBe(false);
    expect(zones[1]?.rootEl.getAttribute("aria-current")).toBe("true");
    expect(zones[0]?.rootEl.getAttribute("aria-current")).toBeNull();
  });

  it("clears local marks when no Indonesian zone matches", () => {
    const zones = createRoots();
    applyLocalZoneHighlight(zones, "Asia/Jakarta");
    applyLocalZoneHighlight(zones, undefined);

    expect(zones.every((zone) => !zone.rootEl.classList.contains("zone--local"))).toBe(
      true,
    );
  });
});

describe("startIndonesiaClocks", () => {
  const createZoneElements = () =>
    ["Asia/Jakarta", "Asia/Makassar", "Asia/Jayapura"].map((id) => ({
      id,
      rootEl: {
        classList: { toggle: vi.fn() },
        setAttribute: vi.fn(),
        removeAttribute: vi.fn(),
      } as unknown as HTMLElement,
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

  it("highlights the zone that matches the user's time zone", () => {
    const zones = createZoneElements();
    const toggles = zones.map((zone) => zone.rootEl.classList.toggle as ReturnType<typeof vi.fn>);

    startIndonesiaClocks(zones, {
      now: () => new Date("2026-07-09T07:00:00.000Z"),
      setInterval: vi.fn(
        () => 1 as unknown as ReturnType<typeof globalThis.setInterval>,
      ),
      clearInterval: vi.fn(),
      timeZone: () => "Asia/Jayapura",
    });

    expect(toggles[0]).toHaveBeenCalledWith("zone--local", false);
    expect(toggles[1]).toHaveBeenCalledWith("zone--local", false);
    expect(toggles[2]).toHaveBeenCalledWith("zone--local", true);
  });
});
