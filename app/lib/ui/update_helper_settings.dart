import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_container.dart';
import 'kit.dart';
import '../l10n/messages.dart';
import 'package:kiosk_satellite/core/lifecycle.dart';

/// The helper is activated by ADB. Its current process decides availability.
class UpdateHelperSettings extends StatefulWidget {
  const UpdateHelperSettings({
    super.key,
    required this.container,
    this.entryBuilder,
  });

  final AppContainer container;
  final WidgetBuilder? entryBuilder;

  @override
  State<UpdateHelperSettings> createState() => _UpdateHelperSettingsState();
}

class _UpdateHelperSettingsState extends State<UpdateHelperSettings>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _status;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  final _returned = ReturnWatch();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_returned.returned(state)) _refresh();
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final status = await widget.container.update.installerStatus();
      if (mounted) {
        setState(() {
          _status = status;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not check the update helper.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entryBuilder != null) {
      // A missing result is unknown, not evidence that a helper is needed.
      return _status?['nativeSilent'] == false
          ? widget.entryBuilder!(context)
          : SizedBox.shrink();
    }
    if (_status?['nativeSilent'] == true) {
      return HintRow(
        deviceText(
          context,
          'Android can now install updates silently. The helper is not needed.',
        ),
        inset: false,
      );
    }
    if (_status == null) {
      return SettingsCard(
        children: [
          ListTile(
            title: Text(deviceText(context, 'Helper status')),
            subtitle: Text(deviceText(context, _error ?? 'Checking...')),
            trailing: IconButton(
              tooltip: deviceText(context, 'Refresh'),
              onPressed: _busy ? null : _refresh,
              icon: Icon(Icons.refresh),
            ),
          ),
        ],
      );
    }
    final helper = _status?['helper'];
    final active = helper == 'ready' || helper == 'busy';
    final command = _status?['startCommand'] as String?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HintRow(
          deviceText(
            context,
            'This device currently needs confirmation on the screen to install '
            'updates through Android. The optional helper lets Kiosk Satellite '
            'install updates without a tap.',
          ),
          inset: false,
        ),
        SettingsCard(
          children: [
            ListTile(
              title: Text(deviceText(context, 'Helper status')),
              subtitle: Text(
                (_error != null ? deviceText(context, _error!) : null) ??
                    (helper == 'busy'
                        ? deviceText(context, 'Installing an update.')
                        : active
                        ? deviceText(
                            context,
                            'Ready. Updates install without confirmation.',
                          )
                        : deviceText(
                            context,
                            'Unavailable. Start the helper through ADB to enable updates without confirmation.',
                          )),
              ),
              trailing: IconButton(
                tooltip: deviceText(context, 'Refresh'),
                onPressed: _busy ? null : _refresh,
                icon: Icon(Icons.refresh),
              ),
            ),
            HintRow(
              deviceText(
                context,
                'The helper survives app restarts and updates but stops after a '
                'device reboot. Run the command from a computer with ADB to start '
                'it again. The computer can then disconnect.',
              ),
            ),
            if (command != null)
              ListTile(
                title: Text(deviceText(context, 'Start through ADB')),
                subtitle: SelectableText(
                  command,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: IconButton(
                  tooltip: deviceText(context, 'Copy command'),
                  icon: Icon(Icons.copy_outlined),
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: command)),
                ),
              ),
            ListTile(
              title: Text(deviceText(context, 'Setup guide')),
              subtitle: Text(
                deviceText(
                  context,
                  'Read the update helper instructions and requirements.',
                ),
              ),
              trailing: Icon(Icons.open_in_new),
              onTap: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
                widget.container.commands.execute('showLinkPage', {
                  'url':
                      'https://kiosksatellite.com/docs/updates/#optional-update-helper',
                });
              },
            ),
          ],
        ),
      ],
    );
  }
}
