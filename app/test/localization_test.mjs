import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync, readdirSync } from 'node:fs';
import { catalogs } from '../remote-ui/static/catalogs.js';
import { formatMessage, localizeSetting, resolveLanguage, t } from '../remote-ui/static/localization.js';

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

test('browser locale selects an available language or English', () => {
  assert.equal(resolveLanguage(['es-EC', 'en'], ['en', 'es']), 'es');
  assert.equal(resolveLanguage(['de-DE'], ['en', 'es']), 'en');
  assert.equal(resolveLanguage(['zh-Hans'], ['en', 'zh-Hant']), 'en');
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
