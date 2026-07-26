const clockEl = document.getElementById("clock");
const dateEl = document.getElementById("date");
const zoneEl = document.getElementById("zone");
const secondsEl = clockEl.querySelector('[data-part="seconds"]');
const hoursEl = clockEl.querySelector('[data-part="hours"]');
const minutesEl = clockEl.querySelector('[data-part="minutes"]');

const dateFmt = new Intl.DateTimeFormat("id-ID", {
  weekday: "long",
  day: "numeric",
  month: "long",
  year: "numeric",
});

function pad(n) {
  return String(n).padStart(2, "0");
}

function update() {
  const now = new Date();
  const hours = pad(now.getHours());
  const minutes = pad(now.getMinutes());
  const seconds = pad(now.getSeconds());

  const prevSeconds = secondsEl.textContent;
  hoursEl.textContent = hours;
  minutesEl.textContent = minutes;
  secondsEl.textContent = seconds;

  if (prevSeconds !== seconds) {
    secondsEl.classList.remove("tick");
    // Restart animation when the second changes
    void secondsEl.offsetWidth;
    secondsEl.classList.add("tick");
  }

  clockEl.setAttribute(
    "datetime",
    `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}T${hours}:${minutes}:${seconds}`
  );

  dateEl.textContent = dateFmt.format(now);

  const offsetMin = -now.getTimezoneOffset();
  const sign = offsetMin >= 0 ? "+" : "-";
  const abs = Math.abs(offsetMin);
  const tzHours = pad(Math.floor(abs / 60));
  const tzMins = pad(abs % 60);
  const zoneName =
    Intl.DateTimeFormat().resolvedOptions().timeZone?.replace(/_/g, " ") || "Lokal";
  zoneEl.textContent = `${zoneName} · UTC${sign}${tzHours}:${tzMins}`;
}

update();
setInterval(update, 250);
