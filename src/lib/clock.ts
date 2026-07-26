const dateFmt = new Intl.DateTimeFormat("id-ID", {
  weekday: "long",
  day: "numeric",
  month: "long",
  year: "numeric",
});

const zoneName =
  Intl.DateTimeFormat().resolvedOptions().timeZone?.replace(/_/g, " ") ||
  "Lokal";

export function pad(n: number): string {
  return String(n).padStart(2, "0");
}

export type ClockSnapshot = {
  hours: string;
  minutes: string;
  seconds: string;
  datetime: string;
  date: string;
  zone: string;
};

export function getClockSnapshot(now: Date = new Date()): ClockSnapshot {
  const hours = pad(now.getHours());
  const minutes = pad(now.getMinutes());
  const seconds = pad(now.getSeconds());

  const offsetMin = -now.getTimezoneOffset();
  const sign = offsetMin >= 0 ? "+" : "-";
  const abs = Math.abs(offsetMin);
  const tzHours = pad(Math.floor(abs / 60));
  const tzMins = pad(abs % 60);

  return {
    hours,
    minutes,
    seconds,
    datetime: `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}T${hours}:${minutes}:${seconds}`,
    date: dateFmt.format(now),
    zone: `${zoneName} · UTC${sign}${tzHours}:${tzMins}`,
  };
}

export const INDONESIAN_ZONES = [
  {
    id: "WIB",
    name: "Waktu Indonesia Barat",
    timeZone: "Asia/Jakarta",
    offset: "UTC+07:00",
  },
  {
    id: "WITA",
    name: "Waktu Indonesia Tengah",
    timeZone: "Asia/Makassar",
    offset: "UTC+08:00",
  },
  {
    id: "WIT",
    name: "Waktu Indonesia Timur",
    timeZone: "Asia/Jayapura",
    offset: "UTC+09:00",
  },
] as const;

export type IndonesianClockSnapshot = {
  id: (typeof INDONESIAN_ZONES)[number]["id"];
  name: string;
  hours: string;
  minutes: string;
  seconds: string;
  datetime: string;
  date: string;
  offset: string;
};

function partsInZone(now: Date, timeZone: string) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hourCycle: "h23",
  }).formatToParts(now);

  const get = (type: Intl.DateTimeFormatPartTypes) =>
    parts.find((p) => p.type === type)?.value ?? "00";

  return {
    year: get("year"),
    month: get("month"),
    day: get("day"),
    hours: get("hour"),
    minutes: get("minute"),
    seconds: get("second"),
  };
}

function formatDateInZone(now: Date, timeZone: string): string {
  return new Intl.DateTimeFormat("id-ID", {
    timeZone,
    weekday: "long",
    day: "numeric",
    month: "long",
    year: "numeric",
  }).format(now);
}

export function getIndonesianClocks(
  now: Date = new Date(),
): IndonesianClockSnapshot[] {
  return INDONESIAN_ZONES.map((zone) => {
    const p = partsInZone(now, zone.timeZone);
    return {
      id: zone.id,
      name: zone.name,
      hours: p.hours,
      minutes: p.minutes,
      seconds: p.seconds,
      datetime: `${p.year}-${p.month}-${p.day}T${p.hours}:${p.minutes}:${p.seconds}`,
      date: formatDateInZone(now, zone.timeZone),
      offset: zone.offset,
    };
  });
}
