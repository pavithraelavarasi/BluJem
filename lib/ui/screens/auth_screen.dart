import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/auth_repository.dart';
import '../theme.dart';
import '../widgets/password_field.dart';
import 'forgot_password_screen.dart';

/// The way in: create an account or sign in. Nobody plays anonymously, so
/// there is nowhere else to go until one of these succeeds.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _signUp = true;
  String? _error;

  /// What is wrong with the leaderboard name, shown under that field itself,
  /// so the message never looks like it is about the password.
  String? _usernameError;
  final _usernameFocus = FocusNode();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _username, _email, _password, _confirm]) {
      c.dispose();
    }
    _usernameFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthRepository>();
    FocusScope.of(context).unfocus();
    if (_signUp && _username.text.trim().isNotEmpty) {
      final problem = AuthRepository.usernameProblem(_username.text);
      if (problem != null) return _showUsernameError(problem);
    }
    final error = _signUp
        ? await auth.signUp(
            name: _name.text,
            username: _username.text,
            email: _email.text,
            password: _password.text,
            confirm: _confirm.text,
          )
        : await auth.signIn(_email.text, _password.text);
    if (!mounted) return;
    if (_signUp && error != null && error.toLowerCase().contains('username')) {
      return _showUsernameError(error.replaceAll('username', 'leaderboard name'));
    }
    setState(() => _error = error);
  }

  /// Marks the leaderboard name field and brings it into view.
  void _showUsernameError(String problem) {
    setState(() {
      _usernameError = problem;
      _error = 'Check your leaderboard name above.';
    });
    _usernameFocus.requestFocus();
  }

  void _switchTo({required bool signUp}) => setState(() {
    _signUp = signUp;
    _error = null;
    _usernameError = null;
  });

  Future<void> _catalyst() async {
    final error = await context.read<AuthRepository>().signInWithCatalyst();
    if (mounted) setState(() => _error = error);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final auth = context.watch<AuthRepository>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Logo(),
                    const SizedBox(height: 16),
                    // Both ways in, side by side at the top, so signing in never
                    // means scrolling past the whole sign-up form to find it.
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Sign in')),
                        ButtonSegment(value: true, label: Text('Create account')),
                      ],
                      selected: {_signUp},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) => _switchTo(signUp: s.first),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _signUp ? 'Create your account' : 'Welcome back',
                      textAlign: TextAlign.center,
                      style: t.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'A new BluJem puzzle every day. Keep your streak and climb the leaderboard.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.inkSoft, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    if (_signUp) ...[
                      _field(_name, 'Name', Icons.person_outline_rounded, hints: const [AutofillHints.name]),
                      _field(
                        _username,
                        'Leaderboard name (optional)',
                        Icons.alternate_email_rounded,
                        helper: '3–16 letters, numbers or _ (no spaces). Shown on the leaderboard.',
                        error: _usernameError,
                        focus: _usernameFocus,
                      ),
                    ],
                    _field(
                      _email,
                      'Email',
                      Icons.mail_outline_rounded,
                      keyboard: TextInputType.emailAddress,
                      hints: const [AutofillHints.email],
                    ),
                    _field(
                      _password,
                      'Password',
                      Icons.lock_outline_rounded,
                      obscure: true,
                      hints: [_signUp ? AutofillHints.newPassword : AutofillHints.password],
                      onDone: _signUp ? null : _submit,
                    ),
                    if (_signUp)
                      _field(
                        _confirm,
                        'Confirm password',
                        Icons.lock_outline_rounded,
                        obscure: true,
                        hints: const [AutofillHints.newPassword],
                        onDone: _submit,
                      ),
                    if (!_signUp)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: auth.busy
                              ? null
                              : () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => ForgotPasswordScreen(email: _email.text.trim())),
                                ),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _error == null
                          ? const SizedBox.shrink()
                          : Container(
                              key: ValueKey(_error),
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: p.warning.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(_error!, style: TextStyle(color: p.warning)),
                            ),
                    ),
                    FilledButton(
                      onPressed: auth.busy ? null : _submit,
                      child: auth.busy
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                          : Text(_signUp ? 'Create account' : 'Sign in'),
                    ),
                    if (auth.socialAvailable) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('or', style: TextStyle(color: p.inkFaint)),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: auth.busy ? null : _catalyst,
                        icon: const Icon(Icons.account_circle_outlined),
                        label: const Text('Continue with Zoho or Google'),
                      ),
                    ],
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () => _switchTo(signUp: !_signUp),
                      child: Text(_signUp ? 'Already have an account? Sign in' : 'New here? Create an account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscure = false,
    TextInputType? keyboard,
    List<String>? hints,
    String? helper,
    String? error,
    FocusNode? focus,
    VoidCallback? onDone,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: obscure
        ? PasswordField(
            controller: controller,
            label: label,
            hints: hints,
            onDone: onDone,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          )
        : TextField(
            controller: controller,
            focusNode: focus,
            keyboardType: keyboard,
            autofillHints: hints,
            autocorrect: false,
            textInputAction: onDone == null ? TextInputAction.next : TextInputAction.done,
            onSubmitted: onDone == null ? null : (_) => onDone(),
            onChanged: (_) {
              if (_error != null || (error != null && _usernameError != null)) {
                setState(() {
                  _error = null;
                  if (error != null) _usernameError = null;
                });
              }
            },
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(icon),
              helperText: helper,
              helperMaxLines: 2,
              errorText: error,
              errorMaxLines: 2,
            ),
          ),
  );
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => Center(
    child: Image.asset(
      'assets/images/blujem_logo.png',
      width: (MediaQuery.sizeOf(context).width * 0.6).clamp(200.0, 300.0),
      semanticLabel: 'BluJem',
    ),
  );
}
