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

  /// Button to grant an Android permission.
  ///
  /// In en, this message translates to:
  /// **'Grant'**
  String get commonGrant;

  /// Button to enable a feature.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get commonEnable;

  /// Button to refresh the displayed status.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// Button to test a connection.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get commonTest;

  /// Button to install an update.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get commonInstall;

  /// Button to save edited settings.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// Button to retry a failed action.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// Button to copy a value to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// Add action button.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// Remove action button.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// Close action button.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

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

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Basic analytics'**
  String get settingAnalyticsBasicTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Information about your device, such as model, Android version, app version, screen size and language.'**
  String get settingAnalyticsBasicDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get settingAnalyticsUsageTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Details of what you use with Kiosk Satellite.'**
  String get settingAnalyticsUsageDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get settingAnalyticsDiagnosticsTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Share crash reports when unexpected errors occur.'**
  String get settingAnalyticsDiagnosticsDescription;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Kiosk Satellite Analytics'**
  String get deviceAnalyticsPage;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Share anonymized information from your installation to help make Kiosk Satellite better and guide which devices and features get attention.'**
  String get deviceAnalyticsIntro;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Learn how we process your data'**
  String get deviceAnalyticsLearn;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'What Kiosk Satellite Analytics sends and what it never sends.'**
  String get deviceAnalyticsLearnHelp;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Export configuration'**
  String get deviceExportConfig;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Save every setting and the page\'s local storage to a file.'**
  String get deviceExportConfigHelp;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Download every setting and the page\'s local storage.'**
  String get deviceExportConfigRemoteHelp;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Import configuration'**
  String get deviceImportConfig;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Replace this device\'s settings from an exported file.'**
  String get deviceImportConfigHelp;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Export failed'**
  String get deviceExportFailed;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Configuration exported'**
  String get deviceExported;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Import failed'**
  String get deviceImportFailed;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'That file is not valid JSON.'**
  String get deviceInvalidJson;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Import complete'**
  String get deviceImportComplete;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Applied {count} settings.'**
  String deviceAppliedSettings(String count);

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Applied {count} settings. The page may reload.'**
  String deviceAppliedReload(String count);

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Replace the original device'**
  String get deviceReplaceOriginal;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Replace this device\'s settings with the file\'s? The page may reload.'**
  String get deviceReplaceQuestion;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Set up as new device'**
  String get deviceNewDevice;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Keeps the backup\'s name and ESPHome identity; the original device must stay offline.'**
  String get deviceReplaceIdentity;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Assign its own name and ESPHome identity, so both devices are unique.'**
  String get deviceNewIdentity;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Restore Webview\'s local storage'**
  String get deviceRestoreStorage;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Includes the Home Assistant signed in session and the Voice Satellite assist_satellite selection - two devices must not share one satellite.'**
  String get deviceRestoreStorageHelp;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get deviceDownload;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Choose file…'**
  String get deviceChooseFile;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Import failed.'**
  String get deviceImportFailedSentence;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Replace \"{name}\"'**
  String deviceReplaceNamed(String name);

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

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'mDNS name'**
  String get settingDeviceHostnameTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Reach the remote admin using this name and the configured port on the local network. Clear it to take the device name again.'**
  String get settingDeviceHostnameDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Legacy renderer'**
  String get settingDisableImpellerTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Use the older Skia renderer, for old GPUs that crash at startup. Turns itself on after two such crashes; takes effect on the next app start.'**
  String get settingDisableImpellerDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Legacy WebView renderer'**
  String get settingLegacyWebViewTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Draw the dashboard into a texture, for old GPUs that crash when it appears. Turns itself on where the device needs it; takes effect on the next app start.'**
  String get settingLegacyWebViewDescription;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Set from the device name'**
  String get deviceHostnamePlaceholder;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get deviceConfiguration;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Permissions Manager'**
  String get devicePermissionsManager;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get deviceOptions;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get deviceStatus;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get deviceConnection;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get devicePermissions;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get deviceHelp;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Access'**
  String get deviceAccess;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Reading…'**
  String get deviceReading;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Checking...'**
  String get deviceChecking;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Status unavailable.'**
  String get deviceUnavailable;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Grant on device'**
  String get deviceGrantOnDevice;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'App settings'**
  String get deviceAppSettings;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Copy command'**
  String get deviceCopyCommand;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Open guide'**
  String get deviceOpenGuide;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get deviceNotSet;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Granted'**
  String get deviceGranted;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Not granted'**
  String get deviceNotGranted;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get deviceMissing;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Not offered'**
  String get deviceNotOffered;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'on'**
  String get deviceOn;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'off'**
  String get deviceOff;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Status, what keeps it running, required permissions'**
  String get deviceServiceHint;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Manage this kiosk from a browser on your network'**
  String get deviceRemoteHintActual;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Where the app looks for new releases'**
  String get deviceUpdatesHint;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Connection, Android permissions and setup'**
  String get deviceShizukuHint;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Silent update status, ADB setup and instructions'**
  String get deviceHelperHint;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Share anonymized information to help improve Kiosk Satellite'**
  String get deviceAnalyticsHint;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Model, Android version, addresses, memory, uptime'**
  String get deviceHardwareHint;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Connection, version and what the kiosk shows'**
  String get deviceHaHint;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Engine version, renderer and user agent'**
  String get deviceWebViewHint;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'•••••• (set)'**
  String get devicePasswordSet;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Could not save this setting. Try again.'**
  String get deviceSaveFailed;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Open settings on device'**
  String get deviceOpenSettingsDevice;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Hardware'**
  String get deviceHardwarePage;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'WebView'**
  String get deviceWebViewPage;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Device model'**
  String get deviceModel;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Android version'**
  String get deviceAndroidVersion;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Android build'**
  String get deviceAndroidBuild;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'IPv4 address'**
  String get deviceIpv4;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'IPv6 addresses'**
  String get deviceIpv6;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'App uptime'**
  String get deviceAppUptime;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Network uptime'**
  String get deviceNetworkUptime;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'CPU usage'**
  String get deviceCpuUsage;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'CPU temperature'**
  String get deviceCpuTemp;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Battery level'**
  String get deviceBatteryLevel;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Screen brightness'**
  String get deviceScreenBrightness;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Screen status'**
  String get deviceScreenStatus;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Screen size'**
  String get deviceScreenSize;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'RAM (free/total)'**
  String get deviceRam;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Internal storage (free/total)'**
  String get deviceStorage;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant URL'**
  String get deviceHaUrl;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Wake word detection'**
  String get deviceWakeDetection;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Wake word status'**
  String get deviceWakeStatus;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Engine'**
  String get deviceEngine;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Wake words'**
  String get deviceWakeWords;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Stop word'**
  String get deviceStopWord;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Motion detection'**
  String get deviceMotionDetection;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Face detection'**
  String get deviceFaceDetection;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get deviceProvider;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get deviceVersion;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'User agent'**
  String get deviceUserAgent;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'plugged'**
  String get devicePlugged;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'low'**
  String get deviceLowMemory;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Required system permissions'**
  String get deviceRequiredPermissions;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Grants are given on this device, so each button opens an Android dialog or settings screen here. Some brands add their own battery or autostart manager on top, which Android cannot report.'**
  String get devicePermissionIntro;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Grants are given on the device, so each button opens an Android dialog or settings screen there. Some brands add their own battery or autostart manager on top, which Android cannot report.'**
  String get devicePermissionIntroRemote;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Microphone'**
  String get deviceMicrophone;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Allows microphone usage for wake word detection, speech to text and intercom calls.'**
  String get deviceMicrophoneHeld;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Unrestricted battery'**
  String get deviceBattery;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Allows the process to run in the background without being paused or killed.'**
  String get deviceBatteryHeld;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get deviceCamera;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Motion detection and snapshots can use the camera.'**
  String get deviceCameraHeld;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Nearby devices'**
  String get deviceBluetooth;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'The Bluetooth proxy can scan for nearby devices.'**
  String get deviceBluetoothHeld;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get deviceNotifications;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Allows the Kiosk Satellite Service\'s ongoing notification, which says what it is keeping alive.'**
  String get deviceNotificationsHeld;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Display over other apps'**
  String get deviceOverlay;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Kiosk Satellite can bring itself back in the foreground.'**
  String get deviceOverlayHeld;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Modify system settings'**
  String get deviceWriteSettings;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Brightness changes set the panel\'s real brightness.'**
  String get deviceWriteSettingsHeld;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'System UI guard'**
  String get deviceUiGuard;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'The notification shade and recents close on their own while the screen is protected.'**
  String get deviceUiGuardHeld;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Device admin'**
  String get deviceDeviceAdmin;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Allows the app to turn the screen off.'**
  String get deviceDeviceAdminHeld;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'All files access'**
  String get deviceAllFiles;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'The File Manager can browse the shared storage.'**
  String get deviceAllFilesHeld;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Usage access'**
  String get deviceUsageAccess;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'The Foreground app sensor can name whichever app is on screen.'**
  String get deviceUsageAccessHeld;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get deviceLocation;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Pages, Bluetooth scanning and the location sensors can use the device position.'**
  String get deviceLocationHeld;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Blocked. Android will not ask again, so allow it in the app settings.'**
  String get deviceMicBlocked;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Wake word detection is on and nothing is listening.'**
  String get deviceMicMissing;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Needed by wake word detection, the intercom and pages that ask for the microphone.'**
  String get deviceMicIdle;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Android may pause the app when the screen is off, dropping the Home Assistant connection and the ESPHome entities with it.'**
  String get deviceBatteryMissing;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'The camera is switched on and cannot be opened.'**
  String get deviceCameraMissing;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Needed by motion detection, camera snapshots and pages that ask for the camera.'**
  String get deviceCameraIdle;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'The Bluetooth proxy is switched on and cannot scan.'**
  String get deviceBluetoothMissing;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth scanning needs the Location permission.'**
  String get deviceBluetoothLocation;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Location is off in the device settings, so Bluetooth scanning finds nothing.'**
  String get deviceBluetoothLocationOff;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Needed by the Bluetooth proxy to scan for devices.'**
  String get deviceBluetoothIdle;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Needed to show the Kiosk Satellite Service\'s ongoing notification.'**
  String get deviceNotificationMissing;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Without this the app cannot reopen itself after a crash, an update or a wake word heard behind another app.'**
  String get deviceOverlayMissing;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Lets the app bring itself back to the front, and the lockdown shield cover the whole screen.'**
  String get deviceOverlayIdle;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Brightness only dims the app window, so the panel and Home Assistant never see the change.'**
  String get deviceBrightnessMissing;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Needed to set the panel\'s real brightness rather than dimming the app window.'**
  String get deviceBrightnessIdle;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'The notification shade and recents stay reachable. Enable Kiosk Satellite under Accessibility.'**
  String get deviceGuardMissing;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Closes the notification shade and recents while kiosk mode protects the screen.'**
  String get deviceGuardIdle;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Lets Screen off power the panel down instead of only blacking it out.'**
  String get deviceAdminIdle;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Lets the File Manager browse the shared storage instead of only the app folder.'**
  String get deviceFilesIdle;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Lets the Foreground app sensor name apps other than Kiosk Satellite.'**
  String get deviceUsageIdle;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Android will not deliver Bluetooth scan results without Location, and the location sensors cannot read the GPS receiver.'**
  String get deviceLocationMissing;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Used by pages that ask for your location, by Bluetooth scanning and by the ESPHome location sensors.'**
  String get deviceLocationIdle;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Without this the service cannot relaunch the kiosk after a crash or a close from recents.'**
  String get deviceServiceOverlayMissing;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Needed to relaunch the kiosk after a crash.'**
  String get deviceServiceOverlayIdle;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Background listening is on and nothing is listening.'**
  String get deviceListeningMissing;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Needed by background listening.'**
  String get deviceListeningIdle;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Needed by motion detection.'**
  String get deviceMotionIdle;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'This device has no settings screen for it. Grant it over adb: adb shell dumpsys deviceidle whitelist +me.jxl.kiosk_satellite'**
  String get deviceBatteryAdb;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'This device has no settings screen for it. Grant it over adb: adb shell appops set me.jxl.kiosk_satellite SYSTEM_ALERT_WINDOW allow'**
  String get deviceOverlayAdb;

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

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Find other kiosks'**
  String get settingRemoteFleetDiscoveryTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Announce this device on the network and list the other kiosks in the remote admin, to switch between them.'**
  String get settingRemoteFleetDiscoveryDescription;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Remote Administration'**
  String get deviceRemotePage;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Admin address'**
  String get deviceAdminAddress;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Open this address in a browser on your computer.'**
  String get deviceAdminAddressHelp;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'By name'**
  String get deviceByName;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'The same address by hostname, on networks that resolve .local names.'**
  String get deviceByNameHelp;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Set an admin password below to start the server.'**
  String get devicePasswordNeeded;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'The server is not running.'**
  String get deviceServerStopped;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Could not listen on port {port}: {error}'**
  String devicePortError(String port, String error);

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Keep the CPU awake while the screen is off'**
  String get settingServiceCpuAwakeTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Holds a wake lock through dark spells so connections and timers keep running on time. Costs battery on an unplugged tablet.'**
  String get settingServiceCpuAwakeDescription;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Kiosk Satellite Service'**
  String get deviceServicePage;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Keeping it running'**
  String get deviceKeepingRunning;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get deviceService;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get deviceStopped;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Stopped.'**
  String get deviceStoppedSentence;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get deviceRunning;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Running.'**
  String get deviceRunningSentence;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Running without the foreground exemption.'**
  String get deviceRunningBackground;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Foreground service types'**
  String get deviceServiceTypes;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'What the service declares to Android for the features it holds up.'**
  String get deviceServiceTypesHelp;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'None declared.'**
  String get deviceNoneDeclared;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'none'**
  String get deviceNone;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'CPU wake lock'**
  String get deviceCpuLock;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Off: the setting below is off.'**
  String get deviceCpuOff;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Held: the screen is off.'**
  String get deviceCpuHeld;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Released while the screen is on.'**
  String get deviceCpuReleased;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Not held.'**
  String get deviceNotHeld;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Held'**
  String get deviceHeld;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Released'**
  String get deviceReleased;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi lock'**
  String get deviceWifiLock;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Held: the radio stays out of power saving.'**
  String get deviceWifiHeld;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Keeps the radio out of power saving through screen-off.'**
  String get deviceWifiHelp;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get deviceNotification;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Hidden: notifications are turned off for the app. The service runs regardless.'**
  String get deviceNotificationHidden;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Shown in the notification shade while the service runs.'**
  String get deviceNotificationShown;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get deviceHidden;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Shown'**
  String get deviceShown;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant connection'**
  String get deviceReasonHa;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Keeps the dashboard session and its websocket open while the screen is off.'**
  String get deviceReasonHaHelp;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Background listening'**
  String get deviceReasonListening;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Keeps the wake word engine and its microphone running behind other apps.'**
  String get deviceReasonListeningHelp;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'RTSP microphone audio'**
  String get deviceReasonRtsp;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Keeps microphone streaming available to connected RTSP viewers.'**
  String get deviceReasonRtspHelp;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'ESPHome server'**
  String get deviceReasonEspHome;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Keeps the ESPHome API server answering Home Assistant.'**
  String get deviceReasonEspHomeHelp;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Remote administration'**
  String get deviceReasonRemote;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Keeps the admin web server answering.'**
  String get deviceReasonRemoteHelp;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Kiosk protections'**
  String get deviceReasonProtections;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Relaunches the kiosk when it is closed from recents or crashes.'**
  String get deviceReasonProtectionsHelp;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth proxy'**
  String get deviceReasonBluetooth;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Keeps Bluetooth scanning running while the app is not on screen.'**
  String get deviceReasonBluetoothHelp;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Location sensors'**
  String get deviceReasonLocation;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Keeps GPS fixes arriving while the screen is off or another app is in front.'**
  String get deviceReasonLocationHelp;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Person detection'**
  String get deviceReasonPerson;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Keeps reading the device\'s person sensor while another app is in front.'**
  String get deviceReasonPersonHelp;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Keeps the camera usable after the panel powers off, for motion and face detection.'**
  String get deviceReasonCameraHelp;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Stopped: {error}'**
  String deviceServiceStopped(String error);

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Running for {uptime}.'**
  String deviceServiceRunning(String uptime);

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Install updates through Shizuku'**
  String get settingShizukuInstallUpdatesTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Install Kiosk Satellite updates without on-device confirmation. Shizuku must be running and authorized.'**
  String get settingShizukuInstallUpdatesDescription;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Shizuku access'**
  String get deviceShizukuAccess;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Checking availability'**
  String get deviceShizukuCheck;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Connected with root access'**
  String get deviceShizukuRoot;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Connected with shell access'**
  String get deviceShizukuShell;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Tap to grant access. Approve the request on this kiosk.'**
  String get deviceShizukuGrant;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Grant access and approve the request on this kiosk.'**
  String get deviceShizukuGrantRemote;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Allow Kiosk Satellite in the Shizuku app.'**
  String get deviceShizukuDenied;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Shizuku 13 or later is required.'**
  String get deviceShizukuUnsupported;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Start Shizuku on this device.'**
  String get deviceShizukuStart;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get deviceShizukuTest;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Read the process identity without changing the device.'**
  String get deviceShizukuTestHelp;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Connection test'**
  String get deviceShizukuTestTitle;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Shizuku could not complete the connection test.'**
  String get deviceShizukuTestFailed;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'All permissions are already granted.'**
  String get deviceShizukuAlreadyGranted;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Android confirmed the requested permissions.'**
  String get deviceShizukuConfirmed;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Permission results'**
  String get deviceShizukuResults;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Grant all permissions'**
  String get deviceShizukuGrantAll;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Grant all permissions used by KS, including features that are currently off.'**
  String get deviceShizukuGrantAllHelp;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Set up Shizuku'**
  String get deviceShizukuSetup;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Read installation and startup instructions.'**
  String get deviceShizukuSetupHelp;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Shizuku started through ADB must be started again after a device reboot. Shell access does not provide root permissions.'**
  String get deviceShizukuLifetime;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Shizuku request failed'**
  String get deviceShizukuFailed;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Approve the request on the kiosk.'**
  String get deviceShizukuApprove;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Shizuku successfully ran a command with {access} access.'**
  String deviceShizukuTestOk(String access);

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Optional update helper'**
  String get deviceHelperPage;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Helper status'**
  String get deviceHelperStatus;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Could not check the update helper.'**
  String get deviceHelperError;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Android can now install updates silently. The helper is not needed.'**
  String get deviceHelperUnneeded;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'This device currently needs confirmation on the screen to install updates through Android. The optional helper lets Kiosk Satellite install updates without a tap.'**
  String get deviceHelperIntro;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Installing an update.'**
  String get deviceHelperBusy;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Ready. Updates install without confirmation.'**
  String get deviceHelperReady;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Unavailable. Start the helper through ADB to enable updates without confirmation.'**
  String get deviceHelperUnavailable;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'The helper survives app restarts and updates but stops after a device reboot. Run the command from a computer with ADB to start it again. The computer can then disconnect.'**
  String get deviceHelperLifetime;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Start through ADB'**
  String get deviceHelperStart;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Setup guide'**
  String get deviceHelperGuide;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Read the update helper instructions and requirements.'**
  String get deviceHelperGuideHelp;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Update source'**
  String get settingUpdateSourceTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Where the app looks for new releases.'**
  String get settingUpdateSourceDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Repository URL'**
  String get settingUpdateSourceUrlTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'A folder on a web server the kiosk can reach, holding releases.json and the release APKs.'**
  String get settingUpdateSourceUrlDescription;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get deviceUpdatesPage;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'GitHub Repository'**
  String get deviceUpdateGithub;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Custom Repository'**
  String get deviceUpdateCustom;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Custom repository guide'**
  String get deviceUpdateGuide;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'How to host the releases file and the APKs on your own network.'**
  String get deviceUpdateGuideHelp;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Install from file'**
  String get deviceInstallFile;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Upload a Kiosk Satellite APK from a computer through the remote admin, on this same page. For a kiosk that cannot reach GitHub or a custom repository.'**
  String get deviceInstallFileHelp;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Upload a Kiosk Satellite APK from this computer and install it. For a kiosk that cannot reach GitHub or a custom repository.'**
  String get deviceInstallFileRemoteHelp;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Uploaded APK'**
  String get deviceUploadedApk;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Installing…'**
  String get deviceInstalling;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'The device did not answer.'**
  String get deviceDeviceNoAnswer;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Update failed. Check the device logs.'**
  String get deviceInstallFailed;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Confirm on the tablet screen'**
  String get deviceConfirmTablet;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Version {version} (build {build}, {size} MB) is on the device, waiting to be installed.'**
  String deviceUploadedVersion(String version, String build, String size);

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Install version {version}'**
  String deviceInstallVersion(String version);

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'The device answered HTTP {code}.'**
  String deviceHttpError(String code);

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'The upload failed.'**
  String get deviceUploadFailed;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Install on the fleet'**
  String get deviceInstallFleet;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Sending to the fleet…'**
  String get deviceSendingFleet;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'The kiosk already runs this build.'**
  String get deviceSameBuild;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'The install must be confirmed on the tablet screen unless the kiosk installs silently.'**
  String get deviceInstallConfirmation;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'This kiosk installs last.'**
  String get deviceSelfLast;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Updating the fleet'**
  String get deviceUpdatingFleet;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Uploading… {percent}%'**
  String deviceUploading(String percent);

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'The uploaded APK is version {version} (build {build}, {size} MB).'**
  String deviceUploadedDetails(String version, String build, String size);

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'The kiosk runs {version} (build {build}).'**
  String deviceCurrentBuild(String version, String build);

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Sending to {name}… {percent}%'**
  String deviceSendingTo(String name, String percent);

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Installing on {name}…'**
  String deviceInstallingOn(String name);

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'{names} installing.'**
  String deviceInstallingNames(String names);

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Enter the folder URL, for example http://nas.local/kiosk-satellite'**
  String get deviceUpdateUrlInvalid;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Enter only the folder URL, without anything after the path. Example: http://nas.local/kiosk-satellite'**
  String get deviceUpdateUrlPath;

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

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'App theme'**
  String get settingUiThemeTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Light or dark for the app\'s own screens: menu, settings, dialogs. System follows the Android setting.'**
  String get settingUiThemeDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Scale UI'**
  String get settingUiScaleTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Size of the app\'s own screens: menu, settings, dialogs. For high density displays. Web content keeps its size.'**
  String get settingUiScaleDescription;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'User Interface'**
  String get deviceUserInterface;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get deviceThemeDark;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get deviceThemeLight;

  /// Label or explanation on this Device settings page.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get deviceThemeSystem;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Hold mode'**
  String get settingHaHoldModeTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Keep the current view on screen: the screensaver, dashboard view rotation and the return to home timer are paused until turned off.'**
  String get settingHaHoldModeDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'End hold automatically after'**
  String get settingHaHoldReleaseMinutesTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Turns hold mode off by itself after the set time. Set to 0 to hold until turned off manually.'**
  String get settingHaHoldReleaseMinutesDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Show in the kiosk menu'**
  String get settingHaHoldMenuTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Adds a menu entry that turns hold mode on and off.'**
  String get settingHaHoldMenuDescription;

  /// Hold subpage summary or duration displayed beside the automatic release slider.
  ///
  /// In en, this message translates to:
  /// **'Pin the current view, automatic release, menu entry'**
  String get haHoldHint;

  /// Hold subpage summary or duration displayed beside the automatic release slider.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get haNever;

  /// Hold subpage summary or duration displayed beside the automatic release slider.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String haMinutes(String minutes);

  /// Hold subpage summary or duration displayed beside the automatic release slider.
  ///
  /// In en, this message translates to:
  /// **'{hours} h'**
  String haHours(String hours);

  /// Hold subpage summary or duration displayed beside the automatic release slider.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String haHoursMinutes(String hours, String minutes);

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Keep connected in the background'**
  String get settingDisableSuspendTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Turns off Home Assistant\'s \"Suspend background connections\" setting, which would otherwise drop the connection a few minutes after the screen goes off.'**
  String get settingDisableSuspendDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Pause dashboard during screensaver'**
  String get settingFreezeOnScreensaverTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Stops drawing the dashboard while the screensaver covers it, cutting CPU and GPU use; the connection stays live. Not for the Dim screensaver.'**
  String get settingFreezeOnScreensaverDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Filter dashboard updates'**
  String get settingWsFilterTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Only process updates for entities on the current view, cutting stutter on low-powered tablets. Views that cannot be resolved stay unfiltered.'**
  String get settingWsFilterDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Pause HA dashboard camera streams during screensaver'**
  String get settingPauseDashboardCamerasTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Pauses supported muted camera streams on the Home Assistant dashboard while the screensaver covers it. Streams reconnect when it closes. Does not affect the device camera or the Camera Streams feature.'**
  String get settingPauseDashboardCamerasDescription;

  /// Live update-filter status, diagnostic dialog label or explanation. Technical scan output and entity names stay as supplied.
  ///
  /// In en, this message translates to:
  /// **'Optimizations'**
  String get haOptimizations;

  /// Live update-filter status, diagnostic dialog label or explanation. Technical scan output and entity names stay as supplied.
  ///
  /// In en, this message translates to:
  /// **'Background connection, dashboard and camera pause, update filter'**
  String get haOptimizationsHint;

  /// Live update-filter status, diagnostic dialog label or explanation. Technical scan output and entity names stay as supplied.
  ///
  /// In en, this message translates to:
  /// **'Scan details are not available for the current view.'**
  String get haScanUnavailable;

  /// Live update-filter status, diagnostic dialog label or explanation. Technical scan output and entity names stay as supplied.
  ///
  /// In en, this message translates to:
  /// **'Dashboard scan details'**
  String get haScanDetails;

  /// Live update-filter status, diagnostic dialog label or explanation. Technical scan output and entity names stay as supplied.
  ///
  /// In en, this message translates to:
  /// **'Watched entities ({count})'**
  String haWatchedTitle(String count);

  /// Live update-filter status, diagnostic dialog label or explanation. Technical scan output and entity names stay as supplied.
  ///
  /// In en, this message translates to:
  /// **'Watched entities'**
  String get haWatched;

  /// Live update-filter status, diagnostic dialog label or explanation. Technical scan output and entity names stay as supplied.
  ///
  /// In en, this message translates to:
  /// **'The entity list is not available right now.'**
  String get haEntityListUnavailable;

  /// Live update-filter status, diagnostic dialog label or explanation. Technical scan output and entity names stay as supplied.
  ///
  /// In en, this message translates to:
  /// **'Watching {count} entities on this view.'**
  String haWatching(String count);

  /// Live update-filter status, diagnostic dialog label or explanation. Technical scan output and entity names stay as supplied.
  ///
  /// In en, this message translates to:
  /// **'No updates in the last minute.'**
  String get haNoUpdates;

  /// Live update-filter status, diagnostic dialog label or explanation. Technical scan output and entity names stay as supplied.
  ///
  /// In en, this message translates to:
  /// **'Filtered {percent}% of updates in the last minute ({dropped} of {total}).'**
  String haFiltered(String percent, String dropped, String total);

  /// Live update-filter status, diagnostic dialog label or explanation. Technical scan output and entity names stay as supplied.
  ///
  /// In en, this message translates to:
  /// **'Something on this page receives every entity update anyway, so filtering saves less here.'**
  String get haRawUpdates;

  /// Live update-filter status, diagnostic dialog label or explanation. Technical scan output and entity names stay as supplied.
  ///
  /// In en, this message translates to:
  /// **'This view reads all entity states, so its updates are not filtered.'**
  String get haAllStates;

  /// Live update-filter status, diagnostic dialog label or explanation. Technical scan output and entity names stay as supplied.
  ///
  /// In en, this message translates to:
  /// **'This view\'s entities can\'t be determined, so its updates are not filtered.'**
  String get haUnknownEntities;

  /// Live update-filter status, diagnostic dialog label or explanation. Technical scan output and entity names stay as supplied.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the dashboard to load…'**
  String get haWaiting;

  /// Live update-filter status, diagnostic dialog label or explanation. Technical scan output and entity names stay as supplied.
  ///
  /// In en, this message translates to:
  /// **'Show scan details.'**
  String get haShowScan;

  /// Live update-filter status, diagnostic dialog label or explanation. Technical scan output and entity names stay as supplied.
  ///
  /// In en, this message translates to:
  /// **'This view uses {count} entities, which crosses the filtering threshold. Filtering is disabled.'**
  String haThreshold(String count);

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Return to home dashboard view'**
  String get settingHaReturnHomeEnabledTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Go back to the dashboard configured above after a period of inactivity.'**
  String get settingHaReturnHomeEnabledDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Return after (seconds)'**
  String get settingHaReturnHomeSecondsTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Inactivity period before the kiosk goes back.'**
  String get settingHaReturnHomeSecondsDescription;

  /// Return-to-home subpage summary, disabled reason or destination.
  ///
  /// In en, this message translates to:
  /// **'Go back to the home view when left idle'**
  String get haReturnHint;

  /// Return-to-home subpage summary, disabled reason or destination.
  ///
  /// In en, this message translates to:
  /// **'Turned off while Dashboard view rotation is on.'**
  String get haReturnDisabled;

  /// Return-to-home subpage summary, disabled reason or destination.
  ///
  /// In en, this message translates to:
  /// **'The configured dashboard has no view path to return to.'**
  String get haReturnNoPath;

  /// Return-to-home subpage summary, disabled reason or destination.
  ///
  /// In en, this message translates to:
  /// **'Returns to \"{path}\" after the timeout.'**
  String haReturnPath(String path);

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Enable dashboard view rotation'**
  String get settingHaRotationEnabledTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Cycle through the selected dashboard views in an endless loop, showing each one for the chosen number of seconds.'**
  String get settingHaRotationEnabledDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Seconds per view'**
  String get settingHaRotationSecondsTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'How long each view stays on screen.'**
  String get settingHaRotationSecondsDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Pause rotation on interaction (seconds)'**
  String get settingHaRotationPauseSecondsTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Touching the screen pauses rotation for this long, and each touch restarts the countdown. Voice interactions pause until they end. 0 keeps rotating through touches.'**
  String get settingHaRotationPauseSecondsDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Fade between views'**
  String get settingHaRotationCrossfadeTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Fade out to the background and into the next view instead of switching instantly. Moving to a different dashboard or an external page still switches instantly.'**
  String get settingHaRotationCrossfadeDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Fade duration (seconds)'**
  String get settingHaRotationFadeSecondsTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Combined fade-out and fade-in time. Loading the next view can add time, especially on its first visit.'**
  String get settingHaRotationFadeSecondsDescription;

  /// Rotation subpage label, guidance or validation error.
  ///
  /// In en, this message translates to:
  /// **'Dashboard View Rotation'**
  String get haRotation;

  /// Rotation subpage label, guidance or validation error.
  ///
  /// In en, this message translates to:
  /// **'Cycle through views, dwell time, fade'**
  String get haRotationHint;

  /// Rotation subpage label, guidance or validation error.
  ///
  /// In en, this message translates to:
  /// **'Default view'**
  String get haDefaultView;

  /// Rotation subpage label, guidance or validation error.
  ///
  /// In en, this message translates to:
  /// **'External pages'**
  String get haExternalPages;

  /// Rotation subpage label, guidance or validation error.
  ///
  /// In en, this message translates to:
  /// **'Choose a fade duration from 0.2 to 5 seconds.'**
  String get haFadeError;

  /// Rotation subpage label, guidance or validation error.
  ///
  /// In en, this message translates to:
  /// **'Touch pauses rotation for this long; each touch restarts it. Voice interactions always pause until they end. 0 keeps rotating.'**
  String get haPauseRemoteHelp;

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

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Log in automatically'**
  String get settingHaAutoLoginTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Sign in to the dashboard with the access token above instead of showing the Home Assistant login page.'**
  String get settingHaAutoLoginDescription;

  /// Connection status, action or dashboard picker text.
  ///
  /// In en, this message translates to:
  /// **'Validate'**
  String get haValidate;

  /// Connection status, action or dashboard picker text.
  ///
  /// In en, this message translates to:
  /// **'Validate connection'**
  String get haValidateConnection;

  /// Connection status, action or dashboard picker text.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get haChecking;

  /// Connection status, action or dashboard picker text.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get haConnected;

  /// Connection status, action or dashboard picker text.
  ///
  /// In en, this message translates to:
  /// **'Connected.'**
  String get haConnectedRemote;

  /// Connection status, action or dashboard picker text.
  ///
  /// In en, this message translates to:
  /// **'Not validated yet. The settings below unlock once the connection checks out.'**
  String get haNotValidated;

  /// Connection status, action or dashboard picker text.
  ///
  /// In en, this message translates to:
  /// **'Could not connect.'**
  String get haConnectFailed;

  /// Connection status, action or dashboard picker text.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant URL and token not configured'**
  String get haNotConfigured;

  /// Connection status, action or dashboard picker text.
  ///
  /// In en, this message translates to:
  /// **'invalid token'**
  String get haInvalidToken;

  /// Connection status, action or dashboard picker text.
  ///
  /// In en, this message translates to:
  /// **'Could not reach Home Assistant: {error}'**
  String haUnreachable(String error);

  /// Connection status, action or dashboard picker text.
  ///
  /// In en, this message translates to:
  /// **'Secure context proxy'**
  String get haProxy;

  /// Connection status, action or dashboard picker text.
  ///
  /// In en, this message translates to:
  /// **'Routes a plain http Home Assistant through an in-app proxy so the browser unlocks the microphone and other https-only features. Only for http URLs.'**
  String get haProxyHelp;

  /// Connection status, action or dashboard picker text.
  ///
  /// In en, this message translates to:
  /// **'Routes a plain http Home Assistant through a proxy inside the app so the browser unlocks the microphone and other https-only features. Available only for http URLs.'**
  String get haProxyRemoteHelp;

  /// Connection status, action or dashboard picker text.
  ///
  /// In en, this message translates to:
  /// **'This Home Assistant URL uses plain http, and browsers block the microphone and other features on http pages. Kiosk Satellite will route the dashboard through a secure proxy inside the app so everything works. You may need to sign in to Home Assistant again.'**
  String get haProxyNotice;

  /// Connection status, action or dashboard picker text.
  ///
  /// In en, this message translates to:
  /// **'This Home Assistant URL uses plain http, and browsers block the microphone and other features on http pages. Kiosk Satellite will route the dashboard through a secure proxy inside the app so everything works. You may need to sign in to Home Assistant again on the tablet.'**
  String get haProxyRemoteNotice;

  /// Connection status, action or dashboard picker text.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get haDashboard;

  /// Connection status, action or dashboard picker text.
  ///
  /// In en, this message translates to:
  /// **'Choose a view'**
  String get haChooseView;

  /// Connection status, action or dashboard picker text.
  ///
  /// In en, this message translates to:
  /// **'Loading dashboards…'**
  String get haLoadingDashboards;

  /// Connection status, action or dashboard picker text.
  ///
  /// In en, this message translates to:
  /// **'Could not list dashboards'**
  String get haListFailed;

  /// Connection status, action or dashboard picker text.
  ///
  /// In en, this message translates to:
  /// **'Tap to retry.'**
  String get haRetryHint;

  /// Connection status, action or dashboard picker text.
  ///
  /// In en, this message translates to:
  /// **'Change view'**
  String get haChangeView;

  /// Connection status, action or dashboard picker text.
  ///
  /// In en, this message translates to:
  /// **'No sub views'**
  String get haNoViews;

  /// Connection status, action or dashboard picker text.
  ///
  /// In en, this message translates to:
  /// **'This dashboard has no selectable sub views.'**
  String get haNoViewsHelp;

  /// Connection status, action or dashboard picker text.
  ///
  /// In en, this message translates to:
  /// **'No dashboards found'**
  String get haNoDashboards;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingHaThemeTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Light or dark for the Home Assistant dashboard, also set from the Theme entity in Home Assistant. Auto follows the settings below.'**
  String get settingHaThemeDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Sync Home Assistant themes with Kiosk Satellite'**
  String get settingThemeMatchAppTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Automatically match your Home Assistant theme to your Kiosk Satellite interface.'**
  String get settingThemeMatchAppDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Match theme to time of day'**
  String get settingThemeAutoTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Switch Home Assistant between light and dark on a schedule. Keeps whatever theme is selected, flipping only its light/dark variant.'**
  String get settingThemeAutoDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Dark theme at'**
  String get settingThemeDarkAtTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Local time to switch to the dark theme.'**
  String get settingThemeDarkAtDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Light theme at'**
  String get settingThemeLightAtTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Local time to switch back to the light theme.'**
  String get settingThemeLightAtDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Also switch the app theme'**
  String get settingThemeAutoAppTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Flip Kiosk Satellite\'s own theme (menu, settings) together with the scheduled Home Assistant change.'**
  String get settingThemeAutoAppDescription;

  /// Theme subpage summary or automatic theme choice.
  ///
  /// In en, this message translates to:
  /// **'Match the app, or switch dark and light on a schedule'**
  String get haThemeHint;

  /// Theme subpage summary or automatic theme choice.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get haThemeAuto;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'HA kiosk mode'**
  String get settingHaKioskModeTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Hide the Home Assistant header and sidebar. Applies immediately.'**
  String get settingHaKioskModeDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Hide the header'**
  String get settingHaKioskHideHeaderTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Hide the dashboard toolbar and view tabs while HA kiosk mode is on. Leave off if you switch views from the header.'**
  String get settingHaKioskHideHeaderDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Hide the sidebar'**
  String get settingHaKioskHideSidebarTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Hide the navigation sidebar while HA kiosk mode is on.'**
  String get settingHaKioskHideSidebarDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Show in the kiosk menu'**
  String get settingHaKioskMenuTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Add an HA Kiosk Mode entry to the kiosk menu that turns it on and off.'**
  String get settingHaKioskMenuDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Enable dashboard carousel'**
  String get settingHaDashboardCarouselTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Swipe left or right on the dashboard to move between its views. Swipes on sliders, maps and scrolling cards are left alone.'**
  String get settingHaDashboardCarouselDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Capture swipe gestures over cards'**
  String get settingHaCarouselOverCardsTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Switch views even when the swipe starts on a card that reacts to swipes. Sliders still work normally.'**
  String get settingHaCarouselOverCardsDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Enable haptics'**
  String get settingHaHapticsTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Vibrate when buttons, switches, cards, sliders and thermostat dials are used. Requires a vibration motor.'**
  String get settingHaHapticsDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Vibration strength'**
  String get settingHaHapticsStrengthTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'How strong the vibration feels.'**
  String get settingHaHapticsStrengthDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Play tap sounds'**
  String get settingHaTapSoundTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Play the standard tap sound when buttons, switches, cards, sliders and thermostat dials are used.'**
  String get settingHaTapSoundDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Tap sound volume'**
  String get settingHaTapSoundVolumeTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'How loud the tap sound plays.'**
  String get settingHaTapSoundVolumeDescription;

  /// Subpage heading, summary or vibration choice. Light means gentle vibration, not a color theme.
  ///
  /// In en, this message translates to:
  /// **'User Interface'**
  String get haUserInterface;

  /// Subpage heading, summary or vibration choice. Light means gentle vibration, not a color theme.
  ///
  /// In en, this message translates to:
  /// **'Kiosk mode, dashboard carousel, haptics, tap sounds'**
  String get haInterfaceHint;

  /// Subpage heading, summary or vibration choice. Light means gentle vibration, not a color theme.
  ///
  /// In en, this message translates to:
  /// **'Haptics'**
  String get haHaptics;

  /// Subpage heading, summary or vibration choice. Light means gentle vibration, not a color theme.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get haVibrationLight;

  /// Subpage heading, summary or vibration choice. Light means gentle vibration, not a color theme.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get haVibrationMedium;

  /// Subpage heading, summary or vibration choice. Light means gentle vibration, not a color theme.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get haVibrationStrong;

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
