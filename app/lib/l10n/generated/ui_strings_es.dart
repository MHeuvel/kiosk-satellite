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
  String get commonSettings => 'Configuración';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonOk => 'Aceptar';

  @override
  String drawerPluginAction(String pluginName, String actionTitle) {
    return '$pluginName: $actionTitle';
  }

  @override
  String get drawerPluginActionErrorTitle => 'Acción del plugin';

  @override
  String get drawerPluginActionError => 'No se pudo ejecutar esta acción.';

  @override
  String get drawerDashboard => 'Panel';

  @override
  String get drawerHaKiosk => 'Modo kiosko de HA';

  @override
  String get drawerCameraView => 'Vista de cámaras';

  @override
  String get drawerIntercom => 'Intercomunicador';

  @override
  String get drawerMusicAssistant => 'Music Assistant';

  @override
  String get drawerHidePlayer => 'Ocultar reproductor flotante';

  @override
  String get drawerShowPlayer => 'Mostrar reproductor flotante';

  @override
  String get drawerNowPlaying => 'En reproducción';

  @override
  String get drawerScreensaver => 'Iniciar protector de pantalla';

  @override
  String get drawerLockdown => 'Modo de bloqueo';

  @override
  String get drawerHoldOff => 'Desactivar modo de pausa';

  @override
  String get drawerHoldOn => 'Activar modo de pausa';

  @override
  String get drawerApps => 'Aplicaciones';

  @override
  String get drawerClearCache => 'Borrar caché web';

  @override
  String get drawerRestartDevice => 'Reiniciar dispositivo';

  @override
  String get drawerRestartConfirm =>
      '¿Reiniciar este dispositivo? Kiosk Satellite volverá a abrirse cuando se inicie.';

  @override
  String get drawerRestart => 'Reiniciar';

  @override
  String get drawerExitApplication => 'Salir de la aplicación';

  @override
  String get drawerExitConfirm => '¿Cerrar Kiosk Satellite?';

  @override
  String get drawerExit => 'Salir';

  @override
  String get drawerHoldActive => 'El modo de pausa está activado';

  @override
  String get drawerHoldHelp =>
      'El protector de pantalla y los temporizadores están en pausa · toca para desactivar';

  @override
  String get drawerThemeDark => 'Oscuro';

  @override
  String get drawerThemeLight => 'Claro';

  @override
  String get drawerThemeAndroid => 'Seguir Android';

  @override
  String drawerVersion(String version) {
    return 'Versión $version';
  }

  @override
  String get drawerUpdateAvailable => 'Actualización disponible';

  @override
  String drawerUpdateInstall(String version) {
    return 'Versión $version · toca para instalar';
  }

  @override
  String get drawerUpdateChecking => 'Buscando actualizaciones…';

  @override
  String get drawerUpdateCurrent => 'Actualizado';

  @override
  String get drawerUpdateCurrentHelp => 'Tienes la versión más reciente.';

  @override
  String get drawerUpdateCheckFailed => 'No se pudieron buscar actualizaciones';

  @override
  String get drawerUpdateOffline =>
      '¿El dispositivo tiene conexión a internet?';

  @override
  String drawerUpdateTo(String version) {
    return 'Actualizar a $version';
  }

  @override
  String get drawerUpdateInstructions =>
      'La descarga comienza al tocar Actualizar. Android te pedirá que confirmes la instalación.';

  @override
  String get drawerUpdateRelaunch =>
      'Sin el permiso \"Mostrar sobre otras aplicaciones\", la aplicación no puede volver a abrirse después de actualizarse.';

  @override
  String get drawerUpdate => 'Actualizar';

  @override
  String get drawerUpdateDownloading => 'Descargando actualización';

  @override
  String get drawerUpdateStarting => 'Iniciando…';

  @override
  String get drawerUpdateFailed => 'No se pudo actualizar';

  @override
  String get drawerUpdates => 'Actualizaciones';

  @override
  String get drawerNoReleaseNotes => 'No hay notas de la versión.';

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
  String get settingUiLanguageTitle => 'Idioma';

  @override
  String get settingUiLanguageDescription =>
      'Idioma de Kiosk Satellite y de la administración remota. Home Assistant conserva su propio idioma.';

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
  String get settingsMenuHomeAssistant => 'Configuración de Home Assistant';

  @override
  String get settingsMenuHomeAssistantSummary => 'Conexión, panel, modo kiosko';

  @override
  String get settingsMenuVoiceSatellite => 'Voice Satellite';

  @override
  String get settingsMenuVoiceSatelliteSummary =>
      'Palabra de activación, escucha en segundo plano';

  @override
  String get settingsMenuEsphome => 'ESPHome';

  @override
  String get settingsMenuEsphomeSummary =>
      'Entidades nativas y proxy Bluetooth';

  @override
  String get settingsMenuScreenAudio => 'Pantalla y audio';

  @override
  String get settingsMenuScreenAudioSummary => 'Brillo, volumen, micrófono';

  @override
  String get settingsMenuScreensaver => 'Protector de pantalla';

  @override
  String get settingsMenuScreensaverSummary =>
      'Tiempo de inactividad, modos, activación por movimiento';

  @override
  String get settingsMenuBrowser => 'Navegación web';

  @override
  String get settingsMenuBrowserSummary => 'Caché, SSL, nivel de zoom';

  @override
  String get settingsMenuMediaPlayer => 'Reproductor multimedia';

  @override
  String get settingsMenuMediaPlayerSummary =>
      'Music Assistant, Sendspin, Sonos';

  @override
  String get settingsMenuDlna => 'Receptor DLNA';

  @override
  String get settingsMenuDlnaSummary =>
      'Reproduce imágenes, videos y audio de forma remota';

  @override
  String get settingsMenuIntercom => 'Intercomunicador';

  @override
  String get settingsMenuIntercomSummary => 'Habla entre kioskos';

  @override
  String get settingsMenuCamera => 'Cámara';

  @override
  String get settingsMenuCameraSummary =>
      'Cámara del dispositivo, movimiento, transmisión';

  @override
  String get settingsMenuCameraStreams => 'Transmisiones de cámaras';

  @override
  String get settingsMenuCameraStreamsSummary =>
      'Cámaras de Go2RTC y Home Assistant';

  @override
  String get settingsMenuKiosk => 'Modo kiosko';

  @override
  String get settingsMenuKioskSummary =>
      'Gesto de salida, PIN, botones físicos';

  @override
  String get settingsMenuHomeLauncher => 'Pantalla de inicio';

  @override
  String get settingsMenuHomeLauncherSummary =>
      'Reemplaza la pantalla de inicio del dispositivo';

  @override
  String get settingsMenuAppLauncher => 'Lanzador de aplicaciones';

  @override
  String get settingsMenuAppLauncherSummary =>
      'Abre otras aplicaciones desde el kiosko';

  @override
  String get settingsMenuGestures => 'Gestos';

  @override
  String get settingsMenuGesturesSummary =>
      'Gestos táctiles, con la palma y con aplausos';

  @override
  String get settingsMenuDevice => 'Dispositivo';

  @override
  String get settingsMenuDeviceSummary =>
      'Nombre, tema de la aplicación, acceso remoto';

  @override
  String get settingsMenuFleet => 'Gestión de flotas';

  @override
  String get settingsMenuFleetSummary => 'Coordina otros kioskos o sigue a uno';

  @override
  String get settingsMenuPlugins => 'Gestor de plugins';

  @override
  String get settingsMenuPluginsSummary => 'Instala y administra plugins';

  @override
  String get settingsMenuLogs => 'Registros';

  @override
  String get settingsMenuLogsSummary =>
      'Registro de la aplicación y consola web';

  @override
  String get settingsMenuAbout => 'Acerca de';

  @override
  String get settingsMenuAboutSummary => 'Versión, autor, licencia';

  @override
  String get settingsMenuOverview => 'Vista general';

  @override
  String get settingsMenuOverviewSummary => 'Pantalla y controles rápidos';

  @override
  String get settingsMenuLockdown => 'Modo de bloqueo';

  @override
  String get settingsMenuLockdownSummary =>
      'Desactiva las interacciones con la pantalla';

  @override
  String get settingsMenuFiles => 'Gestor de archivos';

  @override
  String get settingsMenuFilesSummary => 'Explora, descarga y sube archivos';

  @override
  String get settingsGroupHomeAssistant => 'Home Assistant';

  @override
  String get settingsGroupDisplay => 'Pantalla';

  @override
  String get settingsGroupMediaCameras => 'Multimedia y cámaras';

  @override
  String get settingsGroupKiosk => 'Kiosko';

  @override
  String get settingsGroupSystem => 'Sistema';

  @override
  String get settingsMenuMenu => 'Menú';

  @override
  String get settingsMenuTheme => 'Tema';

  @override
  String get settingsMenuLogout => 'Cerrar sesión';

  @override
  String get settingsMenuSwitchKiosk => 'Cambiar de kiosko';

  @override
  String settingsMenuThemeState(String theme) {
    return 'Tema: $theme';
  }

  @override
  String get settingsMenuThemeAuto => 'Automático';

  @override
  String get settingsSearchHint => 'Buscar en la configuración';

  @override
  String get settingsSearchClear => 'Borrar búsqueda';

  @override
  String get settingsSearchResults => 'Resultados de búsqueda';

  @override
  String settingsSearchEmpty(String query) {
    return 'No hay opciones que coincidan con \"$query\".';
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
      'Nombre con el que se identifica este kiosko en Home Assistant, en la administración remota y en la red. Puedes cambiarlo cuando quieras en Configuración > Dispositivo.';

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
