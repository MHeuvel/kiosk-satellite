import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const source = readFileSync(new URL('../remote-ui/static/transport.js', import.meta.url), 'utf8');
const client = () => import('data:text/javascript,' + encodeURIComponent(source + `\n// ${Math.random()}`));
function socket() { return { readyState: 1, sent: [], send(raw) { this.sent.push(JSON.parse(raw)); } }; }

test('concurrent replies resolve by ID even when they arrive out of order', async () => {
  const c = await client(), ws = socket();
  c.attachSocket(ws);
  const first = c.socketRequest({ type: 'command', name: 'read' });
  const second = c.socketRequest({ type: 'settings', values: { mode: 'black' } });
  c.receiveResult({ type: 'result', id: ws.sent[1].id, ok: true, data: 'second' });
  c.receiveResult({ type: 'result', id: ws.sent[0].id, ok: true, data: 'first' });
  assert.equal((await first).data, 'first');
  assert.equal((await second).data, 'second');
});

test('disconnect rejects pending writes without replaying them after reconnect', async () => {
  const c = await client(), ws = socket();
  c.attachSocket(ws);
  const write = c.socketRequest({ type: 'command', name: 'toggle' });
  const rejected = assert.rejects(write, /disconnected/);
  c.detachSocket(ws);
  await rejected;
  const next = socket();
  c.attachSocket(next);
  assert.deepEqual(next.sent, []);
  c.detachSocket(ws);
  assert.equal(c.socketReady(), true);
});

test('aborts and timeouts discard late responses', async () => {
  const c = await client(), ws = socket(), controller = new AbortController();
  c.attachSocket(ws);
  const pending = c.socketRequest({ type: 'command' }, { signal: controller.signal });
  const aborted = assert.rejects(pending, { name: 'AbortError' });
  controller.abort();
  await aborted;
  c.receiveResult({ type: 'result', id: ws.sent[0].id, ok: true });
  await assert.rejects(c.socketRequest({ type: 'command' }, { timeoutMs: 10 }), /timed out/);
  controller.abort();
  await assert.rejects(c.socketRequest({ type: 'command' }, { signal: controller.signal }), { name: 'AbortError' });
  assert.equal(ws.sent.length, 2);
});
