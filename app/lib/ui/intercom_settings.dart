import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_container.dart';
import '../l10n/messages.dart';
import '../core/events.dart';
import '../managers/intercom/intercom_manager.dart' show IntercomManager;
import '../managers/settings/definitions.dart' as defs;
import 'kit.dart';
import 'settings_search.dart';
import 'theme.dart';
import 'toast.dart';

/// The Intercom pieces the definitions cannot draw: the setup card the
/// page opens with when the remote admin is off, the Change key row and
/// its dialog, the Kiosks card, the Call a kiosk screen the kiosk menu
/// opens and the call screen. The remote admin mirrors the page
/// (intercom.js); the two screens are the kiosk's alone, a browser cannot
/// talk.

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
                    "Discovered kiosks and saved fleet members. A kiosk is ready when it is reachable with intercom on, the same key and matching encryption settings.",
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
          title: Text(intercomText(context, "No other kiosks found")),
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
    'key' || 'tls' || 'unreachable' => theme.colorScheme.tertiary,
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

// ── The Call a kiosk screen ────────────────────────────────────────────

/// The Call a kiosk screen the kiosk menu, a gesture or `intercomOpen`
/// opens: the app launcher's ground and close disc, the title with the
/// ready count, Announce to all and the roster as rounded rows, two
/// columns on a wide screen. A ready kiosk's row calls it; the others stay
/// on the list with their reason. Shown and hidden through the
/// manager's [IntercomManager.rosterVisible], so the menu, a gesture, the
/// remote admin, back, HOME, a call starting and the screensaver all meet
/// at one place.
class IntercomRosterOverlay extends StatelessWidget {
  const IntercomRosterOverlay({super.key, required this.container});

  final AppContainer container;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: container.intercom.rosterVisible,
    builder: (context, visible, _) {
      if (!visible) return const SizedBox.shrink();
      return Positioned.fill(child: _RosterScreen(container: container));
    },
  );
}

/// Whether the roster is being driven by dpad or keyboard keys: a key
/// arms the focus highlight, a touch stands it down, every open starts
/// without it. Same reasoning as the app launcher's wall (issue #377).
final _rosterKeysDriving = ValueNotifier<bool>(false);

class _RosterScreen extends StatefulWidget {
  const _RosterScreen({required this.container});

  final AppContainer container;

  @override
  State<_RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends State<_RosterScreen> {
  AppContainer get c => widget.container;

  late Map<String, Object?> _status = c.intercom.status();
  StreamSubscription<IntercomStateChanged>? _sub;

  /// The roster's own focus scope, so a directional search never wanders
  /// out to the dashboard's platform view underneath.
  final _scope = FocusScopeNode(debugLabel: 'intercom roster');
  final _first = FocusNode(debugLabel: 'intercom roster first');

  @override
  void initState() {
    super.initState();
    _rosterKeysDriving.value = false;
    _sub = c.bus.on<IntercomStateChanged>().listen((e) {
      if (mounted) setState(() => _status = e.status);
    });
    // Asks the manager to probe whatever has gone stale.
    unawaited(c.commands.execute('intercomStatus', const {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _first.requestFocus();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _first.dispose();
    _scope.dispose();
    super.dispose();
  }

  void _close() => c.intercom.rosterVisible.value = false;

  /// Places the call or starts the announcement. A call that starts takes
  /// the roster down through the manager; one refused leaves it up with
  /// the reason as a toast.
  Future<void> _pick(String command, Map<String, Object?> params) async {
    final r = await c.commands.execute(command, params);
    if (r.ok || !mounted) return;
    showToast(
      context,
      title: command == 'intercomBroadcast'
          ? intercomText(context, "Could not talk to everyone")
          : intercomText(context, "Could not call"),
      message: r.error == null
          ? null
          : intercomError(context, r.error!, status: c.intercom.status()),
      kind: ToastKind.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final all = [
      for (final k in (_status['kiosks'] as List? ?? const []))
        if (k is Map) k.cast<String, Object?>(),
    ];
    // Ready kiosks first, in the roster's order, then the rest with
    // their reasons.
    final ready = [
      for (final k in all)
        if (k['status'] == 'ready') k,
    ];
    final rest = [
      for (final k in all)
        if (k['status'] != 'ready') k,
    ];
    final kiosks = [...ready, ...rest];
    final count = ready.length;
    final line = switch (count) {
      0 => intercomText(context, "No kiosk is ready."),
      1 => intercomText(context, "1 kiosk is ready."),
      _ => l10n(context).intercomManyReady('$count'),
    };
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (_, event) {
        _rosterKeysDriving.value = true;
        return KeyEventResult.ignored;
      },
      child: FocusScope(
        node: _scope,
        child: Listener(
          onPointerDown: (_) => _rosterKeysDriving.value = false,
          child: GestureDetector(
            // The ground only shields the dashboard underneath: a tap on it
            // does nothing. The screen closes with the X, back or a back
            // swipe, never by a stray touch.
            behavior: HitTestBehavior.opaque,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: ksGroundGradient(scheme.surface, theme.brightness),
              ),
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final compact = width < 600;
                    final stackedHeader =
                        width < 800 ||
                        MediaQuery.textScalerOf(context).scale(16) > 20;
                    // Two columns only where a name still has room: a phone
                    // on its side keeps one column and scrolls.
                    final twoColumns = width >= 960;
                    final inset = math.max(
                      compact ? 20.0 : 40.0,
                      (width - 1120) / 2,
                    );
                    final announce = count == 0
                        ? null
                        : _AnnouncePill(
                            focusNode: _first,
                            onTap: () => _pick('intercomBroadcast', const {}),
                          );
                    final title = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          intercomText(context, "Call a kiosk"),
                          style: TextStyle(
                            fontSize: compact ? 28 : 36,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          line,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.4,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    );
                    final rows = <Widget>[];
                    for (
                      var i = 0;
                      i < kiosks.length;
                      i += twoColumns ? 2 : 1
                    ) {
                      Widget row(int j) => j < kiosks.length
                          ? _KioskRow(
                              key: ValueKey('kiosk-${kiosks[j]['id']}'),
                              kiosk: kiosks[j],
                              compact: compact,
                              focusNode: announce == null && j == 0
                                  ? _first
                                  : null,
                              onTap: () => _pick('intercomCall', {
                                'id': '${kiosks[j]['id']}',
                              }),
                            )
                          : const SizedBox.shrink();
                      if (rows.isNotEmpty) {
                        rows.add(const SizedBox(height: 12));
                      }
                      rows.add(
                        twoColumns
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: row(i)),
                                  const SizedBox(width: 16),
                                  Expanded(child: row(i + 1)),
                                ],
                              )
                            : row(i),
                      );
                    }
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(
                              inset,
                              compact ? 24 : 32,
                              inset,
                              40,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // The mark and the screen's name lead the
                                // list and scroll with it, the way a page
                                // title does; only the close disc stays put.
                                Padding(
                                  padding: EdgeInsets.only(
                                    bottom: compact ? 20 : 28,
                                  ),
                                  child: KsEyebrow(
                                    label: intercomText(context, "Intercom"),
                                    compact: compact,
                                  ),
                                ),
                                if (stackedHeader) ...[
                                  title,
                                  if (announce != null) ...[
                                    const SizedBox(height: 20),
                                    Align(
                                      alignment:
                                          AlignmentDirectional.centerStart,
                                      child: announce,
                                    ),
                                  ],
                                ] else
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(child: title),
                                      if (announce != null) ...[
                                        const SizedBox(width: 32),
                                        announce,
                                      ],
                                    ],
                                  ),
                                SizedBox(height: compact ? 24 : 32),
                                ...rows,
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: l10n(context).commonClose,
                            iconSize: 28,
                            color: scheme.onSurfaceVariant,
                            onPressed: _close,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Announce to all: the one filled pill on the roster, the megaphone and
/// the label.
class _AnnouncePill extends StatefulWidget {
  const _AnnouncePill({required this.focusNode, required this.onTap});

  final FocusNode focusNode;
  final VoidCallback onTap;

  @override
  State<_AnnouncePill> createState() => _AnnouncePillState();
}

class _AnnouncePillState extends State<_AnnouncePill> {
  bool _focused = false;

  void _onKeys() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _rosterKeysDriving.addListener(_onKeys);
  }

  @override
  void dispose() {
    _rosterKeysDriving.removeListener(_onKeys);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ring = _focused && _rosterKeysDriving.value;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: ring ? scheme.onSurface : Colors.transparent,
          width: 3,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(100),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          focusNode: widget.focusNode,
          onFocusChange: (f) => setState(() => _focused = f),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.campaign_outlined,
                  size: 24,
                  color: scheme.onPrimary,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    intercomText(context, "Announce to all"),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One kiosk on the roster, with a single call glyph and a readable
/// status. The whole row is the touch target. Unavailable kiosks keep
/// their names and reasons legible without looking actionable.
class _KioskRow extends StatefulWidget {
  const _KioskRow({
    super.key,
    required this.kiosk,
    required this.compact,
    required this.focusNode,
    required this.onTap,
  });

  final Map<String, Object?> kiosk;
  final bool compact;
  final FocusNode? focusNode;
  final VoidCallback onTap;

  @override
  State<_KioskRow> createState() => _KioskRowState();
}

class _KioskRowState extends State<_KioskRow> {
  bool _focused = false;

  void _onKeys() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _rosterKeysDriving.addListener(_onKeys);
  }

  @override
  void dispose() {
    _rosterKeysDriving.removeListener(_onKeys);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ready = widget.kiosk['status'] == 'ready';
    final highlight = _focused && _rosterKeysDriving.value;
    final okColor = theme.brightness == Brightness.dark
        ? ksSage
        : ksSageOnLight;
    final compact = widget.compact;
    final radius = BorderRadius.circular(Ks.radiusCard);
    return Semantics(
      button: true,
      enabled: ready,
      child: Material(
        color: ready
            ? scheme.surfaceContainerLow
            : scheme.surfaceContainerLow.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: highlight ? scheme.primary : scheme.outlineVariant,
            width: highlight ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: ready ? widget.onTap : null,
          focusNode: widget.focusNode,
          canRequestFocus: ready,
          onFocusChange: (f) => setState(() => _focused = f),
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: compact ? 88 : 96),
            child: Padding(
              padding: EdgeInsets.all(compact ? 16 : 20),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: ready
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(Ks.radiusRow),
                    ),
                    child: Icon(
                      Icons.call_outlined,
                      size: 24,
                      color: ready
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.kiosk['name']}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 18 : 20,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                            color: ready
                                ? scheme.onSurface
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: ready ? okColor : scheme.outline,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                intercomText(
                                  context,
                                  '${widget.kiosk['statusText']}',
                                ),
                                style: TextStyle(
                                  fontSize: compact ? 16 : 18,
                                  height: 1.3,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 20,
                    child: ready
                        ? Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: scheme.onSurfaceVariant,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The call screen over the kiosk screen, full screen on the launcher's
/// ground: calling, ringing (with the auto answer countdown), in a call
/// with push to talk or hands free, a broadcast going out or coming in,
/// and the ended screen. Nothing for idle and missed, which is a toast
/// with Call back instead. Sits in the outer Stack after the
/// notifications and under the Lockdown shield.
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

  static const _shown = IntercomManager.callScreenStates;

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
    'tls' => intercomText(
      context,
      'Encryption mismatch. Enable Encrypt communications on all kiosks in the call.',
    ),
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
    final theme = Theme.of(context);
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: ksGroundGradient(
            theme.colorScheme.surface,
            theme.brightness,
          ),
        ),
        child: SafeArea(child: LayoutBuilder(builder: _screen)),
      ),
    );
  }

  /// The whole screen: the mark and the talk mode top left, then one
  /// centered column on one rhythm: the name block, the meter, the
  /// controls and, with push to talk, End or Done under the pill. A phone
  /// or a short landscape gets the compact sizes so the column still fits
  /// without a scroll; the scroll view is the fallback for a translation
  /// or a name that runs long.
  Widget _screen(BuildContext context, BoxConstraints constraints) {
    final scheme = Theme.of(context).colorScheme;
    final state = _state;
    final call = _call;
    final kind = '${call['kind'] ?? 'call'}';
    final outgoing = call['outgoing'] == true;
    final broadcast = kind == 'broadcast';
    final peerName = '${_peer['name'] ?? ''}';
    final talkMode = '${_status['talkMode'] ?? 'ptt'}';
    final reason = '${call['reason'] ?? ''}';
    final automated = call['automated'] == true;
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    final compact = height < 480 || width < 600;
    // A short landscape (a phone on its side) has no room for a disc
    // under the pill: End sits beside it there, under it everywhere else.
    final short = height < 480;

    // The name and the line under it.
    var name = peerName;
    String? sub;
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

    // The state line: the timer, or who hears you while the talk button
    // is held.
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
        if (_held) {
          stateLine = state == 'broadcasting'
              ? l10n(context).intercomAllHearYou
              : l10n(context).intercomHearsYou(peerName);
          stateColor = scheme.primary;
        } else {
          final elapsed = _elapsed();
          stateLine = elapsed < 0
              ? intercomText(context, "Connecting…")
              : _mmss(elapsed);
          if (elapsed >= 0) stateColor = scheme.onSurface;
        }
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

    // The controls row and, for push to talk, the disc under the pill.
    final pillWidth = math.min(
      compact ? 360.0 : 480.0,
      short ? width - 48 - 88 - 28 : width - 48,
    );
    final controls = <Widget>[];
    final below = <Widget>[];
    _Disc disc(IconData icon, String label, _DiscKind kind, String command) =>
        _Disc(
          icon: icon,
          label: label,
          kind: kind,
          compact: compact,
          onTap: () => _run(command),
        );
    switch (state) {
      case 'calling':
        controls.add(
          disc(
            Icons.call_end,
            intercomText(context, "Cancel"),
            _DiscKind.end,
            'intercomHangup',
          ),
        );
      case 'ringing':
        controls.addAll([
          disc(
            Icons.call_end,
            intercomText(context, "Decline"),
            _DiscKind.end,
            'intercomDecline',
          ),
          disc(
            Icons.call,
            intercomText(context, "Answer"),
            _DiscKind.primary,
            'intercomAnswer',
          ),
        ]);
      case 'in_call' || 'broadcasting':
        final end = state == 'broadcasting'
            ? disc(
                Icons.close,
                intercomText(context, "Done"),
                _DiscKind.plain,
                'intercomHangup',
              )
            : disc(
                Icons.call_end,
                intercomText(context, "End"),
                _DiscKind.end,
                'intercomHangup',
              );
        if (automated) {
          // A clip from Home Assistant plays: nothing to hold or mute.
          controls.add(
            disc(
              Icons.stop,
              intercomText(context, "Stop"),
              _DiscKind.plain,
              'intercomHangup',
            ),
          );
        } else if (talkMode == 'ptt') {
          final pill = _TalkPill(
            held: _held,
            width: pillWidth,
            compact: compact,
            onDown: () => _talk(true),
            onUp: () => _talk(false),
          );
          if (short) {
            controls.add(
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // The pill centers on the disc itself, not on the disc
                  // plus its label, so the two read as one row.
                  Padding(
                    padding: EdgeInsets.only(bottom: compact ? 24 : 28),
                    child: pill,
                  ),
                  const SizedBox(width: 28),
                  end,
                ],
              ),
            );
          } else {
            controls.add(pill);
            below.add(end);
          }
        } else {
          final muted = call['muted'] == true;
          controls.addAll([
            _Disc(
              icon: muted ? Icons.mic_off : Icons.mic,
              label: muted
                  ? intercomText(context, "Muted")
                  : intercomText(context, "Mute"),
              kind: muted ? _DiscKind.dark : _DiscKind.plain,
              compact: compact,
              onTap: () => _run('intercomMute', {'on': !muted}),
            ),
            end,
          ]);
        }
      case 'listening':
        controls.addAll([
          _Disc(
            icon: Icons.call,
            label: intercomText(context, "Reply"),
            kind: _DiscKind.primary,
            compact: compact,
            onTap: () => _run('intercomCall', {'id': '${_peer['id']}'}),
          ),
          disc(
            Icons.close,
            intercomText(context, "Dismiss"),
            _DiscKind.plain,
            'intercomHangup',
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
              compact: compact,
              onTap: () => _run('intercomCall', {'id': '${_peer['id']}'}),
            ),
          );
        }
        controls.add(
          disc(
            Icons.close,
            intercomText(context, "Close"),
            _DiscKind.plain,
            'intercomDismiss',
          ),
        );
    }

    // A short landscape with room across (a phone on its side) keeps the
    // full rhythm and a mid-size name; only a tiny screen packs tight.
    final roomy = width >= 600;
    final gap = compact ? (roomy ? 36.0 : 16.0) : 40.0;
    final nameSize = compact
        ? (roomy ? 40.0 : 30.0)
        : (width < 900 ? 48.0 : 64.0);
    final meterScale = compact ? (roomy ? 1.2 : 0.9) : 1.8;
    // The name block and the meter scroll when a name or a translation
    // runs long; the controls never do, so End stays under a thumb
    // whatever the screen (and a scroll view ignores taps under it while
    // the talk button is held, which the controls must not).
    final details = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (broadcast) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.campaign_outlined,
                size: compact ? 16 : 18,
                color: scheme.primary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  intercomText(context, "Announcement").toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: compact ? 12.5 : 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: .8,
                    color: scheme.primary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 10 : 16),
        ],
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: nameSize,
            fontWeight: FontWeight.w600,
            height: 1.1,
            letterSpacing: -0.5,
            color: scheme.onSurface,
          ),
        ),
        if (sub != null && sub.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            sub,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 16 : 22,
              height: 1.3,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        if (stateLine.isNotEmpty) ...[
          SizedBox(height: compact ? 8 : 12),
          Text(
            stateLine,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 17 : 24,
              fontWeight: FontWeight.w500,
              height: 1.3,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: stateColor,
            ),
          ),
        ],
        SizedBox(height: gap),
        _Meter(level: level, live: live, scale: meterScale),
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
            style: TextStyle(
              fontSize: compact ? 13 : 15,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );

    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            // The column centers in the band under the eyebrow, not in
            // the whole screen, so the name never crowds the mark while
            // the bottom margin sits empty.
            padding: EdgeInsets.fromLTRB(
              24,
              compact ? 64 : 96,
              24,
              compact ? 20 : 64,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: SingleChildScrollView(child: details)),
                  SizedBox(height: gap),
                  Wrap(
                    spacing: compact ? 28 : 56,
                    runSpacing: 16,
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.start,
                    children: controls,
                  ),
                  if (below.isNotEmpty) ...[
                    SizedBox(height: compact ? 16 : 28),
                    Wrap(
                      spacing: compact ? 28 : 56,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: below,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: compact ? 12 : 20,
          left: compact ? 16 : 28,
          child: KsEyebrow(
            label: intercomText(context, "Intercom"),
            trail: automated
                ? null
                : talkMode == 'handsfree'
                ? intercomText(context, "Hands free")
                : intercomText(context, "Push to talk"),
            compact: compact,
          ),
        ),
      ],
    );
  }
}

/// Twelve level bars. At rest every bar is one short stub in the outline
/// color. Live they take the text color and rise with the voice toward
/// their own heights, the logo's four bars in the middle and shorter ones
/// out to the sides, each a little differently so the row reads as sound
/// rather than a gauge.
class _Meter extends StatelessWidget {
  const _Meter({required this.level, required this.live, required this.scale});

  final double level;
  final bool live;

  /// Pixels per logo unit: 1.8 on a tablet (the tallest bar 77 px), less
  /// on a phone.
  final double scale;

  /// Full heights in the logo's units: its house bars are 26.6, 22, 42.6
  /// and 22.6 tall on an 8.6 wide bar with a 4 gap.
  static const _shape = [
    14.0,
    22.0,
    17.0,
    25.0,
    26.6,
    22.0,
    42.6,
    22.6,
    28.0,
    16.0,
    23.0,
    14.0,
  ];
  static const _rest = 8.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final on = live && level > 0.02;
    final k = scale;
    final w = 8.6 * k;
    final rise = math.min(1.0, level * 1.6);
    return SizedBox(
      height: 42.6 * k,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < _shape.length; i++) ...[
            if (i > 0) SizedBox(width: 4 * k),
            AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              width: w,
              height: (on ? _rest + (_shape[i] - _rest) * rise : _rest) * k,
              decoration: BoxDecoration(
                color: on ? scheme.onSurface : scheme.outline,
                borderRadius: BorderRadius.circular(w / 2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _DiscKind { plain, primary, end, dark }

/// A round call button with its label beneath: 96 on the tablet, 64 on
/// a phone or a short landscape.
class _Disc extends StatelessWidget {
  const _Disc({
    required this.icon,
    required this.label,
    required this.kind,
    required this.compact,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final _DiscKind kind;
  final bool compact;
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
    final d = compact ? 64.0 : 96.0;
    return SizedBox(
      width: compact ? 88 : 128,
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
                width: d,
                height: d,
                child: Icon(icon, size: compact ? 27 : 40, color: fg),
              ),
            ),
          ),
          SizedBox(height: compact ? 8 : 12),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 13 : 16,
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
/// send. Idle, it fills primary. Held, it uses a tinted fill, outline and
/// soft ring. The line under the name says who hears you.
class _TalkPill extends StatelessWidget {
  const _TalkPill({
    required this.held,
    required this.width,
    required this.compact,
    required this.onDown,
    required this.onUp,
  });

  final bool held;
  final double width;
  final bool compact;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = held ? scheme.onPrimaryContainer : scheme.onPrimary;
    return Listener(
      onPointerDown: (_) => onDown(),
      onPointerUp: (_) => onUp(),
      onPointerCancel: (_) => onUp(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: width,
        height: compact ? 60 : 96,
        decoration: BoxDecoration(
          color: held ? scheme.primaryContainer : scheme.primary,
          borderRadius: BorderRadius.circular(999),
          border: held ? Border.all(color: scheme.primary) : null,
          boxShadow: held
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.28),
                    spreadRadius: compact ? 6 : 10,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mic, size: compact ? 26 : 32, color: fg),
            SizedBox(width: compact ? 12 : 16),
            Flexible(
              child: Text(
                intercomText(context, "Hold to talk"),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: compact ? 18 : 22,
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
                        compact: true,
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
