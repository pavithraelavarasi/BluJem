import 'dart:io';

import 'package:blujem/data/api_client.dart';
import 'package:blujem/data/auth_repository.dart';
import 'package:blujem/data/local_store.dart';
import 'package:blujem/data/social_sign_in.dart';
import 'package:blujem/ui/screens/auth_screen.dart';
import 'package:blujem/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('a bad leaderboard name is flagged on its own field, not near the password', (tester) async {
    SharedPreferences.setMockInitialValues({});
    var calls = 0;
    final api = ApiClient(
      http: MockClient((_) async {
        calls++;
        return http.Response('{}', 404);
      }),
    );
    final store = await tester.runAsync(() => LocalStore.forTest(Directory.systemTemp.createTempSync('auth')));
    final auth = AuthRepository(api, store!, const NoSocialSignIn());
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: MaterialApp(theme: buildTheme(Brightness.light), home: const AuthScreen()),
      ),
    );

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Ann');
    await tester.enterText(fields.at(1), 'Ann S');
    await tester.enterText(fields.at(2), 'ann@b.co');
    await tester.enterText(fields.at(3), 'secret1');
    await tester.enterText(fields.at(4), 'secret1');
    final create = find.widgetWithText(FilledButton, 'Create account');
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();

    final nameField = tester.widget<TextField>(fields.at(1));
    expect(nameField.decoration?.errorText, contains('No spaces'));
    expect(find.text('Check your leaderboard name above.'), findsOneWidget);
    expect(calls, 0, reason: 'a bad name never leaves the phone');

    // Fixing the name clears the warning.
    await tester.enterText(fields.at(1), 'Ann_S');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(fields.at(1)).decoration?.errorText, isNull);
    expect(find.text('Check your leaderboard name above.'), findsNothing);
  });
}
