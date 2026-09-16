import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const dart = readFileSync(new URL('../lib/managers/js_api/remote_settings_script.dart', import.meta.url), 'utf8');
const script = dart.split("r'''")[1].split("'''")[0];

test('browser setting writes keep storage behavior and publish one change per batch', async () => {
  const calls = [];
  const context = vm.createContext({ call: name => calls.push(name) });
  vm.runInContext(`
    class Storage {
      constructor() { this.values = new Map(); }
      setItem(key, value) { this.values.set(key, String(value)); }
      removeItem(key) { this.values.delete(key); }
      clear() { this.values.clear(); }
      getItem(key) { return this.values.get(key) ?? null; }
    }
    const window = { localStorage: new Storage() };
    const sessionStorage = new Storage();
    ${script}
    window.localStorage.setItem('vs-theme', 'dark');
    window.localStorage.setItem('vs-font', 'large');
    sessionStorage.setItem('vs-theme', 'light');
    window.localStorage.setItem('unrelated', 'value');
  `, context);
  await Promise.resolve();
  assert.deepEqual(calls, ['remoteSettingsChanged']);
  assert.equal(vm.runInContext("window.localStorage.getItem('vs-theme')", context), 'dark');
  vm.runInContext("window.localStorage.removeItem('vs-theme')", context);
  await Promise.resolve();
  assert.equal(calls.length, 2);
  assert.equal(vm.runInContext("window.localStorage.getItem('vs-theme')", context), null);
});
