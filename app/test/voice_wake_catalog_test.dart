import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/managers/voice/chat_log.dart';
import 'package:kiosk_satellite/managers/voice/wake_catalog.dart';
import 'package:kiosk_satellite/managers/wake_word/engine.dart';

void main() {
  test('every bundled wake word and stop model has its files', () {
    for (final entry in bundledWakeWords.entries) {
      final engine = entry.key;
      for (final id in [
        ...entry.value,
        engine == WakeWordEngineType.vsWakeWord ? 'ok_stop' : 'stop',
      ]) {
        final url = bundledModelManifest(engine, id);
        final path = Uri.parse(url).path.replaceFirst('/', '');
        expect(File(path).existsSync(), isTrue, reason: '$engine $id: $path');
        if (engine == WakeWordEngineType.microWakeWord) {
          expect(File(path.replaceAll('.json', '.tflite')).existsSync(), isTrue);
        }
        if (engine == WakeWordEngineType.vsWakeWord) {
          final onnx = path.replaceAll('.json', '.onnx');
          expect(File(onnx).existsSync(), isTrue);
          expect(
            File(onnx.replaceFirst('vswakeword/', 'vswakeword/int8/'))
                .existsSync(),
            isTrue,
          );
        }
      }
    }
    for (final shared in ['melspectrogram', 'embedding_model']) {
      expect(
        File('assets/wake_words/openwakeword/$shared.onnx').existsSync(),
        isTrue,
      );
    }
  });

  test('phrases match Voice Satellite, which Home Assistant dedupes on', () {
    expect(wakeWordPhraseFor('ok_nabu'), 'Okay Nabu');
    expect(wakeWordPhraseFor('hey_jarvis'), 'Hey Jarvis');
    expect(wakeWordPhraseFor('okay_computer'), 'Okay Computer');
    expect(wakeWordPhraseFor('ok_nova'), 'Ok Nova');
  });

  test("sensitivity resolves to Voice Satellite's numbers", () {
    expect(confidenceScaleFor('slightly'), 1.10);
    expect(confidenceScaleFor('very'), 0.90);
    expect(confidenceScaleFor('very', stop: true), 0.95);
    expect(owwCutoffFor('moderately'), 0.5);
    expect(owwCutoffFor('slightly'), closeTo(0.6, 1e-9));
    expect(owwCutoffFor('very', stop: true), closeTo(0.6, 1e-9));
    final gate = energyGateFor('very', enabled: true);
    expect(gate.wakeRms, 0.025);
    expect(gate.sleepAfterChunks, 30);
  });

  test('the config keeps two known wake words, slot 1 first', () {
    final config = buildWakeConfig(
      engine: WakeWordEngineType.openWakeWord,
      activeIds: ['hey_jarvis', 'nope', 'ok_nabu', 'alexa'],
      sensitivity: 'slightly',
      noiseGate: true,
      stopWord: true,
    );
    expect([for (final m in config.models) m.id], ['hey_jarvis', 'ok_nabu']);
    expect(config.models.first.wakeWord, 'Hey Jarvis');
    expect(config.models.first.cutoff, closeTo(0.6, 1e-9));
    expect(config.stopModel?.id, 'stop');
    expect(config.stopModel?.cutoff, closeTo(0.7, 1e-9));
    expect(config.energyGate.enabled, isTrue);
  });

  test('an unknown set falls back to the engine first wake word', () {
    final config = buildWakeConfig(
      engine: WakeWordEngineType.vsWakeWord,
      activeIds: const ['okay_computer'],
      sensitivity: 'moderately',
      noiseGate: false,
      stopWord: false,
    );
    expect(config.models.single.id, 'ok_nabu');
    expect(config.stopModel, isNull);
    expect(config.models.single.cutoff, isNull);
  });

  test("Home Assistant's custom microWakeWord models join the offer", () {
    final external = [
      ExternalWakeWord.fromMap({
        'id': 'hey_kitchen',
        'wakeWord': 'Hey Kitchen',
        'url': 'http://ha/api/esphome/wake_words/hey_kitchen.json',
        'modelType': 'micro',
      })!,
    ];
    final mww = offeredWakeWords(
      WakeWordEngineType.microWakeWord,
      external: external,
    );
    expect(mww.last.id, 'hey_kitchen');
    expect(mww.last.manifestUrl, startsWith('http://ha/'));
    final vww = offeredWakeWords(
      WakeWordEngineType.vsWakeWord,
      external: external,
    );
    expect(vww.any((w) => w.id == 'hey_kitchen'), isFalse);
  });

  test('tool names and results read like Voice Satellite', () {
    expect(humanizeToolName('HassTurnOn'), 'Turn on');
    expect(
      humanizeToolName('voice-satellite-card-weather-forecast__get_weather_forecast'),
      'Get weather forecast',
    );
    expect(humanizeToolName('search_images'), 'Search images');
    final digest = digestLatestTurn([
      {'role': 'user', 'content': 'old'},
      {'role': 'assistant', 'content': 'old answer'},
      {'role': 'user', 'content': 'weather'},
      {
        'role': 'assistant',
        'content': null,
        'tool_calls': [
          {'id': 't1', 'tool_name': 'weather__get_weather_forecast'},
        ],
      },
      {
        'role': 'tool_result',
        'tool_call_id': 't1',
        'tool_name': 'weather__get_weather_forecast',
        'tool_result': {'forecast': [], 'current_temperature': 72},
      },
      {'role': 'assistant', 'content': 'Sunny.'},
    ]);
    expect(digest.tools, ['Get weather forecast']);
    expect(digest.results.single.kind, 'weather');
    expect(digest.answer, 'Sunny.');
    expect(stripSentimentTags('[happy] Sure thing!'), 'Sure thing!');
  });
}
