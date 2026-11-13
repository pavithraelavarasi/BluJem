import 'package:blujem/ui/theme.dart';
import 'package:blujem/ui/widgets/password_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the eye shows and hides the password', (tester) async {
    final controller = TextEditingController(text: 'secret1');
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: PasswordField(controller: controller, label: 'Password'),
        ),
      ),
    );
    bool hidden() => tester.widget<TextField>(find.byType(TextField)).obscureText;

    expect(hidden(), isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(hidden(), isFalse);
    await tester.tap(find.byTooltip('Hide password'));
    await tester.pump();
    expect(hidden(), isTrue);
  });
}
