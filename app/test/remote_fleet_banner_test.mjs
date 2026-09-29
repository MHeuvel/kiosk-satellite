import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

// The follower banner ("<leader> leads these settings") is prepended to a
// tab by applyManagedBanners, which runs after every settings load. The
// generic tabs keep it from there, but a page that rebuilds its tab from
// scratch on every visit throws it away, so such a page has to put it back
// itself, right after the wipe. Gestures and Cameras are those pages.
const read = (file) =>
  readFileSync(new URL(`../remote-ui/static/${file}`, import.meta.url), 'utf8');

const pages = [
  ['gestures.js', 'export async function loadGestures(', "root.innerHTML = '';"],
  ['cameras.js', 'export async function loadCameras(', "root.innerHTML = '';"],
];

for (const [file, loader, wipe] of pages) {
  test(`${file} puts the fleet banner back after rebuilding its tab`, () => {
    const source = read(file);
    assert.match(source, /^import \{ applyManagedBanners \} from '\.\/fleetsync\.js';$/m,
      `${file} imports applyManagedBanners`);
    const start = source.indexOf(loader);
    assert.ok(start >= 0, `${file} defines ${loader}`);
    const body = source.slice(start);
    const wiped = body.indexOf(wipe);
    assert.ok(wiped >= 0, `${loader} clears its tab with ${wipe}`);
    const between = body.slice(wiped + wipe.length, wiped + wipe.length + 400);
    assert.ok(between.includes('applyManagedBanners();'),
      `${loader} calls applyManagedBanners() right after clearing the tab`);
  });
}

// The settings render clears the Voice Satellite and Home Assistant tab
// roots after renderFleetPage() has applied the banners, so it applies
// them again once every section is in place.
test('settings.js applies the fleet banners after its last tab rebuild', () => {
  const source = read('settings.js');
  assert.match(source, /^import \{ applyManagedBanners, renderFleetPage \} from '\.\/fleetsync\.js';$/m,
    'settings.js imports applyManagedBanners');
  const start = source.indexOf('async function renderSettings(');
  assert.ok(start >= 0, 'settings.js defines renderSettings');
  const end = source.indexOf('\n}\n', start);
  const body = source.slice(start, end);
  const applied = body.lastIndexOf('applyManagedBanners();');
  assert.ok(applied >= 0, 'renderSettings calls applyManagedBanners()');
  for (const tab of ['tab-voicesatellite', 'tab-homeassistant']) {
    const wiped = body.indexOf(`document.getElementById('${tab}');\n    root.innerHTML = '';`);
    assert.ok(wiped >= 0, `renderSettings clears #${tab}`);
    assert.ok(applied > wiped, `the banners go back on after #${tab} is cleared`);
  }
});
