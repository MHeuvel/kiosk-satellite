/// What the Intercom sensors on the ESPHome device and the plugin SDK's
/// `intercom.state` report, from one `intercomStatus` shape: the state word,
/// the other kiosk's name (the caller's through a missed call, else empty)
/// and whether Do not disturb holds.
Map<String, Object?> intercomSensors(Map<String, Object?> status) {
  final call = status['call'];
  final peer = call is Map ? call['peer'] : null;
  return {
    'state': '${status['state'] ?? 'idle'}',
    'kiosk': peer is Map ? '${peer['name'] ?? ''}' : '',
    'dnd': status['dnd'] == true,
  };
}
