import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_container.dart';
import '../l10n/messages.dart';
import '../managers/settings/definitions.dart';
import 'kit.dart';
import 'theme.dart';

/// The certificate shared by every encrypted listener on this device.
class TlsSettingsPanel extends StatefulWidget {
  const TlsSettingsPanel({super.key, required this.container});
  final AppContainer container;
  @override
  State<TlsSettingsPanel> createState() => _TlsSettingsPanelState();
}

class _TlsSettingsPanelState extends State<TlsSettingsPanel> {
  Map? _info;
  String? _error;
  bool _busy = false;
  String text(String value) => deviceText(context, value);

  @override
  void initState() {
    super.initState();
    _run(_load);
  }

  Future<Map?> _command(
    String name, [
    Map<String, Object?> params = const {},
  ]) async {
    final result = await widget.container.commands.execute(name, params);
    if (!result.ok) {
      throw StateError(result.error ?? 'Certificate operation failed.');
    }
    return result.data is Map ? result.data as Map : null;
  }

  Future<void> _load() async {
    final info = await _command('tlsCertificate');
    if (mounted) setState(() => _info = info);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = deviceOperationError(context, '$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _replace() async {
    if (!await showConfirmDialog(
      context,
      title: text('Replace certificate'),
      message: text(
        'Generate a new private key and certificate? Active encrypted connections will close. Browsers may ask you to accept the new certificate.',
      ),
      confirmLabel: text('Replace'),
      destructive: true,
    )) {
      return;
    }
    await _run(() async {
      await _command('replaceTlsIdentity');
      await _load();
    });
  }

  Future<void> _import() async {
    var certificate = '';
    var privateKey = '';
    String? error;
    var pending = false;
    final form = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(text('Import certificate')),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      text(
                        'Paste the PEM certificate chain and its unencrypted private key. They are validated before replacing the current certificate.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    for (final isKey in [false, true]) ...[
                      TextFormField(
                        enabled: !pending,
                        minLines: 3,
                        maxLines: 5,
                        autocorrect: false,
                        enableSuggestions: false,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13.5,
                        ),
                        decoration: InputDecoration(
                          labelText: text(
                            isKey
                                ? 'Private key (PEM)'
                                : 'Certificate chain (PEM)',
                          ),
                          alignLabelWithHint: true,
                        ),
                        onChanged: (value) {
                          if (isKey) {
                            privateKey = value;
                          } else {
                            certificate = value;
                          }
                        },
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? text('This field is required.')
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (error != null)
                      NoticeBanner(text: error!, kind: NoticeKind.error),
                    if (pending) const LinearProgressIndicator(),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: pending ? null : () => Navigator.pop(context),
              child: Text(text('Cancel')),
            ),
            FilledButton(
              onPressed: pending
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      update(() {
                        pending = true;
                        error = null;
                      });
                      try {
                        await _command('importTlsCertificate', {
                          'certificate': certificate,
                          'privateKey': privateKey,
                        });
                        privateKey = '';
                        if (context.mounted) Navigator.pop(context);
                        await _run(_load);
                      } catch (e) {
                        if (context.mounted) {
                          update(() {
                            error = deviceOperationError(context, '$e');
                            pending = false;
                          });
                        }
                      }
                    },
              child: Text(text('Import')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(
    String title,
    String description,
    IconData icon,
    VoidCallback? action,
  ) => ListTile(
    enabled: action != null,
    title: Text(text(title)),
    subtitle: Text(text(description)),
    trailing: Icon(icon),
    onTap: action,
  );

  String get _expires {
    final date = DateTime.tryParse('${_info?['expires']}')?.toLocal();
    if (date == null) return '';
    return MaterialLocalizations.of(context).formatShortDate(date);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_error != null) NoticeBanner(text: _error!, kind: NoticeKind.error),
      if (_busy) const LinearProgressIndicator(),
      if (_info != null)
        SettingsCard(
          children: [
            ListTile(
              title: Text(text('Certificate type')),
              trailing: Text(
                text(_info!['imported'] == true ? 'Imported' : 'Self-signed'),
              ),
            ),
            ListTile(title: Text(text('Expires')), trailing: Text(_expires)),
            if (_info!['expired'] == true)
              WarnRow(
                text('Certificate expired. Renew or import a replacement.'),
              ),
            Padding(
              padding: const EdgeInsets.all(Ks.inset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    text('SHA-256 fingerprint'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  CopyBox(value: '${_info!['fingerprint']}'),
                ],
              ),
            ),
          ],
        ),
      SectionHeading(text('Certificate Management')),
      SettingsCard(
        children: [
          _action(
            'Copy public certificate',
            'Use this certificate in browsers and streaming clients.',
            Icons.copy_outlined,
            _busy || _info == null
                ? null
                : () => Clipboard.setData(
                    ClipboardData(text: '${_info!['certificate']}'),
                  ),
          ),
          if (_info?['imported'] != true)
            _action(
              'Renew certificate',
              'Keep the current private key and update the certificate dates.',
              Icons.autorenew,
              _busy
                  ? null
                  : () => _run(() async {
                      await _command('renewTlsCertificate');
                      await _load();
                    }),
            ),
          _action(
            'Import certificate',
            'Use a certificate issued for this device.',
            Icons.file_upload_outlined,
            _busy ? null : _import,
          ),
          _action(
            'Replace certificate',
            'Generate a new private key and self-signed certificate.',
            Icons.restart_alt,
            _busy ? null : _replace,
          ),
        ],
      ),
    ],
  );
}

Future<bool> confirmRemoteProtocol(
  BuildContext context,
  AppContainer container,
  bool https,
) async {
  final ip = await container.device.ipAddress();
  if (!context.mounted) return false;
  final host = ip ?? '${container.settings.tls.hostname}.local';
  final address = Uri(
    scheme: https ? 'https' : 'http',
    host: host,
    port: container.settings.get(remotePort).toInt(),
  ).toString();
  String text(String value) => deviceText(context, value);
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(text('Change connection protocol')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                text(
                  'The current remote connection will close. Reconnect using the address below. You may need to sign in again.',
                ),
              ),
              const SizedBox(height: 16),
              CopyBox(value: address, multiline: true),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(text('Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(text('Confirm')),
            ),
          ],
        ),
      ) ??
      false;
}
