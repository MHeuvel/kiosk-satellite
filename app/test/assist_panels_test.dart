import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/managers/voice/assist_view.dart';
import 'package:kiosk_satellite/ui/assist/assist_panels.dart';
import 'package:kiosk_satellite/ui/assist/assist_skins.dart';

void main() {
  const results = [
    AssistResult('weather', {
      'current_temperature': '72 °F',
      'current_humidity': '40%',
      'forecast_type': 'daily',
      'forecast': [
        {'date': '2026-09-27', 'condition': 'sunny', 'temperature': 75},
        {'date': '2026-09-28', 'condition': 'rainy', 'temperature': 64},
      ],
    }),
    AssistResult('weather', {
      'forecast_type': 'twice_daily',
      'forecast': [
        {'date': '2026-09-27', 'condition': 'cloudy', 'is_daytime': false},
      ],
    }),
    AssistResult('financial', {
      'query_type': 'stock',
      'name': 'Apple',
      'symbol': 'AAPL',
      'exchange': 'NASDAQ - Real Time',
      'current_price': 231.5,
      'change': -1.25,
      'percent_change': -0.54,
      'open': 232,
      'high': 233.1,
      'low': 230.2,
    }),
    AssistResult('financial', {
      'query_type': 'crypto',
      'name': 'Bitcoin',
      'current_price': 0.5,
      'change': 0.01,
      'market_cap': 1.2e12,
    }),
    AssistResult('financial', {
      'query_type': 'currency',
      'amount': 100,
      'from_currency': 'USD',
      'converted_amount': 92.1,
      'to_currency': 'EUR',
      'rate': 0.921,
    }),
    AssistResult('images', {
      'items': [
        {'image_url': 'http://x/1.jpg'},
        {'image_url': 'http://x/2.jpg', 'thumbnail_url': 'http://x/2s.jpg'},
        {'image_url': 'http://x/3.jpg'},
      ],
    }),
    AssistResult('featured', {'image_url': '/local/a.png'}),
    AssistResult('videos', {
      'items': [
        {
          'video_id': 'abc',
          'title': 'Cats',
          'channel': 'Cat TV',
          'duration': '3:12',
          'thumbnail_url': 'http://x/t.jpg',
        },
      ],
    }),
  ];

  // Every panel in every skin, light and dark, landscape and portrait:
  // a layout that throws leaves the result blank with only a log line.
  for (final skin in assistSkins) {
    testWidgets('${skin.name} panels lay out', (tester) async {
      for (final size in const [Size(1280, 800), Size(800, 1280)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        for (final dark in [false, true]) {
          for (final result in results) {
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: Center(
                    child: AssistResultPanel(
                      result: result,
                      skin: skin,
                      dark: dark,
                      scale: 1.5,
                      resolve: (u) => u,
                      onOpen: (_, _) {},
                    ),
                  ),
                ),
              ),
            );
            await tester.pump();
            expect(tester.takeException(), isNull, reason: result.kind);
          }
        }
      }
      tester.view.reset();
    });
  }

  test('the panel picks what Voice Satellite shows first', () {
    expect(primaryResult(results)!.kind, 'videos');
    expect(primaryResult(results.take(5).toList())!.kind, 'weather');
    expect(primaryResult(const []), isNull);
  });

  test('prices read as Voice Satellite formats them', () {
    expect(formatPrice(231.5, 'USD'), r'$231.50');
    expect(formatPrice(0.5, 'USD'), r'$0.500000');
    expect(formatChange(-1.25, -0.54, 'USD'), r'-$1.25 (-0.54%)');
    expect(formatLargeNumber(1.2e12, 'USD'), r'$1.20T');
  });
}
