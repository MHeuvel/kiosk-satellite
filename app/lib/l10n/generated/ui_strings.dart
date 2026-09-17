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

  /// Page title.
  ///
  /// In en, this message translates to:
  /// **'Camera view'**
  String get cameraViewerTitle;

  /// Status shown over a camera tile.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get cameraViewerConnecting;

  /// Status shown over a camera tile.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting...'**
  String get cameraViewerReconnecting;

  /// Status shown over a camera tile.
  ///
  /// In en, this message translates to:
  /// **'Trying {transport}...'**
  String cameraViewerTrying(String transport);

  /// Status shown over a camera tile.
  ///
  /// In en, this message translates to:
  /// **'This device cannot decode {codec}'**
  String cameraViewerCannotDecode(String codec);

  /// Status shown over a camera tile.
  ///
  /// In en, this message translates to:
  /// **'This device cannot play {transport} streams'**
  String cameraViewerCannotPlay(String transport);

  /// Status shown over a camera tile.
  ///
  /// In en, this message translates to:
  /// **'This device cannot decode this stream'**
  String get cameraViewerCannotDecodeStream;

  /// Status shown over a camera tile.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach Home Assistant. Retrying in {seconds}s'**
  String cameraViewerHaRetry(String seconds);

  /// Status shown over a camera tile.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the camera server. Retrying in {seconds}s'**
  String cameraViewerServerRetry(String seconds);

  /// Status shown over a camera tile.
  ///
  /// In en, this message translates to:
  /// **'Connection failed. Retrying in {seconds}s'**
  String cameraViewerConnectionRetry(String seconds);

  /// Status shown over a camera tile.
  ///
  /// In en, this message translates to:
  /// **'The camera server could not start this stream. Retrying...'**
  String get cameraViewerStartRetry;

  /// Status shown over a camera tile.
  ///
  /// In en, this message translates to:
  /// **'The camera server could not start this stream. Retrying in {seconds}s'**
  String cameraViewerStartDelayedRetry(String seconds);

  /// Status shown over a camera tile.
  ///
  /// In en, this message translates to:
  /// **'Stream not found on the camera server. Retrying in {seconds}s'**
  String cameraViewerMissingRetry(String seconds);

  /// Status shown over a camera tile.
  ///
  /// In en, this message translates to:
  /// **'The camera server rejected the login. Retrying in {seconds}s'**
  String cameraViewerLoginRetry(String seconds);

  /// Status shown over a camera tile.
  ///
  /// In en, this message translates to:
  /// **'Stream missing from Go2RTC'**
  String get cameraViewerMissing;

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

  /// Shared dialog action, time picker label or color preset.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// Shared dialog action, time picker label or color preset.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get commonBrowse;

  /// Shared dialog action, time picker label or color preset.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get commonSet;

  /// Shared dialog action, time picker label or color preset.
  ///
  /// In en, this message translates to:
  /// **'Hour'**
  String get commonHour;

  /// Shared dialog action, time picker label or color preset.
  ///
  /// In en, this message translates to:
  /// **'Minute'**
  String get commonMinute;

  /// Shared dialog action, time picker label or color preset.
  ///
  /// In en, this message translates to:
  /// **'Up'**
  String get commonUp;

  /// Shared dialog action, time picker label or color preset.
  ///
  /// In en, this message translates to:
  /// **'Down'**
  String get commonDown;

  /// Shared dialog action, time picker label or color preset.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// Shared dialog action, time picker label or color preset.
  ///
  /// In en, this message translates to:
  /// **'Could not save'**
  String get commonSaveFailed;

  /// Shared dialog action, time picker label or color preset.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get commonColorWhite;

  /// Shared dialog action, time picker label or color preset.
  ///
  /// In en, this message translates to:
  /// **'Warm'**
  String get commonColorWarm;

  /// Shared dialog action, time picker label or color preset.
  ///
  /// In en, this message translates to:
  /// **'Amber'**
  String get commonColorAmber;

  /// Shared dialog action, time picker label or color preset.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get commonColorRed;

  /// Shared dialog action, time picker label or color preset.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get commonColorGreen;

  /// Shared dialog action, time picker label or color preset.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get commonColorBlue;

  /// Shared dialog action, time picker label or color preset.
  ///
  /// In en, this message translates to:
  /// **'Cyan'**
  String get commonColorCyan;

  /// Shared dialog action, time picker label or color preset.
  ///
  /// In en, this message translates to:
  /// **'Dim'**
  String get commonColorDim;

  /// Shared picker action or loading state.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// Shared picker action or loading state.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get commonMoveUp;

  /// Shared picker action or loading state.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get commonMoveDown;

  /// Shared picker action or loading state.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get commonPreviousMonth;

  /// Shared picker action or loading state.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get commonNextMonth;

  /// Shared picker action or loading state.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

  /// Button to choose an item.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get commonChoose;

  /// Validation error for the server port.
  ///
  /// In en, this message translates to:
  /// **'Enter a port between 1024 and 65535, or leave it empty'**
  String get dlnaPortInvalid;

  /// Playback failure caused by the device video decoder.
  ///
  /// In en, this message translates to:
  /// **'This device cannot decode this video.'**
  String get dlnaCannotDecode;

  /// Playback failure caused by an unreadable file.
  ///
  /// In en, this message translates to:
  /// **'This file could not be read.'**
  String get dlnaCannotRead;

  /// Playback failure or accessibility label for the failed media icon.
  ///
  /// In en, this message translates to:
  /// **'This media could not be played.'**
  String get dlnaCannotPlay;

  /// Help below a playback failure.
  ///
  /// In en, this message translates to:
  /// **'See the App Logs for details'**
  String get dlnaSeeLogs;

  /// Accessibility label for the loading spinner.
  ///
  /// In en, this message translates to:
  /// **'Loading media'**
  String get dlnaLoading;

  /// Accessibility label for the failed image icon.
  ///
  /// In en, this message translates to:
  /// **'This image could not be displayed.'**
  String get dlnaImageFailed;

  /// Accessibility label for tapping the overlay to stop playback.
  ///
  /// In en, this message translates to:
  /// **'Stop playback'**
  String get dlnaStop;

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

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get intercomCall;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'No kiosk is ready.'**
  String get intercomNoReady;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'1 kiosk is ready.'**
  String get intercomOneReady;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'{count} kiosks are ready.'**
  String intercomManyReady(String count);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Call a kiosk'**
  String get intercomCallKiosk;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Announce to all'**
  String get intercomAnnounceAll;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Talk to every kiosk. One way only.'**
  String get intercomAnnounceHelp;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Missed call from {name}'**
  String intercomMissedFrom(String name);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Rang for {seconds} seconds.'**
  String intercomRangFor(String seconds);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Call back'**
  String get intercomCallBack;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get intercomDeclined;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Busy'**
  String get intercomBusy;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Its intercom is off'**
  String get intercomPeerOff;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Different intercom key'**
  String get intercomPeerKey;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'No answer'**
  String get intercomNoAnswer;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Did not answer'**
  String get intercomDidNotAnswer;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'The voice link failed'**
  String get intercomVoiceFailed;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get intercomCancelled;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'The page took the microphone'**
  String get intercomPageMic;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Nobody could take it'**
  String get intercomNobody;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get intercomDone;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Call ended'**
  String get intercomEnded;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Announcement'**
  String get intercomAnnouncement;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Announcing to 1 kiosk'**
  String get intercomAnnouncingOne;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Announcing to {count} kiosks'**
  String intercomAnnouncingMany(String count);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'is calling'**
  String get intercomIsCalling;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'is announcing'**
  String get intercomIsAnnouncing;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Calling…'**
  String get intercomCalling;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Answers in {seconds} s'**
  String intercomAnswersIn(String seconds);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Ringing'**
  String get intercomRinging;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get intercomConnecting;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Done, {duration}'**
  String intercomDoneDuration(String duration);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Call ended, {duration}'**
  String intercomEndedDuration(String duration);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get intercomDecline;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get intercomAnswer;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Every kiosk'**
  String get intercomEveryKiosk;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get intercomStop;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'{name} hears you'**
  String intercomHearsYou(String name);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Every kiosk hears you'**
  String get intercomAllHearYou;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Hold to talk, let go to listen'**
  String get intercomHoldHelp;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Muted'**
  String get intercomMuted;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get intercomMute;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get intercomEnd;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get intercomReply;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get intercomDismiss;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Call again'**
  String get intercomCallAgain;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'The dashboard holds the microphone, listening only.'**
  String get intercomDashboardMic;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Microphone not granted, listening only.'**
  String get intercomMicDenied;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Hold to talk'**
  String get intercomHoldTalk;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Playing'**
  String get intercomPlaying;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'a kiosk'**
  String get intercomAKiosk;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Calling {name}'**
  String intercomCallingName(String name);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'{name} is calling'**
  String intercomNameCalling(String name);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'In a call with {name}'**
  String intercomInCallName(String name);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'{name} is announcing'**
  String intercomNameAnnouncing(String name);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant: {message}'**
  String intercomHaMessage(String message);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'End call'**
  String get intercomEndCall;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Could not call'**
  String get intercomCallFailed;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Could not change the key'**
  String get intercomKeyFailed;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Could not talk to everyone'**
  String get intercomBroadcastFailed;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'The device did not answer.'**
  String get intercomDeviceNoAnswer;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'unknown kiosk'**
  String get intercomUnknownKiosk;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'nothing is ringing'**
  String get intercomNothingRinging;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'no call'**
  String get intercomNoCall;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'intercom is off'**
  String get intercomDisabled;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'needs the remote admin'**
  String get intercomNeedsRemote;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'the intercom needs the remote admin and Find other kiosks'**
  String get intercomNeedsDiscovery;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'already in a call'**
  String get intercomAlreadyCalling;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'no kiosk is ready'**
  String get intercomNoReadyError;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'a key is at least 16 characters'**
  String get intercomKeyLength;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'the page holds the microphone'**
  String get intercomMicHeld;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'microphone not granted'**
  String get intercomMicPermission;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'the caller did not answer'**
  String get intercomCallerNoAnswer;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Missed call'**
  String get intercomMissedcall;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Listening'**
  String get intercomListening;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Announcements off'**
  String get intercomAnnouncementsoff;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Kiosk PIN'**
  String get kioskPinTitle;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get kioskPinHint;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN'**
  String get kioskWrongPin;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get kioskUnlock;

  /// Playback button tooltip and accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get mediaPlay;

  /// Playback button tooltip and accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get mediaPause;

  /// Playback button tooltip and accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Previous track'**
  String get mediaPreviousTrack;

  /// Playback button tooltip and accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Next track'**
  String get mediaNextTrack;

  /// Playback status or fallback text when a floating player track has no title.
  ///
  /// In en, this message translates to:
  /// **'Playing'**
  String get mediaPlaying;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get mediaPaused;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get mediaIdle;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Status unavailable'**
  String get mediaStatusUnavailable;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Unknown track'**
  String get mediaUnknownTrack;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'{status} - {source}'**
  String mediaStatusSource(String status, String source);

  /// Button tooltip or slider accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Show volume'**
  String get mediaShowVolume;

  /// Button tooltip or slider accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Hide volume'**
  String get mediaHideVolume;

  /// Button tooltip or slider accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get mediaMute;

  /// Button tooltip or slider accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get mediaUnmute;

  /// Button tooltip or slider accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get mediaFavoriteAdd;

  /// Button tooltip or slider accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get mediaFavoriteRemove;

  /// Button tooltip or slider accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Turn shuffle on'**
  String get mediaShuffleOn;

  /// Button tooltip or slider accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Turn shuffle off'**
  String get mediaShuffleOff;

  /// Button tooltip or slider accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Repeat all'**
  String get mediaRepeatAll;

  /// Button tooltip or slider accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Repeat one'**
  String get mediaRepeatOne;

  /// Button tooltip or slider accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Turn repeat off'**
  String get mediaRepeatOff;

  /// Button tooltip or slider accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Show lyrics'**
  String get mediaShowLyrics;

  /// Button tooltip or slider accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Hide lyrics'**
  String get mediaHideLyrics;

  /// Button tooltip or slider accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Show queue'**
  String get mediaShowQueue;

  /// Button tooltip or slider accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Hide queue'**
  String get mediaHideQueue;

  /// Button tooltip or slider accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get mediaVolume;

  /// Button tooltip or slider accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Playback position'**
  String get mediaPlaybackPosition;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Show Now Playing'**
  String get mediaShowNowPlaying;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Show the floating player'**
  String get mediaShowFloatingPlayer;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Open Music Assistant'**
  String get mediaOpenMusicAssistant;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'command not supported or not sent'**
  String get mediaCannotControl;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Nothing queued'**
  String get mediaNothingQueued;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Chapters'**
  String get mediaChapters;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Now playing'**
  String get mediaNowPlaying;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Up next'**
  String get mediaUpNext;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Chapter {number}'**
  String mediaUnnamedChapter(String number);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Leads the group'**
  String get mediaGroupLead;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'The group could not be read.'**
  String get mediaGroupReadFailed;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'No other players to group with.'**
  String get mediaGroupEmpty;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Speaker selection'**
  String get mediaSpeakerSelection;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Enable camera'**
  String get settingCameraEnabledTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Camera use adds CPU load and heat, which can shorten the battery and device lifespan.'**
  String get settingCameraEnabledDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get settingCameraDeviceTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Which camera to use.'**
  String get settingCameraDeviceDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Snapshot resolution'**
  String get settingCameraSnapshotResolutionTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Higher looks sharper but costs more CPU and bandwidth.'**
  String get settingCameraSnapshotResolutionDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Disable snapshots on detection'**
  String get settingCameraDisableDetectionSnapshotsTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Prevent automatic snapshots triggered by detection. Motion, face, presence and gesture detection keep working. Manual requests and Continuous snapshots can still capture images.'**
  String get settingCameraDisableDetectionSnapshotsDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Continuous snapshots'**
  String get settingCameraSnapshotsTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Publish a fresh camera snapshot to Home Assistant at a fixed interval.'**
  String get settingCameraSnapshotsDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Snapshot interval'**
  String get settingCameraSnapshotIntervalTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Seconds between snapshots.'**
  String get settingCameraSnapshotIntervalDescription;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Front'**
  String get cameraFront;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get cameraBack;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'The only camera this device has.'**
  String get cameraOnlyCamera;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Motion sensor'**
  String get settingMotionSensorTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Expose motion as a Home Assistant sensor. WARNING: Keeps the camera running permanently, even with the screen off.'**
  String get settingMotionSensorDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Clear after'**
  String get settingMotionSensorOffDelayTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Seconds without motion before the sensor reads clear.'**
  String get settingMotionSensorOffDelayDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Motion frame rate'**
  String get settingMotionFpsTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Frames per second the camera checks for motion. Lower is lighter on the CPU; 2 is plenty to notice someone approaching.'**
  String get settingMotionFpsDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Startup delay'**
  String get settingMotionStartDelayTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Ignore motion for this long after the camera starts, for devices whose camera physically moves as it opens.'**
  String get settingMotionStartDelayDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Motion sensitivity'**
  String get settingMotionSensitivityTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Higher trips on smaller movements. 1 needs a large change across the frame; 100 reacts to the slightest motion.'**
  String get settingMotionSensitivityDescription;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Motion Sensor'**
  String get cameraMotionPage;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant motion sensor and shared detection settings'**
  String get cameraMotionHint;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'No camera detected'**
  String get cameraNoCamera;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'This device does not report any usable camera.'**
  String get cameraNoCameraHelp;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Camera permission missing'**
  String get cameraCameraPermission;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Without it the camera cannot be used. The grant dialog appears on the tablet screen.'**
  String get cameraCameraPermissionHelp;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Grant on device'**
  String get cameraGrantOnDevice;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Blocked. Android will not ask again, so allow it in the app settings.'**
  String get cameraCameraBlocked;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Without this the camera cannot be used.'**
  String get cameraCameraNeeded;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'App settings'**
  String get cameraAppSettings;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Latest snapshot'**
  String get cameraLatest;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'No snapshot yet.'**
  String get cameraNoSnapshot;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Latest camera snapshot'**
  String get cameraImageAlt;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Take snapshot'**
  String get cameraTakeSnapshot;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Snapshot failed.'**
  String get cameraSnapshotFailed;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Snapshot failed: {error}'**
  String cameraSnapshotError(String error);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'The camera is disabled in the Camera settings.'**
  String get cameraCameraDisabled;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'A snapshot is already in progress.'**
  String get cameraSnapshotBusy;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Camera permission not granted.'**
  String get cameraPermissionDenied;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Detection snapshots are disabled.'**
  String get cameraDetectionDisabled;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'The camera returned no image.'**
  String get cameraNoImage;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'The camera did not answer in time.'**
  String get cameraTimedOut;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'The camera is unavailable while the app is in the background.'**
  String get cameraBackground;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get cameraJustNow;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'{count} seconds ago'**
  String cameraSecondsAgo(String count);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'1 minute ago'**
  String get cameraMinuteAgo;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'{count} minutes ago'**
  String cameraMinutesAgo(String count);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'1 hour ago'**
  String get cameraHourAgo;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'{count} hours ago'**
  String cameraHoursAgo(String count);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'1 day ago'**
  String get cameraDayAgo;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String cameraDaysAgo(String count);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Stream Status'**
  String get cameraStatusHeading;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Connected Clients'**
  String get cameraClientsHeading;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get cameraUnavailable;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get cameraStopped;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Streaming'**
  String get cameraStreaming;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get cameraIdle;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get cameraConnected;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Checking...'**
  String get cameraChecking;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Checking stream status...'**
  String get cameraCheckingStatus;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Stream status unavailable.'**
  String get cameraStatusUnavailable;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Listener is stopped.'**
  String get cameraListenerStopped;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'{count} connected viewer. Actual video: {resolution}.'**
  String cameraViewer(String count, String resolution);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'{count} connected viewers. Actual video: {resolution}.'**
  String cameraViewers(String count, String resolution);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Ready. The encoder starts when a viewer connects.'**
  String get cameraReady;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Requested {requested}, camera supplied {actual}.'**
  String cameraFallback(String requested, String actual);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Audio: {error}'**
  String cameraAudioError(String error);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Audio paused while the browser uses the microphone.'**
  String get cameraAudioPaused;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Microphone audio streaming.'**
  String get cameraAudioStreaming;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Microphone audio idle.'**
  String get cameraAudioIdle;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'ONVIF discovery: {error}'**
  String cameraDiscoveryError(String error);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'ONVIF URL'**
  String get cameraOnvifUrl;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Stream URL'**
  String get cameraStreamUrl;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a network address'**
  String get cameraWaitingAddress;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Client information unavailable.'**
  String get cameraClientsUnavailable;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'No connected clients.'**
  String get cameraNoClients;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'{status} · {transport} · Port {port}'**
  String cameraClientDetails(String status, String transport, String port);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Connected for {duration}'**
  String cameraConnectedFor(String duration);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String cameraDurationSeconds(String seconds);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m {seconds}s'**
  String cameraDurationMinutes(String minutes, String seconds);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String cameraDurationHours(String hours, String minutes);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Set a streaming username and password to enable authentication.'**
  String get cameraCredentialsMissing;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the RTSP port to be released.'**
  String get cameraPortWaiting;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Could not start the RTSP listener.'**
  String get cameraListenerFailed;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Enable camera streaming'**
  String get settingCameraRtspEnabledTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Share H.264 video with RTSP or ONVIF clients. Video encoding runs only while a viewer is connected. Hardware encoding is preferred with software fallback when needed. Uses the camera selected in Camera settings.'**
  String get settingCameraRtspEnabledDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Streaming protocol'**
  String get settingCameraStreamingProtocolTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'ONVIF lets compatible clients discover the camera and connect to its stream.'**
  String get settingCameraStreamingProtocolDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get settingCameraRtspPortTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'RTSP server port.'**
  String get settingCameraRtspPortDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get settingCameraOnvifPortTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'ONVIF server port.'**
  String get settingCameraOnvifPortDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get settingCameraRtspResolutionTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Supported streaming sizes for the selected camera and encoder. Video follows the device orientation.'**
  String get settingCameraRtspResolutionDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Motion analysis while streaming'**
  String get settingCameraRtspAnalysisTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Keep motion detection, face detection and hand gestures available while viewers are connected. Turning this off can allow higher resolutions. Snapshots then use video frames at the streaming resolution.'**
  String get settingCameraRtspAnalysisDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Frame rate'**
  String get settingCameraRtspFpsTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Target video frames per second. Motion keeps its separate analysis rate. Actual delivery depends on the camera.'**
  String get settingCameraRtspFpsDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Bitrate'**
  String get settingCameraRtspBitrateTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Target video bitrate. Higher improves detail and uses more network bandwidth.'**
  String get settingCameraRtspBitrateDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Include microphone audio'**
  String get settingCameraRtspAudioTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Include microphone audio in the camera stream. Shares your microphone settings. WARNING: Increased CPU usage.'**
  String get settingCameraRtspAudioDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Require authentication'**
  String get settingCameraRtspAuthTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Require a username and password to view the stream. Streaming traffic is not encrypted.'**
  String get settingCameraRtspAuthDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get settingCameraRtspUsernameTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Username for streaming clients.'**
  String get settingCameraRtspUsernameDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get settingCameraRtspPasswordTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Set a password to start the authenticated stream.'**
  String get settingCameraRtspPasswordDescription;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'RTSP & ONVIF Streaming'**
  String get cameraStreamingPage;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Share the device camera via RTSP or ONVIF'**
  String get cameraStreamingHint;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole port number from 1024 to 65535.'**
  String get cameraPortError;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Use 1 to 64 characters without spaces, quotes, colons or backslashes.'**
  String get cameraUsernameError;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'No supported sizes available'**
  String get cameraNoSizes;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'No supported sizes available. Check the camera connection.'**
  String get cameraNoSizesHelp;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Resolution support'**
  String get cameraResolutionSupport;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Checking camera and H.264 encoder support...'**
  String get cameraCheckingSizes;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Only sizes supported by the camera and H.264 encoder at the current streaming settings are listed.'**
  String get cameraSupportedSizes;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Turn off Motion analysis while streaming to also use {sizes}.'**
  String cameraExtraSizes(String sizes);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Motion detection, face detection and hand gestures pause while viewers are connected. Snapshots use video frames at the streaming resolution.'**
  String get cameraAnalysisOff;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'The encoder cannot use {sizes} at these settings.'**
  String cameraRejectedSizes(String sizes);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'{count} camera sizes are excluded because the encoder cannot use them at these settings.'**
  String cameraRejectedCount(String count);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Other camera sizes are unavailable in the current capture setup.'**
  String get cameraCaptureRejected;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'name required'**
  String get cameraStreamsNameRequired;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'valid HTTP or HTTPS baseUrl required'**
  String get cameraStreamsBaseUrlRequired;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'server not found'**
  String get cameraStreamsServerNotFound;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Go2RTC returned an invalid stream list'**
  String get cameraStreamsInvalidStreamList;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'kind must be go2rtc, whep or ha'**
  String get cameraStreamsKindRequired;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'preferredProtocol must be auto, webrtc, hls or mjpeg'**
  String get cameraStreamsProtocolRequired;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'valid serverId required'**
  String get cameraStreamsServerRequired;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'streamName required'**
  String get cameraStreamsStreamRequired;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'a camera.* entityId is required'**
  String get cameraStreamsEntityRequired;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'valid WHEP URL required'**
  String get cameraStreamsWhepRequired;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'camera not found'**
  String get cameraStreamsCameraNotFound;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'cameraIds must be a list'**
  String get cameraStreamsListRequired;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'a view must contain 1 to 12 cameras'**
  String get cameraStreamsViewCount;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'a camera can appear only once per view'**
  String get cameraStreamsRepeatedCamera;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'view contains an unknown camera'**
  String get cameraStreamsUnknownViewCamera;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'view name must be unique'**
  String get cameraStreamsUniqueViewName;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'grid must be between 1 and 12'**
  String get cameraStreamsGridRange;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'grid is smaller than the camera count'**
  String get cameraStreamsGridTooSmall;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'view not found'**
  String get cameraStreamsViewNotFound;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'the default view cannot be deleted; empty it instead'**
  String get cameraStreamsDefaultViewDelete;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'view has no cameras'**
  String get cameraStreamsViewEmpty;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'could not read Home Assistant: {error}'**
  String cameraStreamsHaReadFailed(String error);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'could not connect to {server}: {error}'**
  String cameraStreamsConnectFailed(String server, String error);

  /// Import error.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant is not configured or unreachable'**
  String get cameraStreamsHaUnavailable;

  /// Import error.
  ///
  /// In en, this message translates to:
  /// **'Go2RTC returned HTTP {status}'**
  String cameraStreamsHttpError(String status);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Import cameras from Home Assistant'**
  String get cameraStreamsImportHa;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Add every camera of the connected Home Assistant, playing over WebRTC, HLS or MJPEG. Importing again merges new cameras.'**
  String get cameraStreamsImportHaHelp;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Import failed'**
  String get cameraStreamsImportFailed;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Import complete'**
  String get cameraStreamsImportComplete;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'{added} added, {missing} missing.'**
  String cameraStreamsImportCounts(String added, String missing);

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Allow H.265 streams'**
  String get settingCameraAllowH265Title;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Play H.265 camera streams as they are. A device that cannot decode H.265 shows a blank image instead.'**
  String get settingCameraAllowH265Description;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Prefer MSE over WebRTC'**
  String get settingCameraPreferMseTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Stream Go2RTC cameras over MSE first. For devices that cannot play WebRTC; adds a second or two of delay.'**
  String get settingCameraPreferMseDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Prefer HLS over WebRTC'**
  String get settingCameraPreferHlsTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Stream Home Assistant cameras over HLS first. For devices that cannot play WebRTC; adds a few seconds of delay.'**
  String get settingCameraPreferHlsDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Play sound for a single camera'**
  String get settingCameraSingleAudioTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Play the camera\'s sound when only one camera is on screen. Grids with several cameras stay silent.'**
  String get settingCameraSingleAudioDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Pinch to zoom a single camera'**
  String get settingCameraPinchZoomTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Zoom into the picture with two fingers when only one camera is on screen. Drag to move around, double-tap to reset.'**
  String get settingCameraPinchZoomDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Auto-dismiss after'**
  String get settingCameraAutoDismissSecondsTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Close an opened camera view on its own; 0 keeps it up. The camera screensaver is unaffected.'**
  String get settingCameraAutoDismissSecondsDescription;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get cameraStreamsPlayback;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get cameraStreamsOff;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String cameraStreamsSeconds(String seconds);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Grids with several cameras are video-only. For low-power devices, use lower resolution Go2RTC streams in views and optionally set a separate fullscreen stream.'**
  String get cameraStreamsGridHelp;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Go2RTC servers'**
  String get cameraStreamsServers;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Import streams'**
  String get cameraStreamsImportStreams;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Delete server'**
  String get cameraStreamsDeleteServer;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Add Go2RTC server'**
  String get cameraStreamsAddServer;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Connect to a server and import its streams.'**
  String get cameraStreamsAddServerHelp;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Edit server'**
  String get cameraStreamsEditServer;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get cameraStreamsName;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get cameraStreamsBaseUrl;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Username (optional)'**
  String get cameraStreamsUsername;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'New password (leave blank to keep)'**
  String get cameraStreamsNewPassword;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Password (optional)'**
  String get cameraStreamsPassword;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Allow invalid TLS certificate'**
  String get cameraStreamsInvalidCertificate;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Could not save the server'**
  String get cameraStreamsSaveServerFailed;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Its cameras will be removed from every view.'**
  String get cameraStreamsDeleteServerHelp;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Cameras'**
  String get cameraStreamsCameras;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'No cameras configured'**
  String get cameraStreamsNoCameras;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Import cameras from Home Assistant or Go2RTC, or add one manually.'**
  String get cameraStreamsNoCamerasHelp;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Delete camera'**
  String get cameraStreamsDeleteCamera;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Add camera manually'**
  String get cameraStreamsAddManually;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Use a Go2RTC stream name, a WHEP URL or a Home Assistant camera entity.'**
  String get cameraStreamsAddManuallyHelp;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Unknown camera'**
  String get cameraStreamsUnknownCamera;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Unknown server'**
  String get cameraStreamsUnknownServer;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **' (missing)'**
  String get cameraStreamsMissing;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Add camera'**
  String get cameraStreamsAddCamera;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Edit camera'**
  String get cameraStreamsEditCamera;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get cameraStreamsType;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Go2RTC stream'**
  String get cameraStreamsGo2RtcStream;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Direct WHEP URL'**
  String get cameraStreamsDirectWhep;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant camera'**
  String get cameraStreamsHaCamera;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Camera entity'**
  String get cameraStreamsEntity;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Preferred protocol'**
  String get cameraStreamsProtocol;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get cameraStreamsAuto;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get cameraStreamsServer;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Stream name'**
  String get cameraStreamsStreamName;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Go2RTC stream name'**
  String get cameraStreamsGo2RtcStreamName;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen stream (optional)'**
  String get cameraStreamsFullscreen;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'WHEP URL'**
  String get cameraStreamsWhep;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Could not save the camera'**
  String get cameraStreamsSaveCameraFailed;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'It will be removed from every view.'**
  String get cameraStreamsDeleteCameraHelp;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Could not load cameras.'**
  String get cameraStreamsLoadFailed;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Views'**
  String get cameraStreamsViews;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'No cameras yet'**
  String get cameraStreamsEmptyView;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Names shown'**
  String get cameraStreamsNamesShown;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Names hidden'**
  String get cameraStreamsNamesHidden;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Show view'**
  String get cameraStreamsShowView;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Delete view'**
  String get cameraStreamsDeleteView;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Create camera view'**
  String get cameraStreamsCreateView;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Add a camera first.'**
  String get cameraStreamsAddFirst;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Choose and order up to 12 cameras.'**
  String get cameraStreamsChooseCameras;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Could not show the view'**
  String get cameraStreamsShowFailed;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Could not show view'**
  String get cameraStreamsShowFailedRemote;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Edit view'**
  String get cameraStreamsEditView;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Show camera names'**
  String get cameraStreamsShowNames;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Display a label over each camera.'**
  String get cameraStreamsShowNamesHelp;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get cameraStreamsGrid;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'{count} Camera'**
  String cameraStreamsOneCamera(String count);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'{count} Cameras'**
  String cameraStreamsManyCameras(String count);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'In this view'**
  String get cameraStreamsInView;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get cameraStreamsAvailable;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Position {position}'**
  String cameraStreamsPosition(String position);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Missing from Go2RTC'**
  String get cameraStreamsMissingGo2Rtc;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Could not save the view'**
  String get cameraStreamsSaveViewFailed;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String cameraStreamsDeleteNamed(String name);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get cameraStreamsCannotUndo;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get cameraStreamsShow;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get cameraStreamsStop;

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
  /// **'Enable DLNA renderer'**
  String get settingDlnaEnabledTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Show images and play media pushed from Home Assistant or any DLNA app. The device appears as a media player named after the device name.'**
  String get settingDlnaEnabledDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Keep audio in the background'**
  String get settingDlnaAudioBackgroundTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Pushed audio plays without taking over the screen.'**
  String get settingDlnaAudioBackgroundDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Server port'**
  String get settingDlnaPortTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'The port the renderer is on, filled in when it starts. Change it to move the renderer, or clear it to let it pick again.'**
  String get settingDlnaPortDescription;

  /// Placeholder in the empty server port field.
  ///
  /// In en, this message translates to:
  /// **'Set when the renderer starts'**
  String get settingDlnaPortPlaceholder;

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

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Act as the home screen'**
  String get settingHomeLauncherEnabledTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Register Kiosk Satellite as the device home screen: the kiosk starts at boot and every home press returns to it. Turns itself off and restores the previous launcher if the app fails to start repeatedly.'**
  String get settingHomeLauncherEnabledDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Keep screen pinning'**
  String get settingHomeKeepPinningTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Pin the screen even while Kiosk Satellite is the home screen. Blocks recents and back natively, but brings back the pinning confirmation dialog on devices without device ownership.'**
  String get settingHomeKeepPinningDescription;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Home screen'**
  String get kioskHomeScreen;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Checking the device...'**
  String get kioskCheckingDevice;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Fire OS does not allow replacing its launcher.'**
  String get kioskFireOs;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'This device does not allow changing the home screen.'**
  String get kioskUnsupported;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Turned off automatically after repeated failed starts; the previous launcher was restored. Turn the switch back on to try again.'**
  String get kioskRecovered;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Kiosk Satellite is the home screen. The kiosk starts at boot and every home press returns to it.'**
  String get kioskHeld;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Not the home screen. Turn on Act as the home screen above.'**
  String get kioskDisabled;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Not the current home screen yet: the device is waiting for a confirmation.'**
  String get kioskWaiting;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Open home settings'**
  String get kioskOpenHomeSettings;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Set as default'**
  String get kioskSetDefault;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get kioskActive;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Not the home screen.'**
  String get kioskNotHome;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a confirmation on the device: the system dialog or home settings open there.'**
  String get kioskWaitingRemote;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Set on device'**
  String get kioskSetDevice;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Answer mode'**
  String get settingIntercomAnswerModeTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Ring asks on the screen. Answer automatically opens the call after a chime.'**
  String get settingIntercomAnswerModeDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Ring for'**
  String get settingIntercomRingSecondsTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'How long a call rings before it counts as missed.'**
  String get settingIntercomRingSecondsDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Ring sound'**
  String get settingIntercomRingSoundTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Plays at the notification volume.'**
  String get settingIntercomRingSoundDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Accept announcements'**
  String get settingIntercomAcceptAnnouncementsTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Play Announce to all from the other kiosks.'**
  String get settingIntercomAcceptAnnouncementsDescription;

  /// Visible option. Its stored value stays unchanged.
  ///
  /// In en, this message translates to:
  /// **'Ring'**
  String get intercomOptionAnswerRing;

  /// Visible option. Its stored value stays unchanged.
  ///
  /// In en, this message translates to:
  /// **'Answer automatically'**
  String get intercomOptionAnswerAuto;

  /// Visible option. Its stored value stays unchanged.
  ///
  /// In en, this message translates to:
  /// **'Do not disturb'**
  String get intercomOptionAnswerDnd;

  /// Visible option. Its stored value stays unchanged.
  ///
  /// In en, this message translates to:
  /// **'15 seconds'**
  String get intercomOptionAnswer15;

  /// Visible option. Its stored value stays unchanged.
  ///
  /// In en, this message translates to:
  /// **'30 seconds'**
  String get intercomOptionAnswer30;

  /// Visible option. Its stored value stays unchanged.
  ///
  /// In en, this message translates to:
  /// **'45 seconds'**
  String get intercomOptionAnswer45;

  /// Visible option. Its stored value stays unchanged.
  ///
  /// In en, this message translates to:
  /// **'60 seconds'**
  String get intercomOptionAnswer60;

  /// Section heading.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get intercomAnswerSection;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Enable intercom'**
  String get settingIntercomEnabledTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Call the other kiosks on this network and take their calls.'**
  String get settingIntercomEnabledDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Intercom key'**
  String get settingIntercomKeyTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Kiosks with the same key can call each other. Fleet Management can sync it.'**
  String get settingIntercomKeyDescription;

  /// Placeholder for the key before the intercom is enabled.
  ///
  /// In en, this message translates to:
  /// **'Made when the intercom is enabled'**
  String get settingIntercomKeyPlaceholder;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Show in the kiosk menu'**
  String get settingIntercomMenuTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Add an Intercom entry to the kiosk menu.'**
  String get settingIntercomMenuDescription;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'The intercom needs the remote admin'**
  String get intercomNeedsAdmin;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Kiosks find and reach each other through it. Turn on Remote management and Find other kiosks under Device, then come back.'**
  String get intercomAdminHelp;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Change key'**
  String get intercomChangeKey;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Paste the key from another kiosk, or make a new one.'**
  String get intercomChangeKeyHelp;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get intercomChange;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Kiosks with this key can call each other. A new key cuts this kiosk off from the others until they get it too.'**
  String get intercomKeyWarning;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get intercomRegenerate;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Key changed'**
  String get intercomKeyChanged;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get intercomNotSet;

  /// Action or validation message.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get intercomOpen;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Kiosks'**
  String get intercomKiosks;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Kiosks discovered on this network. A kiosk is ready once its intercom is on with the same key.'**
  String get intercomRosterHelp;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'No other kiosk heard'**
  String get intercomNoOther;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Kiosks with Remote management and Find other kiosks on show up here.'**
  String get intercomRosterDeviceHelp;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'No kiosks heard'**
  String get intercomNoneHeard;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'A kiosk shows up once its remote admin is on and it shares this network.'**
  String get intercomRosterRemoteHelp;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get intercomReady;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Intercom off'**
  String get intercomOff;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Different key'**
  String get intercomDifferentKey;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Unreachable'**
  String get intercomUnreachable;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get intercomOffline;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get intercomChecking;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Talk mode'**
  String get settingIntercomTalkModeTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Push to talk sends while the button is held. Hands free keeps the microphone open for the whole call.'**
  String get settingIntercomTalkModeDescription;

  /// Visible option. Its stored value stays unchanged.
  ///
  /// In en, this message translates to:
  /// **'Push to talk'**
  String get intercomOptionTalkPtt;

  /// Visible option. Its stored value stays unchanged.
  ///
  /// In en, this message translates to:
  /// **'Hands free'**
  String get intercomOptionTalkHandsfree;

  /// Section heading.
  ///
  /// In en, this message translates to:
  /// **'Talk'**
  String get intercomTalkSection;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Allow menu with quick actions'**
  String get settingKioskAllowDrawerTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'An edge swipe opens the menu without the exit gesture or PIN, limited to the actions selected below.'**
  String get settingKioskAllowDrawerDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get settingKioskAllowDashboardTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Reload the start page.'**
  String get settingKioskAllowDashboardDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'HA Kiosk Mode'**
  String get settingKioskAllowHaKioskTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Show or hide the Home Assistant header and sidebar.'**
  String get settingKioskAllowHaKioskDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Camera View'**
  String get settingKioskAllowCameraTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Open the default camera view.'**
  String get settingKioskAllowCameraDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Intercom'**
  String get settingKioskAllowIntercomTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Call other kiosks from the kiosk menu.'**
  String get settingKioskAllowIntercomDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Music Assistant'**
  String get settingKioskAllowMusicTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Open the Music Assistant web interface.'**
  String get settingKioskAllowMusicDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Floating Player'**
  String get settingKioskAllowSendspinPlayerTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Show or hide the floating player and open Now Playing.'**
  String get settingKioskAllowSendspinPlayerDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Start Screensaver'**
  String get settingKioskAllowScreensaverTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Start the screensaver now.'**
  String get settingKioskAllowScreensaverDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Hold Mode'**
  String get settingKioskAllowHoldTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Turn hold mode on or off.'**
  String get settingKioskAllowHoldDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Lockdown Mode'**
  String get settingKioskAllowLockdownTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Lock the screen until the exit gesture or a remote unlock.'**
  String get settingKioskAllowLockdownDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Theme picker'**
  String get settingKioskAllowThemeTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Switch between the light and dark themes.'**
  String get settingKioskAllowThemeDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Apps'**
  String get settingKioskAllowAppsTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Open the app launcher. With Disable home button on, launching an app unpins the kiosk until it returns.'**
  String get settingKioskAllowAppsDescription;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Allowed Actions'**
  String get kioskAllowedActions;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Which quick actions the kiosk menu offers'**
  String get kioskAllowedHelp;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Enable kiosk mode'**
  String get settingKioskEnabledTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Lock the tablet into Kiosk Satellite. The menu swipe is replaced by the exit gesture, the back button stays inside the kiosk, and the protections below arm.'**
  String get settingKioskEnabledDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Start on boot'**
  String get settingKioskStartOnBootTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Launch Kiosk Satellite when the device powers on. On Android 10+ this needs the display over other apps permission; Android asks on first enable.'**
  String get settingKioskStartOnBootDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Kiosk exit gesture'**
  String get settingKioskExitGestureTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Fast taps anywhere open the menu, after the PIN if one is set. Hold variants need the last tap held down. When disabled, only the remote admin can reach settings.'**
  String get settingKioskExitGestureDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Kiosk mode PIN'**
  String get settingKioskPinTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Asked after the exit gesture before the menu opens. Leave empty for no PIN.'**
  String get settingKioskPinDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Disable status bar'**
  String get settingKioskDisableStatusBarTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Block the status bar pull-down with a shield over the top edge. Needs the display over other apps permission; Android asks on first enable.'**
  String get settingKioskDisableStatusBarDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Disable volume buttons'**
  String get settingKioskDisableVolumeTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Swallow the hardware volume keys.'**
  String get settingKioskDisableVolumeDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Disable power button'**
  String get settingKioskDisablePowerTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Android cannot block the power button, so the screen turns right back on when it is pressed. Turning the screen off remotely still works.'**
  String get settingKioskDisablePowerDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Disable home button'**
  String get settingKioskDisableHomeTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Pin the app with Android screen pinning, which blocks the home and recents buttons. Android asks to confirm the first time.'**
  String get settingKioskDisableHomeDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Disable context menus'**
  String get settingKioskDisableContextMenusTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Suppress long-press menus and text selection inside the web view.'**
  String get settingKioskDisableContextMenusDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Disable pull to refresh'**
  String get settingKioskDisablePullRefreshTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Ignore the pull-to-refresh gesture while kiosk mode is on.'**
  String get settingKioskDisablePullRefreshDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Disable Gestures'**
  String get settingKioskDisableGesturesTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Ignore the gestures from the Gestures page while kiosk mode is on.'**
  String get settingKioskDisableGesturesDescription;

  /// Exit gesture option. Keep the number of taps unchanged.
  ///
  /// In en, this message translates to:
  /// **'5 fast taps'**
  String get kioskGestureTaps5;

  /// Exit gesture option. Keep the number of taps unchanged.
  ///
  /// In en, this message translates to:
  /// **'7 fast taps'**
  String get kioskGestureTaps7;

  /// Exit gesture option. Keep the number of taps unchanged.
  ///
  /// In en, this message translates to:
  /// **'5 fast taps, holding the last'**
  String get kioskGestureTaps5Hold;

  /// Exit gesture option. Keep the number of taps unchanged.
  ///
  /// In en, this message translates to:
  /// **'7 fast taps, holding the last'**
  String get kioskGestureTaps7Hold;

  /// Exit gesture option. Keep the number of taps unchanged.
  ///
  /// In en, this message translates to:
  /// **'Disabled (remote admin only)'**
  String get kioskGestureNone;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Kiosk Satellite can bring itself back in the foreground.'**
  String get kioskForeground;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Without this the kiosk cannot bring itself back and the lockdown shield only covers the app.'**
  String get kioskOverlayMissing;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'The notification shade and recents close on their own while the screen is protected.'**
  String get kioskGuardHeld;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Without this the notification shade and recents stay reachable. Enable Kiosk Satellite under Accessibility.'**
  String get kioskGuardMissing;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Without this the kiosk cannot bring itself back. The grant screen appears on the tablet.'**
  String get kioskOverlayRemote;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Without this the notification shade and recents stay reachable. Enable Kiosk Satellite under Accessibility on the tablet.'**
  String get kioskGuardRemote;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Grant on device'**
  String get kioskGrantDevice;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Open settings on device'**
  String get kioskOpenSettingsDevice;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Album art cache'**
  String get mediaCacheTitle;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Could not read cache size.'**
  String get mediaCacheReadFailed;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Could not clear the cache.'**
  String get mediaCacheClearFailed;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Checking cache size...'**
  String get mediaCacheChecking;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Clearing...'**
  String get mediaCacheClearing;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'{used} used of {limit}. Queue thumbnails are cached automatically.'**
  String mediaCacheUsage(String used, String limit);

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Show the floating player'**
  String get settingSendspinShowPlayerTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'While music plays, show a small now-playing window over the dashboard with artwork, track info and progress. Drag it anywhere; the position is remembered.'**
  String get settingSendspinShowPlayerDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Player size'**
  String get settingSendspinPlayerSizeTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Compact is a small, unobtrusive now-playing window. Large adds previous, play/pause and next buttons sized for touch, controlling the whole playback group.'**
  String get settingSendspinPlayerSizeDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Hide the paused player after'**
  String get settingSendspinPausedHideMinutesTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'How long a paused player stays on screen. It applies to both the floating player and the Now Playing view.'**
  String get settingSendspinPausedHideMinutesDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Keep playing when dismissed'**
  String get settingSendspinDismissKeepsPlayingTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Flinging the floating player away hides it without stopping the music.'**
  String get settingSendspinDismissKeepsPlayingDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Show in the kiosk menu'**
  String get settingSendspinPlayerShortcutTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Add an entry in the kiosk menu that shows or hides the floating player. WARNING: If nothing is playing or there is no queue for this player, it won\'t show up.'**
  String get settingSendspinPlayerShortcutDescription;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Floating Player'**
  String get mediaFloatingPage;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'The small card over the dashboard'**
  String get mediaFloatingHint;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get mediaCompact;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Large with controls'**
  String get mediaLargeControls;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Player source'**
  String get settingSendspinPlayerSourceTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'What the floating player and Now Playing show and control: this device or a player elsewhere.'**
  String get settingSendspinPlayerSourceDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get settingSendspinPlayerTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'The player of that source to show and control.'**
  String get settingSendspinPlayerDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Duck volume during voice interactions'**
  String get settingSendspinDuckPercentTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Music drops to this share of its volume during voice interactions and intercom calls, then comes back.'**
  String get settingSendspinDuckPercentDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Volume buttons control the player'**
  String get settingSendspinVolumeKeysTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'This device\'s volume buttons change the followed player\'s volume instead of its own. Only while the Now Playing view is on screen, or whenever the player is playing.'**
  String get settingSendspinVolumeKeysDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Volume button step'**
  String get settingSendspinVolumeKeyStepTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'How far one press of a volume button moves the player.'**
  String get settingSendspinVolumeKeyStepDescription;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'The floating player and Now Playing show only while the picked player has a track playing or a queue loaded. With nothing playing or queued, neither appears.'**
  String get mediaIntro;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get mediaThisDevice;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get mediaOff;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'While Now Playing is shown'**
  String get mediaKeysNowPlaying;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'While the player is playing'**
  String get mediaKeysPlaying;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'another player'**
  String get mediaAnotherPlayer;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'This device\'s own Sendspin player stays offline while {player} is controlled.'**
  String mediaLocalOffline(String player);

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Enable lyrics'**
  String get settingSendspinLyricsEnabledTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Synchronized lyrics on the Now Playing view, for every player source.'**
  String get settingSendspinLyricsEnabledDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Lyrics source'**
  String get settingSendspinLyricsSourceTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Where the lyrics come from. Music Assistant needs the server address and token on its page.'**
  String get settingSendspinLyricsSourceDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Fallback to Music Assistant'**
  String get settingSendspinLyricsFallbackTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'If LRCLIB is unreachable, Music Assistant is asked instead. Needs the Music Assistant connection.'**
  String get settingSendspinLyricsFallbackDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Lyrics timing'**
  String get settingSendspinLyricsOffsetTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Shift the lyrics against the music. Positive shows each line earlier, negative later. Worth a nudge on tracks that read consistently off.'**
  String get settingSendspinLyricsOffsetDescription;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get mediaLyricsPage;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Synchronized lyrics, their source and timing'**
  String get mediaLyricsHint;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get settingSendspinMaUrlTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'The Music Assistant server\'s address, as its web interface shows it. Usually https and port 8095.'**
  String get settingSendspinMaUrlDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Auth token'**
  String get settingSendspinMaTokenTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'A long-lived token from Music Assistant (Settings, then Users). Read access is enough for lyrics; the kiosk menu shortcut opens the web interface as whoever the token belongs to.'**
  String get settingSendspinMaTokenDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Show in the kiosk menu'**
  String get settingSendspinMaShortcutTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Add a Music Assistant entry to the kiosk menu, opening the server\'s web interface over the dashboard. Needs the server address above.'**
  String get settingSendspinMaShortcutDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Open directly to Now Playing'**
  String get settingSendspinMaOpenFullscreenTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Open Music Assistant\'s full-screen player from the kiosk menu or the Open Music Assistant gesture.'**
  String get settingSendspinMaOpenFullscreenDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Close after inactivity'**
  String get settingSendspinMaAutoCloseTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Return to the dashboard when nobody has touched the Music Assistant page for this long. Zero leaves it open until it is closed.'**
  String get settingSendspinMaAutoCloseDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Hide the close button'**
  String get settingSendspinMaHideCloseTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'The floating close button can sit on top of Music Assistant\'s own controls, like the Now Playing menu. Without it, dismiss with the back button or by using the kiosk\'s drawer menu.'**
  String get settingSendspinMaHideCloseDescription;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Server, token, kiosk menu shortcut'**
  String get mediaMaHint;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Kiosk menu'**
  String get mediaKioskMenu;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Validate connection'**
  String get mediaValidateConnection;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Validate'**
  String get mediaValidate;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get mediaChecking;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get mediaConnected;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Connected to Music Assistant {version}'**
  String mediaConnectedVersion(String version);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Check the address and token before turning on the shortcut or lyrics.'**
  String get mediaValidateHint;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'The device did not answer.'**
  String get mediaDeviceNoAnswer;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Validation failed.'**
  String get mediaValidationFailed;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'No server address set.'**
  String get mediaNoAddress;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'No auth token set.'**
  String get mediaNoToken;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Music Assistant did not answer in time.'**
  String get mediaTimeout;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Could not reach {host}: {error}'**
  String mediaUnreachable(String host, String error);

  /// Connection failure.
  ///
  /// In en, this message translates to:
  /// **'the server closed the connection'**
  String get mediaServerClosed;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Show media controls'**
  String get settingSendspinFullscreenControlsTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Previous, play/pause and next buttons and a progress bar on the Now Playing view. With controls on, a close button dismisses it instead of a tap anywhere.'**
  String get settingSendspinFullscreenControlsDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Text scale'**
  String get settingSendspinFullscreenTextScaleTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Size of the track title, artist, album, lyrics and queue text. Applies in both layouts and alongside the screensaver. Artwork adjusts to leave room for the text.'**
  String get settingSendspinFullscreenTextScaleDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Button scale'**
  String get settingSendspinFullscreenButtonScaleTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Size of the playback buttons and progress bar, independent of text size. Applies in both layouts and alongside the screensaver. Controls fit the space available in the player.'**
  String get settingSendspinFullscreenButtonScaleDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Horizontal mode'**
  String get settingSendspinFullscreenHorizontalTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Split artwork and controls into equal left and right halves. With lyrics or the queue open, track details move below the artwork. Ignored while Now Playing is shown alongside a screensaver.'**
  String get settingSendspinFullscreenHorizontalDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Double tap to dismiss'**
  String get settingSendspinFullscreenDoubleTapTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'A double tap anywhere on the Now Playing view dismisses it. The close button won\'t be shown. Ignored while Now Playing is shown alongside a screensaver.'**
  String get settingSendspinFullscreenDoubleTapDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Launch Now Playing when music starts playing'**
  String get settingSendspinFullscreenOnPlayTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Open the Now Playing view as soon as playback starts instead of waiting for the screensaver timeout.'**
  String get settingSendspinFullscreenOnPlayDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Dismiss \"Now Playing\" on motion'**
  String get settingSendspinFullscreenMotionTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Let motion dismiss Now Playing like a regular screensaver. Off, only touch dismisses it, so a walk-past does not interrupt the music display. Ignored while Now Playing is shown alongside a screensaver.'**
  String get settingSendspinFullscreenMotionDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Show in the kiosk menu'**
  String get settingSendspinFullscreenShortcutTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Add an entry in the kiosk menu that shows the Now Playing view. WARNING: If nothing is playing or there is no queue for this player, it won\'t show up.'**
  String get settingSendspinFullscreenShortcutDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Show speaker selection pill'**
  String get settingSendspinSpeakerPillTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Shows speaker selection for 5 seconds after screen interaction. Add or remove speakers from the current group.'**
  String get settingSendspinSpeakerPillDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Show album art in the queue'**
  String get settingSendspinQueueArtTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'A cover on every row of the queue panel.'**
  String get settingSendspinQueueArtDescription;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Full-screen view while music plays'**
  String get mediaNowPlayingHint;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'User Interface'**
  String get mediaInterfaceHeading;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'\"Now Playing\" instead of the screensaver'**
  String get settingSendspinFullscreenTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'While music plays, the screensaver becomes a full-screen Now Playing view with album art. With nothing playing, the regular screensaver runs.'**
  String get settingSendspinFullscreenDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Show alongside screensaver'**
  String get settingSendspinFullscreenSplitTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Keep the screensaver visible beside Now Playing. Portrait screens stack the screensaver above the player. Small screens keep the full-screen player.'**
  String get settingSendspinFullscreenSplitDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Fill the screen'**
  String get settingSendspinFullscreenPhotoFillTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Override photo filling while the screensaver shares the display with Now Playing. Default uses each screensaver\'s own setting. Off keeps the whole photo between black bars. Smart enlarges photos shaped close to the screen, framing the rest over a blurred backdrop. Always enlarges every photo, cutting off what does not fit.'**
  String get settingSendspinFullscreenPhotoFillDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Override screensaver brightness'**
  String get settingSendspinFullscreenOverrideBrightnessTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Use normal screen brightness instead of screensaver brightness while Now Playing is shown alongside a screensaver. This also overrides scheduled screensaver brightness.'**
  String get settingSendspinFullscreenOverrideBrightnessDescription;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Screensaver'**
  String get mediaScreensaverHeading;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get mediaDefaultFill;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get mediaFillOff;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Smart'**
  String get mediaFillSmart;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Always'**
  String get mediaFillAlways;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Pick a player'**
  String get mediaPickPlayer;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Music Assistant player'**
  String get mediaMaPlayer;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant media player'**
  String get mediaHaPlayer;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Sonos room'**
  String get mediaSonosRoom;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Search players'**
  String get mediaSearchPlayers;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get mediaOffline;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'{name} (offline)'**
  String mediaOfflineName(String name);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Set up Music Assistant to list its players.'**
  String get mediaSetUpMa;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Connect Home Assistant to list its media players.'**
  String get mediaSetUpHa;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'No Sonos speakers known yet. Find or add one on the Sonos page.'**
  String get mediaSetUpSonos;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant did not answer: {error}'**
  String mediaHaFailed(String error);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Could not save the player.'**
  String get mediaSaveFailed;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Could not select player'**
  String get mediaSelectFailed;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Enable Sendspin player'**
  String get settingSendspinEnabledTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Turn this device into a synchronized Sendspin player. It appears in Music Assistant under the device name, in sync with every other Sendspin speaker.'**
  String get settingSendspinEnabledDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get settingSendspinServerTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Sendspin server address, for example 192.168.1.10:8927. Leave empty to find the server on the network automatically.'**
  String get settingSendspinServerDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Preferred audio codec'**
  String get settingSendspinCodecTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'FLAC is lossless and ideal on WiFi or ethernet. The server makes the final choice from what this device offers.'**
  String get settingSendspinCodecDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Audio sync offset (ms)'**
  String get settingSendspinSyncOffsetTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Negative plays this device earlier, for speakers that lag behind the group (Bluetooth). Tune by ear; applies live.'**
  String get settingSendspinSyncOffsetDescription;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Sendspin Player'**
  String get mediaSendspinPage;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Make this device a synchronized Music Assistant player'**
  String get mediaSendspinHint;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'FLAC (lossless)'**
  String get mediaFlac;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Opus (efficient)'**
  String get mediaOpus;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'PCM (uncompressed)'**
  String get mediaPcm;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Adjust the group volume'**
  String get settingSendspinSonosGroupVolumeTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'While the followed room plays in a group, the volume slider sets the whole group\'s volume. Off, only that room\'s.'**
  String get settingSendspinSonosGroupVolumeDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Show TV and line-in'**
  String get settingSendspinSonosInputsTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Show activity in the media player when eARC or line-in inputs are active.'**
  String get settingSendspinSonosInputsDescription;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Speakers on the network, add one by address'**
  String get mediaSonosHint;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Speakers'**
  String get mediaSonosSpeakers;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'No Sonos found'**
  String get mediaSonosNoneFound;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Nothing answered on this network. Add one by address.'**
  String get mediaSonosDiscoveryEmpty;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Add a Sonos by address'**
  String get mediaSonosAddTitle;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Looking…'**
  String get mediaSonosLooking;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'No speakers yet'**
  String get mediaSonosEmpty;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Search this network or add a speaker by its address.'**
  String get mediaSonosEmptyHelp;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Forget'**
  String get mediaSonosForget;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Search the network'**
  String get mediaSonosSearchTitle;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Finds Sonos speakers on this network. The speakers must be on the same VLAN as this device to be auto discovered.'**
  String get mediaSonosSearchHelp;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get mediaSonosSearch;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get mediaSonosSearching;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Add by address'**
  String get mediaSonosAddAddress;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'The speaker\'s address on the network. The whole household is added from it.'**
  String get mediaSonosAddressHelp;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Pick a room under Player source, Sonos.'**
  String get mediaSonosPickRoom;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Sonos added'**
  String get mediaSonosAdded;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'The speaker listed no rooms.'**
  String get mediaSonosNoRooms;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'no address'**
  String get mediaSonosNoAddress;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'No Sonos answered at {host}.'**
  String mediaSonosUnreachable(String host);

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

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Adaptive brightness'**
  String get settingAdaptiveBrightnessTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Dim the screen as the room gets darker, using the ambient light sensor.'**
  String get settingAdaptiveBrightnessDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Minimum brightness'**
  String get settingAdaptiveMinBrightnessTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Screen brightness in a dark room.'**
  String get settingAdaptiveMinBrightnessDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Maximum brightness'**
  String get settingAdaptiveMaxBrightnessTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Screen brightness in a bright room.'**
  String get settingAdaptiveMaxBrightnessDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Dark room (lx)'**
  String get settingAdaptiveDarkLuxTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Light level at or below which the screen sits at Minimum brightness.'**
  String get settingAdaptiveDarkLuxDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Bright room (lx)'**
  String get settingAdaptiveBrightLuxTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Light level at or above which the screen sits at Maximum brightness.'**
  String get settingAdaptiveBrightLuxDescription;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'Follow the room light with the ambient light sensor'**
  String get screenAudioAdaptiveHint;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'Level in a bright room. Adaptive brightness dims it from there.'**
  String get screenAudioAdaptiveNote;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'Adaptive brightness is on.'**
  String get screenAudioAdaptiveOwns;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'No ambient light sensor on this device.'**
  String get screenAudioNoSensor;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'Ambient light'**
  String get screenAudioAmbientLight;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'What the ambient light sensor reads right now.'**
  String get screenAudioAmbientHelp;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'No reading yet'**
  String get screenAudioNoReading;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'{lux} lx'**
  String screenAudioLux(String lux);

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'{lux} lx (last known)'**
  String screenAudioLuxLast(String lux);

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'Sets Maximum brightness: adaptive brightness is on.'**
  String get screenAudioSetsMaximum;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'Sets Default brightness.'**
  String get screenAudioSetsDefault;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Microphone'**
  String get settingAudioMicDeviceTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'The microphone wake word detection and voice turns capture from.'**
  String get settingAudioMicDeviceDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Speaker'**
  String get settingAudioSpeakerDeviceTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Output for Voice Satellite sounds; media playback follows the system route. Echo cancellation only works with the microphone and speaker on the same device.'**
  String get settingAudioSpeakerDeviceDescription;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'Audio Devices'**
  String get screenAudioDevices;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'Selected device'**
  String get screenAudioSelectedDevice;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'{name} (not connected)'**
  String screenAudioDisconnected(String name);

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Capture mode'**
  String get settingMicAudioSourceTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Voice communication is the only mode with echo cancellation, so leave it unless the microphone reads far quieter here than in a recorder app.'**
  String get settingMicAudioSourceDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Echo cancellation'**
  String get settingMicEchoCancellationTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Keeps the kiosk\'s own speaker out of the microphone so the stop word works during playback. Turn it off only if the microphone reads far quieter here than in a recorder app.'**
  String get settingMicEchoCancellationDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Microphone channel'**
  String get settingMicChannelTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Multichannel microphones often reserve one channel for speech recognition; picking it can improve detection.'**
  String get settingMicChannelDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Automatic gain control'**
  String get settingMicAgcTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Let Android level the microphone instead of a fixed gain. It also lifts room noise, and on some devices it does nothing at all.'**
  String get settingMicAgcDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Noise suppression'**
  String get settingMicNoiseSuppressionTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Reduce microphone background noise using Android processing. It may help or hurt wake word detection depending on the device.'**
  String get settingMicNoiseSuppressionDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Microphone gain'**
  String get settingMicGainDbTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Boost or cut the microphone before anything hears it. Aim for a level near 0.05 in the wake word tester; too much gain distorts speech and hurts detection.'**
  String get settingMicGainDbDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Capture format'**
  String get settingMicCaptureFormatTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Pick 48 kHz stereo when the microphone works in other apps but not here: some sound cards record in that format only and the app converts it itself.'**
  String get settingMicCaptureFormatDescription;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'Microphone settings'**
  String get screenAudioMicrophoneSettings;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'Capture mode, channel, gain, live level'**
  String get screenAudioMicrophoneHint;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'Adjust capture for your microphone and room. Test wake words and voice interactions after changing these settings.'**
  String get screenAudioMicrophoneNote;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'Voice communication (default)'**
  String get screenAudioVoiceCommunication;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'Voice recognition'**
  String get screenAudioVoiceRecognition;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'Raw microphone'**
  String get screenAudioRawMicrophone;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'Automatic (default)'**
  String get screenAudioAutomaticDefault;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'48 kHz stereo'**
  String get screenAudioStereo;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'Downmix (default)'**
  String get screenAudioDownmix;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'Channel {channel}'**
  String screenAudioChannel(String channel);

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'Channel {channel} (not on this microphone)'**
  String screenAudioChannelMissing(String channel);

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'Microphone level'**
  String get screenAudioMicrophoneLevel;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'Speak from where you use the device; adjust the gain until normal speech tops out around the end of the green.'**
  String get screenAudioMicrophoneLevelHelp;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Display cutout'**
  String get settingBrowserCutoutModeTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'What to do with the screen area around a camera cutout or punch hole. Pick Avoid the cutout if the camera sits on top of buttons at the top of the dashboard.'**
  String get settingBrowserCutoutModeDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Screen orientation'**
  String get settingScreenOrientationTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Force the screen into one orientation. Use this on a device without a rotation sensor, or one mounted a way the sensor gets wrong.'**
  String get settingScreenOrientationDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Keep screen on'**
  String get settingKeepScreenOnTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Prevent the OS from turning the screen off.'**
  String get settingKeepScreenOnDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Set brightness on launch'**
  String get settingSetBrightnessOnLaunchTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Apply the default brightness whenever the app starts.'**
  String get settingSetBrightnessOnLaunchDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Default brightness'**
  String get settingDefaultBrightnessTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Screen brightness applied when the app starts. Moving the slider applies it immediately.'**
  String get settingDefaultBrightnessDescription;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'Screen'**
  String get screenAudioScreen;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'Use the cutout area'**
  String get screenAudioCutoutAlways;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'Short edges only'**
  String get screenAudioCutoutShort;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get screenAudioCutoutDefault;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'Avoid the cutout'**
  String get screenAudioCutoutNever;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get screenAudioAutomatic;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'Landscape'**
  String get screenAudioLandscape;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'Reverse landscape'**
  String get screenAudioReverseLandscape;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'Portrait'**
  String get screenAudioPortrait;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'Reverse portrait'**
  String get screenAudioReversePortrait;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'Permission'**
  String get screenAudioPermission;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'Brightness is using a fallback'**
  String get screenAudioBrightnessFallback;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'Without the \"Modify system settings\" permission, brightness changes only dim this app instead of setting the panel\'s actual brightness.'**
  String get screenAudioBrightnessPermission;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'Without the \"Modify system settings\" permission, brightness changes only dim the app instead of setting the panel\'s actual brightness.'**
  String get screenAudioBrightnessPermissionRemote;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'Always-on display'**
  String get screenAudioAlwaysOn;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'This device keeps a dim clock on'**
  String get screenAudioAlwaysOnClock;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'Turning the screen off puts the device to sleep, but the always-on display lights the lock screen back up and no app can stop it. Turn off \"Always show time and info\" in Android settings under Display, near the lock screen options; some ROMs call it always-on display. The Home Assistant screen entity stays unavailable until you do.'**
  String get screenAudioAlwaysOnHelp;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Media volume'**
  String get settingMediaVolumeTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Music and video play at this share of the master volume. The Sendspin player volume in Music Assistant moves this slider.'**
  String get settingMediaVolumeDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Assistant volume'**
  String get settingAssistantVolumeTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Voice responses and chimes play at this share of the master volume, independent of the media volume.'**
  String get settingAssistantVolumeDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Full assistant volume range'**
  String get settingAssistantFullVolumeRangeTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Initialize the built-in speaker\'s call volume at 100% when assistant audio first starts. Master and assistant volume still apply. Other apps share this call volume, which is not restored afterward.'**
  String get settingAssistantFullVolumeRangeDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Intercom volume'**
  String get settingIntercomVolumeTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'The other kiosk\'s voice and announcements play at this share of the master volume.'**
  String get settingIntercomVolumeDescription;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'Audio Volume'**
  String get screenAudioVolume;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'Master volume'**
  String get screenAudioMasterVolume;

  /// Heading, choice, status or guidance shown in this group.
  ///
  /// In en, this message translates to:
  /// **'The device volume. Media, intercom and assistant volumes scale under it.'**
  String get screenAudioMasterHelp;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Hide all extras'**
  String get settingScreensaverBlackHideExtrasTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Keeps the screen fully black: no small clock, At a Glance entities, or other overlays.'**
  String get settingScreensaverBlackHideExtrasDescription;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Black screensaver'**
  String get screensaverBlackSection;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get settingScreensaverClockStyleTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'How the clock is drawn.'**
  String get settingScreensaverClockStyleDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Font Family'**
  String get settingScreensaverClockFontTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'The typeface the clock is drawn in.'**
  String get settingScreensaverClockFontDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Font weight'**
  String get settingScreensaverClockFontWeightTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'How heavy the clock\'s digits are drawn. Default is each face\'s own weight.'**
  String get settingScreensaverClockFontWeightDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'24-hour clock'**
  String get settingScreensaverClock24hTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Show a 24-hour time instead of AM/PM.'**
  String get settingScreensaverClock24hDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Show seconds'**
  String get settingScreensaverClockSecondsTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Include seconds in the clock.'**
  String get settingScreensaverClockSecondsDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Show date'**
  String get settingScreensaverClockDateTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Show the weekday and date under the clock.'**
  String get settingScreensaverClockDateDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Clock size'**
  String get settingScreensaverClockScaleTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Scale the clock from 50 to 300 percent for this screen.'**
  String get settingScreensaverClockScaleDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Clock color'**
  String get settingScreensaverClockColorTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'The color of the clock text.'**
  String get settingScreensaverClockColorDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Background color'**
  String get settingScreensaverClockBgColorTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'The color behind the clock.'**
  String get settingScreensaverClockBgColorDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Background photo'**
  String get settingScreensaverClockBackgroundTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Show a photo behind the clock instead of the solid color. A path to an image on the device, or an image URL the device fetches.'**
  String get settingScreensaverClockBackgroundDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Refresh URL background'**
  String get settingScreensaverClockBackgroundRefreshTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Minutes between fetches of a URL background. 0 fetches it only when the setting is written.'**
  String get settingScreensaverClockBackgroundRefreshDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Digit color'**
  String get settingScreensaverFlipDigitColorTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'The color of the flip digits.'**
  String get settingScreensaverFlipDigitColorDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Card color'**
  String get settingScreensaverFlipBgColorTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'The color of the cards.'**
  String get settingScreensaverFlipBgColorDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Background color'**
  String get settingScreensaverFlipBackdropColorTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'The color behind the cards.'**
  String get settingScreensaverFlipBackdropColorDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Digit color'**
  String get settingScreensaverRollerDigitColorTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'The color of the rolling digits.'**
  String get settingScreensaverRollerDigitColorDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Background color'**
  String get settingScreensaverRollerBgColorTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'The color behind the digits.'**
  String get settingScreensaverRollerBgColorDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Night mode'**
  String get settingScreensaverClockNightTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Recolor the clock while the room is dark.'**
  String get settingScreensaverClockNightDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Light level'**
  String get settingScreensaverClockNightLuxTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'At or below this light level the clock takes the night color.'**
  String get settingScreensaverClockNightLuxDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Night color'**
  String get settingScreensaverClockNightColorTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'The color of the clock and the widgets in the dark.'**
  String get settingScreensaverClockNightColorDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Night background'**
  String get settingScreensaverClockNightBgColorTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'The color behind the clock in the dark.'**
  String get settingScreensaverClockNightBgColorDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Hide background photo'**
  String get settingScreensaverClockNightHideBackgroundTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Use the night background color instead of the photo while Night mode is active.'**
  String get settingScreensaverClockNightHideBackgroundDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Night card color'**
  String get settingScreensaverClockNightCardColorTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'The color of the flip cards in the dark.'**
  String get settingScreensaverClockNightCardColorDescription;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Clock screensaver'**
  String get screensaverClockSection;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Style, font, size, colors, night mode, background photo'**
  String get screensaverClockHint;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Digital Clock'**
  String get screensaverStyleDigital;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Flip Clock'**
  String get screensaverStyleFlip;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Roller Clock'**
  String get screensaverStyleRoller;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get screensaverFontDefault;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get screensaverFontLight;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Regular'**
  String get screensaverFontRegular;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get screensaverFontMedium;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get screensaverFontBold;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get screensaverFontBlack;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'No photo selected'**
  String get screensaverNoPhoto;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Path to an image on the device, or an image URL'**
  String get screensaverBackgroundHint;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Enter a full image URL'**
  String get screensaverImageUrlError;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Enter whole minutes from 0 to 1440'**
  String get screensaverRefreshError;

  /// Maximum length validation error.
  ///
  /// In en, this message translates to:
  /// **'Use at most {count} characters'**
  String screensaverMaxCharacters(String count);

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Entity'**
  String get screensaverOverlayEntity;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get screensaverOverlayNotSet;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get screensaverOverlayName;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use the Home Assistant name.'**
  String get screensaverOverlayNameHelp;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Displayed value'**
  String get screensaverOverlayValue;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get screensaverOverlayState;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Pick an entity.'**
  String get screensaverOverlayEntityRequired;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Name or entity id'**
  String get screensaverOverlaySearchHint;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Search by name or entity id'**
  String get screensaverOverlaySearchHintRemote;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Type to search entities.'**
  String get screensaverOverlaySearchEmpty;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Nothing matched.'**
  String get screensaverOverlayNoMatches;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get screensaverOverlaySearching;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Could not reach Home Assistant'**
  String get screensaverOverlayUnreachable;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'The device did not answer.'**
  String get screensaverOverlayNoAnswer;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Could not search entities: {error}'**
  String screensaverOverlaySearchError(String error);

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Dismiss on face'**
  String get settingScreensaverDismissOnFaceTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Wake the screen when someone looks at the kiosk, not on movement alone. The camera runs only during the screensaver. WARNING: Needs a lit face; in the dark, schedule motion detection instead.'**
  String get settingScreensaverDismissOnFaceDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Only when screen is off'**
  String get settingScreensaverDismissOnFaceScreenOffOnlyTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Keep the screensaver visible when a face is detected while the screen is on. Once the screen turns off, detection wakes the dashboard. Touch still dismisses the screensaver.'**
  String get settingScreensaverDismissOnFaceScreenOffOnlyDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Postpone screensaver on face'**
  String get settingScreensaverPostponeOnFaceTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Delay activating the screensaver while someone is looking at the kiosk. WARNING: Keeps the camera running permanently, with face detection and its CPU cost on top.'**
  String get settingScreensaverPostponeOnFaceDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Face sensitivity'**
  String get settingFaceSensitivityTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Higher wakes on smaller, more distant faces. 1 needs a face close to the screen; 100 reacts to any face the camera can make out.'**
  String get settingFaceSensitivityDescription;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Face Detection'**
  String get screensaverDetectionFacePage;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Dismiss the screensaver when someone looks at it'**
  String get screensaverDetectionFaceHint;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Dismiss on motion is on and takes precedence, so face detection stays idle until it is turned off.'**
  String get screensaverDetectionMotionPrecedence;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Frame rate, camera pick and startup delay are tuned in the Camera settings.'**
  String get screensaverDetectionFaceTuning;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Not available on this Android version.'**
  String get screensaverDetectionAndroidUnsupported;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Not available on x86 devices.'**
  String get screensaverDetectionX86Unsupported;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Show camera preview'**
  String get settingFacePreviewTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Show a small round live view of the camera in a corner of the screen for a few seconds when a face wakes the kiosk.'**
  String get settingFacePreviewDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Preview duration'**
  String get settingFacePreviewSecondsTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'How long the preview stays on screen.'**
  String get settingFacePreviewSecondsDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Preview scaling'**
  String get settingFacePreviewScaleTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Scale the preview to better fit your screen size.'**
  String get settingFacePreviewScaleDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Preview position'**
  String get settingFacePreviewPositionTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Which corner the preview sits in.'**
  String get settingFacePreviewPositionDescription;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Camera Preview'**
  String get screensaverDetectionPreviewSection;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Screensaver'**
  String get settingScreensaverEnabledTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Dim or blank the screen after a period of inactivity.'**
  String get settingScreensaverEnabledDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Idle timeout (seconds)'**
  String get settingScreensaverTimeoutSecondsTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Inactivity period before the screensaver starts.'**
  String get settingScreensaverTimeoutSecondsDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Screensaver mode'**
  String get settingScreensaverModeTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'What the screensaver shows after the idle timeout. Dim only lowers the backlight and leaves the dashboard on screen.'**
  String get settingScreensaverModeDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Pixel shift'**
  String get settingScreensaverPixelShiftTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Nudge the image every minute to protect OLED panels. Not for the black screensaver, whose pixels are already off.'**
  String get settingScreensaverPixelShiftDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Show in the kiosk menu'**
  String get settingScreensaverMenuTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Add a Start Screensaver entry to the kiosk menu.'**
  String get settingScreensaverMenuDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Dim level'**
  String get settingScreensaverDimLevelTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Screen brightness while the screensaver is dimming.'**
  String get settingScreensaverDimLevelDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Screensaver brightness'**
  String get settingScreensaverBrightnessEnabledTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Use a separate brightness while the screensaver is showing.'**
  String get settingScreensaverBrightnessEnabledDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Brightness level'**
  String get settingScreensaverBrightnessLevelTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Applies to every mode except Dim and Black.'**
  String get settingScreensaverBrightnessLevelDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Brighten for notifications'**
  String get settingScreensaverNotificationBrightnessTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Lift the screensaver dimming while a notification is on screen.'**
  String get settingScreensaverNotificationBrightnessDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Turn screen off after'**
  String get settingScreensaverScreenOffMinutesTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Powers down the display panel once the screensaver has run for the set duration. Set to 0 to keep the screen on indefinitely. Requires Device Administrator permission.'**
  String get settingScreensaverScreenOffMinutesDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Wake to screensaver'**
  String get settingScreensaverScreenOffWakeToScreensaverTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Motion, face, proximity or person detection after the screen has turned off brings the screensaver back instead of the dashboard, with a fresh Turn screen off after countdown. Touch still opens the dashboard.'**
  String get settingScreensaverScreenOffWakeToScreensaverDescription;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Dim'**
  String get screensaverModeDim;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get screensaverModeBlack;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Clock'**
  String get screensaverModeClock;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant Media'**
  String get screensaverModeMedia;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Local Media'**
  String get screensaverModeLocal;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Photo Gallery'**
  String get screensaverModeGallery;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Immich Media'**
  String get screensaverModeImmich;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get screensaverModeWebsite;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Camera Streams'**
  String get screensaverModeCamera;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Dim screensaver'**
  String get screensaverDimSection;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'WARNING: Please Read!'**
  String get screensaverWarningTitle;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Turn screen off anyway'**
  String get screensaverScreenOffProceed;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Not granted, so the screen cannot turn off.'**
  String get screensaverAdminMissing;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Device admin permission missing'**
  String get screensaverAdminMissingRemote;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Without it the screen cannot be turned off. The grant dialog appears on the tablet screen.'**
  String get screensaverAdminMissingRemoteHelp;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'WARNING: Dim keeps the dashboard visible, so the \"Pause dashboard during screensaver\" optimization will not be applied and the dashboard keeps using CPU, GPU and battery.'**
  String get screensaverDimWarning;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Unavailable plugin screensaver'**
  String get screensaverUnavailablePlugin;

  /// Warning before enabling physical screen power-off.
  ///
  /// In en, this message translates to:
  /// **'Once the display truly powers off, the tablet\'s own power management takes over, and many Android models misbehave in that state: Wi-Fi naps or drops, the Home Assistant entities go unavailable, the camera can be revoked, and some models kill background apps outright. What happens depends on the manufacturer.\n\nThe reliable alternative is the Black screensaver with this setting left at 0: the panel looks just as dark, and the app keeps full control.'**
  String get screensaverScreenOffWarning;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Row scaling'**
  String get settingScreensaverGlanceScaleTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Scale the row to better fit your screen size.'**
  String get settingScreensaverGlanceScaleDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Font family'**
  String get settingScreensaverGlanceFontTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'The typeface the row is drawn in.'**
  String get settingScreensaverGlanceFontDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Font weight'**
  String get settingScreensaverGlanceFontWeightTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'How heavy the row\'s text is drawn. Default is each line\'s own weight: regular names, semibold values.'**
  String get settingScreensaverGlanceFontWeightDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Hide names'**
  String get settingScreensaverGlanceHideNamesTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Show only the icon and the value, with the value drawn larger.'**
  String get settingScreensaverGlanceHideNamesDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Monochromatic icons'**
  String get settingScreensaverGlanceBwIconsTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Keep every icon in the neutral grey instead of its state color.'**
  String get settingScreensaverGlanceBwIconsDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Floating text style'**
  String get settingScreensaverGlanceTextOnlyTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Show the entities as floating text instead of chips.'**
  String get settingScreensaverGlanceTextOnlyDescription;

  /// Settings group heading.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get screensaverOverlayAppearance;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'At a glance'**
  String get settingScreensaverGlanceEnabledTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Show a row of Home Assistant entity states on the screensaver.'**
  String get settingScreensaverGlanceEnabledDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Entities'**
  String get settingScreensaverGlanceEntitiesTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Up to four entities to show, each with an optional custom name.'**
  String get settingScreensaverGlanceEntitiesDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Show on Now Playing'**
  String get settingScreensaverGlanceNowPlayingTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Show the row on the full-screen Now Playing view. It stays hidden while lyrics are showing.'**
  String get settingScreensaverGlanceNowPlayingDescription;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Showing'**
  String get screensaverOverlayShowing;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Showing (drag to reorder)'**
  String get screensaverOverlayReorder;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'That is the most the row can show. Remove one to add another.'**
  String get screensaverOverlayFull;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'At a glance entities'**
  String get screensaverOverlayPickerTitle;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'None yet. Up to {count} entities.'**
  String screensaverOverlayGlanceEmpty(String count);

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'None yet'**
  String get screensaverOverlayNone;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Up to {count} entities.'**
  String screensaverOverlayLimit(String count);

  /// Subpage navigation title or summary.
  ///
  /// In en, this message translates to:
  /// **'At a Glance'**
  String get screensaverOverlayGlancePage;

  /// Subpage navigation title or summary.
  ///
  /// In en, this message translates to:
  /// **'Entities shown over the screensaver'**
  String get screensaverOverlayGlanceHint;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get settingScreensaverImmichUrlTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'The address of your Immich server, with its port.'**
  String get settingScreensaverImmichUrlDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get settingScreensaverImmichApiKeyTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Created in Immich under Account Settings → API Keys.'**
  String get settingScreensaverImmichApiKeyDescription;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Immich Media screensaver'**
  String get screensaverMediaImmichPage;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Server, media, slideshow, metadata, filters'**
  String get screensaverMediaImmichHint;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Server Connection'**
  String get screensaverMediaServerConnection;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Validation failed. See the app log for the failing call.'**
  String get screensaverMediaValidateFailedLog;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Validation failed.'**
  String get screensaverMediaValidateFailed;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'The device did not answer.'**
  String get screensaverMediaNoAnswer;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Enter the server address first.'**
  String get screensaverMediaAddressFirst;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Enter an API key first.'**
  String get screensaverMediaKeyFirst;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'The server address is not a valid URL.'**
  String get screensaverMediaBadAddress;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'The API key was rejected.'**
  String get screensaverMediaKeyRejected;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'The API key is missing the {scope} permission.'**
  String screensaverMediaScopeMissing(String scope);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'The API key is missing a permission: {error}'**
  String screensaverMediaPermissionMissing(String error);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'The server answered {status}: {error}'**
  String screensaverMediaServerError(String status, String error);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Could not reach {url}.'**
  String screensaverMediaUnreachable(String url);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Could not talk to the server: {error}'**
  String screensaverMediaTalkError(String error);

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get settingScreensaverImmichPeopleTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Show only media with any of these people.'**
  String get settingScreensaverImmichPeopleDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Exclude people'**
  String get settingScreensaverImmichExcludePeopleTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Skip media with any of these people.'**
  String get settingScreensaverImmichExcludePeopleDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get settingScreensaverImmichTagsTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Show only media with any of these tags.'**
  String get settingScreensaverImmichTagsDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Favorites only'**
  String get settingScreensaverImmichFavoritesOnlyTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Show only media marked as favorite.'**
  String get settingScreensaverImmichFavoritesOnlyDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Taken within'**
  String get settingScreensaverImmichTakenWithinTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Only show media taken in this window.'**
  String get settingScreensaverImmichTakenWithinDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get settingScreensaverImmichTakenFromTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Skip media taken before this date.'**
  String get settingScreensaverImmichTakenFromDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get settingScreensaverImmichTakenToTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Skip media taken after this date. The day itself counts.'**
  String get settingScreensaverImmichTakenToDescription;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get screensaverMediaFilters;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Anyone'**
  String get screensaverMediaAnyone;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Anyone.'**
  String get screensaverMediaAnyoneDevice;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'No one'**
  String get screensaverMediaNoOne;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'No one.'**
  String get screensaverMediaNoOneDevice;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get screensaverMediaAny;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Any.'**
  String get screensaverMediaAnyDevice;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'No named people yet. Name them in Immich first.'**
  String get screensaverMediaNoPeople;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'No tags yet. Create them in Immich first.'**
  String get screensaverMediaNoTags;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Could not list the people'**
  String get screensaverMediaPeopleFailed;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Could not list the tags'**
  String get screensaverMediaTagsFailed;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get screensaverMediaHidden;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Any time'**
  String get screensaverMediaAnyTime;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Past month'**
  String get screensaverMediaPastMonth;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Past 3 months'**
  String get screensaverMediaPast3Months;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Past year'**
  String get screensaverMediaPastYear;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Past 2 years'**
  String get screensaverMediaPast2Years;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Past 5 years'**
  String get screensaverMediaPast5Years;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Past 10 years'**
  String get screensaverMediaPast10Years;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Since'**
  String get screensaverMediaSince;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Timeframe'**
  String get screensaverMediaTimeframe;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get screensaverMediaToday;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Use YYYY-MM-DD.'**
  String get screensaverMediaDateFormat;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'That is not a date.'**
  String get screensaverMediaNotDate;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Show metadata'**
  String get settingScreensaverImmichMetadataTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Album, date, camera and location over the media.'**
  String get settingScreensaverImmichMetadataDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Album name'**
  String get settingScreensaverImmichMetadataAlbumTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Show which album the photo comes from.'**
  String get settingScreensaverImmichMetadataAlbumDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Date taken'**
  String get settingScreensaverImmichMetadataDateTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Show when the photo was taken.'**
  String get settingScreensaverImmichMetadataDateDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Camera details'**
  String get settingScreensaverImmichMetadataCameraTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Show focal length, aperture and ISO.'**
  String get settingScreensaverImmichMetadataCameraDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get settingScreensaverImmichMetadataLocationTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Show the place the photo was taken.'**
  String get settingScreensaverImmichMetadataLocationDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Metadata position'**
  String get settingScreensaverImmichMetadataPositionTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Which corner the details sit in.'**
  String get settingScreensaverImmichMetadataPositionDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Text drop shadow'**
  String get settingScreensaverImmichMetadataTextShadowTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Add a drop shadow to metadata text for readability on photos.'**
  String get settingScreensaverImmichMetadataTextShadowDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Text scaling'**
  String get settingScreensaverImmichMetadataScaleTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Scale the photo details to better fit your screen size.'**
  String get settingScreensaverImmichMetadataScaleDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Vignette strength'**
  String get settingScreensaverImmichVignetteStrengthTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Darkness of the shading behind the details, for readability on bright photos. 0 turns it off.'**
  String get settingScreensaverImmichVignetteStrengthDescription;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Metadata'**
  String get screensaverMediaMetadata;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Top left'**
  String get screensaverMediaTopLeft;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Top right'**
  String get screensaverMediaTopRight;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Bottom left'**
  String get screensaverMediaBottomLeft;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Bottom right'**
  String get screensaverMediaBottomRight;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Seconds per image'**
  String get settingScreensaverImmichIntervalTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'How long each image shows before the next. Videos play in full.'**
  String get settingScreensaverImmichIntervalDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get settingScreensaverImmichShuffleTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Cycle the media in random order.'**
  String get settingScreensaverImmichShuffleDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Transition'**
  String get settingScreensaverImmichTransitionTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'How one item hands off to the next.'**
  String get settingScreensaverImmichTransitionDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Fill the screen'**
  String get settingScreensaverImmichFillTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Off keeps the whole photo between black bars. Smart enlarges photos shaped close to the screen, framing the rest over a blurred backdrop. Always enlarges every photo, cutting off what does not fit.'**
  String get settingScreensaverImmichFillDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Pair portrait photos'**
  String get settingScreensaverImmichPairPortraitTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Show two portrait photos side by side so they fill the screen.'**
  String get settingScreensaverImmichPairPortraitDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Tap edges to change slides'**
  String get settingScreensaverImmichEdgeTapsTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'A tap on the left or right fifth of the screen shows the previous or next slide instead of dismissing.'**
  String get settingScreensaverImmichEdgeTapsDescription;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Slideshow'**
  String get screensaverMediaSlideshow;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Media source'**
  String get settingScreensaverImmichAlbumTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'The whole library, or the albums you pick.'**
  String get settingScreensaverImmichAlbumDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Photos only'**
  String get settingScreensaverImmichPhotosOnlyTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Skip videos in the slideshow.'**
  String get settingScreensaverImmichPhotosOnlyDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Cache media locally'**
  String get settingScreensaverImmichCacheTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Keep copies on the device so images load instantly.'**
  String get settingScreensaverImmichCacheDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Cache size (items)'**
  String get settingScreensaverImmichCacheMaxTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'The oldest items are deleted once the cache is full.'**
  String get settingScreensaverImmichCacheMaxDescription;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'All media'**
  String get screensaverMediaAll;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'All media.'**
  String get screensaverMediaAllDevice;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'No albums yet. Create one in Immich first.'**
  String get screensaverMediaNoAlbums;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Could not list the albums'**
  String get screensaverMediaAlbumsFailed;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Could not list them: {error}'**
  String screensaverMediaListError(String error);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'listing failed'**
  String get screensaverMediaListingFailed;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String screensaverMediaItems(String count);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'{count} cached, {size}'**
  String screensaverMediaCached(String count, String size);

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Camera views'**
  String get settingScreensaverCameraViewsTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'The camera views the screensaver shows, in this order.'**
  String get settingScreensaverCameraViewsDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Seconds per camera view'**
  String get settingScreensaverCameraViewSecondsTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'How long each view stays on screen before the next one. With a single view selected nothing rotates.'**
  String get settingScreensaverCameraViewSecondsDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Mute all views'**
  String get settingScreensaverCameraMuteTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Keeps every view silent, even a single camera.'**
  String get settingScreensaverCameraMuteDescription;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Camera Streams screensaver'**
  String get screensaverMediaCameraPage;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Views to show, seconds per view, sound'**
  String get screensaverMediaCameraHint;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'No camera view has cameras yet. Add one under Camera Streams.'**
  String get screensaverMediaNoCameras;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'No camera view has cameras yet'**
  String get screensaverMediaNoCamerasRemote;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Add one under Camera Streams.'**
  String get screensaverMediaAddCameras;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'None yet. Pick the views the screensaver cycles through.'**
  String get screensaverMediaNoViews;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'In the rotation (drag to reorder)'**
  String get screensaverMediaRotation;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get screensaverMediaAvailable;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'{count} camera'**
  String screensaverMediaOneCamera(String count);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'{count} cameras'**
  String screensaverMediaCameras(String count);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Position {index} · {cameras}'**
  String screensaverMediaPosition(String index, String cameras);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get screensaverMediaTransitionNone;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Crossfade'**
  String get screensaverMediaTransitionFade;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Slide'**
  String get screensaverMediaTransitionSlide;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get screensaverMediaTransitionZoom;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Ken Burns'**
  String get screensaverMediaTransitionKenBurns;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get screensaverMediaTransitionRandom;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get screensaverMediaFillOff;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Smart'**
  String get screensaverMediaFillSmart;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Always'**
  String get screensaverMediaFillAlways;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get settingScreensaverGalleryItemsTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'The photos and videos this screensaver cycles. Picked from the gallery on the device; picking again replaces the selection.'**
  String get settingScreensaverGalleryItemsDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Seconds per photo'**
  String get settingScreensaverGalleryIntervalTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'How long each photo shows before the next. Videos play in full.'**
  String get settingScreensaverGalleryIntervalDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get settingScreensaverGalleryShuffleTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Cycle the selection in random order.'**
  String get settingScreensaverGalleryShuffleDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Transition'**
  String get settingScreensaverGalleryTransitionTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'How one photo hands off to the next.'**
  String get settingScreensaverGalleryTransitionDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Fill the screen'**
  String get settingScreensaverGalleryFillTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Off keeps the whole photo between black bars. Smart enlarges photos shaped close to the screen, framing the rest over a blurred backdrop. Always enlarges every photo, cutting off what does not fit.'**
  String get settingScreensaverGalleryFillDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Tap edges to change slides'**
  String get settingScreensaverGalleryEdgeTapsTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'A tap on the left or right fifth of the screen shows the previous or next slide instead of dismissing.'**
  String get settingScreensaverGalleryEdgeTapsDescription;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Photo Gallery screensaver'**
  String get screensaverMediaGalleryPage;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Photos, timing, shuffle, transition'**
  String get screensaverMediaGalleryHint;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Loading photos...'**
  String get screensaverMediaLoadingPhotos;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Copying photo {index} of {total}...'**
  String screensaverMediaCopying(String index, String total);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Could not copy the photos'**
  String get screensaverMediaCopyFailed;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Try a smaller selection.'**
  String get screensaverMediaSmallerSelection;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'No photos selected'**
  String get screensaverMediaNoPhotos;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String screensaverMediaSelected(String count);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'None selected. Pick on the device.'**
  String get screensaverMediaPickOnDevice;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Media source'**
  String get settingScreensaverMediaIdTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'A Home Assistant media item, folder, or camera. Use Browse to pick one.'**
  String get settingScreensaverMediaIdDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Seconds per image'**
  String get settingScreensaverMediaIntervalTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'How long each image shows before the next. Videos play in full.'**
  String get settingScreensaverMediaIntervalDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get settingScreensaverMediaShuffleTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Play a folder in random order.'**
  String get settingScreensaverMediaShuffleDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Include subfolders'**
  String get settingScreensaverMediaRecursiveTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Descend into subfolders when a folder is chosen.'**
  String get settingScreensaverMediaRecursiveDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Transition'**
  String get settingScreensaverMediaTransitionTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'How one item hands off to the next.'**
  String get settingScreensaverMediaTransitionDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Fill the screen'**
  String get settingScreensaverMediaFillTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Off keeps the whole photo between black bars. Smart enlarges photos shaped close to the screen, framing the rest over a blurred backdrop. Always enlarges every photo, cutting off what does not fit.'**
  String get settingScreensaverMediaFillDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Tap edges to change slides'**
  String get settingScreensaverMediaEdgeTapsTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'A tap on the left or right fifth of the screen shows the previous or next slide instead of dismissing.'**
  String get settingScreensaverMediaEdgeTapsDescription;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant Media screensaver'**
  String get screensaverMediaHaPage;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Media source, timing, shuffle, fill'**
  String get screensaverMediaHaHint;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Choose media'**
  String get screensaverMediaChoose;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get screensaverMediaRoot;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Could not reach Home Assistant, or the token is missing.'**
  String get screensaverMediaHaUnavailable;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Nothing here.'**
  String get screensaverMediaEmpty;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Use this folder'**
  String get screensaverMediaUseFolder;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'folder'**
  String get screensaverMediaFolder;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'camera'**
  String get screensaverMediaCamera;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'item'**
  String get screensaverMediaItem;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'browse failed'**
  String get screensaverMediaBrowseFailed;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Could not browse: {error}'**
  String screensaverMediaBrowseError(String error);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get screensaverMediaNotSet;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Local folder'**
  String get settingScreensaverLocalFolderTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Folder on this device whose photos and videos the screensaver cycles through. Picked on the device; the path can also be typed here remotely.'**
  String get settingScreensaverLocalFolderDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Seconds per photo'**
  String get settingScreensaverLocalIntervalTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'How long each photo shows before the next. Videos play in full.'**
  String get settingScreensaverLocalIntervalDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get settingScreensaverLocalShuffleTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Cycle the folder in random order instead of by name.'**
  String get settingScreensaverLocalShuffleDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Include subfolders'**
  String get settingScreensaverLocalRecursiveTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Also cycle photos and videos inside subfolders.'**
  String get settingScreensaverLocalRecursiveDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Transition'**
  String get settingScreensaverLocalTransitionTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'How one photo hands off to the next.'**
  String get settingScreensaverLocalTransitionDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Fill the screen'**
  String get settingScreensaverLocalFillTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Off keeps the whole photo between black bars. Smart enlarges photos shaped close to the screen, framing the rest over a blurred backdrop. Always enlarges every photo, cutting off what does not fit.'**
  String get settingScreensaverLocalFillDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Tap edges to change slides'**
  String get settingScreensaverLocalEdgeTapsTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'A tap on the left or right fifth of the screen shows the previous or next slide instead of dismissing.'**
  String get settingScreensaverLocalEdgeTapsDescription;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Local Media screensaver'**
  String get screensaverMediaLocalPage;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Folder, timing, shuffle, transition'**
  String get screensaverMediaLocalHint;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Dismiss on motion'**
  String get settingScreensaverDismissOnMotionTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Watch the camera while the screensaver is up and wake the screen when someone approaches. The camera runs only during the screensaver.'**
  String get settingScreensaverDismissOnMotionDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Only when screen is off'**
  String get settingScreensaverDismissOnMotionScreenOffOnlyTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Keep the screensaver visible when motion is detected while the screen is on. Once the screen turns off, detection wakes the dashboard. Touch still dismisses the screensaver.'**
  String get settingScreensaverDismissOnMotionScreenOffOnlyDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Postpone screensaver on motion'**
  String get settingScreensaverPostponeOnMotionTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Delay activating the screensaver when motion is detected. WARNING: Keeps the camera running permanently.'**
  String get settingScreensaverPostponeOnMotionDescription;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Motion Detection'**
  String get screensaverDetectionMotionPage;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Dismiss or postpone the screensaver on motion'**
  String get screensaverDetectionMotionHint;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Motion detection is tuned in the Camera settings.'**
  String get screensaverDetectionMotionTuning;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Dismiss on person'**
  String get settingScreensaverDismissOnPersonTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Read the device\'s person sensor while the screensaver is up and wake the screen when someone is in front of it. Needs the Log access grant below.'**
  String get settingScreensaverDismissOnPersonDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Only when screen is off'**
  String get settingScreensaverDismissOnPersonScreenOffOnlyTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Keep the screensaver visible when someone arrives while the screen is on. Once the screen turns off, detection wakes the dashboard. Touch still dismisses the screensaver.'**
  String get settingScreensaverDismissOnPersonScreenOffOnlyDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Postpone screensaver on person'**
  String get settingScreensaverPostponeOnPersonTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Delay activating the screensaver while someone is in front of the device.'**
  String get settingScreensaverPostponeOnPersonDescription;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Person Detection'**
  String get screensaverDetectionPersonPage;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Dismiss or postpone the screensaver on the device\'s person sensor'**
  String get screensaverDetectionPersonHint;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Occupancy'**
  String get screensaverDetectionOccupancy;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Status unavailable.'**
  String get screensaverDetectionStatusUnavailable;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Off.'**
  String get screensaverDetectionOff;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Starting...'**
  String get screensaverDetectionStarting;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the first heartbeat. The sensor reports every 30 seconds while someone is in view.'**
  String get screensaverDetectionWaiting;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Last heartbeat {ago}.'**
  String screensaverDetectionLastHeartbeat(String ago);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'{count}s ago'**
  String screensaverDetectionSecondsAgo(String count);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String screensaverDetectionMinutesAgo(String count);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'{count} h ago'**
  String screensaverDetectionHoursAgo(String count);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Detected'**
  String get screensaverDetectionDetected;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get screensaverDetectionClear;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Required system permissions'**
  String get screensaverDetectionPermissions;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Log access'**
  String get screensaverDetectionLogAccess;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Checking...'**
  String get screensaverDetectionChecking;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'The device\'s person sensor can be read.'**
  String get screensaverDetectionReadable;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Granted. Restart Kiosk Satellite to apply it.'**
  String get screensaverDetectionRestartRequired;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'This permission can only be granted via ADB. The Meta Portal doc has the full command. Restart Kiosk Satellite afterwards.'**
  String get screensaverDetectionGrantHelp;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'This permission can only be granted via ADB. Below is the full command, ready to be copied. Restart Kiosk Satellite afterwards.'**
  String get screensaverDetectionGrantRemoteHelp;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Granted'**
  String get screensaverDetectionGranted;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get screensaverDetectionMissing;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get screensaverDetectionRestart;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Restart on device'**
  String get screensaverDetectionRestartRemote;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Log access is granted but takes effect when Kiosk Satellite restarts.'**
  String get screensaverDetectionLogRestart;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Log access not granted.'**
  String get screensaverDetectionLogMissing;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Dismiss on proximity'**
  String get settingScreensaverDismissOnProximityTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Watch the proximity sensor while the screensaver is up and wake the screen when something comes close to the device. A device with only sensors made for calls (\"palm\", \"touch\") will not work.'**
  String get settingScreensaverDismissOnProximityDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Only when screen is off'**
  String get settingScreensaverDismissOnProximityScreenOffOnlyTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Keep the screensaver visible when something approaches while the screen is on. Once the screen turns off, detection wakes the dashboard. Touch still dismisses the screensaver.'**
  String get settingScreensaverDismissOnProximityScreenOffOnlyDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Postpone screensaver on proximity'**
  String get settingScreensaverPostponeOnProximityTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Delay activating the screensaver while something is close to the sensor.'**
  String get settingScreensaverPostponeOnProximityDescription;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Proximity Detection'**
  String get screensaverDetectionProximityPage;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Dismiss or postpone the screensaver on the proximity sensor'**
  String get screensaverDetectionProximityHint;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Not available on this device: it has no proximity sensor.'**
  String get screensaverDetectionNoProximity;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Sensor'**
  String get screensaverDetectionSensor;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'What the device reports as the proximity sensor. A sensor made for calls named \"palm\" or \"touch\" will not work.'**
  String get screensaverDetectionSensorHelp;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Enable scheduled screensavers'**
  String get settingScreensaverScheduleEnabledTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Switch to a different screensaver at set times of day.'**
  String get settingScreensaverScheduleEnabledDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Times'**
  String get settingScreensaverScheduleTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Each time switches the screensaver from then on.'**
  String get settingScreensaverScheduleDescription;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Scheduled Screensavers'**
  String get screensaverScheduleSection;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get screensaverTime;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Add time'**
  String get screensaverAddTime;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Remove time'**
  String get screensaverRemoveTime;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'No times yet'**
  String get screensaverNoTimes;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'A screensaver from that time on.'**
  String get screensaverTimeHelp;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Pick a time.'**
  String get screensaverPickTime;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get screensaverDefault;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get screensaverOn;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get screensaverOff;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get screensaverBrightness;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Follows the Screensaver brightness setting.'**
  String get screensaverBrightnessFollow;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Applies to every mode except Black.'**
  String get screensaverBrightnessExceptBlack;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Follows the Turn screen off after setting.'**
  String get screensaverScreenOffFollow;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Keeps the screen on during these hours.'**
  String get screensaverScreenOnHours;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Powers down the display once the screensaver has run this long. Requires Device Administrator permission.'**
  String get screensaverScreenOffHelp;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Screen off never'**
  String get screensaverScreenOffNever;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Dismiss on motion'**
  String get screensaverMotion;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Dismiss on face'**
  String get screensaverFace;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Dismiss on proximity'**
  String get screensaverProximity;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Dismiss on person'**
  String get screensaverPerson;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Widgets'**
  String get screensaverWidgets;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'At a glance'**
  String get screensaverGlance;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Show Now Playing next to the screensaver'**
  String get screensaverNowPlaying;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Default follows the global layout. On uses a shared layout when Now Playing is enabled. Off hides Now Playing during these hours.'**
  String get screensaverNowPlayingHelp;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Requires the camera. Turn it on in the Camera settings first.'**
  String get screensaverCameraRequired;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Not available on this device.'**
  String get screensaverNotAvailable;

  /// Summary of an explicit schedule override.
  ///
  /// In en, this message translates to:
  /// **'Motion on'**
  String get screensaverSummaryMotionOn;

  /// Summary of an explicit schedule override.
  ///
  /// In en, this message translates to:
  /// **'Motion off'**
  String get screensaverSummaryMotionOff;

  /// Summary of an explicit schedule override.
  ///
  /// In en, this message translates to:
  /// **'Face on'**
  String get screensaverSummaryFaceOn;

  /// Summary of an explicit schedule override.
  ///
  /// In en, this message translates to:
  /// **'Face off'**
  String get screensaverSummaryFaceOff;

  /// Summary of an explicit schedule override.
  ///
  /// In en, this message translates to:
  /// **'Proximity on'**
  String get screensaverSummaryProximityOn;

  /// Summary of an explicit schedule override.
  ///
  /// In en, this message translates to:
  /// **'Proximity off'**
  String get screensaverSummaryProximityOff;

  /// Summary of an explicit schedule override.
  ///
  /// In en, this message translates to:
  /// **'Person on'**
  String get screensaverSummaryPersonOn;

  /// Summary of an explicit schedule override.
  ///
  /// In en, this message translates to:
  /// **'Person off'**
  String get screensaverSummaryPersonOff;

  /// Summary of an explicit schedule override.
  ///
  /// In en, this message translates to:
  /// **'Widgets on'**
  String get screensaverSummaryWidgetsOn;

  /// Summary of an explicit schedule override.
  ///
  /// In en, this message translates to:
  /// **'Widgets off'**
  String get screensaverSummaryWidgetsOff;

  /// Summary of an explicit schedule override.
  ///
  /// In en, this message translates to:
  /// **'At a glance on'**
  String get screensaverSummaryGlanceOn;

  /// Summary of an explicit schedule override.
  ///
  /// In en, this message translates to:
  /// **'At a glance off'**
  String get screensaverSummaryGlanceOff;

  /// Summary of an explicit schedule override.
  ///
  /// In en, this message translates to:
  /// **'Now Playing on'**
  String get screensaverSummaryNowPlayingOn;

  /// Summary of an explicit schedule override.
  ///
  /// In en, this message translates to:
  /// **'Now Playing off'**
  String get screensaverSummaryNowPlayingOff;

  /// Schedule brightness summary.
  ///
  /// In en, this message translates to:
  /// **'{percent}% brightness'**
  String screensaverBrightnessPercent(String percent);

  /// Schedule screen-off summary.
  ///
  /// In en, this message translates to:
  /// **'Screen off after {minutes} min'**
  String screensaverScreenOffAfter(String minutes);

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Website URL'**
  String get settingScreensaverWebsiteUrlTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'A page to show full-screen. It must allow being embedded.'**
  String get settingScreensaverWebsiteUrlDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Zoom level'**
  String get settingScreensaverWebsiteZoomTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Scales the whole external screensaver webview.'**
  String get settingScreensaverWebsiteZoomDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Double tap to dismiss'**
  String get settingScreensaverWebsiteDoubleTapTitle;

  /// Help below the setting.
  ///
  /// In en, this message translates to:
  /// **'Single taps interact with the website instead of dismissing.'**
  String get settingScreensaverWebsiteDoubleTapDescription;

  /// Label, status or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Website screensaver'**
  String get screensaverWebsiteSection;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Small clock'**
  String get screensaverOverlaySmallClock;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Weather'**
  String get screensaverOverlayWeather;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get screensaverOverlayBattery;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Hidden in Digital Clock and Camera Streams screensaver modes.'**
  String get screensaverOverlayClockNote;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Hidden in the Camera Streams screensaver mode.'**
  String get screensaverOverlayCameraNote;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Scale'**
  String get screensaverOverlayScale;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Scale this widget size to better fit your screen.'**
  String get screensaverOverlayScaleHelp;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Font family'**
  String get screensaverOverlayFont;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Corner'**
  String get screensaverOverlayCorner;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Widget'**
  String get screensaverOverlayWidget;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'24-hour clock'**
  String get screensaverOverlayClock24;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Show a 24-hour time instead of AM/PM.'**
  String get screensaverOverlayClock24Help;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Show date'**
  String get screensaverOverlayShowDate;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Add a short date under the clock.'**
  String get screensaverOverlayShowDateHelp;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Show percentage'**
  String get screensaverOverlayPercentage;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'The charge beside the icon.'**
  String get screensaverOverlayPercentageHelp;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Only when low'**
  String get screensaverOverlayLow;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Stay hidden until the charge drops to 20 percent.'**
  String get screensaverOverlayLowHelp;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Show name'**
  String get screensaverOverlayShowName;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'The name under the value.'**
  String get screensaverOverlayShowNameHelp;

  /// Generic font family option. Font brand names stay unchanged.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get screensaverOverlayFontSystem;

  /// Generic font family option. Font brand names stay unchanged.
  ///
  /// In en, this message translates to:
  /// **'Serif'**
  String get screensaverOverlayFontSerif;

  /// Generic font family option. Font brand names stay unchanged.
  ///
  /// In en, this message translates to:
  /// **'Condensed'**
  String get screensaverOverlayFontCondensed;

  /// Generic font family option. Font brand names stay unchanged.
  ///
  /// In en, this message translates to:
  /// **'Monospace'**
  String get screensaverOverlayFontMonospace;

  /// Generic font family option. Font brand names stay unchanged.
  ///
  /// In en, this message translates to:
  /// **'Casual'**
  String get screensaverOverlayFontCasual;

  /// Generic font family option. Font brand names stay unchanged.
  ///
  /// In en, this message translates to:
  /// **'Cursive'**
  String get screensaverOverlayFontCursive;

  /// Text color picker label.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get screensaverOverlayColor;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Weather entity'**
  String get screensaverOverlayWeatherEntity;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'No weather entities'**
  String get screensaverOverlayNoWeather;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant reported none.'**
  String get screensaverOverlayNoWeatherHelp;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Pick a weather entity…'**
  String get screensaverOverlayPickWeather;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Pick a weather entity.'**
  String get screensaverOverlayWeatherRequired;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Location name'**
  String get screensaverOverlayLocationName;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to hide the location line.'**
  String get screensaverOverlayLocationHelp;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get screensaverOverlayLocation;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'The place\'s name over the temperature.'**
  String get screensaverOverlayLocationDetail;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Feels like'**
  String get screensaverOverlayFeelsLike;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'The apparent temperature after the real one, \"30° / 33°\".'**
  String get screensaverOverlayFeelsLikeHelp;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Feels like only'**
  String get screensaverOverlayFeelsLikeOnly;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'The apparent temperature in the real one\'s place.'**
  String get screensaverOverlayFeelsLikeOnlyHelp;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Forecast'**
  String get screensaverOverlayForecast;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'The conditions, with a matching icon.'**
  String get screensaverOverlayForecastHelp;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Humidity'**
  String get screensaverOverlayHumidity;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Wind speed'**
  String get screensaverOverlayWind;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get screensaverOverlayVisibility;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Widgets'**
  String get settingScreensaverWidgetsTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Small overlays in the corners of the screensaver.'**
  String get settingScreensaverWidgetsDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Global widget scaling'**
  String get settingScreensaverWidgetScaleTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Scale all widgets together to better fit your screen size. Each widget keeps its own scale relative to the others.'**
  String get settingScreensaverWidgetScaleDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Global font family'**
  String get settingScreensaverWidgetFontTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'The typeface every widget is drawn in. A widget can pick its own.'**
  String get settingScreensaverWidgetFontDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Global font weight'**
  String get settingScreensaverWidgetFontWeightTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'How heavy every widget\'s text is drawn. Default is each line\'s own weight. A widget can pick its own.'**
  String get settingScreensaverWidgetFontWeightDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Text drop shadow'**
  String get settingScreensaverWidgetTextShadowTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Add a drop shadow to widget text for readability on photos.'**
  String get settingScreensaverWidgetTextShadowDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Vignette strength'**
  String get settingScreensaverVignetteStrengthTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Darkness of the shading behind the widgets, for readability on bright photos. 0 turns it off.'**
  String get settingScreensaverVignetteStrengthDescription;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'No widgets yet'**
  String get screensaverOverlayWidgetsEmpty;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Remove widget'**
  String get screensaverOverlayRemove;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'Add widget'**
  String get screensaverOverlayAdd;

  /// Label or guidance in this editor.
  ///
  /// In en, this message translates to:
  /// **'A small clock, the weather, the battery or an entity in a corner.'**
  String get screensaverOverlayAddHelp;

  /// Subpage navigation title or summary.
  ///
  /// In en, this message translates to:
  /// **'Corner overlays and their scale'**
  String get screensaverOverlayWidgetsHint;

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

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Disable cache'**
  String get settingDisableCacheTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Always fetch from the network and drop cached page data on load, so a redeployed dashboard always comes back fresh. Slow; treat it as a development aid.'**
  String get settingDisableCacheDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Allow mixed content'**
  String get settingAllowMixedContentTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Let HTTPS pages load insecure HTTP resources. Helps when Home Assistant mixes http:// content into an https:// dashboard.'**
  String get settingAllowMixedContentDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Ignore SSL errors'**
  String get settingIgnoreSslErrorsTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Accept untrusted or self-signed certificates. Use only on your own network, since it disables certificate verification.'**
  String get settingIgnoreSslErrorsDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Auto-reload on error'**
  String get settingAutoReloadOnErrorTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Recover automatically from page failures and app crashes.'**
  String get settingAutoReloadOnErrorDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Enable pull to refresh'**
  String get settingPullToRefreshTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Drag down from the top of the page to reload it. Off by default: on a scrolling dashboard an accidental pull is easy.'**
  String get settingPullToRefreshDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Clear cache when pulling to refresh'**
  String get settingPullToRefreshClearCacheTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'A pull also clears the web cache and wake word models before reloading, so everything comes back fresh. Login and saved page data are kept.'**
  String get settingPullToRefreshClearCacheDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Zoom level'**
  String get settingBrowserZoomTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Scales the whole page. Above 1x for wall tablets viewed from a distance; below 1x fits more dashboard on a small screen.'**
  String get settingBrowserZoomDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Enable pinch to zoom'**
  String get settingPinchToZoomTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Zoom the page with a two-finger pinch. Off by default so a kiosk dashboard stays put under stray touches.'**
  String get settingPinchToZoomDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Disable scrolling'**
  String get settingDisableScrollingTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Lock the page in place so it cannot be scrolled in any direction. Taps and buttons keep working.'**
  String get settingDisableScrollingDescription;

  /// Warning when the permission is missing.
  ///
  /// In en, this message translates to:
  /// **'Without this the kiosk cannot come back after a crash.'**
  String get browserCrashPermissionHelp;

  /// Remote crash recovery permission notice.
  ///
  /// In en, this message translates to:
  /// **'\"Display over other apps\" permission missing'**
  String get browserCrashPermissionMissing;

  /// Remote crash recovery permission notice.
  ///
  /// In en, this message translates to:
  /// **'Without it the kiosk cannot bring itself back after a crash. The grant screen appears on the tablet.'**
  String get browserCrashPermissionRemoteHelp;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Inject JavaScript on the HA dashboard'**
  String get settingBrowserInjectJsTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Run this JavaScript code after every load of the dashboard page. Useful to hide distracting elements or tweak a dashboard you do not control.'**
  String get settingBrowserInjectJsDescription;

  /// Setting label.
  ///
  /// In en, this message translates to:
  /// **'Inject JavaScript on external pages'**
  String get settingBrowserInjectJsExternalTitle;

  /// Help below this setting.
  ///
  /// In en, this message translates to:
  /// **'Run this JavaScript code after loading each external page: pages opened by a dashboard link, dashboard rotation pages and the website screensaver. The Music Assistant page is left alone.'**
  String get settingBrowserInjectJsExternalDescription;

  /// Example code shown in the empty editor.
  ///
  /// In en, this message translates to:
  /// **'// Example: hide a distracting element\ndocument.querySelector(\'#banner\').style.display = \'none\';'**
  String get browserInjectJsPlaceholder;

  /// Example code shown in the empty editor.
  ///
  /// In en, this message translates to:
  /// **'// Example: zoom a site that ignores the dashboard zoom level\ndocument.documentElement.style.zoom = \'1.25\';'**
  String get browserInjectJsExternalPlaceholder;

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

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Built-in ring'**
  String get intercomBuiltinRing;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Built-in chime'**
  String get intercomBuiltinChime;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'{file} (missing)'**
  String intercomMissingFile(String file);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Add a sound'**
  String get intercomAddSound;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Copy a sound file from this device into the sounds folder.'**
  String get intercomCopySoundHelp;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Upload a sound file from this computer into the sounds folder.'**
  String get intercomUploadSoundHelp;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get intercomUpload;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get intercomUploading;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Not a supported sound'**
  String get intercomUnsupportedSound;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Not a supported sound: pick an MP3, OGG, WAV, FLAC, M4A or AAC file.'**
  String get intercomChooseSound;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Could not copy the file'**
  String get intercomCopyFailed;

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: {error}'**
  String intercomUploadFailed(String error);

  /// Label or guidance in this section.
  ///
  /// In en, this message translates to:
  /// **'Not saved: {error}'**
  String intercomSaveFailed(String error);

  /// Action or validation message.
  ///
  /// In en, this message translates to:
  /// **'Enter a file name, not a path.'**
  String get intercomSoundFilename;

  /// Action or validation message.
  ///
  /// In en, this message translates to:
  /// **'Pick an MP3, OGG, WAV, FLAC, M4A or AAC file.'**
  String get intercomSoundFormats;
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
