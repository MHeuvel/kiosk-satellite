// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'ui_strings.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class UiStringsEn extends UiStrings {
  UiStringsEn([String locale = 'en']) : super(locale);

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
  String get settingDeviceNameTitle => 'Device name';

  @override
  String get settingDeviceNameDescription =>
      'Friendly name shown in remote management and used as the device name published to Home Assistant.';

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
  String get settingUiLanguageTitle => 'Language';

  @override
  String get settingUiLanguageDescription =>
      'Language for Kiosk Satellite and remote administration. Home Assistant keeps its own language.';

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
