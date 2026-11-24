import 'dart:convert';
import 'dart:io';

import 'package:blujem/data/api_client.dart';
import 'package:blujem/data/app_refresh.dart';
import 'package:flutter/widgets.dart';
import 'package:blujem/data/local_store.dart';
import 'package:blujem/data/puzzle_library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('coming back to the app checks for newly opened puzzles', () async {
    SharedPreferences.setMockInitialValues({});
    final routes = <String>[];
    final api = ApiClient(
      http: MockClient((request) async {
        routes.add(request.url.pathSegments.last);
        return http.Response(jsonEncode({'puzzles': []}), 200);
      }),
    );
    final library = PuzzleLibrary(api, await LocalStore.forTest(Directory.systemTemp.createTempSync('resume')));
    var rebuilt = 0;
    library.addListener(() => rebuilt++);

    library.onResumed();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(routes, ['list'], reason: 'one puzzles/list call on resume');
    expect(rebuilt, greaterThan(0), reason: 'the screen redraws with the current time');
    library.dispose();
  });

  testWidgets('the whole app refreshes on coming back, not twice in a row, not in the background', (tester) async {
    var now = DateTime(2026, 11, 24, 15);
    var refreshes = 0;
    var heard = 0;
    final refresh = AppRefresh(() => refreshes++, clock: () => now, every: const Duration(minutes: 5))
      ..addListener(() => heard++)
      ..start();

    refresh.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(refreshes, 1);
    expect(heard, 1, reason: 'listening screens (the leaderboard) reload too');

    // A share sheet closing a few seconds later does not refresh again.
    now = now.add(const Duration(seconds: 5));
    refresh.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(refreshes, 1);

    // Back after a while: refreshes again.
    refresh.didChangeAppLifecycleState(AppLifecycleState.paused);
    now = now.add(const Duration(hours: 6));
    await tester.pump(const Duration(minutes: 10));
    expect(refreshes, 1, reason: 'nothing runs while in the background');
    refresh.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(refreshes, 2);

    // Staying open: refreshes every five minutes.
    now = now.add(const Duration(minutes: 5));
    await tester.pump(const Duration(minutes: 5));
    expect(refreshes, 3);
    refresh.dispose();
  });
}
