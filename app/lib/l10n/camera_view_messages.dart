import 'generated/ui_strings.dart';

/// Patterns sent to the camera WebView. Runtime values stay in JavaScript.
Map<String, String> cameraViewMessages(UiStrings strings) => {
  'cameraViewerTitle': strings.cameraViewerTitle,
  'cameraViewerConnecting': strings.cameraViewerConnecting,
  'cameraViewerReconnecting': strings.cameraViewerReconnecting,
  'cameraViewerTrying': strings.cameraViewerTrying('{transport}'),
  'cameraViewerCannotDecode': strings.cameraViewerCannotDecode('{codec}'),
  'cameraViewerCannotPlay': strings.cameraViewerCannotPlay('{transport}'),
  'cameraViewerCannotDecodeStream': strings.cameraViewerCannotDecodeStream,
  'cameraViewerHaRetry': strings.cameraViewerHaRetry('{seconds}'),
  'cameraViewerServerRetry': strings.cameraViewerServerRetry('{seconds}'),
  'cameraViewerConnectionRetry': strings.cameraViewerConnectionRetry(
    '{seconds}',
  ),
  'cameraViewerStartRetry': strings.cameraViewerStartRetry,
  'cameraViewerStartDelayedRetry': strings.cameraViewerStartDelayedRetry(
    '{seconds}',
  ),
  'cameraViewerMissingRetry': strings.cameraViewerMissingRetry('{seconds}'),
  'cameraViewerLoginRetry': strings.cameraViewerLoginRetry('{seconds}'),
  'cameraViewerMissing': strings.cameraViewerMissing,
};
