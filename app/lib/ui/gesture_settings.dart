import 'dart:convert';

import 'package:flutter/material.dart';

import '../app_container.dart';
import '../l10n/messages.dart';
import '../l10n/gesture_messages.dart';
import '../managers/gestures/gesture_mappings.dart';
import '../managers/settings/definitions.dart' as defs;
import 'hand_gesture_tester.dart';
import 'kit.dart';
import 'toast.dart';
import 'settings_search.dart';

/// The Gestures page (issue #99): the list of gestures and the
/// actions they trigger. Mirrored by the remote admin's Gestures page.
///
/// The editor is two-staged on purpose: the main dialog owns the trigger,
/// and each action type configures itself in its own dialog, so a URL
/// action can be one field while a service call is four.
class GestureSettingsPanel extends StatefulWidget {
  const GestureSettingsPanel({super.key, required this.container});

  final AppContainer container;

  @override
  State<GestureSettingsPanel> createState() => _GestureSettingsPanelState();
}

/// The action chooser's groups of (type, label, icon); config dialogs
/// switch on the type.
const _actionGroups = <(String, List<(String, String, IconData)>)>[
  (
    'Kiosk Satellite',
    [
      ('navigate', 'Go to a dashboard view', Icons.dashboard_outlined),
      ('url', 'Open a web page', Icons.public),
      ('camera_view', 'Show a camera view', Icons.videocam_outlined),
      ('sendspin_player', 'Show the floating player', Icons.speaker_outlined),
      ('now_playing', 'Show Now Playing', Icons.play_circle_outline),
      ('music_assistant', 'Open Music Assistant', Icons.library_music_outlined),
      ('app_launcher', 'Open the app launcher', Icons.apps_outlined),
      ('intercom_open', 'Open Call a kiosk', Icons.speaker_phone_outlined),
      ('intercom_call', 'Call a kiosk', Icons.phone_outlined),
      ('screensaver', 'Start the screensaver', Icons.nightlight_outlined),
      ('screensaver_stop', 'Stop the screensaver', Icons.light_mode_outlined),
      ('hold_mode', 'Toggle hold mode', Icons.pause_circle_outline),
      ('ha_kiosk', 'Toggle HA kiosk mode', Icons.fullscreen),
      ('plugin_action', 'Run a plugin action', Icons.extension_outlined),
    ],
  ),
  (
    'Android',
    [
      ('launch_app', 'Open another app', Icons.apps_outlined),
      ('open_uri', 'Open a deep link', Icons.link_outlined),
      ('android_settings', 'Open Android Settings', Icons.android_outlined),
    ],
  ),
  (
    'Home Assistant',
    [
      ('ha_service', 'Call a service', Icons.home_outlined),
      ('ha_script', 'Run a script', Icons.description_outlined),
      ('ha_automation', 'Trigger an automation', Icons.play_circle_outline),
      ('ha_event', 'Fire an event', Icons.campaign_outlined),
    ],
  ),
];

const _triggerTypes = <(String, String)>[
  ('corner_taps', 'Taps in a corner'),
  ('corner_hold', 'Hold a corner'),
  ('finger_taps', 'Multi-finger tap'),
  ('finger_hold', 'Multi-finger hold'),
  ('corner_sequence', 'Corner sequence'),
  ('claps', 'Claps'),
  ('fingers', 'Show fingers'),
];

class _GestureSettingsPanelState extends State<GestureSettingsPanel> {
  AppContainer get c => widget.container;
  double? _handHoldDrag;

  List<GestureMapping> get _mappings =>
      decodeGestureMappings(c.settings.get(defs.gestureMappings));

  Future<void> _save(List<GestureMapping> mappings) async {
    await c.settings.setFromJson(
      defs.gestureMappings.key,
      jsonEncode([for (final m in mappings) m.toJson()]),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final mappings = _mappings;
    final suppressed =
        c.settings.get(defs.kioskEnabled) &&
        c.settings.get(defs.kioskDisableGestures);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (suppressed)
          Card(
            margin: const EdgeInsets.only(top: 20),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(gestureText(context, 'Gestures are off')),
              subtitle: Text(
                gestureText(
                  context,
                  'Disable Gestures is on in Kiosk Mode settings.',
                ),
              ),
            ),
          ),
        SectionHeading(gestureText(context, 'Gestures')),
        SettingsCard(
          children: [
            if (mappings.isEmpty)
              ListTile(
                leading: Icon(Icons.gesture),
                title: Text(gestureText(context, 'No gestures configured')),
                subtitle: Text(
                  gestureText(
                    context,
                    'A gesture triggers its action without any visible '
                    'control.',
                  ),
                ),
              ),
            for (final mapping in mappings)
              ListTile(
                // Claps are heard and hands are seen, not touched; the
                // row icon says which.
                leading: Icon(switch (mapping.triggerType) {
                  'claps' => Icons.sign_language_outlined,
                  'fingers' => Icons.waving_hand_outlined,
                  _ => Icons.gesture,
                }),
                title: Text(localizedGestureTrigger(context, mapping.trigger)),
                subtitle: Text(localizedGestureAction(context, mapping.action)),
                onTap: () => _edit(mapping),
                trailing: IconButton(
                  tooltip: gestureText(context, 'Delete gesture'),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(mapping),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(gestureText(context, 'Add gesture')),
              subtitle: Text(
                gestureText(
                  context,
                  'Pick a gesture and the action it triggers.',
                ),
              ),
              onTap: () => _edit(null),
            ),
          ],
        ),
        GroupNote(
          gestureText(
            context,
            'Gestures are observed, not blocked: the taps also reach the '
            'dashboard, so corners and multi-finger shapes keep them from '
            'firing anything there.',
          ),
        ),
        SectionHeading(gestureText(context, 'Clapper')),
        SettingsCard(
          children: [
            SearchLandingTarget(
              id: defs.clapStrictness.key,
              child: DropdownRow<String>(
                title: defs.clapStrictness.localizedTitle(context),
                description: defs.clapStrictness.localizedDescription(context),
                value: c.settings.get(defs.clapStrictness),
                options: [
                  ('standard', gestureText(context, 'Standard')),
                  ('strict', gestureText(context, 'Strict')),
                ],
                onChanged: (value) async {
                  if (value == null) return;
                  await c.settings.setFromJson(defs.clapStrictness.key, value);
                  if (mounted) setState(() {});
                },
              ),
            ),
          ],
        ),
        SectionHeading(gestureText(context, 'Hand Gestures')),
        SettingsCard(
          children: [
            SearchLandingTarget(
              id: defs.handGestureHoldSeconds.key,
              child: Column(
                children: [
                  ListTile(
                    title: Text(
                      defs.handGestureHoldSeconds.localizedTitle(context),
                    ),
                    subtitle: Text(
                      defs.handGestureHoldSeconds.localizedDescription(context),
                    ),
                    trailing: Text(
                      localizedHandHoldDuration(
                        context,
                        _handHoldDrag ??
                            c.settings.get(defs.handGestureHoldSeconds),
                      ),
                    ),
                  ),
                  Slider(
                    value:
                        _handHoldDrag ??
                        c.settings
                            .get(defs.handGestureHoldSeconds)
                            .toDouble()
                            .clamp(0, 3),
                    min: 0,
                    max: 3,
                    divisions: 6,
                    label: localizedHandHoldDuration(
                      context,
                      _handHoldDrag ??
                          c.settings.get(defs.handGestureHoldSeconds),
                    ),
                    semanticFormatterCallback: (value) =>
                        localizedHandHoldDuration(context, value),
                    onChanged: (value) => setState(() => _handHoldDrag = value),
                    onChangeEnd: (value) async {
                      await c.settings.set(defs.handGestureHoldSeconds, value);
                      if (mounted) setState(() => _handHoldDrag = null);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        // The tester: a live look at the fingers the camera reads, for
        // learning how to hold a hand before (or after) mapping one.
        SectionHeading(gestureText(context, 'Hand Gesture Tester')),
        SearchLandingTarget(
          id: 'x:hand_gesture_tester',
          child: SettingsCard(children: [HandGestureTesterTile(container: c)]),
        ),
      ],
    );
  }

  Future<void> _delete(GestureMapping mapping) async {
    final confirmed = await showConfirmDialog(
      context,
      title: gestureText(context, 'Delete gesture?'),
      message: l10n(context).gestureDeleteMessage(
        localizedGestureTrigger(context, mapping.trigger),
        localizedGestureAction(context, mapping.action),
      ),
      confirmLabel: gestureText(context, 'Delete'),
      destructive: true,
    );
    if (!confirmed) return;
    await _save([..._mappings]..removeWhere((m) => m.id == mapping.id));
  }

  /// The main editor: trigger shape plus the chosen action's summary row.
  Future<void> _edit(GestureMapping? existing) async {
    var type = existing?.triggerType ?? 'corner_taps';
    var corner = '${existing?.trigger['corner'] ?? 'tl'}';
    var taps = (existing?.trigger['taps'] as num?)?.toInt() ?? 2;
    var fingers = (existing?.trigger['fingers'] as num?)?.toInt() ?? 3;
    var fingerTaps = type == 'finger_taps'
        ? ((existing?.trigger['taps'] as num?)?.toInt() ?? 1)
        : 1;
    var holdMs = (existing?.trigger['holdMs'] as num?)?.toInt() ?? 1500;
    var claps = (existing?.trigger['claps'] as num?)?.toInt() ?? 2;
    var fingerCount = (existing?.trigger['fingers'] as num?)?.toInt() ?? 5;
    final sequence = [
      for (final s in (existing?.trigger['sequence'] as List?) ?? const [])
        '$s',
    ];
    Map<String, Object?>? action = existing?.action;

    if (!cornerNames.containsKey(corner)) corner = 'tl';

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final holdSeconds = holdMs / 1000;
          final canSave =
              action != null &&
              (type != 'corner_sequence' || sequence.length >= 2);
          return AlertDialog(
            title: Text(
              existing == null
                  ? gestureText(context, 'Add gesture')
                  : gestureText(context, 'Edit gesture'),
            ),
            content: SizedBox(
              width: 480,
              child: EdgeFade(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 16,
                    children: [
                      LabeledField(
                        label: gestureText(context, 'Gesture'),
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: type,
                          decoration: const InputDecoration(),
                          items: [
                            // Show fingers needs a hand runtime this
                            // Android version cannot load (issue #331):
                            // not offered, though an existing mapping
                            // still opens for editing.
                            for (final (value, label) in _triggerTypes)
                              if (value != 'fingers' ||
                                  type == 'fingers' ||
                                  !c.deviceCamera.handsKnownUnsupported)
                                DropdownMenuItem(
                                  value: value,
                                  child: Text(gestureText(context, label)),
                                ),
                          ],
                          onChanged: (value) =>
                              setDialogState(() => type = value ?? type),
                        ),
                      ),
                      if (type == 'corner_taps' || type == 'corner_hold')
                        LabeledField(
                          label: gestureText(context, 'Corner'),
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: corner,
                            decoration: const InputDecoration(),
                            items: [
                              for (final entry in cornerNames.entries)
                                DropdownMenuItem(
                                  value: entry.key,
                                  child: Text(
                                    localizedGestureCorner(context, entry.key),
                                  ),
                                ),
                            ],
                            onChanged: (value) =>
                                setDialogState(() => corner = value ?? corner),
                          ),
                        ),
                      if (type == 'corner_taps')
                        LabeledField(
                          label: gestureText(context, 'Taps'),
                          child: DropdownButtonFormField<int>(
                            initialValue: taps.clamp(2, 4),
                            decoration: const InputDecoration(),
                            items: [
                              DropdownMenuItem(
                                value: 2,
                                child: Text(gestureText(context, '2 taps')),
                              ),
                              DropdownMenuItem(
                                value: 3,
                                child: Text(gestureText(context, '3 taps')),
                              ),
                              DropdownMenuItem(
                                value: 4,
                                child: Text(gestureText(context, '4 taps')),
                              ),
                            ],
                            onChanged: (value) =>
                                setDialogState(() => taps = value ?? taps),
                          ),
                        ),
                      if (type == 'finger_taps' || type == 'finger_hold')
                        LabeledField(
                          label: gestureText(context, 'Fingers'),
                          child: DropdownButtonFormField<int>(
                            initialValue: fingers.clamp(2, 3),
                            decoration: const InputDecoration(),
                            items: [
                              DropdownMenuItem(
                                value: 2,
                                child: Text(gestureText(context, '2 fingers')),
                              ),
                              DropdownMenuItem(
                                value: 3,
                                child: Text(gestureText(context, '3 fingers')),
                              ),
                            ],
                            onChanged: (value) => setDialogState(
                              () => fingers = value ?? fingers,
                            ),
                          ),
                        ),
                      if (type == 'finger_taps')
                        LabeledField(
                          label: gestureText(context, 'Taps'),
                          child: DropdownButtonFormField<int>(
                            initialValue: fingerTaps.clamp(1, 2),
                            decoration: const InputDecoration(),
                            items: [
                              DropdownMenuItem(
                                value: 1,
                                child: Text(gestureText(context, 'Single tap')),
                              ),
                              DropdownMenuItem(
                                value: 2,
                                child: Text(gestureText(context, 'Double tap')),
                              ),
                            ],
                            onChanged: (value) => setDialogState(
                              () => fingerTaps = value ?? fingerTaps,
                            ),
                          ),
                        ),
                      if (type == 'corner_hold' || type == 'finger_hold') ...[
                        Text(
                          l10n(
                            context,
                          ).gestureHoldDuration(holdSeconds.toStringAsFixed(2)),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Slider(
                          value: holdSeconds.clamp(0.5, 3),
                          min: 0.5,
                          max: 3,
                          divisions: 10,
                          onChanged: (value) => setDialogState(
                            () => holdMs = (value * 1000).round(),
                          ),
                        ),
                      ],
                      if (type == 'fingers')
                        LabeledField(
                          label: gestureText(context, 'Fingers'),
                          child: DropdownButtonFormField<int>(
                            initialValue: fingerCount.clamp(1, 5),
                            decoration: const InputDecoration(),
                            items: [
                              DropdownMenuItem(
                                value: 1,
                                child: Text(gestureText(context, '1 finger')),
                              ),
                              DropdownMenuItem(
                                value: 2,
                                child: Text(gestureText(context, '2 fingers')),
                              ),
                              DropdownMenuItem(
                                value: 3,
                                child: Text(gestureText(context, '3 fingers')),
                              ),
                              DropdownMenuItem(
                                value: 4,
                                child: Text(gestureText(context, '4 fingers')),
                              ),
                              DropdownMenuItem(
                                value: 5,
                                child: Text(
                                  gestureText(context, 'Open hand (5)'),
                                ),
                              ),
                            ],
                            onChanged: (value) => setDialogState(
                              () => fingerCount = value ?? fingerCount,
                            ),
                          ),
                        ),
                      if (type == 'fingers')
                        Text(
                          c.deviceCamera.handsKnownUnsupported
                              ? gestureText(
                                  context,
                                  cameraText(
                                    context,
                                    c.deviceCamera.visionHint ??
                                        'Not available on this device.',
                                  ),
                                )
                              : gestureText(
                                  context,
                                  'Requires the camera enabled and a well '
                                  'lit environment.',
                                ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (type == 'claps') ...[
                        LabeledField(
                          label: gestureText(context, 'Claps'),
                          child: DropdownButtonFormField<int>(
                            initialValue: claps.clamp(2, 4),
                            decoration: const InputDecoration(),
                            items: [
                              DropdownMenuItem(
                                value: 2,
                                child: Text(gestureText(context, '2 claps')),
                              ),
                              DropdownMenuItem(
                                value: 3,
                                child: Text(gestureText(context, '3 claps')),
                              ),
                              DropdownMenuItem(
                                value: 4,
                                child: Text(gestureText(context, '4 claps')),
                              ),
                            ],
                            onChanged: (value) =>
                                setDialogState(() => claps = value ?? claps),
                          ),
                        ),
                        Text(
                          gestureText(
                            context,
                            'Claps are heard through the microphone, with or '
                            'without wake word detection.',
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if (type == 'corner_sequence') ...[
                        Text(
                          sequence.isEmpty
                              ? gestureText(
                                  context,
                                  'Tap the corners in order (2 to 8 steps).',
                                )
                              : sequence
                                    .map(
                                      (s) => localizedGestureCorner(context, s),
                                    )
                                    .join(' > '),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final entry in cornerNames.entries)
                              OutlinedButton(
                                onPressed: sequence.length >= 8
                                    ? null
                                    : () => setDialogState(
                                        () => sequence.add(entry.key),
                                      ),
                                child: Text(
                                  localizedGestureCorner(context, entry.key),
                                ),
                              ),
                            IconButton(
                              tooltip: gestureText(context, 'Remove last step'),
                              icon: const Icon(Icons.backspace_outlined),
                              onPressed: sequence.isEmpty
                                  ? null
                                  : () => setDialogState(
                                      () => sequence.removeLast(),
                                    ),
                            ),
                          ],
                        ),
                      ],
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.play_circle_outline),
                        title: Text(
                          action == null
                              ? gestureText(context, 'Choose an action')
                              : localizedGestureAction(context, action!),
                        ),
                        subtitle: Text(
                          action == null
                              ? gestureText(
                                  context,
                                  'What this gesture triggers.',
                                )
                              : gestureText(context, 'Tap to change.'),
                        ),
                        onTap: () async {
                          final picked = await _pickAction(action);
                          if (picked != null) {
                            setDialogState(() => action = picked);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(gestureText(context, 'Cancel')),
              ),
              FilledButton(
                onPressed: canSave ? () => Navigator.pop(context, true) : null,
                child: Text(gestureText(context, 'Save')),
              ),
            ],
          );
        },
      ),
    );
    if (submitted != true || action == null) return;

    final trigger = <String, Object?>{
      'type': type,
      if (type == 'corner_taps' || type == 'corner_hold') 'corner': corner,
      if (type == 'corner_taps') 'taps': taps,
      if (type == 'finger_taps' || type == 'finger_hold') 'fingers': fingers,
      if (type == 'finger_taps') 'taps': fingerTaps,
      if (type == 'corner_hold' || type == 'finger_hold') 'holdMs': holdMs,
      if (type == 'corner_sequence') 'sequence': sequence,
      if (type == 'claps') 'claps': claps,
      if (type == 'fingers') 'fingers': fingerCount,
    };
    final mapping = GestureMapping(
      id: existing?.id ?? 'g${DateTime.now().millisecondsSinceEpoch}',
      trigger: trigger,
      action: action!,
    );
    final mappings = [..._mappings];
    final index = mappings.indexWhere((m) => m.id == mapping.id);
    if (index >= 0) {
      mappings[index] = mapping;
    } else {
      mappings.add(mapping);
    }
    await _save(mappings);
  }

  /// The action chooser, then the chosen type's own configuration dialog.
  Future<Map<String, Object?>?> _configurePluginAction() async {
    final actions = c.plugins.actions
        .where((action) => action['available'] == true)
        .toList();
    return showDialog<Map<String, Object?>>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(gestureText(context, 'Plugin action')),
        children: [
          if (actions.isEmpty)
            Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                gestureText(
                  context,
                  'Enable a plugin with actions in Plugin Manager first.',
                ),
              ),
            ),
          for (final action in actions)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, <String, Object?>{
                'type': 'plugin_action',
                'pluginId': action['pluginId'],
                'command': action['command'],
                'pluginName': action['pluginName'],
                'title': action['title'],
              }),
              child: ListTile(
                title: Text('${action['title']}'),
                subtitle: Text('${action['pluginName']}'),
              ),
            ),
        ],
      ),
    );
  }

  Future<Map<String, Object?>?> _pickAction(
    Map<String, Object?>? current,
  ) async {
    final type = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(gestureText(context, 'Action')),
        children: [
          for (final (group, actions) in _actionGroups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
              child: Text(
                group,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            for (final (value, label, icon) in actions)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, value),
                child: Row(
                  children: [
                    Icon(icon, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text(gestureText(context, label))),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
    if (type == null || !mounted) return null;
    final carried = current != null && '${current['type']}' == type
        ? current
        : null;
    return switch (type) {
      'plugin_action' => _configurePluginAction(),
      // Actions with nothing to configure skip the second dialog.
      'android_settings' ||
      'sendspin_player' ||
      'now_playing' ||
      'music_assistant' ||
      'app_launcher' ||
      'intercom_open' ||
      'screensaver' ||
      'screensaver_stop' ||
      'hold_mode' ||
      'ha_kiosk' => {'type': type},
      'navigate' => _configureNavigate(carried),
      'url' => _configureText(
        carried,
        type: 'url',
        title: 'Open a web page',
        field: 'url',
        label: 'URL',
        hint: 'https://example.com',
        keyboard: TextInputType.url,
        validate: (v) {
          final uri = Uri.tryParse(v);
          return uri != null &&
                  (uri.scheme == 'http' || uri.scheme == 'https') &&
                  uri.host.isNotEmpty
              ? null
              : 'Enter a full http(s) URL.';
        },
      ),
      'camera_view' => _configureCameraView(carried),
      'intercom_call' => _configureIntercomCall(carried),
      'launch_app' => _configureText(
        carried,
        type: 'launch_app',
        title: 'Open another app',
        field: 'package',
        label: 'Package name',
        hint: 'com.android.deskclock',
        validate: (v) => v.contains('.') ? null : 'Enter a package name.',
      ),
      'open_uri' => _configureText(
        carried,
        type: 'open_uri',
        title: 'Open a deep link',
        field: 'uri',
        label: 'URI',
        hint: 'myapp://path',
        keyboard: TextInputType.url,
        validate: (v) =>
            Uri.tryParse(v)?.hasScheme == true ? null : 'Enter a full URI.',
      ),
      'ha_service' => _configureHaService(carried),
      'ha_script' => _configureHaEntity(
        carried,
        type: 'ha_script',
        title: 'Run a script',
        label: 'Script entity',
        hint: 'script.good_morning',
        domain: 'script',
        service: 'turn_on',
      ),
      'ha_automation' => _configureHaEntity(
        carried,
        type: 'ha_automation',
        title: 'Trigger an automation',
        label: 'Automation entity',
        hint: 'automation.lights_off',
        domain: 'automation',
        service: 'trigger',
      ),
      'ha_event' => _configureHaEvent(carried),
      _ => Future<Map<String, Object?>?>.value(),
    };
  }

  /// One required text field; the shape of the URL, app and deep link
  /// dialogs.
  Future<Map<String, Object?>?> _configureText(
    Map<String, Object?>? current, {
    required String type,
    required String title,
    required String field,
    required String label,
    required String hint,
    required String? Function(String) validate,
    TextInputType? keyboard,
  }) async {
    final controller = TextEditingController(text: '${current?[field] ?? ''}');
    String? error;
    final route = DialogRoute<Map<String, Object?>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void submit() {
            final value = controller.text.trim();
            final invalid = validate(value);
            if (invalid != null) {
              setDialogState(() => error = invalid);
              return;
            }
            Navigator.pop(context, {'type': type, field: value});
          }

          return AlertDialog(
            title: Text(gestureText(context, title)),
            content: SizedBox(
              width: 480,
              child: LabeledField(
                label: gestureText(context, label),
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: keyboard,
                  decoration: InputDecoration(
                    hintText: hint,
                    errorText: error == null
                        ? null
                        : gestureError(context, error!),
                  ),
                  onSubmitted: (_) => submit(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(gestureText(context, 'Cancel')),
              ),
              FilledButton(
                onPressed: submit,
                child: Text(gestureText(context, 'OK')),
              ),
            ],
          );
        },
      ),
    );
    final result = await Navigator.of(context).push(route);
    await route.completed;
    controller.dispose();
    return result;
  }

  /// Run haValidateAction and reduce its answer to one sentence for the
  /// dialog's status line. Returns (ok, message).
  Future<(bool, String)> _validateHaAction({
    required String domain,
    required String service,
    String entity = '',
  }) async {
    final result = await c.commands.execute('haValidateAction', {
      'domain': domain,
      'service': service,
      if (entity.isNotEmpty) 'entity_id': entity,
    });
    if (!result.ok) return (false, result.error ?? 'Could not validate.');
    final data = result.data is Map ? result.data as Map : const {};
    if (data['domain'] == false) return (false, 'Domain $domain not found.');
    if (data['service'] == false) {
      return (false, 'Service $domain.$service not found.');
    }
    if (data['entity'] == false) return (false, 'Entity $entity not found.');
    return (true, 'Looks good.');
  }

  /// The dialog's Validate row: button plus status line.
  Widget _validateRow(
    BuildContext context, {
    required bool checking,
    required (bool, String)? verdict,
    required VoidCallback onValidate,
  }) => Row(
    children: [
      TextButton.icon(
        onPressed: checking ? null : onValidate,
        icon: checking
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.checklist_outlined, size: 18),
        label: Text(gestureText(context, 'Validate')),
      ),
      const SizedBox(width: 8),
      if (verdict != null)
        Expanded(
          child: Text(
            gestureError(context, verdict.$2),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: verdict.$1
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
            ),
          ),
        ),
    ],
  );

  /// One Home Assistant entity plus a Validate check: the script and
  /// automation dialogs.
  Future<Map<String, Object?>?> _configureHaEntity(
    Map<String, Object?>? current, {
    required String type,
    required String title,
    required String label,
    required String hint,
    required String domain,
    required String service,
  }) async {
    final entity = TextEditingController(text: '${current?['entityId'] ?? ''}');
    String? error;
    var checking = false;
    (bool, String)? verdict;
    // A bare name is obviously meant as one of this domain's entities.
    String qualified() {
      final value = entity.text.trim();
      return value.isEmpty || value.contains('.') ? value : '$domain.$value';
    }

    final route = DialogRoute<Map<String, Object?>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void submit() {
            final value = qualified();
            if (!value.startsWith('$domain.') ||
                value.length <= domain.length + 1) {
              setDialogState(() => error = 'Enter a $domain.* entity.');
              return;
            }
            Navigator.pop(context, {'type': type, 'entityId': value});
          }

          return AlertDialog(
            title: Text(gestureText(context, title)),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 16,
                children: [
                  LabeledField(
                    label: gestureText(context, label),
                    child: TextField(
                      controller: entity,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: hint,
                        errorText: error == null
                            ? null
                            : gestureError(context, error!),
                      ),
                      onSubmitted: (_) => submit(),
                    ),
                  ),
                  _validateRow(
                    context,
                    checking: checking,
                    verdict: verdict,
                    onValidate: () async {
                      setDialogState(() {
                        checking = true;
                        verdict = null;
                      });
                      final checked = await _validateHaAction(
                        domain: domain,
                        service: service,
                        entity: qualified(),
                      );
                      if (!context.mounted) return;
                      setDialogState(() {
                        checking = false;
                        verdict = checked;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(gestureText(context, 'Cancel')),
              ),
              FilledButton(
                onPressed: submit,
                child: Text(gestureText(context, 'OK')),
              ),
            ],
          );
        },
      ),
    );
    final result = await Navigator.of(context).push(route);
    await route.completed;
    entity.dispose();
    return result;
  }

  Future<Map<String, Object?>?> _configureNavigate(
    Map<String, Object?>? current,
  ) async {
    // Fetch every dashboard's views up front; the radio list mirrors the
    // rotation picker's "dashboard / view" flattening.
    final entries = <(String, String)>[];
    final dashboards = await c.commands.execute('haListDashboards', const {});
    if (dashboards.ok && dashboards.data is List) {
      for (final d in dashboards.data as List) {
        if (d is! Map) continue;
        final urlPath = '${d['url_path'] ?? ''}';
        final title = '${d['title'] ?? urlPath}';
        if (urlPath.isEmpty) continue;
        final views = await c.commands.execute('haListDashboardViews', {
          'url_path': urlPath,
        });
        var added = false;
        if (views.ok && views.data is List) {
          for (final v in views.data as List) {
            if (v is! Map) continue;
            final route = '${v['route'] ?? ''}';
            if (route.isEmpty) continue;
            entries.add(('$urlPath/$route', '$title / ${v['title'] ?? route}'));
            added = true;
          }
        }
        // Strategy dashboards expose no views; the dashboard root still
        // makes a fine target.
        if (!added) entries.add((urlPath, title));
      }
    }
    if (!mounted) return null;
    if (entries.isEmpty) {
      showToast(
        context,
        title: gestureText(context, 'Could not list dashboards'),
        message: gestureText(context, 'Is Home Assistant connected?'),
        kind: ToastKind.error,
      );
      return null;
    }
    final currentPath = '${current?['path'] ?? ''}';
    return showDialog<Map<String, Object?>>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(gestureText(context, 'Go to a dashboard view')),
        children: [
          for (final (path, label) in entries)
            ListTile(
              leading: Icon(
                currentPath == path
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              title: Text(label),
              onTap: () =>
                  Navigator.pop(context, {'type': 'navigate', 'path': path}),
            ),
        ],
      ),
    );
  }

  /// The kiosk a Call a kiosk gesture rings: every kiosk the intercom
  /// has heard, whatever its state today, since a mapping outlives a
  /// kiosk being off for the afternoon.
  Future<Map<String, Object?>?> _configureIntercomCall(
    Map<String, Object?>? current,
  ) async {
    final r = await c.commands.execute('intercomStatus', const {});
    final kiosks = [
      for (final k in ((r.data as Map?)?['kiosks'] as List? ?? const []))
        if (k is Map) k.cast<String, Object?>(),
    ];
    if (!mounted) return null;
    final currentId = '${current?['kioskId'] ?? ''}';
    return showDialog<Map<String, Object?>>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(gestureText(context, 'Call a kiosk')),
        children: [
          for (final k in kiosks)
            ListTile(
              leading: Icon(
                currentId == '${k['id']}'
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              title: Text('${k['name']}'),
              subtitle: Text('${k['address']}'),
              onTap: () => Navigator.pop(context, {
                'type': 'intercom_call',
                'kioskId': '${k['id']}',
                'kioskName': '${k['name']}',
              }),
            ),
          if (kiosks.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: Text(
                gestureText(context, 'No kiosk found on the network yet.'),
              ),
            ),
        ],
      ),
    );
  }

  Future<Map<String, Object?>?> _configureCameraView(
    Map<String, Object?>? current,
  ) async {
    final views = c.camera.config.views;
    final currentMode = '${current?['mode'] ?? 'show'}';
    final currentView = '${current?['viewId'] ?? ''}';
    return showDialog<Map<String, Object?>>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(gestureText(context, 'Camera view')),
        children: [
          for (final view in views)
            ListTile(
              leading: Icon(
                currentMode == 'show' && currentView == view.id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              title: Text(l10n(context).gestureCameraShow(view.name)),
              onTap: () => Navigator.pop(context, {
                'type': 'camera_view',
                'mode': 'show',
                'viewId': view.id,
                'viewName': view.name,
              }),
            ),
          ListTile(
            leading: Icon(
              currentMode == 'hide'
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
            ),
            title: Text(gestureText(context, 'Close the camera view')),
            onTap: () =>
                Navigator.pop(context, {'type': 'camera_view', 'mode': 'hide'}),
          ),
          if (views.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: Text(
                gestureText(context, 'No camera views configured yet.'),
              ),
            ),
        ],
      ),
    );
  }

  Future<Map<String, Object?>?> _configureHaService(
    Map<String, Object?>? current,
  ) async {
    final domain = TextEditingController(text: '${current?['domain'] ?? ''}');
    final service = TextEditingController(text: '${current?['service'] ?? ''}');
    final entity = TextEditingController(text: '${current?['entityId'] ?? ''}');
    final data = TextEditingController(
      text: current?['data'] is Map ? jsonEncode(current!['data']) : '',
    );
    String? error;
    var checking = false;
    (bool, String)? verdict;
    final route = DialogRoute<Map<String, Object?>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void submit() {
            if (domain.text.trim().isEmpty || service.text.trim().isEmpty) {
              setDialogState(() => error = 'Domain and service are required.');
              return;
            }
            Object? parsed;
            if (data.text.trim().isNotEmpty) {
              try {
                parsed = jsonDecode(data.text);
                if (parsed is! Map) throw const FormatException();
              } catch (_) {
                setDialogState(
                  () => error = 'Service data must be a JSON object.',
                );
                return;
              }
            }
            Navigator.pop(context, {
              'type': 'ha_service',
              'domain': domain.text.trim(),
              'service': service.text.trim(),
              if (entity.text.trim().isNotEmpty) 'entityId': entity.text.trim(),
              'data': ?parsed,
            });
          }

          return AlertDialog(
            title: Text(gestureText(context, 'Call a Home Assistant service')),
            content: SizedBox(
              width: 480,
              child: EdgeFade(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 16,
                    children: [
                      LabeledField(
                        label: gestureText(context, 'Domain'),
                        child: TextField(
                          controller: domain,
                          decoration: const InputDecoration(hintText: 'light'),
                        ),
                      ),
                      LabeledField(
                        label: gestureText(context, 'Service'),
                        child: TextField(
                          controller: service,
                          decoration: const InputDecoration(
                            hintText: 'turn_on',
                          ),
                        ),
                      ),
                      LabeledField(
                        label: gestureText(context, 'Entity (optional)'),
                        child: TextField(
                          controller: entity,
                          decoration: const InputDecoration(
                            hintText: 'light.kitchen',
                          ),
                        ),
                      ),
                      LabeledField(
                        label: gestureText(context, 'Service data (optional)'),
                        child: TextField(
                          controller: data,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: '{"brightness_pct": 60}',
                            errorText: error == null
                                ? null
                                : gestureError(context, error!),
                          ),
                        ),
                      ),
                      _validateRow(
                        context,
                        checking: checking,
                        verdict: verdict,
                        onValidate: () async {
                          if (domain.text.trim().isEmpty ||
                              service.text.trim().isEmpty) {
                            setDialogState(
                              () => verdict = (
                                false,
                                'Domain and service are required.',
                              ),
                            );
                            return;
                          }
                          setDialogState(() {
                            checking = true;
                            verdict = null;
                          });
                          final checked = await _validateHaAction(
                            domain: domain.text.trim(),
                            service: service.text.trim(),
                            entity: entity.text.trim(),
                          );
                          if (!context.mounted) return;
                          setDialogState(() {
                            checking = false;
                            verdict = checked;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(gestureText(context, 'Cancel')),
              ),
              FilledButton(
                onPressed: submit,
                child: Text(gestureText(context, 'OK')),
              ),
            ],
          );
        },
      ),
    );
    final result = await Navigator.of(context).push(route);
    await route.completed;
    domain.dispose();
    service.dispose();
    entity.dispose();
    data.dispose();
    return result;
  }

  Future<Map<String, Object?>?> _configureHaEvent(
    Map<String, Object?>? current,
  ) async {
    final event = TextEditingController(text: '${current?['event'] ?? ''}');
    final data = TextEditingController(
      text: current?['data'] is Map ? jsonEncode(current!['data']) : '',
    );
    String? error;
    final route = DialogRoute<Map<String, Object?>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void submit() {
            if (event.text.trim().isEmpty) {
              setDialogState(() => error = 'Event type is required.');
              return;
            }
            Object? parsed;
            if (data.text.trim().isNotEmpty) {
              try {
                parsed = jsonDecode(data.text);
                if (parsed is! Map) throw const FormatException();
              } catch (_) {
                setDialogState(
                  () => error = 'Event data must be a JSON object.',
                );
                return;
              }
            }
            Navigator.pop(context, {
              'type': 'ha_event',
              'event': event.text.trim(),
              'data': ?parsed,
            });
          }

          return AlertDialog(
            title: Text(gestureText(context, 'Fire a Home Assistant event')),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 16,
                children: [
                  LabeledField(
                    label: gestureText(context, 'Event type'),
                    child: TextField(
                      controller: event,
                      decoration: InputDecoration(
                        hintText: 'kiosk_satellite_gesture',
                        errorText: error == null
                            ? null
                            : gestureError(context, error!),
                      ),
                    ),
                  ),
                  LabeledField(
                    label: gestureText(context, 'Event data (optional)'),
                    child: TextField(
                      controller: data,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: '{"room": "kitchen"}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(gestureText(context, 'Cancel')),
              ),
              FilledButton(
                onPressed: submit,
                child: Text(gestureText(context, 'OK')),
              ),
            ],
          );
        },
      ),
    );
    final result = await Navigator.of(context).push(route);
    await route.completed;
    event.dispose();
    data.dispose();
    return result;
  }
}
