import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { runInNewContext } from 'node:vm';

const source = readFileSync(new URL(
  '../lib/managers/browser/haptics_script.dart', import.meta.url,
), 'utf8');
const script = source
  .match(/const buttonHapticsScript = '''([\s\S]*?)''';/)[1]
  .replace(/\\\$/g, '$');

// Runs the script against a window that records its listeners and the
// messages it sends to the app.
function page({ haptics = false, tapSound = true } = {}) {
  const listeners = {};
  const sent = [];
  class EventTarget { dispatchEvent() { return true; } }
  class Element extends EventTarget {
    constructor(localName) { super(); this.localName = localName; }
    getAttribute() { return null; }
  }
  const window = {
    __ksHapticsEnabled: haptics,
    __ksTapSoundEnabled: tapSound,
    flutter_inappwebview: { callHandler: (name, kind) => sent.push([name, kind]) },
  };
  runInNewContext(script, {
    window,
    addEventListener: (type, fn) => { listeners[type] = fn; },
    EventTarget,
    Element,
    performance: { now: () => 0 },
  });
  const fire = (type, event) => listeners[type](event);
  return { window, sent, fire, Element };
}

test('a haptic event from a custom card plays a tap', () => {
  for (const type of ['light', 'medium', 'heavy', 'selection', 'warning']) {
    const { sent, fire } = page();
    fire('haptic', { detail: type, timeStamp: 1000 });
    assert.deepEqual(sent, [['ksHaptic', 'tap']], type);
  }
});

test('outcome haptics stay quiet', () => {
  const { sent, fire } = page();
  fire('haptic', { detail: 'success', timeStamp: 1000 });
  fire('haptic', { detail: 'failure', timeStamp: 2000 });
  fire('haptic', { detail: undefined, timeStamp: 3000 });
  assert.deepEqual(sent, []);
});

test('a haptic next to an action or click plays once', () => {
  const { sent, fire, Element } = page();
  fire('action', { detail: { action: 'tap' }, timeStamp: 1000 });
  fire('haptic', { detail: 'light', timeStamp: 1002 });
  const button = new Element('button');
  fire('haptic', { detail: 'selection', timeStamp: 2000 });
  fire('click', { composedPath: () => [button], timeStamp: 2030 });
  fire('haptic', { detail: 'light', timeStamp: 3000 });
  assert.deepEqual(sent, [
    ['ksHaptic', 'tap'],
    ['ksHaptic', 'tap'],
    ['ksHaptic', 'tap'],
  ]);
});

test('haptic events follow the feedback settings', () => {
  const { window, sent, fire } = page({ haptics: false, tapSound: false });
  fire('haptic', { detail: 'light', timeStamp: 1000 });
  assert.deepEqual(sent, []);
  window.__ksHapticsEnabled = true;
  fire('haptic', { detail: 'light', timeStamp: 2000 });
  assert.deepEqual(sent, [['ksHaptic', 'tap']]);
});
