const LOCALE = "id-ID";

const timeFormatter = new Intl.DateTimeFormat(LOCALE, {
  hour: "2-digit",
  minute: "2-digit",
  second: "2-digit",
  hour12: false,
});

const dateFormatter = new Intl.DateTimeFormat(LOCALE, {
  weekday: "long",
  day: "numeric",
  month: "long",
  year: "numeric",
});

/** Machine-readable `HH:MM:SS` for the `<time datetime>` attribute. */
export function formatDateTimeAttr(date: Date): string {
  const h = String(date.getHours()).padStart(2, "0");
  const m = String(date.getMinutes()).padStart(2, "0");
  const s = String(date.getSeconds()).padStart(2, "0");
  return `${h}:${m}:${s}`;
}

/** Display time string for the current locale (24-hour). */
export function formatTime(date: Date): string {
  return timeFormatter.format(date);
}

/** Display date string for the current locale. */
export function formatDate(date: Date): string {
  return dateFormatter.format(date);
}

export type ClockSnapshot = {
  time: string;
  date: string;
  dateTime: string;
};

/** Pure snapshot of clock display values for a given instant. */
export function getClockSnapshot(date: Date): ClockSnapshot {
  return {
    time: formatTime(date),
    date: formatDate(date),
    dateTime: formatDateTimeAttr(date),
  };
}

export function startClock(clockEl: HTMLTimeElement, dateEl: HTMLElement): void {
  const tick = () => {
    const snapshot = getClockSnapshot(new Date());
    clockEl.textContent = snapshot.time;
    clockEl.dateTime = snapshot.dateTime;
    dateEl.textContent = snapshot.date;
  };

  tick();
  window.setInterval(tick, 1000);
}
