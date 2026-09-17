import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_container.dart';
import '../l10n/messages.dart';
import '../core/events.dart';
import '../managers/settings/definitions.dart' as defs;
import 'kit.dart';
import 'settings_search.dart';
import 'theme.dart';
import 'toast.dart';

/// The Intercom pieces the definitions cannot draw: the setup card the
/// page opens with when the remote admin is off, the Change key row and
/// its dialog, the Kiosks card, the sheet the kiosk menu opens and the
/// call overlay. The remote admin mirrors the page (intercom.js); the
/// sheet and the overlay are the kiosk's alone, a browser cannot talk.

// ── The page ───────────────────────────────────────────────────────────

/// The Intercom page: the setup card when the remote admin or Find other
/// kiosks is off, the definition-drawn [cards], then the Kiosks card. The
/// roster comes from `intercomStatus`, which also asks the manager to
/// probe stale kiosks, and redraws on every [IntercomStateChanged] and on
/// a 30 s timer while the page is open.
class IntercomSettingsPanel extends StatefulWidget {
  const IntercomSettingsPanel({
    super.key,
    required this.container,
    required this.cards,
  });

  final AppContainer container;

  /// The generic cards for the category, built by the settings screen.
  final List<Widget> cards;

  @override
  State<IntercomSettingsPanel> createState() => _IntercomSettingsPanelState();
}

class _IntercomSettingsPanelState extends State<IntercomSettingsPanel> {
  late Map<String, Object?> _status = widget.container.intercom.status();
  StreamSubscription<IntercomStateChanged>? _sub;
  Timer? _poll;

  AppContainer get c => widget.container;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _sub = c.bus.on<IntercomStateChanged>().listen((e) {
      if (mounted) setState(() => _status = e.status);
    });
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await c.commands.execute('intercomStatus', const {});
    if (!mounted || !r.ok || r.data is! Map) return;
    setState(() => _status = (r.data as Map).cast<String, Object?>());
  }

  Future<void> _call(String id) async {
    final r = await c.commands.execute('intercomCall', {'id': id});
    if (!mounted || r.ok) return;
    showToast(
      context,
      title: intercomText(context, "Could not call"),
      message: r.error == null
          ? null
          : intercomError(context, r.error!, status: c.intercom.status()),
      kind: ToastKind.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final available = _status['available'] == true;
    // The roster is worth nothing with the intercom off: the switch is
    // the whole page then.
    final enabled = _status['enabled'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!available) ...[
          SettingsCard(
            children: [
              SettingsRow(
                leading: Icon(Icons.cloud_off_outlined),
                title: Text(
                  intercomText(context, "The intercom needs the remote admin"),
                ),
                subtitle: Text(
                  intercomText(
                    context,
                    "Kiosks find and reach each other through it. Turn on Remote management and Find other kiosks under Device, then come back.",
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Ks.cardGap),
        ],
        ...widget.cards,
        if (enabled) ...[
          SectionHeading(intercomText(context, "Kiosks")),
          SearchLandingTarget(
            id: 'x:intercom_kiosks',
            child: SettingsCard(
              children: [
                ..._kioskRows(context),
                HintRow(
                  intercomText(
                    context,
                    "Kiosks discovered on this network. A kiosk is ready once its intercom is on with the same key.",
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _kioskRows(BuildContext context) {
    final kiosks = [
      for (final k in (_status['kiosks'] as List? ?? const []))
        if (k is Map) k.cast<String, Object?>(),
    ];
    if (kiosks.isEmpty) {
      return [
        SettingsRow(
          title: Text(intercomText(context, "No other kiosk heard")),
          subtitle: Text(
            intercomText(
              context,
              "Kiosks with Remote management and Find other kiosks on show up here.",
            ),
          ),
        ),
      ];
    }
    final scheme = Theme.of(context).colorScheme;
    return [
      for (final k in kiosks)
        Opacity(
          opacity: k['status'] == 'offline' ? 0.45 : 1,
          child: SettingsRow(
            leading: const Icon(Icons.tablet_android_outlined),
            title: Text('${k['name']}'),
            subtitle: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('${k['address']}'),
                if ('${k['version'] ?? ''}'.isNotEmpty)
                  IntercomTag('${k['version']}'),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  intercomText(context, '${k['statusText']}'),
                  style: TextStyle(
                    fontSize: 13,
                    color: intercomStatusColor(context, '${k['status']}'),
                  ),
                ),
                if (k['status'] == 'ready') ...[
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => _call('${k['id']}'),
                    icon: Icon(
                      Icons.phone_outlined,
                      size: 18,
                      color: scheme.onSurface,
                    ),
                    label: Text(intercomText(context, "Call")),
                  ),
                ],
              ],
            ),
          ),
        ),
    ];
  }
}

/// The status word's color: ok green for Ready, the warning tone for a
/// different key, muted for the rest. The remote admin's --ok and --warn.
Color intercomStatusColor(BuildContext context, String status) {
  final theme = Theme.of(context);
  return switch (status) {
    'ready' => theme.brightness == Brightness.dark ? ksSage : ksSageOnLight,
    'key' || 'unreachable' => theme.colorScheme.tertiary,
    _ => theme.colorScheme.onSurfaceVariant,
  };
}

/// The small uppercase tag beside a kiosk's address: its version. The
/// remote admin's `.tag`, the fleet page's shape.
class IntercomTag extends StatelessWidget {
  const IntercomTag(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: .4,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ── The key ────────────────────────────────────────────────────────────

/// The row under the key's copy box: opens the Change key dialog.
class IntercomChangeKeyRow extends StatelessWidget {
  const IntercomChangeKeyRow({
    super.key,
    required this.container,
    required this.onChanged,
  });

  final AppContainer container;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => SettingsRow(
    title: Text(intercomText(context, "Change key")),
    subtitle: Text(
      intercomText(
        context,
        "Paste the key from another kiosk, or make a new one.",
      ),
    ),
    trailing: OutlinedButton(
      onPressed: () async {
        final changed = await showIntercomKeyDialog(context, container);
        if (changed) onChanged();
      },
      child: Text(intercomText(context, "Change")),
    ),
  );
}

/// The Change key dialog: the key in a field to paste over, Regenerate for
/// a fresh one. Answers true when the key changed.
Future<bool> showIntercomKeyDialog(
  BuildContext context,
  AppContainer container,
) async {
  final controller = TextEditingController(
    text: container.settings.get(defs.intercomKey),
  );
  final overlay = Overlay.of(context, rootOverlay: true);
  Future<bool> run(Map<String, Object?> params) async {
    final r = await container.commands.execute('intercomSetKey', params);
    if (!r.ok && context.mounted) {
      showToastIn(
        overlay,
        title: intercomText(context, "Could not change the key"),
        message: r.error == null
            ? null
            : intercomError(
                context,
                r.error!,
                status: container.intercom.status(),
              ),
        kind: ToastKind.error,
      );
    }
    return r.ok;
  }

  final route = DialogRoute<bool>(
    context: context,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return AlertDialog(
        title: Text(intercomText(ctx, "Intercom key")),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13.5),
              ),
              const SizedBox(height: 8),
              Text(
                intercomText(
                  ctx,
                  "Kiosks with this key can call each other. A new key cuts this kiosk off from the others until they get it too.",
                ),
                style: Theme.of(
                  ctx,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: OverflowBar(
              alignment: MainAxisAlignment.end,
              overflowAlignment: OverflowBarAlignment.end,
              spacing: 10,
              overflowSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () async {
                    final ok = await run(const {'regenerate': true});
                    if (ok && ctx.mounted) Navigator.pop(ctx, true);
                  },
                  child: Text(intercomText(ctx, "Regenerate")),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(intercomText(ctx, "Cancel")),
                ),
                FilledButton(
                  onPressed: () async {
                    final ok = await run({'key': controller.text});
                    if (ok && ctx.mounted) Navigator.pop(ctx, true);
                  },
                  child: Text(intercomText(ctx, "Save")),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
  final changed = await Navigator.of(context, rootNavigator: true).push(route);
  await route.completed;
  controller.dispose();
  return changed ?? false;
}

// ── The sheet ──────────────────────────────────────────────────────────

/// The Announcements page's Text to speech engine row: the picked
/// entity's name in a control box, and a tap opens the radio picker over
/// every text to speech entity Home Assistant has, First available on
/// top. Mirrored on the remote.
class AnnouncementTtsEngineRow extends StatefulWidget {
  const AnnouncementTtsEngineRow({super.key, required this.container});

  final AppContainer container;

  @override
  State<AnnouncementTtsEngineRow> createState() =>
      _AnnouncementTtsEngineRowState();
}

class _AnnouncementTtsEngineRowState extends State<AnnouncementTtsEngineRow> {
  StreamSubscription<SettingChanged>? _sub;
  List<Map<String, String>> _engines = const [];

  AppContainer get c => widget.container;

  @override
  void initState() {
    super.initState();
    _sub = c.bus.on<SettingChanged>().listen((e) {
      if (e.key == defs.announcementsTtsEngine.key && mounted) setState(() {});
    });
    unawaited(_load());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<bool> _load() async {
    final r = await c.commands.execute('announcementTtsEngines', const {});
    if (!mounted || !r.ok || r.data is! List) return false;
    setState(() {
      _engines = [
        for (final e in r.data as List)
          if (e is Map)
            {'entity_id': '${e['entity_id']}', 'name': '${e['name']}'},
      ];
    });
    return true;
  }

  String _labelOf(String id) {
    if (id.isEmpty) return esphomeText(context, 'First available');
    for (final e in _engines) {
      if (e['entity_id'] == id) return e['name']!;
    }
    return id;
  }

  Future<void> _pick() async {
    final ok = await _load();
    if (!mounted) return;
    if (!ok) {
      showToast(
        context,
        title: esphomeText(context, 'Could not reach Home Assistant'),
        kind: ToastKind.error,
      );
      return;
    }
    final current = c.settings.get(defs.announcementsTtsEngine).trim();
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(esphomeText(context, 'Text to speech engine')),
        children: [
          RadioGroup<String>(
            groupValue: current,
            onChanged: (value) => Navigator.of(context).pop(value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  value: '',
                  title: Text(esphomeText(context, 'First available')),
                ),
                for (final engine in _engines)
                  RadioListTile<String>(
                    value: engine['entity_id']!,
                    title: Text(engine['name']!),
                    subtitle: Text(engine['entity_id']!),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked == null) return;
    await c.settings.set(defs.announcementsTtsEngine, picked);
  }

  @override
  Widget build(BuildContext context) {
    final current = c.settings.get(defs.announcementsTtsEngine).trim();
    return SearchLandingTarget(
      id: defs.announcementsTtsEngine.key,
      child: SettingsRow(
        stack: true,
        title: Text(defs.announcementsTtsEngine.localizedTitle(context)),
        subtitle: Text(
          defs.announcementsTtsEngine.localizedDescription(context),
        ),
        trailing: ControlBox(
          onTap: _pick,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(
                  _labelOf(current),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.expand_more, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// The sheet the kiosk menu, a gesture or `intercomOpen` opens: Announce
/// to all first, then every kiosk that is ready, by name. A tap calls and
/// closes.
Future<void> showIntercomSheet(BuildContext context, AppContainer c) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  await showDialog<void>(
    context: context,
    builder: (ctx) => _IntercomSheet(
      container: c,
      onPick: (command, params) async {
        Navigator.pop(ctx);
        final r = await c.commands.execute(command, params);
        if (r.ok || !context.mounted) return;
        showToastIn(
          overlay,
          title: command == 'intercomBroadcast'
              ? intercomText(context, "Could not talk to everyone")
              : intercomText(context, "Could not call"),
          message: r.error == null
              ? null
              : intercomError(context, r.error!, status: c.intercom.status()),
          kind: ToastKind.error,
        );
      },
    ),
  );
}

class _IntercomSheet extends StatefulWidget {
  const _IntercomSheet({required this.container, required this.onPick});

  final AppContainer container;
  final void Function(String command, Map<String, Object?> params) onPick;

  @override
  State<_IntercomSheet> createState() => _IntercomSheetState();
}

class _IntercomSheetState extends State<_IntercomSheet> {
  late Map<String, Object?> _status = widget.container.intercom.status();
  StreamSubscription<IntercomStateChanged>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.container.bus.on<IntercomStateChanged>().listen((e) {
      if (mounted) setState(() => _status = e.status);
    });
    // Asks the manager to probe whatever has gone stale.
    unawaited(widget.container.commands.execute('intercomStatus', const {}));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ready = [
      for (final k in (_status['kiosks'] as List? ?? const []))
        if (k is Map && k['status'] == 'ready') k.cast<String, Object?>(),
    ];
    final count = ready.length;
    final line = switch (count) {
      0 => intercomText(context, "No kiosk is ready."),
      1 => intercomText(context, "1 kiosk is ready."),
      _ => l10n(context).intercomManyReady('$count'),
    };
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The title and the count stay put, the list scrolls.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    intercomText(context, "Call a kiosk"),
                    style: Theme.of(context).dialogTheme.titleTextStyle,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    line,
                    style: TextStyle(
                      fontSize: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (count > 0)
              Flexible(
                child: EdgeFade(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _AnnounceTile(
                          onTap: () =>
                              widget.onPick('intercomBroadcast', const {}),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
                          child: Text(
                            intercomText(context, "Kiosks").toUpperCase(),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: .8,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Material(
                          color: scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(Ks.radiusRow),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              for (final (i, k) in ready.indexed) ...[
                                if (i > 0)
                                  const Divider(
                                    height: 1,
                                    indent: 16,
                                    endIndent: 16,
                                  ),
                                _KioskRow(
                                  key: ValueKey('kiosk-$i'),
                                  name: '${k['name']}',
                                  onTap: () => widget.onPick('intercomCall', {
                                    'id': '${k['id']}',
                                  }),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),
              ),
            // A way out that is not a tap outside: the quiet text button the
            // kit's dialogs use.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 16, 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(intercomText(context, "Cancel")),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The one way broadcast, its own card above the kiosk list with the
/// campaign disc on the right.
class _AnnounceTile extends StatelessWidget {
  const _AnnounceTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(Ks.radiusRow),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      intercomText(context, "Announce to all"),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      intercomText(
                        context,
                        "Talk to every kiosk. One way only.",
                      ),
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.3,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _ActionDisc(
                icon: Icons.campaign_outlined,
                background: scheme.primary,
                foreground: scheme.onPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One ready kiosk: its name and a call disc, the whole row tappable.
class _KioskRow extends StatelessWidget {
  const _KioskRow({super.key, required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 12),
            _ActionDisc(
              icon: Icons.phone_outlined,
              background: scheme.primary,
              foreground: scheme.onPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

/// The 40 disc at the end of a sheet row. Not a button of its own, the row
/// around it takes the tap.
class _ActionDisc extends StatelessWidget {
  const _ActionDisc({
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(color: background, shape: BoxShape.circle),
    child: Icon(icon, size: 20, color: foreground),
  );
}

// ── The call overlay ───────────────────────────────────────────────────

/// The call card over the kiosk screen: calling, ringing (with the auto
/// answer countdown), in a call with push to talk or hands free, a
/// broadcast going out or coming in, and the ended card. Nothing for idle
/// and missed, which is a toast with Call back instead. Sits in the outer
/// Stack after the notifications and under the Lockdown shield.
class IntercomCallOverlay extends StatefulWidget {
  const IntercomCallOverlay({super.key, required this.container});

  final AppContainer container;

  @override
  State<IntercomCallOverlay> createState() => _IntercomCallOverlayState();
}

class _IntercomCallOverlayState extends State<IntercomCallOverlay> {
  late Map<String, Object?> _status = widget.container.intercom.status();
  StreamSubscription<IntercomStateChanged>? _stateSub;
  StreamSubscription<IntercomLevel>? _levelSub;
  Timer? _tick;
  Timer? _levelDecay;
  double _near = 0;
  double _far = 0;
  bool _held = false;

  AppContainer get c => widget.container;
  String get _state => '${_status['state']}';
  Map<String, Object?> get _call =>
      (_status['call'] as Map?)?.cast<String, Object?>() ?? const {};
  Map<String, Object?> get _peer =>
      (_call['peer'] as Map?)?.cast<String, Object?>() ?? const {};

  static const _shown = {
    'calling',
    'ringing',
    'in_call',
    'broadcasting',
    'listening',
    'ended',
  };

  @override
  void initState() {
    super.initState();
    _stateSub = c.bus.on<IntercomStateChanged>().listen(_onState);
    _levelSub = c.bus.on<IntercomLevel>().listen((e) {
      if (!mounted) return;
      setState(() {
        _near = e.near;
        _far = e.far;
      });
      // Levels only arrive while audio flows: silence must fall back to
      // rest on its own.
      _levelDecay?.cancel();
      _levelDecay = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _near = 0;
            _far = 0;
          });
        }
      });
    });
    _syncTick();
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _levelSub?.cancel();
    _tick?.cancel();
    _levelDecay?.cancel();
    super.dispose();
  }

  void _onState(IntercomStateChanged e) {
    if (!mounted) return;
    final was = _state;
    final wasPeer = _peer;
    setState(() => _status = e.status);
    if (_state != 'in_call' && _state != 'broadcasting') _held = false;
    if (_state == 'missed' && was == 'ringing') _missedToast(wasPeer);
    _syncTick();
  }

  /// A one second tick for the timer and the countdown, only while the
  /// card is up.
  void _syncTick() {
    final live = _shown.contains(_state);
    if (live && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!live) {
      _tick?.cancel();
      _tick = null;
    }
  }

  void _missedToast(Map<String, Object?> peer) {
    final id = '${peer['id'] ?? ''}';
    final overlay = Overlay.of(context, rootOverlay: true);
    showToastIn(
      overlay,
      title: l10n(context).intercomMissedFrom('${peer['name']}'),
      message: l10n(
        context,
      ).intercomRangFor(c.settings.get(defs.intercomRingSeconds)),
      duration: const Duration(seconds: 8),
      actionLabel: id.isEmpty ? null : intercomText(context, "Call back"),
      onAction: id.isEmpty ? null : () => _run('intercomCall', {'id': id}),
    );
  }

  Future<void> _run(
    String command, [
    Map<String, Object?> params = const {},
  ]) async {
    final r = await c.commands.execute(command, params);
    if (r.ok || !mounted) return;
    showToast(
      context,
      title: intercomText(context, "Intercom"),
      message: r.error == null
          ? null
          : intercomError(context, r.error!, status: c.intercom.status()),
      kind: ToastKind.error,
    );
  }

  void _talk(bool on) {
    if (_held == on) return;
    setState(() => _held = on);
    unawaited(c.commands.execute('intercomTalk', {'on': on}));
  }

  static String _mmss(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  int _elapsed() {
    final since = _call['since'];
    if (since is! num) return -1;
    return DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(since.toInt()))
        .inSeconds;
  }

  String _reasonText(String reason) => switch (reason) {
    'declined' => intercomText(context, "Declined"),
    'busy' => intercomText(context, "Busy"),
    'dnd' => intercomText(context, "Do not disturb"),
    'off' => intercomText(context, "Its intercom is off"),
    'key' => intercomText(context, "Different intercom key"),
    'no_answer' => intercomText(context, "No answer"),
    'unreachable' => intercomText(context, "Did not answer"),
    'failed' => intercomText(context, "The voice link failed"),
    'cancelled' => intercomText(context, "Cancelled"),
    'mic_busy' => intercomText(context, "The page took the microphone"),
    'no_targets' => intercomText(context, "Nobody could take it"),
    'broadcast_over' => intercomText(context, "Done"),
    _ => intercomText(context, "Call ended"),
  };

  @override
  Widget build(BuildContext context) {
    final state = _state;
    if (!_shown.contains(state)) return const SizedBox.shrink();
    // An announcement from Home Assistant has a card of its own.
    if (_call['automated'] == true && _call['outgoing'] != true) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ModalBarrier(color: Colors.black54, dismissible: false),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Material(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(Ks.radiusCard),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                  child: LayoutBuilder(
                    builder: (context, constraints) =>
                        _card(context, constraints.maxWidth < 400),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card(BuildContext context, bool tight) {
    final scheme = Theme.of(context).colorScheme;
    final state = _state;
    final call = _call;
    final kind = '${call['kind'] ?? 'call'}';
    final outgoing = call['outgoing'] == true;
    final broadcast = kind == 'broadcast';
    final peerName = '${_peer['name'] ?? ''}';
    final talkMode = '${_status['talkMode'] ?? 'ptt'}';
    final reason = '${call['reason'] ?? ''}';

    // The name and the line under it.
    var name = peerName;
    String? sub;
    final automated = call['automated'] == true;
    if (broadcast && outgoing && state == 'ended') {
      name = intercomText(context, "Announcement");
    } else if (broadcast && outgoing) {
      final listening = [
        for (final t in (call['targets'] as List? ?? const []))
          if (t is Map && t['status'] == 'listening') '${t['name']}',
      ];
      name = listening.isEmpty
          ? intercomText(context, "Announcement")
          : intercomAnnouncing(context, listening.length);
      sub = listening.join(', ');
    } else if (state == 'ringing') {
      sub = intercomText(context, "is calling");
    } else if (state == 'listening') {
      sub = intercomText(context, "is announcing");
    }

    // The state line.
    String stateLine;
    var stateColor = scheme.onSurfaceVariant;
    switch (state) {
      case 'calling':
        stateLine = intercomText(context, "Calling…");
      case 'ringing':
        final auto = call['autoAnswerAt'];
        if (auto is num) {
          final left = (auto.toInt() - DateTime.now().millisecondsSinceEpoch);
          stateLine = l10n(
            context,
          ).intercomAnswersIn('${math.max(0, (left / 1000).ceil())}');
        } else {
          stateLine = intercomText(context, "Ringing");
        }
      case 'in_call' || 'broadcasting':
        final elapsed = _elapsed();
        stateLine = elapsed < 0
            ? intercomText(context, "Connecting…")
            : _mmss(elapsed);
        if (elapsed >= 0) stateColor = scheme.onSurface;
      case 'listening':
        stateLine = '';
      case 'ended':
        final duration = (call['duration'] as num?)?.toInt() ?? 0;
        stateLine = reason == 'ended' || reason.isEmpty
            ? broadcast && outgoing
                  ? l10n(context).intercomDoneDuration(_mmss(duration))
                  : l10n(context).intercomEndedDuration(_mmss(duration))
            : _reasonText(reason);
      default:
        stateLine = '';
    }

    // Whether this kiosk's own voice is what the meter should show.
    final sending = switch (state) {
      'in_call' ||
      'broadcasting' => talkMode == 'handsfree' ? call['muted'] != true : _held,
      _ => false,
    };
    final live =
        state == 'in_call' || state == 'broadcasting' || state == 'listening';
    final level = !live ? 0.0 : (sending ? _near : _far);

    final micBusy = _status['micBusy'] == true;
    final micDenied =
        (_status['micGranted'] == false || micBusy) &&
        (state == 'in_call' || state == 'broadcasting');

    final pillWidth = tight ? 240.0 : 320.0;
    final controls = <Widget>[];
    switch (state) {
      case 'calling':
        controls.add(
          _Disc(
            icon: Icons.call_end,
            label: intercomText(context, "Cancel"),
            kind: _DiscKind.end,
            onTap: () => _run('intercomHangup'),
          ),
        );
      case 'ringing':
        controls.addAll([
          _Disc(
            icon: Icons.call_end,
            label: intercomText(context, "Decline"),
            kind: _DiscKind.end,
            onTap: () => _run('intercomDecline'),
          ),
          _Disc(
            icon: Icons.call,
            label: intercomText(context, "Answer"),
            kind: _DiscKind.primary,
            onTap: () => _run('intercomAnswer'),
          ),
        ]);
      case 'in_call' || 'broadcasting':
        if (automated) {
          // A clip from Home Assistant plays: nothing to hold or mute.
          controls.add(
            _Disc(
              icon: Icons.stop,
              label: intercomText(context, "Stop"),
              kind: _DiscKind.plain,
              onTap: () => _run('intercomHangup'),
            ),
          );
          break;
        }
        if (talkMode == 'ptt') {
          controls.add(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TalkPill(
                  held: _held,
                  width: pillWidth,
                  onDown: () => _talk(true),
                  onUp: () => _talk(false),
                ),
                const SizedBox(height: 10),
                Text(
                  _held
                      ? (state == 'broadcasting'
                            ? l10n(context).intercomAllHearYou
                            : l10n(context).intercomHearsYou(peerName))
                      : intercomText(context, "Hold to talk, let go to listen"),
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        } else {
          final muted = call['muted'] == true;
          controls.add(
            _Disc(
              icon: muted ? Icons.mic_off : Icons.mic,
              label: muted
                  ? intercomText(context, "Muted")
                  : intercomText(context, "Mute"),
              kind: muted ? _DiscKind.dark : _DiscKind.plain,
              onTap: () => _run('intercomMute', {'on': !muted}),
            ),
          );
        }
        controls.add(
          state == 'broadcasting'
              ? _Disc(
                  icon: Icons.close,
                  label: intercomText(context, "Done"),
                  kind: _DiscKind.plain,
                  onTap: () => _run('intercomHangup'),
                )
              : _Disc(
                  icon: Icons.call_end,
                  label: intercomText(context, "End"),
                  kind: _DiscKind.end,
                  onTap: () => _run('intercomHangup'),
                ),
        );
      case 'listening':
        controls.addAll([
          _Disc(
            icon: Icons.call,
            label: intercomText(context, "Reply"),
            kind: _DiscKind.primary,
            onTap: () => _run('intercomCall', {'id': '${_peer['id']}'}),
          ),
          _Disc(
            icon: Icons.close,
            label: intercomText(context, "Dismiss"),
            kind: _DiscKind.plain,
            onTap: () => _run('intercomHangup'),
          ),
        ]);
      case 'ended':
        // A broadcast has no one kiosk to call again.
        if (reason != 'broadcast_over' && !(broadcast && outgoing)) {
          controls.add(
            _Disc(
              icon: Icons.call,
              label: intercomText(context, "Call again"),
              kind: _DiscKind.primary,
              onTap: () => _run('intercomCall', {'id': '${_peer['id']}'}),
            ),
          );
        }
        controls.add(
          _Disc(
            icon: Icons.close,
            label: intercomText(context, "Close"),
            kind: _DiscKind.plain,
            onTap: () => _run('intercomDismiss'),
          ),
        );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (broadcast) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.campaign_outlined, size: 16, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                intercomText(context, "Announcement").toUpperCase(),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .8,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w600,
            height: 1.2,
            color: scheme.onSurface,
          ),
        ),
        if (sub != null && sub.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        if (stateLine.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            stateLine,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: stateColor,
            ),
          ),
        ],
        const SizedBox(height: 12),
        _Meter(level: level, live: live),
        const SizedBox(height: 16),
        Wrap(
          spacing: 28,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: controls,
        ),
        if (micDenied) ...[
          const SizedBox(height: 12),
          Text(
            micBusy
                ? intercomText(
                    context,
                    "The dashboard holds the microphone, listening only.",
                  )
                : intercomText(
                    context,
                    "Microphone not granted, listening only.",
                  ),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

/// Fifteen level bars: at rest 6 px in the outline color, live they rise
/// with the voice, each a little differently so the meter reads as sound
/// rather than a gauge.
class _Meter extends StatelessWidget {
  const _Meter({required this.level, required this.live});

  final double level;
  final bool live;

  static const _shape = [
    10.0,
    18.0,
    28.0,
    36.0,
    22.0,
    30.0,
    16.0,
    26.0,
    34.0,
    20.0,
    12.0,
    24.0,
    30.0,
    14.0,
    8.0,
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final on = live && level > 0.02;
    return SizedBox(
      height: 40,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < _shape.length; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              width: 5,
              height: on ? 6 + (_shape[i] - 6) * math.min(1, level * 1.6) : 6,
              decoration: BoxDecoration(
                color: on ? scheme.primary : scheme.outline,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _DiscKind { plain, primary, end, dark }

/// A 64 px round call button with its label beneath.
class _Disc extends StatelessWidget {
  const _Disc({
    required this.icon,
    required this.label,
    required this.kind,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final _DiscKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (kind) {
      _DiscKind.plain => (scheme.surfaceContainerHighest, scheme.onSurface),
      _DiscKind.primary => (scheme.primary, scheme.onPrimary),
      _DiscKind.end => (scheme.error, scheme.onError),
      _DiscKind.dark => (scheme.onSurface, scheme.surface),
    };
    return SizedBox(
      width: 88,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: bg,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                width: 64,
                height: 64,
                child: Icon(icon, size: 27, color: fg),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Push to talk: one wide pill held down for as long as the kiosk should
/// send. Held, it fills primary with a soft ring around it.
class _TalkPill extends StatelessWidget {
  const _TalkPill({
    required this.held,
    required this.width,
    required this.onDown,
    required this.onUp,
  });

  final bool held;
  final double width;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = held ? scheme.onPrimary : scheme.onSurface;
    return Listener(
      onPointerDown: (_) => onDown(),
      onPointerUp: (_) => onUp(),
      onPointerCancel: (_) => onUp(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: width,
        height: 72,
        decoration: BoxDecoration(
          color: held ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: held ? null : Border.all(color: scheme.outlineVariant),
          boxShadow: held
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.28),
                    spreadRadius: 6,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mic, size: 26, color: fg),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                intercomText(context, "Hold to talk"),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The card an announcement from Home Assistant shows while it plays: who
/// it is from, the spoken text large enough to read across the room (or
/// the clip's name when it was a file) and Dismiss. Its own overlay,
/// apart from the intercom's call card: no meter, no one to call back.
class AnnouncementOverlay extends StatefulWidget {
  const AnnouncementOverlay({super.key, required this.container});

  final AppContainer container;

  @override
  State<AnnouncementOverlay> createState() => _AnnouncementOverlayState();
}

class _AnnouncementOverlayState extends State<AnnouncementOverlay> {
  late Map<String, Object?> _status = widget.container.intercom.status();
  StreamSubscription<IntercomStateChanged>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.container.bus.on<IntercomStateChanged>().listen((e) {
      if (mounted) setState(() => _status = e.status);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = '${_status['state']}';
    final call = (_status['call'] as Map?)?.cast<String, Object?>();
    if (call == null ||
        call['automated'] != true ||
        call['audioOnly'] == true ||
        call['outgoing'] == true ||
        (state != 'listening' && state != 'ended')) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final message = '${call['message'] ?? ''}'.trim();
    final playing = state == 'listening';
    final tight = MediaQuery.sizeOf(context).width < 480;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ModalBarrier(color: Colors.black54, dismissible: false),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Material(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(Ks.radiusCard),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    tight ? 20 : 32,
                    24,
                    tight ? 20 : 32,
                    20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.campaign_outlined,
                            size: 18,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'HOME ASSISTANT',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: .8,
                              color: scheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        message.isEmpty
                            ? intercomText(context, "Announcement")
                            : message,
                        textAlign: TextAlign.center,
                        maxLines: 8,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: tight ? 22 : 26,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        playing
                            ? intercomText(context, "Playing")
                            : intercomText(context, "Done"),
                        style: TextStyle(
                          fontSize: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _Disc(
                        icon: Icons.close,
                        label: intercomText(context, "Dismiss"),
                        kind: _DiscKind.plain,
                        onTap: () => widget.container.commands.execute(
                          playing ? 'intercomHangup' : 'intercomDismiss',
                          const {},
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
