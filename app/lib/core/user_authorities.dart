import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'certificate_log.dart';

/// Adds the certificate authorities the user installed in Android's
/// security settings to [context], the process default unless a test
/// passes its own.
///
/// dart:io trusts only the system store, so a Home Assistant behind a
/// private CA failed every Dart connection: the API, the websockets and
/// downloads (issue #775). The WebView and the native players get the same
/// CAs from the network security config. Clients built on their own
/// context, such as the strict client for GitHub, are unaffected.
///
/// Runs once at startup, before anything connects. Returns how many CAs
/// were added. A CA installed later takes effect after a restart.
Future<int> trustUserAuthorities({
  MethodChannel channel = const MethodChannel('kiosk_satellite/tls'),
  SecurityContext? context,
}) async {
  final Map<String, Object?> reply;
  try {
    reply =
        await channel.invokeMapMethod<String, Object?>('userAuthorities') ??
        const {};
  } on Exception catch (e) {
    CertificateLog.warn(
      'could not read user-installed certificate authorities: $e',
    );
    return 0;
  }
  final error = reply['error'];
  if (error is String) {
    CertificateLog.warn(
      'could not read user-installed certificate authorities: $error',
    );
  }
  final authorities = (reply['authorities'] as List?) ?? const [];
  if (authorities.isEmpty && error == null) {
    CertificateLog.info('no user-installed certificate authorities');
  }
  final target = context ?? SecurityContext.defaultContext;
  var added = 0;
  for (final entry in authorities.whereType<Map>()) {
    final subject = entry['subject'] as String? ?? 'unknown subject';
    final notAfter = entry['notAfter'];
    final expires = notAfter is int
        ? DateTime.fromMillisecondsSinceEpoch(notAfter)
        : null;
    try {
      target.setTrustedCertificatesBytes(
        utf8.encode(entry['pem'] as String? ?? ''),
      );
      added++;
      CertificateLog.info(
        'trusting user-installed certificate authority $subject'
        '${expires == null ? '' : ', expires ${_date(expires)}'}'
        '${expires != null && expires.isBefore(DateTime.now()) ? ' (expired)' : ''}',
      );
    } on TlsException catch (e) {
      // One unreadable certificate must not keep the others out.
      CertificateLog.warn(
        'could not use certificate authority $subject: ${e.message}',
      );
    }
  }
  return added;
}

String _date(DateTime t) => t.toIso8601String().substring(0, 10);
