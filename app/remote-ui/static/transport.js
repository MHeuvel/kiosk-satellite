// One connection carries concurrent requests. A lost response must never
// replay a command that might already have changed the device.
let socket = null;
let nextId = 1;
const pending = new Map();
export function socketReady() { return socket?.readyState === 1; }
export function attachSocket(value) {
  detachSocket();
  socket = value;
}
export function detachSocket(value = socket) {
  if (value !== socket) return;
  socket = null;
  for (const request of pending.values()) request.reject(new Error('Device disconnected'));
  pending.clear();
}
export function receiveResult(message) {
  if (message.type !== 'result') return false;
  pending.get(message.id)?.resolve(message);
  return true;
}
export function socketRequest(message, { signal, timeoutMs = 30000 } = {}) {
  if (!socketReady()) return Promise.reject(new Error('Device disconnected'));
  return new Promise((resolve, reject) => {
    const id = nextId++;
    let timer;
    const finish = (callback, value) => {
      pending.delete(id);
      clearTimeout(timer);
      signal?.removeEventListener('abort', abort);
      callback(value);
    };
    const abort = () => finish(reject, new DOMException('Request aborted', 'AbortError'));
    if (signal?.aborted) { abort(); return; }
    signal?.addEventListener('abort', abort, { once: true });
    // A caller with an AbortSignal owns its deadline (APK installs and
    // permission operations can legitimately take more than 30 seconds).
    if (!signal && timeoutMs > 0) timer = setTimeout(() =>
      finish(reject, new Error('Device response timed out')), timeoutMs);
    pending.set(id, {
      resolve: value => finish(resolve, value),
      reject: error => finish(reject, error),
    });
    try { socket.send(JSON.stringify({ ...message, id })); }
    catch (error) { finish(reject, error); }
  });
}
