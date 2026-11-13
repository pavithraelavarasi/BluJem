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

/// A saved session the server no longer accepts (one from the old DailyJumble
/// project) signs the player out, so they sign in again and get a BluJem one.
void main() {
  const saved = {
    'id': '58106000000151058',
    'email': 'ann@b.co',
    'name': 'Ann',
    'username': 'Ann1',
    'role': 'player',
    'token': 'old',
  };

  Future<AuthRepository> signedIn(http.Response Function(http.Request) reply) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.forTest(Directory.systemTemp.createTempSync('session'));
    await store.writeJson('account', saved);
    return AuthRepository(ApiClient(http: MockClient((r) async => reply(r))), store, const NoSocialSignIn());
  }

  test('a refused session is signed out at launch', () async {
    final auth = await signedIn((_) => http.Response(jsonEncode({'error': 'Sign in again.'}), 401));
    expect(auth.signedIn, isTrue);
    await auth.start();
    expect(auth.signedIn, isFalse);
  });

  test('no connection keeps the saved session', () async {
    final auth = await signedIn((_) => throw const SocketException('offline'));
    await auth.start();
    expect(auth.signedIn, isTrue);
  });

  test('a server error other than 401 keeps the saved session', () async {
    final auth = await signedIn((_) => http.Response('{}', 500));
    await auth.start();
    expect(auth.signedIn, isTrue);
  });

  test('a wrong password while signed out does not count as a refused session', () async {
    SharedPreferences.setMockInitialValues({});
    var rejected = 0;
    final api = ApiClient(
      http: MockClient((_) async => http.Response(jsonEncode({'error': 'Email or password is incorrect.'}), 401)),
    )..onSessionRejected = () => rejected++;
    await expectLater(api.post(JumbleFunction.auth, 'login'), throwsA(isA<ApiException>()));
    expect(rejected, 0);
  });
}
