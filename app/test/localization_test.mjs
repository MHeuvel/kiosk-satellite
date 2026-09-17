import assert from 'node:assert/strict';
import test, { beforeEach } from 'node:test';
import { readFileSync, readdirSync } from 'node:fs';
import { catalogs } from '../remote-ui/static/catalogs.js';
import { formatMessage, localizeSetting, setLanguagePreference, t } from '../remote-ui/static/localization.js';

beforeEach(() => setLanguagePreference('en'));

test('browser English catalog matches the current source', () => {
  const directory = new URL('../l10n/source/', import.meta.url);
  const source = {};
  for (const name of readdirSync(directory).filter(name => name.endsWith('_en.arb'))) {
    const bundle = JSON.parse(readFileSync(new URL(name, directory), 'utf8'));
    for (const [key, value] of Object.entries(bundle).filter(([key]) => !key.startsWith('@'))) {
      assert.equal(Object.hasOwn(source, key), false, `Duplicate message: ${key}`);
      source[key] = value;
    }
  }
  assert.ok(Object.keys(source).length > 0);
  assert.deepEqual(catalogs.en, source);
});

test('English is the default and replaces the old automatic choice', () => {
  assert.equal(t('commonNext'), 'Next');
  setLanguagePreference('es');
  assert.equal(t('commonNext'), 'Siguiente');
  setLanguagePreference('system');
  assert.equal(t('commonNext'), 'Next');
  setLanguagePreference(undefined);
  assert.equal(t('commonNext'), 'Next');
});

test('placeholder values stay plain text and are not substituted twice', () => {
  assert.equal(formatMessage('Response: {error}', { error: '<img src=x> {error}' }), 'Response: <img src=x> {error}');
  assert.throws(() => formatMessage('Response: {error}'), /Missing message placeholder/);
  assert.equal(t('setupUnexpectedResponse', { error: 'HTTP 503' }), 'Unexpected response (HTTP 503)');
});

test('setting localization preserves keys and values without changing the input', () => {
  const setting = { key: 'ha.url', value: 'https://example.test', title: 'Original', description: 'Original help', titleMessageId: 'settingHaUrlTitle' };
  const localized = localizeSetting(setting);
  assert.equal(localized.title, 'Home Assistant base URL');
  assert.equal(localized.englishTitle, 'Original');
  assert.equal(localized.key, setting.key);
  assert.equal(localized.value, setting.value);
  assert.equal(setting.title, 'Original');
  assert.deepEqual(localizeSetting(localized), localized);
});

test('explicit kiosk language overrides the browser while keeping native names', () => {
  setLanguagePreference('es');
  const setting = { key: 'ui.language', value: 'es', title: 'Language',
    options: ['en', 'es'], optionLabels: { en: 'English', es: 'Español' } };
  const localized = localizeSetting(setting);
  assert.deepEqual(localized.options, setting.options);
  assert.equal(localized.optionLabels.es, 'Español');
  assert.equal(localized.value, 'es');
  assert.equal(t('commonNext'), 'Siguiente');
  setLanguagePreference('en');
  assert.equal(t('commonNext'), 'Next');
  setLanguagePreference('unavailable');
  assert.equal(t('commonNext'), 'Next');
});

test('changing language translates cached settings again without losing English aliases', () => {
  const original = { title: 'Device name', titleMessageId: 'settingDeviceNameTitle', value: 'Kitchen' };
  setLanguagePreference('es');
  const spanish = localizeSetting(original);
  assert.equal(spanish.title, 'Nombre del dispositivo');
  setLanguagePreference('en');
  const english = localizeSetting(spanish);
  assert.equal(english.title, 'Device name');
  assert.equal(english.englishTitle, 'Device name');
  assert.equal(english.value, 'Kitchen');
});
