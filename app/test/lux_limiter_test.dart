import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/managers/btproxy/lux_limiter.dart';

/// The Ambient light limiter (issue #521): a real transition passes
/// untouched, a driver flapping between two values collapses to one row
/// per refill, the held publish carries the latest reading and a quiet
/// spell refills the burst.
void main() {
  late DateTime now;
  late List<int> published;
  late LuxLimiter limiter;

  void tick(FakeAsync async, Duration d) {
    now = now.add(d);
    async.elapse(d);
  }

  void start() {
    now = DateTime.utc(2026, 9, 13, 5, 38);
    published = [];
    limiter = LuxLimiter(published.add, now: () => now);
  }

  test('a transition lands at once: the leading reading and the settled '
      'value 2 seconds later both pass', () {
    fakeAsync((async) {
      start();
      limiter.offer(120);
      tick(async, const Duration(minutes: 5));
      limiter.offer(43); // lights go out
      tick(async, const Duration(seconds: 2));
      limiter.offer(2); // the damper's trailing edge
      expect(published, [120, 43, 2]);
      tick(async, const Duration(minutes: 10));
      expect(published, [120, 43, 2]);
    });
  });

  test('a driver flapping between two values collapses to one publish per '
      'refill and the held publish carries the latest reading', () {
    fakeAsync((async) {
      start();
      // 10 and 160 every 2 seconds for 5 minutes: 150 offers.
      for (var i = 0; i < 150; i++) {
        limiter.offer(i.isEven ? 10 : 160);
        tick(async, const Duration(seconds: 2));
      }
      // The burst of four, then one every 30 seconds for the remaining
      // ~4.9 minutes: a handful, not 150.
      expect(published.length, lessThanOrEqualTo(4 + 10));
      expect(published.length, greaterThanOrEqualTo(4 + 9));
      // Every publish is one of the two readings, never something else.
      expect(published.toSet().difference({10, 160}), isEmpty);
      // The flapping stops on 160: the entity settles there.
      limiter.offer(160);
      tick(async, const Duration(minutes: 1));
      expect(published.last, 160);
      expect(limiter.published, 160);
    });
  });

  test('a reading equal to the one on the wire drops what was held', () {
    fakeAsync((async) {
      start();
      for (final lux in [10, 160, 10, 160]) {
        limiter.offer(lux); // the burst
      }
      expect(published, [10, 160, 10, 160]);
      limiter.offer(10); // held
      limiter.offer(160); // back to the wire's value: nothing to say
      tick(async, const Duration(minutes: 2));
      expect(published, [10, 160, 10, 160]);
    });
  });

  test('a quiet spell refills the burst', () {
    fakeAsync((async) {
      start();
      for (final lux in [10, 160, 10, 160]) {
        limiter.offer(lux);
      }
      tick(async, const Duration(minutes: 2)); // four tokens back
      var i = 0;
      for (final lux in [20, 30, 40, 50]) {
        limiter.offer(lux);
        i++;
        expect(published.length, 4 + i);
      }
      limiter.offer(60); // the bucket is empty again
      expect(published.length, 8);
      tick(async, const Duration(seconds: 30));
      expect(published.last, 60);
    });
  });

  test('reset forgets the wire and refills the bucket', () {
    fakeAsync((async) {
      start();
      for (final lux in [10, 160, 10, 160]) {
        limiter.offer(lux);
      }
      limiter.offer(10); // held
      limiter.reset();
      tick(async, const Duration(minutes: 1));
      expect(published, [10, 160, 10, 160]);
      limiter.offer(160); // the registration seed, same as the last wire value
      expect(published.last, 160);
      expect(published.length, 5);
    });
  });
}
