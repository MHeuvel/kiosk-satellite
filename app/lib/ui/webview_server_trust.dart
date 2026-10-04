import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../core/certificate_log.dart';
import '../managers/settings/definitions.dart' as defs;
import '../managers/settings/settings_manager.dart';

/// The WebViews' answer to a certificate Android does not trust, which
/// already counts the system CAs and the ones the user installed: proceed
/// only when the user opted in with Ignore SSL errors (e.g. a local HA
/// without proper SSL), otherwise refuse. Either way it goes to the app log.
ServerTrustAuthResponse webViewServerTrust(
  String client,
  SettingsManager settings,
  ServerTrustChallenge challenge,
) {
  final space = challenge.protectionSpace;
  final proceed = settings.get(defs.ignoreSslErrors);
  CertificateLog.untrusted(
    client: client,
    host: space.host,
    reason: proceed ? 'Ignore SSL errors is on' : null,
    subject: space.sslCertificate?.issuedTo?.CName,
    issuer: space.sslCertificate?.issuedBy?.CName,
    error: space.sslError?.message ?? space.sslError?.code?.toString(),
  );
  return ServerTrustAuthResponse(
    action: proceed
        ? ServerTrustAuthResponseAction.PROCEED
        : ServerTrustAuthResponseAction.CANCEL,
  );
}
