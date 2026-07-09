const clockEl = document.getElementById("clock");
const dateEl = document.getElementById("date");
const hoursEl = clockEl.querySelector('[data-part="hours"]');
const minutesEl = clockEl.querySelector('[data-part="minutes"]');
const secondsEl = clockEl.querySelector('[data-part="seconds"]');

const dateFormatter = new Intl.DateTimeFormat("id-ID", {
  weekday: "long",
  day: "numeric",
  month: "long",
  year: "numeric",
});

function pad(value) {
  return String(value).padStart(2, "0");
}

function render(now = new Date()) {
  const hours = pad(now.getHours());
  const minutes = pad(now.getMinutes());
  const seconds = pad(now.getSeconds());

  hoursEl.textContent = hours;
  minutesEl.textContent = minutes;
  secondsEl.textContent = seconds;
  clockEl.setAttribute(
    "datetime",
    `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}T${hours}:${minutes}:${seconds}`
  );
  dateEl.textContent = dateFormatter.format(now);
}

function tick() {
  render();
  const delay = 1000 - (Date.now() % 1000);
  window.setTimeout(tick, delay);
}

render();
tick();
