import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Kiosks use self-signed certificates without pairing or certificate checks.
/// This policy belongs only to kiosk traffic, never Home Assistant or downloads.
HttpClient kioskPeerHttpClient({
  bool requireTls = false,
}) => HttpOverrides.runWithHttpOverrides(() {
  final context = SecurityContext()
    ..minimumTlsProtocolVersion = TlsProtocolVersion.tls1_2;
  final client = HttpClient(context: context)
    ..connectionTimeout = const Duration(seconds: 6)
    ..badCertificateCallback = (_, _, _) => true;
  if (requireTls) {
    // WebSocket.connect follows redirects, so enforce TLS on every connection.
    client.connectionFactory = (target, proxyHost, proxyPort) {
      if (target.scheme != 'https') {
        throw StateError('Encrypted kiosk connections require HTTPS.');
      }
      // HttpClient upgrades proxy tunnels itself. Direct sockets need TLS here.
      if (proxyHost != null) return Socket.startConnect(proxyHost, proxyPort!);
      return SecureSocket.startConnect(
        target.host,
        target.port,
        context: context,
        onBadCertificate: (_) => true,
      );
    };
  }
  return client;
}, _KioskHttpOverrides());

http.Client kioskPeerClient() => IOClient(kioskPeerHttpClient());

class _KioskHttpOverrides extends HttpOverrides {}
