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
  String get commonGrant => 'Conceder';

  @override
  String get commonEnable => 'Activar';

  @override
  String get commonRefresh => 'Actualizar';

  @override
  String get commonTest => 'Probar';

  @override
  String get commonInstall => 'Instalar';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonCopy => 'Copiar';

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
  String get settingAnalyticsBasicTitle => 'Estadísticas básicas';

  @override
  String get settingAnalyticsBasicDescription =>
      'Información del dispositivo, como el modelo, la versión de Android, la versión de la aplicación, el tamaño de pantalla y el idioma.';

  @override
  String get settingAnalyticsUsageTitle => 'Uso';

  @override
  String get settingAnalyticsUsageDescription =>
      'Detalles de lo que usas con Kiosk Satellite.';

  @override
  String get settingAnalyticsDiagnosticsTitle => 'Diagnóstico';

  @override
  String get settingAnalyticsDiagnosticsDescription =>
      'Comparte informes de fallos cuando se producen errores inesperados.';

  @override
  String get deviceAnalyticsPage => 'Estadísticas de Kiosk Satellite';

  @override
  String get deviceAnalyticsIntro =>
      'Comparte información anónima de tu instalación para mejorar Kiosk Satellite y ayudar a decidir qué dispositivos y funciones necesitan atención.';

  @override
  String get deviceAnalyticsLearn => 'Cómo procesamos tus datos';

  @override
  String get deviceAnalyticsLearnHelp =>
      'Qué envían las estadísticas de Kiosk Satellite y qué información nunca se envía.';

  @override
  String get deviceExportConfig => 'Exportar configuración';

  @override
  String get deviceExportConfigHelp =>
      'Guarda toda la configuración y el almacenamiento local de la página en un archivo.';

  @override
  String get deviceExportConfigRemoteHelp =>
      'Descarga toda la configuración y el almacenamiento local de la página.';

  @override
  String get deviceImportConfig => 'Importar configuración';

  @override
  String get deviceImportConfigHelp =>
      'Reemplaza la configuración de este dispositivo con la de un archivo exportado.';

  @override
  String get deviceExportFailed => 'No se pudo exportar';

  @override
  String get deviceExported => 'Configuración exportada';

  @override
  String get deviceImportFailed => 'No se pudo importar';

  @override
  String get deviceInvalidJson => 'El archivo no contiene JSON válido.';

  @override
  String get deviceImportComplete => 'Importación completada';

  @override
  String deviceAppliedSettings(String count) {
    return 'Se aplicaron $count opciones de configuración.';
  }

  @override
  String deviceAppliedReload(String count) {
    return 'Se aplicaron $count opciones de configuración. Es posible que la página se recargue.';
  }

  @override
  String get deviceReplaceOriginal => 'Reemplazar el dispositivo original';

  @override
  String get deviceReplaceQuestion =>
      '¿Reemplazar la configuración de este dispositivo con la del archivo? Es posible que la página se recargue.';

  @override
  String get deviceNewDevice => 'Configurar como dispositivo nuevo';

  @override
  String get deviceReplaceIdentity =>
      'Conserva el nombre y la identidad de ESPHome de la copia de seguridad. El dispositivo original debe permanecer desconectado.';

  @override
  String get deviceNewIdentity =>
      'Asigna un nombre y una identidad de ESPHome propios para que los dos dispositivos sean únicos.';

  @override
  String get deviceRestoreStorage =>
      'Restaurar el almacenamiento local de WebView';

  @override
  String get deviceRestoreStorageHelp =>
      'Incluye la sesión iniciada de Home Assistant y la selección de assist_satellite de Voice Satellite. Dos dispositivos no deben compartir un satélite.';

  @override
  String get deviceDownload => 'Descargar';

  @override
  String get deviceChooseFile => 'Elegir archivo…';

  @override
  String get deviceImportFailedSentence => 'No se pudo importar.';

  @override
  String deviceReplaceNamed(String name) {
    return 'Reemplazar \"$name\"';
  }

  @override
  String get settingDeviceNameTitle => 'Nombre del dispositivo';

  @override
  String get settingDeviceNameDescription =>
      'Nombre que se muestra en la administración remota y con el que se identifica el dispositivo en Home Assistant.';

  @override
  String get settingDeviceHostnameTitle => 'Nombre mDNS';

  @override
  String get settingDeviceHostnameDescription =>
      'Accede a la administración remota con este nombre y el puerto configurado en la red local. Bórralo para volver a usar el nombre del dispositivo.';

  @override
  String get settingDisableImpellerTitle => 'Renderizador antiguo';

  @override
  String get settingDisableImpellerDescription =>
      'Usa el renderizador Skia para GPU antiguas que fallan al iniciar. Se activa automáticamente después de dos fallos de este tipo. Se aplica la próxima vez que se inicia la aplicación.';

  @override
  String get settingLegacyWebViewTitle => 'Renderizador WebView antiguo';

  @override
  String get settingLegacyWebViewDescription =>
      'Dibuja el panel en una textura para GPU antiguas que fallan cuando aparece. Se activa automáticamente cuando el dispositivo lo necesita. Se aplica la próxima vez que se inicia la aplicación.';

  @override
  String get deviceHostnamePlaceholder => 'Se toma del nombre del dispositivo';

  @override
  String get deviceConfiguration => 'Configuración';

  @override
  String get devicePermissionsManager => 'Gestor de permisos';

  @override
  String get deviceOptions => 'Opciones';

  @override
  String get deviceStatus => 'Estado';

  @override
  String get deviceConnection => 'Conexión';

  @override
  String get devicePermissions => 'Permisos';

  @override
  String get deviceHelp => 'Ayuda';

  @override
  String get deviceAccess => 'Acceso';

  @override
  String get deviceReading => 'Leyendo…';

  @override
  String get deviceChecking => 'Comprobando...';

  @override
  String get deviceUnavailable => 'Estado no disponible.';

  @override
  String get deviceGrantOnDevice => 'Conceder en el dispositivo';

  @override
  String get deviceAppSettings => 'Configuración de la aplicación';

  @override
  String get deviceCopyCommand => 'Copiar comando';

  @override
  String get deviceOpenGuide => 'Abrir guía';

  @override
  String get deviceNotSet => 'Sin definir';

  @override
  String get deviceGranted => 'Concedido';

  @override
  String get deviceNotGranted => 'Sin conceder';

  @override
  String get deviceMissing => 'Falta';

  @override
  String get deviceNotOffered => 'No disponible';

  @override
  String get deviceOn => 'activado';

  @override
  String get deviceOff => 'desactivado';

  @override
  String get deviceServiceHint =>
      'Estado, funciones que mantiene activas, permisos necesarios';

  @override
  String get deviceRemoteHintActual =>
      'Administra este kiosko desde un navegador de tu red';

  @override
  String get deviceUpdatesHint => 'Dónde busca la aplicación nuevas versiones';

  @override
  String get deviceShizukuHint =>
      'Conexión, permisos de Android y configuración';

  @override
  String get deviceHelperHint =>
      'Estado de las actualizaciones sin confirmación, configuración por ADB e instrucciones';

  @override
  String get deviceAnalyticsHint =>
      'Comparte información anónima para mejorar Kiosk Satellite';

  @override
  String get deviceHardwareHint =>
      'Modelo, versión de Android, direcciones, memoria, tiempo de actividad';

  @override
  String get deviceHaHint => 'Conexión, versión y contenido del kiosko';

  @override
  String get deviceWebViewHint =>
      'Versión del motor, renderizador y agente de usuario';

  @override
  String get devicePasswordSet => '•••••• (definida)';

  @override
  String get deviceSaveFailed =>
      'No se pudo guardar esta opción. Inténtalo de nuevo.';

  @override
  String get deviceOpenSettingsDevice =>
      'Abrir configuración en el dispositivo';

  @override
  String get deviceHardwarePage => 'Hardware';

  @override
  String get deviceWebViewPage => 'WebView';

  @override
  String get deviceModel => 'Modelo del dispositivo';

  @override
  String get deviceAndroidVersion => 'Versión de Android';

  @override
  String get deviceAndroidBuild => 'Compilación de Android';

  @override
  String get deviceIpv4 => 'Dirección IPv4';

  @override
  String get deviceIpv6 => 'Direcciones IPv6';

  @override
  String get deviceAppUptime => 'Tiempo de actividad de la aplicación';

  @override
  String get deviceNetworkUptime => 'Tiempo de actividad de la red';

  @override
  String get deviceCpuUsage => 'Uso de CPU';

  @override
  String get deviceCpuTemp => 'Temperatura de CPU';

  @override
  String get deviceBatteryLevel => 'Nivel de batería';

  @override
  String get deviceScreenBrightness => 'Brillo de pantalla';

  @override
  String get deviceScreenStatus => 'Estado de la pantalla';

  @override
  String get deviceScreenSize => 'Tamaño de pantalla';

  @override
  String get deviceRam => 'RAM (libre/total)';

  @override
  String get deviceStorage => 'Almacenamiento interno (libre/total)';

  @override
  String get deviceHaUrl => 'URL de Home Assistant';

  @override
  String get deviceWakeDetection => 'Detección de palabras de activación';

  @override
  String get deviceWakeStatus => 'Estado de la palabra de activación';

  @override
  String get deviceEngine => 'Motor';

  @override
  String get deviceWakeWords => 'Palabras de activación';

  @override
  String get deviceStopWord => 'Palabra de detención';

  @override
  String get deviceMotionDetection => 'Detección de movimiento';

  @override
  String get deviceFaceDetection => 'Detección de rostros';

  @override
  String get deviceProvider => 'Proveedor';

  @override
  String get deviceVersion => 'Versión';

  @override
  String get deviceUserAgent => 'Agente de usuario';

  @override
  String get devicePlugged => 'conectada';

  @override
  String get deviceLowMemory => 'escasa';

  @override
  String get deviceRequiredPermissions => 'Permisos del sistema necesarios';

  @override
  String get devicePermissionIntro =>
      'Los permisos se conceden en este dispositivo. Cada botón abre aquí un diálogo o una pantalla de configuración de Android. Algunas marcas incluyen su propio gestor de batería o de inicio automático, que Android no puede consultar.';

  @override
  String get devicePermissionIntroRemote =>
      'Los permisos se conceden en el dispositivo. Cada botón abre allí un diálogo o una pantalla de configuración de Android. Algunas marcas incluyen su propio gestor de batería o de inicio automático, que Android no puede consultar.';

  @override
  String get deviceMicrophone => 'Micrófono';

  @override
  String get deviceMicrophoneHeld =>
      'Permite usar el micrófono para detectar palabras de activación, convertir voz en texto y hacer llamadas por el intercomunicador.';

  @override
  String get deviceBattery => 'Batería sin restricciones';

  @override
  String get deviceBatteryHeld =>
      'Permite que el proceso se ejecute en segundo plano sin que se pause ni se cierre.';

  @override
  String get deviceCamera => 'Cámara';

  @override
  String get deviceCameraHeld =>
      'La detección de movimiento y las capturas pueden usar la cámara.';

  @override
  String get deviceBluetooth => 'Dispositivos cercanos';

  @override
  String get deviceBluetoothHeld =>
      'El proxy Bluetooth puede buscar dispositivos cercanos.';

  @override
  String get deviceNotifications => 'Notificaciones';

  @override
  String get deviceNotificationsHeld =>
      'Permite la notificación permanente del servicio de Kiosk Satellite, que indica qué funciones mantiene activas.';

  @override
  String get deviceOverlay => 'Mostrar sobre otras aplicaciones';

  @override
  String get deviceOverlayHeld =>
      'Kiosk Satellite puede volver al primer plano.';

  @override
  String get deviceWriteSettings => 'Modificar la configuración del sistema';

  @override
  String get deviceWriteSettingsHeld =>
      'Los cambios de brillo ajustan el brillo real de la pantalla.';

  @override
  String get deviceUiGuard => 'Protección de la interfaz del sistema';

  @override
  String get deviceUiGuardHeld =>
      'El panel de notificaciones y las aplicaciones recientes se cierran automáticamente mientras la pantalla está protegida.';

  @override
  String get deviceDeviceAdmin => 'Administrador del dispositivo';

  @override
  String get deviceDeviceAdminHeld =>
      'Permite que la aplicación apague la pantalla.';

  @override
  String get deviceAllFiles => 'Acceso a todos los archivos';

  @override
  String get deviceAllFilesHeld =>
      'El gestor de archivos puede explorar el almacenamiento compartido.';

  @override
  String get deviceUsageAccess => 'Acceso al uso';

  @override
  String get deviceUsageAccessHeld =>
      'El sensor de aplicación en primer plano puede identificar la aplicación que aparece en pantalla.';

  @override
  String get deviceLocation => 'Ubicación';

  @override
  String get deviceLocationHeld =>
      'Las páginas, la búsqueda Bluetooth y los sensores de ubicación pueden usar la posición del dispositivo.';

  @override
  String get deviceMicBlocked =>
      'Bloqueado. Android no volverá a solicitarlo. Concédelo en la configuración de la aplicación.';

  @override
  String get deviceMicMissing =>
      'La detección de palabras de activación está activada, pero no hay nada escuchando.';

  @override
  String get deviceMicIdle =>
      'Necesario para detectar palabras de activación, usar el intercomunicador y abrir páginas que soliciten el micrófono.';

  @override
  String get deviceBatteryMissing =>
      'Android puede pausar la aplicación con la pantalla apagada, interrumpiendo la conexión con Home Assistant y las entidades de ESPHome.';

  @override
  String get deviceCameraMissing =>
      'La cámara está activada, pero no se puede abrir.';

  @override
  String get deviceCameraIdle =>
      'Necesario para detectar movimiento, tomar capturas y abrir páginas que soliciten la cámara.';

  @override
  String get deviceBluetoothMissing =>
      'El proxy Bluetooth está activado, pero no puede buscar dispositivos.';

  @override
  String get deviceBluetoothLocation =>
      'La búsqueda Bluetooth necesita el permiso de ubicación.';

  @override
  String get deviceBluetoothLocationOff =>
      'La ubicación está desactivada en la configuración del dispositivo, por lo que la búsqueda Bluetooth no encuentra dispositivos.';

  @override
  String get deviceBluetoothIdle =>
      'Necesario para que el proxy Bluetooth busque dispositivos.';

  @override
  String get deviceNotificationMissing =>
      'Necesario para mostrar la notificación permanente del servicio de Kiosk Satellite.';

  @override
  String get deviceOverlayMissing =>
      'Sin este permiso, la aplicación no puede volver a abrirse después de un fallo, una actualización o una palabra de activación escuchada mientras otra aplicación está en primer plano.';

  @override
  String get deviceOverlayIdle =>
      'Permite que la aplicación vuelva al primer plano y que la protección del modo de bloqueo cubra toda la pantalla.';

  @override
  String get deviceBrightnessMissing =>
      'El brillo solo atenúa la ventana de la aplicación. La pantalla y Home Assistant no reciben el cambio.';

  @override
  String get deviceBrightnessIdle =>
      'Necesario para ajustar el brillo real de la pantalla en lugar de atenuar la ventana de la aplicación.';

  @override
  String get deviceGuardMissing =>
      'El panel de notificaciones y las aplicaciones recientes siguen accesibles. Activa Kiosk Satellite en Accesibilidad.';

  @override
  String get deviceGuardIdle =>
      'Cierra el panel de notificaciones y las aplicaciones recientes mientras el modo kiosko protege la pantalla.';

  @override
  String get deviceAdminIdle =>
      'Permite que la acción de apagar pantalla la apague de verdad en lugar de mostrarla en negro.';

  @override
  String get deviceFilesIdle =>
      'Permite que el gestor de archivos explore el almacenamiento compartido y no solo la carpeta de la aplicación.';

  @override
  String get deviceUsageIdle =>
      'Permite que el sensor de aplicación en primer plano identifique otras aplicaciones además de Kiosk Satellite.';

  @override
  String get deviceLocationMissing =>
      'Android no entrega resultados de búsqueda Bluetooth sin ubicación y los sensores de ubicación no pueden leer el receptor GPS.';

  @override
  String get deviceLocationIdle =>
      'Lo usan las páginas que solicitan tu ubicación, la búsqueda Bluetooth y los sensores de ubicación de ESPHome.';

  @override
  String get deviceServiceOverlayMissing =>
      'Sin este permiso, el servicio no puede volver a abrir el kiosko después de un fallo o de cerrarlo desde las aplicaciones recientes.';

  @override
  String get deviceServiceOverlayIdle =>
      'Necesario para volver a abrir el kiosko después de un fallo.';

  @override
  String get deviceListeningMissing =>
      'La escucha en segundo plano está activada, pero no hay nada escuchando.';

  @override
  String get deviceListeningIdle =>
      'Necesario para la escucha en segundo plano.';

  @override
  String get deviceMotionIdle => 'Necesario para la detección de movimiento.';

  @override
  String get deviceBatteryAdb =>
      'Este dispositivo no tiene una pantalla de configuración para este permiso. Concédelo mediante ADB: adb shell dumpsys deviceidle whitelist +me.jxl.kiosk_satellite';

  @override
  String get deviceOverlayAdb =>
      'Este dispositivo no tiene una pantalla de configuración para este permiso. Concédelo mediante ADB: adb shell appops set me.jxl.kiosk_satellite SYSTEM_ALERT_WINDOW allow';

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
  String get settingRemoteFleetDiscoveryTitle => 'Buscar otros kioskos';

  @override
  String get settingRemoteFleetDiscoveryDescription =>
      'Anuncia este dispositivo en la red y muestra los otros kioskos en la administración remota para cambiar entre ellos.';

  @override
  String get deviceRemotePage => 'Administración remota';

  @override
  String get deviceAdminAddress => 'Dirección de administración';

  @override
  String get deviceAdminAddressHelp =>
      'Abre esta dirección en un navegador de tu computadora.';

  @override
  String get deviceByName => 'Por nombre';

  @override
  String get deviceByNameHelp =>
      'La misma dirección mediante el nombre del equipo, en redes que resuelven nombres .local.';

  @override
  String get devicePasswordNeeded =>
      'Define una contraseña de administración abajo para iniciar el servidor.';

  @override
  String get deviceServerStopped => 'El servidor no está en ejecución.';

  @override
  String devicePortError(String port, String error) {
    return 'No se pudo escuchar en el puerto $port: $error';
  }

  @override
  String get settingServiceCpuAwakeTitle =>
      'Mantener la CPU activa con la pantalla apagada';

  @override
  String get settingServiceCpuAwakeDescription =>
      'Impide que la CPU entre en suspensión con la pantalla apagada para que las conexiones y los temporizadores sigan funcionando a tiempo. Consume batería si la tableta no está conectada a la corriente.';

  @override
  String get deviceServicePage => 'Servicio de Kiosk Satellite';

  @override
  String get deviceKeepingRunning => 'Funciones que mantiene activas';

  @override
  String get deviceService => 'Servicio';

  @override
  String get deviceStopped => 'Detenido';

  @override
  String get deviceStoppedSentence => 'Detenido.';

  @override
  String get deviceRunning => 'En ejecución';

  @override
  String get deviceRunningSentence => 'En ejecución.';

  @override
  String get deviceRunningBackground =>
      'En ejecución sin la excepción de servicio en primer plano.';

  @override
  String get deviceServiceTypes => 'Tipos de servicio en primer plano';

  @override
  String get deviceServiceTypesHelp =>
      'Lo que el servicio declara a Android para las funciones que mantiene activas.';

  @override
  String get deviceNoneDeclared => 'Ninguno declarado.';

  @override
  String get deviceNone => 'ninguno';

  @override
  String get deviceCpuLock => 'Bloqueo de suspensión de la CPU';

  @override
  String get deviceCpuOff =>
      'Desactivado: la opción de abajo está desactivada.';

  @override
  String get deviceCpuHeld => 'Activo: la pantalla está apagada.';

  @override
  String get deviceCpuReleased =>
      'Liberado mientras la pantalla está encendida.';

  @override
  String get deviceNotHeld => 'No está activo.';

  @override
  String get deviceHeld => 'Activo';

  @override
  String get deviceReleased => 'Liberado';

  @override
  String get deviceWifiLock => 'Bloqueo de suspensión de Wi-Fi';

  @override
  String get deviceWifiHeld =>
      'Activo: la radio no entra en ahorro de energía.';

  @override
  String get deviceWifiHelp =>
      'Impide que la radio entre en ahorro de energía con la pantalla apagada.';

  @override
  String get deviceNotification => 'Notificación';

  @override
  String get deviceNotificationHidden =>
      'Oculta: las notificaciones de la aplicación están desactivadas. El servicio sigue funcionando.';

  @override
  String get deviceNotificationShown =>
      'Se muestra en el panel de notificaciones mientras el servicio está en ejecución.';

  @override
  String get deviceHidden => 'Oculta';

  @override
  String get deviceShown => 'Visible';

  @override
  String get deviceReasonHa => 'Conexión con Home Assistant';

  @override
  String get deviceReasonHaHelp =>
      'Mantiene abiertas la sesión del panel y su conexión WebSocket con la pantalla apagada.';

  @override
  String get deviceReasonListening => 'Escucha en segundo plano';

  @override
  String get deviceReasonListeningHelp =>
      'Mantiene activos el motor de palabras de activación y su micrófono mientras se usan otras aplicaciones.';

  @override
  String get deviceReasonRtsp => 'Audio del micrófono por RTSP';

  @override
  String get deviceReasonRtspHelp =>
      'Mantiene disponible la transmisión del micrófono para los clientes RTSP conectados.';

  @override
  String get deviceReasonEspHome => 'Servidor ESPHome';

  @override
  String get deviceReasonEspHomeHelp =>
      'Mantiene disponible el servidor de la API de ESPHome para Home Assistant.';

  @override
  String get deviceReasonRemote => 'Administración remota';

  @override
  String get deviceReasonRemoteHelp =>
      'Mantiene disponible el servidor web de administración.';

  @override
  String get deviceReasonProtections => 'Protecciones del kiosko';

  @override
  String get deviceReasonProtectionsHelp =>
      'Vuelve a abrir el kiosko si se cierra desde las aplicaciones recientes o por un fallo.';

  @override
  String get deviceReasonBluetooth => 'Proxy Bluetooth';

  @override
  String get deviceReasonBluetoothHelp =>
      'Mantiene activa la búsqueda Bluetooth mientras la aplicación no está en pantalla.';

  @override
  String get deviceReasonLocation => 'Sensores de ubicación';

  @override
  String get deviceReasonLocationHelp =>
      'Sigue recibiendo posiciones GPS con la pantalla apagada o mientras otra aplicación está en primer plano.';

  @override
  String get deviceReasonPerson => 'Detección de personas';

  @override
  String get deviceReasonPersonHelp =>
      'Sigue leyendo el sensor de personas del dispositivo mientras otra aplicación está en primer plano.';

  @override
  String get deviceReasonCameraHelp =>
      'Mantiene disponible la cámara después de apagar la pantalla para detectar movimiento y rostros.';

  @override
  String deviceServiceStopped(String error) {
    return 'Detenido: $error';
  }

  @override
  String deviceServiceRunning(String uptime) {
    return 'En ejecución durante $uptime.';
  }

  @override
  String get settingShizukuInstallUpdatesTitle =>
      'Instalar actualizaciones mediante Shizuku';

  @override
  String get settingShizukuInstallUpdatesDescription =>
      'Instala actualizaciones de Kiosk Satellite sin confirmación en el dispositivo. Shizuku debe estar en ejecución y autorizado.';

  @override
  String get deviceShizukuAccess => 'Acceso de Shizuku';

  @override
  String get deviceShizukuCheck => 'Comprobando disponibilidad';

  @override
  String get deviceShizukuRoot => 'Conectado con acceso root';

  @override
  String get deviceShizukuShell => 'Conectado con acceso shell';

  @override
  String get deviceShizukuGrant =>
      'Toca para conceder acceso. Aprueba la solicitud en este kiosko.';

  @override
  String get deviceShizukuGrantRemote =>
      'Concede acceso y aprueba la solicitud en este kiosko.';

  @override
  String get deviceShizukuDenied =>
      'Autoriza Kiosk Satellite en la aplicación Shizuku.';

  @override
  String get deviceShizukuUnsupported =>
      'Se requiere Shizuku 13 o una versión posterior.';

  @override
  String get deviceShizukuStart => 'Inicia Shizuku en este dispositivo.';

  @override
  String get deviceShizukuTest => 'Probar conexión';

  @override
  String get deviceShizukuTestHelp =>
      'Consulta la identidad del proceso sin modificar el dispositivo.';

  @override
  String get deviceShizukuTestTitle => 'Prueba de conexión';

  @override
  String get deviceShizukuTestFailed =>
      'Shizuku no pudo completar la prueba de conexión.';

  @override
  String get deviceShizukuAlreadyGranted =>
      'Ya se concedieron todos los permisos.';

  @override
  String get deviceShizukuConfirmed =>
      'Android confirmó los permisos solicitados.';

  @override
  String get deviceShizukuResults => 'Resultados de los permisos';

  @override
  String get deviceShizukuGrantAll => 'Conceder todos los permisos';

  @override
  String get deviceShizukuGrantAllHelp =>
      'Concede todos los permisos que usa KS, incluidas las funciones que están desactivadas.';

  @override
  String get deviceShizukuSetup => 'Configurar Shizuku';

  @override
  String get deviceShizukuSetupHelp =>
      'Consulta las instrucciones de instalación e inicio.';

  @override
  String get deviceShizukuLifetime =>
      'Si inicias Shizuku mediante ADB, debes volver a iniciarlo después de reiniciar el dispositivo. El acceso shell no proporciona permisos root.';

  @override
  String get deviceShizukuFailed => 'Falló la solicitud de Shizuku';

  @override
  String get deviceShizukuApprove => 'Aprueba la solicitud en el kiosko.';

  @override
  String deviceShizukuTestOk(String access) {
    return 'Shizuku ejecutó un comando correctamente con acceso $access.';
  }

  @override
  String get deviceHelperPage => 'Asistente de actualización opcional';

  @override
  String get deviceHelperStatus => 'Estado del asistente';

  @override
  String get deviceHelperError =>
      'No se pudo consultar el asistente de actualización.';

  @override
  String get deviceHelperUnneeded =>
      'Android ya puede instalar actualizaciones sin confirmación. No se necesita el asistente.';

  @override
  String get deviceHelperIntro =>
      'Este dispositivo necesita confirmación en la pantalla para instalar actualizaciones mediante Android. El asistente opcional permite que Kiosk Satellite instale actualizaciones sin tocar la pantalla.';

  @override
  String get deviceHelperBusy => 'Instalando una actualización.';

  @override
  String get deviceHelperReady =>
      'Listo. Las actualizaciones se instalan sin confirmación.';

  @override
  String get deviceHelperUnavailable =>
      'No disponible. Inicia el asistente mediante ADB para permitir actualizaciones sin confirmación.';

  @override
  String get deviceHelperLifetime =>
      'El asistente sigue funcionando después de reiniciar o actualizar la aplicación, pero se detiene al reiniciar el dispositivo. Ejecuta el comando desde una computadora con ADB para iniciarlo de nuevo. Luego puedes desconectar la computadora.';

  @override
  String get deviceHelperStart => 'Iniciar mediante ADB';

  @override
  String get deviceHelperGuide => 'Guía de configuración';

  @override
  String get deviceHelperGuideHelp =>
      'Consulta las instrucciones y los requisitos del asistente de actualización.';

  @override
  String get settingUpdateSourceTitle => 'Origen de las actualizaciones';

  @override
  String get settingUpdateSourceDescription =>
      'Dónde busca la aplicación las nuevas versiones.';

  @override
  String get settingUpdateSourceUrlTitle => 'URL del repositorio';

  @override
  String get settingUpdateSourceUrlDescription =>
      'Carpeta en un servidor web al que el kiosko pueda acceder, que contiene releases.json y los APK de las versiones.';

  @override
  String get deviceUpdatesPage => 'Actualizaciones';

  @override
  String get deviceUpdateGithub => 'Repositorio de GitHub';

  @override
  String get deviceUpdateCustom => 'Repositorio personalizado';

  @override
  String get deviceUpdateGuide => 'Guía del repositorio personalizado';

  @override
  String get deviceUpdateGuideHelp =>
      'Cómo alojar el archivo de versiones y los APK en tu propia red.';

  @override
  String get deviceInstallFile => 'Instalar desde un archivo';

  @override
  String get deviceInstallFileHelp =>
      'Sube un APK de Kiosk Satellite desde una computadora mediante la administración remota, en esta misma página. Para un kiosko que no puede acceder a GitHub ni a un repositorio personalizado.';

  @override
  String get deviceInstallFileRemoteHelp =>
      'Sube un APK de Kiosk Satellite desde esta computadora e instálalo. Para un kiosko que no puede acceder a GitHub ni a un repositorio personalizado.';

  @override
  String get deviceUploadedApk => 'APK subido';

  @override
  String get deviceInstalling => 'Instalando…';

  @override
  String get deviceDeviceNoAnswer => 'El dispositivo no respondió.';

  @override
  String get deviceInstallFailed =>
      'Falló la actualización. Revisa los registros del dispositivo.';

  @override
  String get deviceConfirmTablet => 'Confirma en la pantalla de la tableta';

  @override
  String deviceUploadedVersion(String version, String build, String size) {
    return 'La versión $version (compilación $build, $size MB) está en el dispositivo, pendiente de instalación.';
  }

  @override
  String deviceInstallVersion(String version) {
    return 'Instalar la versión $version';
  }

  @override
  String deviceHttpError(String code) {
    return 'El dispositivo respondió con HTTP $code.';
  }

  @override
  String get deviceUploadFailed => 'No se pudo subir el archivo.';

  @override
  String get deviceInstallFleet => 'Instalar en la flota';

  @override
  String get deviceSendingFleet => 'Enviando a la flota…';

  @override
  String get deviceSameBuild => 'El kiosko ya usa esta compilación.';

  @override
  String get deviceInstallConfirmation =>
      'Debes confirmar la instalación en la pantalla de la tableta, a menos que el kiosko instale sin confirmación.';

  @override
  String get deviceSelfLast => 'Este kiosko se instala al final.';

  @override
  String get deviceUpdatingFleet => 'Actualizando la flota';

  @override
  String deviceUploading(String percent) {
    return 'Subiendo… $percent%';
  }

  @override
  String deviceUploadedDetails(String version, String build, String size) {
    return 'El APK subido es la versión $version (compilación $build, $size MB).';
  }

  @override
  String deviceCurrentBuild(String version, String build) {
    return 'El kiosko usa la versión $version (compilación $build).';
  }

  @override
  String deviceSendingTo(String name, String percent) {
    return 'Enviando a $name… $percent%';
  }

  @override
  String deviceInstallingOn(String name) {
    return 'Instalando en $name…';
  }

  @override
  String deviceInstallingNames(String names) {
    return 'Instalando en $names.';
  }

  @override
  String get deviceUpdateUrlInvalid =>
      'Introduce la URL de la carpeta, por ejemplo http://nas.local/kiosk-satellite';

  @override
  String get deviceUpdateUrlPath =>
      'Introduce solo la URL de la carpeta, sin nada después de la ruta. Ejemplo: http://nas.local/kiosk-satellite';

  @override
  String get settingUiLanguageTitle => 'Idioma';

  @override
  String get settingUiLanguageDescription =>
      'Idioma de Kiosk Satellite y de la administración remota. Home Assistant conserva su propio idioma.';

  @override
  String get settingUiThemeTitle => 'Tema de la aplicación';

  @override
  String get settingUiThemeDescription =>
      'Claro u oscuro para las pantallas de la aplicación: menú, configuración y diálogos. Sistema sigue la configuración de Android.';

  @override
  String get settingUiScaleTitle => 'Escala de la interfaz';

  @override
  String get settingUiScaleDescription =>
      'Tamaño de las pantallas de la aplicación: menú, configuración y diálogos. Para pantallas de alta densidad. El contenido web conserva su tamaño.';

  @override
  String get deviceUserInterface => 'Interfaz de usuario';

  @override
  String get deviceThemeDark => 'Oscuro';

  @override
  String get deviceThemeLight => 'Claro';

  @override
  String get deviceThemeSystem => 'Sistema';

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
