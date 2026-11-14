import 'dart:io';

import 'package:blujem/data/api_client.dart';
import 'package:blujem/data/local_store.dart';
import 'package:blujem/data/records_repository.dart';
import 'package:blujem/models/records.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// When the server's scores are reset, phones drop the runs they kept.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStore store;
  late http.Response reply;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await LocalStore.forTest(Directory.systemTemp.createTempSync('blujem'));
  });

  RecordsRepository repo() => RecordsRepository(ApiClient(http: MockClient((_) async => reply)), store);

  Future<RecordsRepository> withOldRun() async {
    reply = http.Response('{}', 500);
    final records = repo();
    await records.switchAccount('player');
    await records.record(
      const Completion(
        puzzleId: 'old',
        sheetDate: '2026-11-01',
        finalAnswer: 'OLD',
        seconds: 90,
        hintsUsed: 0,
        completedAt: 1,
      ),
    );
    return records;
  }

  test('an empty list from the server clears the runs kept on the phone', () async {
    await withOldRun();
    reply = http.Response('{"completions": []}', 200);
    final records = repo();
    await records.switchAccount('player');
    expect(records.runs, isEmpty);
  });

  test('a failed call keeps them', () async {
    await withOldRun();
    reply = http.Response('{}', 500);
    final records = repo();
    await records.switchAccount('player');
    expect(records.runs.map((r) => r.puzzleId), ['old']);
  });
}
