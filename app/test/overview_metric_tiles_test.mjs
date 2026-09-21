import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

// The stack as data, lifted out of overview.js the way the filter status
// test lifts its painter: the function is pure and its callers are DOM.
const overview = readFileSync(new URL('../remote-ui/static/overview.js', import.meta.url), 'utf8');
const start = overview.indexOf('export function ledCells(');
const end = overview.indexOf('\n}\n', start) + 3;
const context = vm.createContext({});
vm.runInContext(overview.slice(start, end).replace('export ', ''), context);
// Arrays born in the vm context carry its Array prototype, which strict
// deepEqual rejects: round-trip through JSON to plain host values.
const ledCells = (...args) => JSON.parse(JSON.stringify(context.ledCells(...args)));
const cpu = { lo: 0, hi: 100, warn: 70, err: 90 };
const temp = { lo: 20, hi: 90, warn: 65, err: 80 };
const lit = (col) => col.filter(Boolean).length;

test('a column lights from the bottom to the value and cells wear their band', () => {
  const [col] = ledCells([95], cpu, 1, 8);
  assert.equal(lit(col), 8);
  // Midpoints 6.25 .. 93.75: the top cell is red, the one below amber.
  assert.deepEqual(col.slice(5), ['ok', 'warn', 'off']);
  assert.deepEqual(col.slice(0, 5), ['ok', 'ok', 'ok', 'ok', 'ok']);
});

test('the band comes from the cell, not the current value', () => {
  const [col] = ledCells([40], cpu, 1, 8);
  assert.equal(lit(col), 4);
  assert.ok(col.slice(0, 4).every((band) => band === 'ok'));
  assert.ok(col.slice(4).every((band) => band === null));
});

test('any load above the floor lights at least one cell, nothing above the ceiling overflows', () => {
  assert.equal(lit(ledCells([0.5], cpu, 1, 8)[0]), 1);
  assert.equal(lit(ledCells([0], cpu, 1, 8)[0]), 0);
  assert.equal(lit(ledCells([140], cpu, 1, 8)[0]), 8);
  assert.equal(lit(ledCells([10], temp, 1, 8)[0]), 0);
});

test('a fixed temperature scale keeps a warm room low and a hot chip red', () => {
  assert.equal(lit(ledCells([38], temp, 1, 8)[0]), 3);
  const hot = ledCells([86], temp, 1, 8)[0];
  assert.equal(hot[7], 'off');
  assert.equal(hot[5], 'warn');
});

test('the newest sample is the last column and short history pads unlit columns on the left', () => {
  const cols = ledCells([10, 20, 30], cpu, 5, 4);
  assert.equal(cols.length, 5);
  assert.equal(lit(cols[0]), 0);
  assert.equal(lit(cols[1]), 0);
  assert.deepEqual(cols.slice(2).map(lit), [1, 1, 2]);
});

test('history longer than the slot shows only its tail', () => {
  const values = Array.from({ length: 60 }, (_, i) => (i === 59 ? 100 : 0));
  const cols = ledCells(values, cpu, 24, 8);
  assert.equal(cols.length, 24);
  assert.equal(lit(cols[23]), 8);
  assert.ok(cols.slice(0, 23).every((col) => lit(col) === 0));
});

test('a declined sample is an unlit column in its place', () => {
  const cols = ledCells([50, null, 50], cpu, 3, 4);
  assert.deepEqual(cols.map(lit), [2, 0, 2]);
});

test('fewer rows still put amber and red at the top', () => {
  const [col] = ledCells([100], cpu, 1, 5);
  assert.deepEqual(col, ['ok', 'ok', 'ok', 'warn', 'off']);
});
