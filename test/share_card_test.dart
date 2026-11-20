import 'dart:io';
import 'dart:ui' as ui;

import 'package:blujem/models/box_rect.dart';
import 'package:blujem/models/records.dart';
import 'package:blujem/ui/share_card.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> _decode(List<int> bytes) async {
  final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
  return (await codec.getNextFrame()).image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the card says the time big, then the points', () {
    WinCard card({int? seconds, int? points}) => WinCard(
      logo: _none,
      sheet: _none,
      cartoon: const BoxRect(0, 0, 1, 1),
      answer: 'HOLES STORY',
      title: "Today's BluJem",
      heading: 'Morning',
      seconds: seconds,
      points: points,
    );
    expect(card(seconds: 102).timeLine, 'Solved in 1:42');
    expect(card().timeLine, 'Solved!');
    expect(card(points: 120).detailLine, '+120 points');
    expect(card(points: 0).detailLine, '');
  });

  test('the message invites friends to match the time', () {
    expect(winMessage(today: true, seconds: 84), "I solved today's BluJem in 1:24. Can you match my time?!");
    expect(winMessage(today: false, seconds: 725), 'I solved a BluJem in 12:05. Can you match my time?!');
    expect(winMessage(today: true), "I solved today's BluJem. Can you solve it too?!");
    expect(winMessage(today: true, seconds: 84).toLowerCase(), isNot(contains('jumble')));
  });

  test('the QR code and the shared message point at the download page', () {
    expect(appDownloadPage, endsWith('/server/blujem_daily/execute/download'));
    expect(appDownloadUrl, 'https://tinyurl.com/blujem');
    expect(appDownloadUrl, endsWith(appDownloadLink));
  });

  testWidgets('the card draws to a PNG 1080 wide', (tester) async {
    final font = FontLoader('Fredoka')..addFont(rootBundle.load('assets/fonts/Fredoka.ttf'));
    await font.load();
    await tester.runAsync(() async {
      final card = WinCard(
        logo: await _decode(File('assets/images/blujem_logo.png').readAsBytesSync()),
        sheet: await _decode(File('assets/bundled/sheet_jul18.png').readAsBytesSync()),
        cartoon: const BoxRect(0.495, 0.103, 0.465, 0.704),
        answer: '"HOLES" STORY',
        title: "Today's BluJem",
        heading: 'Morning · Mon, Nov 9',
        captionTop: 0.85,
        seconds: 102,
        points: 120,
      );
      final png = await renderWinCard(card);
      final image = await _decode(png);
      expect(image.width, 1080);
      expect(image.height, lessThanOrEqualTo(winCardMaxHeight));
      // SHARE_CARD_OUT=/path/card.png flutter test … saves it to look at.
      final out = Platform.environment['SHARE_CARD_OUT'];
      if (out != null) File(out).writeAsBytesSync(png);
    });
  });

  test('the app card brags only once there is something to brag about', () {
    PlayerStats stats(int solved, int streak) => PlayerStats(
      currentStreak: streak,
      longestStreak: streak,
      puzzlesCompleted: solved,
      bestSeconds: null,
      averageSeconds: null,
      hintsUsed: 0,
      solvedToday: false,
    );
    expect(appBrag(null), isNull);
    expect(appBrag(stats(0, 0)), isNull);
    expect(appBrag(stats(1, 1)), 'I have 1 puzzle solved');
    expect(appBrag(stats(12, 5)), "I'm on a 5-day streak · 12 puzzles solved");
  });

  testWidgets('the app card draws to a PNG 1080 wide', (tester) async {
    final font = FontLoader('Fredoka')..addFont(rootBundle.load('assets/fonts/Fredoka.ttf'));
    await font.load();
    await tester.runAsync(() async {
      final logo = await _decode(File('assets/images/blujem_logo.png').readAsBytesSync());
      final png = await renderAppCard(AppCard(logo: logo, brag: "I'm on a 5-day streak · 12 puzzles solved"));
      final image = await _decode(png);
      expect(image.width, 1080);
      expect(image.height, greaterThan(1200));
      // APP_CARD_OUT=/path/card.png flutter test … saves it to look at.
      final out = Platform.environment['APP_CARD_OUT'];
      if (out != null) File(out).writeAsBytesSync(png);
    });
  });
}

ui.Image get _none {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder);
  return recorder.endRecording().toImageSync(1, 1);
}
