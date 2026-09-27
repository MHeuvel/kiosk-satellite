import 'dart:async';

import 'package:flutter/material.dart';

import '../app_container.dart';
import '../core/events.dart';
import '../l10n/messages.dart';
import '../managers/settings/definitions.dart' as defs;
import 'assist/assist_art.dart';
import 'assist/assist_skins.dart';
import 'kit.dart';
import 'theme.dart';
import 'toast.dart';

/// The notice on the Voice Satellite page while the kiosk still runs the
/// integration's engine in the dashboard, with the way out.
class VoiceMigrationNotice extends StatelessWidget {
  const VoiceMigrationNotice({super.key, required this.container});

  final AppContainer container;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = voiceText(
      context,
      'Voice Satellite is currently installed as an integration in Home '
      'Assistant. Migrate to a native experience inside Kiosk Satellite.',
    );
    final button = FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.onTertiaryContainer,
        foregroundColor: scheme.tertiaryContainer,
      ),
      onPressed: () => showVoiceMigrationWizard(context, container),
      child: Text(voiceText(context, 'Migrate')),
    );
    final body = Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        fontSize: 13.5,
        height: 1.45,
        color: scheme.onTertiaryContainer,
      ),
    );
    final icon = Icon(
      Icons.warning_amber_rounded,
      size: 20,
      color: scheme.onTertiaryContainer,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: Ks.cardGap),
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: tightPane(context)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 12,
                  children: [
                    icon,
                    Expanded(child: body),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: button,
                ),
              ],
            )
          : Row(
              spacing: 12,
              children: [
                icon,
                Expanded(child: body),
                button,
              ],
            ),
    );
  }
}

/// The top of the native Voice Satellite page: whether it runs, what Home
/// Assistant calls it, or what is missing before it can.
class VoiceStatusCard extends StatefulWidget {
  const VoiceStatusCard({
    super.key,
    required this.container,
    required this.rows,
  });

  final AppContainer container;

  /// The setting rows that follow the status in the same card (enable,
  /// mute, background listening).
  final List<Widget> rows;

  @override
  State<VoiceStatusCard> createState() => _VoiceStatusCardState();
}

class _VoiceStatusCardState extends State<VoiceStatusCard> {
  AppContainer get c => widget.container;
  StreamSubscription<Object?>? _wakeSub;

  @override
  void initState() {
    super.initState();
    c.voice.homeAssistant.addListener(_changed);
    _wakeSub = c.bus.on<WakeWordStateChanged>().listen((_) => _changed());
  }

  @override
  void dispose() {
    c.voice.homeAssistant.removeListener(_changed);
    _wakeSub?.cancel();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final settings = c.settings;
    final scheme = Theme.of(context).colorScheme;
    final enabled = settings.get(defs.voiceEnabled);
    final ha = c.voice.homeAssistant.value;
    final esphome = settings.get(defs.esphomeEnabled);
    final muted = settings.get(defs.voiceMute);
    final listening = c.wakeWord.listening;
    Widget statusWord(String text, Color color) => Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.w500,
      ),
    );
    final rows = <Widget>[
      ...widget.rows.take(1),
      if (enabled) ...[
        SettingsRow(
          title: Text(voiceText(context, 'Status')),
          subtitle: Text(
            !esphome
                ? voiceText(context, 'The ESPHome server is off.')
                : !ha.subscribed
                ? voiceText(
                    context,
                    'This kiosk is not added to Home Assistant yet.',
                  )
                : muted
                ? voiceText(context, 'The microphone is muted.')
                : voiceText(context, 'Listening for the wake word.'),
          ),
          trailing: statusWord(
            !esphome || !ha.subscribed
                ? voiceText(context, 'Not added')
                : muted
                ? voiceText(context, 'Muted')
                : listening
                ? voiceText(context, 'Listening')
                : voiceText(context, 'Busy'),
            !esphome || !ha.subscribed
                ? scheme.tertiary
                : muted
                ? scheme.onSurfaceVariant
                : scheme.primary,
          ),
        ),
        SettingsRow(
          title: Text(voiceText(context, 'Home Assistant')),
          subtitle: Text(
            ha.satelliteEntity.isNotEmpty
                ? ha.satelliteEntity
                : esphome
                ? voiceText(
                    context,
                    'Add this kiosk under Settings, Devices & services in '
                    'Home Assistant, where it shows up as discovered.',
                  )
                : voiceText(
                    context,
                    'Turn on the ESPHome server so Home Assistant can add '
                    'this kiosk as a satellite.',
                  ),
          ),
          trailing: esphome
              ? statusWord(
                  ha.satelliteEntity.isNotEmpty
                      ? voiceText(context, 'Added')
                      : voiceText(context, 'Not added'),
                  ha.satelliteEntity.isNotEmpty
                      ? scheme.primary
                      : scheme.tertiary,
                )
              : FilledButton(
                  onPressed: () async {
                    await settings.set(defs.esphomeEnabled, true);
                    _changed();
                  },
                  child: Text(voiceText(context, 'Turn on')),
                ),
        ),
      ],
      ...widget.rows.skip(1),
    ];
    return SettingsCard(children: rows);
  }
}

/// One of Home Assistant's selects on the kiosk's device (the Assistant
/// and Wake word pickers), as a dropdown row that writes it live.
class VoiceHaSelects extends StatefulWidget {
  const VoiceHaSelects({
    super.key,
    required this.container,
    required this.rows,
  });

  final AppContainer container;

  /// (key, title, description) per row, keys as voiceHaSelects answers.
  final List<(String, String, String)> rows;

  @override
  State<VoiceHaSelects> createState() => _VoiceHaSelectsState();
}

class _VoiceHaSelectsState extends State<VoiceHaSelects> {
  Map<String, Object?>? _data;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    // Home Assistant, a voice command or the remote admin can change them.
    _poll = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && ModalRoute.of(context)?.isCurrent != false) {
        unawaited(_load());
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final result = await widget.container.commands.execute(
      'voiceHaSelects',
      const {},
    );
    if (!mounted) return;
    setState(
      () => _data = result.ok && result.data is Map
          ? (result.data as Map).cast<String, Object?>()
          : const {},
    );
  }

  String _label(String key, String option) {
    if (option == 'preferred') return voiceText(context, 'Preferred');
    if (option == 'no_wake_word') return voiceText(context, 'None');
    if (key == 'vad_sensitivity') return voiceVadOption(context, option);
    return option;
  }

  Future<void> _set(String key, String option) async {
    final entity = (_data?[key] as Map?)?.cast<String, Object?>();
    if (entity != null) setState(() => entity['state'] = option);
    await widget.container.commands.execute('voiceSelectOption', {
      'key': key,
      'option': option,
    });
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (key, title, description) in widget.rows)
          _row(context, key, title, description, data[key]),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    String key,
    String title,
    String description,
    Object? raw,
  ) {
    final entity = raw is Map ? raw.cast<String, Object?>() : null;
    final options = [
      for (final o in (entity?['options'] as List? ?? const [])) '$o',
    ];
    if (entity == null || entity['available'] != true || options.isEmpty) {
      return SettingsRow(
        title: Text(voiceText(context, title)),
        subtitle: Text(voiceText(context, description)),
        trailing: Text(
          voiceText(context, 'Not available'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    final state = '${entity['state'] ?? ''}';
    return DropdownRow<String>(
      title: voiceText(context, title),
      description: voiceText(context, description),
      value: options.contains(state) ? state : null,
      options: [for (final o in options) (o, _label(key, o))],
      onChanged: (v) {
        if (v != null && v != state) unawaited(_set(key, v));
      },
    );
  }
}

/// The Skin row: the current skin as a thumbnail and name, opening the
/// picker.
class VoiceSkinRow extends StatelessWidget {
  const VoiceSkinRow({
    super.key,
    required this.container,
    required this.onChanged,
  });

  final AppContainer container;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final skin = assistSkinById(container.settings.get(defs.voiceSkin));
    return SettingsRow(
      title: Text(voiceText(context, 'Skin')),
      subtitle: Text(
        voiceText(context, 'The look of the voice assistant overlay.'),
      ),
      onTap: () async {
        final picked = await showVoiceSkinPicker(context, container);
        if (picked != null) {
          await container.settings.set(defs.voiceSkin, picked);
          onChanged();
        }
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 56,
              height: 35,
              child: VoiceSkinThumbnail(
                skin: skin,
                dark: _dark(context, container, skin),
              ),
            ),
          ),
          Text(skin.name),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

bool _dark(BuildContext context, AppContainer container, AssistSkin skin) =>
    skin.darkOnly ||
    switch (container.settings.get(defs.voiceTheme)) {
      'dark' => true,
      'light' => false,
      _ => Theme.of(context).brightness == Brightness.dark,
    };

/// A skin in miniature: its backdrop, its art listening, a line of text.
class VoiceSkinThumbnail extends StatelessWidget {
  const VoiceSkinThumbnail({
    super.key,
    required this.skin,
    required this.dark,
    this.text = true,
  });

  final AssistSkin skin;
  final bool dark;
  final bool text;

  static final _level = ValueNotifier<double>(0.4);
  static final _clock = ArtClock.still();

  @override
  Widget build(BuildContext context) {
    final palette = skin.palette(dark);
    return LayoutBuilder(
      builder: (context, box) {
        // The art draws at kiosk scale; the thumbnail shrinks all of it.
        const width = 960.0;
        final height = width * box.maxHeight / box.maxWidth;
        return FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                SkinBackdrop(skin: skin, color: palette.backdrop),
                SkinBarLayer(
                  skin: skin,
                  mode: ArtMode.speaking,
                  reactive: true,
                  level: _level,
                  clock: _clock,
                ),
                if (text)
                  Positioned(
                    left: width * 0.075,
                    right: width * 0.075,
                    bottom: skin.chatBottomReactive + 4,
                    child: Text(
                      'Sunny and 72° right now.',
                      textAlign: skin.centered
                          ? TextAlign.center
                          : TextAlign.start,
                      style: TextStyle(
                        fontFamily: skin.font,
                        fontSize: skin.answerSize,
                        fontWeight: skin.answerWeight,
                        color: palette.answer,
                        shadows: [
                          for (final s in palette.answerShadows) s.shadow,
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Every skin as a live thumbnail, the current one ringed.
Future<String?> showVoiceSkinPicker(
  BuildContext context,
  AppContainer container,
) {
  final current = container.settings.get(defs.voiceSkin);
  return showDialog<String>(
    context: context,
    builder: (context) {
      final wide = MediaQuery.sizeOf(context).width >= 640;
      return AlertDialog(
        title: Text(voiceText(context, 'Skin')),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        content: SizedBox(
          width: wide ? 560 : 320,
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: wide ? 3 : 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.25,
            children: [
              for (final skin in assistSkins)
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.of(context).pop(skin.id),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 6,
                    children: [
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              width: skin.id == current ? 3 : 1,
                              color: skin.id == current
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).dividerColor,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: VoiceSkinThumbnail(
                              skin: skin,
                              dark: _dark(context, container, skin),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        skin.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// The Background row: a slider whose far left reads Skin default.
class VoiceBackgroundRow extends StatelessWidget {
  const VoiceBackgroundRow({
    super.key,
    required this.container,
    required this.onChanged,
  });

  final AppContainer container;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final value = container.settings
        .get(defs.voiceBackgroundOpacity)
        .toDouble();
    final label = value < 0
        ? voiceText(context, 'Skin default')
        : '${value.round()}%';
    return Padding(
      padding: const EdgeInsets.fromLTRB(Ks.inset, 12, Ks.inset, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      voiceText(context, 'Background'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      voiceText(
                        context,
                        'How much of the dashboard shows through.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(label),
            ],
          ),
          Slider(
            min: -5,
            max: 100,
            divisions: 21,
            value: value < 0 ? -5 : value,
            onChanged: (v) async {
              await container.settings.set(
                defs.voiceBackgroundOpacity,
                v < 0 ? -1 : v.roundToDouble(),
              );
              onChanged();
            },
          ),
        ],
      ),
    );
  }
}

/// The Preview row: the overlay over the screen for five seconds.
class VoicePreviewRow extends StatelessWidget {
  const VoicePreviewRow({super.key, required this.container});

  final AppContainer container;

  @override
  Widget build(BuildContext context) => SettingsRow(
    title: Text(voiceText(context, 'Preview')),
    subtitle: Text(
      voiceText(context, 'Show the overlay on this screen for five seconds.'),
    ),
    trailing: OutlinedButton(
      onPressed: () {
        Navigator.of(context).popUntil((route) => route.isFirst);
        unawaited(container.commands.execute('voicePreview', const {}));
      },
      child: Text(voiceText(context, 'Preview')),
    ),
  );
}

/// Run from the dashboard again, while the integration is still installed.
class VoiceRollbackCard extends StatelessWidget {
  const VoiceRollbackCard({super.key, required this.container});

  final AppContainer container;

  @override
  Widget build(BuildContext context) => SettingsCard(
    children: [
      SettingsRow(
        title: Text(voiceText(context, 'Run from the dashboard again')),
        subtitle: Text(
          voiceText(
            context,
            'Go back to the Voice Satellite integration. Nothing set here is '
            'lost.',
          ),
        ),
        trailing: OutlinedButton(
          onPressed: () async {
            final ok = await showConfirmDialog(
              context,
              title: voiceText(context, 'Run from the dashboard again?'),
              message: voiceText(
                context,
                'The dashboard runs Voice Satellite again through the '
                'integration, with the settings it had before. What you set '
                'here stays for next time.',
              ),
              confirmLabel: voiceText(context, 'Switch back'),
            );
            if (ok) {
              await container.commands.execute('vsRollback', const {});
            }
          },
          child: Text(voiceText(context, 'Switch back')),
        ),
      ),
    ],
  );
}

// ── the migration wizard ─────────────────────────────────────────────────

Future<void> showVoiceMigrationWizard(
  BuildContext context,
  AppContainer container,
) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (context) => _MigrationWizard(container: container),
);

class _MigrationWizard extends StatefulWidget {
  const _MigrationWizard({required this.container});
  final AppContainer container;

  @override
  State<_MigrationWizard> createState() => _MigrationWizardState();
}

class _MigrationWizardState extends State<_MigrationWizard> {
  AppContainer get c => widget.container;

  int _step = 0;
  Map<String, Object?>? _check;
  Map<String, Object?>? _plan;
  List<Map<String, Object?>>? _automations;
  final _groups = <String>{
    'voice',
    'appearance',
    'conversation',
    'assistant',
    'timers',
  };
  bool _switching = false;
  Map<String, Object?>? _result;

  @override
  void initState() {
    super.initState();
    unawaited(_runCheck());
    c.voice.migrationSteps.addListener(_changed);
  }

  @override
  void dispose() {
    c.voice.migrationSteps.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _runCheck() async {
    setState(() => _check = null);
    final result = await c.commands.execute('voiceMigrationCheck', const {});
    if (!mounted) return;
    setState(
      () => _check = result.ok && result.data is Map
          ? (result.data as Map).cast<String, Object?>()
          : const {'checks': [], 'ready': false},
    );
  }

  Future<void> _loadPlan() async {
    final result = await c.commands.execute('voiceMigrationPlan', const {});
    if (!mounted) return;
    setState(
      () => _plan = result.ok && result.data is Map
          ? (result.data as Map).cast<String, Object?>()
          : const {'groups': []},
    );
  }

  Future<void> _loadAutomations() async {
    final result = await c.commands.execute(
      'voiceMigrationAutomations',
      const {},
    );
    if (!mounted) return;
    final items = result.ok && result.data is Map
        ? (result.data as Map)['items']
        : null;
    setState(
      () => _automations = [
        for (final i in (items as List? ?? const []))
          if (i is Map) i.cast<String, Object?>(),
      ],
    );
  }

  Future<void> _switch() async {
    setState(() {
      _switching = true;
      _step = 4;
    });
    final result = await c.commands.execute('vsMigrate', {
      'groups': _groups.toList(),
    });
    if (!mounted) return;
    setState(() {
      _switching = false;
      _result = {
        'ok': result.ok,
        'error': result.error,
        'fallbacks': result.data is Map
            ? (result.data as Map)['fallbacks']
            : null,
      };
    });
  }

  Widget _stepper(int n) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        spacing: 8,
        children: [
          for (var i = 0; i < 4; i++)
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: i < n
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          Text(
            voiceText(context, 'Step {n} of 4').replaceAll('{n}', '$n'),
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _checkRow(Map<String, Object?> check) {
    final scheme = Theme.of(context).colorScheme;
    final ok = check['ok'] == true;
    final warnOnly = check['warnOnly'] == true;
    final (title, good, bad) = switch (check['id']) {
      'homeAssistant' => (
        'Home Assistant',
        'Connected.',
        'Not connected. Check Home Assistant Setup.',
      ),
      'esphome' => (
        'This kiosk in Home Assistant',
        'Added through ESPHome.',
        check['esphomeOn'] == true
            ? 'Not added yet. Home Assistant lists this kiosk as discovered '
                  'under Settings, Devices & services. Add it there, then '
                  'come back.'
            : 'The ESPHome server is off. Turn it on, then add this kiosk in '
                  'Home Assistant.',
      ),
      'admin' => (
        'Administrator token',
        'Tool use and results will show.',
        'The token is a regular user\'s. Voice Satellite works, tool use '
            'and results will not show.',
      ),
      'microphone' => (
        'Microphone',
        'Allowed.',
        'Not allowed. Grant it under Required system permissions.',
      ),
      _ => ('${check['id']}', '', ''),
    };
    final color = ok
        ? scheme.primary
        : warnOnly
        ? scheme.tertiary
        : scheme.error;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 14,
        children: [
          Icon(
            ok
                ? Icons.check_circle_outline
                : warnOnly
                ? Icons.warning_amber_rounded
                : Icons.error_outline,
            color: color,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  voiceText(context, title),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  voiceText(context, ok ? good : bad),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ok ? scheme.onSurfaceVariant : color,
                  ),
                ),
              ],
            ),
          ),
          if (check['id'] == 'esphome' && check['esphomeOn'] != true)
            TextButton(
              onPressed: () async {
                await c.settings.set(defs.esphomeEnabled, true);
                await _runCheck();
              },
              child: Text(voiceText(context, 'Turn on ESPHome')),
            ),
        ],
      ),
    );
  }

  static const _groupTitles = {
    'voice': 'Voice',
    'appearance': 'Appearance',
    'conversation': 'Conversation',
    'assistant': 'Assistant',
    'timers': 'Timers',
  };

  @override
  Widget build(BuildContext context) {
    final (title, body, actions) = switch (_step) {
      0 => _stepOne(),
      1 => _stepTwo(),
      2 => _stepThree(),
      3 => _stepFour(),
      _ => _switchingStep(),
    };
    return AlertDialog(
      title: title == null ? null : Text(title),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: body,
          ),
        ),
      ),
      actions: actions,
    );
  }

  (String?, List<Widget>, List<Widget>) _stepOne() {
    final check = _check;
    final checks = [
      for (final raw in (check?['checks'] as List? ?? const []))
        if (raw is Map) raw.cast<String, Object?>(),
    ];
    return (
      voiceText(context, 'Migrate Voice Satellite'),
      [
        _stepper(1),
        Text(
          voiceText(
            context,
            'This kiosk becomes the voice satellite itself. The Voice '
            'Satellite integration is not needed after this.',
          ),
        ),
        const SizedBox(height: 8),
        if (check == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          for (final c in checks) _checkRow(c),
      ],
      [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(voiceText(context, 'Cancel')),
        ),
        if (check != null && check['ready'] != true)
          TextButton(
            onPressed: _runCheck,
            child: Text(voiceText(context, 'Check again')),
          ),
        FilledButton(
          onPressed: check?['ready'] == true
              ? () {
                  setState(() => _step = 1);
                  unawaited(_loadPlan());
                }
              : null,
          child: Text(voiceText(context, 'Next')),
        ),
      ],
    );
  }

  (String?, List<Widget>, List<Widget>) _stepTwo() {
    final plan = _plan;
    final groups = [
      for (final raw in (plan?['groups'] as List? ?? const []))
        if (raw is Map) raw.cast<String, Object?>(),
    ];
    final scheme = Theme.of(context).colorScheme;
    return (
      voiceText(context, 'Settings to bring over'),
      [
        _stepper(2),
        if (plan == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          for (final g in groups)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _groups.contains(g['id']),
              onChanged: (v) => setState(
                () => v == true
                    ? _groups.add('${g['id']}')
                    : _groups.remove('${g['id']}'),
              ),
              title: Text(
                voiceText(context, _groupTitles['${g['id']}'] ?? '${g['id']}'),
              ),
              subtitle: '${g['values']}'.isEmpty
                  ? null
                  : Text('${g['values']}'),
            ),
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              voiceText(
                context,
                'Not carried over: custom CSS, the browser microphone '
                'processing, answers on another speaker and the conversation '
                'memory length. Custom microWakeWord models work from '
                'config/custom_wake_words in Home Assistant.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ],
      [
        TextButton(
          onPressed: () => setState(() => _step = 0),
          child: Text(voiceText(context, 'Back')),
        ),
        FilledButton(
          onPressed: plan == null
              ? null
              : () {
                  setState(() => _step = 2);
                  unawaited(_loadAutomations());
                },
          child: Text(voiceText(context, 'Next')),
        ),
      ],
    );
  }

  (String?, List<Widget>, List<Widget>) _stepThree() {
    final items = _automations;
    final satellite = '${_check?['satellite'] ?? ''}';
    return (
      voiceText(context, 'Automations and scripts'),
      [
        _stepper(3),
        if (items == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (items.isEmpty)
          Row(
            spacing: 12,
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              Expanded(
                child: Text(
                  voiceText(
                    context,
                    'Nothing in Home Assistant points at the old satellite.',
                  ),
                ),
              ),
            ],
          )
        else ...[
          Text(
            voiceText(
              context,
              'These still point at {satellite}. Edit them in Home Assistant '
              'to use this kiosk\'s satellite. The wizard does not change '
              'them.',
            ).replaceAll('{satellite}', satellite),
          ),
          const SizedBox(height: 8),
          for (final item in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                item['kind'] == 'Script'
                    ? Icons.code
                    : Icons.auto_mode_outlined,
              ),
              title: Text('${item['name']}'),
              subtitle: Text(
                '${voiceText(context, '${item['kind']}')} · '
                '${(item['refs'] as List? ?? const []).join(', ')}',
              ),
            ),
        ],
      ],
      [
        TextButton(
          onPressed: () => setState(() => _step = 1),
          child: Text(voiceText(context, 'Back')),
        ),
        FilledButton(
          onPressed: items == null ? null : () => setState(() => _step = 3),
          child: Text(voiceText(context, 'Next')),
        ),
      ],
    );
  }

  (String?, List<Widget>, List<Widget>) _stepFour() {
    final settings = (_plan?['groups'] as List? ?? const [])
        .whereType<Map>()
        .firstWhere(
          (g) => g['id'] == 'appearance',
          orElse: () => const {},
        )['settings'];
    final skinId = settings is Map
        ? '${settings[defs.voiceSkin.key] ?? c.settings.get(defs.voiceSkin)}'
        : c.settings.get(defs.voiceSkin);
    final skin = assistSkinById(skinId);
    return (
      voiceText(context, 'Ready to switch'),
      [
        _stepper(4),
        for (final line in [
          'This kiosk listens, answers and draws the overlay.',
          'The dashboard stops running Voice Satellite on this kiosk.',
          'The old satellite stays in Home Assistant, unused.',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('•  ${voiceText(context, line)}'),
          ),
        const SizedBox(height: 10),
        Row(
          spacing: 14,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 120,
                height: 75,
                child: VoiceSkinThumbnail(
                  skin: skin,
                  dark: _dark(context, c, skin),
                ),
              ),
            ),
            Expanded(
              child: Text(
                skin.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ],
      [
        TextButton(
          onPressed: () => setState(() => _step = 2),
          child: Text(voiceText(context, 'Back')),
        ),
        FilledButton(
          onPressed: _switch,
          child: Text(voiceText(context, 'Switch now')),
        ),
      ],
    );
  }

  (String?, List<Widget>, List<Widget>) _switchingStep() {
    final result = _result;
    final scheme = Theme.of(context).colorScheme;
    if (result != null) {
      final ok = result['ok'] == true;
      return (
        null,
        [
          const SizedBox(height: 8),
          Center(
            child: CircleAvatar(
              radius: 32,
              backgroundColor: ok
                  ? scheme.primaryContainer
                  : scheme.errorContainer,
              child: Icon(
                ok ? Icons.check : Icons.error_outline,
                size: 32,
                color: ok ? scheme.onPrimaryContainer : scheme.onErrorContainer,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            ok
                ? voiceText(context, 'Voice Satellite runs here now')
                : voiceText(context, 'Could not switch'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            ok
                ? voiceText(
                    context,
                    'Say the wake word to try it. Once no other device uses '
                    'the Voice Satellite integration, uninstall it from HACS.',
                  )
                : '${result['error'] ?? ''} ${voiceText(context, 'Voice Satellite runs from the dashboard again.')}',
            textAlign: TextAlign.center,
          ),
        ],
        [
          if (!ok)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(voiceText(context, 'Close')),
            ),
          FilledButton(
            onPressed: ok
                ? () => Navigator.of(context).pop()
                : () => setState(() {
                    _result = null;
                    _step = 3;
                  }),
            child: Text(
              ok ? voiceText(context, 'Done') : voiceText(context, 'Try again'),
            ),
          ),
        ],
      );
    }
    const titles = {
      'save': 'Save the settings',
      'stop': 'Stop the dashboard engine',
      'start': 'Start listening here',
      'entities': 'Set the kiosk\'s entities in Home Assistant',
      'check': 'Check the satellite in Home Assistant',
    };
    return (
      voiceText(context, 'Switching…'),
      [
        for (final step in c.voice.migrationSteps.value)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              spacing: 14,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: switch (step['state']) {
                    'done' => Icon(
                      Icons.check_circle_outline,
                      color: scheme.primary,
                      size: 22,
                    ),
                    'failed' => Icon(
                      Icons.error_outline,
                      color: scheme.error,
                      size: 22,
                    ),
                    'run' => const CircularProgressIndicator(strokeWidth: 3),
                    _ => Icon(
                      Icons.radio_button_unchecked,
                      color: scheme.outline,
                      size: 22,
                    ),
                  },
                ),
                Expanded(
                  child: Text(voiceText(context, titles[step['id']] ?? '')),
                ),
              ],
            ),
          ),
      ],
      const [],
    );
  }

  bool get switching => _switching;
}

/// The page's rows that pick the pipelines: Home Assistant's selects.
const voicePipelineRows = [
  ('pipeline', 'Assistant 1', 'Answers wake word 1.'),
  ('pipeline_2', 'Assistant 2', 'Answers wake word 2.'),
  (
    'vad_sensitivity',
    'Finished speaking detection',
    'How long a pause ends a voice command.',
  ),
];

/// The page's rows that pick the wake words: Home Assistant's selects.
const voiceWakeWordRows = [
  ('wake_word', 'Wake word 1', 'The word that starts a voice command.'),
  (
    'wake_word_2',
    'Wake word 2',
    'A second wake word, answered by Assistant 2.',
  ),
];

/// Shows a toast after a switch or rollback from anywhere.
void voiceToast(BuildContext context, String message) =>
    showToast(context, title: 'Voice Satellite', message: message);
