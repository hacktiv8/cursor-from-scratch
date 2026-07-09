const clockEl = document.getElementById("clock");
const dateEl = document.getElementById("date");

const timeFormatter = new Intl.DateTimeFormat("id-ID", {
  hour: "2-digit",
  minute: "2-digit",
  second: "2-digit",
  hour12: false,
});

const dateFormatter = new Intl.DateTimeFormat("id-ID", {
  weekday: "long",
  day: "numeric",
  month: "long",
  year: "numeric",
});

function padIsoTime(date) {
  const h = String(date.getHours()).padStart(2, "0");
  const m = String(date.getMinutes()).padStart(2, "0");
  const s = String(date.getSeconds()).padStart(2, "0");
  return `${h}:${m}:${s}`;
}

function tick() {
  const now = new Date();
  clockEl.textContent = timeFormatter.format(now);
  clockEl.setAttribute("datetime", padIsoTime(now));
  dateEl.textContent = dateFormatter.format(now);
}

tick();
setInterval(tick, 1000);
