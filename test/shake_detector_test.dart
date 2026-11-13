import 'dart:async';

import 'package:blujem/ui/feedback.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() {
  test('one physical shake is one reshuffle; another after the cooldown counts again', () async {
    final readings = StreamController<AccelerometerEvent>();
    var now = DateTime(2026, 10, 29, 10);
    var shakes = 0;
    final detector = ShakeDetector(() => shakes++, events: readings.stream, clock: () => now)..start();

    AccelerometerEvent g(double force) => AccelerometerEvent(0, 0, force * 9.80665, now);
    Future<void> reading(double force, {int afterMs = 0}) async {
      now = now.add(Duration(milliseconds: afterMs));
      readings.add(g(force));
      await Future<void>.delayed(Duration.zero);
    }

    await reading(1); // resting: nothing
    expect(shakes, 0);
    // One hard shake: several readings over 2.4 g within half a second.
    for (var i = 0; i < 8; i++) {
      await reading(3.2, afterMs: 60);
    }
    expect(shakes, 1);
    await reading(3.5, afterMs: 700); // still inside the 1.2 s cooldown
    expect(shakes, 1);
    await reading(3.5, afterMs: 800); // a fresh shake, well after
    expect(shakes, 2);

    detector.stop();
    await readings.close();
  });
}
