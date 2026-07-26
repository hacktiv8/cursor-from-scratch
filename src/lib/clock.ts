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
