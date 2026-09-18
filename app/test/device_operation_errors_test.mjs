import assert from 'node:assert/strict';
import test from 'node:test';
import {deviceOperationError, setLanguagePreference, t} from '../remote-ui/static/localization.js';

for (const language of ['en', 'es']) {
  test(`device errors preserve parameters and unknown diagnostics in ${language}`, () => {
    setLanguagePreference(language);
    const cases = [
      ['the device admin permission is not active', t('deviceAdminInactive')],
      ['restart is Android-only', t('deviceRestartAndroidOnly')],
      ['Shizuku refused the restart', t('deviceRestartShizukuRefused')],
      ['restart failed: E_VENDOR <raw>', t('deviceRestartFailed', {error:'E_VENDOR <raw>'})],
      ['restart failed: Shizuku refused the restart', t('deviceRestartFailed', {error:t('deviceRestartShizukuRefused')})],
      ['a download is already running', t('updateDownloadBusy')],
      ['Bad state: The file is not an Android APK.', t('updateInvalidApk')],
      ['Not enough free space: the APK is 132.6 MB and the install needs about 365.2 MB, but the device has 90.1 MB free.', t('updateUploadSpace', {size:'132.6',required:'365.2',free:'90.1'})],
      ['The upload was interrupted after 3.2 MB: ECONNRESET <raw>', t('updateUploadInterrupted', {size:'3.2',error:'ECONNRESET <raw>'})],
      ['The upload ended early: 2.1 of 4.7 MB arrived.', t('updateUploadEarly', {received:'2.1',expected:'4.7'})],
      ['The APK is com.example.app, not Kiosk Satellite (me.jxl.kiosk_satellite).', t('updateWrongPackage', {package:'com.example.app',expected:'me.jxl.kiosk_satellite'})],
      ['The APK is another package, not Kiosk Satellite (me.jxl.kiosk_satellite).', t('updateWrongPackage', {package:t('updateAnotherPackage'),expected:'me.jxl.kiosk_satellite'})],
      ['The APK is version 1.2.3-beta (build 7), older than the running 2.3.4 (build 8). Downgrades are refused: Android would not install one either.', t('updateOlderBuild', {version:'1.2.3-beta',build:'7',currentVersion:'2.3.4',currentBuild:'8'})],
      ['Download failed (HTTP 503).', t('updateDownloadHttpFailed', {status:'503'})],
      ['Update failed: The download stalled: no data arrived for 30 seconds.', t('deviceUpdateFailedDetail', {error:t('updateDownloadStalled', {seconds:'30'})})],
      ['PlatformException(shizuku_error, Grant Shizuku access first, null, null)', `PlatformException(shizuku_error, ${t('shizukuGrantFirst')}, null, null)`],
      ['Install failed: Bad state: The uploaded APK is gone. Upload it again.', t('deviceInstallFailedDetail', {error:t('updateUploadedGone')})],
      ['Device disconnected', t('deviceDisconnectedError')],
      ['Device response timed out', t('deviceResponseTimedOut')],
    ];
    for (const [raw, expected] of cases) assert.equal(deviceOperationError(raw), expected, raw);
    for (const raw of ['Bad state: vendor failure', 'PlatformException(code, vendor <detail>, {errno: 32}, null)', 'com.example.SomeError: /data/a.apk']) {
      assert.equal(deviceOperationError(raw), raw);
      assert.equal(deviceOperationError('Install failed: '+raw), t('deviceInstallFailedDetail', {error:raw}));
    }
  });
}
