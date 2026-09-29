/* The adaptive brightness curve editor (issue #742), mirroring the device's
   BrightnessCurveEditor: a chart of screen brightness over the room's light
   on a log scale, four points to drag, the live reading marked on it, and a
   chip per point that opens a dialog for exact values. It stands in for
   the curve's settings rows: the row it lives in is Minimum brightness's,
   and the chips carry the other keys, so a live change to any of them
   repaints the chart instead of rebuilding the page, and a search for any
   of them lands here. */
import { api, state } from './core.js';
import { cameraEditor, cameraField } from './cameras.js';
import { screenAudioText, t } from './localization.js';
import { hintRow } from './widgets.js';
import {
  CURVE_KEYS,
  clampPoint,
  curveDomain,
  curvePoints,
  curveSettings,
  formatCurveLux,
  levelAt,
  pointBounds,
  snapLevel,
  snapLux,
} from './adaptive_curve.js';

const CURVE_HINT = 'Drag a point, or tap it to type exact values. The Screen '
  + 'light in Home Assistant moves the top point and the curve follows.';

const SVG = 'http://www.w3.org/2000/svg';
const PAD = { left: 40, right: 10, top: 14, bottom: 26 };
const REACH = 30;

/* The editors on the page, for the live light reading. */
const editors = new Set();
document.addEventListener('ks-lightlevel', () => {
  for (const editor of editors) {
    if (editor.row.isConnected) editor.moveLux();
    else editors.delete(editor);
  }
});

let gradients = 0;

function settingValues() {
  const byKey = Object.fromEntries((state.settings || []).map((s) => [s.key, s]));
  const num = (key, fallback) => {
    const v = Number(byKey[key]?.value);
    return Number.isFinite(v) ? v : fallback;
  };
  return {
    min: num(CURVE_KEYS.min, 0.15),
    max: num(CURVE_KEYS.max, 0.8),
    dark: num(CURVE_KEYS.dark, 5),
    bright: num(CURVE_KEYS.bright, 300),
    p2Position: num(CURVE_KEYS.p2Position, 1 / 3),
    p2Level: num(CURVE_KEYS.p2Level, 1 / 3),
    p3Position: num(CURVE_KEYS.p3Position, 2 / 3),
    p3Level: num(CURVE_KEYS.p3Level, 2 / 3),
  };
}

const ease = (t) => 1 - (1 - t) ** 3;
const luxText = (lux) => t('screenAudioLux', { lux: formatCurveLux(lux) });
const decadeLabel = (e) => e < 0 ? (10 ** e).toFixed(-e)
  : e < 3 ? String(10 ** e) : e < 6 ? `${10 ** (e - 3)}k` : `${10 ** (e - 6)}M`;

/* Builds the editor into `row` (Minimum brightness's settings row).
   `showError` and `clearError` are the row's own error line. */
export function brightnessCurveRow(row, { showError, clearError }) {
  row.classList.add('curve-row');
  row.textContent = '';
  const chart = document.createElement('div');
  chart.className = 'curve-chart';
  const svg = document.createElementNS(SVG, 'svg');
  svg.setAttribute('aria-hidden', 'true');
  chart.appendChild(svg);
  const chips = document.createElement('div');
  chips.className = 'curve-points';
  row.append(chart, chips, hintRow(screenAudioText(CURVE_HINT)));
  const gradientId = `curve-fill-${++gradients}`;

  // The curve as the settings hold it, the one on screen easing toward it
  // when something else moves it, and a drag in progress.
  let target = curvePoints(settingValues());
  let from = target;
  let morphStart = 0;
  let lux = typeof state.lightLux === 'number' ? state.lightLux : null;
  let luxFrom = lux;
  let luxStart = 0;
  let drag = null;
  let frame = 0;

  const shown = () => {
    if (drag) return drag.points;
    const k = morphStart ? Math.min(1, (performance.now() - morphStart) / 320) : 1;
    if (k >= 1) return target;
    const e = ease(k);
    return target.map((p, i) => ({
      lux: Math.exp(Math.log(from[i].lux) + (Math.log(p.lux) - Math.log(from[i].lux)) * e),
      level: from[i].level + (p.level - from[i].level) * e,
    }));
  };
  const shownLux = () => {
    if (lux == null || luxFrom == null || !luxStart) return lux;
    const k = Math.min(1, (performance.now() - luxStart) / 420);
    const a = Math.log(Math.max(luxFrom, 0.01));
    const b = Math.log(Math.max(lux, 0.01));
    return Math.exp(a + (b - a) * ease(k));
  };
  const animating = () => (morphStart && performance.now() - morphStart < 320)
    || (luxStart && performance.now() - luxStart < 420);

  const schedule = () => {
    if (frame) return;
    frame = requestAnimationFrame(() => {
      frame = 0;
      paint();
      if (animating()) schedule();
    });
  };

  // Chart coordinates for the current size and range.
  const geometry = (domain) => {
    const width = Math.max(chart.clientWidth, 200);
    const height = chart.clientHeight || 250;
    const plot = {
      left: PAD.left, top: PAD.top,
      right: width - PAD.right, bottom: height - PAD.bottom,
    };
    const logLo = Math.log(domain.lo);
    const logHi = Math.log(domain.hi);
    const x = (v) => plot.left + (Math.log(Math.min(Math.max(v, domain.lo), domain.hi)) - logLo)
      / (logHi - logLo) * (plot.right - plot.left);
    const y = (v) => plot.bottom - Math.min(Math.max(v, 0), 1) * (plot.bottom - plot.top);
    const luxAt = (px) => Math.exp(logLo + Math.min(Math.max((px - plot.left)
      / (plot.right - plot.left), 0), 1) * (logHi - logLo));
    const levelAtY = (py) => Math.min(Math.max((plot.bottom - py) / (plot.bottom - plot.top), 0), 1);
    return { width, height, plot, domain, x, y, luxAt, levelAtY };
  };
  const currentGeometry = () => geometry(drag ? drag.domain
    : curveDomain(target));

  const el = (name, attrs = {}, text) => {
    const node = document.createElementNS(SVG, name);
    for (const [k, v] of Object.entries(attrs)) node.setAttribute(k, v);
    if (text != null) node.textContent = text;
    return node;
  };

  // One chip per point: its light level over its brightness. The chips
  // carry the curve's keys for the live updates and the search.
  const chipKeys = [
    [CURVE_KEYS.dark, null],
    [CURVE_KEYS.p2Position, CURVE_KEYS.p2Level],
    [CURVE_KEYS.p3Position, CURVE_KEYS.p3Level],
    [CURVE_KEYS.bright, CURVE_KEYS.max],
  ];
  const chipEls = chipKeys.map(([luxKey, levelKey], i) => {
    const chip = document.createElement('button');
    chip.type = 'button';
    chip.className = 'curve-point';
    const luxEl = document.createElement('span');
    luxEl.className = 'curve-lux';
    const levelEl = document.createElement('span');
    levelEl.className = 'curve-level';
    for (const [node, key] of [[chip, luxKey], [levelEl, levelKey]]) {
      if (!key) continue;
      node.dataset.key = key;
      node.updateSetting = () => { retarget(); return true; };
    }
    chip.append(luxEl, levelEl);
    chip.addEventListener('click', () => editPoint(i));
    chips.appendChild(chip);
    return { chip, luxEl, levelEl };
  });
  row.updateSetting = () => { retarget(); return true; };

  // Invisible handles over the points take the pointer and the keyboard:
  // a drag starting on one never scrolls the page, and one starting
  // anywhere else on the chart still does.
  const handles = [0, 1, 2, 3].map((i) => {
    const handle = document.createElement('button');
    handle.type = 'button';
    handle.className = 'curve-handle';
    handle.setAttribute('aria-label', t('screenAudioCurvePoint', { number: String(i + 1) }));
    handle.addEventListener('pointerdown', (e) => startDrag(e, i));
    handle.addEventListener('keydown', (e) => nudge(e, i));
    chart.appendChild(handle);
    return handle;
  });

  function paint() {
    const points = shown();
    const now = shownLux();
    const g = currentGeometry();
    const { plot } = g;
    svg.setAttribute('viewBox', `0 0 ${g.width} ${g.height}`);
    svg.textContent = '';
    const defs = el('defs');
    const gradient = el('linearGradient', { id: gradientId, x1: 0, y1: 0, x2: 0, y2: 1 });
    gradient.append(
      el('stop', { offset: 0, style: 'stop-color:var(--primary);stop-opacity:.26' }),
      el('stop', { offset: 1, style: 'stop-color:var(--primary);stop-opacity:.02' }));
    defs.appendChild(gradient);
    svg.appendChild(defs);

    for (let q = 0; q <= 4; q++) {
      const y = g.y(q / 4);
      svg.appendChild(el('line', { class: 'curve-grid', x1: plot.left, x2: plot.right, y1: y, y2: y }));
      if (q % 2 === 0) {
        svg.appendChild(el('text', { class: 'curve-label', x: plot.left - 8, y, 'text-anchor': 'end',
          'dominant-baseline': 'central' }, `${q * 25}%`));
      }
    }
    const first = Math.round(Math.log10(g.domain.lo));
    const last = Math.round(Math.log10(g.domain.hi));
    for (let e = first; e <= last; e++) {
      const x = g.x(10 ** e);
      svg.appendChild(el('line', { class: 'curve-grid', x1: x, x2: x, y1: plot.top, y2: plot.bottom }));
      svg.appendChild(el('text', { class: 'curve-label', x, y: plot.bottom + 6,
        'text-anchor': e === first ? 'start' : e === last ? 'end' : 'middle',
        'dominant-baseline': 'hanging' }, decadeLabel(e)));
    }

    let d = '';
    for (let x = plot.left; x <= plot.right + 0.01; x += 2) {
      d += `${d ? 'L' : 'M'}${x.toFixed(1)},${g.y(levelAt(points, g.luxAt(x))).toFixed(1)}`;
    }
    svg.appendChild(el('path', { d: `${d}L${plot.right},${plot.bottom}L${plot.left},${plot.bottom}Z`,
      fill: `url(#${gradientId})` }));
    svg.appendChild(el('path', { class: 'curve-line', d }));

    if (now != null) {
      const x = g.x(Math.max(now, g.domain.lo));
      const y = g.y(levelAt(points, now));
      svg.appendChild(el('line', { class: 'curve-now', x1: x, x2: x, y1: plot.top, y2: plot.bottom }));
      svg.appendChild(el('circle', { class: 'curve-now-halo', cx: x, cy: y, r: 9 }));
      svg.appendChild(el('circle', { class: 'curve-now-dot', cx: x, cy: y, r: 5 }));
      const label = `${luxText(now)} · ${Math.round(levelAt(points, now) * 100)}%`;
      const text = el('text', { class: 'curve-pill-text', y: plot.top + 6, 'dominant-baseline': 'central' }, label);
      const pill = el('rect', { class: 'curve-pill', y: plot.top - 4, height: 20, rx: 10 });
      svg.append(pill, text);
      const w = text.getComputedTextLength() + 14;
      const left = Math.min(Math.max(x - w / 2, plot.left), plot.right - w);
      pill.setAttribute('x', left);
      pill.setAttribute('width', w);
      text.setAttribute('x', left + 7);
    }

    points.forEach((p, i) => {
      const cx = g.x(p.lux);
      const cy = g.y(p.level);
      const active = drag?.index === i;
      if (active) svg.appendChild(el('circle', { class: 'curve-halo', cx, cy, r: 20 }));
      svg.appendChild(el('circle', { class: active ? 'curve-dot active' : 'curve-dot', cx, cy,
        r: active ? 9 : 7.5 }));
      handles[i].style.left = `${cx}px`;
      handles[i].style.top = `${cy}px`;
      chipEls[i].luxEl.textContent = luxText(p.lux);
      chipEls[i].levelEl.textContent = `${Math.round(p.level * 100)}%`;
      chipEls[i].chip.classList.toggle('active', active);
    });
  }

  function retarget({ animate = true } = {}) {
    if (drag) return;
    const next = curvePoints(settingValues());
    from = animate ? shown() : next;
    target = next;
    morphStart = animate ? performance.now() : 0;
    schedule();
  }

  const editor = {
    row,
    moveLux() {
      if (typeof state.lightLux !== 'number' || state.lightLux === lux) return;
      luxFrom = shownLux() ?? state.lightLux;
      lux = state.lightLux;
      luxStart = performance.now();
      schedule();
    },
  };
  editors.add(editor);

  function startDrag(e, index) {
    if (e.button !== 0) return;
    e.preventDefault();
    const handle = handles[index];
    handle.setPointerCapture(e.pointerId);
    handle.focus({ preventScroll: true });
    const box = chart.getBoundingClientRect();
    const g = currentGeometry();
    const points = shown().map((p) => ({ ...p }));
    const local = { x: e.clientX - box.left, y: e.clientY - box.top };
    drag = {
      index, points, domain: g.domain, pointer: e.pointerId, travel: 0,
      last: local,
      grab: { x: g.x(points[index].lux) - local.x, y: g.y(points[index].level) - local.y },
    };
    const move = (ev) => {
      if (!drag || ev.pointerId !== drag.pointer) return;
      const b = chart.getBoundingClientRect();
      const at = { x: ev.clientX - b.left, y: ev.clientY - b.top };
      drag.travel += Math.hypot(at.x - drag.last.x, at.y - drag.last.y);
      drag.last = at;
      if (drag.travel < 4) return;
      const gm = geometry(drag.domain);
      const moved = clampPoint(drag.points, drag.index, {
        lux: snapLux(gm.luxAt(at.x + drag.grab.x)),
        level: snapLevel(gm.levelAtY(at.y + drag.grab.y)),
      }, drag.domain);
      drag.points = drag.points.map((p, i) => (i === drag.index ? moved : p));
      schedule();
    };
    const end = async (ev) => {
      if (!drag || ev.pointerId !== drag.pointer) return;
      handle.removeEventListener('pointermove', move);
      handle.removeEventListener('pointerup', end);
      handle.removeEventListener('pointercancel', end);
      const done = drag;
      if (done.travel < 4) {
        drag = null;
        schedule();
        editPoint(done.index);
        return;
      }
      await commit(done.points);
      drag = null;
      retarget({ animate: false });
    };
    handle.addEventListener('pointermove', move);
    handle.addEventListener('pointerup', end);
    handle.addEventListener('pointercancel', end);
    schedule();
  }

  // Arrows move the focused point: up and down by 1% brightness, left and
  // right along the light scale. Enter opens its dialog.
  async function nudge(e, index) {
    const step = {
      ArrowUp: [0, 0.01], ArrowDown: [0, -0.01], ArrowRight: [1, 0], ArrowLeft: [-1, 0],
    }[e.key];
    if (!step) return;
    e.preventDefault();
    const points = target.map((p) => ({ ...p }));
    const p = points[index];
    const lux = step[0] ? snapLux(p.lux * (step[0] > 0 ? 1.1 : 1 / 1.1)) : p.lux;
    points[index] = clampPoint(points, index, { lux, level: snapLevel(p.level + step[1]) },
      curveDomain(target));
    await commit(points);
    retarget({ animate: false });
  }

  // Write a whole curve in one request: the device checks the settings
  // together, so the ends may pass each other's old values in one move.
  async function commit(points) {
    const values = curveSettings(points);
    try {
      const res = await api('/api/settings', { method: 'PATCH', body: JSON.stringify(values) });
      const out = await res.json().catch(() => null);
      if (!res.ok || out?.ok !== true) {
        throw new Error(Object.values(out?.errors || {})[0] || out?.error
          || 'Could not save this setting. Try again.');
      }
    } catch (error) {
      showError(error?.message || 'Could not save this setting. Try again.');
      return false;
    }
    clearError();
    for (const s of state.settings || []) {
      if (s.key in values) s.value = values[s.key];
    }
    return true;
  }

  function editPoint(index) {
    const points = target.map((p) => ({ ...p }));
    const p = points[index];
    const b = pointBounds(points, index, null, 1);
    const body = document.createElement('div');
    const luxField = cameraField(screenAudioText('Light level (lx)'), formatCurveLux(p.lux));
    const levelField = cameraField(screenAudioText('Brightness (%)'), String(Math.round(p.level * 100)));
    luxField.input.inputMode = 'decimal';
    levelField.input.inputMode = 'numeric';
    body.append(luxField.wrap, levelField.wrap);
    requestAnimationFrame(() => luxField.input.focus());
    cameraEditor({
      title: t('screenAudioCurvePoint', { number: String(index + 1) }),
      width: 420,
      body,
      save: async () => {
        const lux = Number(luxField.input.value.trim().replace(',', '.'));
        const level = Number(levelField.input.value.trim());
        if (!luxField.input.value.trim() || !Number.isFinite(lux) || lux <= b.luxLo || lux >= b.luxHi) {
          return { ok: false, error: t('screenAudioCurveLuxRange',
            { low: formatCurveLux(b.luxLo), high: formatCurveLux(b.luxHi) }) };
        }
        if (!levelField.input.value.trim() || !Number.isFinite(level)
            || level / 100 < b.levelLo - 1e-9 || level / 100 > b.levelHi + 1e-9) {
          return { ok: false, error: t('screenAudioCurveLevelRange',
            { low: String(Math.round(b.levelLo * 100)), high: String(Math.round(b.levelHi * 100)) }) };
        }
        points[index] = { lux, level: Math.round(level) / 100 };
        const ok = await commit(points);
        retarget({ animate: false });
        return ok ? { ok: true } : { ok: false, error: row.querySelector('.row-error')?.textContent };
      },
    });
  }

  // The chart follows the card's width.
  new ResizeObserver(() => schedule()).observe(chart);
  schedule();
  return row;
}
