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

const pad2 = (n: number): string => String(n).padStart(2, "0");

/** Machine-readable `HH:MM:SS` for the `<time datetime>` attribute. */
export const formatDateTimeAttr = (date: Date): string =>
  [date.getHours(), date.getMinutes(), date.getSeconds()].map(pad2).join(":");

/** Display time string for the current locale (24-hour). */
export const formatTime = (date: Date): string => timeFormatter.format(date);

/** Display date string for the current locale. */
export const formatDate = (date: Date): string => dateFormatter.format(date);

export type ClockSnapshot = {
  readonly time: string;
  readonly date: string;
  readonly dateTime: string;
};

/** Pure snapshot of clock display values for a given instant. */
export const getClockSnapshot = (date: Date): ClockSnapshot => ({
  time: formatTime(date),
  date: formatDate(date),
  dateTime: formatDateTimeAttr(date),
});

export type ClockDeps = {
  readonly now?: () => Date;
  readonly setInterval?: typeof globalThis.setInterval;
  readonly clearInterval?: typeof globalThis.clearInterval;
};

const applySnapshot =
  (clockEl: HTMLTimeElement, dateEl: HTMLElement) =>
  (snapshot: ClockSnapshot): void => {
    clockEl.textContent = snapshot.time;
    clockEl.dateTime = snapshot.dateTime;
    dateEl.textContent = snapshot.date;
  };

export const startClock = (
  clockEl: HTMLTimeElement,
  dateEl: HTMLElement,
  deps: ClockDeps = {},
): (() => void) => {
  const now = deps.now ?? (() => new Date());
  const schedule = deps.setInterval ?? globalThis.setInterval.bind(globalThis);
  const cancel = deps.clearInterval ?? globalThis.clearInterval.bind(globalThis);
  const render = applySnapshot(clockEl, dateEl);
  const tick = () => render(getClockSnapshot(now()));

  tick();
  const id = schedule(tick, 1000);
  return () => cancel(id);
};
