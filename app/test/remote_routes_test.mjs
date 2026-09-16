import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const source = readFileSync(new URL('../remote-ui/static/routes.js', import.meta.url), 'utf8');
const { routeHash, routeSlug, readRoute } = await import('data:text/javascript,' + encodeURIComponent(source));

test('human labels produce readable routes and plugin IDs remain distinct', () => {
  assert.equal(routeHash('camera/RTSP & ONVIF Streaming'), 'camera/rtsp-onvif-streaming');
  assert.equal(routeHash('device/Permissions Manager'), 'device/permissions-manager');
  assert.equal(routeHash('screensaver/'), 'screensaver');
  assert.equal(routeHash('plugins/example.plugin'), 'plugins/example.plugin');
  assert.equal(routeSlug('Wake Word'), 'wake-word');
  assert.equal(readRoute('#camera/RTSP%20&%20ONVIF%20Streaming'), 'camera/RTSP & ONVIF Streaming');
  assert.equal(readRoute('#camera/%E0%A4%A'), '');
});

test('both legacy titles and slugs open the same panel with its original title', () => {
  const tabs = readFileSync(new URL('../remote-ui/static/tabs.js', import.meta.url), 'utf8');
  const start = tabs.indexOf('export function applySubpageView(');
  const end = tabs.indexOf('\n// The tab the page', start);
  const panel = { dataset: { subpage: 'RTSP & ONVIF Streaming' }, classList: { toggle(_, open) { panel.open = open; } } };
  const root = { querySelectorAll: () => [panel], classList: { toggle() {} } };
  const context = vm.createContext({ routeSlug, document: { getElementById: () => root } });
  vm.runInContext(tabs.slice(start, end).replace('export ', ''), context);
  for (const path of ['RTSP & ONVIF Streaming', 'rtsp-onvif-streaming']) {
    assert.equal(context.applySubpageView('camera', path), 'RTSP & ONVIF Streaming');
    assert.equal(panel.open, true);
  }
  assert.equal(context.applySubpageView('camera', 'unknown'), '');
  assert.equal(panel.open, false);
});
