import assert from 'node:assert/strict';
import test from 'node:test';
import {pluginError, launcherError, setLanguagePreference, t} from '../remote-ui/static/localization.js';
for (const language of ['en', 'es']) {
  test(`owned errors preserve diagnostic data in ${language}`, () => {
    setLanguagePreference(language);
    assert.equal(pluginError('Bad state: GitHub denied the request or its request limit was reached. Try again later.'), t('pluginErrorGithubLimited'));
    assert.equal(pluginError('FormatException: Release asset original-1.2.zip must be published by GitHub Actions. Manually uploaded files are not supported.'), t('pluginErrorAssetPublisher', {name:'original-1.2.zip'}));
    assert.equal(pluginError('GitHub request failed (503)'), t('pluginErrorGithubRequest', {status:'503'}));
    assert.equal(pluginError('Invalid entryClass'), t('pluginErrorInvalidField', {field:'entryClass'}));
    assert.equal(pluginError('PlatformException(plugin_error, Plugin needs Android API 35, null, null)'), `PlatformException(plugin_error, ${t('pluginErrorAndroidApi', {version:'35'})}, null, null)`);
    assert.equal(pluginError('Unexpected or duplicate ZIP entry: <original>.jar'), t('pluginErrorZipEntry', {name:'<original>.jar'}));
    assert.equal(pluginError('Plugin update failed: E_VENDOR. The previous version was retained.'), t('pluginErrorUpdateFailed', {error:'E_VENDOR', recovery:t('pluginErrorVersionRetained')}));
    assert.equal(launcherError('Error: could not list apps: E_VENDOR <details>'), t('launcherErrorListDetail', {error:'E_VENDOR <details>'}));
    for (const raw of ['Bad state: Community plugin failure', 'Invalid arbitrary content', 'PlatformException(code, original details, {errno: 32}, null)', '<b>Original value</b>']) {
      assert.equal(pluginError(raw), raw);
      assert.equal(launcherError(raw), raw);
    }
  });
}
