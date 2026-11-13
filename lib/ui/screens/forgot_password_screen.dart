import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/auth_repository.dart';
import '../theme.dart';
import '../widgets/password_field.dart';

/// Forgot password, one thing at a time: the email to send a code to, the
/// code (checked before going on), then the new password twice. Setting it
/// signs the player straight in.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.email = ''});

  /// What was typed on the sign-in form, to start from.
  final String email;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

enum _Step { email, code, password }

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _email = TextEditingController(text: widget.email);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  _Step _step = _Step.email;
  String? _error;
  String? _note;

  @override
  void dispose() {
    for (final c in [_email, _code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    final error = await context.read<AuthRepository>().requestPasswordReset(_email.text);
    if (!mounted) return;
    setState(() {
      _error = error;
      if (error == null) {
        _step = _Step.code;
        _note =
            'If ${_email.text.trim()} has a BluJem account, a 6-digit code is on its way. '
            'It works for 15 minutes. Check spam if you cannot see it.';
      }
    });
  }

  Future<void> _checkCode() async {
    FocusScope.of(context).unfocus();
    final error = await context.read<AuthRepository>().checkResetCode(_email.text, _code.text);
    if (!mounted) return;
    setState(() {
      _error = error;
      if (error == null) {
        _step = _Step.password;
        _note = 'Choose a new password for ${_email.text.trim()}.';
      }
    });
  }

  void _startOver() => setState(() {
    _step = _Step.email;
    _note = null;
    _error = null;
    _code.clear();
    _password.clear();
    _confirm.clear();
  });

  Future<void> _reset() async {
    FocusScope.of(context).unfocus();
    final error = await context.read<AuthRepository>().resetPassword(
      email: _email.text,
      code: _code.text,
      password: _password.text,
      confirm: _confirm.text,
    );
    if (!mounted) return;
    if (error == null) {
      // Signed in: the app behind this screen is already the game.
      Navigator.of(context).pop();
      return;
    }
    setState(() => _error = error);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final busy = context.watch<AuthRepository>().busy;

    return Scaffold(
      appBar: AppBar(title: const Text('Forgot password')),
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
                    Text(switch (_step) {
                      _Step.email => 'Reset your password',
                      _Step.code => 'Enter the code',
                      _Step.password => 'Set a new password',
                    }, style: t.headlineSmall),
                    const SizedBox(height: 6),
                    Text(
                      _note ?? "Enter your account's email and we'll send you a code to set a new password.",
                      style: TextStyle(color: p.inkSoft, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    if (_step == _Step.email)
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                      ),
                    if (_step == _Step.code)
                      TextField(
                        controller: _code,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        maxLength: 6,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _checkCode(),
                        decoration: const InputDecoration(
                          labelText: '6-digit code',
                          prefixIcon: Icon(Icons.pin_outlined),
                          counterText: '',
                        ),
                      ),
                    if (_step == _Step.password) ...[
                      PasswordField(
                        controller: _password,
                        label: 'New password',
                        hints: const [AutofillHints.newPassword],
                      ),
                      const SizedBox(height: 12),
                      PasswordField(
                        controller: _confirm,
                        label: 'Confirm new password',
                        hints: const [AutofillHints.newPassword],
                        onDone: _reset,
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: p.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(_error!, style: TextStyle(color: p.warning)),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: busy
                          ? null
                          : switch (_step) {
                              _Step.email => _send,
                              _Step.code => _checkCode,
                              _Step.password => _reset,
                            },
                      child: busy
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                          : Text(switch (_step) {
                              _Step.email => 'Send code',
                              _Step.code => 'Continue',
                              _Step.password => 'Set new password',
                            }),
                    ),
                    if (_step != _Step.email) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: busy ? null : _startOver,
                        child: const Text('Use a different email or send a new code'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
