import 'dart:async';

import 'package:flutter/material.dart';

import '../app_container.dart';
import '../core/events.dart';
import '../l10n/messages.dart';
import '../managers/settings/definitions.dart' as defs;
import 'kit.dart';
import 'toast.dart';

/// Uses the same boxed entity control as the Announcements TTS engine row.
class WeatherMoodEntityRow extends StatefulWidget {
  const WeatherMoodEntityRow({super.key, required this.container});

  final AppContainer container;

  @override
  State<WeatherMoodEntityRow> createState() => _WeatherMoodEntityRowState();
}

class _WeatherMoodEntityRowState extends State<WeatherMoodEntityRow> {
  StreamSubscription<SettingChanged>? _sub;
  List<(String, String)> _entities = const [];

  AppContainer get c => widget.container;

  @override
  void initState() {
    super.initState();
    _sub = c.bus.on<SettingChanged>().listen((event) {
      if (event.key == defs.screensaverWeatherEntity.key && mounted) {
        setState(() {});
      }
    });
    unawaited(_load());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<bool> _load() async {
    final result = await c.commands.execute('haSearchEntities', const {
      'query': 'weather.',
    });
    if (!mounted || !result.ok || result.data is! List) return false;
    setState(() {
      _entities = [
        for (final entity in result.data as List)
          if (entity is Map && '${entity['entity_id']}'.startsWith('weather.'))
            (
              '${entity['entity_id']}',
              '${entity['name'] ?? entity['entity_id']}',
            ),
      ];
    });
    return true;
  }

  String _labelOf(String id) {
    if (id.isEmpty) return screensaverText(context, 'Pick a weather entity…');
    return _entities.where((entity) => entity.$1 == id).firstOrNull?.$2 ?? id;
  }

  Future<void> _pick() async {
    final ok = await _load();
    if (!mounted) return;
    if (!ok) {
      showToast(
        context,
        title: screensaverText(context, 'Could not reach Home Assistant'),
        kind: ToastKind.error,
      );
      return;
    }
    final current = c.settings.get(defs.screensaverWeatherEntity).trim();
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(defs.screensaverWeatherEntity.localizedTitle(context)),
        children: [
          RadioGroup<String>(
            groupValue: current,
            onChanged: (value) => Navigator.of(context).pop(value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  value: '',
                  title: Text(screensaverText(context, 'Not set')),
                ),
                for (final entity in _entities)
                  RadioListTile<String>(
                    value: entity.$1,
                    title: Text(entity.$2),
                    subtitle: Text(entity.$1),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked == null) return;
    await c.settings.set(defs.screensaverWeatherEntity, picked);
  }

  @override
  Widget build(BuildContext context) {
    final current = c.settings.get(defs.screensaverWeatherEntity).trim();
    return SettingsRow(
      stack: true,
      title: Text(defs.screensaverWeatherEntity.localizedTitle(context)),
      subtitle: Text(
        defs.screensaverWeatherEntity.localizedDescription(context),
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
    );
  }
}
