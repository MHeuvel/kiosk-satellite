import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
import { catalogs } from '../remote-ui/static/catalogs.js';
import { deviceOperationError, deviceText, setLanguagePreference } from '../remote-ui/static/localization.js';

const read = path => JSON.parse(readFileSync(new URL(path, import.meta.url), 'utf8'));
const certificateIds = Object.keys(read('../l10n/source/settings_device_tls_en.arb')).filter(key => !key.startsWith('@'));
const featureIds = {
  settings_intercom_general: ['settingIntercomTlsTitle', 'settingIntercomTlsDescription'],
  intercom_errors: ['intercomEncryptionMismatch', 'intercomEncryptionMismatchHelp'],
  settings_camera_streaming: ['settingCameraRtspAuthDescription', 'settingCameraRtspTlsTitle', 'settingCameraRtspTlsDescription'],
  settings_intercom_kiosks: ['intercomRosterHelp'],
  settings_device_remote_administration: ['settingRemoteTlsTitle', 'settingRemoteTlsDescription'],
  settings_device_tls: certificateIds,
};

for (const locale of ['de', 'es', 'fr']) {
  test(`TLS messages ship the translations from the pinned ${locale} snapshot`, () => {
    for (const [bundle, ids] of Object.entries(featureIds)) {
      const translated = read(`../l10n/vendor/translations/${locale}/${bundle}_${locale}.arb`);
      for (const id of ids) {
        assert.ok(translated[id], `${locale}: missing ${id}`);
        assert.equal(catalogs[locale][id], translated[id], `${locale}: stale ${id}`);
        if (id !== 'tlsTLS') assert.notEqual(catalogs[locale][id], catalogs.en[id], `${locale}: English fallback for ${id}`);
      }
    }
  });

  test(`TLS actions and wrapped certificate failures resolve in ${locale}`, () => {
    setLanguagePreference(locale);
    assert.equal(deviceText('Replace'), catalogs[locale].tlsReplace);
    assert.equal(deviceText('Certificate Management'), catalogs[locale].tlsCertificateManagement);
    const message = 'Certificate and private key do not match.';
    assert.equal(deviceOperationError(`Bad state: ${message}`), catalogs[locale].tlsKeyMismatch);
    assert.equal(deviceOperationError(`PlatformException(tls, ${message}, null, null)`),
      `PlatformException(tls, ${catalogs[locale].tlsKeyMismatch}, null, null)`);
    assert.equal(deviceOperationError('unknown diagnostic'), 'unknown diagnostic');
  });
}
