import 'dart:io';

import 'package:flutter/foundation.dart';

import 'logging.dart';

/// Every certificate decision the app makes, in the app log under one tag,
/// so a report about a private CA or a self-signed server shows which
/// client met which certificate and what happened to it.
///
/// Process-wide like [HttpOverrides.global]: certificate callbacks live in
/// static clients and widgets that have no logger of their own. The clients
/// call back on every connection, so a decision is logged once per client,
/// host and verdict for the run.
class CertificateLog {
  const CertificateLog._();

  static const tag = 'tls';

  static Logger? _log;
  static final _seen = <String>{};

  static void attach(Logger log) => _log = log;

  @visibleForTesting
  static void reset() {
    _log = null;
    _seen.clear();
  }

  static void info(String message) => _log?.info(tag, message);
  static void warn(String message) => _log?.warn(tag, message);

  /// A certificate the device does not trust, met by a dart:io client.
  /// [reason] says why it is accepted anyway, null when it is refused.
  /// Returns whether it was accepted, so a badCertificateCallback can end
  /// with this call.
  static bool dart(
    String client,
    String host,
    X509Certificate? cert,
    String? reason,
  ) {
    untrusted(
      client: client,
      host: host,
      reason: reason,
      subject: cert?.subject,
      issuer: cert?.issuer,
    );
    return reason != null;
  }

  static void untrusted({
    required String client,
    required String host,
    required String? reason,
    String? subject,
    String? issuer,
    String? error,
  }) {
    final log = _log;
    if (log == null || !_seen.add('$client|$host|$reason')) return;
    final details = [
      if (subject != null && subject.isNotEmpty) 'subject $subject',
      if (issuer != null && issuer.isNotEmpty) 'issued by $issuer',
      if (error != null && error.isNotEmpty) error,
    ].join(', ');
    final what =
        '$client: certificate for $host is not trusted by the device'
        '${details.isEmpty ? '' : ' ($details)'}';
    if (reason != null) {
      log.info(tag, '$what, accepted because $reason');
    } else {
      log.warn(
        tag,
        '$what, refused. Install its certificate authority in Android '
        'security settings and restart the app, or turn on Ignore SSL errors',
      );
    }
  }
}
