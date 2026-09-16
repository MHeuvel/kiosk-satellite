import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const source = readFileSync(new URL('../remote-ui/static/live.js', import.meta.url), 'utf8')
  .replace(/^import .*\n/gm, '').replaceAll('export ', '');
const settle = () => new Promise(resolve => setImmediate(resolve));
const wait = ms => new Promise(resolve => setTimeout(resolve, ms));
function fixture() {
  const subscriptions = [];
  const document = { hidden: false, body: {}, addEventListener() {},
    querySelector: () => null };
  const context = vm.createContext({ document, setTimeout, clearTimeout, queueMicrotask,
    MutationObserver: class { observe() {} },
    socketReady: () => true,
    socketRequest: async message => { subscriptions.push(message.topics); },
  });
  vm.runInContext(source, context);
  return { context, document, subscriptions };
}

test('event bursts are bounded and never become idle polling', async () => {
  const { context } = fixture();
  let reads = 0;
  const stop = context.watchUpdates(['plugins'], async () => { reads++; }, { intervalMs: 40 });
  await settle();
  assert.equal(reads, 1);
  for (let i = 0; i < 100; i++) context.receiveUpdate('plugins');
  await wait(65);
  assert.equal(reads, 2);
  await wait(65);
  assert.equal(reads, 2);
  stop();
});

test('hidden and detached panels release their topics and pending reads', async () => {
  const { context, document, subscriptions } = fixture();
  let reads = 0;
  const owner = { isConnected: true, getClientRects: () => [1] };
  const stop = context.watchUpdates(['rtsp'], async () => { reads++; }, { owner, intervalMs: 40 });
  await settle();
  assert(subscriptions.at(-1).includes('rtsp'));
  context.receiveUpdate('rtsp');
  document.hidden = true;
  context.syncSubscriptions();
  assert(!subscriptions.at(-1).includes('rtsp'));
  await wait(65);
  assert.equal(reads, 1);
  document.hidden = false;
  context.syncSubscriptions();
  await settle();
  assert.equal(reads, 2);
  owner.isConnected = false;
  context.syncSubscriptions();
  assert(!subscriptions.at(-1).includes('rtsp'));
  context.receiveUpdate('rtsp');
  await wait(65);
  assert.equal(reads, 2);
  stop();
});
