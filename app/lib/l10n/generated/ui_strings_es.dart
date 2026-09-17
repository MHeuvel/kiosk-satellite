// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'ui_strings.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class UiStringsEs extends UiStrings {
  UiStringsEs([String locale = 'es']) : super(locale);

  @override
  String get commonImport => 'Importar';

  @override
  String get commonBack => 'Atrás';

  @override
  String get commonNext => 'Siguiente';

  @override
  String get commonFinish => 'Finalizar';

  @override
  String get commonWorking => 'Procesando…';

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
  String get settingDeviceNameTitle => 'Nombre del dispositivo';

  @override
  String get settingDeviceNameDescription =>
      'Nombre que se muestra en la administración remota y con el que se identifica el dispositivo en Home Assistant.';

  @override
  String get settingRemoteEnabledTitle => 'Administración remota';

  @override
  String get settingRemoteEnabledDescription =>
      'Activa el servidor web integrado para administrar el dispositivo.';

  @override
  String get settingRemotePortTitle => 'Puerto del servidor';

  @override
  String get settingRemotePortDescription =>
      'Puerto de la interfaz de administración remota.';

  @override
  String get settingRemotePasswordTitle => 'Contraseña de administración';

  @override
  String get settingRemotePasswordDescription =>
      'Necesaria para iniciar sesión en la interfaz remota.';

  @override
  String get settingUiLanguageTitle => 'Language';

  @override
  String get settingUiLanguageDescription =>
      'Language for Kiosk Satellite and remote administration. Home Assistant keeps its own language.';

  @override
  String get settingHaUrlTitle => 'URL base de Home Assistant';

  @override
  String get settingHaUrlDescription =>
      'Por ejemplo, https://homeassistant.local:8123, sin la ruta de un panel.';

  @override
  String get settingHaTokenTitle => 'Token de acceso de larga duración';

  @override
  String get settingHaTokenDescription =>
      'Se crea en tu perfil de Home Assistant → Seguridad.';

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
  String get setupConnectHeading => 'Conectar con Home Assistant';

  @override
  String get setupConnectLead =>
      'La URL base de tu instancia y un token de acceso de larga duración, que puedes crear en tu perfil de Home Assistant → Seguridad → Tokens de acceso de larga duración.';

  @override
  String get setupBaseUrl => 'URL base de Home Assistant';

  @override
  String get setupToken => 'Token de acceso de larga duración';

  @override
  String get setupScanQr => 'Escanear el código QR';

  @override
  String get setupInvalidToken => 'Token de acceso no válido';

  @override
  String get setupInvalidTokenHelp =>
      'Home Assistant rechazó este token. En Home Assistant, abre tu perfil → Seguridad → Tokens de acceso de larga duración, crea un nuevo token y copia su valor completo.';

  @override
  String get setupUnreachable => 'Home Assistant no responde';

  @override
  String get setupUnreachableHelp =>
      'No se recibió respuesta de esta dirección. Comprueba que la URL sea correcta y que este dispositivo esté en la misma red que tu servidor de Home Assistant.';

  @override
  String get setupUnexpectedResponseHelp =>
      'Un servidor respondió, pero no parece ser Home Assistant. Comprueba que la URL sea la dirección base de Home Assistant, por ejemplo https://homeassistant.local:8123.';

  @override
  String get setupCannotConnect => 'No se pudo conectar';

  @override
  String get setupCameraPermission => 'Se necesita permiso para usar la cámara';

  @override
  String get setupCameraBlocked =>
      'Permite que Kiosk Satellite acceda a la cámara en la configuración de Android para escanear el código QR.';

  @override
  String get setupCameraAllow =>
      'Permite el acceso a la cámara para escanear el código QR.';

  @override
  String get setupEnterBaseUrl => 'Introduce la URL base de Home Assistant';

  @override
  String get setupInvalidBaseUrl => 'URL base no válida';

  @override
  String get setupBaseUrlHelp =>
      'Es la dirección que usas para abrir Home Assistant, por ejemplo https://homeassistant.local:8123.';

  @override
  String get setupEnterToken =>
      'Introduce un token de acceso de larga duración';

  @override
  String get setupEnterTokenHelp =>
      'En Home Assistant, abre tu perfil → Seguridad → Tokens de acceso de larga duración para crear uno.';

  @override
  String get setupValidateContinue => 'Validar y continuar';

  @override
  String setupUnexpectedResponse(String error) {
    return 'Respuesta inesperada ($error)';
  }

  @override
  String get baseUrlInvalid =>
      'Introduce una URL válida, por ejemplo https://homeassistant.local:8123';

  @override
  String get baseUrlPath =>
      'Introduce solo la URL base, sin la ruta de un panel. Ejemplo: https://homeassistant.local:8123';

  @override
  String get baseUrlQuery =>
      'Introduce solo la URL base, sin nada después del puerto. Ejemplo: https://homeassistant.local:8123';

  @override
  String get setupWelcome => 'Bienvenido';

  @override
  String get setupConnect => 'Conectar';

  @override
  String get setupConnectSummary => 'URL y token de Home Assistant';

  @override
  String get setupDashboard => 'Panel';

  @override
  String get setupDashboardSummary => 'Lo que muestra el kiosko';

  @override
  String get setupRecommendedSummary => 'Configuración recomendada';

  @override
  String get setupPermissions => 'Permisos';

  @override
  String get setupPermissionsSummary => 'Lo necesario para la configuración';

  @override
  String get setupRemoteHeading => 'Administración remota';

  @override
  String get setupTitle => 'Configurar\nKiosk Satellite';

  @override
  String get setupWelcomeLead =>
      'Convierte esta tableta en un kiosko de Home Assistant. La configuración tarda un par de minutos y este asistente te guía paso a paso.';

  @override
  String get setupDeviceName => 'Nombre del dispositivo';

  @override
  String get setupDeviceNameHelp =>
      'Nombre con el que se identifica este kiosko en Home Assistant, en la administración remota y en la red. Puedes cambiarlo cuando quieras en Settings > Device.';

  @override
  String get setupEnableRemote => 'Activar la administración remota';

  @override
  String get setupEnableRemoteHelp =>
      'Sigue administrando este kiosko desde un navegador web después de configurarlo. Desde allí es mucho más fácil pegar el token de acceso de Home Assistant.';

  @override
  String get setupRemotePassword => 'Contraseña de administración remota';

  @override
  String get setupRestoreHeading => 'Restaurar copia de seguridad';

  @override
  String get setupRestore => 'Restaurar desde un archivo de configuración';

  @override
  String get setupRestoreHelp =>
      'Importa una configuración exportada desde Kiosk Satellite y omite el resto de este asistente. Se incluyen la configuración, el panel y los datos de inicio de sesión.';

  @override
  String get setupServicePermissions =>
      'Permisos recomendados para el servicio';

  @override
  String get setupPasswordShort => 'La contraseña es demasiado corta';

  @override
  String get setupPasswordMinimum => 'Usa al menos 4 caracteres.';

  @override
  String setupRemoteAddress(String address) {
    return 'Puedes continuar esta configuración de forma remota desde un navegador web en $address, aunque el interruptor de arriba esté desactivado.';
  }

  @override
  String get remoteWelcomeTitle => 'Bienvenido a Kiosk Satellite';

  @override
  String get remoteWelcomePassword =>
      'Esta tableta está pendiente de configurar. Primero, protege la administración remota con una contraseña.';

  @override
  String get remoteWelcomeReady =>
      'Esta tableta está pendiente de configurar. La contraseña de administración remota ya está definida. Para cambiarla, escribe una nueva aquí.';

  @override
  String get remoteInitialPassword =>
      'Contraseña de administración (mínimo 4 caracteres)';

  @override
  String get remoteNewPassword =>
      'Nueva contraseña de administración (deja el campo vacío para conservar la actual)';
}
