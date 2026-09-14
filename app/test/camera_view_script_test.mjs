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
