const LOCALE = "id-ID";

export const INDONESIA_ZONES = [
  { id: "Asia/Jakarta", label: "WIB", name: "Waktu Indonesia Barat" },
  { id: "Asia/Makassar", label: "WITA", name: "Waktu Indonesia Tengah" },
  { id: "Asia/Jayapura", label: "WIT", name: "Waktu Indonesia Timur" },
] as const;

export const WORLD_ZONES = [
  { id: "Europe/London", label: "London", name: "Britania Raya" },
  { id: "America/New_York", label: "New York", name: "Amerika Serikat" },
  { id: "Asia/Tokyo", label: "Tokyo", name: "Jepang" },
  { id: "Asia/Dubai", label: "Dubai", name: "Uni Emirat Arab" },
  { id: "Asia/Singapore", label: "Singapura", name: "Singapura" },
  { id: "Australia/Sydney", label: "Sydney", name: "Australia" },
] as const;

export type TimeZoneId = (typeof INDONESIA_ZONES)[number]["id"];
type WorldTimeZoneId = (typeof WORLD_ZONES)[number]["id"];

/** IANA aliases that belong to the same Indonesian civil time as a canonical zone. */
const ZONE_ALIASES: Readonly<Record<string, TimeZoneId>> = {
  "Asia/Jakarta": "Asia/Jakarta",
  "Asia/Pontianak": "Asia/Jakarta",
  "Asia/Makassar": "Asia/Makassar",
  "Asia/Ujung_Pandang": "Asia/Makassar",
  "Asia/Jayapura": "Asia/Jayapura",
};

const offsetMinutesAt = (date: Date, timeZone: string): number => {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone,
    timeZoneName: "shortOffset",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).formatToParts(date);

  const raw = parts.find((part) => part.type === "timeZoneName")?.value ?? "GMT";
  const match = raw.match(/GMT([+-])(\d{1,2})(?::(\d{2}))?/);
  if (!match) return 0;

  const sign = match[1] === "-" ? -1 : 1;
  const hours = Number(match[2]);
  const minutes = Number(match[3] ?? "0");
  return sign * (hours * 60 + minutes);
};

/** Prefers known aliases, then falls back to matching the UTC offset. */
export const resolveIndonesiaZone = (
  timeZone: string,
  at: Date = new Date(),
): TimeZoneId | undefined => {
  const alias = ZONE_ALIASES[timeZone];
  if (alias) return alias;

  const localOffset = offsetMinutesAt(at, timeZone);
  return INDONESIA_ZONES.find((zone) => offsetMinutesAt(at, zone.id) === localOffset)?.id;
};

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

export const formatTime = (date: Date, timeZone?: string): string =>
  (timeZone ? createTimeFormatter(timeZone) : localTimeFormatter).format(date);

export const formatDate = (date: Date, timeZone?: string): string =>
  (timeZone ? createDateFormatter(timeZone) : localDateFormatter).format(date);

export type ClockSnapshot = {
  readonly time: string;
  readonly date: string;
  readonly dateTime: string;
};

export const getClockSnapshot = (date: Date, timeZone?: string): ClockSnapshot => ({
  time: formatTime(date, timeZone),
  date: formatDate(date, timeZone),
  dateTime: formatDateTimeAttr(date, timeZone),
});

export type ZoneClockSnapshot = ClockSnapshot & {
  readonly id: TimeZoneId | WorldTimeZoneId;
  readonly label: string;
  readonly name: string;
};

export const getIndonesiaClocksSnapshot = (date: Date): readonly ZoneClockSnapshot[] =>
  INDONESIA_ZONES.map((zone) => ({
    ...zone,
    ...getClockSnapshot(date, zone.id),
  }));

export const getWorldClocksSnapshot = (date: Date): readonly ZoneClockSnapshot[] =>
  WORLD_ZONES.map((zone) => ({
    ...zone,
    ...getClockSnapshot(date, zone.id),
  }));

export type ZoneClockElements = {
  readonly id: string;
  readonly rootEl: HTMLElement;
  readonly clockEl: HTMLTimeElement;
  readonly dateEl: HTMLElement;
};

export type ClockDeps = {
  readonly now?: () => Date;
  readonly setInterval?: typeof globalThis.setInterval;
  readonly clearInterval?: typeof globalThis.clearInterval;
  readonly timeZone?: () => string;
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

export const applyLocalZoneHighlight = (
  zones: readonly Pick<ZoneClockElements, "id" | "rootEl">[],
  localZone: TimeZoneId | undefined,
): void => {
  for (const zone of zones) {
    const isLocal = zone.id === localZone;
    zone.rootEl.classList.toggle("zone--local", isLocal);
    if (isLocal) {
      zone.rootEl.setAttribute("aria-current", "true");
    } else {
      zone.rootEl.removeAttribute("aria-current");
    }
  }
};

const readLocalTimeZone = (): string =>
  Intl.DateTimeFormat().resolvedOptions().timeZone;

const startZoneClocks = (
  zones: readonly ZoneClockElements[],
  getSnapshots: (date: Date) => readonly ZoneClockSnapshot[],
  deps: ClockDeps = {},
  onStart?: (zones: readonly ZoneClockElements[], now: Date, timeZone: string) => void,
): (() => void) => {
  const now = deps.now ?? (() => new Date());
  const schedule = deps.setInterval ?? globalThis.setInterval.bind(globalThis);
  const cancel = deps.clearInterval ?? globalThis.clearInterval.bind(globalThis);
  const timeZone = deps.timeZone ?? readLocalTimeZone;

  onStart?.(zones, now(), timeZone());

  const tick = () => {
    const snapshots = getSnapshots(now());
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

export const startIndonesiaClocks = (
  zones: readonly ZoneClockElements[],
  deps: ClockDeps = {},
): (() => void) =>
  startZoneClocks(zones, getIndonesiaClocksSnapshot, deps, (zoneEls, at, timeZone) => {
    applyLocalZoneHighlight(zoneEls, resolveIndonesiaZone(timeZone, at));
  });

export const startWorldClocks = (
  zones: readonly ZoneClockElements[],
  deps: ClockDeps = {},
): (() => void) => startZoneClocks(zones, getWorldClocksSnapshot, deps);
