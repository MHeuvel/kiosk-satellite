import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'ui_strings_en.dart';
import 'ui_strings_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of UiStrings
/// returned by `UiStrings.of(context)`.
///
/// Applications need to include `UiStrings.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/ui_strings.dart';
///
/// return MaterialApp(
///   localizationsDelegates: UiStrings.localizationsDelegates,
///   supportedLocales: UiStrings.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the UiStrings.supportedLocales
/// property.
abstract class UiStrings {
  UiStrings(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static UiStrings? of(BuildContext context) {
    return Localizations.of<UiStrings>(context, UiStrings);
  }

  static const LocalizationsDelegate<UiStrings> delegate = _UiStringsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// Button to import a configuration file.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get commonImport;

  /// Button to return to the previous step.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// Button to advance to the next step.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// Button to complete setup.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get commonFinish;

  /// Button label while an operation is running.
  ///
  /// In en, this message translates to:
  /// **'Working…'**
  String get commonWorking;

  /// Heading for Settings and the drawer action that opens it.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get commonSettings;

  /// Button to dismiss a dialog without applying its action.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Button to dismiss a message.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// Plugin action label. Both values come from the plugin and are kept as supplied.
  ///
  /// In en, this message translates to:
  /// **'{pluginName}: {actionTitle}'**
  String drawerPluginAction(String pluginName, String actionTitle);

  /// Error heading after a plugin action fails.
  ///
  /// In en, this message translates to:
  /// **'Plugin action'**
  String get drawerPluginActionErrorTitle;

  /// Fallback error when a plugin provides no error text.
  ///
  /// In en, this message translates to:
  /// **'Could not run this action.'**
  String get drawerPluginActionError;

  /// Opens the configured Home Assistant dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get drawerDashboard;

  /// Toggles the Home Assistant header and sidebar. Shown when the menu shortcut is enabled.
  ///
  /// In en, this message translates to:
  /// **'HA Kiosk Mode'**
  String get drawerHaKiosk;

  /// Opens the default camera view. Shown when that view contains cameras.
  ///
  /// In en, this message translates to:
  /// **'Camera View'**
  String get drawerCameraView;

  /// Opens the intercom when it is enabled and available.
  ///
  /// In en, this message translates to:
  /// **'Intercom'**
  String get drawerIntercom;

  /// Opens Music Assistant when its address and menu shortcut are configured. Keep the product name.
  ///
  /// In en, this message translates to:
  /// **'Music Assistant'**
  String get drawerMusicAssistant;

  /// Shown while the floating player is visible.
  ///
  /// In en, this message translates to:
  /// **'Hide Floating Player'**
  String get drawerHidePlayer;

  /// Shown while the floating player is hidden.
  ///
  /// In en, this message translates to:
  /// **'Show Floating Player'**
  String get drawerShowPlayer;

  /// Opens the full-screen player when a track is available and the shortcut is enabled.
  ///
  /// In en, this message translates to:
  /// **'Now Playing'**
  String get drawerNowPlaying;

  /// Starts the screensaver when its menu shortcut is enabled.
  ///
  /// In en, this message translates to:
  /// **'Start Screensaver'**
  String get drawerScreensaver;

  /// Activates lockdown when its menu shortcut is enabled.
  ///
  /// In en, this message translates to:
  /// **'Lockdown Mode'**
  String get drawerLockdown;

  /// Releases a hold so screensaver and timers can resume.
  ///
  /// In en, this message translates to:
  /// **'Turn Off Hold Mode'**
  String get drawerHoldOff;

  /// Pauses screensaver and timers to keep the current view on screen.
  ///
  /// In en, this message translates to:
  /// **'Turn On Hold Mode'**
  String get drawerHoldOn;

  /// Opens the app launcher when it is enabled and has allowed apps.
  ///
  /// In en, this message translates to:
  /// **'Apps'**
  String get drawerApps;

  /// Clears the embedded browser cache.
  ///
  /// In en, this message translates to:
  /// **'Clear web cache'**
  String get drawerClearCache;

  /// Shown when device owner or Shizuku access allows a restart. Also the confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Restart Device'**
  String get drawerRestartDevice;

  /// Confirmation before restarting Android.
  ///
  /// In en, this message translates to:
  /// **'Restart this device? Kiosk Satellite comes back when it boots.'**
  String get drawerRestartConfirm;

  /// Button that confirms the device restart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get drawerRestart;

  /// Hidden when Kiosk Satellite is the home screen. Also the confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Exit Application'**
  String get drawerExitApplication;

  /// Confirmation before closing the application.
  ///
  /// In en, this message translates to:
  /// **'Close Kiosk Satellite?'**
  String get drawerExitConfirm;

  /// Button that confirms closing the application.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get drawerExit;

  /// Notice below the menu while hold mode is active.
  ///
  /// In en, this message translates to:
  /// **'Hold mode is on'**
  String get drawerHoldActive;

  /// Tappable notice that releases hold mode.
  ///
  /// In en, this message translates to:
  /// **'Screensaver and timers are paused · tap to turn off'**
  String get drawerHoldHelp;

  /// Tooltip for the dark theme button at the bottom of the drawer.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get drawerThemeDark;

  /// Tooltip for the light theme button at the bottom of the drawer.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get drawerThemeLight;

  /// Tooltip for matching the Android theme. This controls appearance, not language.
  ///
  /// In en, this message translates to:
  /// **'Follow Android'**
  String get drawerThemeAndroid;

  /// Current version below the drawer actions. Tap to check for updates.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String drawerVersion(String version);

  /// Notice shown when a newer version is available.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get drawerUpdateAvailable;

  /// Tappable update notice below the drawer actions.
  ///
  /// In en, this message translates to:
  /// **'Version {version} · tap to install'**
  String drawerUpdateInstall(String version);

  /// Progress notice during a manual update check.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates…'**
  String get drawerUpdateChecking;

  /// Heading when the installed version is current.
  ///
  /// In en, this message translates to:
  /// **'Up to date'**
  String get drawerUpdateCurrent;

  /// Result of a successful check with no update.
  ///
  /// In en, this message translates to:
  /// **'You are on the latest version.'**
  String get drawerUpdateCurrentHelp;

  /// Heading when the manual update check fails.
  ///
  /// In en, this message translates to:
  /// **'Update check failed'**
  String get drawerUpdateCheckFailed;

  /// Help after an update check fails.
  ///
  /// In en, this message translates to:
  /// **'Is the device online?'**
  String get drawerUpdateOffline;

  /// Title of the update confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Update to {version}'**
  String drawerUpdateTo(String version);

  /// Help below the release notes.
  ///
  /// In en, this message translates to:
  /// **'The download starts on Update. Android asks you to confirm the installation.'**
  String get drawerUpdateInstructions;

  /// Notice when the overlay permission is missing.
  ///
  /// In en, this message translates to:
  /// **'Without the \"Display over other apps\" permission the app cannot reopen itself after updating.'**
  String get drawerUpdateRelaunch;

  /// Button that starts downloading an update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get drawerUpdate;

  /// Title of the download progress dialog.
  ///
  /// In en, this message translates to:
  /// **'Downloading update'**
  String get drawerUpdateDownloading;

  /// Progress text before a download percentage is available.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get drawerUpdateStarting;

  /// Title when downloading or installing fails. Technical error details remain as supplied.
  ///
  /// In en, this message translates to:
  /// **'Update failed'**
  String get drawerUpdateFailed;

  /// Dialog title when there is no longer an update to install.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get drawerUpdates;

  /// Placeholder when a release has no notes. Published release notes remain as supplied.
  ///
  /// In en, this message translates to:
  /// **'No release notes.'**
  String get drawerNoReleaseNotes;

  /// Device name field label.
  ///
  /// In en, this message translates to:
  /// **'Device name'**
  String get settingDeviceNameTitle;

  /// Help below the Device name field.
  ///
  /// In en, this message translates to:
  /// **'Friendly name shown in remote management and used as the device name published to Home Assistant.'**
  String get settingDeviceNameDescription;

  /// Switch label.
  ///
  /// In en, this message translates to:
  /// **'Remote management'**
  String get settingRemoteEnabledTitle;

  /// Help below the switch.
  ///
  /// In en, this message translates to:
  /// **'Run the embedded admin web server.'**
  String get settingRemoteEnabledDescription;

  /// Server port field label.
  ///
  /// In en, this message translates to:
  /// **'Server port'**
  String get settingRemotePortTitle;

  /// Help below the Server port field.
  ///
  /// In en, this message translates to:
  /// **'Port for the remote admin interface.'**
  String get settingRemotePortDescription;

  /// Admin password field label.
  ///
  /// In en, this message translates to:
  /// **'Admin password'**
  String get settingRemotePasswordTitle;

  /// Help below the Admin password field.
  ///
  /// In en, this message translates to:
  /// **'Required to log in to the remote interface.'**
  String get settingRemotePasswordDescription;

  /// Language selector label.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingUiLanguageTitle;

  /// Help below the language selector.
  ///
  /// In en, this message translates to:
  /// **'Language for Kiosk Satellite and remote administration. Home Assistant keeps its own language.'**
  String get settingUiLanguageDescription;

  /// Home Assistant base URL field label.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant base URL'**
  String get settingHaUrlTitle;

  /// Help below the Home Assistant base URL field.
  ///
  /// In en, this message translates to:
  /// **'e.g. https://homeassistant.local:8123, without a dashboard path.'**
  String get settingHaUrlDescription;

  /// Long-lived access token field label.
  ///
  /// In en, this message translates to:
  /// **'Long-lived access token'**
  String get settingHaTokenTitle;

  /// Help below the Long-lived access token field.
  ///
  /// In en, this message translates to:
  /// **'Created under your HA profile → Security.'**
  String get settingHaTokenDescription;

  /// Settings menu entry. Product names stay unchanged.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant Setup'**
  String get settingsMenuHomeAssistant;

  /// Summary below Home Assistant Setup in the Settings menu.
  ///
  /// In en, this message translates to:
  /// **'Connection, dashboard, kiosk mode'**
  String get settingsMenuHomeAssistantSummary;

  /// Settings menu entry. Product names stay unchanged.
  ///
  /// In en, this message translates to:
  /// **'Voice Satellite'**
  String get settingsMenuVoiceSatellite;

  /// Summary below Voice Satellite in the Settings menu.
  ///
  /// In en, this message translates to:
  /// **'Wake word, background listening'**
  String get settingsMenuVoiceSatelliteSummary;

  /// Settings menu entry. Product names stay unchanged.
  ///
  /// In en, this message translates to:
  /// **'ESPHome'**
  String get settingsMenuEsphome;

  /// Summary below ESPHome in the Settings menu.
  ///
  /// In en, this message translates to:
  /// **'Native entities and Bluetooth proxy'**
  String get settingsMenuEsphomeSummary;

  /// Settings menu entry. Product names stay unchanged.
  ///
  /// In en, this message translates to:
  /// **'Screen & Audio'**
  String get settingsMenuScreenAudio;

  /// Summary below Screen & Audio in the Settings menu.
  ///
  /// In en, this message translates to:
  /// **'Brightness, volume, microphone'**
  String get settingsMenuScreenAudioSummary;

  /// Settings menu entry. Product names stay unchanged.
  ///
  /// In en, this message translates to:
  /// **'Screensaver'**
  String get settingsMenuScreensaver;

  /// Summary below Screensaver in the Settings menu.
  ///
  /// In en, this message translates to:
  /// **'Idle timeout, modes, motion wake'**
  String get settingsMenuScreensaverSummary;

  /// Settings menu entry. Product names stay unchanged.
  ///
  /// In en, this message translates to:
  /// **'Web Browsing'**
  String get settingsMenuBrowser;

  /// Summary below Web Browsing in the Settings menu.
  ///
  /// In en, this message translates to:
  /// **'Cache, SSL, Zoom level'**
  String get settingsMenuBrowserSummary;

  /// Settings menu entry. Product names stay unchanged.
  ///
  /// In en, this message translates to:
  /// **'Media Player'**
  String get settingsMenuMediaPlayer;

  /// Summary below Media Player in the Settings menu.
  ///
  /// In en, this message translates to:
  /// **'Music Assistant, Sendspin, Sonos'**
  String get settingsMenuMediaPlayerSummary;

  /// Settings menu entry. Product names stay unchanged.
  ///
  /// In en, this message translates to:
  /// **'DLNA Renderer'**
  String get settingsMenuDlna;

  /// Summary below DLNA Renderer in the Settings menu.
  ///
  /// In en, this message translates to:
  /// **'Play images, videos and audio remotely'**
  String get settingsMenuDlnaSummary;

  /// Settings menu entry. Product names stay unchanged.
  ///
  /// In en, this message translates to:
  /// **'Intercom'**
  String get settingsMenuIntercom;

  /// Summary below Intercom in the Settings menu.
  ///
  /// In en, this message translates to:
  /// **'Talk between kiosks'**
  String get settingsMenuIntercomSummary;

  /// Settings menu entry. Product names stay unchanged.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get settingsMenuCamera;

  /// Summary below Camera in the Settings menu.
  ///
  /// In en, this message translates to:
  /// **'Device camera, motion, streaming'**
  String get settingsMenuCameraSummary;

  /// Settings menu entry. Product names stay unchanged.
  ///
  /// In en, this message translates to:
  /// **'Camera Streams'**
  String get settingsMenuCameraStreams;

  /// Summary below Camera Streams in the Settings menu.
  ///
  /// In en, this message translates to:
  /// **'Go2RTC and Home Assistant cameras'**
  String get settingsMenuCameraStreamsSummary;

  /// Settings menu entry. Product names stay unchanged.
  ///
  /// In en, this message translates to:
  /// **'Kiosk Mode'**
  String get settingsMenuKiosk;

  /// Summary below Kiosk Mode in the Settings menu.
  ///
  /// In en, this message translates to:
  /// **'Exit gesture, PIN, hardware buttons'**
  String get settingsMenuKioskSummary;

  /// Settings menu entry. Product names stay unchanged.
  ///
  /// In en, this message translates to:
  /// **'Home Launcher'**
  String get settingsMenuHomeLauncher;

  /// Summary below Home Launcher in the Settings menu.
  ///
  /// In en, this message translates to:
  /// **'Replace the device home screen'**
  String get settingsMenuHomeLauncherSummary;

  /// Settings menu entry. Product names stay unchanged.
  ///
  /// In en, this message translates to:
  /// **'App Launcher'**
  String get settingsMenuAppLauncher;

  /// Summary below App Launcher in the Settings menu.
  ///
  /// In en, this message translates to:
  /// **'Open other apps from the kiosk'**
  String get settingsMenuAppLauncherSummary;

  /// Settings menu entry. Product names stay unchanged.
  ///
  /// In en, this message translates to:
  /// **'Gestures'**
  String get settingsMenuGestures;

  /// Summary below Gestures in the Settings menu.
  ///
  /// In en, this message translates to:
  /// **'Touch, palm and clap gestures'**
  String get settingsMenuGesturesSummary;

  /// Settings menu entry. Product names stay unchanged.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get settingsMenuDevice;

  /// Summary below Device in the Settings menu.
  ///
  /// In en, this message translates to:
  /// **'Name, app theme, remote access'**
  String get settingsMenuDeviceSummary;

  /// Settings menu entry. Product names stay unchanged.
  ///
  /// In en, this message translates to:
  /// **'Fleet Management'**
  String get settingsMenuFleet;

  /// Summary below Fleet Management in the Settings menu.
  ///
  /// In en, this message translates to:
  /// **'Lead or follow other kiosks'**
  String get settingsMenuFleetSummary;

  /// Settings menu entry. Product names stay unchanged.
  ///
  /// In en, this message translates to:
  /// **'Plugin Manager'**
  String get settingsMenuPlugins;

  /// Summary below Plugin Manager in the Settings menu.
  ///
  /// In en, this message translates to:
  /// **'Install and manage plugins'**
  String get settingsMenuPluginsSummary;

  /// Settings menu entry. Product names stay unchanged.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get settingsMenuLogs;

  /// Summary below Logs in the Settings menu.
  ///
  /// In en, this message translates to:
  /// **'App log and web console'**
  String get settingsMenuLogsSummary;

  /// Settings menu entry. Product names stay unchanged.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsMenuAbout;

  /// Summary below About in the Settings menu.
  ///
  /// In en, this message translates to:
  /// **'Version, author, license'**
  String get settingsMenuAboutSummary;

  /// Settings menu entry. Product names stay unchanged.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get settingsMenuOverview;

  /// Summary below Overview in the Settings menu.
  ///
  /// In en, this message translates to:
  /// **'Screen and quick controls'**
  String get settingsMenuOverviewSummary;

  /// Settings menu entry. Product names stay unchanged.
  ///
  /// In en, this message translates to:
  /// **'Lockdown Mode'**
  String get settingsMenuLockdown;

  /// Summary below Lockdown Mode in the Settings menu.
  ///
  /// In en, this message translates to:
  /// **'Disable screen interactions'**
  String get settingsMenuLockdownSummary;

  /// Settings menu entry. Product names stay unchanged.
  ///
  /// In en, this message translates to:
  /// **'File Manager'**
  String get settingsMenuFiles;

  /// Summary below File Manager in the Settings menu.
  ///
  /// In en, this message translates to:
  /// **'Browse, download and upload files'**
  String get settingsMenuFilesSummary;

  /// Heading above a group of Settings menu entries.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant'**
  String get settingsGroupHomeAssistant;

  /// Heading above a group of Settings menu entries.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get settingsGroupDisplay;

  /// Heading above a group of Settings menu entries.
  ///
  /// In en, this message translates to:
  /// **'Media & Cameras'**
  String get settingsGroupMediaCameras;

  /// Heading above a group of Settings menu entries.
  ///
  /// In en, this message translates to:
  /// **'Kiosk'**
  String get settingsGroupKiosk;

  /// Heading above a group of Settings menu entries.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsGroupSystem;

  /// Remote administration sidebar control or accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get settingsMenuMenu;

  /// Remote administration sidebar control or accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsMenuTheme;

  /// Remote administration sidebar control or accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get settingsMenuLogout;

  /// Remote administration sidebar control or accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Switch kiosk'**
  String get settingsMenuSwitchKiosk;

  /// Tooltip on the remote sidebar theme button. The value is the localized theme name.
  ///
  /// In en, this message translates to:
  /// **'Theme: {theme}'**
  String settingsMenuThemeState(String theme);

  /// Theme choice that follows the browser color preference.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get settingsMenuThemeAuto;

  /// Placeholder in the Settings search box.
  ///
  /// In en, this message translates to:
  /// **'Search settings'**
  String get settingsSearchHint;

  /// Tooltip and accessibility label for the clear button.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get settingsSearchClear;

  /// Heading above matching settings.
  ///
  /// In en, this message translates to:
  /// **'Search results'**
  String get settingsSearchResults;

  /// Empty result message. The query is the text entered by the user.
  ///
  /// In en, this message translates to:
  /// **'No settings match \"{query}\".'**
  String settingsSearchEmpty(String query);

  /// Page heading.
  ///
  /// In en, this message translates to:
  /// **'Connect to Home Assistant'**
  String get setupConnectHeading;

  /// Introduction explaining the required credentials.
  ///
  /// In en, this message translates to:
  /// **'The base URL of your instance and a long-lived access token, created under your HA profile → Security → Long-lived access tokens.'**
  String get setupConnectLead;

  /// Home Assistant address field label.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant base URL'**
  String get setupBaseUrl;

  /// Access token field label.
  ///
  /// In en, this message translates to:
  /// **'Long-lived access token'**
  String get setupToken;

  /// Button to scan connection details from a QR code.
  ///
  /// In en, this message translates to:
  /// **'Scan the QR code'**
  String get setupScanQr;

  /// Error heading when Home Assistant rejects the token.
  ///
  /// In en, this message translates to:
  /// **'Invalid access token'**
  String get setupInvalidToken;

  /// Instructions for replacing a rejected token.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant rejected this token. In Home Assistant, open your profile → Security → Long-lived access tokens, create a new token and copy the complete value.'**
  String get setupInvalidTokenHelp;

  /// Error heading when the server does not respond.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach Home Assistant'**
  String get setupUnreachable;

  /// Troubleshooting advice for an unreachable server.
  ///
  /// In en, this message translates to:
  /// **'No response from this address. Check that the URL is correct and that this device is on the same network as your Home Assistant server.'**
  String get setupUnreachableHelp;

  /// Help when the address responds as a different service.
  ///
  /// In en, this message translates to:
  /// **'A server responded, but it doesn\'t appear to be Home Assistant. Check that the URL is your Home Assistant base address, for example https://homeassistant.local:8123.'**
  String get setupUnexpectedResponseHelp;

  /// Heading for other connection errors.
  ///
  /// In en, this message translates to:
  /// **'Can\'t connect'**
  String get setupCannotConnect;

  /// Error heading when QR scanning needs camera permission.
  ///
  /// In en, this message translates to:
  /// **'Camera permission needed'**
  String get setupCameraPermission;

  /// Instructions when camera access must be enabled in Android.
  ///
  /// In en, this message translates to:
  /// **'Allow the camera for Kiosk Satellite in the Android settings to scan the QR code.'**
  String get setupCameraBlocked;

  /// Instructions when camera access can be requested in the app.
  ///
  /// In en, this message translates to:
  /// **'Allow the camera to scan the QR code.'**
  String get setupCameraAllow;

  /// Error heading when the address field is empty.
  ///
  /// In en, this message translates to:
  /// **'Enter your Home Assistant base URL'**
  String get setupEnterBaseUrl;

  /// Error heading when the address format is invalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid base URL'**
  String get setupInvalidBaseUrl;

  /// Example explaining the expected address.
  ///
  /// In en, this message translates to:
  /// **'This is the address you use to open Home Assistant, for example https://homeassistant.local:8123.'**
  String get setupBaseUrlHelp;

  /// Error heading when the access token field is empty.
  ///
  /// In en, this message translates to:
  /// **'Enter a long-lived access token'**
  String get setupEnterToken;

  /// Instructions for creating an access token.
  ///
  /// In en, this message translates to:
  /// **'In Home Assistant, open your profile → Security → Long-lived access tokens to create one.'**
  String get setupEnterTokenHelp;

  /// Button to test credentials and advance.
  ///
  /// In en, this message translates to:
  /// **'Validate & continue'**
  String get setupValidateContinue;

  /// Error heading for an unexpected server response.
  ///
  /// In en, this message translates to:
  /// **'Unexpected response ({error})'**
  String setupUnexpectedResponse(String error);

  /// Validation error for a malformed address.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid URL, for example https://homeassistant.local:8123'**
  String get baseUrlInvalid;

  /// Validation error for an address containing a dashboard path.
  ///
  /// In en, this message translates to:
  /// **'Enter only the base URL, without a dashboard path. Example: https://homeassistant.local:8123'**
  String get baseUrlPath;

  /// Validation error for an address containing a query or fragment.
  ///
  /// In en, this message translates to:
  /// **'Enter only the base URL, without anything after the port. Example: https://homeassistant.local:8123'**
  String get baseUrlQuery;

  /// Welcome step label.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get setupWelcome;

  /// Home Assistant connection step label.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get setupConnect;

  /// Summary below the connection step label.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant URL & token'**
  String get setupConnectSummary;

  /// Dashboard step label.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get setupDashboard;

  /// Summary below the dashboard step label.
  ///
  /// In en, this message translates to:
  /// **'What the kiosk shows'**
  String get setupDashboardSummary;

  /// Summary below the recommended settings step.
  ///
  /// In en, this message translates to:
  /// **'Recommended settings'**
  String get setupRecommendedSummary;

  /// Permissions step label and page heading.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get setupPermissions;

  /// Summary below the permissions step label.
  ///
  /// In en, this message translates to:
  /// **'What the setup needs'**
  String get setupPermissionsSummary;

  /// Remote administration section heading and step summary.
  ///
  /// In en, this message translates to:
  /// **'Remote administration'**
  String get setupRemoteHeading;

  /// Setup heading on the device.
  ///
  /// In en, this message translates to:
  /// **'Set up\nKiosk Satellite'**
  String get setupTitle;

  /// Introduction on the device.
  ///
  /// In en, this message translates to:
  /// **'Turn this tablet into a Home Assistant kiosk. Setup takes a couple of minutes and this wizard walks you through it.'**
  String get setupWelcomeLead;

  /// Device name field label on the device.
  ///
  /// In en, this message translates to:
  /// **'Device name'**
  String get setupDeviceName;

  /// Help below the device name field.
  ///
  /// In en, this message translates to:
  /// **'How this kiosk is called in Home Assistant, in the remote admin and on the network. Change it any time under Settings, Device.'**
  String get setupDeviceNameHelp;

  /// Remote administration switch label on the device.
  ///
  /// In en, this message translates to:
  /// **'Enable remote administration'**
  String get setupEnableRemote;

  /// Help below the remote administration switch.
  ///
  /// In en, this message translates to:
  /// **'Keep managing this kiosk from a web browser after setup, where pasting the Home Assistant access token is much easier.'**
  String get setupEnableRemoteHelp;

  /// Remote password field label on the device.
  ///
  /// In en, this message translates to:
  /// **'Remote admin password'**
  String get setupRemotePassword;

  /// Configuration restore section heading.
  ///
  /// In en, this message translates to:
  /// **'Restore backup'**
  String get setupRestoreHeading;

  /// Action to select a configuration file.
  ///
  /// In en, this message translates to:
  /// **'Restore from configuration file'**
  String get setupRestore;

  /// Explanation of what restoring a configuration imports.
  ///
  /// In en, this message translates to:
  /// **'Import a configuration exported from Kiosk Satellite and skip the rest of this wizard. Settings, dashboard and login all come along.'**
  String get setupRestoreHelp;

  /// Heading above the recommended service permissions.
  ///
  /// In en, this message translates to:
  /// **'Recommended Service Permissions'**
  String get setupServicePermissions;

  /// Error heading for a password below the minimum length.
  ///
  /// In en, this message translates to:
  /// **'Password too short'**
  String get setupPasswordShort;

  /// Password length requirement below the error heading.
  ///
  /// In en, this message translates to:
  /// **'Use at least 4 characters.'**
  String get setupPasswordMinimum;

  /// Instructions for continuing setup in a browser.
  ///
  /// In en, this message translates to:
  /// **'You can continue this setup remotely from a web browser at {address}, whether the switch above is on or not.'**
  String setupRemoteAddress(String address);

  /// Welcome heading in the browser.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Kiosk Satellite'**
  String get remoteWelcomeTitle;

  /// Browser introduction when no admin password is set.
  ///
  /// In en, this message translates to:
  /// **'This tablet is waiting to be set up. First, protect this remote admin with a password.'**
  String get remoteWelcomePassword;

  /// Browser introduction when an admin password is already set.
  ///
  /// In en, this message translates to:
  /// **'This tablet is waiting to be set up. The remote admin password is already set; type a new one here to change it.'**
  String get remoteWelcomeReady;

  /// Browser password field label for a new password.
  ///
  /// In en, this message translates to:
  /// **'Admin password (min 4 characters)'**
  String get remoteInitialPassword;

  /// Browser password field label for an optional replacement.
  ///
  /// In en, this message translates to:
  /// **'New admin password (leave empty to keep the current one)'**
  String get remoteNewPassword;
}

class _UiStringsDelegate extends LocalizationsDelegate<UiStrings> {
  const _UiStringsDelegate();

  @override
  Future<UiStrings> load(Locale locale) {
    return SynchronousFuture<UiStrings>(lookupUiStrings(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_UiStringsDelegate old) => false;
}

UiStrings lookupUiStrings(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return UiStringsEn();
    case 'es':
      return UiStringsEs();
  }

  throw FlutterError(
    'UiStrings.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
