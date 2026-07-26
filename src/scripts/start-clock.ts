import { getIndonesianClocks } from "../lib/clock";

type ZoneElements = {
  root: HTMLElement;
  clock: HTMLTimeElement;
  hours: HTMLElement;
  minutes: HTMLElement;
  seconds: HTMLElement;
  date: HTMLElement;
};

function requireEl<T extends Element>(root: ParentNode, selector: string): T {
  const el = root.querySelector<T>(selector);
  if (!el) {
    throw new Error(`Missing element: ${selector}`);
  }
  return el;
}

function bindZone(root: HTMLElement): ZoneElements {
  const clock = requireEl<HTMLTimeElement>(root, "time.clock");
  return {
    root,
    clock,
    hours: requireEl(clock, '[data-part="hours"]'),
    minutes: requireEl(clock, '[data-part="minutes"]'),
    seconds: requireEl(clock, '[data-part="seconds"]'),
    date: requireEl(root, '[data-part="date"]'),
  };
}

export function bindClock(root: ParentNode = document): () => void {
  const section = requireEl<HTMLElement>(root, "#indo-clocks");
  const zones = new Map(
    Array.from(section.querySelectorAll<HTMLElement>(".zone-clock")).map(
      (el) => [el.dataset.zone ?? "", bindZone(el)] as const,
    ),
  );

  if (zones.size !== 3) {
    throw new Error("Expected three Indonesian zone clocks");
  }

  let prevSeconds: string | null = null;

  const tick = () => {
    const snaps = getIndonesianClocks();
    const marker = snaps.map((s) => s.seconds).join(":");
    if (prevSeconds === marker) return;
    prevSeconds = marker;

    for (const snap of snaps) {
      const els = zones.get(snap.id);
      if (!els) {
        throw new Error(`Missing zone clock for ${snap.id}`);
      }
      els.hours.textContent = snap.hours;
      els.minutes.textContent = snap.minutes;
      els.seconds.textContent = snap.seconds;
      els.clock.setAttribute("datetime", snap.datetime);
      els.date.textContent = snap.date;

      els.seconds.classList.remove("tick");
      void els.seconds.offsetWidth;
      els.seconds.classList.add("tick");
    }
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
