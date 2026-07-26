import { getClockSnapshot } from "../lib/clock";

type ClockElements = {
  clock: HTMLTimeElement;
  hours: HTMLElement;
  minutes: HTMLElement;
  seconds: HTMLElement;
  date: HTMLElement;
  zone: HTMLElement;
};

function requireEl<T extends Element>(root: ParentNode, selector: string): T {
  const el = root.querySelector<T>(selector);
  if (!el) {
    throw new Error(`Missing element: ${selector}`);
  }
  return el;
}

export function bindClock(root: ParentNode = document): () => void {
  const clock = requireEl<HTMLTimeElement>(root, "#clock");
  const els: ClockElements = {
    clock,
    hours: requireEl(clock, '[data-part="hours"]'),
    minutes: requireEl(clock, '[data-part="minutes"]'),
    seconds: requireEl(clock, '[data-part="seconds"]'),
    date: requireEl(root, "#date"),
    zone: requireEl(root, "#zone"),
  };

  let prevSeconds: string | null = null;

  const tick = () => {
    const snap = getClockSnapshot();
    if (prevSeconds === snap.seconds) return;

    prevSeconds = snap.seconds;
    els.hours.textContent = snap.hours;
    els.minutes.textContent = snap.minutes;
    els.seconds.textContent = snap.seconds;
    els.clock.setAttribute("datetime", snap.datetime);
    els.date.textContent = snap.date;
    els.zone.textContent = snap.zone;

    els.seconds.classList.remove("tick");
    void els.seconds.offsetWidth;
    els.seconds.classList.add("tick");
  };

  tick();
  const id = window.setInterval(tick, 250);
  return () => window.clearInterval(id);
}

let dispose = bindClock();

if (import.meta.hot) {
  import.meta.hot.dispose(() => dispose());
  import.meta.hot.accept();
}
