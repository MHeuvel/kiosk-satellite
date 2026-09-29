/* The adaptive brightness curve (issues #343 and #742), the device's
   AdaptiveCurve (lib/managers/screen/adaptive_brightness.dart) line for
   line: four points, a monotone cubic through them on the log of the light
   level, flat before the first and after the last. Pure, so the tests can
   load it without a page. */

const LUX_FLOOR = 0.01;

export const CURVE_KEYS = {
  min: 'screen.adaptive_min_brightness',
  max: 'screen.adaptive_max_brightness',
  dark: 'screen.adaptive_dark_lux',
  bright: 'screen.adaptive_bright_lux',
  p2Position: 'screen.adaptive_point2_position',
  p2Level: 'screen.adaptive_point2_level',
  p3Position: 'screen.adaptive_point3_position',
  p3Level: 'screen.adaptive_point3_level',
};

const clamp = (v, lo, hi) => Math.min(Math.max(v, lo), hi);

/* Crossed light levels and falling brightness are flattened, so the curve
   stays a monotone function whatever the settings say mid-edit. */
export function sanePoints(raw) {
  const out = [];
  for (const p of raw) {
    let lux = Math.max(p.lux, LUX_FLOOR);
    let level = clamp(p.level, 0, 1);
    if (out.length) {
      lux = Math.max(lux, out[out.length - 1].lux);
      level = Math.max(level, out[out.length - 1].level);
    }
    out.push({ lux, level });
  }
  return out;
}

/* The four points from the settings: the ends as they are, the middle two
   from their shares of the span between the ends. */
export function curvePoints(v) {
  const dark = Math.max(v.dark, LUX_FLOOR);
  const bright = Math.max(v.bright, LUX_FLOOR);
  const lux = (position) => Math.exp(Math.log(dark)
    + clamp(position, 0, 1) * (Math.log(bright) - Math.log(dark)));
  const level = (share) => v.min + clamp(share, 0, 1) * (v.max - v.min);
  return sanePoints([
    { lux: dark, level: v.min },
    { lux: lux(v.p2Position), level: level(v.p2Level) },
    { lux: lux(v.p3Position), level: level(v.p3Level) },
    { lux: bright, level: v.max },
  ]);
}

export function positionFor(lux, darkLux, brightLux) {
  const dark = Math.log(Math.max(darkLux, LUX_FLOOR));
  const bright = Math.log(Math.max(brightLux, LUX_FLOOR));
  if (bright <= dark) return 0;
  return clamp((Math.log(Math.max(lux, LUX_FLOOR)) - dark) / (bright - dark), 0, 1);
}

export function shareFor(level, minLevel, maxLevel) {
  if (maxLevel <= minLevel) return 0;
  return clamp((level - minLevel) / (maxLevel - minLevel), 0, 1);
}

/* Fritsch-Butland tangents: the weighted harmonic mean of the neighboring
   slopes, zero at a flat step, one-sided at the ends. */
function tangents(xs, ys) {
  const n = xs.length;
  const h = [];
  const d = [];
  for (let i = 0; i < n - 1; i++) {
    h.push(xs[i + 1] - xs[i]);
    d.push(h[i] <= 0 ? 0 : (ys[i + 1] - ys[i]) / h[i]);
  }
  const m = new Array(n).fill(0);
  m[0] = d[0];
  m[n - 1] = d[n - 2];
  for (let i = 1; i < n - 1; i++) {
    if (d[i - 1] <= 0 || d[i] <= 0) continue;
    const w1 = 2 * h[i] + h[i - 1];
    const w2 = h[i] + 2 * h[i - 1];
    m[i] = (w1 + w2) / (w1 / d[i - 1] + w2 / d[i]);
  }
  return m;
}

export function levelAt(points, lux) {
  const first = points[0];
  const last = points[points.length - 1];
  if (lux >= last.lux) return last.level;
  if (lux <= first.lux) return first.level;
  const xs = points.map((p) => Math.log(p.lux));
  const ys = points.map((p) => p.level);
  const x = Math.log(lux);
  let k = 0;
  while (k < points.length - 2 && x >= xs[k + 1]) k++;
  const h = xs[k + 1] - xs[k];
  if (h <= 0) return ys[k + 1];
  const m = tangents(xs, ys);
  const t = (x - xs[k]) / h;
  const t2 = t * t;
  const t3 = t2 * t;
  const y = (2 * t3 - 3 * t2 + 1) * ys[k] + (t3 - 2 * t2 + t) * h * m[k]
    + (-2 * t3 + 3 * t2) * ys[k + 1] + (t3 - t2) * h * m[k + 1];
  return clamp(y, ys[k], ys[k + 1]);
}

/* The settings a curve writes, rounded the way the device rounds them. */
export function curveSettings(p) {
  const level = (v) => Math.round(v * 100) / 100;
  const lux = (v) => Math.round(v * 10) / 10;
  const share = (v) => Number(v.toFixed(6));
  const min = level(p[0].level);
  const max = level(p[3].level);
  const dark = lux(p[0].lux);
  const bright = lux(p[3].lux);
  return {
    [CURVE_KEYS.min]: min,
    [CURVE_KEYS.max]: max,
    [CURVE_KEYS.dark]: dark,
    [CURVE_KEYS.bright]: bright,
    [CURVE_KEYS.p2Position]: share(positionFor(p[1].lux, dark, bright)),
    [CURVE_KEYS.p2Level]: share(shareFor(p[1].level, min, max)),
    [CURVE_KEYS.p3Position]: share(positionFor(p[2].lux, dark, bright)),
    [CURVE_KEYS.p3Level]: share(shareFor(p[2].level, min, max)),
  };
}

/* A light level for a label: one decimal at most, none when whole. */
export function formatCurveLux(lux) {
  const r = Math.round(lux * 10) / 10;
  return Number.isInteger(r) ? String(r) : r.toFixed(1);
}

/* A dragged light level lands on two significant figures. */
export function snapLux(lux) {
  if (lux <= 0) return 0.1;
  const magnitude = 10 ** (Math.floor(Math.log10(lux)) - 1);
  const snapped = Math.round(lux / magnitude) * magnitude;
  return Math.max(0.1, Math.round(snapped * 10) / 10);
}

export const snapLevel = (level) => Math.round(level * 100) / 100;

/* Where point i may go: between its neighbors in light (a drag keeps a
   little room, a typed value only has to differ), between their
   brightness, and the ends keep Minimum under Maximum. */
export function pointBounds(p, i, domain, gap = 1.12) {
  const last = p.length - 1;
  let levelLo = i === 0 ? 0 : p[i - 1].level;
  let levelHi = i === last ? 1 : p[i + 1].level;
  if (i === 0) levelHi = Math.min(levelHi, p[last].level - 0.01);
  if (i === last) levelLo = Math.max(levelLo, p[0].level + 0.01);
  return {
    luxLo: i === 0 ? (domain ? domain.lo : 0) : p[i - 1].lux * gap,
    luxHi: i === last ? (domain ? domain.hi : 200000) : p[i + 1].lux / gap,
    levelLo,
    levelHi,
  };
}

export function clampPoint(p, i, want, domain) {
  const b = pointBounds(p, i, domain);
  return {
    lux: b.luxLo <= b.luxHi ? clamp(want.lux, b.luxLo, b.luxHi) : p[i].lux,
    level: b.levelLo <= b.levelHi ? clamp(want.level, b.levelLo, b.levelHi) : p[i].level,
  };
}

/* The chart's light range: whole decades around the ends, from 1 lx or
   lower, with room past the ends to drag. The live reading has no say: a
   dark room's sensor flapping between 0 and 1 lx would redraw the axis on
   every sample. A reading outside the range sits on the chart's edge. */
export function curveDomain(p) {
  let lo = Math.min(1, p[0].lux / 2);
  const hi = Math.max(10, p[p.length - 1].lux * 2);
  lo = Math.max(lo, LUX_FLOOR);
  return {
    lo: 10 ** Math.floor(Math.log10(lo) + 1e-9),
    hi: 10 ** Math.ceil(Math.log10(hi) - 1e-9),
  };
}
