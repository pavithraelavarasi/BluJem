import 'package:flutter/foundation.dart';

import '../models/records.dart';
import 'api_client.dart';
import 'local_store.dart';
import 'social_sign_in.dart';

/// Who is signed in, and every way of becoming so.
///
/// All of it goes through the jumble_auth function, which checks passwords
/// with admin scope; this only remembers the answer. A Zoho or Google sign-in
/// gives a Catalyst session, which is traded straight away for the same kind
/// of BluJem session a password gives — so nothing downstream can tell them
/// apart. Only a BluJem account ever lets a player in.
class AuthRepository extends ChangeNotifier {
  AuthRepository(this._api, this._store, this._social) {
    _account = Account.tryParse(_store.readJson(_key));
    _api.token = () => _account?.token;
    _api.onSessionRejected = () {
      if (signedIn) signOut();
    };
  }

  static const _key = 'account';
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _username = RegExp(r'^[A-Za-z0-9_]{3,16}$');

  final ApiClient _api;
  final LocalStore _store;
  final SocialSignIn _social;

  Account? _account;
  Account? get account => _account;
  bool get signedIn => _account != null;

  bool _busy = false;
  bool get busy => _busy;

  /// Whether Zoho / Google sign-in can be offered on this platform.
  bool get socialAvailable => _social.available;

  /// Clears a half-finished social sign-in left from a previous launch, and
  /// checks a saved session with the server (a refused one signs out).
  Future<void> start() async {
    if (!signedIn) await _social.signOut();
    if (signedIn) await refreshProfile();
  }

  // ------------------------------------------------------------- sign in

  /// Null on success, otherwise what to tell the player.
  Future<String?> signIn(String email, String password) async {
    final problem = _emailProblem(email) ?? (password.isEmpty ? 'Enter your password.' : null);
    if (problem != null) return problem;
    return _run(() => _api.post(JumbleFunction.auth, 'login', body: {'email': email.trim(), 'password': password}));
  }

  Future<String?> signUp({
    required String name,
    required String username,
    required String email,
    required String password,
    required String confirm,
  }) async {
    String? problem;
    if (name.trim().isEmpty) {
      problem = 'Enter your name.';
    } else if (username.trim().isNotEmpty) {
      problem = usernameProblem(username);
    }
    problem ??= _emailProblem(email);
    if (problem == null && password.length < 6) problem = 'Use at least six characters for the password.';
    if (problem == null && password != confirm) problem = 'The two passwords do not match.';
    if (problem != null) return problem;
    return _run(
      () => _api.post(
        JumbleFunction.auth,
        'signup',
        body: {'name': name.trim(), 'username': username.trim(), 'email': email.trim(), 'password': password},
      ),
    );
  }

  // ------------------------------------------------------- forgot password

  /// Emails a 6-digit code for setting a new password. Null when asked for —
  /// the server answers the same whether or not the email has an account.
  Future<String?> requestPasswordReset(String email) async {
    final problem = _emailProblem(email);
    if (problem != null) return problem;
    _setBusy(true);
    try {
      await _api.post(JumbleFunction.auth, 'forgot-password', body: {'email': email.trim()});
      return null;
    } on ApiException catch (e) {
      // A server without the reset steps answers 404 with a list of routes;
      // the player only needs to know it did not go.
      return e.status == 404 ? "Couldn't send the code. Try again later." : e.message;
    } catch (_) {
      return 'Something went wrong. Try again.';
    } finally {
      _setBusy(false);
    }
  }

  /// Checks the emailed code before asking for the new password. Null when right.
  Future<String?> checkResetCode(String email, String code) async {
    final digits = code.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 6) return 'Enter the 6-digit code from the email.';
    _setBusy(true);
    try {
      await _api.post(JumbleFunction.auth, 'check-reset-code', body: {'email': email.trim(), 'code': digits});
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Something went wrong. Try again.';
    } finally {
      _setBusy(false);
    }
  }

  /// Sets the new password with the emailed code, and signs straight in.
  Future<String?> resetPassword({
    required String email,
    required String code,
    required String password,
    required String confirm,
  }) async {
    String? problem = _emailProblem(email);
    final digits = code.replaceAll(RegExp(r'\D'), '');
    if (problem == null && digits.length != 6) problem = 'Enter the 6-digit code from the email.';
    if (problem == null && password.length < 6) problem = 'Use at least six characters for the password.';
    if (problem == null && password != confirm) problem = 'The two passwords do not match.';
    if (problem != null) return problem;
    return _run(
      () => _api.post(
        JumbleFunction.auth,
        'reset-password',
        body: {'email': email.trim(), 'code': digits, 'password': password},
      ),
    );
  }

  /// Zoho or Google through Catalyst, then traded for a BluJem session.
  Future<String?> signInWithCatalyst() async {
    _setBusy(true);
    final String token;
    try {
      final result = await _social.signIn();
      if (result == null) {
        _setBusy(false);
        return null; // Cancelled: back to the form, no message needed.
      }
      token = result;
    } catch (e) {
      // Never leave a Catalyst session behind without an account for it.
      await _social.signOut();
      _setBusy(false);
      return 'Zoho / Google sign-in failed. ${e is ApiException ? e.message : 'Try again.'}';
    }
    final error = await _run(() => _api.post(JumbleFunction.auth, 'zoho', authorization: 'Zoho-oauthtoken $token'));
    if (error != null) await _social.signOut();
    return error;
  }

  Future<void> signOut() async {
    _account = null;
    await _store.writeJson(_key, null);
    await _social.signOut();
    notifyListeners();
  }

  // ------------------------------------------------------------- profile

  /// Re-reads the profile; gives an older session the username it lacks.
  Future<void> refreshProfile() async {
    if (!signedIn) return;
    final reply = await _api.tryPost(JumbleFunction.auth, 'me');
    if (reply != null) await _accept(reply);
  }

  /// Null when saved, otherwise why not.
  Future<String?> changeUsername(String wanted) async {
    final value = wanted.trim();
    final problem = usernameProblem(value);
    if (problem != null) return problem;
    if (value == _account?.username) return null;
    return _run(() => _api.post(JumbleFunction.auth, 'username', body: {'username': value}));
  }

  /// The same rule the server applies, so most mistakes never leave the phone.
  static String? usernameProblem(String value) =>
      _username.hasMatch(value.trim()) ? null : 'Use 3 to 16 letters, numbers or _ only. No spaces, dots or dashes.';

  // ------------------------------------------------------------- internals

  static String? _emailProblem(String email) {
    if (email.trim().isEmpty) return 'Enter your email.';
    if (!_email.hasMatch(email.trim())) return 'That does not look like an email address.';
    return null;
  }

  Future<String?> _run(Future<Map<String, dynamic>> Function() call) async {
    _setBusy(true);
    try {
      await _accept(await call());
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Something went wrong. Try again.';
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _accept(Map<String, dynamic> reply) async {
    final user = reply['user'];
    final token = reply['token'];
    if (user is! Map || token is! String || token.isEmpty) {
      throw const ApiException('The server did not issue a session.');
    }
    _account = Account.fromJson(Map<String, dynamic>.from(user), token);
    await _store.writeJson(_key, _account!.toJson());
    notifyListeners();
  }

  void _setBusy(bool value) {
    if (_busy == value) return;
    _busy = value;
    notifyListeners();
  }
}
