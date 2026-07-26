import { getIndonesianClocks, getWorldClocks } from "../lib/clock";

type ClockSnapshot = {
  id: string;
  hours: string;
  minutes: string;
  seconds: string;
  datetime: string;
  date: string;
  offset?: string;
};

type ZoneElements = {
  root: HTMLElement;
  clock: HTMLTimeElement;
  hours: HTMLElement;
  minutes: HTMLElement;
  seconds: HTMLElement;
  date: HTMLElement;
  offset: HTMLElement | null;
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
    offset: root.querySelector('[data-part="offset"]'),
  };
}

function applySnapshot(els: ZoneElements, snap: ClockSnapshot): void {
  els.hours.textContent = snap.hours;
  els.minutes.textContent = snap.minutes;
  els.seconds.textContent = snap.seconds;
  els.clock.setAttribute("datetime", snap.datetime);
  els.date.textContent = snap.date;
  if (els.offset && snap.offset) {
    els.offset.textContent = snap.offset;
  }

  els.seconds.classList.remove("tick");
  void els.seconds.offsetWidth;
  els.seconds.classList.add("tick");
}

function bindSection(
  root: ParentNode,
  sectionSelector: string,
  expectedCount: number,
  getSnapshots: () => ClockSnapshot[],
): () => void {
  const section = requireEl<HTMLElement>(root, sectionSelector);
  const zones = new Map(
    Array.from(section.querySelectorAll<HTMLElement>(".zone-clock")).map(
      (el) => [el.dataset.zone ?? "", bindZone(el)] as const,
    ),
  );

  if (zones.size !== expectedCount) {
    throw new Error(
      `Expected ${expectedCount} zone clocks in ${sectionSelector}`,
    );
  }

  let prevSeconds: string | null = null;

  const tick = () => {
    const snaps = getSnapshots();
    const marker = snaps.map((s) => s.seconds).join(":");
    if (prevSeconds === marker) return;
    prevSeconds = marker;

    for (const snap of snaps) {
      const els = zones.get(snap.id);
      if (!els) {
        throw new Error(`Missing zone clock for ${snap.id}`);
      }
      applySnapshot(els, snap);
    }
  };

  tick();
  const id = window.setInterval(tick, 250);
  return () => window.clearInterval(id);
}

export function bindClock(root: ParentNode = document): () => void {
  const stopIndo = bindSection(root, "#indo-clocks", 3, getIndonesianClocks);
  const stopWorld = bindSection(root, "#world-clocks", 4, getWorldClocks);
  return () => {
    stopIndo();
    stopWorld();
  };
}

let dispose = bindClock();

if (import.meta.hot) {
  import.meta.hot.dispose(() => dispose());
  import.meta.hot.accept();
}
