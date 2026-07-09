const LOCALE = "id-ID";

export type TimeZoneId = "Asia/Jakarta" | "Asia/Makassar" | "Asia/Jayapura";

export const INDONESIA_ZONES = [
  { id: "Asia/Jakarta" as const, label: "WIB", name: "Waktu Indonesia Barat" },
  { id: "Asia/Makassar" as const, label: "WITA", name: "Waktu Indonesia Tengah" },
  { id: "Asia/Jayapura" as const, label: "WIT", name: "Waktu Indonesia Timur" },
] as const;

const createTimeFormatter = (timeZone?: string) =>
  new Intl.DateTimeFormat(LOCALE, {
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
    ...(timeZone ? { timeZone } : {}),
  });

const createDateFormatter = (timeZone?: string) =>
  new Intl.DateTimeFormat(LOCALE, {
    weekday: "long",
    day: "numeric",
    month: "long",
    year: "numeric",
    ...(timeZone ? { timeZone } : {}),
  });

const localTimeFormatter = createTimeFormatter();
const localDateFormatter = createDateFormatter();

const pad2 = (n: number): string => String(n).padStart(2, "0");

/** Machine-readable `HH:MM:SS` for the `<time datetime>` attribute. */
export const formatDateTimeAttr = (date: Date, timeZone?: string): string => {
  if (!timeZone) {
    return [date.getHours(), date.getMinutes(), date.getSeconds()].map(pad2).join(":");
  }

  const parts = createTimeFormatter(timeZone).formatToParts(date);
  const get = (type: Intl.DateTimeFormatPartTypes) =>
    parts.find((part) => part.type === type)?.value ?? "00";

  return `${get("hour")}:${get("minute")}:${get("second")}`;
};

/** Display time string for the current locale (24-hour). */
export const formatTime = (date: Date, timeZone?: string): string =>
  (timeZone ? createTimeFormatter(timeZone) : localTimeFormatter).format(date);

/** Display date string for the current locale. */
export const formatDate = (date: Date, timeZone?: string): string =>
  (timeZone ? createDateFormatter(timeZone) : localDateFormatter).format(date);

export type ClockSnapshot = {
  readonly time: string;
  readonly date: string;
  readonly dateTime: string;
};

/** Pure snapshot of clock display values for a given instant. */
export const getClockSnapshot = (date: Date, timeZone?: string): ClockSnapshot => ({
  time: formatTime(date, timeZone),
  date: formatDate(date, timeZone),
  dateTime: formatDateTimeAttr(date, timeZone),
});

export type ZoneClockSnapshot = ClockSnapshot & {
  readonly id: TimeZoneId;
  readonly label: string;
  readonly name: string;
};

/** Snapshots for WIB, WITA, and WIT at the same instant. */
export const getIndonesiaClocksSnapshot = (date: Date): readonly ZoneClockSnapshot[] =>
  INDONESIA_ZONES.map((zone) => ({
    ...zone,
    ...getClockSnapshot(date, zone.id),
  }));

export type ZoneClockElements = {
  readonly id: TimeZoneId | string;
  readonly clockEl: HTMLTimeElement;
  readonly dateEl: HTMLElement;
};

export type ClockDeps = {
  readonly now?: () => Date;
  readonly setInterval?: typeof globalThis.setInterval;
  readonly clearInterval?: typeof globalThis.clearInterval;
};

const applySnapshot = (
  clockEl: HTMLTimeElement,
  dateEl: HTMLElement,
  snapshot: ClockSnapshot,
): void => {
  clockEl.textContent = snapshot.time;
  clockEl.dateTime = snapshot.dateTime;
  dateEl.textContent = snapshot.date;
};

/** Tick WIB, WITA, and WIT clocks together for side-by-side comparison. */
export const startIndonesiaClocks = (
  zones: readonly ZoneClockElements[],
  deps: ClockDeps = {},
): (() => void) => {
  const now = deps.now ?? (() => new Date());
  const schedule = deps.setInterval ?? globalThis.setInterval.bind(globalThis);
  const cancel = deps.clearInterval ?? globalThis.clearInterval.bind(globalThis);

  const tick = () => {
    const snapshots = getIndonesiaClocksSnapshot(now());
    for (const zone of zones) {
      const snapshot = snapshots.find((entry) => entry.id === zone.id);
      if (snapshot) {
        applySnapshot(zone.clockEl, zone.dateEl, snapshot);
      }
    }
  };

  tick();
  const id = schedule(tick, 1000);
  return () => cancel(id);
};
