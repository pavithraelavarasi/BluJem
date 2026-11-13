import 'dart:convert';
import 'dart:io';

import 'package:blujem/data/api_client.dart';
import 'package:blujem/data/auth_repository.dart';
import 'package:blujem/data/local_store.dart';
import 'package:blujem/data/social_sign_in.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late List<(String, Map<String, dynamic>)> calls;
  late AuthRepository auth;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    calls = [];
    final api = ApiClient(
      http: MockClient((request) async {
        final route = request.url.pathSegments.last;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        calls.add((route, body));
        return switch (route) {
          'forgot-password' => http.Response(jsonEncode({'status': 'sent'}), 200),
          'check-reset-code' when body['code'] == '123456' => http.Response(jsonEncode({'status': 'ok'}), 200),
          'check-reset-code' => http.Response(
            jsonEncode({'error': 'That code is not right. Check the email and try again.'}),
            400,
          ),
          'reset-password' when body['code'] == '123456' => http.Response(
            jsonEncode({
              'user': {'id': '1', 'email': body['email'], 'name': 'Ann', 'username': 'Ann1', 'role': 'player'},
              'token': 'session',
            }),
            200,
          ),
          'reset-password' => http.Response(
            jsonEncode({'error': 'That code is not right. Check the email and try again.'}),
            400,
          ),
          _ => http.Response('{}', 404),
        };
      }),
    );
    auth = AuthRepository(
      api,
      await LocalStore.forTest(Directory.systemTemp.createTempSync('auth')),
      const NoSocialSignIn(),
    );
  });

  test('asking for a code sends the email to forgot-password', () async {
    expect(await auth.requestPasswordReset('not-an-email'), isNotNull);
    expect(calls, isEmpty, reason: 'a mistyped email never leaves the phone');
    expect(await auth.requestPasswordReset(' ann@b.co '), isNull);
    expect(calls.single.$1, 'forgot-password');
    expect(calls.single.$2, {'email': 'ann@b.co'});
  });

  test('the right code and a new password sign straight in', () async {
    expect(
      await auth.resetPassword(email: 'ann@b.co', code: '12 34 56', password: 'secret1', confirm: 'secret1'),
      isNull,
    );
    expect(calls.single.$2, {'email': 'ann@b.co', 'code': '123456', 'password': 'secret1'});
    expect(auth.signedIn, isTrue);
    expect(auth.account!.email, 'ann@b.co');
  });

  test('mistakes are caught before the server, and a wrong code says so', () async {
    expect(
      await auth.resetPassword(email: 'ann@b.co', code: '123', password: 'secret1', confirm: 'secret1'),
      contains('6-digit'),
    );
    expect(
      await auth.resetPassword(email: 'ann@b.co', code: '123456', password: 'abc', confirm: 'abc'),
      contains('six'),
    );
    expect(
      await auth.resetPassword(email: 'ann@b.co', code: '123456', password: 'secret1', confirm: 'secret2'),
      contains('match'),
    );
    expect(calls, isEmpty);
    expect(
      await auth.resetPassword(email: 'ann@b.co', code: '654321', password: 'secret1', confirm: 'secret1'),
      contains('not right'),
    );
    expect(auth.signedIn, isFalse);
  });

  test('the code is checked on its own before the new password is asked for', () async {
    expect(await auth.checkResetCode('ann@b.co', '12'), contains('6-digit'));
    expect(calls, isEmpty);
    expect(await auth.checkResetCode('ann@b.co', '654321'), contains('not right'));
    expect(await auth.checkResetCode('ann@b.co', '123 456'), isNull);
    expect(calls.last.$1, 'check-reset-code');
    expect(calls.last.$2, {'email': 'ann@b.co', 'code': '123456'});
    expect(auth.signedIn, isFalse, reason: 'checking the code does not sign in');
  });
}
