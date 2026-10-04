import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/managers/settings/definitions.dart' as defs;
import 'package:kiosk_satellite/ui/clock_faces.dart';
import 'package:kiosk_satellite/ui/digital_clock_face.dart';
import 'package:kiosk_satellite/ui/screensaver_view.dart';
import 'package:kiosk_satellite/ui/weather_mood_information.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Vertical mode (issue #767) stacks the hours above the minutes so a
/// portrait panel can draw them as large as its height allows. The
/// digital and flip faces of the Clock screensaver take it, and the
/// Weather Mood clock has a switch of its own.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppContainer> container(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues({
      'ks.ha.url': 'http://ha.local:8123',
      'ks.ha.token': 'token',
      ...prefs,
    });
    final c = AppContainer();
    await c.settings.init();
    return c;
  }

  Widget face(String time, {required bool vertical}) => MaterialApp(
    home: Center(
      child: DigitalClockFace(
        time: time,
        date: null,
        color: Colors.white,
        clockSize: 100,
        dateSize: 20,
        fontFamily: null,
        weight: FontWeight.w300,
        vertical: vertical,
      ),
    ),
  );

  // The change event reaches the face through the bus, a hop after the
  // write returns, so the frame that shows it is the second one.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  Finder stacked() => find.byWidgetPredicate(
    (w) => w is Text && (w.data?.contains('\n') ?? false),
  );

  testWidgets('the digital face puts each part on a line of its own', (
    tester,
  ) async {
    await tester.pumpWidget(face('7:05 PM', vertical: false));
    expect(find.text('7:05 PM'), findsOneWidget);

    await tester.pumpWidget(face('7:05 PM', vertical: true));
    // The hour takes two digits, like the minutes under it.
    expect(find.text('07\n05'), findsOneWidget);
    // AM or PM drops under the digits at the date's size.
    final meridiem = tester.widget<Text>(find.text('PM'));
    expect(meridiem.style!.fontSize, 20);

    await tester.pumpWidget(face('19:05:42', vertical: true));
    expect(find.text('19\n05\n42'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  test('a stacked face sizes its digits from the height on portrait', () {
    const portrait = Size(800, 1280);
    final flat = DigitalClockFace.sizeFor(portrait);
    final stacked = DigitalClockFace.sizeFor(portrait, vertical: true);
    expect(stacked, greaterThan(flat * 2));
    // A third line for seconds shares the same height.
    expect(
      DigitalClockFace.sizeFor(portrait, vertical: true, lines: 3),
      lessThan(stacked),
    );
    // The date follows the stacked digits, so it grows with them too.
    expect(
      DigitalClockFace.dateSizeFor(portrait, vertical: true),
      greaterThan(DigitalClockFace.dateSizeFor(portrait)),
    );
  });

  test('the switch shows for the digital and flip styles only', () async {
    final c = await container({'ks.screensaver.mode': 'clock'});
    for (final (style, shown) in [
      ('digital', true),
      ('flip', true),
      ('roller', false),
    ]) {
      await c.settings.set(defs.screensaverClockStyle, style);
      expect(
        c.settings.visible(defs.screensaverClockVertical),
        shown,
        reason: style,
      );
    }
  });

  testWidgets('the Clock screensaver stacks live on a write', (tester) async {
    final c = await container({
      'ks.screensaver.mode': 'clock',
      'ks.screensaver.clock_show_date': false,
    });
    await tester.pumpWidget(MaterialApp(home: ClockScreensaver(container: c)));
    expect(stacked(), findsNothing);
    await c.settings.set(defs.screensaverClockVertical, true);
    await settle(tester);
    expect(stacked(), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the flip cards stack, and the roller ignores the switch', (
    tester,
  ) async {
    var c = await container({
      'ks.screensaver.mode': 'clock',
      'ks.screensaver.clock_style': 'flip',
      'ks.screensaver.clock_vertical': true,
    });
    await tester.pumpWidget(MaterialApp(home: ClockScreensaver(container: c)));
    final cards = tester.widget<Flex>(
      find
          .descendant(
            of: find.byType(FlipClockFace),
            matching: find.byType(Flex),
          )
          .first,
    );
    expect(cards.direction, Axis.vertical);
    // In 12-hour time too, the hours card shows two digits.
    final hour = DateTime.now().hour % 12 == 0 ? 12 : DateTime.now().hour % 12;
    expect(find.text(hour.toString().padLeft(2, '0')), findsWidgets);
    await tester.pumpWidget(const SizedBox());

    c = await container({
      'ks.screensaver.mode': 'clock',
      'ks.screensaver.clock_style': 'roller',
      'ks.screensaver.clock_vertical': true,
    });
    await tester.pumpWidget(MaterialApp(home: ClockScreensaver(container: c)));
    expect(find.byType(RollerClockFace), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the Weather Mood clock stacks with its own switch', (
    tester,
  ) async {
    final c = await container({
      'ks.screensaver.mode': 'weather_mood',
      'ks.screensaver.weather_clock_show_date': false,
      'ks.screensaver.weather_clock_shadow': false,
      'ks.screensaver.weather_bar': false,
    });
    final readings = WeatherMoodReadings()..update({'state': 'sunny'});
    Future<void> show() async {
      await tester.pumpWidget(
        MaterialApp(
          home: WeatherMoodInformation(container: c, readings: readings),
        ),
      );
      await tester.pump();
    }

    await show();
    expect(stacked(), findsNothing);
    // The Clock screensaver's switch is not this one.
    await c.settings.set(defs.screensaverClockVertical, true);
    await show();
    expect(stacked(), findsNothing);
    await c.settings.set(defs.screensaverWeatherClockVertical, true);
    await show();
    expect(stacked(), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
