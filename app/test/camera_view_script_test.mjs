import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const source = readFileSync(new URL('../assets/camera-view/camera-view.js', import.meta.url), 'utf8');

// Lifts one top-level function out of the page script; the page itself
// needs a DOM and the app bridge to run.
function lift(name) {
  const start = source.indexOf(`function ${name}(`);
  assert.notEqual(start, -1, `${name} is defined`);
  return source.slice(start, source.indexOf('\n}\n', start) + 3);
}

function helpers(allowH265) {
  const logged = [];
  const context = vm.createContext({
    ALLOW_H265: allowH265,
    log: (message, level) => logged.push({ message, level }),
  });
  vm.runInContext(lift('sanitizeAnswer') + lift('decodeHint'), context);
  return { logged, sanitizeAnswer: context.sanitizeAnswer, decodeHint: context.decodeHint };
}

// The answer Go2RTC 1.9.14 returns for a `candidates:` entry written
// "192.168.3.70:8555?transport=tcp" (issue #543).
const answer = [
  'v=0',
  'o=- 1 1 IN IP4 0.0.0.0',
  'm=video 9 UDP/TLS/RTP/SAVPF 96',
  'a=candidate:3042148898 1 tcp 1671430142 192.168.3.70 8555?transport=tcp typ host tcptype passive',
  'a=candidate:144765890 1 udp 2130706429 192.168.3.70 8555?transport=tcp typ host',
  'a=candidate:144765890 1 udp 2130706431 192.168.3.70 8555 typ host ufrag iyvJVMNhGpfueJhT',
  'a=candidate:3042148898 1 tcp 1671430143 192.168.3.70 8555 typ host tcptype passive ufrag iyvJVMNhGpfueJhT',
  'a=candidate:1611365382 1 udp 1694498815 181.198.245.170 51354 typ srflx raddr 0.0.0.0 rport 51354 ufrag iyvJVMNhGpfueJhT',
  'a=end-of-candidates',
  '',
].join('\r\n');

test('sanitizeAnswer drops candidates whose port the SDP parser refuses', () => {
  const { sanitizeAnswer, logged } = helpers(false);
  const lines = sanitizeAnswer(answer, 'cam').split('\r\n');
  assert.deepEqual(lines.filter((line) => line.includes('?transport')), []);
  assert.equal(lines.filter((line) => line.startsWith('a=candidate:')).length, 3);
  assert.equal(lines[0], 'v=0');
  assert.equal(lines.at(-2), 'a=end-of-candidates');
  assert.equal(lines.at(-1), '');
  assert.equal(logged.length, 2);
  assert.equal(logged[0].level, 'warn');
  assert.match(logged[0].message, /^cam: dropped an ICE candidate with port "8555\?transport=tcp"/);
  assert.match(logged[0].message, /Go2RTC config/);
});

test('sanitizeAnswer leaves a clean answer alone', () => {
  const { sanitizeAnswer, logged } = helpers(false);
  const clean = answer.split('\r\n').filter((line) => !line.includes('?transport')).join('\r\n');
  assert.equal(sanitizeAnswer(clean, 'cam'), clean);
  assert.equal(sanitizeAnswer(clean.replace(/\r\n/g, '\n'), 'cam'), clean);
  assert.equal(logged.length, 0);
});

test('sanitizeAnswer treats an out-of-range port as malformed', () => {
  const { sanitizeAnswer } = helpers(false);
  const line = 'a=candidate:1 1 udp 1 192.168.3.70 65536 typ host';
  assert.equal(sanitizeAnswer(`v=0\r\n${line}\r\n`, 'cam'), 'v=0\r\n');
  assert.equal(sanitizeAnswer(`v=0\r\n${line.replace('65536', '65535')}\r\n`, 'cam'),
    `v=0\r\n${line.replace('65536', '65535')}\r\n`);
});

test('decodeHint names the Allow H.265 setting only when it let H.265 through', () => {
  assert.match(helpers(true).decodeHint('H.265'), /turn off Allow H.265 streams/);
  assert.equal(helpers(true).decodeHint('H.264'), '');
  assert.equal(helpers(false).decodeHint('H.265'), '');
});

test('the page sanitizes every answer and watches MSE decoding', () => {
  assert.match(source, /sdp: sanitizeAnswer\(signaling\.answer, cameraId\)/);
  assert.match(source, /watching = true;[\s\S]{0,80}watchMseDecode\(\);/);
  // "playing over MSE" means frames decoded, not bytes received.
  assert.match(source, /session\.undecoded = null;[\s\S]{0,200}playing over MSE/);
  assert.doesNotMatch(source, /session\.queue\.push\(event\.data\);[\s\S]{0,300}playing over MSE/);
  // A media decode error and an append refused over one both name the codec.
  assert.equal((source.match(/failedToDecode\(detail\);/g) || []).length, 2);
  // Both watchdogs share the parking logic so a codec neither transport
  // decodes stops the switching loop.
  assert.equal((source.match(/undecodable\((codec|label)\);/g) || []).length, 2);
});

function deferred() {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
}

// Run the real session lifecycle with a fake clock and controllable peers.
function playbackHarness({ transports = ['webrtc'], handler = () => undefined } = {}) {
  let now = 0, nextId = 0;
  const timers = new Map(), sessions = new Map(), statuses = new Map();
  const peers = [], logged = [], calls = [];
  const pendingPlay = deferred();
  const video = {
    src: '', srcObject: null,
    play: () => pendingPlay.promise,
    pause() { pendingPlay.reject(new Error('AbortError')); },
    removeAttribute() {}, load() {}, remove() {},
  };
  const tile = { querySelector: (selector) => selector === 'video' ? video : null };
  class Peer {
    constructor() {
      this.connectionState = 'new';
      this.iceConnectionState = 'new';
      this.iceGatheringState = 'complete';
      this.stats = new Map();
      this.remoteDescriptions = [];
      peers.push(this);
    }
    addTransceiver() { return {}; }
    async createOffer() { return { type: 'offer', sdp: 'offer' }; }
    async setLocalDescription(offer) { this.localDescription = offer; }
    async setRemoteDescription(answer) { this.remoteDescriptions.push(answer); }
    getStats() { return Promise.resolve(this.stats); }
    getReceivers() { return []; }
    close() { this.connectionState = 'closed'; this.onconnectionstatechange?.(); }
    connect() { this.connectionState = 'connected'; this.onconnectionstatechange(); }
    track() { this.ontrack({ streams: [{ getTracks: () => [] }] }); }
  }
  const schedule = (callback, delay, interval = 0) => {
    timers.set(++nextId, { at: now + delay, callback, interval });
    return nextId;
  };
  const context = vm.createContext({
    CFG: { cameras: [{ id: 'cam', transports }] }, sessions,
    window: { RTCPeerConnection: Peer }, RTCPeerConnection: Peer,
    document: { readyState: 'complete', querySelector: () => tile },
    CSS: { escape: (value) => value },
    setTimeout: (callback, delay) => schedule(callback, delay),
    setInterval: (callback, delay) => schedule(callback, delay, delay),
    clearTimeout: (id) => timers.delete(id), clearInterval: (id) => timers.delete(id),
    bridge: (name, value) => {
      calls.push({ name, value });
      return handler(name, value) ?? Promise.resolve(
        name === 'cameraOffer' ? { ok: true, answer: 'v=0\r\n' } : null);
    },
    log: (message, level) => logged.push({ message, level }),
    setStatus: (id, message) => statuses.set(id, message),
    audioFor: () => false,
  });
  const constants = source.slice(source.indexOf('const DISCONNECT_GRACE_MS'),
    source.indexOf('// Sound is opt-in'));
  vm.runInContext(constants + ['viewStatus', 'codecLabel', 'decodeHint',
    'signalingFailure', 'sanitizeAnswer', 'waitForIce', 'waitForHlsLibrary', 'stop',
    'start']
    .map(lift).join('\n'), context);
  const flush = async () => { for (let i = 0; i < 20; i++) await Promise.resolve(); };
  async function advance(ms) {
    const end = now + ms;
    await flush();
    for (;;) {
      const next = [...timers.entries()].filter(([, timer]) => timer.at <= end)
        .sort((a, b) => a[1].at - b[1].at)[0];
      if (!next) break;
      const [id, timer] = next;
      now = timer.at;
      if (timer.interval) timer.at += timer.interval;
      else timers.delete(id);
      timer.callback();
      await flush();
    }
    now = end;
  }
  context.start('cam', false);
  return { context, peers, sessions, statuses, logged, calls, timers, flush, advance,
    video, pendingPlay };
}

function videoStats(framesDecoded, packetsReceived = 10) {
  return new Map([
    ['codec', { type: 'codec', id: 'codec', mimeType: 'video/H264' }],
    ['video', { type: 'inbound-rtp', kind: 'video', codecId: 'codec',
      framesDecoded, packetsReceived, framesReceived: framesDecoded,
      frameWidth: 1280, frameHeight: 960 }],
  ]);
}

test('HLS fallback times out WebRTC without waiting for play to settle', async () => {
  const h = playbackHarness({ transports: ['hls', 'webrtc', 'mjpeg'] });
  await h.advance(2000);
  const pc = h.peers[0];
  pc.track();
  assert.equal(h.statuses.get('cam').id, 'cameraViewerConnecting');
  await h.advance(9999);
  assert.equal(pc.connectionState, 'new');
  await h.advance(1);
  assert.equal(pc.connectionState, 'closed');
  assert.match(h.logged.at(-1).message, /WebRTC connect timeout.*connection=new/);
  assert.equal(h.logged.at(-1).level, 'warn');
  assert.equal(h.statuses.get('cam').id, 'cameraViewerConnectionRetry');
  await h.advance(4000);
  assert.equal(h.peers.length, 2);
});

test('connected peers receiving no video time out and eventually switch transport', async () => {
  const h = playbackHarness({ transports: ['webrtc', 'hls'] });
  await h.flush();
  for (const delay of [2000, 4000, 8000]) {
    h.peers.at(-1).connect();
    await h.advance(10000);
    assert.equal(h.sessions.get('cam').pc, null);
    if (delay !== 8000) await h.advance(delay);
  }
  assert.equal(h.sessions.get('cam').modeIndex, 1);
  assert.equal(h.logged.filter(({ message }) => /WebRTC connect timeout/.test(message)).length, 3);
  assert.match(h.logged.at(-1).message, /switching to HLS/);
});

test('decoded video cancels startup timeout and clears connection status', async () => {
  const h = playbackHarness();
  await h.flush();
  const pc = h.peers[0];
  pc.connect();
  assert.equal(h.statuses.get('cam').id, 'cameraViewerConnecting');
  pc.stats = videoStats(1);
  await h.advance(2500);
  assert.equal(h.statuses.get('cam'), '');
  assert.equal(h.calls.filter(({ name }) => name === 'cameraPlaying').length, 1);
  await h.advance(30000);
  assert.equal(pc.connectionState, 'connected');
  assert.equal(h.timers.size, 0);
});

test('startup timeout preserves codec diagnostics and transport fallback', async () => {
  const h = playbackHarness({ transports: ['webrtc', 'hls'] });
  await h.flush();
  h.peers[0].stats = videoStats(0);
  h.peers[0].connect();
  await h.advance(10000);
  assert.equal(h.sessions.get('cam').modeIndex, 1);
  assert.ok(h.logged.some(({ message }) => /H.264 stream connected.*decoded 0 frames/.test(message)));
});

test('video playback starting between stats polls cancels the deadline', async () => {
  const h = playbackHarness();
  await h.flush();
  const pc = h.peers[0];
  pc.track();
  pc.connect();
  await h.advance(9999);
  h.video.videoWidth = 1280;
  h.pendingPlay.resolve();
  await h.advance(1);
  assert.equal(pc.connectionState, 'connected');
  assert.equal(h.statuses.get('cam'), '');
  assert.equal(h.logged.length, 0);
});

test('audio playback without a video picture does not cancel the deadline', async () => {
  const h = playbackHarness();
  await h.flush();
  h.peers[0].track();
  h.pendingPlay.resolve();
  await h.advance(10000);
  assert.equal(h.peers[0].connectionState, 'closed');
  assert.match(h.logged.at(-1).message, /WebRTC connect timeout/);
});

for (const stage of ['cameraRtcConfig', 'cameraOffer']) {
  test(`a stalled ${stage} is bounded and its late result cannot affect the retry`, async () => {
    const pending = deferred();
    let requests = 0;
    const h = playbackHarness({ handler: (name) => {
      if (name === stage && ++requests === 1) return pending.promise;
    } });
    await h.advance(12000);
    const replacement = h.sessions.get('cam').pc;
    assert.ok(replacement);
    const count = h.peers.length;
    pending.resolve({ ok: true, answer: 'v=0\r\n' });
    await h.flush();
    assert.equal(h.peers.length, count);
    assert.equal(h.sessions.get('cam').pc, replacement);
    assert.equal(replacement.remoteDescriptions.length, 1);
    if (stage === 'cameraOffer') assert.equal(h.peers[0].remoteDescriptions.length, 0);
  });
}

test('a late signaling rejection cannot close a replacement peer', async () => {
  const pending = deferred();
  let offers = 0;
  const h = playbackHarness({ handler: (name) => {
    if (name === 'cameraOffer' && ++offers === 1) return pending.promise;
  } });
  await h.advance(12000);
  const replacement = h.sessions.get('cam').pc;
  pending.reject(new Error('old offer failed'));
  await h.flush();
  assert.equal(h.sessions.get('cam').pc, replacement);
  assert.equal(replacement.connectionState, 'new');
  assert.equal(h.logged.some(({ message }) => /old offer failed/.test(message)), false);
});

test('late stats from an abandoned peer cannot report playback or cancel the new watchdog', async () => {
  const h = playbackHarness();
  await h.flush();
  const pending = deferred();
  const old = h.peers[0];
  old.getStats = () => pending.promise;
  old.connect();
  await h.advance(12000);
  const replacement = h.sessions.get('cam').pc;
  pending.resolve(videoStats(1));
  await h.flush();
  assert.equal(h.calls.some(({ name }) => name === 'cameraPlaying'), false);
  await h.advance(10000);
  assert.equal(replacement.connectionState, 'closed');
});

test('closing during startup cancels timers and ignores the pending play rejection', async () => {
  const h = playbackHarness();
  await h.flush();
  h.peers[0].track();
  h.context.stop('cam');
  await h.advance(60000);
  assert.equal(h.timers.size, 0);
  assert.equal(h.peers.length, 1);
  assert.equal(h.logged.length, 0);
});

// The bootstrap appends the page script, which runs as soon as it loads
// and can beat the deferred hls.js on a slow start (issue #643).
function hlsWait(win) {
  const listeners = [];
  const context = vm.createContext({
    window: win,
    document: { readyState: win.readyState },
    addEventListener: (name, handler) => listeners.push({ name, handler }),
  });
  vm.runInContext(lift('waitForHlsLibrary'), context);
  return { listeners, wait: context.waitForHlsLibrary };
}

test('waitForHlsLibrary resolves at once when the library is there', async () => {
  const { listeners, wait } = hlsWait({ Hls: {}, readyState: 'interactive' });
  await wait();
  assert.equal(listeners.length, 0);
});

test('waitForHlsLibrary resolves at once once the page has loaded', async () => {
  const { listeners, wait } = hlsWait({ readyState: 'complete' });
  await wait();
  assert.equal(listeners.length, 0);
});

test('waitForHlsLibrary waits for the load event while parsing is over but the library is not', async () => {
  const { listeners, wait } = hlsWait({ readyState: 'interactive' });
  let settled = false;
  const pending = wait().then(() => { settled = true; });
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(settled, false);
  assert.equal(listeners.length, 1);
  assert.equal(listeners[0].name, 'load');
  listeners[0].handler();
  await pending;
  assert.equal(settled, true);
});
