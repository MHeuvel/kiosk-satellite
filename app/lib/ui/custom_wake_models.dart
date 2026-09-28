import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_container.dart';
import '../core/events.dart';
import '../l10n/messages.dart';
import 'kit.dart';
import 'settings_search.dart';
import 'toast.dart';

/// Where the custom wake word models are explained.
const customWakeModelsDocs =
    'https://github.com/jxlarrea/kiosk-satellite/blob/main/docs/custom-wake-words.md';

/// The engines as the lists name them.
const customWakeEngineLabels = {
  'microwakeword': 'microWakeWord',
  'openwakeword': 'openWakeWord',
  'vswakeword': 'vsWakeWord',
};

/// Why a custom model file was refused, in the kiosk's language: the store
/// sends its message's code and values beside the English, which stays for
/// what has no code (an error from the model's loader).
String wakeModelReason(BuildContext context, Map<Object?, Object?> file) {
  final strings = l10n(context);
  final values = file['values'];
  String v(String key) => values is Map ? '${values[key] ?? ''}' : '';
  return switch (file['code']) {
    'voiceModelNotFileName' => strings.voiceModelNotFileName,
    'voiceModelBadExtension' => strings.voiceModelBadExtension,
    'voiceModelTooLarge' => strings.voiceModelTooLarge(v('name')),
    'voiceModelIncomplete' => strings.voiceModelIncomplete(v('name')),
    'voiceModelBadJson' => strings.voiceModelBadJson(v('file')),
    'voiceModelNotManifest' => strings.voiceModelNotManifest(v('file')),
    'voiceModelMwwNeedsTflite' => strings.voiceModelMwwNeedsTflite(v('file')),
    'voiceModelMwwBadManifest' => strings.voiceModelMwwBadManifest(v('file')),
    'voiceModelVswwNeedsOnnx' => strings.voiceModelVswwNeedsOnnx(v('file')),
    'voiceModelVswwBadManifest' => strings.voiceModelVswwBadManifest(v('file')),
    'voiceModelUnknownManifest' => strings.voiceModelUnknownManifest(v('file')),
    'voiceModelNoModelFile' => strings.voiceModelNoModelFile(v('name')),
    'voiceModelBothFormats' => strings.voiceModelBothFormats(
      v('onnx'),
      v('tflite'),
    ),
    'voiceModelNotOwwTflite' => strings.voiceModelNotOwwTflite(
      v('file'),
      v('json'),
    ),
    'voiceModelNotTflite' => strings.voiceModelNotTflite,
    'voiceModelNotOnnx' => strings.voiceModelNotOnnx,
    'voiceModelNotOww' => strings.voiceModelNotOww,
    'voiceModelOwwWindow' => strings.voiceModelOwwWindow,
    'voiceModelNoLoad' => strings.voiceModelNoLoad(v('error')),
    _ => '${file['reason'] ?? ''}',
  };
}

/// The Custom Models group on the Voice Satellite Wake Word page: the models
/// added to the kiosk, a way to add more and the documentation. The remote
/// admin draws the same group from customWakeModels.
class CustomWakeModelsGroup extends StatefulWidget {
  const CustomWakeModelsGroup({super.key, required this.container});

  final AppContainer container;

  @override
  State<CustomWakeModelsGroup> createState() => _CustomWakeModelsGroupState();
}

class _CustomWakeModelsGroupState extends State<CustomWakeModelsGroup> {
  List<Map<Object?, Object?>> _models = const [];
  String _engine = '';
  bool _managed = false;
  bool _busy = false;
  StreamSubscription<RemoteStatusChanged>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.container.bus.on<RemoteStatusChanged>().listen((e) {
      if (e.topic == 'wake-models') unawaited(_load());
    });
    unawaited(_load());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await widget.container.commands.execute(
      'customWakeModels',
      const {},
    );
    final data = r.data;
    if (!mounted || !r.ok || data is! Map) return;
    setState(() {
      _models = [
        for (final m in (data['models'] as List? ?? const []))
          if (m is Map) m,
      ];
      _engine = '${data['engine'] ?? ''}';
      _managed = data['managed'] == true;
    });
  }

  Future<void> _add() async {
    final picked = await FilePicker.platform.pickFiles(allowMultiple: true);
    final paths = [
      for (final f in picked?.files ?? const <PlatformFile>[]) ?f.path,
    ];
    if (paths.isEmpty || !mounted) return;
    setState(() => _busy = true);
    final r = await widget.container.commands.execute(
      'addCustomWakeModelFiles',
      {'paths': paths},
    );
    if (!mounted) return;
    setState(() => _busy = false);
    final data = r.data;
    if (!r.ok || data is! Map) {
      showToast(
        context,
        title: voiceText(context, 'The models were not added.'),
        message: voiceText(context, r.error ?? ''),
        kind: ToastKind.error,
      );
      return;
    }
    final added = data['added'] as List? ?? const [];
    final rejected = data['rejected'] as List? ?? const [];
    if (rejected.isNotEmpty) {
      showToast(
        context,
        title: added.isEmpty
            ? voiceText(context, 'The models were not added.')
            : voiceText(context, 'Some files were not added.'),
        message: {
          for (final f in rejected)
            if (f is Map) '${f['file']}: ${wakeModelReason(context, f)}',
        }.join('\n'),
        kind: ToastKind.error,
        // Long enough to read each file's reason.
        duration: const Duration(seconds: 8),
      );
    } else {
      showToast(
        context,
        title: voiceText(context, 'Models added.'),
        kind: ToastKind.success,
      );
    }
    await _load();
  }

  Future<void> _delete(Map<Object?, Object?> model) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(voiceText(ctx, 'Delete this model?')),
        content: Text('${model['wakeWord']}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(voiceText(ctx, 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(voiceText(ctx, 'Delete')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final r = await widget.container.commands.execute('deleteCustomWakeModel', {
      'engine': model['engine'],
      'id': model['id'],
    });
    if (!mounted) return;
    if (!r.ok) {
      showToast(
        context,
        title: voiceText(context, 'The model was not deleted.'),
        message: voiceText(context, r.error ?? ''),
        kind: ToastKind.error,
      );
    }
    await _load();
  }

  Widget _row(BuildContext context, Map<Object?, Object?> m) {
    final engine = '${m['engine']}';
    final label = customWakeEngineLabels[engine] ?? engine;
    final files = [
      for (final f in (m['files'] as List? ?? const []))
        if (f is Map) '${f['name']}',
    ].join(', ');
    return SettingsRow(
      title: Text('${m['wakeWord']}'),
      subtitle: Text(
        engine == _engine
            ? '$label\n$files'
            : '$label, ${voiceText(context, 'not the engine in use')}\n$files',
      ),
      trailing: _managed
          ? null
          : IconButton(
              tooltip: voiceText(context, 'Delete'),
              onPressed: _busy ? null : () => _delete(m),
              icon: const Icon(Icons.delete_outline),
            ),
    );
  }

  @override
  Widget build(BuildContext context) => SearchLandingTarget(
    id: 'x:vs_custom_models',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(voiceText(context, 'Custom Models')),
        SettingsCard(
          children: [
            if (_models.isEmpty)
              HintRow(voiceText(context, 'No custom models yet.'))
            else
              for (final m in _models) _row(context, m),
          ],
        ),
        // Adding, and the documentation, each in a card of its own under
        // the list.
        SettingsCard(
          children: [
            if (_managed)
              HintRow(
                voiceText(
                  context,
                  'The fleet leader manages the custom models on this kiosk.',
                ),
              )
            else
              SettingsRow(
                title: Text(voiceText(context, 'Add models')),
                subtitle: Text(
                  voiceText(
                    context,
                    'Pick the files of one or more models. They show up in Wake '
                    'word 1 and 2 above.',
                  ),
                ),
                trailing: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                enabled: !_busy,
                onTap: _add,
              ),
          ],
        ),
        SettingsCard(
          children: [
            SettingsRow(
              title: Text(voiceText(context, 'How to add custom models')),
              subtitle: Text(
                voiceText(
                  context,
                  'The files each engine needs and where the models come from.',
                ),
              ),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => launchUrl(
                Uri.parse(customWakeModelsDocs),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
