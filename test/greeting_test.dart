import 'package:blujem/ui/screens/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// Home greets by the phone's time of day.
void main() {
  String at(int hour, [int minute = 0]) => HomeScreen.greeting(DateTime(2026, 11, 14, hour, minute));

  test('morning until noon', () {
    expect(at(0), 'Good Morning');
    expect(at(11, 59), 'Good Morning');
  });

  test('afternoon from noon until 5 PM', () {
    expect(at(12), 'Good Afternoon');
    expect(at(16, 59), 'Good Afternoon');
  });

  test('evening from 5 PM', () {
    expect(at(17), 'Good Evening');
    expect(at(23, 59), 'Good Evening');
  });
}
