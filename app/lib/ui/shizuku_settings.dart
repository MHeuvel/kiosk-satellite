import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../managers/shizuku/shizuku_manager.dart';
import '../managers/wake_word/permission_descriptions.dart';
import 'kit.dart';
import '../l10n/messages.dart';
import 'plugin_shizuku.dart';
import 'toast.dart';
import 'settings_search.dart';
import 'package:kiosk_satellite/core/lifecycle.dart';

class ShizukuSettingsPanel extends StatefulWidget {
  const ShizukuSettingsPanel({
    super.key,
    required this.manager,
    required this.updateSettings,
  });
  final ShizukuManager manager;
  final Widget updateSettings;
  @override
  State<ShizukuSettingsPanel> createState() => _ShizukuSettingsPanelState();
}

class _ShizukuSettingsPanelState extends State<ShizukuSettingsPanel>
    with WidgetsBindingObserver {
  String? _busy;
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
    try {
      await widget.manager.refresh();
    } catch (_) {
      if (mounted) widget.manager.state.value = {'status': 'unavailable'};
    }
  }

  Future<void> _run(String action) async {
    if (_busy != null) return;
    setState(() => _busy = action);
    try {
      if (action == 'permission') {
        await widget.manager.refresh(request: true);
      } else {
        final result = await widget.manager.run(action);
        if (!mounted) return;
        if (action == 'identity') {
          final ok = result['exitCode'] == 0 && result['timedOut'] != true;
          showToast(
            context,
            title: deviceText(context, 'Connection test'),
            message: ok
                ? l10n(context).deviceShizukuTestOk(
                    widget.manager.state.value['uid'] == 0 ? 'root' : 'shell',
                  )
                : deviceText(
                    context,
                    'Shizuku could not complete the connection test.',
                  ),
            kind: ok ? ToastKind.success : ToastKind.error,
          );
        } else {
          final rows = (result['results'] as List? ?? [])
              .whereType<Map>()
              .toList();
          final failed = rows.where((row) => row['ok'] != true).toList();
          await showDialog<void>(
            context: context,
            builder: (context) {
              final names = {
                for (final entry in devicePermissionDescriptions.entries)
                  entry.key: deviceText(context, entry.value.title),
              };
              final message = rows.isEmpty
                  ? deviceText(context, 'All permissions are already granted.')
                  : failed.isEmpty
                  ? deviceText(
                      context,
                      'Android confirmed the requested permissions.',
                    )
                  : failed
                        .map(
                          (row) =>
                              '${names[row['key']] ?? row['key']}: ${deviceOperationError(context, '${row['error']}')}',
                        )
                        .join('\n');
              return AlertDialog(
                title: Text(deviceText(context, 'Permission results')),
                content: SingleChildScrollView(child: Text(message)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(deviceText(context, 'OK')),
                  ),
                ],
              );
            },
          );
        }
      }
    } catch (error) {
      if (mounted) {
        showToast(
          context,
          title: 'Shizuku',
          message: deviceOperationError(context, '$error'),
          kind: ToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Widget _button(
    String action,
    String label,
    bool enabled, {
    bool primary = false,
  }) {
    final child = _busy == action
        ? SizedBox(
            width: 48,
            height: 20,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        : Text(label);
    final onPressed = enabled && _busy == null ? () => _run(action) : null;
    return primary
        ? FilledButton(onPressed: onPressed, child: child)
        : OutlinedButton(onPressed: onPressed, child: child);
  }

  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<Map<String, Object?>>(
    valueListenable: widget.manager.state,
    builder: (_, state, _) {
      final ready = state['granted'] == true;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeading(deviceText(context, 'Connection')),
          SettingsCard(
            children: [
              SearchLandingTarget(
                id: 'x:shizuku:permission',
                child: SettingsRow(
                  title: Text(deviceText(context, 'Shizuku access')),
                  subtitle: Text(
                    deviceText(
                      context,
                      pluginShizukuHint(
                        state,
                      ).replaceAll(' Tap for setup instructions.', ''),
                    ),
                  ),
                  trailing: ready
                      ? Icon(Icons.check_circle_outline)
                      : _button(
                          'permission',
                          deviceText(context, 'Grant'),
                          state['status'] == 'permission_required',
                        ),
                ),
              ),
              SearchLandingTarget(
                id: 'x:shizuku:identity',
                child: SettingsRow(
                  title: Text(deviceText(context, 'Test connection')),
                  subtitle: Text(
                    deviceText(
                      context,
                      'Read the process identity without changing the device.',
                    ),
                  ),
                  trailing: _button(
                    'identity',
                    deviceText(context, 'Test'),
                    ready,
                  ),
                ),
              ),
            ],
          ),
          SettingsCard(children: [widget.updateSettings]),
          SectionHeading(deviceText(context, 'Permissions')),
          SettingsCard(
            children: [
              SearchLandingTarget(
                id: 'x:shizuku:grantAll',
                child: SettingsRow(
                  title: Text(deviceText(context, 'Grant all permissions')),
                  subtitle: Text(
                    deviceText(
                      context,
                      'Grant all permissions used by KS, including features that are currently off.',
                    ),
                  ),
                  trailing: _button(
                    'grantAll',
                    deviceText(context, 'Grant'),
                    ready,
                    primary: true,
                  ),
                ),
              ),
              for (final entry in devicePermissionDescriptions.entries)
                SearchLandingTarget(
                  id: 'x:shizuku:${entry.key}',
                  child: SettingsRow(
                    title: Text(deviceText(context, entry.value.title)),
                    subtitle: Text(
                      deviceText(context, entry.value.description),
                    ),
                    trailing: _button(
                      entry.key,
                      deviceText(context, 'Grant'),
                      ready,
                    ),
                  ),
                ),
            ],
          ),
          SectionHeading(deviceText(context, 'Help')),
          SettingsCard(
            children: [
              SearchLandingTarget(
                id: 'x:shizuku:setup',
                child: SettingsRow(
                  title: Text(deviceText(context, 'Set up Shizuku')),
                  subtitle: Text(
                    deviceText(
                      context,
                      'Read installation and startup instructions.',
                    ),
                  ),
                  trailing: Icon(Icons.open_in_new),
                  onTap: () => launchUrl(
                    Uri.parse('https://shizuku.rikka.app/guide/setup/'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ),
              HintRow(
                deviceText(
                  context,
                  'Shizuku started through ADB must be started again after a device reboot. Shell access does not provide root permissions.',
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}
