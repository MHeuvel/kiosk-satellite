import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/managers/voice/voice_manager.dart';

void main() {
  const tts = 'http://192.168.178.96/api/tts_proxy/abc123.mp3';

  test('a speech URL moves to the Home Assistant URL the kiosk uses', () {
    expect(
      speechUrlOnKioskHa(tts, 'http://homeassistant.local:8123'),
      'http://homeassistant.local:8123/api/tts_proxy/abc123.mp3',
    );
  });

  test('the scheme and default port follow the kiosk URL', () {
    expect(
      speechUrlOnKioskHa(tts, 'https://ha.example.com/'),
      'https://ha.example.com/api/tts_proxy/abc123.mp3',
    );
  });

  test('a path on the kiosk URL is not carried over', () {
    expect(
      speechUrlOnKioskHa(tts, 'http://10.0.0.2:8123/dashboard-home/main'),
      'http://10.0.0.2:8123/api/tts_proxy/abc123.mp3',
    );
  });

  test('a relative speech path gets the kiosk URL', () {
    expect(
      speechUrlOnKioskHa('/api/tts_proxy/abc123.flac', 'http://10.0.0.2:8123'),
      'http://10.0.0.2:8123/api/tts_proxy/abc123.flac',
    );
  });

  test('other URLs and a missing kiosk URL leave it alone', () {
    const media = 'http://192.168.178.96:8123/media/local/ding.mp3?authSig=x';
    expect(speechUrlOnKioskHa(media, 'http://10.0.0.2:8123'), media);
    expect(speechUrlOnKioskHa(tts, ''), tts);
    expect(speechUrlOnKioskHa(tts, 'homeassistant.local:8123'), tts);
  });
}
