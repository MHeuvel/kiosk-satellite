import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/l10n/camera_view_messages.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings_en.dart';

class ViewerTestMessages extends UiStringsEn {
  @override
  String cameraViewerCannotDecode(String codec) => 'TEST "$codec"\nstatus';
  @override
  String cameraViewerServerRetry(String seconds) => 'TEST $seconds seconds';
}

void main() {
  test(
    'viewer bridge supplies every English pattern with runtime placeholders',
    () {
      final source =
          jsonDecode(
                File(
                  'l10n/source/camera_view_status_en.arb',
                ).readAsStringSync(),
              )
              as Map;
      final expected = Map<String, String>.fromEntries([
        for (final entry in source.entries)
          if (!(entry.key as String).startsWith('@'))
            MapEntry(entry.key as String, entry.value as String),
      ]);
      expect(cameraViewMessages(UiStringsEn()), expected);
    },
  );

  test(
    'translated patterns survive JSON injection with placeholders intact',
    () {
      final restored =
          jsonDecode(jsonEncode(cameraViewMessages(ViewerTestMessages())))
              as Map;
      expect(restored['cameraViewerCannotDecode'], 'TEST "{codec}"\nstatus');
      expect(restored['cameraViewerServerRetry'], 'TEST {seconds} seconds');
    },
  );
}
