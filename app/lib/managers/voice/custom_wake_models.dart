/// The custom wake word models added to the kiosk: uploaded in the remote
/// admin or picked on the device, and passed from a fleet leader to its
/// followers. One folder per engine under the app's support directory:
///
///   microwakeword/  name.json + name.tflite
///   vswakeword/     name.json + name.onnx
///   openwakeword/   name.onnx or name.tflite
///
/// A model is checked before it is kept: its manifest parses and its
/// weights load, so a bad file never reaches the engine.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../wake_word/engine.dart';
import '../wake_word/mww/mww_manifest.dart';
import '../wake_word/oww/oww_isolate.dart' show loadOwwTflite;
import '../wake_word/oww/oww_model_store.dart' show isTfliteModel;
import '../wake_word/oww/oww_pipeline.dart';
import '../wake_word/oww/onnx_ir.dart';
import '../wake_word/vsww/manifest.dart';
import '../wake_word/vsww/ort_init.dart';
import 'wake_catalog.dart';

/// A model file refused, and why.
/// Why a file is refused: the English and the message that says it in the
/// kiosk's language, [code] its message id and [values] its placeholders.
class WakeModelError implements Exception {
  const WakeModelError(this.code, this.english, [this.values = const {}]);

  final String code;
  final String english;
  final Map<String, String> values;

  @override
  String toString() => english;
}

class RejectedWakeFile {
  const RejectedWakeFile(
    this.file,
    this.reason, {
    this.code = '',
    this.values = const {},
  });
  final String file;
  final String reason;

  final String code;
  final Map<String, String> values;

  Map<String, Object?> toJson() => {
    'file': file,
    'reason': reason,
    if (code.isNotEmpty) 'code': code,
    if (values.isNotEmpty) 'values': values,
  };
}

class CustomWakeModels {
  CustomWakeModels({required this.onChanged, required this.log});

  /// The models changed: the engine and Home Assistant's selects follow.
  final void Function() onChanged;
  final void Function(String line) log;

  /// Largest file accepted. The biggest vsWakeWord models are a few MB.
  static const maxFileBytes = 64 * 1024 * 1024;

  static const _extensions = {'.json', '.tflite', '.onnx'};

  /// The models on the kiosk, complete ones only.
  List<CustomWakeWord> get models => _models;
  List<CustomWakeWord> _models = const [];

  /// Files and sizes of each model, by `folder/id`, for the lists.
  final _files = <String, List<({String name, int size})>>{};

  Directory? _root;

  Future<Directory> _dir([String? sub]) async {
    final root = _root ??= Directory(
      '${(await getApplicationSupportDirectory()).path}/custom_wake_words',
    );
    final dir = Directory(sub == null ? root.path : '${root.path}/$sub');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> init() => _reload(notify: false);

  // ── the list ───────────────────────────────────────────────────────────

  Future<void> _reload({bool notify = true}) async {
    final found = <CustomWakeWord>[];
    _files.clear();
    for (final engine in WakeWordEngineType.values) {
      final folder = engineFolder(engine);
      final dir = await _dir(folder);
      final names = <String, int>{
        await for (final f in dir.list())
          if (f is File) f.uri.pathSegments.last: await f.length(),
      };
      final stems = {for (final n in names.keys) _stem(n)}.toList()..sort();
      for (final stem in stems) {
        final json = names.containsKey('$stem.json');
        final String? weights = switch (engine) {
          WakeWordEngineType.microWakeWord =>
            json && names.containsKey('$stem.tflite') ? '$stem.tflite' : null,
          WakeWordEngineType.vsWakeWord =>
            json && names.containsKey('$stem.onnx') ? '$stem.onnx' : null,
          WakeWordEngineType.openWakeWord =>
            names.containsKey('$stem.onnx')
                ? '$stem.onnx'
                : names.containsKey('$stem.tflite')
                ? '$stem.tflite'
                : null,
        };
        // Half a model: a fleet transfer still arriving, or a pair missing
        // its other file. Not offered until it is whole.
        if (weights == null) continue;
        final main = engine == WakeWordEngineType.openWakeWord
            ? weights
            : '$stem.json';
        found.add(
          CustomWakeWord(
            engine: engine,
            id: stem,
            phrase: await _phraseOf(engine, stem, File('${dir.path}/$main')),
            url: File('${dir.path}/$main').uri.toString(),
          ),
        );
        _files['$folder/$stem'] = [
          if (json && engine != WakeWordEngineType.openWakeWord)
            (name: '$stem.json', size: names['$stem.json']!),
          (name: weights, size: names[weights]!),
        ];
      }
    }
    _models = found;
    if (notify) onChanged();
  }

  static String _stem(String name) {
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  static String _ext(String name) {
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(dot).toLowerCase() : '';
  }

  /// The phrase the model answers to: its manifest's wake word (or vsWakeWord's
  /// name), else the file name, title-cased when it reads like an id.
  static Future<String> _phraseOf(
    WakeWordEngineType engine,
    String stem,
    File main,
  ) async {
    var phrase = '';
    if (engine != WakeWordEngineType.openWakeWord) {
      try {
        final json = jsonDecode(await main.readAsString());
        if (json is Map) {
          phrase = '${json['wake_word'] ?? json['name'] ?? ''}'.trim();
        }
      } catch (_) {}
    }
    if (phrase.isEmpty || !phrase.contains(' ')) {
      phrase = wakeWordPhraseFor(phrase.isEmpty ? stem : phrase);
    }
    return phrase;
  }

  /// The models for the lists, with their files and sizes.
  List<Map<String, Object?>> describe() => [
    for (final m in _models)
      {
        'engine': engineFolder(m.engine),
        'id': m.id,
        'wakeWord': m.phrase,
        'files': [
          for (final f in _files['${engineFolder(m.engine)}/${m.id}'] ?? [])
            {'name': f.name, 'size': f.size},
        ],
      },
  ];

  // ── adding ─────────────────────────────────────────────────────────────

  /// Refuses what is not a model file name: no folders, only the three
  /// extensions.
  static WakeModelError? _checkName(String name) {
    if (name.isEmpty ||
        name.contains('/') ||
        name.contains(r'\') ||
        name.startsWith('.')) {
      return const WakeModelError('voiceModelNotFileName', 'Not a file name.');
    }
    if (!_extensions.contains(_ext(name))) {
      return const WakeModelError(
        'voiceModelBadExtension',
        'Only .json, .tflite and .onnx files are models.',
      );
    }
    return null;
  }

  static WakeModelError _tooLarge(String name) => WakeModelError(
    'voiceModelTooLarge',
    '$name is larger than 64 MB.',
    {'name': name},
  );

  /// Takes one uploaded file into the staging folder, to be checked with
  /// the others of the same upload by [commit].
  Future<void> stage(String name, Stream<List<int>> body, int? length) async {
    final bad = _checkName(name);
    if (bad != null) throw bad;
    if (length != null && length > maxFileBytes) throw _tooLarge(name);
    final dir = await _dir('.staging');
    final part = File('${dir.path}/$name.part');
    final sink = part.openWrite();
    var written = 0;
    try {
      await for (final chunk in body) {
        written += chunk.length;
        if (written > maxFileBytes) throw _tooLarge(name);
        sink.add(chunk);
      }
      await sink.close();
    } catch (_) {
      await sink.close().catchError((_) {});
      await part.delete().catchError((_) => part);
      rethrow;
    }
    if (written == 0 || (length != null && written != length)) {
      await part.delete();
      throw WakeModelError(
        'voiceModelIncomplete',
        '$name arrived incomplete.',
        {'name': name},
      );
    }
    await part.rename('${dir.path}/$name');
  }

  /// A file picked on the device, into the staging folder.
  Future<void> stageCopy(String path) async {
    final file = File(path);
    await stage(
      file.uri.pathSegments.last,
      file.openRead(),
      await file.length(),
    );
  }

  /// Checks what was staged, keeps each complete and working model in its
  /// engine's folder (replacing one of the same name) and clears the
  /// staging folder. Returns the models kept and the files refused.
  Future<Map<String, Object?>> commit() async {
    final staging = await _dir('.staging');
    final files = <String, File>{
      await for (final f in staging.list())
        if (f is File && !f.path.endsWith('.part')) f.uri.pathSegments.last: f,
    };
    final byStem = <String, Map<String, File>>{};
    for (final e in files.entries) {
      (byStem[_stem(e.key)] ??= {})[_ext(e.key)] = e.value;
    }
    final added = <Map<String, Object?>>[];
    final rejected = <RejectedWakeFile>[];
    for (final e in byStem.entries) {
      final stem = e.key;
      final group = e.value;
      final names = [for (final f in group.values) f.uri.pathSegments.last];
      try {
        final (engine, keep) = await _classify(stem, group);
        final dir = await _dir(engineFolder(engine));
        // A model of the same name is replaced whole: a new .onnx must not
        // leave an old .tflite of the same openWakeWord name behind.
        await for (final old in dir.list()) {
          if (old is File && _stem(old.uri.pathSegments.last) == stem) {
            await old.delete();
          }
        }
        for (final f in keep) {
          await f.rename('${dir.path}/${f.uri.pathSegments.last}');
        }
        added.add({'engine': engineFolder(engine), 'id': stem});
        log('custom model ${engineFolder(engine)}/$stem added');
      } catch (err) {
        final reason = err is StateError ? err.message : '$err';
        for (final n in names) {
          rejected.add(
            err is WakeModelError
                ? RejectedWakeFile(
                    n,
                    reason,
                    code: err.code,
                    values: err.values,
                  )
                : RejectedWakeFile(n, reason),
          );
        }
        log('custom model $stem refused: $reason');
      }
    }
    await _clear(staging);
    if (added.isNotEmpty) await _reload();
    return {
      'added': added,
      'rejected': [for (final r in rejected) r.toJson()],
    };
  }

  Future<void> _clear(Directory dir) async {
    await for (final f in dir.list()) {
      await f.delete(recursive: true).catchError((_) => f);
    }
  }

  /// Which engine a group of files with one name is for, and the files to
  /// keep, once its model has loaded. Throws a [StateError] saying what is
  /// wrong.
  Future<(WakeWordEngineType, List<File>)> _classify(
    String stem,
    Map<String, File> group,
  ) async {
    final json = group['.json'];
    final tflite = group['.tflite'];
    final onnx = group['.onnx'];
    if (json != null) {
      Object? manifest;
      try {
        manifest = jsonDecode(await json.readAsString());
      } catch (_) {
        throw WakeModelError(
          'voiceModelBadJson',
          '$stem.json is not valid JSON.',
          {'file': '$stem.json'},
        );
      }
      if (manifest is! Map) {
        throw WakeModelError(
          'voiceModelNotManifest',
          '$stem.json is not a manifest.',
          {'file': '$stem.json'},
        );
      }
      if (manifest['micro'] is Map || manifest['type'] == 'micro') {
        if (tflite == null) {
          throw WakeModelError(
            'voiceModelMwwNeedsTflite',
            'A microWakeWord model needs $stem.tflite too.',
            {'file': '$stem.tflite'},
          );
        }
        if (MwwManifest.fromJson(manifest.cast<String, Object?>()) == null) {
          throw WakeModelError(
            'voiceModelMwwBadManifest',
            '$stem.json is not a valid microWakeWord manifest.',
            {'file': '$stem.json'},
          );
        }
        await _check(_Check.micro, await tflite.readAsBytes());
        return (WakeWordEngineType.microWakeWord, [json, tflite]);
      }
      if (manifest['format'] == 'vs-wake-word-ctc-v1') {
        if (onnx == null) {
          throw WakeModelError(
            'voiceModelVswwNeedsOnnx',
            'A vsWakeWord model needs $stem.onnx too.',
            {'file': '$stem.onnx'},
          );
        }
        try {
          if (!VswwManifest.fromJson(manifest.cast<String, dynamic>()).isCtc) {
            throw const FormatException();
          }
        } catch (_) {
          throw WakeModelError(
            'voiceModelVswwBadManifest',
            '$stem.json is not a valid vsWakeWord manifest.',
            {'file': '$stem.json'},
          );
        }
        await _check(_Check.onnx, await onnx.readAsBytes());
        return (WakeWordEngineType.vsWakeWord, [json, onnx]);
      }
      throw WakeModelError(
        'voiceModelUnknownManifest',
        '$stem.json is neither a microWakeWord nor a vsWakeWord manifest.',
        {'file': '$stem.json'},
      );
    }
    // No manifest: an openWakeWord classifier, in either format.
    final model = onnx ?? tflite;
    if (model == null) {
      throw WakeModelError(
        'voiceModelNoModelFile',
        'No model file for $stem.',
        {'name': stem},
      );
    }
    if (onnx != null && tflite != null) {
      throw WakeModelError(
        'voiceModelBothFormats',
        'Add either $stem.onnx or $stem.tflite, not both.',
        {'onnx': '$stem.onnx', 'tflite': '$stem.tflite'},
      );
    }
    final bytes = await model.readAsBytes();
    try {
      await _check(_Check.oww, bytes);
    } catch (e) {
      if (tflite != null) {
        throw WakeModelError(
          'voiceModelNotOwwTflite',
          '$stem.tflite is not an openWakeWord model. A microWakeWord model '
              'needs its $stem.json too.',
          {'file': '$stem.tflite', 'json': '$stem.json'},
        );
      }
      rethrow;
    }
    return (WakeWordEngineType.openWakeWord, [model]);
  }

  /// Loads the model in a short lived isolate, off the UI.
  static Future<void> _check(_Check kind, Uint8List bytes) async {
    final error = await Isolate.run(() => _load(kind, bytes));
    if (error != null) {
      throw WakeModelError(error.code, error.english, error.values);
    }
  }

  // ── removing ───────────────────────────────────────────────────────────

  Future<bool> delete(String folder, String id) async {
    final engine = _engineOf(folder);
    if (engine == null || _checkName('$id.json') != null) return false;
    final dir = await _dir(folder);
    var removed = false;
    await for (final f in dir.list()) {
      if (f is File && _stem(f.uri.pathSegments.last) == id) {
        await f.delete();
        removed = true;
      }
    }
    if (removed) {
      log('custom model $folder/$id deleted');
      await _reload();
    }
    return removed;
  }

  static WakeWordEngineType? _engineOf(String folder) {
    for (final e in WakeWordEngineType.values) {
      if (engineFolder(e) == folder) return e;
    }
    return null;
  }

  // ── the fleet ──────────────────────────────────────────────────────────

  /// Every file with its SHA-256, by `folder/name`: what a leader compares
  /// with a follower's.
  Future<Map<String, String>> manifest() async {
    final out = <String, String>{};
    for (final engine in WakeWordEngineType.values) {
      final folder = engineFolder(engine);
      final dir = await _dir(folder);
      await for (final f in dir.list()) {
        if (f is! File || f.path.endsWith('.part')) continue;
        final name = f.uri.pathSegments.last;
        out['$folder/$name'] = (await sha256.bind(f.openRead()).first)
            .toString();
      }
    }
    return out;
  }

  /// The file at [path] (`folder/name`), for a leader sending it on.
  Future<File?> file(String path) async {
    final parts = path.split('/');
    if (parts.length != 2 ||
        _engineOf(parts[0]) == null ||
        _checkName(parts[1]) != null) {
      return null;
    }
    final f = File('${(await _dir(parts[0])).path}/${parts[1]}');
    return await f.exists() ? f : null;
  }

  /// A file from the fleet leader, written straight into place: the leader
  /// already checked it. Complete models appear once their last file lands.
  Future<void> receive(String path, Stream<List<int>> body, int? length) async {
    final parts = path.split('/');
    if (parts.length != 2 || _engineOf(parts[0]) == null) {
      throw StateError('Not a model path.');
    }
    final bad = _checkName(parts[1]);
    if (bad != null) throw bad;
    final dir = await _dir(parts[0]);
    final part = File('${dir.path}/${parts[1]}.part');
    final sink = part.openWrite();
    var written = 0;
    try {
      await for (final chunk in body) {
        written += chunk.length;
        if (written > maxFileBytes) throw StateError('Larger than 64 MB.');
        sink.add(chunk);
      }
      await sink.close();
    } catch (_) {
      await sink.close().catchError((_) {});
      await part.delete().catchError((_) => part);
      rethrow;
    }
    if (length != null && written != length) {
      await part.delete();
      throw StateError('Arrived incomplete.');
    }
    await part.rename('${dir.path}/${parts[1]}');
    _scheduleReload();
  }

  /// Removes a file the fleet leader no longer has.
  Future<void> remove(String path) async {
    final f = await file(path);
    if (f == null) return;
    await f.delete();
    _scheduleReload();
  }

  /// A leader sends files one at a time: the engine and Home Assistant
  /// follow once, after the last.
  Timer? _reloadTimer;
  void _scheduleReload() {
    _reloadTimer?.cancel();
    _reloadTimer = Timer(const Duration(seconds: 2), () => _reload());
  }

  void dispose() => _reloadTimer?.cancel();
}

enum _Check { micro, onnx, oww }

/// What the checking isolate found wrong with a model: a [WakeModelError]'s
/// parts, sent back across the isolate.
typedef _LoadError = ({
  String code,
  String english,
  Map<String, String> values,
});

_LoadError _loadError(
  String code,
  String english, [
  Map<String, String> values = const {},
]) => (code: code, english: english, values: values);

/// In the checking isolate: null when the model loads, else what is wrong.
_LoadError? _load(_Check kind, Uint8List bytes) {
  try {
    switch (kind) {
      case _Check.micro:
        if (!isTfliteModel(bytes)) {
          return _loadError('voiceModelNotTflite', 'Not a TFLite model.');
        }
        Interpreter.fromBuffer(bytes).close();
      case _Check.onnx:
        if (isTfliteModel(bytes)) {
          return _loadError('voiceModelNotOnnx', 'Not an ONNX model.');
        }
        _onnxSession(bytes).release();
      case _Check.oww:
        if (isTfliteModel(bytes)) {
          final interpreter = loadOwwTflite(bytes);
          final input = interpreter.getInputTensor(0);
          input.data = Uint8List(input.numBytes());
          interpreter
            ..invoke()
            ..close();
          return null;
        }
        final session = _onnxSession(bytes);
        final input = OrtValueTensor.createTensorWithDataList(
          Float32List(OwwPipeline.embeddingWindow * OwwPipeline.embeddingDim),
          [1, OwwPipeline.embeddingWindow, OwwPipeline.embeddingDim],
        );
        final options = OrtRunOptions();
        try {
          final out = session.run(options, {session.inputNames.first: input});
          final value = out.isEmpty ? null : out.first?.value;
          for (final o in out) {
            o?.release();
          }
          if (value == null) {
            return _loadError('voiceModelNotOww', 'Not an openWakeWord model.');
          }
        } catch (_) {
          return _loadError(
            'voiceModelOwwWindow',
            'Not an openWakeWord model: it does not take the 16 x 96 '
                'embedding window.',
          );
        } finally {
          input.release();
          options.release();
          session.release();
        }
    }
    return null;
  } catch (e) {
    return _loadError('voiceModelNoLoad', 'The model does not load: $e', {
      'error': '$e',
    });
  }
}

OrtSession _onnxSession(Uint8List bytes) {
  ensureOrtInit();
  final patched = Uint8List.fromList(bytes);
  downgradeIrVersion(patched);
  final options = OrtSessionOptions();
  try {
    return OrtSession.fromBuffer(patched, options);
  } finally {
    options.release();
  }
}
