import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/core/certificate_log.dart';
import 'package:kiosk_satellite/core/logging.dart';
import 'package:kiosk_satellite/core/user_authorities.dart';

// A test CA and a localhost certificate it signed, both valid for a century.
const _ca = '''
-----BEGIN CERTIFICATE-----
MIIBmjCCAUGgAwIBAgIUG+qBDe0i2SX/xu7AaPs8FcD4fb4wCgYIKoZIzj0EAwIw
IjEgMB4GA1UEAwwXS2lvc2sgU2F0ZWxsaXRlIFRlc3QgQ0EwIBcNMjYxMDAxMjMz
NTA0WhgPMjEyNjA5MDcyMzM1MDRaMCIxIDAeBgNVBAMMF0tpb3NrIFNhdGVsbGl0
ZSBUZXN0IENBMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAESmyU4/UnolT/m+g2
LQ+lmE/dP/hs1VcNeFl9+xTCCSeIiipauGfjNnj+lwsqtgYkaaQ6GHlEo5DK5dev
EAci+6NTMFEwHQYDVR0OBBYEFO5ZmgoG3iKcak2+l/gptN76Ge+rMB8GA1UdIwQY
MBaAFO5ZmgoG3iKcak2+l/gptN76Ge+rMA8GA1UdEwEB/wQFMAMBAf8wCgYIKoZI
zj0EAwIDRwAwRAIgUixa7b7ZGOl+QJFmQCw9ZaRAYuWHVexLQiK8HoOHNUUCIE4o
b1uoCGR9Uzv8sts4znJWHN5Ma93rIcTQZP8rT6Du
-----END CERTIFICATE-----
''';
const _leaf = '''
-----BEGIN CERTIFICATE-----
MIIBuDCCAV6gAwIBAgIUQjdYIfNvteXNSdX1FlgzWredvmswCgYIKoZIzj0EAwIw
IjEgMB4GA1UEAwwXS2lvc2sgU2F0ZWxsaXRlIFRlc3QgQ0EwIBcNMjYxMDAxMjMz
NTA0WhgPMjEyNjA5MDcyMzM1MDRaMBQxEjAQBgNVBAMMCWxvY2FsaG9zdDBZMBMG
ByqGSM49AgEGCCqGSM49AwEHA0IABF1YwDWwT8wedzt04kbyg/OJQ1tOqnqRTSnj
R05PnhXGJXQtd+lcx4gDAj/FOgGWO34DFeXzy8jz1vbAjMKlKdyjfjB8MBoGA1Ud
EQQTMBGCCWxvY2FsaG9zdIcEfwAAATAJBgNVHRMEAjAAMBMGA1UdJQQMMAoGCCsG
AQUFBwMBMB0GA1UdDgQWBBS38GMcpN427v+jWg3mib6/IKIbYDAfBgNVHSMEGDAW
gBTuWZoKBt4inGpNvpf4KbTe+hnvqzAKBggqhkjOPQQDAgNIADBFAiAEeVK38E15
SBym6WJofVRdouQ8Y6o2uJK2hzMoIe5ZXgIhAJbdSGd5qJMiHDuU9JCtzLksbkRm
8ZKFo+BT6YXGN4DN
-----END CERTIFICATE-----
''';
const _leafKey = '''
-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgL3JH9I/O7x7e/Bcf
ePqPCg+piLOMB6jdjtC7N0wxOlihRANCAARdWMA1sE/MHnc7dOJG8oPziUNbTqp6
kU0p40dOT54VxiV0LXfpXMeIAwI/xToBljt+AxXl88vI89b2wIzCpSnc
-----END PRIVATE KEY-----
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('kiosk_satellite/tls');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void answer(Object? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, (call) async => handler(call));
  }

  late Logger log;
  setUp(() {
    log = Logger();
    CertificateLog.attach(log);
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    CertificateLog.reset();
  });

  List<String> lines() => [
    for (final e in log.recent)
      if (e.tag == CertificateLog.tag) '${e.level.name} ${e.message}',
  ];

  Map<String, Object?> authority(String pem, {String subject = 'CN=Test CA'}) =>
      {
        'pem': pem,
        'subject': subject,
        'notAfter': DateTime.utc(2126, 6, 15, 12).millisecondsSinceEpoch,
      };

  Future<bool> handshake(SecurityContext context) async {
    final server = await SecureServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
      SecurityContext()
        ..useCertificateChainBytes(utf8.encode(_leaf))
        ..usePrivateKeyBytes(utf8.encode(_leafKey)),
    );
    server.listen((socket) => socket.close(), onError: (_) {});
    try {
      final socket = await SecureSocket.connect(
        'localhost',
        server.port,
        context: context,
      );
      await socket.close();
      return true;
    } on HandshakeException {
      return false;
    } finally {
      await server.close();
    }
  }

  test('a server signed by a user CA verifies once the CA is added', () async {
    final context = SecurityContext();
    expect(await handshake(context), isFalse);

    answer(
      (call) => call.method == 'userAuthorities'
          ? {
              'authorities': [authority(_ca)],
            }
          : null,
    );
    expect(await trustUserAuthorities(context: context), 1);
    expect(await handshake(context), isTrue);
    expect(lines(), [
      'info trusting user-installed certificate authority CN=Test CA, '
          'expires 2126-06-15',
    ]);
  });

  test('an unreadable certificate does not keep the others out', () async {
    answer(
      (_) => {
        'authorities': [
          authority('not a certificate', subject: 'CN=Broken'),
          authority(_ca),
        ],
      },
    );
    final context = SecurityContext();
    expect(await trustUserAuthorities(context: context), 1);
    expect(await handshake(context), isTrue);
    expect(
      lines().first,
      startsWith('warn could not use certificate authority CN=Broken'),
    );
  });

  test('an empty store and a store error are both logged', () async {
    answer((_) => {'authorities': <Object>[]});
    expect(await trustUserAuthorities(context: SecurityContext()), 0);
    answer((_) => {'authorities': <Object>[], 'error': 'KeyStore failed'});
    expect(await trustUserAuthorities(context: SecurityContext()), 0);
    expect(lines(), [
      'info no user-installed certificate authorities',
      'warn could not read user-installed certificate authorities: '
          'KeyStore failed',
    ]);
  });

  test('a failing channel adds nothing and does not throw', () async {
    answer((_) => throw PlatformException(code: 'tls'));
    expect(await trustUserAuthorities(context: SecurityContext()), 0);
    expect(lines().single, startsWith('warn could not read'));
  });

  test(
    'certificate decisions are logged once per client, host and verdict',
    () {
      for (var i = 0; i < 3; i++) {
        CertificateLog.dart(
          'app',
          'ha.lan',
          null,
          'it is the Home Assistant host',
        );
      }
      CertificateLog.dart('app', 'nas.lan', null, null);
      CertificateLog.untrusted(
        client: 'dashboard',
        host: 'ha.lan',
        reason: null,
        subject: 'ha.lan',
        issuer: 'Home CA',
        error: 'SSL_UNTRUSTED',
      );
      expect(lines(), [
        'info app: certificate for ha.lan is not trusted by the device, '
            'accepted because it is the Home Assistant host',
        'warn app: certificate for nas.lan is not trusted by the device, '
            'refused. Install its certificate authority in Android security '
            'settings and restart the app, or turn on Ignore SSL errors',
        'warn dashboard: certificate for ha.lan is not trusted by the device '
            '(subject ha.lan, issued by Home CA, SSL_UNTRUSTED), refused. '
            'Install its certificate authority in Android security settings '
            'and restart the app, or turn on Ignore SSL errors',
      ]);
    },
  );
}
