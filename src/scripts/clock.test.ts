import { describe, expect, it, vi } from "vitest";
import {
  formatDate,
  formatDateTimeAttr,
  formatTime,
  getClockSnapshot,
  startClock,
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
});

describe("formatDate", () => {
  it("returns the id-ID weekday, day, month, and year", () => {
    const date = new Date(2026, 6, 9, 12, 0, 0);
    expect(formatDate(date)).toBe("Kamis, 9 Juli 2026");
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
});

describe("startClock", () => {
  const createElements = () => {
    const clockEl = { textContent: "", dateTime: "" } as HTMLTimeElement;
    const dateEl = { textContent: "" } as HTMLElement;
    return { clockEl, dateEl };
  };

  it("renders the current snapshot immediately", () => {
    const { clockEl, dateEl } = createElements();
    const now = () => new Date(2026, 6, 9, 14, 30, 45);
    const setInterval = vi.fn(
      () => 1 as unknown as ReturnType<typeof globalThis.setInterval>,
    );
    const clearInterval = vi.fn();

    const stop = startClock(clockEl, dateEl, { now, setInterval, clearInterval });

    expect(clockEl.textContent).toBe("14.30.45");
    expect(clockEl.dateTime).toBe("14:30:45");
    expect(dateEl.textContent).toBe("Kamis, 9 Juli 2026");
    expect(setInterval).toHaveBeenCalledWith(expect.any(Function), 1000);

    stop();
    expect(clearInterval).toHaveBeenCalledWith(1);
  });

  it("updates the DOM on each scheduled tick", () => {
    const { clockEl, dateEl } = createElements();
    let instant = new Date(2026, 6, 9, 10, 0, 0);
    let tick: (() => void) | undefined;

    const stop = startClock(clockEl, dateEl, {
      now: () => instant,
      setInterval: (fn) => {
        tick = fn as () => void;
        return 7 as unknown as ReturnType<typeof globalThis.setInterval>;
      },
      clearInterval: vi.fn(),
    });

    expect(clockEl.dateTime).toBe("10:00:00");

    instant = new Date(2026, 6, 9, 10, 0, 1);
    tick?.();

    expect(clockEl.textContent).toBe(formatTime(instant));
    expect(clockEl.dateTime).toBe("10:00:01");
    expect(dateEl.textContent).toBe(formatDate(instant));

    stop();
  });
});
