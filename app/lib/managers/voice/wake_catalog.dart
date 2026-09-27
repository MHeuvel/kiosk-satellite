import '../wake_word/engine.dart';
import '../wake_word/model_source.dart';

/// The wake words native Voice Satellite can listen for: the models bundled
/// with the app per engine, plus the microWakeWord models Home Assistant
/// offers from its `config/custom_wake_words` folder.
///
/// The tables here are Voice Satellite's own (its wake-word module and the
/// vsWakeWord and openWakeWord sensitivity modules), ported so a kiosk needs
/// nothing in Home Assistant beyond the satellite itself.

/// The engines, by the stored setting value.
const voiceEngines = <String, WakeWordEngineType>{
  'vswakeword': WakeWordEngineType.vsWakeWord,
  'microwakeword': WakeWordEngineType.microWakeWord,
  'openwakeword': WakeWordEngineType.openWakeWord,
};

/// Bundled model ids per engine, in the order the wake word selects offer
/// them. The stop classifiers are not wake words and are listed apart.
const bundledWakeWords = <WakeWordEngineType, List<String>>{
  WakeWordEngineType.vsWakeWord: [
    'ok_nabu',
    'hey_jarvis',
    'alexa',
    'hey_mycroft',
    'hey_home_assistant',
    'hey_luna',
    'ok_computer',
    'ok_luna',
    'ok_nova',
    'ok_vesta',
    'hey_vesta',
    'hey_alfred',
  ],
  WakeWordEngineType.microWakeWord: [
    'ok_nabu',
    'hey_jarvis',
    'alexa',
    'hey_mycroft',
    'hey_home_assistant',
    'hey_luna',
    'okay_computer',
    'hey_baby',
  ],
  WakeWordEngineType.openWakeWord: [
    'ok_nabu',
    'hey_jarvis',
    'alexa',
    'hey_mycroft',
    'home_assistant',
    'hey_luna',
    'okay_computer',
    'hey_rhasspy',
  ],
};

const _stopIds = <WakeWordEngineType, String>{
  WakeWordEngineType.vsWakeWord: 'ok_stop',
  WakeWordEngineType.microWakeWord: 'stop',
  WakeWordEngineType.openWakeWord: 'stop',
};

/// The phrases Home Assistant dedupes simultaneous wakes on and matches its
/// Wake word selects against (Voice Satellite's WAKE_WORD_PHRASES). Anything
/// else is title-cased from the id, as there.
const _phrases = <String, String>{
  'ok_nabu': 'Okay Nabu',
  'hey_jarvis': 'Hey Jarvis',
  'alexa': 'Alexa',
  'hey_mycroft': 'Hey Mycroft',
  'hey_home_assistant': 'Hey Home Assistant',
  'hey_luna': 'Hey Luna',
  'okay_computer': 'Okay Computer',
};

String wakeWordPhraseFor(String id) =>
    _phrases[id] ??
    id
        .split('_')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');

String _folder(WakeWordEngineType engine) => switch (engine) {
  WakeWordEngineType.vsWakeWord => 'vswakeword',
  WakeWordEngineType.microWakeWord => 'microwakeword',
  WakeWordEngineType.openWakeWord => 'openwakeword',
};

/// Where a bundled model is: a `.json` manifest for vsWakeWord and
/// microWakeWord (the stores derive the weights from it), the classifier
/// itself for openWakeWord, which ships no manifest.
String bundledModelManifest(WakeWordEngineType engine, String id) {
  final ext = engine == WakeWordEngineType.openWakeWord ? 'onnx' : 'json';
  return bundledModelUrl('assets/wake_words/${_folder(engine)}/$id.$ext');
}

/// A microWakeWord model Home Assistant offers from config/custom_wake_words.
class ExternalWakeWord {
  const ExternalWakeWord({
    required this.id,
    required this.wakeWord,
    required this.url,
    required this.modelType,
  });

  final String id;
  final String wakeWord;

  /// The manifest's URL on Home Assistant; the `.tflite` sits beside it.
  final String url;
  final String modelType;

  static ExternalWakeWord? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final id = '${raw['id'] ?? ''}';
    final url = '${raw['url'] ?? ''}';
    if (id.isEmpty || url.isEmpty) return null;
    return ExternalWakeWord(
      id: id,
      wakeWord: '${raw['wakeWord'] ?? ''}'.isEmpty
          ? wakeWordPhraseFor(id)
          : '${raw['wakeWord']}',
      url: url,
      modelType: '${raw['modelType'] ?? ''}',
    );
  }
}

/// A wake word the kiosk can offer: id, phrase and where its model is.
class OfferedWakeWord {
  const OfferedWakeWord(this.id, this.phrase, this.manifestUrl);
  final String id;
  final String phrase;
  final String manifestUrl;
}

/// Everything the engine can listen for right now: its bundled models, and
/// for microWakeWord the custom ones Home Assistant offered (their ids win
/// over a bundled model of the same id: the user put that file there).
List<OfferedWakeWord> offeredWakeWords(
  WakeWordEngineType engine, {
  List<ExternalWakeWord> external = const [],
}) {
  final custom = engine == WakeWordEngineType.microWakeWord
      ? [
          for (final w in external)
            if (w.modelType.isEmpty || w.modelType == 'micro') w,
        ]
      : const <ExternalWakeWord>[];
  final customIds = {for (final w in custom) w.id};
  return [
    for (final id in bundledWakeWords[engine] ?? const <String>[])
      if (!customIds.contains(id))
        OfferedWakeWord(
          id,
          wakeWordPhraseFor(id),
          bundledModelManifest(engine, id),
        ),
    for (final w in custom) OfferedWakeWord(w.id, w.wakeWord, w.url),
  ];
}

// ── Sensitivity (Voice Satellite's vsWakeWord and openWakeWord policy) ───

const _confFactors = {'slightly': 1.10, 'moderately': 1.00, 'very': 0.90};
const _stopConfFactors = {'slightly': 1.05, 'moderately': 1.00, 'very': 0.95};
const _owwWakeOffsets = {'slightly': 0.10, 'moderately': 0.0, 'very': -0.10};
const _owwStopOffsets = {'slightly': 0.05, 'moderately': 0.0, 'very': -0.05};
const _energyWake = {'slightly': 0.12, 'moderately': 0.06, 'very': 0.025};

/// The factor every confidence gate of a model is multiplied by.
double confidenceScaleFor(String sensitivity, {bool stop = false}) =>
    (stop ? _stopConfFactors : _confFactors)[sensitivity] ?? 1.0;

/// openWakeWord's absolute cutoff, which ships no manifest to scale.
double owwCutoffFor(String sensitivity, {bool stop = false}) {
  final base = stop ? 0.65 : 0.5;
  final offset = (stop ? _owwStopOffsets : _owwWakeOffsets)[sensitivity] ?? 0.0;
  return (base + offset).clamp(0.1, 0.99).toDouble();
}

EnergyGateConfig energyGateFor(String sensitivity, {required bool enabled}) =>
    EnergyGateConfig(
      enabled: enabled,
      wakeRms: _energyWake[sensitivity] ?? 0.06,
      sleepAfterChunks: 30,
    );

/// The engine config for the settings: the active wake words (slot 1
/// first), the stop classifier when stop word interruption is on, the gates
/// the sensitivity resolves to. Ids the engine does not offer are dropped;
/// with none left, slot 1 falls back to the engine's first.
WakeWordConfig buildWakeConfig({
  required WakeWordEngineType engine,
  required List<String> activeIds,
  required String sensitivity,
  required bool noiseGate,
  required bool stopWord,
  List<ExternalWakeWord> external = const [],
}) {
  final offered = offeredWakeWords(engine, external: external);
  final byId = {for (final w in offered) w.id: w};
  final picked = <OfferedWakeWord>[for (final id in activeIds) ?byId[id]];
  final unique = <String, OfferedWakeWord>{for (final w in picked) w.id: w};
  final models = unique.values.take(2).toList();
  if (models.isEmpty && offered.isNotEmpty) models.add(offered.first);
  final oww = engine == WakeWordEngineType.openWakeWord;
  WakeWordModelRef ref(OfferedWakeWord w, {bool stop = false}) =>
      WakeWordModelRef(
        id: w.id,
        wakeWord: w.phrase,
        manifestUrl: w.manifestUrl,
        confidenceScale: confidenceScaleFor(sensitivity, stop: stop),
        cutoff: oww ? owwCutoffFor(sensitivity, stop: stop) : null,
      );
  final stopId = _stopIds[engine]!;
  return WakeWordConfig(
    engine: engine,
    models: [for (final w in models) ref(w)],
    stopModel: stopWord
        ? ref(
            OfferedWakeWord(
              stopId,
              wakeWordPhraseFor(stopId),
              bundledModelManifest(engine, stopId),
            ),
            stop: true,
          )
        : null,
    energyGate: energyGateFor(sensitivity, enabled: noiseGate),
  );
}
