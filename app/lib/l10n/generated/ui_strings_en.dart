// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'ui_strings.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class UiStringsEn extends UiStrings {
  UiStringsEn([String locale = 'en']) : super(locale);

  @override
  String get cameraViewerTitle => 'Camera view';

  @override
  String get cameraViewerConnecting => 'Connecting...';

  @override
  String get cameraViewerReconnecting => 'Reconnecting...';

  @override
  String cameraViewerTrying(String transport) {
    return 'Trying $transport...';
  }

  @override
  String cameraViewerCannotDecode(String codec) {
    return 'This device cannot decode $codec';
  }

  @override
  String cameraViewerCannotPlay(String transport) {
    return 'This device cannot play $transport streams';
  }

  @override
  String get cameraViewerCannotDecodeStream =>
      'This device cannot decode this stream';

  @override
  String cameraViewerHaRetry(String seconds) {
    return 'Cannot reach Home Assistant. Retrying in ${seconds}s';
  }

  @override
  String cameraViewerServerRetry(String seconds) {
    return 'Cannot reach the camera server. Retrying in ${seconds}s';
  }

  @override
  String cameraViewerConnectionRetry(String seconds) {
    return 'Connection failed. Retrying in ${seconds}s';
  }

  @override
  String get cameraViewerStartRetry =>
      'The camera server could not start this stream. Retrying...';

  @override
  String cameraViewerStartDelayedRetry(String seconds) {
    return 'The camera server could not start this stream. Retrying in ${seconds}s';
  }

  @override
  String cameraViewerMissingRetry(String seconds) {
    return 'Stream not found on the camera server. Retrying in ${seconds}s';
  }

  @override
  String cameraViewerLoginRetry(String seconds) {
    return 'The camera server rejected the login. Retrying in ${seconds}s';
  }

  @override
  String get cameraViewerMissing => 'Stream missing from Go2RTC';

  @override
  String get commonImport => 'Import';

  @override
  String get commonBack => 'Back';

  @override
  String get commonNext => 'Next';

  @override
  String get commonFinish => 'Finish';

  @override
  String get commonWorking => 'Working…';

  @override
  String get commonSettings => 'Settings';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonOk => 'OK';

  @override
  String get commonGrant => 'Grant';

  @override
  String get commonEnable => 'Enable';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonTest => 'Test';

  @override
  String get commonInstall => 'Install';

  @override
  String get commonSave => 'Save';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonClose => 'Close';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonBrowse => 'Browse';

  @override
  String get commonSet => 'Set';

  @override
  String get commonHour => 'Hour';

  @override
  String get commonMinute => 'Minute';

  @override
  String get commonUp => 'Up';

  @override
  String get commonDown => 'Down';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonSaveFailed => 'Could not save';

  @override
  String get commonColorWhite => 'White';

  @override
  String get commonColorWarm => 'Warm';

  @override
  String get commonColorAmber => 'Amber';

  @override
  String get commonColorRed => 'Red';

  @override
  String get commonColorGreen => 'Green';

  @override
  String get commonColorBlue => 'Blue';

  @override
  String get commonColorCyan => 'Cyan';

  @override
  String get commonColorDim => 'Dim';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonMoveUp => 'Move up';

  @override
  String get commonMoveDown => 'Move down';

  @override
  String get commonPreviousMonth => 'Previous month';

  @override
  String get commonNextMonth => 'Next month';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonChoose => 'Choose';

  @override
  String drawerPluginAction(String pluginName, String actionTitle) {
    return '$pluginName: $actionTitle';
  }

  @override
  String get drawerPluginActionErrorTitle => 'Plugin action';

  @override
  String get drawerPluginActionError => 'Could not run this action.';

  @override
  String get drawerDashboard => 'Dashboard';

  @override
  String get drawerHaKiosk => 'HA Kiosk Mode';

  @override
  String get drawerCameraView => 'Camera View';

  @override
  String get drawerIntercom => 'Intercom';

  @override
  String get drawerMusicAssistant => 'Music Assistant';

  @override
  String get drawerHidePlayer => 'Hide Floating Player';

  @override
  String get drawerShowPlayer => 'Show Floating Player';

  @override
  String get drawerNowPlaying => 'Now Playing';

  @override
  String get drawerScreensaver => 'Start Screensaver';

  @override
  String get drawerLockdown => 'Lockdown Mode';

  @override
  String get drawerHoldOff => 'Turn Off Hold Mode';

  @override
  String get drawerHoldOn => 'Turn On Hold Mode';

  @override
  String get drawerApps => 'Apps';

  @override
  String get drawerClearCache => 'Clear web cache';

  @override
  String get drawerRestartDevice => 'Restart Device';

  @override
  String get drawerRestartConfirm =>
      'Restart this device? Kiosk Satellite comes back when it boots.';

  @override
  String get drawerRestart => 'Restart';

  @override
  String get drawerExitApplication => 'Exit Application';

  @override
  String get drawerExitConfirm => 'Close Kiosk Satellite?';

  @override
  String get drawerExit => 'Exit';

  @override
  String get drawerHoldActive => 'Hold mode is on';

  @override
  String get drawerHoldHelp =>
      'Screensaver and timers are paused · tap to turn off';

  @override
  String get drawerThemeDark => 'Dark';

  @override
  String get drawerThemeLight => 'Light';

  @override
  String get drawerThemeAndroid => 'Follow Android';

  @override
  String drawerVersion(String version) {
    return 'Version $version';
  }

  @override
  String get drawerUpdateAvailable => 'Update available';

  @override
  String drawerUpdateInstall(String version) {
    return 'Version $version · tap to install';
  }

  @override
  String get drawerUpdateChecking => 'Checking for updates…';

  @override
  String get drawerUpdateCurrent => 'Up to date';

  @override
  String get drawerUpdateCurrentHelp => 'You are on the latest version.';

  @override
  String get drawerUpdateCheckFailed => 'Update check failed';

  @override
  String get drawerUpdateOffline => 'Is the device online?';

  @override
  String drawerUpdateTo(String version) {
    return 'Update to $version';
  }

  @override
  String get drawerUpdateInstructions =>
      'The download starts on Update. Android asks you to confirm the installation.';

  @override
  String get drawerUpdateRelaunch =>
      'Without the \"Display over other apps\" permission the app cannot reopen itself after updating.';

  @override
  String get drawerUpdate => 'Update';

  @override
  String get drawerUpdateDownloading => 'Downloading update';

  @override
  String get drawerUpdateStarting => 'Starting…';

  @override
  String get drawerUpdateFailed => 'Update failed';

  @override
  String get drawerUpdates => 'Updates';

  @override
  String get drawerNoReleaseNotes => 'No release notes.';

  @override
  String get settingCameraEnabledTitle => 'Enable camera';

  @override
  String get settingCameraEnabledDescription =>
      'Camera use adds CPU load and heat, which can shorten the battery and device lifespan.';

  @override
  String get settingCameraDeviceTitle => 'Camera';

  @override
  String get settingCameraDeviceDescription => 'Which camera to use.';

  @override
  String get settingCameraSnapshotResolutionTitle => 'Snapshot resolution';

  @override
  String get settingCameraSnapshotResolutionDescription =>
      'Higher looks sharper but costs more CPU and bandwidth.';

  @override
  String get settingCameraDisableDetectionSnapshotsTitle =>
      'Disable snapshots on detection';

  @override
  String get settingCameraDisableDetectionSnapshotsDescription =>
      'Prevent automatic snapshots triggered by detection. Motion, face, presence and gesture detection keep working. Manual requests and Continuous snapshots can still capture images.';

  @override
  String get settingCameraSnapshotsTitle => 'Continuous snapshots';

  @override
  String get settingCameraSnapshotsDescription =>
      'Publish a fresh camera snapshot to Home Assistant at a fixed interval.';

  @override
  String get settingCameraSnapshotIntervalTitle => 'Snapshot interval';

  @override
  String get settingCameraSnapshotIntervalDescription =>
      'Seconds between snapshots.';

  @override
  String get cameraFront => 'Front';

  @override
  String get cameraBack => 'Back';

  @override
  String get cameraOnlyCamera => 'The only camera this device has.';

  @override
  String get settingMotionSensorTitle => 'Motion sensor';

  @override
  String get settingMotionSensorDescription =>
      'Expose motion as a Home Assistant sensor. WARNING: Keeps the camera running permanently, even with the screen off.';

  @override
  String get settingMotionSensorOffDelayTitle => 'Clear after';

  @override
  String get settingMotionSensorOffDelayDescription =>
      'Seconds without motion before the sensor reads clear.';

  @override
  String get settingMotionFpsTitle => 'Motion frame rate';

  @override
  String get settingMotionFpsDescription =>
      'Frames per second the camera checks for motion. Lower is lighter on the CPU; 2 is plenty to notice someone approaching.';

  @override
  String get settingMotionStartDelayTitle => 'Startup delay';

  @override
  String get settingMotionStartDelayDescription =>
      'Ignore motion for this long after the camera starts, for devices whose camera physically moves as it opens.';

  @override
  String get settingMotionSensitivityTitle => 'Motion sensitivity';

  @override
  String get settingMotionSensitivityDescription =>
      'Higher trips on smaller movements. 1 needs a large change across the frame; 100 reacts to the slightest motion.';

  @override
  String get cameraMotionPage => 'Motion Sensor';

  @override
  String get cameraMotionHint =>
      'Home Assistant motion sensor and shared detection settings';

  @override
  String get cameraNoCamera => 'No camera detected';

  @override
  String get cameraNoCameraHelp =>
      'This device does not report any usable camera.';

  @override
  String get cameraCameraPermission => 'Camera permission missing';

  @override
  String get cameraCameraPermissionHelp =>
      'Without it the camera cannot be used. The grant dialog appears on the tablet screen.';

  @override
  String get cameraGrantOnDevice => 'Grant on device';

  @override
  String get cameraCameraBlocked =>
      'Blocked. Android will not ask again, so allow it in the app settings.';

  @override
  String get cameraCameraNeeded => 'Without this the camera cannot be used.';

  @override
  String get cameraAppSettings => 'App settings';

  @override
  String get cameraLatest => 'Latest snapshot';

  @override
  String get cameraNoSnapshot => 'No snapshot yet.';

  @override
  String get cameraImageAlt => 'Latest camera snapshot';

  @override
  String get cameraTakeSnapshot => 'Take snapshot';

  @override
  String get cameraSnapshotFailed => 'Snapshot failed.';

  @override
  String cameraSnapshotError(String error) {
    return 'Snapshot failed: $error';
  }

  @override
  String get cameraCameraDisabled =>
      'The camera is disabled in the Camera settings.';

  @override
  String get cameraSnapshotBusy => 'A snapshot is already in progress.';

  @override
  String get cameraPermissionDenied => 'Camera permission not granted.';

  @override
  String get cameraDetectionDisabled => 'Detection snapshots are disabled.';

  @override
  String get cameraNoImage => 'The camera returned no image.';

  @override
  String get cameraTimedOut => 'The camera did not answer in time.';

  @override
  String get cameraBackground =>
      'The camera is unavailable while the app is in the background.';

  @override
  String get cameraJustNow => 'just now';

  @override
  String cameraSecondsAgo(String count) {
    return '$count seconds ago';
  }

  @override
  String get cameraMinuteAgo => '1 minute ago';

  @override
  String cameraMinutesAgo(String count) {
    return '$count minutes ago';
  }

  @override
  String get cameraHourAgo => '1 hour ago';

  @override
  String cameraHoursAgo(String count) {
    return '$count hours ago';
  }

  @override
  String get cameraDayAgo => '1 day ago';

  @override
  String cameraDaysAgo(String count) {
    return '$count days ago';
  }

  @override
  String get cameraStatusHeading => 'Stream Status';

  @override
  String get cameraClientsHeading => 'Connected Clients';

  @override
  String get cameraUnavailable => 'Unavailable';

  @override
  String get cameraStopped => 'Stopped';

  @override
  String get cameraStreaming => 'Streaming';

  @override
  String get cameraIdle => 'Idle';

  @override
  String get cameraConnected => 'Connected';

  @override
  String get cameraChecking => 'Checking...';

  @override
  String get cameraCheckingStatus => 'Checking stream status...';

  @override
  String get cameraStatusUnavailable => 'Stream status unavailable.';

  @override
  String get cameraListenerStopped => 'Listener is stopped.';

  @override
  String cameraViewer(String count, String resolution) {
    return '$count connected viewer. Actual video: $resolution.';
  }

  @override
  String cameraViewers(String count, String resolution) {
    return '$count connected viewers. Actual video: $resolution.';
  }

  @override
  String get cameraReady => 'Ready. The encoder starts when a viewer connects.';

  @override
  String cameraFallback(String requested, String actual) {
    return 'Requested $requested, camera supplied $actual.';
  }

  @override
  String cameraAudioError(String error) {
    return 'Audio: $error';
  }

  @override
  String get cameraAudioPaused =>
      'Audio paused while the browser uses the microphone.';

  @override
  String get cameraAudioStreaming => 'Microphone audio streaming.';

  @override
  String get cameraAudioIdle => 'Microphone audio idle.';

  @override
  String cameraDiscoveryError(String error) {
    return 'ONVIF discovery: $error';
  }

  @override
  String get cameraOnvifUrl => 'ONVIF URL';

  @override
  String get cameraStreamUrl => 'Stream URL';

  @override
  String get cameraWaitingAddress => 'Waiting for a network address';

  @override
  String get cameraClientsUnavailable => 'Client information unavailable.';

  @override
  String get cameraNoClients => 'No connected clients.';

  @override
  String cameraClientDetails(String status, String transport, String port) {
    return '$status · $transport · Port $port';
  }

  @override
  String cameraConnectedFor(String duration) {
    return 'Connected for $duration';
  }

  @override
  String cameraDurationSeconds(String seconds) {
    return '${seconds}s';
  }

  @override
  String cameraDurationMinutes(String minutes, String seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String cameraDurationHours(String hours, String minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String get cameraCredentialsMissing =>
      'Set a streaming username and password to enable authentication.';

  @override
  String get cameraPortWaiting => 'Waiting for the RTSP port to be released.';

  @override
  String get cameraListenerFailed => 'Could not start the RTSP listener.';

  @override
  String get settingCameraRtspEnabledTitle => 'Enable camera streaming';

  @override
  String get settingCameraRtspEnabledDescription =>
      'Share H.264 video with RTSP or ONVIF clients. Video encoding runs only while a viewer is connected. Hardware encoding is preferred with software fallback when needed. Uses the camera selected in Camera settings.';

  @override
  String get settingCameraStreamingProtocolTitle => 'Streaming protocol';

  @override
  String get settingCameraStreamingProtocolDescription =>
      'ONVIF lets compatible clients discover the camera and connect to its stream.';

  @override
  String get settingCameraRtspPortTitle => 'Port';

  @override
  String get settingCameraRtspPortDescription => 'RTSP server port.';

  @override
  String get settingCameraOnvifPortTitle => 'Port';

  @override
  String get settingCameraOnvifPortDescription => 'ONVIF server port.';

  @override
  String get settingCameraRtspResolutionTitle => 'Resolution';

  @override
  String get settingCameraRtspResolutionDescription =>
      'Supported streaming sizes for the selected camera and encoder. Video follows the device orientation.';

  @override
  String get settingCameraRtspAnalysisTitle =>
      'Motion analysis while streaming';

  @override
  String get settingCameraRtspAnalysisDescription =>
      'Keep motion detection, face detection and hand gestures available while viewers are connected. Turning this off can allow higher resolutions. Snapshots then use video frames at the streaming resolution.';

  @override
  String get settingCameraRtspFpsTitle => 'Frame rate';

  @override
  String get settingCameraRtspFpsDescription =>
      'Target video frames per second. Motion keeps its separate analysis rate. Actual delivery depends on the camera.';

  @override
  String get settingCameraRtspBitrateTitle => 'Bitrate';

  @override
  String get settingCameraRtspBitrateDescription =>
      'Target video bitrate. Higher improves detail and uses more network bandwidth.';

  @override
  String get settingCameraRtspAudioTitle => 'Include microphone audio';

  @override
  String get settingCameraRtspAudioDescription =>
      'Include microphone audio in the camera stream. Shares your microphone settings. WARNING: Increased CPU usage.';

  @override
  String get settingCameraRtspAuthTitle => 'Require authentication';

  @override
  String get settingCameraRtspAuthDescription =>
      'Require a username and password to view the stream. Streaming traffic is not encrypted.';

  @override
  String get settingCameraRtspUsernameTitle => 'Username';

  @override
  String get settingCameraRtspUsernameDescription =>
      'Username for streaming clients.';

  @override
  String get settingCameraRtspPasswordTitle => 'Password';

  @override
  String get settingCameraRtspPasswordDescription =>
      'Set a password to start the authenticated stream.';

  @override
  String get cameraStreamingPage => 'RTSP & ONVIF Streaming';

  @override
  String get cameraStreamingHint => 'Share the device camera via RTSP or ONVIF';

  @override
  String get cameraPortError => 'Enter a whole port number from 1024 to 65535.';

  @override
  String get cameraUsernameError =>
      'Use 1 to 64 characters without spaces, quotes, colons or backslashes.';

  @override
  String get cameraNoSizes => 'No supported sizes available';

  @override
  String get cameraNoSizesHelp =>
      'No supported sizes available. Check the camera connection.';

  @override
  String get cameraResolutionSupport => 'Resolution support';

  @override
  String get cameraCheckingSizes =>
      'Checking camera and H.264 encoder support...';

  @override
  String get cameraSupportedSizes =>
      'Only sizes supported by the camera and H.264 encoder at the current streaming settings are listed.';

  @override
  String cameraExtraSizes(String sizes) {
    return 'Turn off Motion analysis while streaming to also use $sizes.';
  }

  @override
  String get cameraAnalysisOff =>
      'Motion detection, face detection and hand gestures pause while viewers are connected. Snapshots use video frames at the streaming resolution.';

  @override
  String cameraRejectedSizes(String sizes) {
    return 'The encoder cannot use $sizes at these settings.';
  }

  @override
  String cameraRejectedCount(String count) {
    return '$count camera sizes are excluded because the encoder cannot use them at these settings.';
  }

  @override
  String get cameraCaptureRejected =>
      'Other camera sizes are unavailable in the current capture setup.';

  @override
  String get cameraStreamsNameRequired => 'name required';

  @override
  String get cameraStreamsBaseUrlRequired =>
      'valid HTTP or HTTPS baseUrl required';

  @override
  String get cameraStreamsServerNotFound => 'server not found';

  @override
  String get cameraStreamsInvalidStreamList =>
      'Go2RTC returned an invalid stream list';

  @override
  String get cameraStreamsKindRequired => 'kind must be go2rtc, whep or ha';

  @override
  String get cameraStreamsProtocolRequired =>
      'preferredProtocol must be auto, webrtc, hls or mjpeg';

  @override
  String get cameraStreamsServerRequired => 'valid serverId required';

  @override
  String get cameraStreamsStreamRequired => 'streamName required';

  @override
  String get cameraStreamsEntityRequired => 'a camera.* entityId is required';

  @override
  String get cameraStreamsWhepRequired => 'valid WHEP URL required';

  @override
  String get cameraStreamsCameraNotFound => 'camera not found';

  @override
  String get cameraStreamsListRequired => 'cameraIds must be a list';

  @override
  String get cameraStreamsViewCount => 'a view must contain 1 to 12 cameras';

  @override
  String get cameraStreamsRepeatedCamera =>
      'a camera can appear only once per view';

  @override
  String get cameraStreamsUnknownViewCamera =>
      'view contains an unknown camera';

  @override
  String get cameraStreamsUniqueViewName => 'view name must be unique';

  @override
  String get cameraStreamsGridRange => 'grid must be between 1 and 12';

  @override
  String get cameraStreamsGridTooSmall =>
      'grid is smaller than the camera count';

  @override
  String get cameraStreamsViewNotFound => 'view not found';

  @override
  String get cameraStreamsDefaultViewDelete =>
      'the default view cannot be deleted; empty it instead';

  @override
  String get cameraStreamsViewEmpty => 'view has no cameras';

  @override
  String cameraStreamsHaReadFailed(String error) {
    return 'could not read Home Assistant: $error';
  }

  @override
  String cameraStreamsConnectFailed(String server, String error) {
    return 'could not connect to $server: $error';
  }

  @override
  String get cameraStreamsHaUnavailable =>
      'Home Assistant is not configured or unreachable';

  @override
  String cameraStreamsHttpError(String status) {
    return 'Go2RTC returned HTTP $status';
  }

  @override
  String get cameraStreamsImportHa => 'Import cameras from Home Assistant';

  @override
  String get cameraStreamsImportHaHelp =>
      'Add every camera of the connected Home Assistant, playing over WebRTC, HLS or MJPEG. Importing again merges new cameras.';

  @override
  String get cameraStreamsImportFailed => 'Import failed';

  @override
  String get cameraStreamsImportComplete => 'Import complete';

  @override
  String cameraStreamsImportCounts(String added, String missing) {
    return '$added added, $missing missing.';
  }

  @override
  String get settingCameraAllowH265Title => 'Allow H.265 streams';

  @override
  String get settingCameraAllowH265Description =>
      'Play H.265 camera streams as they are. A device that cannot decode H.265 shows a blank image instead.';

  @override
  String get settingCameraPreferMseTitle => 'Prefer MSE over WebRTC';

  @override
  String get settingCameraPreferMseDescription =>
      'Stream Go2RTC cameras over MSE first. For devices that cannot play WebRTC; adds a second or two of delay.';

  @override
  String get settingCameraPreferHlsTitle => 'Prefer HLS over WebRTC';

  @override
  String get settingCameraPreferHlsDescription =>
      'Stream Home Assistant cameras over HLS first. For devices that cannot play WebRTC; adds a few seconds of delay.';

  @override
  String get settingCameraSingleAudioTitle => 'Play sound for a single camera';

  @override
  String get settingCameraSingleAudioDescription =>
      'Play the camera\'s sound when only one camera is on screen. Grids with several cameras stay silent.';

  @override
  String get settingCameraPinchZoomTitle => 'Pinch to zoom a single camera';

  @override
  String get settingCameraPinchZoomDescription =>
      'Zoom into the picture with two fingers when only one camera is on screen. Drag to move around, double-tap to reset.';

  @override
  String get settingCameraAutoDismissSecondsTitle => 'Auto-dismiss after';

  @override
  String get settingCameraAutoDismissSecondsDescription =>
      'Close an opened camera view on its own; 0 keeps it up. The camera screensaver is unaffected.';

  @override
  String get cameraStreamsPlayback => 'Playback';

  @override
  String get cameraStreamsOff => 'Off';

  @override
  String cameraStreamsSeconds(String seconds) {
    return '$seconds s';
  }

  @override
  String get cameraStreamsGridHelp =>
      'Grids with several cameras are video-only. For low-power devices, use lower resolution Go2RTC streams in views and optionally set a separate fullscreen stream.';

  @override
  String get cameraStreamsServers => 'Go2RTC servers';

  @override
  String get cameraStreamsImportStreams => 'Import streams';

  @override
  String get cameraStreamsDeleteServer => 'Delete server';

  @override
  String get cameraStreamsAddServer => 'Add Go2RTC server';

  @override
  String get cameraStreamsAddServerHelp =>
      'Connect to a server and import its streams.';

  @override
  String get cameraStreamsEditServer => 'Edit server';

  @override
  String get cameraStreamsName => 'Name';

  @override
  String get cameraStreamsBaseUrl => 'Base URL';

  @override
  String get cameraStreamsUsername => 'Username (optional)';

  @override
  String get cameraStreamsNewPassword => 'New password (leave blank to keep)';

  @override
  String get cameraStreamsPassword => 'Password (optional)';

  @override
  String get cameraStreamsInvalidCertificate => 'Allow invalid TLS certificate';

  @override
  String get cameraStreamsSaveServerFailed => 'Could not save the server';

  @override
  String get cameraStreamsDeleteServerHelp =>
      'Its cameras will be removed from every view.';

  @override
  String get cameraStreamsCameras => 'Cameras';

  @override
  String get cameraStreamsNoCameras => 'No cameras configured';

  @override
  String get cameraStreamsNoCamerasHelp =>
      'Import cameras from Home Assistant or Go2RTC, or add one manually.';

  @override
  String get cameraStreamsDeleteCamera => 'Delete camera';

  @override
  String get cameraStreamsAddManually => 'Add camera manually';

  @override
  String get cameraStreamsAddManuallyHelp =>
      'Use a Go2RTC stream name, a WHEP URL or a Home Assistant camera entity.';

  @override
  String get cameraStreamsUnknownCamera => 'Unknown camera';

  @override
  String get cameraStreamsUnknownServer => 'Unknown server';

  @override
  String get cameraStreamsMissing => ' (missing)';

  @override
  String get cameraStreamsAddCamera => 'Add camera';

  @override
  String get cameraStreamsEditCamera => 'Edit camera';

  @override
  String get cameraStreamsType => 'Type';

  @override
  String get cameraStreamsGo2RtcStream => 'Go2RTC stream';

  @override
  String get cameraStreamsDirectWhep => 'Direct WHEP URL';

  @override
  String get cameraStreamsHaCamera => 'Home Assistant camera';

  @override
  String get cameraStreamsEntity => 'Camera entity';

  @override
  String get cameraStreamsProtocol => 'Preferred protocol';

  @override
  String get cameraStreamsAuto => 'Auto';

  @override
  String get cameraStreamsServer => 'Server';

  @override
  String get cameraStreamsStreamName => 'Stream name';

  @override
  String get cameraStreamsGo2RtcStreamName => 'Go2RTC stream name';

  @override
  String get cameraStreamsFullscreen => 'Fullscreen stream (optional)';

  @override
  String get cameraStreamsWhep => 'WHEP URL';

  @override
  String get cameraStreamsSaveCameraFailed => 'Could not save the camera';

  @override
  String get cameraStreamsDeleteCameraHelp =>
      'It will be removed from every view.';

  @override
  String get cameraStreamsLoadFailed => 'Could not load cameras.';

  @override
  String get cameraStreamsViews => 'Views';

  @override
  String get cameraStreamsEmptyView => 'No cameras yet';

  @override
  String get cameraStreamsNamesShown => 'Names shown';

  @override
  String get cameraStreamsNamesHidden => 'Names hidden';

  @override
  String get cameraStreamsShowView => 'Show view';

  @override
  String get cameraStreamsDeleteView => 'Delete view';

  @override
  String get cameraStreamsCreateView => 'Create camera view';

  @override
  String get cameraStreamsAddFirst => 'Add a camera first.';

  @override
  String get cameraStreamsChooseCameras => 'Choose and order up to 12 cameras.';

  @override
  String get cameraStreamsShowFailed => 'Could not show the view';

  @override
  String get cameraStreamsShowFailedRemote => 'Could not show view';

  @override
  String get cameraStreamsEditView => 'Edit view';

  @override
  String get cameraStreamsShowNames => 'Show camera names';

  @override
  String get cameraStreamsShowNamesHelp => 'Display a label over each camera.';

  @override
  String get cameraStreamsGrid => 'Grid';

  @override
  String cameraStreamsOneCamera(String count) {
    return '$count Camera';
  }

  @override
  String cameraStreamsManyCameras(String count) {
    return '$count Cameras';
  }

  @override
  String get cameraStreamsInView => 'In this view';

  @override
  String get cameraStreamsAvailable => 'Available';

  @override
  String cameraStreamsPosition(String position) {
    return 'Position $position';
  }

  @override
  String get cameraStreamsMissingGo2Rtc => 'Missing from Go2RTC';

  @override
  String get cameraStreamsSaveViewFailed => 'Could not save the view';

  @override
  String cameraStreamsDeleteNamed(String name) {
    return 'Delete $name?';
  }

  @override
  String get cameraStreamsCannotUndo => 'This cannot be undone.';

  @override
  String get cameraStreamsShow => 'Show';

  @override
  String get cameraStreamsStop => 'Stop';

  @override
  String get settingAnalyticsBasicTitle => 'Basic analytics';

  @override
  String get settingAnalyticsBasicDescription =>
      'Information about your device, such as model, Android version, app version, screen size and language.';

  @override
  String get settingAnalyticsUsageTitle => 'Usage';

  @override
  String get settingAnalyticsUsageDescription =>
      'Details of what you use with Kiosk Satellite.';

  @override
  String get settingAnalyticsDiagnosticsTitle => 'Diagnostics';

  @override
  String get settingAnalyticsDiagnosticsDescription =>
      'Share crash reports when unexpected errors occur.';

  @override
  String get deviceAnalyticsPage => 'Kiosk Satellite Analytics';

  @override
  String get deviceAnalyticsIntro =>
      'Share anonymized information from your installation to help make Kiosk Satellite better and guide which devices and features get attention.';

  @override
  String get deviceAnalyticsLearn => 'Learn how we process your data';

  @override
  String get deviceAnalyticsLearnHelp =>
      'What Kiosk Satellite Analytics sends and what it never sends.';

  @override
  String get deviceExportConfig => 'Export configuration';

  @override
  String get deviceExportConfigHelp =>
      'Save every setting and the page\'s local storage to a file.';

  @override
  String get deviceExportConfigRemoteHelp =>
      'Download every setting and the page\'s local storage.';

  @override
  String get deviceImportConfig => 'Import configuration';

  @override
  String get deviceImportConfigHelp =>
      'Replace this device\'s settings from an exported file.';

  @override
  String get deviceExportFailed => 'Export failed';

  @override
  String get deviceExported => 'Configuration exported';

  @override
  String get deviceImportFailed => 'Import failed';

  @override
  String get deviceInvalidJson => 'That file is not valid JSON.';

  @override
  String get deviceImportComplete => 'Import complete';

  @override
  String deviceAppliedSettings(String count) {
    return 'Applied $count settings.';
  }

  @override
  String deviceAppliedReload(String count) {
    return 'Applied $count settings. The page may reload.';
  }

  @override
  String get deviceReplaceOriginal => 'Replace the original device';

  @override
  String get deviceReplaceQuestion =>
      'Replace this device\'s settings with the file\'s? The page may reload.';

  @override
  String get deviceNewDevice => 'Set up as new device';

  @override
  String get deviceReplaceIdentity =>
      'Keeps the backup\'s name and ESPHome identity; the original device must stay offline.';

  @override
  String get deviceNewIdentity =>
      'Assign its own name and ESPHome identity, so both devices are unique.';

  @override
  String get deviceRestoreStorage => 'Restore Webview\'s local storage';

  @override
  String get deviceRestoreStorageHelp =>
      'Includes the Home Assistant signed in session and the Voice Satellite assist_satellite selection - two devices must not share one satellite.';

  @override
  String get deviceDownload => 'Download';

  @override
  String get deviceChooseFile => 'Choose file…';

  @override
  String get deviceImportFailedSentence => 'Import failed.';

  @override
  String deviceReplaceNamed(String name) {
    return 'Replace \"$name\"';
  }

  @override
  String get settingDeviceNameTitle => 'Device name';

  @override
  String get settingDeviceNameDescription =>
      'Friendly name shown in remote management and used as the device name published to Home Assistant.';

  @override
  String get settingDeviceHostnameTitle => 'mDNS name';

  @override
  String get settingDeviceHostnameDescription =>
      'Reach the remote admin using this name and the configured port on the local network. Clear it to take the device name again.';

  @override
  String get settingDisableImpellerTitle => 'Legacy renderer';

  @override
  String get settingDisableImpellerDescription =>
      'Use the older Skia renderer, for old GPUs that crash at startup. Turns itself on after two such crashes; takes effect on the next app start.';

  @override
  String get settingLegacyWebViewTitle => 'Legacy WebView renderer';

  @override
  String get settingLegacyWebViewDescription =>
      'Draw the dashboard into a texture, for old GPUs that crash when it appears. Turns itself on where the device needs it; takes effect on the next app start.';

  @override
  String get deviceHostnamePlaceholder => 'Set from the device name';

  @override
  String get deviceConfiguration => 'Configuration';

  @override
  String get devicePermissionsManager => 'Permissions Manager';

  @override
  String get deviceOptions => 'Options';

  @override
  String get deviceStatus => 'Status';

  @override
  String get deviceConnection => 'Connection';

  @override
  String get devicePermissions => 'Permissions';

  @override
  String get deviceHelp => 'Help';

  @override
  String get deviceAccess => 'Access';

  @override
  String get deviceReading => 'Reading…';

  @override
  String get deviceChecking => 'Checking...';

  @override
  String get deviceUnavailable => 'Status unavailable.';

  @override
  String get deviceGrantOnDevice => 'Grant on device';

  @override
  String get deviceAppSettings => 'App settings';

  @override
  String get deviceCopyCommand => 'Copy command';

  @override
  String get deviceOpenGuide => 'Open guide';

  @override
  String get deviceNotSet => 'Not set';

  @override
  String get deviceGranted => 'Granted';

  @override
  String get deviceNotGranted => 'Not granted';

  @override
  String get deviceMissing => 'Missing';

  @override
  String get deviceNotOffered => 'Not offered';

  @override
  String get deviceOn => 'on';

  @override
  String get deviceOff => 'off';

  @override
  String get deviceServiceHint =>
      'Status, what keeps it running, required permissions';

  @override
  String get deviceRemoteHintActual =>
      'Manage this kiosk from a browser on your network';

  @override
  String get deviceUpdatesHint => 'Where the app looks for new releases';

  @override
  String get deviceShizukuHint => 'Connection, Android permissions and setup';

  @override
  String get deviceHelperHint =>
      'Silent update status, ADB setup and instructions';

  @override
  String get deviceAnalyticsHint =>
      'Share anonymized information to help improve Kiosk Satellite';

  @override
  String get deviceHardwareHint =>
      'Model, Android version, addresses, memory, uptime';

  @override
  String get deviceHaHint => 'Connection, version and what the kiosk shows';

  @override
  String get deviceWebViewHint => 'Engine version, renderer and user agent';

  @override
  String get devicePasswordSet => '•••••• (set)';

  @override
  String get deviceSaveFailed => 'Could not save this setting. Try again.';

  @override
  String get deviceOpenSettingsDevice => 'Open settings on device';

  @override
  String get deviceHardwarePage => 'Hardware';

  @override
  String get deviceWebViewPage => 'WebView';

  @override
  String get deviceModel => 'Device model';

  @override
  String get deviceAndroidVersion => 'Android version';

  @override
  String get deviceAndroidBuild => 'Android build';

  @override
  String get deviceIpv4 => 'IPv4 address';

  @override
  String get deviceIpv6 => 'IPv6 addresses';

  @override
  String get deviceAppUptime => 'App uptime';

  @override
  String get deviceNetworkUptime => 'Network uptime';

  @override
  String get deviceCpuUsage => 'CPU usage';

  @override
  String get deviceCpuTemp => 'CPU temperature';

  @override
  String get deviceBatteryLevel => 'Battery level';

  @override
  String get deviceScreenBrightness => 'Screen brightness';

  @override
  String get deviceScreenStatus => 'Screen status';

  @override
  String get deviceScreenSize => 'Screen size';

  @override
  String get deviceRam => 'RAM (free/total)';

  @override
  String get deviceStorage => 'Internal storage (free/total)';

  @override
  String get deviceHaUrl => 'Home Assistant URL';

  @override
  String get deviceWakeDetection => 'Wake word detection';

  @override
  String get deviceWakeStatus => 'Wake word status';

  @override
  String get deviceEngine => 'Engine';

  @override
  String get deviceWakeWords => 'Wake words';

  @override
  String get deviceStopWord => 'Stop word';

  @override
  String get deviceMotionDetection => 'Motion detection';

  @override
  String get deviceFaceDetection => 'Face detection';

  @override
  String get deviceProvider => 'Provider';

  @override
  String get deviceVersion => 'Version';

  @override
  String get deviceUserAgent => 'User agent';

  @override
  String get devicePlugged => 'plugged';

  @override
  String get deviceLowMemory => 'low';

  @override
  String get deviceRequiredPermissions => 'Required system permissions';

  @override
  String get devicePermissionIntro =>
      'Grants are given on this device, so each button opens an Android dialog or settings screen here. Some brands add their own battery or autostart manager on top, which Android cannot report.';

  @override
  String get devicePermissionIntroRemote =>
      'Grants are given on the device, so each button opens an Android dialog or settings screen there. Some brands add their own battery or autostart manager on top, which Android cannot report.';

  @override
  String get deviceMicrophone => 'Microphone';

  @override
  String get deviceMicrophoneHeld =>
      'Allows microphone usage for wake word detection, speech to text and intercom calls.';

  @override
  String get deviceBattery => 'Unrestricted battery';

  @override
  String get deviceBatteryHeld =>
      'Allows the process to run in the background without being paused or killed.';

  @override
  String get deviceCamera => 'Camera';

  @override
  String get deviceCameraHeld =>
      'Motion detection and snapshots can use the camera.';

  @override
  String get deviceBluetooth => 'Nearby devices';

  @override
  String get deviceBluetoothHeld =>
      'The Bluetooth proxy can scan for nearby devices.';

  @override
  String get deviceNotifications => 'Notifications';

  @override
  String get deviceNotificationsHeld =>
      'Allows the Kiosk Satellite Service\'s ongoing notification, which says what it is keeping alive.';

  @override
  String get deviceOverlay => 'Display over other apps';

  @override
  String get deviceOverlayHeld =>
      'Kiosk Satellite can bring itself back in the foreground.';

  @override
  String get deviceWriteSettings => 'Modify system settings';

  @override
  String get deviceWriteSettingsHeld =>
      'Brightness changes set the panel\'s real brightness.';

  @override
  String get deviceUiGuard => 'System UI guard';

  @override
  String get deviceUiGuardHeld =>
      'The notification shade and recents close on their own while the screen is protected.';

  @override
  String get deviceDeviceAdmin => 'Device admin';

  @override
  String get deviceDeviceAdminHeld => 'Allows the app to turn the screen off.';

  @override
  String get deviceAllFiles => 'All files access';

  @override
  String get deviceAllFilesHeld =>
      'The File Manager can browse the shared storage.';

  @override
  String get deviceUsageAccess => 'Usage access';

  @override
  String get deviceUsageAccessHeld =>
      'The Foreground app sensor can name whichever app is on screen.';

  @override
  String get deviceLocation => 'Location';

  @override
  String get deviceLocationHeld =>
      'Pages, Bluetooth scanning and the location sensors can use the device position.';

  @override
  String get deviceMicBlocked =>
      'Blocked. Android will not ask again, so allow it in the app settings.';

  @override
  String get deviceMicMissing =>
      'Wake word detection is on and nothing is listening.';

  @override
  String get deviceMicIdle =>
      'Needed by wake word detection, the intercom and pages that ask for the microphone.';

  @override
  String get deviceBatteryMissing =>
      'Android may pause the app when the screen is off, dropping the Home Assistant connection and the ESPHome entities with it.';

  @override
  String get deviceCameraMissing =>
      'The camera is switched on and cannot be opened.';

  @override
  String get deviceCameraIdle =>
      'Needed by motion detection, camera snapshots and pages that ask for the camera.';

  @override
  String get deviceBluetoothMissing =>
      'The Bluetooth proxy is switched on and cannot scan.';

  @override
  String get deviceBluetoothLocation =>
      'Bluetooth scanning needs the Location permission.';

  @override
  String get deviceBluetoothLocationOff =>
      'Location is off in the device settings, so Bluetooth scanning finds nothing.';

  @override
  String get deviceBluetoothIdle =>
      'Needed by the Bluetooth proxy to scan for devices.';

  @override
  String get deviceNotificationMissing =>
      'Needed to show the Kiosk Satellite Service\'s ongoing notification.';

  @override
  String get deviceOverlayMissing =>
      'Without this the app cannot reopen itself after a crash, an update or a wake word heard behind another app.';

  @override
  String get deviceOverlayIdle =>
      'Lets the app bring itself back to the front, and the lockdown shield cover the whole screen.';

  @override
  String get deviceBrightnessMissing =>
      'Brightness only dims the app window, so the panel and Home Assistant never see the change.';

  @override
  String get deviceBrightnessIdle =>
      'Needed to set the panel\'s real brightness rather than dimming the app window.';

  @override
  String get deviceGuardMissing =>
      'The notification shade and recents stay reachable. Enable Kiosk Satellite under Accessibility.';

  @override
  String get deviceGuardIdle =>
      'Closes the notification shade and recents while kiosk mode protects the screen.';

  @override
  String get deviceAdminIdle =>
      'Lets Screen off power the panel down instead of only blacking it out.';

  @override
  String get deviceFilesIdle =>
      'Lets the File Manager browse the shared storage instead of only the app folder.';

  @override
  String get deviceUsageIdle =>
      'Lets the Foreground app sensor name apps other than Kiosk Satellite.';

  @override
  String get deviceLocationMissing =>
      'Android will not deliver Bluetooth scan results without Location, and the location sensors cannot read the GPS receiver.';

  @override
  String get deviceLocationIdle =>
      'Used by pages that ask for your location, by Bluetooth scanning and by the ESPHome location sensors.';

  @override
  String get deviceServiceOverlayMissing =>
      'Without this the service cannot relaunch the kiosk after a crash or a close from recents.';

  @override
  String get deviceServiceOverlayIdle =>
      'Needed to relaunch the kiosk after a crash.';

  @override
  String get deviceListeningMissing =>
      'Background listening is on and nothing is listening.';

  @override
  String get deviceListeningIdle => 'Needed by background listening.';

  @override
  String get deviceMotionIdle => 'Needed by motion detection.';

  @override
  String get deviceBatteryAdb =>
      'This device has no settings screen for it. Grant it over adb: adb shell dumpsys deviceidle whitelist +me.jxl.kiosk_satellite';

  @override
  String get deviceOverlayAdb =>
      'This device has no settings screen for it. Grant it over adb: adb shell appops set me.jxl.kiosk_satellite SYSTEM_ALERT_WINDOW allow';

  @override
  String get settingRemoteEnabledTitle => 'Remote management';

  @override
  String get settingRemoteEnabledDescription =>
      'Run the embedded admin web server.';

  @override
  String get settingRemotePortTitle => 'Server port';

  @override
  String get settingRemotePortDescription =>
      'Port for the remote admin interface.';

  @override
  String get settingRemotePasswordTitle => 'Admin password';

  @override
  String get settingRemotePasswordDescription =>
      'Required to log in to the remote interface.';

  @override
  String get settingRemoteFleetDiscoveryTitle => 'Find other kiosks';

  @override
  String get settingRemoteFleetDiscoveryDescription =>
      'Announce this device on the network and list the other kiosks in the remote admin, to switch between them.';

  @override
  String get deviceRemotePage => 'Remote Administration';

  @override
  String get deviceAdminAddress => 'Admin address';

  @override
  String get deviceAdminAddressHelp =>
      'Open this address in a browser on your computer.';

  @override
  String get deviceByName => 'By name';

  @override
  String get deviceByNameHelp =>
      'The same address by hostname, on networks that resolve .local names.';

  @override
  String get devicePasswordNeeded =>
      'Set an admin password below to start the server.';

  @override
  String get deviceServerStopped => 'The server is not running.';

  @override
  String devicePortError(String port, String error) {
    return 'Could not listen on port $port: $error';
  }

  @override
  String get settingServiceCpuAwakeTitle =>
      'Keep the CPU awake while the screen is off';

  @override
  String get settingServiceCpuAwakeDescription =>
      'Holds a wake lock through dark spells so connections and timers keep running on time. Costs battery on an unplugged tablet.';

  @override
  String get deviceServicePage => 'Kiosk Satellite Service';

  @override
  String get deviceKeepingRunning => 'Keeping it running';

  @override
  String get deviceService => 'Service';

  @override
  String get deviceStopped => 'Stopped';

  @override
  String get deviceStoppedSentence => 'Stopped.';

  @override
  String get deviceRunning => 'Running';

  @override
  String get deviceRunningSentence => 'Running.';

  @override
  String get deviceRunningBackground =>
      'Running without the foreground exemption.';

  @override
  String get deviceServiceTypes => 'Foreground service types';

  @override
  String get deviceServiceTypesHelp =>
      'What the service declares to Android for the features it holds up.';

  @override
  String get deviceNoneDeclared => 'None declared.';

  @override
  String get deviceNone => 'none';

  @override
  String get deviceCpuLock => 'CPU wake lock';

  @override
  String get deviceCpuOff => 'Off: the setting below is off.';

  @override
  String get deviceCpuHeld => 'Held: the screen is off.';

  @override
  String get deviceCpuReleased => 'Released while the screen is on.';

  @override
  String get deviceNotHeld => 'Not held.';

  @override
  String get deviceHeld => 'Held';

  @override
  String get deviceReleased => 'Released';

  @override
  String get deviceWifiLock => 'Wi-Fi lock';

  @override
  String get deviceWifiHeld => 'Held: the radio stays out of power saving.';

  @override
  String get deviceWifiHelp =>
      'Keeps the radio out of power saving through screen-off.';

  @override
  String get deviceNotification => 'Notification';

  @override
  String get deviceNotificationHidden =>
      'Hidden: notifications are turned off for the app. The service runs regardless.';

  @override
  String get deviceNotificationShown =>
      'Shown in the notification shade while the service runs.';

  @override
  String get deviceHidden => 'Hidden';

  @override
  String get deviceShown => 'Shown';

  @override
  String get deviceReasonHa => 'Home Assistant connection';

  @override
  String get deviceReasonHaHelp =>
      'Keeps the dashboard session and its websocket open while the screen is off.';

  @override
  String get deviceReasonListening => 'Background listening';

  @override
  String get deviceReasonListeningHelp =>
      'Keeps the wake word engine and its microphone running behind other apps.';

  @override
  String get deviceReasonRtsp => 'RTSP microphone audio';

  @override
  String get deviceReasonRtspHelp =>
      'Keeps microphone streaming available to connected RTSP viewers.';

  @override
  String get deviceReasonEspHome => 'ESPHome server';

  @override
  String get deviceReasonEspHomeHelp =>
      'Keeps the ESPHome API server answering Home Assistant.';

  @override
  String get deviceReasonRemote => 'Remote administration';

  @override
  String get deviceReasonRemoteHelp => 'Keeps the admin web server answering.';

  @override
  String get deviceReasonProtections => 'Kiosk protections';

  @override
  String get deviceReasonProtectionsHelp =>
      'Relaunches the kiosk when it is closed from recents or crashes.';

  @override
  String get deviceReasonBluetooth => 'Bluetooth proxy';

  @override
  String get deviceReasonBluetoothHelp =>
      'Keeps Bluetooth scanning running while the app is not on screen.';

  @override
  String get deviceReasonLocation => 'Location sensors';

  @override
  String get deviceReasonLocationHelp =>
      'Keeps GPS fixes arriving while the screen is off or another app is in front.';

  @override
  String get deviceReasonPerson => 'Person detection';

  @override
  String get deviceReasonPersonHelp =>
      'Keeps reading the device\'s person sensor while another app is in front.';

  @override
  String get deviceReasonCameraHelp =>
      'Keeps the camera usable after the panel powers off, for motion and face detection.';

  @override
  String deviceServiceStopped(String error) {
    return 'Stopped: $error';
  }

  @override
  String deviceServiceRunning(String uptime) {
    return 'Running for $uptime.';
  }

  @override
  String get settingShizukuInstallUpdatesTitle =>
      'Install updates through Shizuku';

  @override
  String get settingShizukuInstallUpdatesDescription =>
      'Install Kiosk Satellite updates without on-device confirmation. Shizuku must be running and authorized.';

  @override
  String get deviceShizukuAccess => 'Shizuku access';

  @override
  String get deviceShizukuCheck => 'Checking availability';

  @override
  String get deviceShizukuRoot => 'Connected with root access';

  @override
  String get deviceShizukuShell => 'Connected with shell access';

  @override
  String get deviceShizukuGrant =>
      'Tap to grant access. Approve the request on this kiosk.';

  @override
  String get deviceShizukuGrantRemote =>
      'Grant access and approve the request on this kiosk.';

  @override
  String get deviceShizukuDenied => 'Allow Kiosk Satellite in the Shizuku app.';

  @override
  String get deviceShizukuUnsupported => 'Shizuku 13 or later is required.';

  @override
  String get deviceShizukuStart => 'Start Shizuku on this device.';

  @override
  String get deviceShizukuTest => 'Test connection';

  @override
  String get deviceShizukuTestHelp =>
      'Read the process identity without changing the device.';

  @override
  String get deviceShizukuTestTitle => 'Connection test';

  @override
  String get deviceShizukuTestFailed =>
      'Shizuku could not complete the connection test.';

  @override
  String get deviceShizukuAlreadyGranted =>
      'All permissions are already granted.';

  @override
  String get deviceShizukuConfirmed =>
      'Android confirmed the requested permissions.';

  @override
  String get deviceShizukuResults => 'Permission results';

  @override
  String get deviceShizukuGrantAll => 'Grant all permissions';

  @override
  String get deviceShizukuGrantAllHelp =>
      'Grant all permissions used by KS, including features that are currently off.';

  @override
  String get deviceShizukuSetup => 'Set up Shizuku';

  @override
  String get deviceShizukuSetupHelp =>
      'Read installation and startup instructions.';

  @override
  String get deviceShizukuLifetime =>
      'Shizuku started through ADB must be started again after a device reboot. Shell access does not provide root permissions.';

  @override
  String get deviceShizukuFailed => 'Shizuku request failed';

  @override
  String get deviceShizukuApprove => 'Approve the request on the kiosk.';

  @override
  String deviceShizukuTestOk(String access) {
    return 'Shizuku successfully ran a command with $access access.';
  }

  @override
  String get deviceHelperPage => 'Optional update helper';

  @override
  String get deviceHelperStatus => 'Helper status';

  @override
  String get deviceHelperError => 'Could not check the update helper.';

  @override
  String get deviceHelperUnneeded =>
      'Android can now install updates silently. The helper is not needed.';

  @override
  String get deviceHelperIntro =>
      'This device currently needs confirmation on the screen to install updates through Android. The optional helper lets Kiosk Satellite install updates without a tap.';

  @override
  String get deviceHelperBusy => 'Installing an update.';

  @override
  String get deviceHelperReady =>
      'Ready. Updates install without confirmation.';

  @override
  String get deviceHelperUnavailable =>
      'Unavailable. Start the helper through ADB to enable updates without confirmation.';

  @override
  String get deviceHelperLifetime =>
      'The helper survives app restarts and updates but stops after a device reboot. Run the command from a computer with ADB to start it again. The computer can then disconnect.';

  @override
  String get deviceHelperStart => 'Start through ADB';

  @override
  String get deviceHelperGuide => 'Setup guide';

  @override
  String get deviceHelperGuideHelp =>
      'Read the update helper instructions and requirements.';

  @override
  String get settingUpdateSourceTitle => 'Update source';

  @override
  String get settingUpdateSourceDescription =>
      'Where the app looks for new releases.';

  @override
  String get settingUpdateSourceUrlTitle => 'Repository URL';

  @override
  String get settingUpdateSourceUrlDescription =>
      'A folder on a web server the kiosk can reach, holding releases.json and the release APKs.';

  @override
  String get deviceUpdatesPage => 'Updates';

  @override
  String get deviceUpdateGithub => 'GitHub Repository';

  @override
  String get deviceUpdateCustom => 'Custom Repository';

  @override
  String get deviceUpdateGuide => 'Custom repository guide';

  @override
  String get deviceUpdateGuideHelp =>
      'How to host the releases file and the APKs on your own network.';

  @override
  String get deviceInstallFile => 'Install from file';

  @override
  String get deviceInstallFileHelp =>
      'Upload a Kiosk Satellite APK from a computer through the remote admin, on this same page. For a kiosk that cannot reach GitHub or a custom repository.';

  @override
  String get deviceInstallFileRemoteHelp =>
      'Upload a Kiosk Satellite APK from this computer and install it. For a kiosk that cannot reach GitHub or a custom repository.';

  @override
  String get deviceUploadedApk => 'Uploaded APK';

  @override
  String get deviceInstalling => 'Installing…';

  @override
  String get deviceDeviceNoAnswer => 'The device did not answer.';

  @override
  String get deviceInstallFailed => 'Update failed. Check the device logs.';

  @override
  String get deviceConfirmTablet => 'Confirm on the tablet screen';

  @override
  String deviceUploadedVersion(String version, String build, String size) {
    return 'Version $version (build $build, $size MB) is on the device, waiting to be installed.';
  }

  @override
  String deviceInstallVersion(String version) {
    return 'Install version $version';
  }

  @override
  String deviceHttpError(String code) {
    return 'The device answered HTTP $code.';
  }

  @override
  String get deviceUploadFailed => 'The upload failed.';

  @override
  String get deviceInstallFleet => 'Install on the fleet';

  @override
  String get deviceSendingFleet => 'Sending to the fleet…';

  @override
  String get deviceSameBuild => 'The kiosk already runs this build.';

  @override
  String get deviceInstallConfirmation =>
      'The install must be confirmed on the tablet screen unless the kiosk installs silently.';

  @override
  String get deviceSelfLast => 'This kiosk installs last.';

  @override
  String get deviceUpdatingFleet => 'Updating the fleet';

  @override
  String deviceUploading(String percent) {
    return 'Uploading… $percent%';
  }

  @override
  String deviceUploadedDetails(String version, String build, String size) {
    return 'The uploaded APK is version $version (build $build, $size MB).';
  }

  @override
  String deviceCurrentBuild(String version, String build) {
    return 'The kiosk runs $version (build $build).';
  }

  @override
  String deviceSendingTo(String name, String percent) {
    return 'Sending to $name… $percent%';
  }

  @override
  String deviceInstallingOn(String name) {
    return 'Installing on $name…';
  }

  @override
  String deviceInstallingNames(String names) {
    return '$names installing.';
  }

  @override
  String get deviceUpdateUrlInvalid =>
      'Enter the folder URL, for example http://nas.local/kiosk-satellite';

  @override
  String get deviceUpdateUrlPath =>
      'Enter only the folder URL, without anything after the path. Example: http://nas.local/kiosk-satellite';

  @override
  String get settingUiLanguageTitle => 'Language';

  @override
  String get settingUiLanguageDescription =>
      'Language for Kiosk Satellite and remote administration. Home Assistant keeps its own language.';

  @override
  String get settingUiThemeTitle => 'App theme';

  @override
  String get settingUiThemeDescription =>
      'Light or dark for the app\'s own screens: menu, settings, dialogs. System follows the Android setting.';

  @override
  String get settingUiScaleTitle => 'Scale UI';

  @override
  String get settingUiScaleDescription =>
      'Size of the app\'s own screens: menu, settings, dialogs. For high density displays. Web content keeps its size.';

  @override
  String get deviceUserInterface => 'User Interface';

  @override
  String get deviceThemeDark => 'Dark';

  @override
  String get deviceThemeLight => 'Light';

  @override
  String get deviceThemeSystem => 'System';

  @override
  String get settingHaHoldModeTitle => 'Hold mode';

  @override
  String get settingHaHoldModeDescription =>
      'Keep the current view on screen: the screensaver, dashboard view rotation and the return to home timer are paused until turned off.';

  @override
  String get settingHaHoldReleaseMinutesTitle => 'End hold automatically after';

  @override
  String get settingHaHoldReleaseMinutesDescription =>
      'Turns hold mode off by itself after the set time. Set to 0 to hold until turned off manually.';

  @override
  String get settingHaHoldMenuTitle => 'Show in the kiosk menu';

  @override
  String get settingHaHoldMenuDescription =>
      'Adds a menu entry that turns hold mode on and off.';

  @override
  String get haHoldHint =>
      'Pin the current view, automatic release, menu entry';

  @override
  String get haNever => 'Never';

  @override
  String haMinutes(String minutes) {
    return '$minutes min';
  }

  @override
  String haHours(String hours) {
    return '$hours h';
  }

  @override
  String haHoursMinutes(String hours, String minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get settingDisableSuspendTitle => 'Keep connected in the background';

  @override
  String get settingDisableSuspendDescription =>
      'Turns off Home Assistant\'s \"Suspend background connections\" setting, which would otherwise drop the connection a few minutes after the screen goes off.';

  @override
  String get settingFreezeOnScreensaverTitle =>
      'Pause dashboard during screensaver';

  @override
  String get settingFreezeOnScreensaverDescription =>
      'Stops drawing the dashboard while the screensaver covers it, cutting CPU and GPU use; the connection stays live. Not for the Dim screensaver.';

  @override
  String get settingWsFilterTitle => 'Filter dashboard updates';

  @override
  String get settingWsFilterDescription =>
      'Only process updates for entities on the current view, cutting stutter on low-powered tablets. Views that cannot be resolved stay unfiltered.';

  @override
  String get settingPauseDashboardCamerasTitle =>
      'Pause HA dashboard camera streams during screensaver';

  @override
  String get settingPauseDashboardCamerasDescription =>
      'Pauses supported muted camera streams on the Home Assistant dashboard while the screensaver covers it. Streams reconnect when it closes. Does not affect the device camera or the Camera Streams feature.';

  @override
  String get haOptimizations => 'Optimizations';

  @override
  String get haOptimizationsHint =>
      'Background connection, dashboard and camera pause, update filter';

  @override
  String get haScanUnavailable =>
      'Scan details are not available for the current view.';

  @override
  String get haScanDetails => 'Dashboard scan details';

  @override
  String haWatchedTitle(String count) {
    return 'Watched entities ($count)';
  }

  @override
  String get haWatched => 'Watched entities';

  @override
  String get haEntityListUnavailable =>
      'The entity list is not available right now.';

  @override
  String haWatching(String count) {
    return 'Watching $count entities on this view.';
  }

  @override
  String get haNoUpdates => 'No updates in the last minute.';

  @override
  String haFiltered(String percent, String dropped, String total) {
    return 'Filtered $percent% of updates in the last minute ($dropped of $total).';
  }

  @override
  String get haRawUpdates =>
      'Something on this page receives every entity update anyway, so filtering saves less here.';

  @override
  String get haAllStates =>
      'This view reads all entity states, so its updates are not filtered.';

  @override
  String get haUnknownEntities =>
      'This view\'s entities can\'t be determined, so its updates are not filtered.';

  @override
  String get haWaiting => 'Waiting for the dashboard to load…';

  @override
  String get haShowScan => 'Show scan details.';

  @override
  String haThreshold(String count) {
    return 'This view uses $count entities, which crosses the filtering threshold. Filtering is disabled.';
  }

  @override
  String get settingHaReturnHomeEnabledTitle => 'Return to home dashboard view';

  @override
  String get settingHaReturnHomeEnabledDescription =>
      'Go back to the dashboard configured above after a period of inactivity.';

  @override
  String get settingHaReturnHomeSecondsTitle => 'Return after (seconds)';

  @override
  String get settingHaReturnHomeSecondsDescription =>
      'Inactivity period before the kiosk goes back.';

  @override
  String get haReturnHint => 'Go back to the home view when left idle';

  @override
  String get haReturnDisabled =>
      'Turned off while Dashboard view rotation is on.';

  @override
  String get haReturnNoPath =>
      'The configured dashboard has no view path to return to.';

  @override
  String haReturnPath(String path) {
    return 'Returns to \"$path\" after the timeout.';
  }

  @override
  String get settingHaRotationEnabledTitle => 'Enable dashboard view rotation';

  @override
  String get settingHaRotationEnabledDescription =>
      'Cycle through the selected dashboard views in an endless loop, showing each one for the chosen number of seconds.';

  @override
  String get settingHaRotationSecondsTitle => 'Seconds per view';

  @override
  String get settingHaRotationSecondsDescription =>
      'How long each view stays on screen.';

  @override
  String get settingHaRotationPauseSecondsTitle =>
      'Pause rotation on interaction (seconds)';

  @override
  String get settingHaRotationPauseSecondsDescription =>
      'Touching the screen pauses rotation for this long, and each touch restarts the countdown. Voice interactions pause until they end. 0 keeps rotating through touches.';

  @override
  String get settingHaRotationCrossfadeTitle => 'Fade between views';

  @override
  String get settingHaRotationCrossfadeDescription =>
      'Fade out to the background and into the next view instead of switching instantly. Moving to a different dashboard or an external page still switches instantly.';

  @override
  String get settingHaRotationFadeSecondsTitle => 'Fade duration (seconds)';

  @override
  String get settingHaRotationFadeSecondsDescription =>
      'Combined fade-out and fade-in time. Loading the next view can add time, especially on its first visit.';

  @override
  String get haRotation => 'Dashboard View Rotation';

  @override
  String get haRotationHint => 'Cycle through views, dwell time, fade';

  @override
  String get haDefaultView => 'Default view';

  @override
  String get haExternalPages => 'External pages';

  @override
  String get haFadeError => 'Choose a fade duration from 0.2 to 5 seconds.';

  @override
  String get haPauseRemoteHelp =>
      'Touch pauses rotation for this long; each touch restarts it. Voice interactions always pause until they end. 0 keeps rotating.';

  @override
  String get settingHaUrlTitle => 'Home Assistant base URL';

  @override
  String get settingHaUrlDescription =>
      'e.g. https://homeassistant.local:8123, without a dashboard path.';

  @override
  String get settingHaTokenTitle => 'Long-lived access token';

  @override
  String get settingHaTokenDescription =>
      'Created under your HA profile → Security.';

  @override
  String get settingHaAutoLoginTitle => 'Log in automatically';

  @override
  String get settingHaAutoLoginDescription =>
      'Sign in to the dashboard with the access token above instead of showing the Home Assistant login page.';

  @override
  String get haValidate => 'Validate';

  @override
  String get haValidateConnection => 'Validate connection';

  @override
  String get haChecking => 'Checking…';

  @override
  String get haConnected => 'Connected';

  @override
  String get haConnectedRemote => 'Connected.';

  @override
  String get haNotValidated =>
      'Not validated yet. The settings below unlock once the connection checks out.';

  @override
  String get haConnectFailed => 'Could not connect.';

  @override
  String get haNotConfigured => 'Home Assistant URL and token not configured';

  @override
  String get haInvalidToken => 'invalid token';

  @override
  String haUnreachable(String error) {
    return 'Could not reach Home Assistant: $error';
  }

  @override
  String get haProxy => 'Secure context proxy';

  @override
  String get haProxyHelp =>
      'Routes a plain http Home Assistant through an in-app proxy so the browser unlocks the microphone and other https-only features. Only for http URLs.';

  @override
  String get haProxyRemoteHelp =>
      'Routes a plain http Home Assistant through a proxy inside the app so the browser unlocks the microphone and other https-only features. Available only for http URLs.';

  @override
  String get haProxyNotice =>
      'This Home Assistant URL uses plain http, and browsers block the microphone and other features on http pages. Kiosk Satellite will route the dashboard through a secure proxy inside the app so everything works. You may need to sign in to Home Assistant again.';

  @override
  String get haProxyRemoteNotice =>
      'This Home Assistant URL uses plain http, and browsers block the microphone and other features on http pages. Kiosk Satellite will route the dashboard through a secure proxy inside the app so everything works. You may need to sign in to Home Assistant again on the tablet.';

  @override
  String get haDashboard => 'Dashboard';

  @override
  String get haChooseView => 'Choose a view';

  @override
  String get haLoadingDashboards => 'Loading dashboards…';

  @override
  String get haListFailed => 'Could not list dashboards';

  @override
  String get haRetryHint => 'Tap to retry.';

  @override
  String get haChangeView => 'Change view';

  @override
  String get haNoViews => 'No sub views';

  @override
  String get haNoViewsHelp => 'This dashboard has no selectable sub views.';

  @override
  String get haNoDashboards => 'No dashboards found';

  @override
  String get settingHaThemeTitle => 'Theme';

  @override
  String get settingHaThemeDescription =>
      'Light or dark for the Home Assistant dashboard, also set from the Theme entity in Home Assistant. Auto follows the settings below.';

  @override
  String get settingThemeMatchAppTitle =>
      'Sync Home Assistant themes with Kiosk Satellite';

  @override
  String get settingThemeMatchAppDescription =>
      'Automatically match your Home Assistant theme to your Kiosk Satellite interface.';

  @override
  String get settingThemeAutoTitle => 'Match theme to time of day';

  @override
  String get settingThemeAutoDescription =>
      'Switch Home Assistant between light and dark on a schedule. Keeps whatever theme is selected, flipping only its light/dark variant.';

  @override
  String get settingThemeDarkAtTitle => 'Dark theme at';

  @override
  String get settingThemeDarkAtDescription =>
      'Local time to switch to the dark theme.';

  @override
  String get settingThemeLightAtTitle => 'Light theme at';

  @override
  String get settingThemeLightAtDescription =>
      'Local time to switch back to the light theme.';

  @override
  String get settingThemeAutoAppTitle => 'Also switch the app theme';

  @override
  String get settingThemeAutoAppDescription =>
      'Flip Kiosk Satellite\'s own theme (menu, settings) together with the scheduled Home Assistant change.';

  @override
  String get haThemeHint =>
      'Match the app, or switch dark and light on a schedule';

  @override
  String get haThemeAuto => 'Auto';

  @override
  String get settingHaKioskModeTitle => 'HA kiosk mode';

  @override
  String get settingHaKioskModeDescription =>
      'Hide the Home Assistant header and sidebar. Applies immediately.';

  @override
  String get settingHaKioskHideHeaderTitle => 'Hide the header';

  @override
  String get settingHaKioskHideHeaderDescription =>
      'Hide the dashboard toolbar and view tabs while HA kiosk mode is on. Leave off if you switch views from the header.';

  @override
  String get settingHaKioskHideSidebarTitle => 'Hide the sidebar';

  @override
  String get settingHaKioskHideSidebarDescription =>
      'Hide the navigation sidebar while HA kiosk mode is on.';

  @override
  String get settingHaKioskMenuTitle => 'Show in the kiosk menu';

  @override
  String get settingHaKioskMenuDescription =>
      'Add an HA Kiosk Mode entry to the kiosk menu that turns it on and off.';

  @override
  String get settingHaDashboardCarouselTitle => 'Enable dashboard carousel';

  @override
  String get settingHaDashboardCarouselDescription =>
      'Swipe left or right on the dashboard to move between its views. Swipes on sliders, maps and scrolling cards are left alone.';

  @override
  String get settingHaCarouselOverCardsTitle =>
      'Capture swipe gestures over cards';

  @override
  String get settingHaCarouselOverCardsDescription =>
      'Switch views even when the swipe starts on a card that reacts to swipes. Sliders still work normally.';

  @override
  String get settingHaHapticsTitle => 'Enable haptics';

  @override
  String get settingHaHapticsDescription =>
      'Vibrate when buttons, switches, cards, sliders and thermostat dials are used. Requires a vibration motor.';

  @override
  String get settingHaHapticsStrengthTitle => 'Vibration strength';

  @override
  String get settingHaHapticsStrengthDescription =>
      'How strong the vibration feels.';

  @override
  String get settingHaTapSoundTitle => 'Play tap sounds';

  @override
  String get settingHaTapSoundDescription =>
      'Play the standard tap sound when buttons, switches, cards, sliders and thermostat dials are used.';

  @override
  String get settingHaTapSoundVolumeTitle => 'Tap sound volume';

  @override
  String get settingHaTapSoundVolumeDescription =>
      'How loud the tap sound plays.';

  @override
  String get haUserInterface => 'User Interface';

  @override
  String get haInterfaceHint =>
      'Kiosk mode, dashboard carousel, haptics, tap sounds';

  @override
  String get haHaptics => 'Haptics';

  @override
  String get haVibrationLight => 'Light';

  @override
  String get haVibrationMedium => 'Medium';

  @override
  String get haVibrationStrong => 'Strong';

  @override
  String get settingsMenuHomeAssistant => 'Home Assistant Setup';

  @override
  String get settingsMenuHomeAssistantSummary =>
      'Connection, dashboard, kiosk mode';

  @override
  String get settingsMenuVoiceSatellite => 'Voice Satellite';

  @override
  String get settingsMenuVoiceSatelliteSummary =>
      'Wake word, background listening';

  @override
  String get settingsMenuEsphome => 'ESPHome';

  @override
  String get settingsMenuEsphomeSummary =>
      'Native entities and Bluetooth proxy';

  @override
  String get settingsMenuScreenAudio => 'Screen & Audio';

  @override
  String get settingsMenuScreenAudioSummary => 'Brightness, volume, microphone';

  @override
  String get settingsMenuScreensaver => 'Screensaver';

  @override
  String get settingsMenuScreensaverSummary =>
      'Idle timeout, modes, motion wake';

  @override
  String get settingsMenuBrowser => 'Web Browsing';

  @override
  String get settingsMenuBrowserSummary => 'Cache, SSL, Zoom level';

  @override
  String get settingsMenuMediaPlayer => 'Media Player';

  @override
  String get settingsMenuMediaPlayerSummary =>
      'Music Assistant, Sendspin, Sonos';

  @override
  String get settingsMenuDlna => 'DLNA Renderer';

  @override
  String get settingsMenuDlnaSummary =>
      'Play images, videos and audio remotely';

  @override
  String get settingsMenuIntercom => 'Intercom';

  @override
  String get settingsMenuIntercomSummary => 'Talk between kiosks';

  @override
  String get settingsMenuCamera => 'Camera';

  @override
  String get settingsMenuCameraSummary => 'Device camera, motion, streaming';

  @override
  String get settingsMenuCameraStreams => 'Camera Streams';

  @override
  String get settingsMenuCameraStreamsSummary =>
      'Go2RTC and Home Assistant cameras';

  @override
  String get settingsMenuKiosk => 'Kiosk Mode';

  @override
  String get settingsMenuKioskSummary => 'Exit gesture, PIN, hardware buttons';

  @override
  String get settingsMenuHomeLauncher => 'Home Launcher';

  @override
  String get settingsMenuHomeLauncherSummary =>
      'Replace the device home screen';

  @override
  String get settingsMenuAppLauncher => 'App Launcher';

  @override
  String get settingsMenuAppLauncherSummary => 'Open other apps from the kiosk';

  @override
  String get settingsMenuGestures => 'Gestures';

  @override
  String get settingsMenuGesturesSummary => 'Touch, palm and clap gestures';

  @override
  String get settingsMenuDevice => 'Device';

  @override
  String get settingsMenuDeviceSummary => 'Name, app theme, remote access';

  @override
  String get settingsMenuFleet => 'Fleet Management';

  @override
  String get settingsMenuFleetSummary => 'Lead or follow other kiosks';

  @override
  String get settingsMenuPlugins => 'Plugin Manager';

  @override
  String get settingsMenuPluginsSummary => 'Install and manage plugins';

  @override
  String get settingsMenuLogs => 'Logs';

  @override
  String get settingsMenuLogsSummary => 'App log and web console';

  @override
  String get settingsMenuAbout => 'About';

  @override
  String get settingsMenuAboutSummary => 'Version, author, license';

  @override
  String get settingsMenuOverview => 'Overview';

  @override
  String get settingsMenuOverviewSummary => 'Screen and quick controls';

  @override
  String get settingsMenuLockdown => 'Lockdown Mode';

  @override
  String get settingsMenuLockdownSummary => 'Disable screen interactions';

  @override
  String get settingsMenuFiles => 'File Manager';

  @override
  String get settingsMenuFilesSummary => 'Browse, download and upload files';

  @override
  String get settingsGroupHomeAssistant => 'Home Assistant';

  @override
  String get settingsGroupDisplay => 'Display';

  @override
  String get settingsGroupMediaCameras => 'Media & Cameras';

  @override
  String get settingsGroupKiosk => 'Kiosk';

  @override
  String get settingsGroupSystem => 'System';

  @override
  String get settingsMenuMenu => 'Menu';

  @override
  String get settingsMenuTheme => 'Theme';

  @override
  String get settingsMenuLogout => 'Log out';

  @override
  String get settingsMenuSwitchKiosk => 'Switch kiosk';

  @override
  String settingsMenuThemeState(String theme) {
    return 'Theme: $theme';
  }

  @override
  String get settingsMenuThemeAuto => 'Automatic';

  @override
  String get settingAdaptiveBrightnessTitle => 'Adaptive brightness';

  @override
  String get settingAdaptiveBrightnessDescription =>
      'Dim the screen as the room gets darker, using the ambient light sensor.';

  @override
  String get settingAdaptiveMinBrightnessTitle => 'Minimum brightness';

  @override
  String get settingAdaptiveMinBrightnessDescription =>
      'Screen brightness in a dark room.';

  @override
  String get settingAdaptiveMaxBrightnessTitle => 'Maximum brightness';

  @override
  String get settingAdaptiveMaxBrightnessDescription =>
      'Screen brightness in a bright room.';

  @override
  String get settingAdaptiveDarkLuxTitle => 'Dark room (lx)';

  @override
  String get settingAdaptiveDarkLuxDescription =>
      'Light level at or below which the screen sits at Minimum brightness.';

  @override
  String get settingAdaptiveBrightLuxTitle => 'Bright room (lx)';

  @override
  String get settingAdaptiveBrightLuxDescription =>
      'Light level at or above which the screen sits at Maximum brightness.';

  @override
  String get screenAudioAdaptiveHint =>
      'Follow the room light with the ambient light sensor';

  @override
  String get screenAudioAdaptiveNote =>
      'Level in a bright room. Adaptive brightness dims it from there.';

  @override
  String get screenAudioAdaptiveOwns => 'Adaptive brightness is on.';

  @override
  String get screenAudioNoSensor => 'No ambient light sensor on this device.';

  @override
  String get screenAudioAmbientLight => 'Ambient light';

  @override
  String get screenAudioAmbientHelp =>
      'What the ambient light sensor reads right now.';

  @override
  String get screenAudioNoReading => 'No reading yet';

  @override
  String screenAudioLux(String lux) {
    return '$lux lx';
  }

  @override
  String screenAudioLuxLast(String lux) {
    return '$lux lx (last known)';
  }

  @override
  String get screenAudioSetsMaximum =>
      'Sets Maximum brightness: adaptive brightness is on.';

  @override
  String get screenAudioSetsDefault => 'Sets Default brightness.';

  @override
  String get settingAudioMicDeviceTitle => 'Microphone';

  @override
  String get settingAudioMicDeviceDescription =>
      'The microphone wake word detection and voice turns capture from.';

  @override
  String get settingAudioSpeakerDeviceTitle => 'Speaker';

  @override
  String get settingAudioSpeakerDeviceDescription =>
      'Output for Voice Satellite sounds; media playback follows the system route. Echo cancellation only works with the microphone and speaker on the same device.';

  @override
  String get screenAudioDevices => 'Audio Devices';

  @override
  String get screenAudioSelectedDevice => 'Selected device';

  @override
  String screenAudioDisconnected(String name) {
    return '$name (not connected)';
  }

  @override
  String get settingMicAudioSourceTitle => 'Capture mode';

  @override
  String get settingMicAudioSourceDescription =>
      'Voice communication is the only mode with echo cancellation, so leave it unless the microphone reads far quieter here than in a recorder app.';

  @override
  String get settingMicEchoCancellationTitle => 'Echo cancellation';

  @override
  String get settingMicEchoCancellationDescription =>
      'Keeps the kiosk\'s own speaker out of the microphone so the stop word works during playback. Turn it off only if the microphone reads far quieter here than in a recorder app.';

  @override
  String get settingMicChannelTitle => 'Microphone channel';

  @override
  String get settingMicChannelDescription =>
      'Multichannel microphones often reserve one channel for speech recognition; picking it can improve detection.';

  @override
  String get settingMicAgcTitle => 'Automatic gain control';

  @override
  String get settingMicAgcDescription =>
      'Let Android level the microphone instead of a fixed gain. It also lifts room noise, and on some devices it does nothing at all.';

  @override
  String get settingMicNoiseSuppressionTitle => 'Noise suppression';

  @override
  String get settingMicNoiseSuppressionDescription =>
      'Reduce microphone background noise using Android processing. It may help or hurt wake word detection depending on the device.';

  @override
  String get settingMicGainDbTitle => 'Microphone gain';

  @override
  String get settingMicGainDbDescription =>
      'Boost or cut the microphone before anything hears it. Aim for a level near 0.05 in the wake word tester; too much gain distorts speech and hurts detection.';

  @override
  String get settingMicCaptureFormatTitle => 'Capture format';

  @override
  String get settingMicCaptureFormatDescription =>
      'Pick 48 kHz stereo when the microphone works in other apps but not here: some sound cards record in that format only and the app converts it itself.';

  @override
  String get screenAudioMicrophoneSettings => 'Microphone settings';

  @override
  String get screenAudioMicrophoneHint =>
      'Capture mode, channel, gain, live level';

  @override
  String get screenAudioMicrophoneNote =>
      'Adjust capture for your microphone and room. Test wake words and voice interactions after changing these settings.';

  @override
  String get screenAudioVoiceCommunication => 'Voice communication (default)';

  @override
  String get screenAudioVoiceRecognition => 'Voice recognition';

  @override
  String get screenAudioRawMicrophone => 'Raw microphone';

  @override
  String get screenAudioAutomaticDefault => 'Automatic (default)';

  @override
  String get screenAudioStereo => '48 kHz stereo';

  @override
  String get screenAudioDownmix => 'Downmix (default)';

  @override
  String screenAudioChannel(String channel) {
    return 'Channel $channel';
  }

  @override
  String screenAudioChannelMissing(String channel) {
    return 'Channel $channel (not on this microphone)';
  }

  @override
  String get screenAudioMicrophoneLevel => 'Microphone level';

  @override
  String get screenAudioMicrophoneLevelHelp =>
      'Speak from where you use the device; adjust the gain until normal speech tops out around the end of the green.';

  @override
  String get settingBrowserCutoutModeTitle => 'Display cutout';

  @override
  String get settingBrowserCutoutModeDescription =>
      'What to do with the screen area around a camera cutout or punch hole. Pick Avoid the cutout if the camera sits on top of buttons at the top of the dashboard.';

  @override
  String get settingScreenOrientationTitle => 'Screen orientation';

  @override
  String get settingScreenOrientationDescription =>
      'Force the screen into one orientation. Use this on a device without a rotation sensor, or one mounted a way the sensor gets wrong.';

  @override
  String get settingKeepScreenOnTitle => 'Keep screen on';

  @override
  String get settingKeepScreenOnDescription =>
      'Prevent the OS from turning the screen off.';

  @override
  String get settingSetBrightnessOnLaunchTitle => 'Set brightness on launch';

  @override
  String get settingSetBrightnessOnLaunchDescription =>
      'Apply the default brightness whenever the app starts.';

  @override
  String get settingDefaultBrightnessTitle => 'Default brightness';

  @override
  String get settingDefaultBrightnessDescription =>
      'Screen brightness applied when the app starts. Moving the slider applies it immediately.';

  @override
  String get screenAudioScreen => 'Screen';

  @override
  String get screenAudioCutoutAlways => 'Use the cutout area';

  @override
  String get screenAudioCutoutShort => 'Short edges only';

  @override
  String get screenAudioCutoutDefault => 'System default';

  @override
  String get screenAudioCutoutNever => 'Avoid the cutout';

  @override
  String get screenAudioAutomatic => 'Automatic';

  @override
  String get screenAudioLandscape => 'Landscape';

  @override
  String get screenAudioReverseLandscape => 'Reverse landscape';

  @override
  String get screenAudioPortrait => 'Portrait';

  @override
  String get screenAudioReversePortrait => 'Reverse portrait';

  @override
  String get screenAudioPermission => 'Permission';

  @override
  String get screenAudioBrightnessFallback => 'Brightness is using a fallback';

  @override
  String get screenAudioBrightnessPermission =>
      'Without the \"Modify system settings\" permission, brightness changes only dim this app instead of setting the panel\'s actual brightness.';

  @override
  String get screenAudioBrightnessPermissionRemote =>
      'Without the \"Modify system settings\" permission, brightness changes only dim the app instead of setting the panel\'s actual brightness.';

  @override
  String get screenAudioAlwaysOn => 'Always-on display';

  @override
  String get screenAudioAlwaysOnClock => 'This device keeps a dim clock on';

  @override
  String get screenAudioAlwaysOnHelp =>
      'Turning the screen off puts the device to sleep, but the always-on display lights the lock screen back up and no app can stop it. Turn off \"Always show time and info\" in Android settings under Display, near the lock screen options; some ROMs call it always-on display. The Home Assistant screen entity stays unavailable until you do.';

  @override
  String get settingMediaVolumeTitle => 'Media volume';

  @override
  String get settingMediaVolumeDescription =>
      'Music and video play at this share of the master volume. The Sendspin player volume in Music Assistant moves this slider.';

  @override
  String get settingAssistantVolumeTitle => 'Assistant volume';

  @override
  String get settingAssistantVolumeDescription =>
      'Voice responses and chimes play at this share of the master volume, independent of the media volume.';

  @override
  String get settingAssistantFullVolumeRangeTitle =>
      'Full assistant volume range';

  @override
  String get settingAssistantFullVolumeRangeDescription =>
      'Initialize the built-in speaker\'s call volume at 100% when assistant audio first starts. Master and assistant volume still apply. Other apps share this call volume, which is not restored afterward.';

  @override
  String get settingIntercomVolumeTitle => 'Intercom volume';

  @override
  String get settingIntercomVolumeDescription =>
      'The other kiosk\'s voice and announcements play at this share of the master volume.';

  @override
  String get screenAudioVolume => 'Audio Volume';

  @override
  String get screenAudioMasterVolume => 'Master volume';

  @override
  String get screenAudioMasterHelp =>
      'The device volume. Media, intercom and assistant volumes scale under it.';

  @override
  String get settingScreensaverBlackHideExtrasTitle => 'Hide all extras';

  @override
  String get settingScreensaverBlackHideExtrasDescription =>
      'Keeps the screen fully black: no small clock, At a Glance entities, or other overlays.';

  @override
  String get screensaverBlackSection => 'Black screensaver';

  @override
  String get settingScreensaverClockStyleTitle => 'Style';

  @override
  String get settingScreensaverClockStyleDescription =>
      'How the clock is drawn.';

  @override
  String get settingScreensaverClockFontTitle => 'Font Family';

  @override
  String get settingScreensaverClockFontDescription =>
      'The typeface the clock is drawn in.';

  @override
  String get settingScreensaverClockFontWeightTitle => 'Font weight';

  @override
  String get settingScreensaverClockFontWeightDescription =>
      'How heavy the clock\'s digits are drawn. Default is each face\'s own weight.';

  @override
  String get settingScreensaverClock24hTitle => '24-hour clock';

  @override
  String get settingScreensaverClock24hDescription =>
      'Show a 24-hour time instead of AM/PM.';

  @override
  String get settingScreensaverClockSecondsTitle => 'Show seconds';

  @override
  String get settingScreensaverClockSecondsDescription =>
      'Include seconds in the clock.';

  @override
  String get settingScreensaverClockDateTitle => 'Show date';

  @override
  String get settingScreensaverClockDateDescription =>
      'Show the weekday and date under the clock.';

  @override
  String get settingScreensaverClockScaleTitle => 'Clock size';

  @override
  String get settingScreensaverClockScaleDescription =>
      'Scale the clock from 50 to 300 percent for this screen.';

  @override
  String get settingScreensaverClockColorTitle => 'Clock color';

  @override
  String get settingScreensaverClockColorDescription =>
      'The color of the clock text.';

  @override
  String get settingScreensaverClockBgColorTitle => 'Background color';

  @override
  String get settingScreensaverClockBgColorDescription =>
      'The color behind the clock.';

  @override
  String get settingScreensaverClockBackgroundTitle => 'Background photo';

  @override
  String get settingScreensaverClockBackgroundDescription =>
      'Show a photo behind the clock instead of the solid color. A path to an image on the device, or an image URL the device fetches.';

  @override
  String get settingScreensaverClockBackgroundRefreshTitle =>
      'Refresh URL background';

  @override
  String get settingScreensaverClockBackgroundRefreshDescription =>
      'Minutes between fetches of a URL background. 0 fetches it only when the setting is written.';

  @override
  String get settingScreensaverFlipDigitColorTitle => 'Digit color';

  @override
  String get settingScreensaverFlipDigitColorDescription =>
      'The color of the flip digits.';

  @override
  String get settingScreensaverFlipBgColorTitle => 'Card color';

  @override
  String get settingScreensaverFlipBgColorDescription =>
      'The color of the cards.';

  @override
  String get settingScreensaverFlipBackdropColorTitle => 'Background color';

  @override
  String get settingScreensaverFlipBackdropColorDescription =>
      'The color behind the cards.';

  @override
  String get settingScreensaverRollerDigitColorTitle => 'Digit color';

  @override
  String get settingScreensaverRollerDigitColorDescription =>
      'The color of the rolling digits.';

  @override
  String get settingScreensaverRollerBgColorTitle => 'Background color';

  @override
  String get settingScreensaverRollerBgColorDescription =>
      'The color behind the digits.';

  @override
  String get settingScreensaverClockNightTitle => 'Night mode';

  @override
  String get settingScreensaverClockNightDescription =>
      'Recolor the clock while the room is dark.';

  @override
  String get settingScreensaverClockNightLuxTitle => 'Light level';

  @override
  String get settingScreensaverClockNightLuxDescription =>
      'At or below this light level the clock takes the night color.';

  @override
  String get settingScreensaverClockNightColorTitle => 'Night color';

  @override
  String get settingScreensaverClockNightColorDescription =>
      'The color of the clock and the widgets in the dark.';

  @override
  String get settingScreensaverClockNightBgColorTitle => 'Night background';

  @override
  String get settingScreensaverClockNightBgColorDescription =>
      'The color behind the clock in the dark.';

  @override
  String get settingScreensaverClockNightHideBackgroundTitle =>
      'Hide background photo';

  @override
  String get settingScreensaverClockNightHideBackgroundDescription =>
      'Use the night background color instead of the photo while Night mode is active.';

  @override
  String get settingScreensaverClockNightCardColorTitle => 'Night card color';

  @override
  String get settingScreensaverClockNightCardColorDescription =>
      'The color of the flip cards in the dark.';

  @override
  String get screensaverClockSection => 'Clock screensaver';

  @override
  String get screensaverClockHint =>
      'Style, font, size, colors, night mode, background photo';

  @override
  String get screensaverStyleDigital => 'Digital Clock';

  @override
  String get screensaverStyleFlip => 'Flip Clock';

  @override
  String get screensaverStyleRoller => 'Roller Clock';

  @override
  String get screensaverFontDefault => 'Default';

  @override
  String get screensaverFontLight => 'Light';

  @override
  String get screensaverFontRegular => 'Regular';

  @override
  String get screensaverFontMedium => 'Medium';

  @override
  String get screensaverFontBold => 'Bold';

  @override
  String get screensaverFontBlack => 'Black';

  @override
  String get screensaverNoPhoto => 'No photo selected';

  @override
  String get screensaverBackgroundHint =>
      'Path to an image on the device, or an image URL';

  @override
  String get screensaverImageUrlError => 'Enter a full image URL';

  @override
  String get screensaverRefreshError => 'Enter whole minutes from 0 to 1440';

  @override
  String screensaverMaxCharacters(String count) {
    return 'Use at most $count characters';
  }

  @override
  String get screensaverOverlayEntity => 'Entity';

  @override
  String get screensaverOverlayNotSet => 'Not set';

  @override
  String get screensaverOverlayName => 'Name';

  @override
  String get screensaverOverlayNameHelp =>
      'Leave empty to use the Home Assistant name.';

  @override
  String get screensaverOverlayValue => 'Displayed value';

  @override
  String get screensaverOverlayState => 'State';

  @override
  String get screensaverOverlayEntityRequired => 'Pick an entity.';

  @override
  String get screensaverOverlaySearchHint => 'Name or entity id';

  @override
  String get screensaverOverlaySearchHintRemote =>
      'Search by name or entity id';

  @override
  String get screensaverOverlaySearchEmpty => 'Type to search entities.';

  @override
  String get screensaverOverlayNoMatches => 'Nothing matched.';

  @override
  String get screensaverOverlaySearching => 'Searching…';

  @override
  String get screensaverOverlayUnreachable => 'Could not reach Home Assistant';

  @override
  String get screensaverOverlayNoAnswer => 'The device did not answer.';

  @override
  String screensaverOverlaySearchError(String error) {
    return 'Could not search entities: $error';
  }

  @override
  String get settingScreensaverDismissOnFaceTitle => 'Dismiss on face';

  @override
  String get settingScreensaverDismissOnFaceDescription =>
      'Wake the screen when someone looks at the kiosk, not on movement alone. The camera runs only during the screensaver. WARNING: Needs a lit face; in the dark, schedule motion detection instead.';

  @override
  String get settingScreensaverDismissOnFaceScreenOffOnlyTitle =>
      'Only when screen is off';

  @override
  String get settingScreensaverDismissOnFaceScreenOffOnlyDescription =>
      'Keep the screensaver visible when a face is detected while the screen is on. Once the screen turns off, detection wakes the dashboard. Touch still dismisses the screensaver.';

  @override
  String get settingScreensaverPostponeOnFaceTitle =>
      'Postpone screensaver on face';

  @override
  String get settingScreensaverPostponeOnFaceDescription =>
      'Delay activating the screensaver while someone is looking at the kiosk. WARNING: Keeps the camera running permanently, with face detection and its CPU cost on top.';

  @override
  String get settingFaceSensitivityTitle => 'Face sensitivity';

  @override
  String get settingFaceSensitivityDescription =>
      'Higher wakes on smaller, more distant faces. 1 needs a face close to the screen; 100 reacts to any face the camera can make out.';

  @override
  String get screensaverDetectionFacePage => 'Face Detection';

  @override
  String get screensaverDetectionFaceHint =>
      'Dismiss the screensaver when someone looks at it';

  @override
  String get screensaverDetectionMotionPrecedence =>
      'Dismiss on motion is on and takes precedence, so face detection stays idle until it is turned off.';

  @override
  String get screensaverDetectionFaceTuning =>
      'Frame rate, camera pick and startup delay are tuned in the Camera settings.';

  @override
  String get screensaverDetectionAndroidUnsupported =>
      'Not available on this Android version.';

  @override
  String get screensaverDetectionX86Unsupported =>
      'Not available on x86 devices.';

  @override
  String get settingFacePreviewTitle => 'Show camera preview';

  @override
  String get settingFacePreviewDescription =>
      'Show a small round live view of the camera in a corner of the screen for a few seconds when a face wakes the kiosk.';

  @override
  String get settingFacePreviewSecondsTitle => 'Preview duration';

  @override
  String get settingFacePreviewSecondsDescription =>
      'How long the preview stays on screen.';

  @override
  String get settingFacePreviewScaleTitle => 'Preview scaling';

  @override
  String get settingFacePreviewScaleDescription =>
      'Scale the preview to better fit your screen size.';

  @override
  String get settingFacePreviewPositionTitle => 'Preview position';

  @override
  String get settingFacePreviewPositionDescription =>
      'Which corner the preview sits in.';

  @override
  String get screensaverDetectionPreviewSection => 'Camera Preview';

  @override
  String get settingScreensaverEnabledTitle => 'Screensaver';

  @override
  String get settingScreensaverEnabledDescription =>
      'Dim or blank the screen after a period of inactivity.';

  @override
  String get settingScreensaverTimeoutSecondsTitle => 'Idle timeout (seconds)';

  @override
  String get settingScreensaverTimeoutSecondsDescription =>
      'Inactivity period before the screensaver starts.';

  @override
  String get settingScreensaverModeTitle => 'Screensaver mode';

  @override
  String get settingScreensaverModeDescription =>
      'What the screensaver shows after the idle timeout. Dim only lowers the backlight and leaves the dashboard on screen.';

  @override
  String get settingScreensaverPixelShiftTitle => 'Pixel shift';

  @override
  String get settingScreensaverPixelShiftDescription =>
      'Nudge the image every minute to protect OLED panels. Not for the black screensaver, whose pixels are already off.';

  @override
  String get settingScreensaverMenuTitle => 'Show in the kiosk menu';

  @override
  String get settingScreensaverMenuDescription =>
      'Add a Start Screensaver entry to the kiosk menu.';

  @override
  String get settingScreensaverDimLevelTitle => 'Dim level';

  @override
  String get settingScreensaverDimLevelDescription =>
      'Screen brightness while the screensaver is dimming.';

  @override
  String get settingScreensaverBrightnessEnabledTitle =>
      'Screensaver brightness';

  @override
  String get settingScreensaverBrightnessEnabledDescription =>
      'Use a separate brightness while the screensaver is showing.';

  @override
  String get settingScreensaverBrightnessLevelTitle => 'Brightness level';

  @override
  String get settingScreensaverBrightnessLevelDescription =>
      'Applies to every mode except Dim and Black.';

  @override
  String get settingScreensaverNotificationBrightnessTitle =>
      'Brighten for notifications';

  @override
  String get settingScreensaverNotificationBrightnessDescription =>
      'Lift the screensaver dimming while a notification is on screen.';

  @override
  String get settingScreensaverScreenOffMinutesTitle => 'Turn screen off after';

  @override
  String get settingScreensaverScreenOffMinutesDescription =>
      'Powers down the display panel once the screensaver has run for the set duration. Set to 0 to keep the screen on indefinitely. Requires Device Administrator permission.';

  @override
  String get settingScreensaverScreenOffWakeToScreensaverTitle =>
      'Wake to screensaver';

  @override
  String get settingScreensaverScreenOffWakeToScreensaverDescription =>
      'Motion, face, proximity or person detection after the screen has turned off brings the screensaver back instead of the dashboard, with a fresh Turn screen off after countdown. Touch still opens the dashboard.';

  @override
  String get screensaverModeDim => 'Dim';

  @override
  String get screensaverModeBlack => 'Black';

  @override
  String get screensaverModeClock => 'Clock';

  @override
  String get screensaverModeMedia => 'Home Assistant Media';

  @override
  String get screensaverModeLocal => 'Local Media';

  @override
  String get screensaverModeGallery => 'Photo Gallery';

  @override
  String get screensaverModeImmich => 'Immich Media';

  @override
  String get screensaverModeWebsite => 'Website';

  @override
  String get screensaverModeCamera => 'Camera Streams';

  @override
  String get screensaverDimSection => 'Dim screensaver';

  @override
  String get screensaverWarningTitle => 'WARNING: Please Read!';

  @override
  String get screensaverScreenOffProceed => 'Turn screen off anyway';

  @override
  String get screensaverAdminMissing =>
      'Not granted, so the screen cannot turn off.';

  @override
  String get screensaverAdminMissingRemote => 'Device admin permission missing';

  @override
  String get screensaverAdminMissingRemoteHelp =>
      'Without it the screen cannot be turned off. The grant dialog appears on the tablet screen.';

  @override
  String get screensaverDimWarning =>
      'WARNING: Dim keeps the dashboard visible, so the \"Pause dashboard during screensaver\" optimization will not be applied and the dashboard keeps using CPU, GPU and battery.';

  @override
  String get screensaverUnavailablePlugin => 'Unavailable plugin screensaver';

  @override
  String get screensaverScreenOffWarning =>
      'Once the display truly powers off, the tablet\'s own power management takes over, and many Android models misbehave in that state: Wi-Fi naps or drops, the Home Assistant entities go unavailable, the camera can be revoked, and some models kill background apps outright. What happens depends on the manufacturer.\n\nThe reliable alternative is the Black screensaver with this setting left at 0: the panel looks just as dark, and the app keeps full control.';

  @override
  String get settingScreensaverGlanceScaleTitle => 'Row scaling';

  @override
  String get settingScreensaverGlanceScaleDescription =>
      'Scale the row to better fit your screen size.';

  @override
  String get settingScreensaverGlanceFontTitle => 'Font family';

  @override
  String get settingScreensaverGlanceFontDescription =>
      'The typeface the row is drawn in.';

  @override
  String get settingScreensaverGlanceFontWeightTitle => 'Font weight';

  @override
  String get settingScreensaverGlanceFontWeightDescription =>
      'How heavy the row\'s text is drawn. Default is each line\'s own weight: regular names, semibold values.';

  @override
  String get settingScreensaverGlanceHideNamesTitle => 'Hide names';

  @override
  String get settingScreensaverGlanceHideNamesDescription =>
      'Show only the icon and the value, with the value drawn larger.';

  @override
  String get settingScreensaverGlanceBwIconsTitle => 'Monochromatic icons';

  @override
  String get settingScreensaverGlanceBwIconsDescription =>
      'Keep every icon in the neutral grey instead of its state color.';

  @override
  String get settingScreensaverGlanceTextOnlyTitle => 'Floating text style';

  @override
  String get settingScreensaverGlanceTextOnlyDescription =>
      'Show the entities as floating text instead of chips.';

  @override
  String get screensaverOverlayAppearance => 'Appearance';

  @override
  String get settingScreensaverGlanceEnabledTitle => 'At a glance';

  @override
  String get settingScreensaverGlanceEnabledDescription =>
      'Show a row of Home Assistant entity states on the screensaver.';

  @override
  String get settingScreensaverGlanceEntitiesTitle => 'Entities';

  @override
  String get settingScreensaverGlanceEntitiesDescription =>
      'Up to four entities to show, each with an optional custom name.';

  @override
  String get settingScreensaverGlanceNowPlayingTitle => 'Show on Now Playing';

  @override
  String get settingScreensaverGlanceNowPlayingDescription =>
      'Show the row on the full-screen Now Playing view. It stays hidden while lyrics are showing.';

  @override
  String get screensaverOverlayShowing => 'Showing';

  @override
  String get screensaverOverlayReorder => 'Showing (drag to reorder)';

  @override
  String get screensaverOverlayFull =>
      'That is the most the row can show. Remove one to add another.';

  @override
  String get screensaverOverlayPickerTitle => 'At a glance entities';

  @override
  String screensaverOverlayGlanceEmpty(String count) {
    return 'None yet. Up to $count entities.';
  }

  @override
  String get screensaverOverlayNone => 'None yet';

  @override
  String screensaverOverlayLimit(String count) {
    return 'Up to $count entities.';
  }

  @override
  String get screensaverOverlayGlancePage => 'At a Glance';

  @override
  String get screensaverOverlayGlanceHint =>
      'Entities shown over the screensaver';

  @override
  String get settingScreensaverImmichUrlTitle => 'Server address';

  @override
  String get settingScreensaverImmichUrlDescription =>
      'The address of your Immich server, with its port.';

  @override
  String get settingScreensaverImmichApiKeyTitle => 'API key';

  @override
  String get settingScreensaverImmichApiKeyDescription =>
      'Created in Immich under Account Settings → API Keys.';

  @override
  String get screensaverMediaImmichPage => 'Immich Media screensaver';

  @override
  String get screensaverMediaImmichHint =>
      'Server, media, slideshow, metadata, filters';

  @override
  String get screensaverMediaServerConnection => 'Server Connection';

  @override
  String get screensaverMediaValidateFailedLog =>
      'Validation failed. See the app log for the failing call.';

  @override
  String get screensaverMediaValidateFailed => 'Validation failed.';

  @override
  String get screensaverMediaNoAnswer => 'The device did not answer.';

  @override
  String get screensaverMediaAddressFirst => 'Enter the server address first.';

  @override
  String get screensaverMediaKeyFirst => 'Enter an API key first.';

  @override
  String get screensaverMediaBadAddress =>
      'The server address is not a valid URL.';

  @override
  String get screensaverMediaKeyRejected => 'The API key was rejected.';

  @override
  String screensaverMediaScopeMissing(String scope) {
    return 'The API key is missing the $scope permission.';
  }

  @override
  String screensaverMediaPermissionMissing(String error) {
    return 'The API key is missing a permission: $error';
  }

  @override
  String screensaverMediaServerError(String status, String error) {
    return 'The server answered $status: $error';
  }

  @override
  String screensaverMediaUnreachable(String url) {
    return 'Could not reach $url.';
  }

  @override
  String screensaverMediaTalkError(String error) {
    return 'Could not talk to the server: $error';
  }

  @override
  String get settingScreensaverImmichPeopleTitle => 'People';

  @override
  String get settingScreensaverImmichPeopleDescription =>
      'Show only media with any of these people.';

  @override
  String get settingScreensaverImmichExcludePeopleTitle => 'Exclude people';

  @override
  String get settingScreensaverImmichExcludePeopleDescription =>
      'Skip media with any of these people.';

  @override
  String get settingScreensaverImmichTagsTitle => 'Tags';

  @override
  String get settingScreensaverImmichTagsDescription =>
      'Show only media with any of these tags.';

  @override
  String get settingScreensaverImmichFavoritesOnlyTitle => 'Favorites only';

  @override
  String get settingScreensaverImmichFavoritesOnlyDescription =>
      'Show only media marked as favorite.';

  @override
  String get settingScreensaverImmichTakenWithinTitle => 'Taken within';

  @override
  String get settingScreensaverImmichTakenWithinDescription =>
      'Only show media taken in this window.';

  @override
  String get settingScreensaverImmichTakenFromTitle => 'From';

  @override
  String get settingScreensaverImmichTakenFromDescription =>
      'Skip media taken before this date.';

  @override
  String get settingScreensaverImmichTakenToTitle => 'To';

  @override
  String get settingScreensaverImmichTakenToDescription =>
      'Skip media taken after this date. The day itself counts.';

  @override
  String get screensaverMediaFilters => 'Filters';

  @override
  String get screensaverMediaAnyone => 'Anyone';

  @override
  String get screensaverMediaAnyoneDevice => 'Anyone.';

  @override
  String get screensaverMediaNoOne => 'No one';

  @override
  String get screensaverMediaNoOneDevice => 'No one.';

  @override
  String get screensaverMediaAny => 'Any';

  @override
  String get screensaverMediaAnyDevice => 'Any.';

  @override
  String get screensaverMediaNoPeople =>
      'No named people yet. Name them in Immich first.';

  @override
  String get screensaverMediaNoTags =>
      'No tags yet. Create them in Immich first.';

  @override
  String get screensaverMediaPeopleFailed => 'Could not list the people';

  @override
  String get screensaverMediaTagsFailed => 'Could not list the tags';

  @override
  String get screensaverMediaHidden => 'Hidden';

  @override
  String get screensaverMediaAnyTime => 'Any time';

  @override
  String get screensaverMediaPastMonth => 'Past month';

  @override
  String get screensaverMediaPast3Months => 'Past 3 months';

  @override
  String get screensaverMediaPastYear => 'Past year';

  @override
  String get screensaverMediaPast2Years => 'Past 2 years';

  @override
  String get screensaverMediaPast5Years => 'Past 5 years';

  @override
  String get screensaverMediaPast10Years => 'Past 10 years';

  @override
  String get screensaverMediaSince => 'Since';

  @override
  String get screensaverMediaTimeframe => 'Timeframe';

  @override
  String get screensaverMediaToday => 'Today';

  @override
  String get screensaverMediaDateFormat => 'Use YYYY-MM-DD.';

  @override
  String get screensaverMediaNotDate => 'That is not a date.';

  @override
  String get settingScreensaverImmichMetadataTitle => 'Show metadata';

  @override
  String get settingScreensaverImmichMetadataDescription =>
      'Album, date, camera and location over the media.';

  @override
  String get settingScreensaverImmichMetadataAlbumTitle => 'Album name';

  @override
  String get settingScreensaverImmichMetadataAlbumDescription =>
      'Show which album the photo comes from.';

  @override
  String get settingScreensaverImmichMetadataDateTitle => 'Date taken';

  @override
  String get settingScreensaverImmichMetadataDateDescription =>
      'Show when the photo was taken.';

  @override
  String get settingScreensaverImmichMetadataCameraTitle => 'Camera details';

  @override
  String get settingScreensaverImmichMetadataCameraDescription =>
      'Show focal length, aperture and ISO.';

  @override
  String get settingScreensaverImmichMetadataLocationTitle => 'Location';

  @override
  String get settingScreensaverImmichMetadataLocationDescription =>
      'Show the place the photo was taken.';

  @override
  String get settingScreensaverImmichMetadataPositionTitle =>
      'Metadata position';

  @override
  String get settingScreensaverImmichMetadataPositionDescription =>
      'Which corner the details sit in.';

  @override
  String get settingScreensaverImmichMetadataTextShadowTitle =>
      'Text drop shadow';

  @override
  String get settingScreensaverImmichMetadataTextShadowDescription =>
      'Add a drop shadow to metadata text for readability on photos.';

  @override
  String get settingScreensaverImmichMetadataScaleTitle => 'Text scaling';

  @override
  String get settingScreensaverImmichMetadataScaleDescription =>
      'Scale the photo details to better fit your screen size.';

  @override
  String get settingScreensaverImmichVignetteStrengthTitle =>
      'Vignette strength';

  @override
  String get settingScreensaverImmichVignetteStrengthDescription =>
      'Darkness of the shading behind the details, for readability on bright photos. 0 turns it off.';

  @override
  String get screensaverMediaMetadata => 'Metadata';

  @override
  String get screensaverMediaTopLeft => 'Top left';

  @override
  String get screensaverMediaTopRight => 'Top right';

  @override
  String get screensaverMediaBottomLeft => 'Bottom left';

  @override
  String get screensaverMediaBottomRight => 'Bottom right';

  @override
  String get settingScreensaverImmichIntervalTitle => 'Seconds per image';

  @override
  String get settingScreensaverImmichIntervalDescription =>
      'How long each image shows before the next. Videos play in full.';

  @override
  String get settingScreensaverImmichShuffleTitle => 'Shuffle';

  @override
  String get settingScreensaverImmichShuffleDescription =>
      'Cycle the media in random order.';

  @override
  String get settingScreensaverImmichTransitionTitle => 'Transition';

  @override
  String get settingScreensaverImmichTransitionDescription =>
      'How one item hands off to the next.';

  @override
  String get settingScreensaverImmichFillTitle => 'Fill the screen';

  @override
  String get settingScreensaverImmichFillDescription =>
      'Off keeps the whole photo between black bars. Smart enlarges photos shaped close to the screen, framing the rest over a blurred backdrop. Always enlarges every photo, cutting off what does not fit.';

  @override
  String get settingScreensaverImmichPairPortraitTitle =>
      'Pair portrait photos';

  @override
  String get settingScreensaverImmichPairPortraitDescription =>
      'Show two portrait photos side by side so they fill the screen.';

  @override
  String get settingScreensaverImmichEdgeTapsTitle =>
      'Tap edges to change slides';

  @override
  String get settingScreensaverImmichEdgeTapsDescription =>
      'A tap on the left or right fifth of the screen shows the previous or next slide instead of dismissing.';

  @override
  String get screensaverMediaSlideshow => 'Slideshow';

  @override
  String get settingScreensaverImmichAlbumTitle => 'Media source';

  @override
  String get settingScreensaverImmichAlbumDescription =>
      'The whole library, or the albums you pick.';

  @override
  String get settingScreensaverImmichPhotosOnlyTitle => 'Photos only';

  @override
  String get settingScreensaverImmichPhotosOnlyDescription =>
      'Skip videos in the slideshow.';

  @override
  String get settingScreensaverImmichCacheTitle => 'Cache media locally';

  @override
  String get settingScreensaverImmichCacheDescription =>
      'Keep copies on the device so images load instantly.';

  @override
  String get settingScreensaverImmichCacheMaxTitle => 'Cache size (items)';

  @override
  String get settingScreensaverImmichCacheMaxDescription =>
      'The oldest items are deleted once the cache is full.';

  @override
  String get screensaverMediaAll => 'All media';

  @override
  String get screensaverMediaAllDevice => 'All media.';

  @override
  String get screensaverMediaNoAlbums =>
      'No albums yet. Create one in Immich first.';

  @override
  String get screensaverMediaAlbumsFailed => 'Could not list the albums';

  @override
  String screensaverMediaListError(String error) {
    return 'Could not list them: $error';
  }

  @override
  String get screensaverMediaListingFailed => 'listing failed';

  @override
  String screensaverMediaItems(String count) {
    return '$count items';
  }

  @override
  String screensaverMediaCached(String count, String size) {
    return '$count cached, $size';
  }

  @override
  String get settingScreensaverCameraViewsTitle => 'Camera views';

  @override
  String get settingScreensaverCameraViewsDescription =>
      'The camera views the screensaver shows, in this order.';

  @override
  String get settingScreensaverCameraViewSecondsTitle =>
      'Seconds per camera view';

  @override
  String get settingScreensaverCameraViewSecondsDescription =>
      'How long each view stays on screen before the next one. With a single view selected nothing rotates.';

  @override
  String get settingScreensaverCameraMuteTitle => 'Mute all views';

  @override
  String get settingScreensaverCameraMuteDescription =>
      'Keeps every view silent, even a single camera.';

  @override
  String get screensaverMediaCameraPage => 'Camera Streams screensaver';

  @override
  String get screensaverMediaCameraHint =>
      'Views to show, seconds per view, sound';

  @override
  String get screensaverMediaNoCameras =>
      'No camera view has cameras yet. Add one under Camera Streams.';

  @override
  String get screensaverMediaNoCamerasRemote =>
      'No camera view has cameras yet';

  @override
  String get screensaverMediaAddCameras => 'Add one under Camera Streams.';

  @override
  String get screensaverMediaNoViews =>
      'None yet. Pick the views the screensaver cycles through.';

  @override
  String get screensaverMediaRotation => 'In the rotation (drag to reorder)';

  @override
  String get screensaverMediaAvailable => 'Available';

  @override
  String screensaverMediaOneCamera(String count) {
    return '$count camera';
  }

  @override
  String screensaverMediaCameras(String count) {
    return '$count cameras';
  }

  @override
  String screensaverMediaPosition(String index, String cameras) {
    return 'Position $index · $cameras';
  }

  @override
  String get screensaverMediaTransitionNone => 'None';

  @override
  String get screensaverMediaTransitionFade => 'Crossfade';

  @override
  String get screensaverMediaTransitionSlide => 'Slide';

  @override
  String get screensaverMediaTransitionZoom => 'Zoom';

  @override
  String get screensaverMediaTransitionKenBurns => 'Ken Burns';

  @override
  String get screensaverMediaTransitionRandom => 'Random';

  @override
  String get screensaverMediaFillOff => 'Off';

  @override
  String get screensaverMediaFillSmart => 'Smart';

  @override
  String get screensaverMediaFillAlways => 'Always';

  @override
  String get settingScreensaverGalleryItemsTitle => 'Photos';

  @override
  String get settingScreensaverGalleryItemsDescription =>
      'The photos and videos this screensaver cycles. Picked from the gallery on the device; picking again replaces the selection.';

  @override
  String get settingScreensaverGalleryIntervalTitle => 'Seconds per photo';

  @override
  String get settingScreensaverGalleryIntervalDescription =>
      'How long each photo shows before the next. Videos play in full.';

  @override
  String get settingScreensaverGalleryShuffleTitle => 'Shuffle';

  @override
  String get settingScreensaverGalleryShuffleDescription =>
      'Cycle the selection in random order.';

  @override
  String get settingScreensaverGalleryTransitionTitle => 'Transition';

  @override
  String get settingScreensaverGalleryTransitionDescription =>
      'How one photo hands off to the next.';

  @override
  String get settingScreensaverGalleryFillTitle => 'Fill the screen';

  @override
  String get settingScreensaverGalleryFillDescription =>
      'Off keeps the whole photo between black bars. Smart enlarges photos shaped close to the screen, framing the rest over a blurred backdrop. Always enlarges every photo, cutting off what does not fit.';

  @override
  String get settingScreensaverGalleryEdgeTapsTitle =>
      'Tap edges to change slides';

  @override
  String get settingScreensaverGalleryEdgeTapsDescription =>
      'A tap on the left or right fifth of the screen shows the previous or next slide instead of dismissing.';

  @override
  String get screensaverMediaGalleryPage => 'Photo Gallery screensaver';

  @override
  String get screensaverMediaGalleryHint =>
      'Photos, timing, shuffle, transition';

  @override
  String get screensaverMediaLoadingPhotos => 'Loading photos...';

  @override
  String screensaverMediaCopying(String index, String total) {
    return 'Copying photo $index of $total...';
  }

  @override
  String get screensaverMediaCopyFailed => 'Could not copy the photos';

  @override
  String get screensaverMediaSmallerSelection => 'Try a smaller selection.';

  @override
  String get screensaverMediaNoPhotos => 'No photos selected';

  @override
  String screensaverMediaSelected(String count) {
    return '$count selected';
  }

  @override
  String get screensaverMediaPickOnDevice =>
      'None selected. Pick on the device.';

  @override
  String get settingScreensaverMediaIdTitle => 'Media source';

  @override
  String get settingScreensaverMediaIdDescription =>
      'A Home Assistant media item, folder, or camera. Use Browse to pick one.';

  @override
  String get settingScreensaverMediaIntervalTitle => 'Seconds per image';

  @override
  String get settingScreensaverMediaIntervalDescription =>
      'How long each image shows before the next. Videos play in full.';

  @override
  String get settingScreensaverMediaShuffleTitle => 'Shuffle';

  @override
  String get settingScreensaverMediaShuffleDescription =>
      'Play a folder in random order.';

  @override
  String get settingScreensaverMediaRecursiveTitle => 'Include subfolders';

  @override
  String get settingScreensaverMediaRecursiveDescription =>
      'Descend into subfolders when a folder is chosen.';

  @override
  String get settingScreensaverMediaTransitionTitle => 'Transition';

  @override
  String get settingScreensaverMediaTransitionDescription =>
      'How one item hands off to the next.';

  @override
  String get settingScreensaverMediaFillTitle => 'Fill the screen';

  @override
  String get settingScreensaverMediaFillDescription =>
      'Off keeps the whole photo between black bars. Smart enlarges photos shaped close to the screen, framing the rest over a blurred backdrop. Always enlarges every photo, cutting off what does not fit.';

  @override
  String get settingScreensaverMediaEdgeTapsTitle =>
      'Tap edges to change slides';

  @override
  String get settingScreensaverMediaEdgeTapsDescription =>
      'A tap on the left or right fifth of the screen shows the previous or next slide instead of dismissing.';

  @override
  String get screensaverMediaHaPage => 'Home Assistant Media screensaver';

  @override
  String get screensaverMediaHaHint => 'Media source, timing, shuffle, fill';

  @override
  String get screensaverMediaChoose => 'Choose media';

  @override
  String get screensaverMediaRoot => 'Media';

  @override
  String get screensaverMediaHaUnavailable =>
      'Could not reach Home Assistant, or the token is missing.';

  @override
  String get screensaverMediaEmpty => 'Nothing here.';

  @override
  String get screensaverMediaUseFolder => 'Use this folder';

  @override
  String get screensaverMediaFolder => 'folder';

  @override
  String get screensaverMediaCamera => 'camera';

  @override
  String get screensaverMediaItem => 'item';

  @override
  String get screensaverMediaBrowseFailed => 'browse failed';

  @override
  String screensaverMediaBrowseError(String error) {
    return 'Could not browse: $error';
  }

  @override
  String get screensaverMediaNotSet => 'Not set';

  @override
  String get settingScreensaverLocalFolderTitle => 'Local folder';

  @override
  String get settingScreensaverLocalFolderDescription =>
      'Folder on this device whose photos and videos the screensaver cycles through. Picked on the device; the path can also be typed here remotely.';

  @override
  String get settingScreensaverLocalIntervalTitle => 'Seconds per photo';

  @override
  String get settingScreensaverLocalIntervalDescription =>
      'How long each photo shows before the next. Videos play in full.';

  @override
  String get settingScreensaverLocalShuffleTitle => 'Shuffle';

  @override
  String get settingScreensaverLocalShuffleDescription =>
      'Cycle the folder in random order instead of by name.';

  @override
  String get settingScreensaverLocalRecursiveTitle => 'Include subfolders';

  @override
  String get settingScreensaverLocalRecursiveDescription =>
      'Also cycle photos and videos inside subfolders.';

  @override
  String get settingScreensaverLocalTransitionTitle => 'Transition';

  @override
  String get settingScreensaverLocalTransitionDescription =>
      'How one photo hands off to the next.';

  @override
  String get settingScreensaverLocalFillTitle => 'Fill the screen';

  @override
  String get settingScreensaverLocalFillDescription =>
      'Off keeps the whole photo between black bars. Smart enlarges photos shaped close to the screen, framing the rest over a blurred backdrop. Always enlarges every photo, cutting off what does not fit.';

  @override
  String get settingScreensaverLocalEdgeTapsTitle =>
      'Tap edges to change slides';

  @override
  String get settingScreensaverLocalEdgeTapsDescription =>
      'A tap on the left or right fifth of the screen shows the previous or next slide instead of dismissing.';

  @override
  String get screensaverMediaLocalPage => 'Local Media screensaver';

  @override
  String get screensaverMediaLocalHint => 'Folder, timing, shuffle, transition';

  @override
  String get settingScreensaverDismissOnMotionTitle => 'Dismiss on motion';

  @override
  String get settingScreensaverDismissOnMotionDescription =>
      'Watch the camera while the screensaver is up and wake the screen when someone approaches. The camera runs only during the screensaver.';

  @override
  String get settingScreensaverDismissOnMotionScreenOffOnlyTitle =>
      'Only when screen is off';

  @override
  String get settingScreensaverDismissOnMotionScreenOffOnlyDescription =>
      'Keep the screensaver visible when motion is detected while the screen is on. Once the screen turns off, detection wakes the dashboard. Touch still dismisses the screensaver.';

  @override
  String get settingScreensaverPostponeOnMotionTitle =>
      'Postpone screensaver on motion';

  @override
  String get settingScreensaverPostponeOnMotionDescription =>
      'Delay activating the screensaver when motion is detected. WARNING: Keeps the camera running permanently.';

  @override
  String get screensaverDetectionMotionPage => 'Motion Detection';

  @override
  String get screensaverDetectionMotionHint =>
      'Dismiss or postpone the screensaver on motion';

  @override
  String get screensaverDetectionMotionTuning =>
      'Motion detection is tuned in the Camera settings.';

  @override
  String get settingScreensaverDismissOnPersonTitle => 'Dismiss on person';

  @override
  String get settingScreensaverDismissOnPersonDescription =>
      'Read the device\'s person sensor while the screensaver is up and wake the screen when someone is in front of it. Needs the Log access grant below.';

  @override
  String get settingScreensaverDismissOnPersonScreenOffOnlyTitle =>
      'Only when screen is off';

  @override
  String get settingScreensaverDismissOnPersonScreenOffOnlyDescription =>
      'Keep the screensaver visible when someone arrives while the screen is on. Once the screen turns off, detection wakes the dashboard. Touch still dismisses the screensaver.';

  @override
  String get settingScreensaverPostponeOnPersonTitle =>
      'Postpone screensaver on person';

  @override
  String get settingScreensaverPostponeOnPersonDescription =>
      'Delay activating the screensaver while someone is in front of the device.';

  @override
  String get screensaverDetectionPersonPage => 'Person Detection';

  @override
  String get screensaverDetectionPersonHint =>
      'Dismiss or postpone the screensaver on the device\'s person sensor';

  @override
  String get screensaverDetectionOccupancy => 'Occupancy';

  @override
  String get screensaverDetectionStatusUnavailable => 'Status unavailable.';

  @override
  String get screensaverDetectionOff => 'Off.';

  @override
  String get screensaverDetectionStarting => 'Starting...';

  @override
  String get screensaverDetectionWaiting =>
      'Waiting for the first heartbeat. The sensor reports every 30 seconds while someone is in view.';

  @override
  String screensaverDetectionLastHeartbeat(String ago) {
    return 'Last heartbeat $ago.';
  }

  @override
  String screensaverDetectionSecondsAgo(String count) {
    return '${count}s ago';
  }

  @override
  String screensaverDetectionMinutesAgo(String count) {
    return '$count min ago';
  }

  @override
  String screensaverDetectionHoursAgo(String count) {
    return '$count h ago';
  }

  @override
  String get screensaverDetectionDetected => 'Detected';

  @override
  String get screensaverDetectionClear => 'Clear';

  @override
  String get screensaverDetectionPermissions => 'Required system permissions';

  @override
  String get screensaverDetectionLogAccess => 'Log access';

  @override
  String get screensaverDetectionChecking => 'Checking...';

  @override
  String get screensaverDetectionReadable =>
      'The device\'s person sensor can be read.';

  @override
  String get screensaverDetectionRestartRequired =>
      'Granted. Restart Kiosk Satellite to apply it.';

  @override
  String get screensaverDetectionGrantHelp =>
      'This permission can only be granted via ADB. The Meta Portal doc has the full command. Restart Kiosk Satellite afterwards.';

  @override
  String get screensaverDetectionGrantRemoteHelp =>
      'This permission can only be granted via ADB. Below is the full command, ready to be copied. Restart Kiosk Satellite afterwards.';

  @override
  String get screensaverDetectionGranted => 'Granted';

  @override
  String get screensaverDetectionMissing => 'Missing';

  @override
  String get screensaverDetectionRestart => 'Restart';

  @override
  String get screensaverDetectionRestartRemote => 'Restart on device';

  @override
  String get screensaverDetectionLogRestart =>
      'Log access is granted but takes effect when Kiosk Satellite restarts.';

  @override
  String get screensaverDetectionLogMissing => 'Log access not granted.';

  @override
  String get settingScreensaverDismissOnProximityTitle =>
      'Dismiss on proximity';

  @override
  String get settingScreensaverDismissOnProximityDescription =>
      'Watch the proximity sensor while the screensaver is up and wake the screen when something comes close to the device. A device with only sensors made for calls (\"palm\", \"touch\") will not work.';

  @override
  String get settingScreensaverDismissOnProximityScreenOffOnlyTitle =>
      'Only when screen is off';

  @override
  String get settingScreensaverDismissOnProximityScreenOffOnlyDescription =>
      'Keep the screensaver visible when something approaches while the screen is on. Once the screen turns off, detection wakes the dashboard. Touch still dismisses the screensaver.';

  @override
  String get settingScreensaverPostponeOnProximityTitle =>
      'Postpone screensaver on proximity';

  @override
  String get settingScreensaverPostponeOnProximityDescription =>
      'Delay activating the screensaver while something is close to the sensor.';

  @override
  String get screensaverDetectionProximityPage => 'Proximity Detection';

  @override
  String get screensaverDetectionProximityHint =>
      'Dismiss or postpone the screensaver on the proximity sensor';

  @override
  String get screensaverDetectionNoProximity =>
      'Not available on this device: it has no proximity sensor.';

  @override
  String get screensaverDetectionSensor => 'Sensor';

  @override
  String get screensaverDetectionSensorHelp =>
      'What the device reports as the proximity sensor. A sensor made for calls named \"palm\" or \"touch\" will not work.';

  @override
  String get settingScreensaverScheduleEnabledTitle =>
      'Enable scheduled screensavers';

  @override
  String get settingScreensaverScheduleEnabledDescription =>
      'Switch to a different screensaver at set times of day.';

  @override
  String get settingScreensaverScheduleTitle => 'Times';

  @override
  String get settingScreensaverScheduleDescription =>
      'Each time switches the screensaver from then on.';

  @override
  String get screensaverScheduleSection => 'Scheduled Screensavers';

  @override
  String get screensaverTime => 'Time';

  @override
  String get screensaverAddTime => 'Add time';

  @override
  String get screensaverRemoveTime => 'Remove time';

  @override
  String get screensaverNoTimes => 'No times yet';

  @override
  String get screensaverTimeHelp => 'A screensaver from that time on.';

  @override
  String get screensaverPickTime => 'Pick a time.';

  @override
  String get screensaverDefault => 'Default';

  @override
  String get screensaverOn => 'On';

  @override
  String get screensaverOff => 'Off';

  @override
  String get screensaverBrightness => 'Brightness';

  @override
  String get screensaverBrightnessFollow =>
      'Follows the Screensaver brightness setting.';

  @override
  String get screensaverBrightnessExceptBlack =>
      'Applies to every mode except Black.';

  @override
  String get screensaverScreenOffFollow =>
      'Follows the Turn screen off after setting.';

  @override
  String get screensaverScreenOnHours =>
      'Keeps the screen on during these hours.';

  @override
  String get screensaverScreenOffHelp =>
      'Powers down the display once the screensaver has run this long. Requires Device Administrator permission.';

  @override
  String get screensaverScreenOffNever => 'Screen off never';

  @override
  String get screensaverMotion => 'Dismiss on motion';

  @override
  String get screensaverFace => 'Dismiss on face';

  @override
  String get screensaverProximity => 'Dismiss on proximity';

  @override
  String get screensaverPerson => 'Dismiss on person';

  @override
  String get screensaverWidgets => 'Widgets';

  @override
  String get screensaverGlance => 'At a glance';

  @override
  String get screensaverNowPlaying =>
      'Show Now Playing next to the screensaver';

  @override
  String get screensaverNowPlayingHelp =>
      'Default follows the global layout. On uses a shared layout when Now Playing is enabled. Off hides Now Playing during these hours.';

  @override
  String get screensaverCameraRequired =>
      'Requires the camera. Turn it on in the Camera settings first.';

  @override
  String get screensaverNotAvailable => 'Not available on this device.';

  @override
  String get screensaverSummaryMotionOn => 'Motion on';

  @override
  String get screensaverSummaryMotionOff => 'Motion off';

  @override
  String get screensaverSummaryFaceOn => 'Face on';

  @override
  String get screensaverSummaryFaceOff => 'Face off';

  @override
  String get screensaverSummaryProximityOn => 'Proximity on';

  @override
  String get screensaverSummaryProximityOff => 'Proximity off';

  @override
  String get screensaverSummaryPersonOn => 'Person on';

  @override
  String get screensaverSummaryPersonOff => 'Person off';

  @override
  String get screensaverSummaryWidgetsOn => 'Widgets on';

  @override
  String get screensaverSummaryWidgetsOff => 'Widgets off';

  @override
  String get screensaverSummaryGlanceOn => 'At a glance on';

  @override
  String get screensaverSummaryGlanceOff => 'At a glance off';

  @override
  String get screensaverSummaryNowPlayingOn => 'Now Playing on';

  @override
  String get screensaverSummaryNowPlayingOff => 'Now Playing off';

  @override
  String screensaverBrightnessPercent(String percent) {
    return '$percent% brightness';
  }

  @override
  String screensaverScreenOffAfter(String minutes) {
    return 'Screen off after $minutes min';
  }

  @override
  String get settingScreensaverWebsiteUrlTitle => 'Website URL';

  @override
  String get settingScreensaverWebsiteUrlDescription =>
      'A page to show full-screen. It must allow being embedded.';

  @override
  String get settingScreensaverWebsiteZoomTitle => 'Zoom level';

  @override
  String get settingScreensaverWebsiteZoomDescription =>
      'Scales the whole external screensaver webview.';

  @override
  String get settingScreensaverWebsiteDoubleTapTitle => 'Double tap to dismiss';

  @override
  String get settingScreensaverWebsiteDoubleTapDescription =>
      'Single taps interact with the website instead of dismissing.';

  @override
  String get screensaverWebsiteSection => 'Website screensaver';

  @override
  String get screensaverOverlaySmallClock => 'Small clock';

  @override
  String get screensaverOverlayWeather => 'Weather';

  @override
  String get screensaverOverlayBattery => 'Battery';

  @override
  String get screensaverOverlayClockNote =>
      'Hidden in Digital Clock and Camera Streams screensaver modes.';

  @override
  String get screensaverOverlayCameraNote =>
      'Hidden in the Camera Streams screensaver mode.';

  @override
  String get screensaverOverlayScale => 'Scale';

  @override
  String get screensaverOverlayScaleHelp =>
      'Scale this widget size to better fit your screen.';

  @override
  String get screensaverOverlayFont => 'Font family';

  @override
  String get screensaverOverlayCorner => 'Corner';

  @override
  String get screensaverOverlayWidget => 'Widget';

  @override
  String get screensaverOverlayClock24 => '24-hour clock';

  @override
  String get screensaverOverlayClock24Help =>
      'Show a 24-hour time instead of AM/PM.';

  @override
  String get screensaverOverlayShowDate => 'Show date';

  @override
  String get screensaverOverlayShowDateHelp =>
      'Add a short date under the clock.';

  @override
  String get screensaverOverlayPercentage => 'Show percentage';

  @override
  String get screensaverOverlayPercentageHelp => 'The charge beside the icon.';

  @override
  String get screensaverOverlayLow => 'Only when low';

  @override
  String get screensaverOverlayLowHelp =>
      'Stay hidden until the charge drops to 20 percent.';

  @override
  String get screensaverOverlayShowName => 'Show name';

  @override
  String get screensaverOverlayShowNameHelp => 'The name under the value.';

  @override
  String get screensaverOverlayFontSystem => 'System';

  @override
  String get screensaverOverlayFontSerif => 'Serif';

  @override
  String get screensaverOverlayFontCondensed => 'Condensed';

  @override
  String get screensaverOverlayFontMonospace => 'Monospace';

  @override
  String get screensaverOverlayFontCasual => 'Casual';

  @override
  String get screensaverOverlayFontCursive => 'Cursive';

  @override
  String get screensaverOverlayColor => 'Color';

  @override
  String get screensaverOverlayWeatherEntity => 'Weather entity';

  @override
  String get screensaverOverlayNoWeather => 'No weather entities';

  @override
  String get screensaverOverlayNoWeatherHelp => 'Home Assistant reported none.';

  @override
  String get screensaverOverlayPickWeather => 'Pick a weather entity…';

  @override
  String get screensaverOverlayWeatherRequired => 'Pick a weather entity.';

  @override
  String get screensaverOverlayLocationName => 'Location name';

  @override
  String get screensaverOverlayLocationHelp =>
      'Leave empty to hide the location line.';

  @override
  String get screensaverOverlayLocation => 'Location';

  @override
  String get screensaverOverlayLocationDetail =>
      'The place\'s name over the temperature.';

  @override
  String get screensaverOverlayFeelsLike => 'Feels like';

  @override
  String get screensaverOverlayFeelsLikeHelp =>
      'The apparent temperature after the real one, \"30° / 33°\".';

  @override
  String get screensaverOverlayFeelsLikeOnly => 'Feels like only';

  @override
  String get screensaverOverlayFeelsLikeOnlyHelp =>
      'The apparent temperature in the real one\'s place.';

  @override
  String get screensaverOverlayForecast => 'Forecast';

  @override
  String get screensaverOverlayForecastHelp =>
      'The conditions, with a matching icon.';

  @override
  String get screensaverOverlayHumidity => 'Humidity';

  @override
  String get screensaverOverlayWind => 'Wind speed';

  @override
  String get screensaverOverlayVisibility => 'Visibility';

  @override
  String get settingScreensaverWidgetsTitle => 'Widgets';

  @override
  String get settingScreensaverWidgetsDescription =>
      'Small overlays in the corners of the screensaver.';

  @override
  String get settingScreensaverWidgetScaleTitle => 'Global widget scaling';

  @override
  String get settingScreensaverWidgetScaleDescription =>
      'Scale all widgets together to better fit your screen size. Each widget keeps its own scale relative to the others.';

  @override
  String get settingScreensaverWidgetFontTitle => 'Global font family';

  @override
  String get settingScreensaverWidgetFontDescription =>
      'The typeface every widget is drawn in. A widget can pick its own.';

  @override
  String get settingScreensaverWidgetFontWeightTitle => 'Global font weight';

  @override
  String get settingScreensaverWidgetFontWeightDescription =>
      'How heavy every widget\'s text is drawn. Default is each line\'s own weight. A widget can pick its own.';

  @override
  String get settingScreensaverWidgetTextShadowTitle => 'Text drop shadow';

  @override
  String get settingScreensaverWidgetTextShadowDescription =>
      'Add a drop shadow to widget text for readability on photos.';

  @override
  String get settingScreensaverVignetteStrengthTitle => 'Vignette strength';

  @override
  String get settingScreensaverVignetteStrengthDescription =>
      'Darkness of the shading behind the widgets, for readability on bright photos. 0 turns it off.';

  @override
  String get screensaverOverlayWidgetsEmpty => 'No widgets yet';

  @override
  String get screensaverOverlayRemove => 'Remove widget';

  @override
  String get screensaverOverlayAdd => 'Add widget';

  @override
  String get screensaverOverlayAddHelp =>
      'A small clock, the weather, the battery or an entity in a corner.';

  @override
  String get screensaverOverlayWidgetsHint => 'Corner overlays and their scale';

  @override
  String get settingsSearchHint => 'Search settings';

  @override
  String get settingsSearchClear => 'Clear search';

  @override
  String get settingsSearchResults => 'Search results';

  @override
  String settingsSearchEmpty(String query) {
    return 'No settings match \"$query\".';
  }

  @override
  String get setupConnectHeading => 'Connect to Home Assistant';

  @override
  String get setupConnectLead =>
      'The base URL of your instance and a long-lived access token, created under your HA profile → Security → Long-lived access tokens.';

  @override
  String get setupBaseUrl => 'Home Assistant base URL';

  @override
  String get setupToken => 'Long-lived access token';

  @override
  String get setupScanQr => 'Scan the QR code';

  @override
  String get setupInvalidToken => 'Invalid access token';

  @override
  String get setupInvalidTokenHelp =>
      'Home Assistant rejected this token. In Home Assistant, open your profile → Security → Long-lived access tokens, create a new token and copy the complete value.';

  @override
  String get setupUnreachable => 'Can\'t reach Home Assistant';

  @override
  String get setupUnreachableHelp =>
      'No response from this address. Check that the URL is correct and that this device is on the same network as your Home Assistant server.';

  @override
  String get setupUnexpectedResponseHelp =>
      'A server responded, but it doesn\'t appear to be Home Assistant. Check that the URL is your Home Assistant base address, for example https://homeassistant.local:8123.';

  @override
  String get setupCannotConnect => 'Can\'t connect';

  @override
  String get setupCameraPermission => 'Camera permission needed';

  @override
  String get setupCameraBlocked =>
      'Allow the camera for Kiosk Satellite in the Android settings to scan the QR code.';

  @override
  String get setupCameraAllow => 'Allow the camera to scan the QR code.';

  @override
  String get setupEnterBaseUrl => 'Enter your Home Assistant base URL';

  @override
  String get setupInvalidBaseUrl => 'Invalid base URL';

  @override
  String get setupBaseUrlHelp =>
      'This is the address you use to open Home Assistant, for example https://homeassistant.local:8123.';

  @override
  String get setupEnterToken => 'Enter a long-lived access token';

  @override
  String get setupEnterTokenHelp =>
      'In Home Assistant, open your profile → Security → Long-lived access tokens to create one.';

  @override
  String get setupValidateContinue => 'Validate & continue';

  @override
  String setupUnexpectedResponse(String error) {
    return 'Unexpected response ($error)';
  }

  @override
  String get baseUrlInvalid =>
      'Enter a valid URL, for example https://homeassistant.local:8123';

  @override
  String get baseUrlPath =>
      'Enter only the base URL, without a dashboard path. Example: https://homeassistant.local:8123';

  @override
  String get baseUrlQuery =>
      'Enter only the base URL, without anything after the port. Example: https://homeassistant.local:8123';

  @override
  String get setupWelcome => 'Welcome';

  @override
  String get setupConnect => 'Connect';

  @override
  String get setupConnectSummary => 'Home Assistant URL & token';

  @override
  String get setupDashboard => 'Dashboard';

  @override
  String get setupDashboardSummary => 'What the kiosk shows';

  @override
  String get setupRecommendedSummary => 'Recommended settings';

  @override
  String get setupPermissions => 'Permissions';

  @override
  String get setupPermissionsSummary => 'What the setup needs';

  @override
  String get setupRemoteHeading => 'Remote administration';

  @override
  String get setupTitle => 'Set up\nKiosk Satellite';

  @override
  String get setupWelcomeLead =>
      'Turn this tablet into a Home Assistant kiosk. Setup takes a couple of minutes and this wizard walks you through it.';

  @override
  String get setupDeviceName => 'Device name';

  @override
  String get setupDeviceNameHelp =>
      'How this kiosk is called in Home Assistant, in the remote admin and on the network. Change it any time under Settings, Device.';

  @override
  String get setupEnableRemote => 'Enable remote administration';

  @override
  String get setupEnableRemoteHelp =>
      'Keep managing this kiosk from a web browser after setup, where pasting the Home Assistant access token is much easier.';

  @override
  String get setupRemotePassword => 'Remote admin password';

  @override
  String get setupRestoreHeading => 'Restore backup';

  @override
  String get setupRestore => 'Restore from configuration file';

  @override
  String get setupRestoreHelp =>
      'Import a configuration exported from Kiosk Satellite and skip the rest of this wizard. Settings, dashboard and login all come along.';

  @override
  String get setupServicePermissions => 'Recommended Service Permissions';

  @override
  String get setupPasswordShort => 'Password too short';

  @override
  String get setupPasswordMinimum => 'Use at least 4 characters.';

  @override
  String setupRemoteAddress(String address) {
    return 'You can continue this setup remotely from a web browser at $address, whether the switch above is on or not.';
  }

  @override
  String get remoteWelcomeTitle => 'Welcome to Kiosk Satellite';

  @override
  String get remoteWelcomePassword =>
      'This tablet is waiting to be set up. First, protect this remote admin with a password.';

  @override
  String get remoteWelcomeReady =>
      'This tablet is waiting to be set up. The remote admin password is already set; type a new one here to change it.';

  @override
  String get remoteInitialPassword => 'Admin password (min 4 characters)';

  @override
  String get remoteNewPassword =>
      'New admin password (leave empty to keep the current one)';
}
