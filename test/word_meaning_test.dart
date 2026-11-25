import 'package:blujem/data/api_client.dart';
import 'package:blujem/data/hint_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final api = ApiClient(http: MockClient((_) async => http.Response('{}', 500)));
  final hints = HintService(api, () => false, loadGlossary: () async => 'WIFE\ta married woman\nAJAR\tslightly open\n');

  test("a solved word's meaning comes from the bundled glossary, capitalised", () async {
    expect(await hints.meaningOf('WIFE'), 'A married woman');
    expect(await hints.meaningOf('ajar'), 'Slightly open');
  });

  test('a word the glossary lacks has no meaning, not an error', () async {
    expect(await hints.meaningOf('BLUJEM'), isNull);
  });

  test("the real glossary has today's words", () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final real = HintService(api, () => false);
    for (final w in ['WIFE', 'GAUDY', 'SORROW', 'SOMEONE']) {
      expect(await real.meaningOf(w), isNotNull, reason: w);
    }
  });
}
