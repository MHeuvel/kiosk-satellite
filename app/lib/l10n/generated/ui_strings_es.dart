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
  String get commonAdd => 'Añadir';

  @override
  String get commonRemove => 'Eliminar';

  @override
  String get commonClose => 'Cerrar';

  @override
  String get commonClear => 'Borrar';

  @override
  String get commonBrowse => 'Examinar';

  @override
  String get commonSet => 'Establecer';

  @override
  String get commonHour => 'Hora';

  @override
  String get commonMinute => 'Minuto';

  @override
  String get commonUp => 'Aumentar';

  @override
  String get commonDown => 'Disminuir';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonSaveFailed => 'No se pudo guardar';

  @override
  String get commonColorWhite => 'Blanco';

  @override
  String get commonColorWarm => 'Cálido';

  @override
  String get commonColorAmber => 'Ámbar';

  @override
  String get commonColorRed => 'Rojo';

  @override
  String get commonColorGreen => 'Verde';

  @override
  String get commonColorBlue => 'Azul';

  @override
  String get commonColorCyan => 'Cian';

  @override
  String get commonColorDim => 'Gris oscuro';

  @override
  String get commonEdit => 'Editar';

  @override
  String get commonMoveUp => 'Subir';

  @override
  String get commonMoveDown => 'Bajar';

  @override
  String get commonPreviousMonth => 'Mes anterior';

  @override
  String get commonNextMonth => 'Mes siguiente';

  @override
  String get commonLoading => 'Cargando…';

  @override
  String drawerPluginAction(String pluginName, String actionTitle) {
    return '$pluginName: $actionTitle';
  }

  @override
  String get drawerPluginActionErrorTitle => 'Acción del plugin';

  @override
  String get drawerPluginActionError => 'No se pudo ejecutar esta acción.';

  @override
  String get drawerDashboard => 'Panel de control';

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
      'Dibuja el panel de control en una textura para GPU antiguas que fallan cuando aparece. Se activa automáticamente cuando el dispositivo lo necesita. Se aplica la próxima vez que se inicia la aplicación.';

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
      'Mantiene abiertas la sesión del panel de control y su conexión WebSocket con la pantalla apagada.';

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
  String get settingHaHoldModeTitle => 'Modo de pausa';

  @override
  String get settingHaHoldModeDescription =>
      'Mantiene la vista actual en pantalla. El protector de pantalla, la rotación de vistas y el temporizador de regreso al inicio quedan en pausa hasta desactivarlo.';

  @override
  String get settingHaHoldReleaseMinutesTitle =>
      'Terminar la pausa automáticamente después de';

  @override
  String get settingHaHoldReleaseMinutesDescription =>
      'Desactiva el modo de pausa al cumplirse el tiempo indicado. Con 0, continúa hasta desactivarlo manualmente.';

  @override
  String get settingHaHoldMenuTitle => 'Mostrar en el menú del kiosko';

  @override
  String get settingHaHoldMenuDescription =>
      'Añade una opción al menú para activar y desactivar el modo de pausa.';

  @override
  String get haHoldHint =>
      'Mantiene la vista actual, finalización automática y opción de menú';

  @override
  String get haNever => 'Nunca';

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
  String get settingDisableSuspendTitle =>
      'Mantener la conexión en segundo plano';

  @override
  String get settingDisableSuspendDescription =>
      'Desactiva la opción «Suspender conexiones en segundo plano» de Home Assistant, que de otro modo cerraría la conexión unos minutos después de apagarse la pantalla.';

  @override
  String get settingFreezeOnScreensaverTitle =>
      'Pausar el panel de control durante el protector de pantalla';

  @override
  String get settingFreezeOnScreensaverDescription =>
      'Deja de dibujar el panel de control mientras lo cubre el protector de pantalla para reducir el uso de CPU y GPU. La conexión sigue activa. No se aplica al modo Atenuar.';

  @override
  String get settingWsFilterTitle =>
      'Filtrar las actualizaciones del panel de control';

  @override
  String get settingWsFilterDescription =>
      'Procesa solo las actualizaciones de las entidades de la vista actual para reducir las interrupciones en tabletas poco potentes. Las vistas cuyas entidades no se puedan determinar quedan sin filtrar.';

  @override
  String get settingPauseDashboardCamerasTitle =>
      'Pausar las cámaras del panel de control durante el protector de pantalla';

  @override
  String get settingPauseDashboardCamerasDescription =>
      'Pausa las transmisiones de cámara compatibles y silenciadas del panel de control de Home Assistant mientras lo cubre el protector de pantalla. Se reconectan al cerrarlo. No afecta a la cámara del dispositivo ni a la función Transmisiones de cámara.';

  @override
  String get haOptimizations => 'Optimizaciones';

  @override
  String get haOptimizationsHint =>
      'Conexión en segundo plano, pausa del panel de control y las cámaras, filtro de actualizaciones';

  @override
  String get haScanUnavailable =>
      'Los detalles del análisis no están disponibles para la vista actual.';

  @override
  String get haScanDetails => 'Detalles del análisis del panel de control';

  @override
  String haWatchedTitle(String count) {
    return 'Entidades supervisadas ($count)';
  }

  @override
  String get haWatched => 'Entidades supervisadas';

  @override
  String get haEntityListUnavailable =>
      'La lista de entidades no está disponible en este momento.';

  @override
  String haWatching(String count) {
    return 'Se supervisan $count entidades en esta vista.';
  }

  @override
  String get haNoUpdates => 'No hubo actualizaciones en el último minuto.';

  @override
  String haFiltered(String percent, String dropped, String total) {
    return 'Se filtró el $percent% de las actualizaciones del último minuto ($dropped de $total).';
  }

  @override
  String get haRawUpdates =>
      'Un elemento de esta página recibe todas las actualizaciones de entidades de todas formas, por lo que el filtrado ahorra menos aquí.';

  @override
  String get haAllStates =>
      'Esta vista lee los estados de todas las entidades, por lo que sus actualizaciones no se filtran.';

  @override
  String get haUnknownEntities =>
      'No se pueden determinar las entidades de esta vista, por lo que sus actualizaciones no se filtran.';

  @override
  String get haWaiting => 'Esperando a que se cargue el panel de control…';

  @override
  String get haShowScan => 'Mostrar detalles del análisis.';

  @override
  String haThreshold(String count) {
    return 'Esta vista usa $count entidades, lo que supera el umbral del filtro. El filtrado está desactivado.';
  }

  @override
  String get settingHaReturnHomeEnabledTitle =>
      'Volver a la vista de inicio del panel de control';

  @override
  String get settingHaReturnHomeEnabledDescription =>
      'Vuelve al panel de control configurado arriba después de un periodo de inactividad.';

  @override
  String get settingHaReturnHomeSecondsTitle => 'Volver después de (segundos)';

  @override
  String get settingHaReturnHomeSecondsDescription =>
      'Periodo de inactividad antes de que el kiosko vuelva.';

  @override
  String get haReturnHint =>
      'Vuelve a la vista de inicio tras un periodo de inactividad';

  @override
  String get haReturnDisabled =>
      'Se desactiva mientras está activa la rotación de vistas del panel de control.';

  @override
  String get haReturnNoPath =>
      'El panel de control configurado no tiene una ruta de vista a la que volver.';

  @override
  String haReturnPath(String path) {
    return 'Vuelve a \"$path\" al cumplirse el tiempo de espera.';
  }

  @override
  String get settingHaRotationEnabledTitle =>
      'Activar la rotación de vistas del panel de control';

  @override
  String get settingHaRotationEnabledDescription =>
      'Recorre las vistas seleccionadas del panel de control en un ciclo continuo y muestra cada una durante el número de segundos elegido.';

  @override
  String get settingHaRotationSecondsTitle => 'Segundos por vista';

  @override
  String get settingHaRotationSecondsDescription =>
      'Cuánto tiempo permanece cada vista en pantalla.';

  @override
  String get settingHaRotationPauseSecondsTitle =>
      'Pausa de la rotación al interactuar (segundos)';

  @override
  String get settingHaRotationPauseSecondsDescription =>
      'Tocar la pantalla pausa la rotación durante este tiempo y cada toque reinicia la cuenta. Las interacciones de voz la pausan hasta que terminan. Con 0, los toques no pausan la rotación.';

  @override
  String get settingHaRotationCrossfadeTitle => 'Fundido entre vistas';

  @override
  String get settingHaRotationCrossfadeDescription =>
      'Se desvanece hasta el fondo y luego aparece la siguiente vista en lugar de cambiar al instante. Los cambios a otro panel de control o a una página externa siguen siendo instantáneos.';

  @override
  String get settingHaRotationFadeSecondsTitle =>
      'Duración del fundido (segundos)';

  @override
  String get settingHaRotationFadeSecondsDescription =>
      'Tiempo total de desaparición y aparición. Cargar la siguiente vista puede añadir tiempo, sobre todo al abrirla por primera vez.';

  @override
  String get haRotation => 'Rotación de vistas del panel de control';

  @override
  String get haRotationHint =>
      'Recorre las vistas, duración de cada vista y fundido';

  @override
  String get haDefaultView => 'Vista predeterminada';

  @override
  String get haExternalPages => 'Páginas externas';

  @override
  String get haFadeError =>
      'Elige una duración de fundido entre 0.2 y 5 segundos.';

  @override
  String get haPauseRemoteHelp =>
      'Tocar la pantalla pausa la rotación durante este tiempo y cada toque reinicia la cuenta. Las interacciones de voz la pausan hasta que terminan. Con 0, los toques no pausan la rotación.';

  @override
  String get settingHaUrlTitle => 'URL base de Home Assistant';

  @override
  String get settingHaUrlDescription =>
      'Por ejemplo, https://homeassistant.local:8123, sin la ruta de un panel de control.';

  @override
  String get settingHaTokenTitle => 'Token de acceso de larga duración';

  @override
  String get settingHaTokenDescription =>
      'Se crea en tu perfil de Home Assistant → Seguridad.';

  @override
  String get settingHaAutoLoginTitle => 'Iniciar sesión automáticamente';

  @override
  String get settingHaAutoLoginDescription =>
      'Inicia sesión en el panel de control con el token de acceso indicado arriba en lugar de mostrar la página de inicio de sesión de Home Assistant.';

  @override
  String get haValidate => 'Validar';

  @override
  String get haValidateConnection => 'Validar conexión';

  @override
  String get haChecking => 'Comprobando…';

  @override
  String get haConnected => 'Conectado';

  @override
  String get haConnectedRemote => 'Conectado.';

  @override
  String get haNotValidated =>
      'Aún no se ha validado. Las opciones de abajo se habilitan cuando se confirma la conexión.';

  @override
  String get haConnectFailed => 'No se pudo conectar.';

  @override
  String get haNotConfigured =>
      'La URL y el token de Home Assistant no están configurados';

  @override
  String get haInvalidToken => 'Token no válido';

  @override
  String haUnreachable(String error) {
    return 'No se pudo conectar con Home Assistant: $error';
  }

  @override
  String get haProxy => 'Proxy de contexto seguro';

  @override
  String get haProxyHelp =>
      'Pasa la conexión http de Home Assistant por un proxy dentro de la aplicación para que el navegador habilite el micrófono y otras funciones exclusivas de https. Solo para direcciones http.';

  @override
  String get haProxyRemoteHelp =>
      'Pasa la conexión http de Home Assistant por un proxy dentro de la aplicación para que el navegador habilite el micrófono y otras funciones exclusivas de https. Solo para direcciones http.';

  @override
  String get haProxyNotice =>
      'Esta dirección de Home Assistant usa http y los navegadores bloquean el micrófono y otras funciones en páginas http. Kiosk Satellite pasará el panel de control por un proxy seguro dentro de la aplicación para habilitarlas. Es posible que tengas que volver a iniciar sesión en Home Assistant.';

  @override
  String get haProxyRemoteNotice =>
      'Esta dirección de Home Assistant usa http y los navegadores bloquean el micrófono y otras funciones en páginas http. Kiosk Satellite pasará el panel de control por un proxy seguro dentro de la aplicación para habilitarlas. Es posible que tengas que volver a iniciar sesión en Home Assistant en la tableta.';

  @override
  String get haDashboard => 'Panel de control';

  @override
  String get haChooseView => 'Elegir una vista';

  @override
  String get haLoadingDashboards => 'Cargando paneles de control…';

  @override
  String get haListFailed => 'No se pudieron listar los paneles de control';

  @override
  String get haRetryHint => 'Toca para volver a intentarlo.';

  @override
  String get haChangeView => 'Cambiar vista';

  @override
  String get haNoViews => 'No hay vistas secundarias';

  @override
  String get haNoViewsHelp =>
      'Este panel de control no tiene vistas secundarias seleccionables.';

  @override
  String get haNoDashboards => 'No se encontraron paneles de control';

  @override
  String get settingHaThemeTitle => 'Tema';

  @override
  String get settingHaThemeDescription =>
      'Tema claro u oscuro para el panel de control de Home Assistant. También se puede elegir desde la entidad Tema de Home Assistant. Automático sigue las opciones de abajo.';

  @override
  String get settingThemeMatchAppTitle =>
      'Sincronizar el tema de Home Assistant con Kiosk Satellite';

  @override
  String get settingThemeMatchAppDescription =>
      'Adapta automáticamente el tema de Home Assistant al de la interfaz de Kiosk Satellite.';

  @override
  String get settingThemeAutoTitle => 'Cambiar el tema según la hora';

  @override
  String get settingThemeAutoDescription =>
      'Cambia Home Assistant entre claro y oscuro según un horario. Conserva el tema seleccionado y cambia solo su variante clara u oscura.';

  @override
  String get settingThemeDarkAtTitle => 'Tema oscuro a las';

  @override
  String get settingThemeDarkAtDescription =>
      'Hora local para cambiar al tema oscuro.';

  @override
  String get settingThemeLightAtTitle => 'Tema claro a las';

  @override
  String get settingThemeLightAtDescription =>
      'Hora local para volver al tema claro.';

  @override
  String get settingThemeAutoAppTitle =>
      'Cambiar también el tema de la aplicación';

  @override
  String get settingThemeAutoAppDescription =>
      'Cambia el tema de Kiosk Satellite (menú y configuración) junto con el cambio programado de Home Assistant.';

  @override
  String get haThemeHint =>
      'Sincroniza con la aplicación o cambia entre claro y oscuro según un horario';

  @override
  String get haThemeAuto => 'Automático';

  @override
  String get settingHaKioskModeTitle => 'Modo kiosko de HA';

  @override
  String get settingHaKioskModeDescription =>
      'Oculta la cabecera y la barra lateral de Home Assistant. Se aplica de inmediato.';

  @override
  String get settingHaKioskHideHeaderTitle => 'Ocultar la cabecera';

  @override
  String get settingHaKioskHideHeaderDescription =>
      'Oculta la barra de herramientas del panel de control y las pestañas de las vistas mientras está activo el modo kiosko de HA. Déjalo desactivado si cambias de vista desde la cabecera.';

  @override
  String get settingHaKioskHideSidebarTitle => 'Ocultar la barra lateral';

  @override
  String get settingHaKioskHideSidebarDescription =>
      'Oculta la barra lateral de navegación mientras está activo el modo kiosko de HA.';

  @override
  String get settingHaKioskMenuTitle => 'Mostrar en el menú del kiosko';

  @override
  String get settingHaKioskMenuDescription =>
      'Añade una opción al menú del kiosko para activar y desactivar el modo kiosko de HA.';

  @override
  String get settingHaDashboardCarouselTitle =>
      'Activar el carrusel del panel de control';

  @override
  String get settingHaDashboardCarouselDescription =>
      'Desliza a izquierda o derecha sobre el panel de control para cambiar de vista. No afecta a los gestos sobre controles deslizantes, mapas y tarjetas con desplazamiento.';

  @override
  String get settingHaCarouselOverCardsTitle =>
      'Capturar deslizamientos sobre tarjetas';

  @override
  String get settingHaCarouselOverCardsDescription =>
      'Cambia de vista incluso cuando el gesto comienza sobre una tarjeta que responde a deslizamientos. Los controles deslizantes siguen funcionando normalmente.';

  @override
  String get settingHaHapticsTitle => 'Activar la vibración';

  @override
  String get settingHaHapticsDescription =>
      'Vibra al usar botones, interruptores, tarjetas, controles deslizantes y diales de termostato. Requiere un motor de vibración.';

  @override
  String get settingHaHapticsStrengthTitle => 'Intensidad de la vibración';

  @override
  String get settingHaHapticsStrengthDescription =>
      'Qué tan intensa se siente la vibración.';

  @override
  String get settingHaTapSoundTitle => 'Reproducir sonidos al tocar';

  @override
  String get settingHaTapSoundDescription =>
      'Reproduce el sonido de toque de Android al usar botones, interruptores, tarjetas, controles deslizantes y diales de termostato.';

  @override
  String get settingHaTapSoundVolumeTitle => 'Volumen del sonido de toque';

  @override
  String get settingHaTapSoundVolumeDescription =>
      'Qué tan fuerte suena cada toque.';

  @override
  String get haUserInterface => 'Interfaz de usuario';

  @override
  String get haInterfaceHint =>
      'Modo kiosko, carrusel del panel de control, vibración y sonidos de toque';

  @override
  String get haHaptics => 'Vibración y sonidos';

  @override
  String get haVibrationLight => 'Suave';

  @override
  String get haVibrationMedium => 'Media';

  @override
  String get haVibrationStrong => 'Fuerte';

  @override
  String get settingsMenuHomeAssistant => 'Configuración de Home Assistant';

  @override
  String get settingsMenuHomeAssistantSummary =>
      'Conexión, panel de control, modo kiosko';

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
  String get settingAdaptiveBrightnessTitle => 'Brillo adaptativo';

  @override
  String get settingAdaptiveBrightnessDescription =>
      'Atenúa la pantalla a medida que se oscurece la habitación usando el sensor de luz ambiental.';

  @override
  String get settingAdaptiveMinBrightnessTitle => 'Brillo mínimo';

  @override
  String get settingAdaptiveMinBrightnessDescription =>
      'Brillo de la pantalla en una habitación oscura.';

  @override
  String get settingAdaptiveMaxBrightnessTitle => 'Brillo máximo';

  @override
  String get settingAdaptiveMaxBrightnessDescription =>
      'Brillo de la pantalla en una habitación iluminada.';

  @override
  String get settingAdaptiveDarkLuxTitle => 'Habitación oscura (lx)';

  @override
  String get settingAdaptiveDarkLuxDescription =>
      'Nivel de luz en el que la pantalla alcanza el brillo mínimo. Por debajo, permanece en ese nivel.';

  @override
  String get settingAdaptiveBrightLuxTitle => 'Habitación iluminada (lx)';

  @override
  String get settingAdaptiveBrightLuxDescription =>
      'Nivel de luz en el que la pantalla alcanza el brillo máximo. Por encima, permanece en ese nivel.';

  @override
  String get screenAudioAdaptiveHint =>
      'Ajusta el brillo a la luz de la habitación con el sensor de luz ambiental';

  @override
  String get screenAudioAdaptiveNote =>
      'Nivel en una habitación iluminada. El brillo adaptativo lo reduce a partir de ese valor.';

  @override
  String get screenAudioAdaptiveOwns => 'El brillo adaptativo está activado.';

  @override
  String get screenAudioNoSensor =>
      'Este dispositivo no tiene sensor de luz ambiental.';

  @override
  String get screenAudioAmbientLight => 'Luz ambiental';

  @override
  String get screenAudioAmbientHelp =>
      'Lectura actual del sensor de luz ambiental.';

  @override
  String get screenAudioNoReading => 'Aún no hay lectura';

  @override
  String screenAudioLux(String lux) {
    return '$lux lx';
  }

  @override
  String screenAudioLuxLast(String lux) {
    return '$lux lx (última lectura)';
  }

  @override
  String get screenAudioSetsMaximum =>
      'Ajusta el brillo máximo porque el brillo adaptativo está activado.';

  @override
  String get screenAudioSetsDefault => 'Ajusta el brillo predeterminado.';

  @override
  String get settingAudioMicDeviceTitle => 'Micrófono';

  @override
  String get settingAudioMicDeviceDescription =>
      'Micrófono que se usa para detectar la palabra de activación y capturar las interacciones de voz.';

  @override
  String get settingAudioSpeakerDeviceTitle => 'Altavoz';

  @override
  String get settingAudioSpeakerDeviceDescription =>
      'Salida para los sonidos de Voice Satellite. La reproducción multimedia sigue la ruta del sistema. La cancelación de eco solo funciona si el micrófono y el altavoz pertenecen al mismo dispositivo.';

  @override
  String get screenAudioDevices => 'Dispositivos de audio';

  @override
  String get screenAudioSelectedDevice => 'Dispositivo seleccionado';

  @override
  String screenAudioDisconnected(String name) {
    return '$name (sin conectar)';
  }

  @override
  String get settingMicAudioSourceTitle => 'Modo de captura';

  @override
  String get settingMicAudioSourceDescription =>
      'Comunicación de voz es el único modo con cancelación de eco. Déjalo seleccionado salvo que el micrófono capte un volumen mucho más bajo aquí que en una aplicación de grabación.';

  @override
  String get settingMicEchoCancellationTitle => 'Cancelación de eco';

  @override
  String get settingMicEchoCancellationDescription =>
      'Evita que el micrófono capte el altavoz del kiosko para que la palabra de parada funcione durante la reproducción. Desactívala solo si el micrófono capta un volumen mucho más bajo aquí que en una aplicación de grabación.';

  @override
  String get settingMicChannelTitle => 'Canal del micrófono';

  @override
  String get settingMicChannelDescription =>
      'Los micrófonos multicanal suelen reservar un canal para el reconocimiento de voz. Elegirlo puede mejorar la detección.';

  @override
  String get settingMicAgcTitle => 'Control automático de ganancia';

  @override
  String get settingMicAgcDescription =>
      'Permite que Android ajuste el nivel del micrófono en lugar de usar una ganancia fija. También amplifica el ruido ambiental y en algunos dispositivos no tiene ningún efecto.';

  @override
  String get settingMicNoiseSuppressionTitle => 'Supresión de ruido';

  @override
  String get settingMicNoiseSuppressionDescription =>
      'Reduce el ruido de fondo del micrófono mediante el procesamiento de Android. Puede mejorar o empeorar la detección de la palabra de activación según el dispositivo.';

  @override
  String get settingMicGainDbTitle => 'Ganancia del micrófono';

  @override
  String get settingMicGainDbDescription =>
      'Amplifica o atenúa el micrófono antes de procesar el audio. Busca un nivel cercano a 0.05 en el probador de palabras de activación. Una ganancia excesiva distorsiona la voz y empeora la detección.';

  @override
  String get settingMicCaptureFormatTitle => 'Formato de captura';

  @override
  String get settingMicCaptureFormatDescription =>
      'Elige Estéreo a 48 kHz cuando el micrófono funcione en otras aplicaciones pero no aquí. Algunas tarjetas de sonido solo graban en ese formato y la aplicación lo convierte por su cuenta.';

  @override
  String get screenAudioMicrophoneSettings => 'Configuración del micrófono';

  @override
  String get screenAudioMicrophoneHint =>
      'Modo de captura, canal, ganancia y nivel en tiempo real';

  @override
  String get screenAudioMicrophoneNote =>
      'Ajusta la captura al micrófono y a la habitación. Prueba las palabras de activación y las interacciones de voz después de cambiar estas opciones.';

  @override
  String get screenAudioVoiceCommunication =>
      'Comunicación de voz (predeterminado)';

  @override
  String get screenAudioVoiceRecognition => 'Reconocimiento de voz';

  @override
  String get screenAudioRawMicrophone => 'Micrófono sin procesar';

  @override
  String get screenAudioAutomaticDefault => 'Automático (predeterminado)';

  @override
  String get screenAudioStereo => 'Estéreo a 48 kHz';

  @override
  String get screenAudioDownmix => 'Mezclar canales (predeterminado)';

  @override
  String screenAudioChannel(String channel) {
    return 'Canal $channel';
  }

  @override
  String screenAudioChannelMissing(String channel) {
    return 'Canal $channel (no disponible en este micrófono)';
  }

  @override
  String get screenAudioMicrophoneLevel => 'Nivel del micrófono';

  @override
  String get screenAudioMicrophoneLevelHelp =>
      'Habla desde donde usas el dispositivo. Ajusta la ganancia hasta que la voz normal alcance aproximadamente el final de la zona verde.';

  @override
  String get settingBrowserCutoutModeTitle => 'Área de la cámara frontal';

  @override
  String get settingBrowserCutoutModeDescription =>
      'Qué hacer con el área de la pantalla alrededor de la cámara frontal. Elige Evitar el área de la cámara si esta cubre los botones de la parte superior del panel de control.';

  @override
  String get settingScreenOrientationTitle => 'Orientación de la pantalla';

  @override
  String get settingScreenOrientationDescription =>
      'Fuerza la pantalla a una orientación. Úsalo en un dispositivo sin sensor de rotación o instalado de una forma que el sensor no detecta correctamente.';

  @override
  String get settingKeepScreenOnTitle => 'Mantener la pantalla encendida';

  @override
  String get settingKeepScreenOnDescription =>
      'Evita que el sistema operativo apague la pantalla.';

  @override
  String get settingSetBrightnessOnLaunchTitle =>
      'Establecer el brillo al iniciar';

  @override
  String get settingSetBrightnessOnLaunchDescription =>
      'Aplica el brillo predeterminado cada vez que se inicia la aplicación.';

  @override
  String get settingDefaultBrightnessTitle => 'Brillo predeterminado';

  @override
  String get settingDefaultBrightnessDescription =>
      'Brillo de la pantalla al iniciar la aplicación. Mover el control deslizante lo aplica de inmediato.';

  @override
  String get screenAudioScreen => 'Pantalla';

  @override
  String get screenAudioCutoutAlways => 'Usar el área de la cámara';

  @override
  String get screenAudioCutoutShort => 'Solo en los bordes cortos';

  @override
  String get screenAudioCutoutDefault => 'Predeterminado del sistema';

  @override
  String get screenAudioCutoutNever => 'Evitar el área de la cámara';

  @override
  String get screenAudioAutomatic => 'Automático';

  @override
  String get screenAudioLandscape => 'Horizontal';

  @override
  String get screenAudioReverseLandscape => 'Horizontal invertida';

  @override
  String get screenAudioPortrait => 'Vertical';

  @override
  String get screenAudioReversePortrait => 'Vertical invertida';

  @override
  String get screenAudioPermission => 'Permiso';

  @override
  String get screenAudioBrightnessFallback =>
      'El brillo usa un método alternativo';

  @override
  String get screenAudioBrightnessPermission =>
      'Sin el permiso «Modificar ajustes del sistema», los cambios de brillo solo atenúan esta aplicación en lugar de ajustar el brillo real de la pantalla.';

  @override
  String get screenAudioBrightnessPermissionRemote =>
      'Sin el permiso «Modificar ajustes del sistema», los cambios de brillo solo atenúan la aplicación en lugar de ajustar el brillo real de la pantalla.';

  @override
  String get screenAudioAlwaysOn => 'Pantalla siempre activa';

  @override
  String get screenAudioAlwaysOnClock =>
      'Este dispositivo mantiene un reloj tenue encendido';

  @override
  String get screenAudioAlwaysOnHelp =>
      'Apagar la pantalla pone el dispositivo en reposo, pero la función de pantalla siempre activa vuelve a encender la pantalla de bloqueo y ninguna aplicación puede impedirlo. Desactiva «Mostrar siempre la hora y la información» en los ajustes de Android, en Pantalla, junto a las opciones de bloqueo. Algunas ROM llaman a esta función Pantalla siempre activa. La entidad de pantalla de Home Assistant seguirá sin estar disponible hasta que lo hagas.';

  @override
  String get settingMediaVolumeTitle => 'Volumen multimedia';

  @override
  String get settingMediaVolumeDescription =>
      'La música y los videos se reproducen a esta proporción del volumen principal. El volumen del reproductor Sendspin en Music Assistant mueve este control.';

  @override
  String get settingAssistantVolumeTitle => 'Volumen del asistente';

  @override
  String get settingAssistantVolumeDescription =>
      'Las respuestas de voz y los sonidos se reproducen a esta proporción del volumen principal, independientemente del volumen multimedia.';

  @override
  String get settingAssistantFullVolumeRangeTitle =>
      'Rango completo del volumen del asistente';

  @override
  String get settingAssistantFullVolumeRangeDescription =>
      'Establece el volumen de llamadas del altavoz integrado al 100 % cuando se inicia el audio del asistente por primera vez. El volumen principal y el del asistente siguen aplicándose. Otras aplicaciones comparten este volumen de llamadas, que no se restaura después.';

  @override
  String get settingIntercomVolumeTitle => 'Volumen del intercomunicador';

  @override
  String get settingIntercomVolumeDescription =>
      'La voz y los anuncios del otro kiosko se reproducen a esta proporción del volumen principal.';

  @override
  String get screenAudioVolume => 'Volumen de audio';

  @override
  String get screenAudioMasterVolume => 'Volumen principal';

  @override
  String get screenAudioMasterHelp =>
      'Volumen del dispositivo. Los volúmenes multimedia, del intercomunicador y del asistente se ajustan en proporción a este.';

  @override
  String get settingScreensaverBlackHideExtrasTitle =>
      'Ocultar todos los elementos adicionales';

  @override
  String get settingScreensaverBlackHideExtrasDescription =>
      'Mantiene la pantalla completamente negra, sin reloj pequeño, entidades de De un vistazo ni otros elementos superpuestos.';

  @override
  String get screensaverBlackSection => 'Protector de pantalla: Negro';

  @override
  String get settingScreensaverClockStyleTitle => 'Estilo';

  @override
  String get settingScreensaverClockStyleDescription =>
      'Cómo se muestra el reloj.';

  @override
  String get settingScreensaverClockFontTitle => 'Tipo de letra';

  @override
  String get settingScreensaverClockFontDescription =>
      'Tipo de letra del reloj.';

  @override
  String get settingScreensaverClockFontWeightTitle => 'Grosor de la letra';

  @override
  String get settingScreensaverClockFontWeightDescription =>
      'Grosor de los dígitos del reloj. Predeterminado usa el grosor propio de cada estilo.';

  @override
  String get settingScreensaverClock24hTitle => 'Reloj de 24 horas';

  @override
  String get settingScreensaverClock24hDescription =>
      'Muestra la hora en formato de 24 horas en lugar de AM/PM.';

  @override
  String get settingScreensaverClockSecondsTitle => 'Mostrar segundos';

  @override
  String get settingScreensaverClockSecondsDescription =>
      'Incluye los segundos en el reloj.';

  @override
  String get settingScreensaverClockDateTitle => 'Mostrar fecha';

  @override
  String get settingScreensaverClockDateDescription =>
      'Muestra el día de la semana y la fecha debajo del reloj.';

  @override
  String get settingScreensaverClockScaleTitle => 'Tamaño del reloj';

  @override
  String get settingScreensaverClockScaleDescription =>
      'Ajusta el tamaño del reloj del 50 al 300 por ciento para esta pantalla.';

  @override
  String get settingScreensaverClockColorTitle => 'Color del reloj';

  @override
  String get settingScreensaverClockColorDescription =>
      'Color del texto del reloj.';

  @override
  String get settingScreensaverClockBgColorTitle => 'Color de fondo';

  @override
  String get settingScreensaverClockBgColorDescription =>
      'Color detrás del reloj.';

  @override
  String get settingScreensaverClockBackgroundTitle => 'Foto de fondo';

  @override
  String get settingScreensaverClockBackgroundDescription =>
      'Muestra una foto detrás del reloj en lugar de un color sólido. Puede ser la ruta de una imagen en el dispositivo o una URL desde la que el dispositivo descarga la imagen.';

  @override
  String get settingScreensaverClockBackgroundRefreshTitle =>
      'Actualizar el fondo desde la URL';

  @override
  String get settingScreensaverClockBackgroundRefreshDescription =>
      'Minutos entre descargas de una imagen de fondo desde una URL. Con 0, solo se descarga al guardar esta opción.';

  @override
  String get settingScreensaverFlipDigitColorTitle => 'Color de los dígitos';

  @override
  String get settingScreensaverFlipDigitColorDescription =>
      'Color de los dígitos del reloj de láminas.';

  @override
  String get settingScreensaverFlipBgColorTitle => 'Color de las láminas';

  @override
  String get settingScreensaverFlipBgColorDescription =>
      'Color de las láminas del reloj.';

  @override
  String get settingScreensaverFlipBackdropColorTitle => 'Color de fondo';

  @override
  String get settingScreensaverFlipBackdropColorDescription =>
      'Color detrás de las láminas.';

  @override
  String get settingScreensaverRollerDigitColorTitle => 'Color de los dígitos';

  @override
  String get settingScreensaverRollerDigitColorDescription =>
      'Color de los dígitos del reloj de rodillos.';

  @override
  String get settingScreensaverRollerBgColorTitle => 'Color de fondo';

  @override
  String get settingScreensaverRollerBgColorDescription =>
      'Color detrás de los dígitos.';

  @override
  String get settingScreensaverClockNightTitle => 'Modo nocturno';

  @override
  String get settingScreensaverClockNightDescription =>
      'Cambia los colores del reloj cuando la habitación está oscura.';

  @override
  String get settingScreensaverClockNightLuxTitle => 'Nivel de luz';

  @override
  String get settingScreensaverClockNightLuxDescription =>
      'Con este nivel de luz o uno inferior, el reloj usa el color nocturno.';

  @override
  String get settingScreensaverClockNightColorTitle => 'Color nocturno';

  @override
  String get settingScreensaverClockNightColorDescription =>
      'Color del reloj y los widgets en la oscuridad.';

  @override
  String get settingScreensaverClockNightBgColorTitle => 'Fondo nocturno';

  @override
  String get settingScreensaverClockNightBgColorDescription =>
      'Color detrás del reloj en la oscuridad.';

  @override
  String get settingScreensaverClockNightHideBackgroundTitle =>
      'Ocultar la foto de fondo';

  @override
  String get settingScreensaverClockNightHideBackgroundDescription =>
      'Usa el color de fondo nocturno en lugar de la foto mientras está activo el modo nocturno.';

  @override
  String get settingScreensaverClockNightCardColorTitle =>
      'Color nocturno de las láminas';

  @override
  String get settingScreensaverClockNightCardColorDescription =>
      'Color de las láminas del reloj en la oscuridad.';

  @override
  String get screensaverClockSection => 'Protector de pantalla: Reloj';

  @override
  String get screensaverClockHint =>
      'Estilo, tipo de letra, tamaño, colores, modo nocturno y foto de fondo';

  @override
  String get screensaverStyleDigital => 'Reloj digital';

  @override
  String get screensaverStyleFlip => 'Reloj de láminas';

  @override
  String get screensaverStyleRoller => 'Reloj de rodillos';

  @override
  String get screensaverFontDefault => 'Predeterminado';

  @override
  String get screensaverFontLight => 'Fino';

  @override
  String get screensaverFontRegular => 'Normal';

  @override
  String get screensaverFontMedium => 'Medio';

  @override
  String get screensaverFontBold => 'Negrita';

  @override
  String get screensaverFontBlack => 'Muy grueso';

  @override
  String get screensaverNoPhoto => 'No se ha seleccionado ninguna foto';

  @override
  String get screensaverBackgroundHint =>
      'Ruta de una imagen en el dispositivo o URL de una imagen';

  @override
  String get screensaverImageUrlError =>
      'Introduce la URL completa de una imagen';

  @override
  String get screensaverRefreshError =>
      'Introduce minutos enteros entre 0 y 1440';

  @override
  String screensaverMaxCharacters(String count) {
    return 'Usa como máximo $count caracteres';
  }

  @override
  String get settingScreensaverEnabledTitle => 'Protector de pantalla';

  @override
  String get settingScreensaverEnabledDescription =>
      'Atenúa o deja en negro la pantalla tras un periodo de inactividad.';

  @override
  String get settingScreensaverTimeoutSecondsTitle =>
      'Tiempo de inactividad (segundos)';

  @override
  String get settingScreensaverTimeoutSecondsDescription =>
      'Periodo de inactividad antes de que se active el protector de pantalla.';

  @override
  String get settingScreensaverModeTitle => 'Modo del protector de pantalla';

  @override
  String get settingScreensaverModeDescription =>
      'Qué muestra el protector de pantalla tras el tiempo de inactividad. Atenuar solo reduce la iluminación y mantiene visible el panel de control.';

  @override
  String get settingScreensaverPixelShiftTitle => 'Desplazamiento de píxeles';

  @override
  String get settingScreensaverPixelShiftDescription =>
      'Mueve ligeramente la imagen cada minuto para proteger las pantallas OLED. No se aplica al protector de pantalla Negro, cuyos píxeles ya están apagados.';

  @override
  String get settingScreensaverMenuTitle => 'Mostrar en el menú del kiosko';

  @override
  String get settingScreensaverMenuDescription =>
      'Añade la opción Iniciar protector de pantalla al menú del kiosko.';

  @override
  String get settingScreensaverDimLevelTitle => 'Nivel de atenuación';

  @override
  String get settingScreensaverDimLevelDescription =>
      'Brillo de la pantalla mientras el protector de pantalla la atenúa.';

  @override
  String get settingScreensaverBrightnessEnabledTitle =>
      'Brillo del protector de pantalla';

  @override
  String get settingScreensaverBrightnessEnabledDescription =>
      'Usa un brillo diferente mientras se muestra el protector de pantalla.';

  @override
  String get settingScreensaverBrightnessLevelTitle => 'Nivel de brillo';

  @override
  String get settingScreensaverBrightnessLevelDescription =>
      'Se aplica a todos los modos excepto Atenuar y Negro.';

  @override
  String get settingScreensaverNotificationBrightnessTitle =>
      'Aumentar el brillo para las notificaciones';

  @override
  String get settingScreensaverNotificationBrightnessDescription =>
      'Reduce la atenuación del protector de pantalla mientras se muestra una notificación.';

  @override
  String get settingScreensaverScreenOffMinutesTitle =>
      'Apagar la pantalla después de';

  @override
  String get settingScreensaverScreenOffMinutesDescription =>
      'Apaga la pantalla cuando el protector de pantalla lleva activo el tiempo indicado. Con 0, la pantalla permanece encendida indefinidamente. Requiere permiso de administrador del dispositivo.';

  @override
  String get settingScreensaverScreenOffWakeToScreensaverTitle =>
      'Volver al protector de pantalla al despertar';

  @override
  String get settingScreensaverScreenOffWakeToScreensaverDescription =>
      'Tras apagarse la pantalla, la detección de movimiento, rostros, proximidad o personas muestra el protector de pantalla en lugar del panel de control y reinicia el tiempo para apagar la pantalla. Tocar la pantalla sigue abriendo el panel de control.';

  @override
  String get screensaverModeDim => 'Atenuar';

  @override
  String get screensaverModeBlack => 'Negro';

  @override
  String get screensaverModeClock => 'Reloj';

  @override
  String get screensaverModeMedia => 'Contenido multimedia de Home Assistant';

  @override
  String get screensaverModeLocal => 'Contenido multimedia local';

  @override
  String get screensaverModeGallery => 'Galería de fotos';

  @override
  String get screensaverModeImmich => 'Immich';

  @override
  String get screensaverModeWebsite => 'Sitio web';

  @override
  String get screensaverModeCamera => 'Transmisiones de cámara';

  @override
  String get screensaverDimSection => 'Protector de pantalla: Atenuar';

  @override
  String get screensaverWarningTitle => 'ADVERTENCIA: Lee antes de continuar';

  @override
  String get screensaverScreenOffProceed => 'Apagar la pantalla de todos modos';

  @override
  String get screensaverAdminMissing =>
      'No se ha concedido el permiso, por lo que la pantalla no puede apagarse.';

  @override
  String get screensaverAdminMissingRemote =>
      'Falta el permiso de administrador del dispositivo';

  @override
  String get screensaverAdminMissingRemoteHelp =>
      'Sin este permiso no se puede apagar la pantalla. El diálogo para concederlo aparece en la tableta.';

  @override
  String get screensaverDimWarning =>
      'ADVERTENCIA: Atenuar mantiene visible el panel de control, por lo que no se aplica la optimización «Pausar el panel de control durante el protector de pantalla». El panel de control sigue usando CPU, GPU y batería.';

  @override
  String get screensaverUnavailablePlugin =>
      'Protector de pantalla de un plugin no disponible';

  @override
  String get screensaverScreenOffWarning =>
      'Cuando la pantalla se apaga por completo, la administración de energía de la tableta toma el control. Muchos modelos de Android presentan problemas en ese estado: el Wi-Fi se suspende o se desconecta, las entidades de Home Assistant dejan de estar disponibles, se puede perder el acceso a la cámara y algunos modelos cierran las aplicaciones en segundo plano. El comportamiento depende del fabricante.\n\nLa alternativa fiable es usar el protector de pantalla Negro y dejar esta opción en 0. La pantalla se ve igual de oscura y la aplicación mantiene el control.';

  @override
  String get settingScreensaverImmichUrlTitle => 'Dirección del servidor';

  @override
  String get settingScreensaverImmichUrlDescription =>
      'Dirección del servidor de Immich, incluido su puerto.';

  @override
  String get settingScreensaverImmichApiKeyTitle => 'Clave de API';

  @override
  String get settingScreensaverImmichApiKeyDescription =>
      'Se crea en Immich, en Ajustes de la cuenta → Claves de API.';

  @override
  String get screensaverMediaImmichPage => 'Protector de pantalla: Immich';

  @override
  String get screensaverMediaImmichHint =>
      'Servidor, contenido multimedia, presentación, metadatos y filtros';

  @override
  String get screensaverMediaServerConnection => 'Conexión con el servidor';

  @override
  String get screensaverMediaValidateFailedLog =>
      'La validación falló. Consulta en el registro de la aplicación qué llamada falló.';

  @override
  String get screensaverMediaValidateFailed => 'La validación falló.';

  @override
  String get screensaverMediaNoAnswer => 'El dispositivo no respondió.';

  @override
  String get screensaverMediaAddressFirst =>
      'Introduce primero la dirección del servidor.';

  @override
  String get screensaverMediaKeyFirst => 'Introduce primero una clave de API.';

  @override
  String get screensaverMediaBadAddress =>
      'La dirección del servidor no es una URL válida.';

  @override
  String get screensaverMediaKeyRejected => 'Se rechazó la clave de API.';

  @override
  String screensaverMediaScopeMissing(String scope) {
    return 'A la clave de API le falta el permiso $scope.';
  }

  @override
  String screensaverMediaPermissionMissing(String error) {
    return 'A la clave de API le falta un permiso: $error';
  }

  @override
  String screensaverMediaServerError(String status, String error) {
    return 'El servidor respondió $status: $error';
  }

  @override
  String screensaverMediaUnreachable(String url) {
    return 'No se pudo conectar con $url.';
  }

  @override
  String screensaverMediaTalkError(String error) {
    return 'No se pudo comunicar con el servidor: $error';
  }

  @override
  String get settingScreensaverImmichPeopleTitle => 'Personas';

  @override
  String get settingScreensaverImmichPeopleDescription =>
      'Muestra solo contenido en el que aparezca alguna de estas personas.';

  @override
  String get settingScreensaverImmichExcludePeopleTitle => 'Excluir personas';

  @override
  String get settingScreensaverImmichExcludePeopleDescription =>
      'Omite el contenido en el que aparezca alguna de estas personas.';

  @override
  String get settingScreensaverImmichTagsTitle => 'Etiquetas';

  @override
  String get settingScreensaverImmichTagsDescription =>
      'Muestra solo contenido con alguna de estas etiquetas.';

  @override
  String get settingScreensaverImmichFavoritesOnlyTitle => 'Solo favoritos';

  @override
  String get settingScreensaverImmichFavoritesOnlyDescription =>
      'Muestra solo el contenido marcado como favorito.';

  @override
  String get settingScreensaverImmichTakenWithinTitle => 'Fecha de captura';

  @override
  String get settingScreensaverImmichTakenWithinDescription =>
      'Muestra solo el contenido capturado durante este periodo.';

  @override
  String get settingScreensaverImmichTakenFromTitle => 'Desde';

  @override
  String get settingScreensaverImmichTakenFromDescription =>
      'Omite el contenido capturado antes de esta fecha.';

  @override
  String get settingScreensaverImmichTakenToTitle => 'Hasta';

  @override
  String get settingScreensaverImmichTakenToDescription =>
      'Omite el contenido capturado después de esta fecha. Incluye el día indicado.';

  @override
  String get screensaverMediaFilters => 'Filtros';

  @override
  String get screensaverMediaAnyone => 'Cualquier persona';

  @override
  String get screensaverMediaAnyoneDevice => 'Cualquier persona.';

  @override
  String get screensaverMediaNoOne => 'Ninguna persona';

  @override
  String get screensaverMediaNoOneDevice => 'Ninguna persona.';

  @override
  String get screensaverMediaAny => 'Cualquiera';

  @override
  String get screensaverMediaAnyDevice => 'Cualquiera.';

  @override
  String get screensaverMediaNoPeople =>
      'Aún no hay personas con nombre. Asígnales un nombre primero en Immich.';

  @override
  String get screensaverMediaNoTags =>
      'Aún no hay etiquetas. Créalas primero en Immich.';

  @override
  String get screensaverMediaPeopleFailed =>
      'No se pudieron listar las personas';

  @override
  String get screensaverMediaTagsFailed =>
      'No se pudieron listar las etiquetas';

  @override
  String get screensaverMediaHidden => 'Oculto';

  @override
  String get screensaverMediaAnyTime => 'Cualquier fecha';

  @override
  String get screensaverMediaPastMonth => 'Último mes';

  @override
  String get screensaverMediaPast3Months => 'Últimos 3 meses';

  @override
  String get screensaverMediaPastYear => 'Último año';

  @override
  String get screensaverMediaPast2Years => 'Últimos 2 años';

  @override
  String get screensaverMediaPast5Years => 'Últimos 5 años';

  @override
  String get screensaverMediaPast10Years => 'Últimos 10 años';

  @override
  String get screensaverMediaSince => 'Desde una fecha';

  @override
  String get screensaverMediaTimeframe => 'Intervalo de fechas';

  @override
  String get screensaverMediaToday => 'Hoy';

  @override
  String get screensaverMediaDateFormat => 'Usa el formato YYYY-MM-DD.';

  @override
  String get screensaverMediaNotDate => 'La fecha no es válida.';

  @override
  String get settingScreensaverImmichMetadataTitle => 'Mostrar metadatos';

  @override
  String get settingScreensaverImmichMetadataDescription =>
      'Muestra el álbum, la fecha, la cámara y la ubicación sobre el contenido multimedia.';

  @override
  String get settingScreensaverImmichMetadataAlbumTitle => 'Nombre del álbum';

  @override
  String get settingScreensaverImmichMetadataAlbumDescription =>
      'Muestra de qué álbum proviene la foto.';

  @override
  String get settingScreensaverImmichMetadataDateTitle => 'Fecha de captura';

  @override
  String get settingScreensaverImmichMetadataDateDescription =>
      'Muestra cuándo se tomó la foto.';

  @override
  String get settingScreensaverImmichMetadataCameraTitle =>
      'Detalles de la cámara';

  @override
  String get settingScreensaverImmichMetadataCameraDescription =>
      'Muestra la distancia focal, la apertura y el ISO.';

  @override
  String get settingScreensaverImmichMetadataLocationTitle => 'Ubicación';

  @override
  String get settingScreensaverImmichMetadataLocationDescription =>
      'Muestra dónde se tomó la foto.';

  @override
  String get settingScreensaverImmichMetadataPositionTitle =>
      'Posición de los metadatos';

  @override
  String get settingScreensaverImmichMetadataPositionDescription =>
      'Esquina en la que se muestran los detalles.';

  @override
  String get settingScreensaverImmichMetadataTextShadowTitle =>
      'Sombra del texto';

  @override
  String get settingScreensaverImmichMetadataTextShadowDescription =>
      'Añade una sombra al texto de los metadatos para facilitar su lectura sobre las fotos.';

  @override
  String get settingScreensaverImmichMetadataScaleTitle => 'Tamaño del texto';

  @override
  String get settingScreensaverImmichMetadataScaleDescription =>
      'Ajusta el tamaño de los detalles de la foto a la pantalla.';

  @override
  String get settingScreensaverImmichVignetteStrengthTitle =>
      'Intensidad del sombreado';

  @override
  String get settingScreensaverImmichVignetteStrengthDescription =>
      'Oscuridad del sombreado detrás de los detalles para facilitar la lectura sobre fotos claras. Con 0, se desactiva.';

  @override
  String get screensaverMediaMetadata => 'Metadatos';

  @override
  String get screensaverMediaTopLeft => 'Arriba a la izquierda';

  @override
  String get screensaverMediaTopRight => 'Arriba a la derecha';

  @override
  String get screensaverMediaBottomLeft => 'Abajo a la izquierda';

  @override
  String get screensaverMediaBottomRight => 'Abajo a la derecha';

  @override
  String get settingScreensaverImmichIntervalTitle => 'Segundos por imagen';

  @override
  String get settingScreensaverImmichIntervalDescription =>
      'Tiempo que se muestra cada imagen antes de pasar a la siguiente. Los videos se reproducen completos.';

  @override
  String get settingScreensaverImmichShuffleTitle => 'Orden aleatorio';

  @override
  String get settingScreensaverImmichShuffleDescription =>
      'Recorre el contenido multimedia en orden aleatorio.';

  @override
  String get settingScreensaverImmichTransitionTitle => 'Transición';

  @override
  String get settingScreensaverImmichTransitionDescription =>
      'Cómo se pasa de un elemento al siguiente.';

  @override
  String get settingScreensaverImmichFillTitle => 'Llenar la pantalla';

  @override
  String get settingScreensaverImmichFillDescription =>
      'Desactivado mantiene la foto completa entre franjas negras. Inteligente amplía las fotos de proporciones similares a la pantalla y muestra las demás sobre un fondo desenfocado. Siempre amplía todas las fotos y recorta lo que no cabe.';

  @override
  String get settingScreensaverImmichPairPortraitTitle =>
      'Combinar fotos verticales';

  @override
  String get settingScreensaverImmichPairPortraitDescription =>
      'Muestra dos fotos verticales una junto a la otra para llenar la pantalla.';

  @override
  String get settingScreensaverImmichEdgeTapsTitle =>
      'Tocar los bordes para cambiar de imagen';

  @override
  String get settingScreensaverImmichEdgeTapsDescription =>
      'Tocar el quinto izquierdo o derecho de la pantalla muestra la imagen anterior o siguiente en lugar de cerrar el protector de pantalla.';

  @override
  String get screensaverMediaSlideshow => 'Presentación';

  @override
  String get settingScreensaverImmichAlbumTitle => 'Origen multimedia';

  @override
  String get settingScreensaverImmichAlbumDescription =>
      'Toda la biblioteca o los álbumes que elijas.';

  @override
  String get settingScreensaverImmichPhotosOnlyTitle => 'Solo fotos';

  @override
  String get settingScreensaverImmichPhotosOnlyDescription =>
      'Omite los videos de la presentación.';

  @override
  String get settingScreensaverImmichCacheTitle =>
      'Guardar contenido en caché local';

  @override
  String get settingScreensaverImmichCacheDescription =>
      'Guarda copias en el dispositivo para que las imágenes carguen al instante.';

  @override
  String get settingScreensaverImmichCacheMaxTitle =>
      'Tamaño de la caché (elementos)';

  @override
  String get settingScreensaverImmichCacheMaxDescription =>
      'Elimina los elementos más antiguos cuando se llena la caché.';

  @override
  String get screensaverMediaAll => 'Todo el contenido';

  @override
  String get screensaverMediaAllDevice => 'Todo el contenido.';

  @override
  String get screensaverMediaNoAlbums =>
      'Aún no hay álbumes. Crea uno primero en Immich.';

  @override
  String get screensaverMediaAlbumsFailed =>
      'No se pudieron listar los álbumes';

  @override
  String screensaverMediaListError(String error) {
    return 'No se pudieron listar los elementos: $error';
  }

  @override
  String get screensaverMediaListingFailed =>
      'No se pudieron listar los elementos';

  @override
  String screensaverMediaItems(String count) {
    return '$count elementos';
  }

  @override
  String screensaverMediaCached(String count, String size) {
    return '$count en caché, $size';
  }

  @override
  String get settingScreensaverCameraViewsTitle => 'Vistas de cámaras';

  @override
  String get settingScreensaverCameraViewsDescription =>
      'Vistas de cámaras que muestra el protector de pantalla, en este orden.';

  @override
  String get settingScreensaverCameraViewSecondsTitle =>
      'Segundos por vista de cámaras';

  @override
  String get settingScreensaverCameraViewSecondsDescription =>
      'Tiempo que permanece cada vista en pantalla antes de pasar a la siguiente. Si solo se elige una vista, no hay rotación.';

  @override
  String get settingScreensaverCameraMuteTitle => 'Silenciar todas las vistas';

  @override
  String get settingScreensaverCameraMuteDescription =>
      'Mantiene todas las vistas en silencio, incluso las de una sola cámara.';

  @override
  String get screensaverMediaCameraPage =>
      'Protector de pantalla: Transmisiones de cámara';

  @override
  String get screensaverMediaCameraHint =>
      'Vistas que se muestran, segundos por vista y sonido';

  @override
  String get screensaverMediaNoCameras =>
      'Ninguna vista tiene cámaras todavía. Añade una en Transmisiones de cámara.';

  @override
  String get screensaverMediaNoCamerasRemote =>
      'Ninguna vista tiene cámaras todavía';

  @override
  String get screensaverMediaAddCameras =>
      'Añade una en Transmisiones de cámara.';

  @override
  String get screensaverMediaNoViews =>
      'Aún no hay vistas seleccionadas. Elige las vistas que recorre el protector de pantalla.';

  @override
  String get screensaverMediaRotation =>
      'En la rotación (arrastra para reordenar)';

  @override
  String get screensaverMediaAvailable => 'Disponibles';

  @override
  String screensaverMediaOneCamera(String count) {
    return '$count cámara';
  }

  @override
  String screensaverMediaCameras(String count) {
    return '$count cámaras';
  }

  @override
  String screensaverMediaPosition(String index, String cameras) {
    return 'Posición $index · $cameras';
  }

  @override
  String get screensaverMediaTransitionNone => 'Ninguna';

  @override
  String get screensaverMediaTransitionFade => 'Fundido cruzado';

  @override
  String get screensaverMediaTransitionSlide => 'Deslizamiento';

  @override
  String get screensaverMediaTransitionZoom => 'Zoom';

  @override
  String get screensaverMediaTransitionKenBurns => 'Ken Burns';

  @override
  String get screensaverMediaTransitionRandom => 'Aleatoria';

  @override
  String get screensaverMediaFillOff => 'Desactivado';

  @override
  String get screensaverMediaFillSmart => 'Inteligente';

  @override
  String get screensaverMediaFillAlways => 'Siempre';

  @override
  String get settingScreensaverGalleryItemsTitle => 'Fotos';

  @override
  String get settingScreensaverGalleryItemsDescription =>
      'Fotos y videos que recorre este protector de pantalla. Se eligen desde la galería del dispositivo. Volver a elegir reemplaza la selección.';

  @override
  String get settingScreensaverGalleryIntervalTitle => 'Segundos por foto';

  @override
  String get settingScreensaverGalleryIntervalDescription =>
      'Tiempo que se muestra cada foto antes de pasar a la siguiente. Los videos se reproducen completos.';

  @override
  String get settingScreensaverGalleryShuffleTitle => 'Orden aleatorio';

  @override
  String get settingScreensaverGalleryShuffleDescription =>
      'Recorre la selección en orden aleatorio.';

  @override
  String get settingScreensaverGalleryTransitionTitle => 'Transición';

  @override
  String get settingScreensaverGalleryTransitionDescription =>
      'Cómo se pasa de una foto a la siguiente.';

  @override
  String get settingScreensaverGalleryFillTitle => 'Llenar la pantalla';

  @override
  String get settingScreensaverGalleryFillDescription =>
      'Desactivado mantiene la foto completa entre franjas negras. Inteligente amplía las fotos de proporciones similares a la pantalla y muestra las demás sobre un fondo desenfocado. Siempre amplía todas las fotos y recorta lo que no cabe.';

  @override
  String get settingScreensaverGalleryEdgeTapsTitle =>
      'Tocar los bordes para cambiar de imagen';

  @override
  String get settingScreensaverGalleryEdgeTapsDescription =>
      'Tocar el quinto izquierdo o derecho de la pantalla muestra la imagen anterior o siguiente en lugar de cerrar el protector de pantalla.';

  @override
  String get screensaverMediaGalleryPage =>
      'Protector de pantalla: Galería de fotos';

  @override
  String get screensaverMediaGalleryHint =>
      'Fotos, duración, orden aleatorio y transición';

  @override
  String get screensaverMediaLoadingPhotos => 'Cargando fotos...';

  @override
  String screensaverMediaCopying(String index, String total) {
    return 'Copiando foto $index de $total...';
  }

  @override
  String get screensaverMediaCopyFailed => 'No se pudieron copiar las fotos';

  @override
  String get screensaverMediaSmallerSelection =>
      'Prueba con una selección más pequeña.';

  @override
  String get screensaverMediaNoPhotos => 'No se han seleccionado fotos';

  @override
  String screensaverMediaSelected(String count) {
    return '$count seleccionados';
  }

  @override
  String get screensaverMediaPickOnDevice =>
      'No hay elementos seleccionados. Elígelos en el dispositivo.';

  @override
  String get settingScreensaverMediaIdTitle => 'Origen multimedia';

  @override
  String get settingScreensaverMediaIdDescription =>
      'Elemento multimedia, carpeta o cámara de Home Assistant. Usa Examinar para elegir uno.';

  @override
  String get settingScreensaverMediaIntervalTitle => 'Segundos por imagen';

  @override
  String get settingScreensaverMediaIntervalDescription =>
      'Tiempo que se muestra cada imagen antes de pasar a la siguiente. Los videos se reproducen completos.';

  @override
  String get settingScreensaverMediaShuffleTitle => 'Orden aleatorio';

  @override
  String get settingScreensaverMediaShuffleDescription =>
      'Reproduce una carpeta en orden aleatorio.';

  @override
  String get settingScreensaverMediaRecursiveTitle => 'Incluir subcarpetas';

  @override
  String get settingScreensaverMediaRecursiveDescription =>
      'Incluye las subcarpetas de la carpeta elegida.';

  @override
  String get settingScreensaverMediaTransitionTitle => 'Transición';

  @override
  String get settingScreensaverMediaTransitionDescription =>
      'Cómo se pasa de un elemento al siguiente.';

  @override
  String get settingScreensaverMediaFillTitle => 'Llenar la pantalla';

  @override
  String get settingScreensaverMediaFillDescription =>
      'Desactivado mantiene la foto completa entre franjas negras. Inteligente amplía las fotos de proporciones similares a la pantalla y muestra las demás sobre un fondo desenfocado. Siempre amplía todas las fotos y recorta lo que no cabe.';

  @override
  String get settingScreensaverMediaEdgeTapsTitle =>
      'Tocar los bordes para cambiar de imagen';

  @override
  String get settingScreensaverMediaEdgeTapsDescription =>
      'Tocar el quinto izquierdo o derecho de la pantalla muestra la imagen anterior o siguiente en lugar de cerrar el protector de pantalla.';

  @override
  String get screensaverMediaHaPage =>
      'Protector de pantalla: Contenido multimedia de Home Assistant';

  @override
  String get screensaverMediaHaHint =>
      'Origen multimedia, duración, orden aleatorio y ajuste a la pantalla';

  @override
  String get screensaverMediaChoose => 'Elegir contenido multimedia';

  @override
  String get screensaverMediaRoot => 'Contenido multimedia';

  @override
  String get screensaverMediaHaUnavailable =>
      'No se pudo conectar con Home Assistant o falta el token.';

  @override
  String get screensaverMediaEmpty => 'No hay elementos aquí.';

  @override
  String get screensaverMediaUseFolder => 'Usar esta carpeta';

  @override
  String get screensaverMediaFolder => 'carpeta';

  @override
  String get screensaverMediaCamera => 'cámara';

  @override
  String get screensaverMediaItem => 'elemento';

  @override
  String get screensaverMediaBrowseFailed => 'No se pudo explorar el contenido';

  @override
  String screensaverMediaBrowseError(String error) {
    return 'No se pudo explorar el contenido: $error';
  }

  @override
  String get screensaverMediaNotSet => 'Sin configurar';

  @override
  String get settingScreensaverLocalFolderTitle => 'Carpeta local';

  @override
  String get settingScreensaverLocalFolderDescription =>
      'Carpeta de este dispositivo cuyas fotos y videos recorre el protector de pantalla. Se elige en el dispositivo. También se puede escribir la ruta desde la administración remota.';

  @override
  String get settingScreensaverLocalIntervalTitle => 'Segundos por foto';

  @override
  String get settingScreensaverLocalIntervalDescription =>
      'Tiempo que se muestra cada foto antes de pasar a la siguiente. Los videos se reproducen completos.';

  @override
  String get settingScreensaverLocalShuffleTitle => 'Orden aleatorio';

  @override
  String get settingScreensaverLocalShuffleDescription =>
      'Recorre la carpeta en orden aleatorio en lugar de ordenar por nombre.';

  @override
  String get settingScreensaverLocalRecursiveTitle => 'Incluir subcarpetas';

  @override
  String get settingScreensaverLocalRecursiveDescription =>
      'Incluye también las fotos y los videos de las subcarpetas.';

  @override
  String get settingScreensaverLocalTransitionTitle => 'Transición';

  @override
  String get settingScreensaverLocalTransitionDescription =>
      'Cómo se pasa de una foto a la siguiente.';

  @override
  String get settingScreensaverLocalFillTitle => 'Llenar la pantalla';

  @override
  String get settingScreensaverLocalFillDescription =>
      'Desactivado mantiene la foto completa entre franjas negras. Inteligente amplía las fotos de proporciones similares a la pantalla y muestra las demás sobre un fondo desenfocado. Siempre amplía todas las fotos y recorta lo que no cabe.';

  @override
  String get settingScreensaverLocalEdgeTapsTitle =>
      'Tocar los bordes para cambiar de imagen';

  @override
  String get settingScreensaverLocalEdgeTapsDescription =>
      'Tocar el quinto izquierdo o derecho de la pantalla muestra la imagen anterior o siguiente en lugar de cerrar el protector de pantalla.';

  @override
  String get screensaverMediaLocalPage =>
      'Protector de pantalla: Contenido multimedia local';

  @override
  String get screensaverMediaLocalHint =>
      'Carpeta, duración, orden aleatorio y transición';

  @override
  String get settingScreensaverScheduleEnabledTitle =>
      'Activar los protectores de pantalla programados';

  @override
  String get settingScreensaverScheduleEnabledDescription =>
      'Cambia a otro protector de pantalla a determinadas horas del día.';

  @override
  String get settingScreensaverScheduleTitle => 'Horas';

  @override
  String get settingScreensaverScheduleDescription =>
      'Cada hora indica cuándo empieza a usarse ese protector de pantalla.';

  @override
  String get screensaverScheduleSection =>
      'Protectores de pantalla programados';

  @override
  String get screensaverTime => 'Hora';

  @override
  String get screensaverAddTime => 'Añadir hora';

  @override
  String get screensaverRemoveTime => 'Eliminar hora';

  @override
  String get screensaverNoTimes => 'Aún no hay horas programadas';

  @override
  String get screensaverTimeHelp =>
      'Protector de pantalla que se usa a partir de esa hora.';

  @override
  String get screensaverPickTime => 'Elige una hora.';

  @override
  String get screensaverDefault => 'Predeterminado';

  @override
  String get screensaverOn => 'Activado';

  @override
  String get screensaverOff => 'Desactivado';

  @override
  String get screensaverBrightness => 'Brillo';

  @override
  String get screensaverBrightnessFollow =>
      'Sigue la opción Brillo del protector de pantalla.';

  @override
  String get screensaverBrightnessExceptBlack =>
      'Se aplica a todos los modos excepto Negro.';

  @override
  String get screensaverScreenOffFollow =>
      'Sigue la opción Apagar la pantalla después de.';

  @override
  String get screensaverScreenOnHours =>
      'Mantiene la pantalla encendida durante estas horas.';

  @override
  String get screensaverScreenOffHelp =>
      'Apaga la pantalla cuando el protector de pantalla lleva activo este tiempo. Requiere permiso de administrador del dispositivo.';

  @override
  String get screensaverScreenOffNever => 'No apagar la pantalla';

  @override
  String get screensaverMotion => 'Cerrar al detectar movimiento';

  @override
  String get screensaverFace => 'Cerrar al detectar un rostro';

  @override
  String get screensaverProximity => 'Cerrar al detectar proximidad';

  @override
  String get screensaverPerson => 'Cerrar al detectar una persona';

  @override
  String get screensaverWidgets => 'Widgets';

  @override
  String get screensaverGlance => 'De un vistazo';

  @override
  String get screensaverNowPlaying =>
      'Mostrar En reproducción junto al protector de pantalla';

  @override
  String get screensaverNowPlayingHelp =>
      'Predeterminado sigue la distribución general. Activado comparte la pantalla cuando En reproducción está habilitado. Desactivado oculta En reproducción durante estas horas.';

  @override
  String get screensaverCameraRequired =>
      'Requiere la cámara. Actívala primero en la configuración de Cámara.';

  @override
  String get screensaverNotAvailable =>
      'No está disponible en este dispositivo.';

  @override
  String get screensaverSummaryMotionOn => 'Movimiento: activado';

  @override
  String get screensaverSummaryMotionOff => 'Movimiento: desactivado';

  @override
  String get screensaverSummaryFaceOn => 'Rostros: activado';

  @override
  String get screensaverSummaryFaceOff => 'Rostros: desactivado';

  @override
  String get screensaverSummaryProximityOn => 'Proximidad: activado';

  @override
  String get screensaverSummaryProximityOff => 'Proximidad: desactivado';

  @override
  String get screensaverSummaryPersonOn => 'Personas: activado';

  @override
  String get screensaverSummaryPersonOff => 'Personas: desactivado';

  @override
  String get screensaverSummaryWidgetsOn => 'Widgets: activado';

  @override
  String get screensaverSummaryWidgetsOff => 'Widgets: desactivado';

  @override
  String get screensaverSummaryGlanceOn => 'De un vistazo: activado';

  @override
  String get screensaverSummaryGlanceOff => 'De un vistazo: desactivado';

  @override
  String get screensaverSummaryNowPlayingOn => 'En reproducción: activado';

  @override
  String get screensaverSummaryNowPlayingOff => 'En reproducción: desactivado';

  @override
  String screensaverBrightnessPercent(String percent) {
    return 'Brillo del $percent %';
  }

  @override
  String screensaverScreenOffAfter(String minutes) {
    return 'Apagar la pantalla después de $minutes min';
  }

  @override
  String get settingScreensaverWebsiteUrlTitle => 'URL del sitio web';

  @override
  String get settingScreensaverWebsiteUrlDescription =>
      'Página que se muestra a pantalla completa. Debe permitir que se incruste.';

  @override
  String get settingScreensaverWebsiteZoomTitle => 'Nivel de zoom';

  @override
  String get settingScreensaverWebsiteZoomDescription =>
      'Cambia la escala de toda la vista web del protector de pantalla.';

  @override
  String get settingScreensaverWebsiteDoubleTapTitle =>
      'Tocar dos veces para cerrar';

  @override
  String get settingScreensaverWebsiteDoubleTapDescription =>
      'Un solo toque permite interactuar con el sitio web en lugar de cerrar el protector de pantalla.';

  @override
  String get screensaverWebsiteSection => 'Protector de pantalla: Sitio web';

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
      'Introduce solo la URL base, sin la ruta de un panel de control. Ejemplo: https://homeassistant.local:8123';

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
  String get setupDashboard => 'Panel de control';

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
      'Importa una configuración exportada desde Kiosk Satellite y omite el resto de este asistente. Se incluyen la configuración, el panel de control y los datos de inicio de sesión.';

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
