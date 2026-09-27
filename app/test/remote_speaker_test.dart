import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/managers/voice/ha_socket.dart';
import 'package:kiosk_satellite/managers/voice/remote_speaker.dart';

/// Home Assistant with one media player: entity subscriptions get its
/// state as the compressed messages, service calls are recorded.
class _Ha extends HaSocket {
  _Ha(this.initial) : super(baseUrl: () => '', token: () => '');

  final Map<String, Object?> initial;
  final calls = <Map<String, Object?>>[];
  final _listeners = <void Function(Map<String, Object?> event)>[];
  bool failPlay = false;

  static const entity = 'media_player.kitchen';

  @override
  Future<Object?> request(
    Map<String, Object?> command, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    calls.add(command);
    if (failPlay && command['service'] == 'play_media') {
      throw StateError('unavailable');
    }
    return null;
  }

  @override
  Future<Future<void> Function()> subscribe(
    Map<String, Object?> command,
    void Function(Map<String, Object?> event) onEvent, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    _listeners.add(onEvent);
    onEvent({
      'a': {entity: initial},
    });
    return () async => _listeners.remove(onEvent);
  }

  /// The player's state changes.
  void change(String state, [Map<String, Object?> attributes = const {}]) {
    for (final listener in [..._listeners]) {
      listener({
        'c': {
          entity: {
            '+': {'s': state, 'a': attributes},
          },
        },
      });
    }
  }

  List<String> get services => [
    for (final c in calls)
      if (c['type'] == 'call_service') '${c['service']}',
  ];

  Map<Object?, Object?> data(String service, {bool last = false}) {
    final matching = calls.where((c) => c['service'] == service);
    return (last ? matching.last : matching.first)['service_data']! as Map;
  }
}

const _music = {
  's': 'playing',
  'a': {
    'media_content_id': 'http://radio/stream',
    'media_content_type': 'music',
    'media_position': 42,
    'media_duration': 300,
  },
};

void main() {
  const url = 'https://ha.local:8123/api/tts_proxy/abc123.mp3';
  const ours = {'media_content_id': 'http://ha:8123/api/tts_proxy/abc123.mp3'};
  const chime = 'http://192.168.1.5:40000/token/done.mp3';

  RemoteSpeaker speakerFor(
    _Ha ha,
    List<String> ended, {
    Future<double?> Function(String, Duration)? measure,
    List<Duration>? progress,
  }) => RemoteSpeaker(
    ha: ha,
    onEnded: (id, {error}) => ended.add(id),
    onProgress: (id, position, length) => progress?.add(length),
    measure: measure,
    log: (_) {},
  );

  test('a Cast player: our speech buffers, plays and stops', () {
    fakeAsync((async) {
      final ha = _Ha({'s': 'idle', 'a': <String, Object?>{}});
      final ended = <String>[];
      final speaker = speakerFor(ha, ended);
      String? id;
      speaker.play(_Ha.entity, url, normal: false).then((v) => id = v);
      async.flushMicrotasks();
      // Relative, for Home Assistant to resolve and sign for the speaker.
      expect(
        ha.data('play_media')['media_content_id'],
        '/api/tts_proxy/abc123.mp3',
      );
      expect(ha.data('play_media')['announce'], isTrue);
      ha.change('buffering', ours);
      ha.change('playing', ours);
      expect(ended, isEmpty);
      ha.change('idle');
      expect(ended, [id]);
      // Once only.
      ha.change('playing', ours);
      ha.change('idle');
      expect(ended, [id]);
    });
  });

  test('announcing over music ends when the music comes back', () {
    fakeAsync((async) {
      final ha = _Ha({
        's': 'playing',
        'a': {'media_content_id': 'spotify:track:1'},
      });
      final ended = <String>[];
      final speaker = speakerFor(ha, ended);
      speaker.play(_Ha.entity, url, normal: false);
      async.flushMicrotasks();
      // Still the music: not our speech yet.
      ha.change('playing', {'media_content_id': 'spotify:track:1'});
      expect(ended, isEmpty);
      ha.change('playing', {'media_content_id': 'announcement'});
      expect(ended, isEmpty);
      ha.change('playing', {'media_content_id': 'spotify:track:1'});
      expect(ended, hasLength(1));
    });
  });

  test('normal playback: snapshot at the wake chime, music back after '
      'the done chime', () {
    fakeAsync((async) {
      final ha = _Ha(_music);
      final ended = <String>[];
      final speaker = speakerFor(ha, ended);
      speaker.chime(_Ha.entity, chime, 0.3, normal: true);
      async.flushMicrotasks();
      expect(ha.data('play_media')['announce'], isFalse);
      speaker.play(_Ha.entity, url, normal: true);
      async.flushMicrotasks();
      ha.change('playing', ours);
      ha.change('idle');
      // The answer, the wake chime's length not yet gone by.
      expect(ended, hasLength(1));
      // The answer's restore waits for a chime that may follow.
      async.elapse(const Duration(milliseconds: 1000));
      speaker.chime(_Ha.entity, chime, 0.3, normal: true, end: true);
      async.flushMicrotasks();
      // Rescheduled after the done chime: 0.3 s plus half a second.
      async.elapse(const Duration(milliseconds: 700));
      expect(ha.services, ['play_media', 'play_media', 'play_media']);
      async.elapse(const Duration(milliseconds: 200));
      expect(ha.services, hasLength(4));
      final restore = ha.data('play_media', last: true);
      // The music as it was before the wake chime, not the chime.
      expect(restore['media_content_id'], 'http://radio/stream');
      expect((restore['extra']! as Map)['current_time'], 42);
      async.elapse(const Duration(milliseconds: 1500));
      expect(ha.services.last, 'media_seek');
      expect(ha.data('media_seek')['seek_position'], 42);
    });
  });

  test('a restore pending when more sound comes is put off', () {
    fakeAsync((async) {
      final ha = _Ha(_music);
      final speaker = speakerFor(ha, []);
      speaker.chime(_Ha.entity, chime, 0.3, normal: true, end: true);
      async.flushMicrotasks();
      async.elapse(const Duration(milliseconds: 500));
      // A follow-up's chime before the restore fired.
      speaker.chime(_Ha.entity, chime, 0.3, normal: true);
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 5));
      expect(ha.services, ['play_media', 'play_media']);
      speaker.settle();
      async.elapse(const Duration(milliseconds: 1500));
      expect(ha.services, ['play_media', 'play_media', 'play_media']);
    });
  });

  test('media at its end is not restored', () {
    fakeAsync((async) {
      final ha = _Ha({
        's': 'playing',
        'a': {
          'media_content_id': 'http://radio/song.mp3',
          'media_position': 299,
          'media_duration': 300,
        },
      });
      final speaker = speakerFor(ha, []);
      speaker.chime(_Ha.entity, chime, 0.3, normal: true, end: true);
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 5));
      expect(ha.services, ['play_media']);
    });
  });

  test('our own speech is never taken for the music', () {
    fakeAsync((async) {
      final ha = _Ha({'s': 'playing', 'a': ours});
      final speaker = speakerFor(ha, []);
      speaker.chime(_Ha.entity, chime, 0.3, normal: true);
      async.flushMicrotasks();
      speaker.settle();
      async.elapse(const Duration(seconds: 5));
      expect(ha.services, ['play_media']);
    });
  });

  test('stopping: announcement mode stops the player, normal playback '
      'puts the music back', () {
    fakeAsync((async) {
      final ha = _Ha({'s': 'idle', 'a': <String, Object?>{}});
      final ended = <String>[];
      final speaker = speakerFor(ha, ended);
      String? id;
      speaker.play(_Ha.entity, url, normal: false).then((v) => id = v);
      async.flushMicrotasks();
      speaker.stop(id!);
      async.flushMicrotasks();
      expect(ended, [id]);
      expect(ha.services, ['play_media', 'media_stop']);

      final music = _Ha(_music);
      final normal = speakerFor(music, []);
      normal.play(_Ha.entity, url, normal: true).then((v) => id = v);
      async.flushMicrotasks();
      normal.stop(id!);
      async.flushMicrotasks();
      async.elapse(const Duration(milliseconds: 1500));
      expect(music.services, ['play_media', 'play_media']);
      expect(
        music.data('play_media', last: true)['media_content_id'],
        'http://radio/stream',
      );
    });
  });

  test('a refused call ends the sound as played', () {
    fakeAsync((async) {
      final ha = _Ha({'s': 'idle', 'a': <String, Object?>{}})..failPlay = true;
      final errors = <String?>[];
      final speaker = RemoteSpeaker(
        ha: ha,
        onEnded: (id, {error}) => errors.add(error),
        log: (_) {},
      );
      speaker.play(_Ha.entity, url, normal: false);
      async.flushMicrotasks();
      expect(errors, [null]);
    });
  });

  test('a player that reports nothing is let go after 30 seconds, or '
      'after a long answer', () {
    fakeAsync((async) {
      final ha = _Ha({'s': 'idle', 'a': <String, Object?>{}});
      final ended = <String>[];
      final speaker = speakerFor(ha, ended);
      speaker.play(_Ha.entity, url, normal: false, text: 'Sure.');
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 29));
      expect(ended, isEmpty);
      async.elapse(const Duration(seconds: 1));
      expect(ended, hasLength(1));

      speaker.play(
        _Ha.entity,
        url,
        normal: false,
        text: List.filled(100, 'word').join(' '),
      );
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 31));
      expect(ended, hasLength(1));
      async.elapse(const Duration(seconds: 30));
      expect(ended, hasLength(2));
    });
  });

  test('a measured answer ends by its length, or when the player shows '
      'it and stops', () {
    fakeAsync((async) {
      final ha = _Ha({
        's': 'playing',
        'a': {'media_content_id': 'spotify:track:1'},
      });
      final ended = <String>[];
      final progress = <Duration>[];
      final speaker = speakerFor(
        ha,
        ended,
        measure: (url, timeout) async => 4.0,
        progress: progress,
      );
      speaker.play(_Ha.entity, url, normal: false);
      async.flushMicrotasks();
      expect(progress, [const Duration(seconds: 4)]);
      // Announce mode blips back to the music early: the length decides.
      ha.change('playing', {'media_content_id': 'announcement'});
      ha.change('playing', {'media_content_id': 'spotify:track:1'});
      expect(ended, isEmpty);
      async.elapse(const Duration(seconds: 6));
      expect(ended, hasLength(1));

      speaker.play(_Ha.entity, url, normal: false);
      async.flushMicrotasks();
      ha.change('playing', ours);
      ha.change('idle');
      expect(ended, hasLength(2));
    });
  });

  test('the timer phrase plays for its length, and stops the player', () {
    fakeAsync((async) {
      final ha = _Ha({'s': 'idle', 'a': <String, Object?>{}});
      final ended = <String>[];
      final speaker = speakerFor(ha, ended, measure: (url, timeout) async => 2);
      speaker.play(_Ha.entity, url, normal: false, kind: RemoteSound.timed);
      async.flushMicrotasks();
      async.elapse(const Duration(milliseconds: 2700));
      expect(ended, isEmpty);
      async.elapse(const Duration(milliseconds: 100));
      expect(ended, hasLength(1));

      String? id;
      speaker.chime(_Ha.entity, chime, 0.6, normal: false).then((v) => id = v);
      async.flushMicrotasks();
      speaker.stop(id!);
      async.flushMicrotasks();
      expect(ended, hasLength(2));
      expect(ha.services.last, 'media_stop');
    });
  });
}
