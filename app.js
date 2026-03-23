const tapZone = document.getElementById("tapZone");
const resetButton = document.getElementById("resetButton");
const bpmValue = document.getElementById("bpmValue");
const hint = document.getElementById("hint");
const canvas = document.getElementById("rippleCanvas");
const ctx = canvas.getContext("2d");

const MAX_TAPS = 10;
const INACTIVITY_RESET_MS = 2000;

let taps = [];
let lastTapTime = 0;

const ripples = [];

function playResetFeedback() {
  resetButton.classList.remove("feedback");
  void resetButton.offsetWidth;
  resetButton.classList.add("feedback");
}

function resizeCanvas() {
  const dpr = window.devicePixelRatio || 1;
  const width = window.innerWidth;
  const height = window.innerHeight;
  canvas.width = Math.round(width * dpr);
  canvas.height = Math.round(height * dpr);
  canvas.style.width = `${width}px`;
  canvas.style.height = `${height}px`;
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
}

function resetBpm() {
  taps = [];
  lastTapTime = 0;
  bpmValue.textContent = "--.-";
  hint.textContent = "";
}

function pushTap(timestampMs) {
  if (lastTapTime && timestampMs - lastTapTime > INACTIVITY_RESET_MS) {
    taps = [];
  }

  taps.push(timestampMs);
  lastTapTime = timestampMs;

  if (taps.length > MAX_TAPS) {
    taps.shift();
  }

  if (taps.length < 2) {
    hint.textContent = "";
    return;
  }

  let totalInterval = 0;
  for (let i = 1; i < taps.length; i += 1) {
    totalInterval += taps[i] - taps[i - 1];
  }

  const meanInterval = totalInterval / (taps.length - 1);
  const bpm = 60000 / meanInterval;
  bpmValue.textContent = bpm.toFixed(1);
}

function addRipple(x, y) {
  const now = performance.now();
  ripples.push({
    x,
    y,
    createdAt: now,
    lifeMs: 1200
  });
}

function drawWaterSurface() {
  const width = canvas.clientWidth;
  const height = canvas.clientHeight;
  const now = performance.now();

  ctx.clearRect(0, 0, width, height);

  for (let i = ripples.length - 1; i >= 0; i -= 1) {
    const ripple = ripples[i];
    const age = now - ripple.createdAt;
    const t = age / ripple.lifeMs;

    if (t >= 1) {
      ripples.splice(i, 1);
      continue;
    }

    const eased = 1 - Math.pow(1 - t, 2);
    const radius = 15 + eased * 220;
    const alpha = (1 - t) * 0.65;
    const strokeWidth = 4 - eased * 3.2;

    ctx.beginPath();
    ctx.strokeStyle = `rgba(210, 247, 255, ${alpha})`;
    ctx.lineWidth = Math.max(0.8, strokeWidth);
    ctx.arc(ripple.x, ripple.y, radius, 0, Math.PI * 2);
    ctx.stroke();

    const dropAlpha = (1 - t) * (1 - t) * 0.8;
    ctx.beginPath();
    ctx.fillStyle = `rgba(235, 255, 255, ${dropAlpha})`;
    ctx.arc(ripple.x, ripple.y, Math.max(0, 4 - t * 5), 0, Math.PI * 2);
    ctx.fill();
  }

  requestAnimationFrame(drawWaterSurface);
}

function onTap(event) {
  if (event.target === resetButton) {
    return;
  }

  if (event.pointerType === "mouse" && event.button !== 0) {
    return;
  }

  const timestampMs = performance.now();
  pushTap(timestampMs);
  addRipple(event.clientX, event.clientY);
}

tapZone.addEventListener("pointerdown", onTap, { passive: true });

resetButton.addEventListener("pointerdown", (event) => {
  event.stopPropagation();
  playResetFeedback();
});

resetButton.addEventListener("click", (event) => {
  event.stopPropagation();
  resetBpm();
});

resetButton.addEventListener("animationend", () => {
  resetButton.classList.remove("feedback");
});

window.addEventListener("resize", resizeCanvas);

resizeCanvas();
resetBpm();
drawWaterSurface();
