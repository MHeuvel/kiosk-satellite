import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/managers/device/stats_history.dart';

void main() {
  test('keeps the newest samples up to capacity, oldest first', () {
    final h = StatsHistory(capacity: 3);
    for (var i = 1; i <= 5; i++) {
      h.add(cpu: i.toDouble(), memory: i * 10.0, temp: 30.0 + i);
    }
    final json = h.toJson();
    expect(json['cpu'], [3.0, 4.0, 5.0]);
    expect(json['memory'], [30.0, 40.0, 50.0]);
    expect(json['temp'], [33.0, 34.0, 35.0]);
    expect(json['capacity'], 3);
    expect(json['intervalSeconds'], 15);
    expect(h.length, 3);
  });

  test('a declined read keeps its slot so the columns stay aligned', () {
    final h = StatsHistory();
    h.add(cpu: 12.0, memory: 40.0, temp: null);
    h.add(cpu: null, memory: 41.0, temp: null);
    final json = h.toJson();
    expect(json['cpu'], [12.0, null]);
    expect(json['temp'], [null, null]);
    expect(h.hasData, isTrue);
  });

  test('a host that declines everything has no data to show', () {
    final h = StatsHistory();
    expect(h.hasData, isFalse);
    expect(h.toJson()['at'], isNull);
    h.add();
    expect(h.hasData, isFalse);
    expect(h.toJson()['at'], isNotNull);
  });

  test('the sample time is the caller\'s when given', () {
    final h = StatsHistory();
    final at = DateTime.fromMillisecondsSinceEpoch(1700000000000);
    h.add(cpu: 1, at: at);
    expect(h.lastSampleAt, at);
    expect(h.toJson()['at'], 1700000000000);
  });
}
