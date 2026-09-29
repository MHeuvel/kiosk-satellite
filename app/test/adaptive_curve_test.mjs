import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

// The remote admin's copy of the adaptive brightness curve (issue #742),
// loaded the way the other pure-module tests load theirs: the module has
// no imports, so its exports run as plain declarations.
const source = readFileSync(new URL('../remote-ui/static/adaptive_curve.js', import.meta.url), 'utf8');
const context = vm.createContext({});
vm.runInContext(source.replace(/^export /gm, ''), context);
const plain = (value) => JSON.parse(JSON.stringify(value));
const { curvePoints, curveSettings, levelAt, positionFor, shareFor, curveDomain, clampPoint, snapLux } = context;

const steep = [
  { lux: 5, level: 0.05 },
  { lux: 10, level: 0.10 },
  { lux: 15, level: 0.30 },
  { lux: 300, level: 1.0 },
];
const defaults = {
  min: 0.15, max: 0.8, dark: 5, bright: 300,
  p2Position: 1 / 3, p2Level: 1 / 3, p3Position: 2 / 3, p3Level: 2 / 3,
};

test('the same numbers as the device curve', () => {
  // test/adaptive_brightness_test.dart pins the same values on the device.
  const expected = { 6: 0.060943507576, 7: 0.069020084484, 12: 0.176648713345,
    40: 0.580238677605, 120: 0.808277772294 };
  for (const [lux, level] of Object.entries(expected)) {
    assert.ok(Math.abs(levelAt(steep, Number(lux)) - level) < 1e-9, lux);
  }
});

test('the default middle points draw the straight log line', () => {
  const points = curvePoints(defaults);
  for (const lux of [7, 20, 120]) {
    const t = (Math.log(lux) - Math.log(5)) / (Math.log(300) - Math.log(5));
    assert.ok(Math.abs(levelAt(points, lux) - (0.15 + 0.65 * t)) < 1e-9, String(lux));
  }
  assert.equal(levelAt(points, 1), 0.15);
  assert.equal(levelAt(points, 5000), 0.8);
});

test('never dips where the points climb', () => {
  let last = -1;
  for (let lux = 1; lux <= 1000; lux *= 1.01) {
    const level = levelAt(steep, lux);
    assert.ok(level >= last - 1e-12, String(lux));
    last = level;
  }
});

test('the settings a curve writes read back as the same curve', () => {
  const values = plain(curveSettings(steep));
  assert.equal(values['screen.adaptive_min_brightness'], 0.05);
  assert.equal(values['screen.adaptive_max_brightness'], 1);
  assert.equal(values['screen.adaptive_dark_lux'], 5);
  assert.equal(values['screen.adaptive_bright_lux'], 300);
  assert.ok(Math.abs(values['screen.adaptive_point2_position'] - positionFor(10, 5, 300)) < 1e-6);
  assert.ok(Math.abs(values['screen.adaptive_point3_level'] - shareFor(0.3, 0.05, 1)) < 1e-6);
  const back = curvePoints({
    min: values['screen.adaptive_min_brightness'],
    max: values['screen.adaptive_max_brightness'],
    dark: values['screen.adaptive_dark_lux'],
    bright: values['screen.adaptive_bright_lux'],
    p2Position: values['screen.adaptive_point2_position'],
    p2Level: values['screen.adaptive_point2_level'],
    p3Position: values['screen.adaptive_point3_position'],
    p3Level: values['screen.adaptive_point3_level'],
  });
  back.forEach((p, i) => {
    assert.ok(Math.abs(p.lux - steep[i].lux) < 1e-3, `lux ${i}`);
    assert.ok(Math.abs(p.level - steep[i].level) < 1e-6, `level ${i}`);
  });
});

test('the chart range ignores the live reading, so a flapping sensor never '
  + 'moves the axis', () => {
  // The range takes only the points: no reading can reach it.
  assert.equal(curveDomain.length, 1);
  const points = curvePoints({ min: 0.2, max: 1, dark: 5, bright: 30,
    p2Position: 1 / 3, p2Level: 1 / 3, p3Position: 2 / 3, p3Level: 2 / 3 });
  assert.deepEqual(plain(curveDomain(points)), { lo: 1, hi: 100 });
});

test('a dragged point stays between its neighbors and snaps to two figures', () => {
  const domain = plain(curveDomain(steep));
  assert.deepEqual(domain, { lo: 1, hi: 1000 });
  const moved = plain(clampPoint(steep, 1, { lux: 40, level: 0.9 }, domain));
  assert.ok(moved.lux < 15 && moved.lux > 5 * 1.12);
  assert.equal(moved.level, 0.3);
  assert.equal(snapLux(47.3), 47);
  assert.equal(snapLux(4.73), 4.7);
  assert.equal(snapLux(1234), 1200);
});
