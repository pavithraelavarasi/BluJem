import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:qr/qr.dart';
import 'package:share_plus/share_plus.dart';

import '../core/dates.dart';
import '../data/api_client.dart';
import '../data/puzzle_library.dart';
import '../game/caption.dart';
import '../game/game_controller.dart';
import '../models/box_rect.dart';
import '../models/records.dart';
import 'theme.dart';
import 'widgets/sheet_views.dart';

/// The page with the latest Android download (blujem_daily's site pages), so
/// the link never goes stale the way a signed APK link does.
const appDownloadPage = '$functionsBaseUrl/server/blujem_daily/execute/download';

/// Where the QR code sends friends: a short link to [appDownloadPage]
/// (TinyURL alias "blujem"; repoint it there if the page ever moves).
const appDownloadUrl = 'https://tinyurl.com/blujem';

/// The same link as written in a message: chat apps make it tappable
/// without the https://.
const appDownloadLink = 'tinyurl.com/blujem';

/// What a "Share your win" card shows.
class WinCard {
  const WinCard({
    required this.logo,
    required this.sheet,
    required this.cartoon,
    required this.answer,
    required this.title,
    required this.heading,
    this.captionTop,
    this.seconds,
    this.points,
  });

  final ui.Image logo;
  final ui.Image sheet;
  final BoxRect cartoon;

  /// The final answer as printed, punctuation and all. Only its shape is
  /// drawn, as blank squares: the card must not spoil the puzzle.
  final String answer;

  /// "Today's BluJem", or "BluJem" for an earlier day's.
  final String title;

  /// "Morning · Mon, Nov 9".
  final String heading;

  /// Where the cartoon's caption begins, as a fraction of its height: the
  /// card shows the picture above it, since the caption gives the riddle away.
  final double? captionTop;

  /// The solve time, or null when the clock ran out.
  final int? seconds;
  final int? points;

  /// The big line: "Solved in 1:42".
  String get timeLine => seconds == null ? 'Solved!' : 'Solved in ${shortClock(seconds!)}';

  /// The line under it: "+120 points", or nothing.
  String get detailLine => points != null && points! > 0 ? '+$points points' : '';
}

/// Whether there is a win to share: this run just solved, not given up, or
/// before a replay is started, the solve kept from earlier.
bool canShareWin(GameController game) =>
    game.completed ? !game.board.finalRow.revealed && !game.answersShown : !game.started && game.pastWin != null;

/// Draws the card for [game]'s win and opens the share sheet with it.
Future<void> shareWin(BuildContext context, GameController game) async {
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final puzzle = game.puzzle;
  final past = game.completed ? null : game.pastWin;
  final answer = past?.finalAnswer ?? puzzle.finalFrom(game.board.finalRow.letters);
  final seconds = past != null ? (past.timed ? past.seconds : null) : (game.timedOut ? null : game.elapsedAtCompletion);
  final library = context.read<PuzzleLibrary>();
  try {
    final logo = await _asset('assets/images/blujem_logo.png');
    final today = puzzle.publishDate == isoDate(DateTime.now());
    // The wordless cartoon when the admin gave one: the whole picture, no
    // words to give the pun away. Otherwise the cartoon above its caption.
    final wordless = await _decodeFile(await library.wordlessImage(puzzle));
    final ui.Image picture;
    final BoxRect region;
    double? caption;
    if (wordless != null) {
      picture = wordless;
      region = const BoxRect(0, 0, 1, 1);
    } else {
      final sheet = await loadSheet(puzzle);
      picture = sheet.image;
      region = sheet.cartoon;
      final pixels = await sheet.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (pixels != null) {
        caption = captionTop(pixels.buffer.asUint8List(), sheet.image.width, sheet.image.height, sheet.cartoon);
      }
    }
    final card = WinCard(
      logo: logo,
      sheet: picture,
      cartoon: region,
      answer: answer,
      title: today ? "Today's BluJem" : 'BluJem',
      captionTop: caption,
      heading: '${puzzle.slotKind.label} · ${dayLabel(puzzle.publishDate)}',
      seconds: seconds,
      // A replay or an earlier solve shows no points: they were not won now.
      points: past == null ? game.score?.totalPoints : null,
    );
    final png = await renderWinCard(card);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/blujem-win-${puzzle.id}.png');
    await file.writeAsBytes(png, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: '${winMessage(today: today, seconds: seconds)} $appDownloadLink',
        subject: 'I solved BluJem',
        sharePositionOrigin: origin,
      ),
    );
  } catch (e) {
    debugPrint('Share failed: $e');
    messenger?.showSnackBar(const SnackBar(content: Text('Could not make the picture to share. Try again.')));
  }
}

/// The message sent with the card: "I solved today's BluJem in 1:24. Can you
/// match my time?!" — an invitation, not a dare.
String winMessage({required bool today, int? seconds}) {
  final which = today ? "today's" : 'a';
  return seconds == null
      ? 'I solved $which BluJem. Can you solve it too?!'
      : 'I solved $which BluJem in ${shortClock(seconds)}. Can you match my time?!';
}

/// Draws the card that invites friends to BluJem itself — no puzzle on it —
/// and opens the share sheet with it. [stats] adds this player's streak and
/// count when there is something to brag about.
Future<void> shareApp(BuildContext context, {PlayerStats? stats}) async {
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final logo = await _asset('assets/images/blujem_logo.png');
    final png = await renderAppCard(AppCard(logo: logo, brag: appBrag(stats)));
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/blujem-invite.png');
    await file.writeAsBytes(png, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: 'Play BluJem with me — a new BluJem every morning, afternoon and night! $appDownloadLink',
        subject: 'Play BluJem with me',
        sharePositionOrigin: origin,
      ),
    );
  } catch (e) {
    debugPrint('Share failed: $e');
    messenger?.showSnackBar(const SnackBar(content: Text('Could not make the picture to share. Try again.')));
  }
}

/// What the app card shows: the logo and, when there is one, a line about
/// this player.
class AppCard {
  const AppCard({required this.logo, this.brag});
  final ui.Image logo;
  final String? brag;
}

/// "I'm on a 5-day streak · 12 puzzles solved", or null before the first solve.
String? appBrag(PlayerStats? stats) {
  if (stats == null || stats.puzzlesCompleted == 0) return null;
  final solved = stats.puzzlesCompleted == 1 ? '1 puzzle solved' : '${stats.puzzlesCompleted} puzzles solved';
  return stats.currentStreak > 1 ? "I'm on a ${stats.currentStreak}-day streak · $solved" : 'I have $solved';
}

/// [file] decoded, or null when there is none or it is not a picture.
Future<ui.Image?> _decodeFile(File? file) async {
  if (file == null) return null;
  try {
    final codec = await ui.instantiateImageCodec(await file.readAsBytes());
    return (await codec.getNextFrame()).image;
  } catch (e) {
    debugPrint('Wordless cartoon unreadable: $e');
    return null;
  }
}

Future<ui.Image> _asset(String path) async {
  final data = await rootBundle.load(path);
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  return (await codec.getNextFrame()).image;
}

// ------------------------------------------------------------------ drawing

const _width = 1080.0;
const _margin = 64.0;
const _paper = Color(0xFFFAF7F0);
const _card = Color(0xFFFFFDF8);
const _ink = Color(0xFF1C1B19);
const _inkSoft = Color(0xFF55524B);
const _rule = Color(0xFFD9D2C3);
const _tile = Color(0xFFE8C547);
const _blue = Color(0xFF1E6FE0);

/// [card] as a PNG, 1080 pixels wide and at most 1440 tall (3:4), so a chat
/// shows it whole instead of cropping the top and bottom: BluJem at the top,
/// the cartoon without its caption in the middle, the solve time, the
/// answer's blank squares, and a QR code to get the app.
Future<Uint8List> renderWinCard(WinCard card) async {
  final recorder = ui.PictureRecorder();
  final height = paintWinCard(Canvas(recorder), card);
  final image = await recorder.endRecording().toImage(_width.round(), height.round());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

/// The tallest a win card gets: 3:4, a shape chats show uncropped.
const winCardMaxHeight = 1440.0;

/// Paints [card] from the top of [canvas]; returns the height used.
double paintWinCard(Canvas canvas, WinCard card) {
  // Everything is laid out first, so the background can be drawn to fit.
  const logoHeight = 110.0;
  final logoWidth = card.logo.width * logoHeight / card.logo.height;

  final lines = _answerLines(card.answer);
  final tile = min(_tileSize(lines), 84.0);
  final answerHeight = lines.length * tile + (lines.length - 1) * 12;
  final hasDetail = card.detailLine.isNotEmpty;
  const footerHeight = 230.0;

  var y = 64.0;
  final logoTop = y;
  y += logoHeight + 10;
  final titleTop = y;
  y += 64;
  final headingTop = y;
  y += 40 + 22;
  final cartoonTop = y;
  // What comes under the cartoon, so the cartoon takes the rest of the room.
  final below = 40 + 30 + 76 + (hasDetail ? 42 : 0) + 22 + 34 + 14 + answerHeight + 36 + footerHeight + 48;

  // The picture above the caption, scaled to fit.
  final crop = card.cartoon;
  final keep = (card.captionTop ?? 1.0).clamp(0.5, 1.0);
  final cropW = crop.w * card.sheet.width;
  final cropH = crop.h * keep * card.sheet.height;
  const inner = _width - 2 * _margin - 40;
  final maxH = max(360.0, winCardMaxHeight - cartoonTop - below);
  var cartoonW = inner;
  var cartoonH = cropH / max(cropW, 1) * cartoonW;
  if (cartoonH > maxH) {
    cartoonH = maxH;
    cartoonW = cropW / max(cropH, 1) * cartoonH;
  }

  y += cartoonH + 40 + 30;
  final timeTop = y;
  y += 76;
  final detailTop = y;
  if (hasDetail) y += 42;
  y += 22;
  final labelTop = y;
  y += 34 + 14;
  final answerTop = y;
  y += answerHeight + 36;
  final footerTop = y;
  y += footerHeight + 48;
  final height = y;

  canvas.drawRect(Rect.fromLTWH(0, 0, _width, height), Paint()..color = _paper);

  // BluJem on top.
  _image(canvas, card.logo, Rect.fromLTWH((_width - logoWidth) / 2, logoTop, logoWidth, logoHeight));
  _text(canvas, card.title, titleTop, size: 52, weight: FontWeight.w700, color: _blue);
  _text(canvas, card.heading, headingTop, size: 32, weight: FontWeight.w600, color: _inkSoft);

  // The cartoon, in a card.
  final frame = Rect.fromLTWH((_width - cartoonW) / 2 - 20, cartoonTop, cartoonW + 40, cartoonH + 40);
  canvas.drawRRect(
    RRect.fromRectAndRadius(frame.shift(const Offset(0, 6)), const Radius.circular(28)),
    Paint()..color = const Color(0x1A000000),
  );
  canvas.drawRRect(RRect.fromRectAndRadius(frame, const Radius.circular(28)), Paint()..color = _card);
  canvas.drawRRect(
    RRect.fromRectAndRadius(frame, const Radius.circular(28)),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = _rule,
  );
  final src = Rect.fromLTWH(crop.x * card.sheet.width, crop.y * card.sheet.height, cropW, cropH);
  canvas.save();
  final picture = Rect.fromLTWH(frame.left + 20, frame.top + 20, cartoonW, cartoonH);
  canvas.clipRRect(RRect.fromRectAndRadius(picture, const Radius.circular(14)));
  canvas.drawImageRect(card.sheet, src, picture, Paint()..filterQuality = FilterQuality.high);
  canvas.restore();

  // The solve time, big, for friends to match.
  _text(canvas, card.timeLine, timeTop, size: 62, weight: FontWeight.w700, color: _ink);
  if (hasDetail) _text(canvas, card.detailLine, detailTop, size: 32, weight: FontWeight.w600, color: _inkSoft);

  // The answer stays hidden: only its blank squares, in the game's yellow.
  _text(canvas, 'CAN YOU GET THE ANSWER?', labelTop, size: 26, weight: FontWeight.w700, color: _inkSoft, spacing: 3);
  for (var i = 0; i < lines.length; i++) {
    _answerRow(canvas, lines[i], answerTop + i * (tile + 12), tile);
  }

  // The ad: a QR code to download the app.
  _appFooter(
    canvas,
    footerTop,
    footerHeight,
    'Can you solve it?',
    'A new BluJem every morning, afternoon and night. Scan to get the free Android app.',
  );
  return height;
}

/// [card] as a PNG, 1080 pixels wide.
Future<Uint8List> renderAppCard(AppCard card) async {
  final recorder = ui.PictureRecorder();
  final height = paintAppCard(Canvas(recorder), card);
  final image = await recorder.endRecording().toImage(_width.round(), height.round());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

/// What a day of BluJem holds, for the app card.
const _features = [
  ('3 new puzzles a day', 'Morning, afternoon and night'),
  ('Every day of the week', 'Sundays too'),
  ('Win daily medals', 'Gold, silver and bronze'),
  ('Climb the leaderboard', 'Race friends against the clock'),
];

/// Paints the invite [card] from the top of [canvas]; returns the height used.
/// BluJem on top, a row of letter tiles, what a day holds, the player's line,
/// and the QR code to get the app.
double paintAppCard(Canvas canvas, AppCard card) {
  const logoHeight = 150.0;
  final logoWidth = card.logo.width * logoHeight / card.logo.height;
  const featureHeight = 118.0;
  const footerHeight = 280.0;

  var y = 72.0;
  final logoTop = y;
  y += logoHeight + 20;
  final taglineTop = y;
  y += 70 + 40;
  final tilesTop = y;
  const tile = 120.0;
  y += tile + 56;
  final featuresTop = y;
  y += _features.length * featureHeight + 24;
  final bragTop = card.brag == null ? null : y;
  if (card.brag != null) y += 110;
  final footerTop = y;
  y += footerHeight + _margin;
  final height = y;

  canvas.drawRect(Rect.fromLTWH(0, 0, _width, height), Paint()..color = _paper);
  _image(canvas, card.logo, Rect.fromLTWH((_width - logoWidth) / 2, logoTop, logoWidth, logoHeight));
  _text(canvas, 'The daily word puzzle', taglineTop, size: 54, weight: FontWeight.w700, color: _blue);

  // BLUJEM in the game's tiles, each tipped a little, like letters to sort.
  const word = 'BLUJEM';
  const gap = 18.0;
  var x = (_width - (word.length * tile + (word.length - 1) * gap)) / 2;
  for (var i = 0; i < word.length; i++) {
    canvas.save();
    canvas.translate(x + tile / 2, tilesTop + tile / 2);
    canvas.rotate((i.isEven ? -1 : 1) * 0.06);
    final r = RRect.fromRectAndRadius(const Rect.fromLTWH(-tile / 2, -tile / 2, tile, tile), const Radius.circular(22));
    canvas.drawRRect(r.shift(const Offset(0, 7)), Paint()..color = const Color(0xFFB8952A));
    canvas.drawRRect(r, Paint()..color = _tile);
    _text(canvas, word[i], -tile * 0.36, size: tile * 0.58, weight: FontWeight.w700, left: -tile / 2, width: tile);
    canvas.restore();
    x += tile + gap;
  }

  // What a day holds, one card per line.
  for (var i = 0; i < _features.length; i++) {
    final (title, detail) = _features[i];
    final row = Rect.fromLTWH(_margin, featuresTop + i * featureHeight, _width - 2 * _margin, featureHeight - 18);
    canvas.drawRRect(RRect.fromRectAndRadius(row, const Radius.circular(24)), Paint()..color = _card);
    canvas.drawRRect(
      RRect.fromRectAndRadius(row, const Radius.circular(24)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = _rule,
    );
    canvas.drawCircle(Offset(row.left + 50, row.center.dy), 14, Paint()..color = _blue);
    final left = row.left + 90;
    final width = row.right - 24 - left;
    _text(canvas, title, row.top + 12, size: 36, weight: FontWeight.w700, left: left, width: width);
    _text(canvas, detail, row.top + 56, size: 28, color: _inkSoft, left: left, width: width);
  }

  if (bragTop != null) {
    _text(canvas, card.brag!, bragTop, size: 40, weight: FontWeight.w700, color: _ink);
    _text(canvas, 'Can you keep up?', bragTop + 52, size: 32, weight: FontWeight.w600, color: _inkSoft);
  }

  _appFooter(canvas, footerTop, footerHeight, 'Play with me', 'Free on Android. Scan to get BluJem.');
  return height;
}

/// The dark footer with the QR code to the download page.
void _appFooter(Canvas canvas, double top, double footerHeight, String title, String body) {
  final footer = Rect.fromLTWH(_margin, top, _width - 2 * _margin, footerHeight);
  canvas.drawRRect(RRect.fromRectAndRadius(footer, const Radius.circular(32)), Paint()..color = _ink);
  final qrSize = footerHeight - 64;
  final qrBox = Rect.fromLTWH(footer.left + 32, footer.top + (footerHeight - qrSize) / 2, qrSize, qrSize);
  canvas.drawRRect(RRect.fromRectAndRadius(qrBox, const Radius.circular(16)), Paint()..color = Colors.white);
  _qr(canvas, appDownloadUrl, qrBox.deflate(14));
  final textLeft = qrBox.right + 36;
  final textWidth = footer.right - 32 - textLeft;
  _text(
    canvas,
    title,
    footer.top + footerHeight * 0.16,
    size: 44,
    weight: FontWeight.w700,
    color: Colors.white,
    left: textLeft,
    width: textWidth,
  );
  _text(
    canvas,
    body,
    footer.top + footerHeight * 0.39,
    size: 30,
    color: const Color(0xFFE6E0D3),
    left: textLeft,
    width: textWidth,
  );
}

/// The answer on one line, or two split at the space nearest the middle when
/// one line would make the squares too small to read.
List<String> _answerLines(String answer) {
  final text = answer.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.length <= 13 || !text.contains(' ')) return [text];
  final middle = text.length ~/ 2;
  var best = -1;
  for (var i = 0; i < text.length; i++) {
    if (text[i] == ' ' && (best < 0 || (i - middle).abs() < (best - middle).abs())) best = i;
  }
  return [text.substring(0, best), text.substring(best + 1)];
}

bool _isLetter(String c) => RegExp('[A-Za-z]').hasMatch(c);

/// How wide one character of [line] is drawn, in squares: a letter is one,
/// a space or a mark is less.
double _span(String line) => line.split('').fold(0.0, (sum, c) => sum + (_isLetter(c) ? 1.0 : 0.45));

double _tileSize(List<String> lines) {
  const room = _width - 2 * _margin;
  final widest = lines.map(_span).reduce(max);
  return min(96.0, room / (widest * 1.2));
}

void _answerRow(Canvas canvas, String line, double top, double tile) {
  final gap = tile * 0.1;
  final total = line.split('').fold(0.0, (w, c) => w + (_isLetter(c) ? tile + gap : tile * 0.45 + gap)) - gap;
  var x = (_width - total) / 2;
  for (final c in line.split('')) {
    if (_isLetter(c)) {
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(x, top, tile, tile), Radius.circular(tile * 0.18));
      canvas.drawRRect(r.shift(Offset(0, tile * 0.05)), Paint()..color = const Color(0xFFB8952A));
      canvas.drawRRect(r, Paint()..color = _tile);
      _text(
        canvas,
        '?',
        top + tile * 0.08,
        size: tile * 0.62,
        weight: FontWeight.w700,
        color: const Color(0x99000000),
        left: x,
        width: tile,
      );
      x += tile + gap;
    } else {
      if (c != ' ') {
        _text(canvas, c, top + tile * 0.08, size: tile * 0.62, weight: FontWeight.w700, left: x, width: tile * 0.45);
      }
      x += tile * 0.45 + gap;
    }
  }
}

void _qr(Canvas canvas, String data, Rect box) {
  final image = QrImage(QrCode(payload: QrPayload.fromString(data)));
  final n = image.moduleCount;
  final cell = box.width / n;
  final dark = Paint()..color = _ink;
  for (var r = 0; r < n; r++) {
    for (var c = 0; c < n; c++) {
      if (image.isDark(r, c)) {
        // A hair wider than the cell, so neighbours join without seams.
        canvas.drawRect(Rect.fromLTWH(box.left + c * cell, box.top + r * cell, cell + 0.5, cell + 0.5), dark);
      }
    }
  }
  // The blue dot in the middle says "BluJem" without hurting the scan.
  canvas.drawCircle(box.center, cell * 2.2, Paint()..color = Colors.white);
  canvas.drawCircle(box.center, cell * 1.6, Paint()..color = _blue);
}

void _image(Canvas canvas, ui.Image image, Rect to) => canvas.drawImageRect(
  image,
  Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
  to,
  Paint()..filterQuality = FilterQuality.high,
);

/// [text] centred in [width] from [left] (the whole card by default).
void _text(
  Canvas canvas,
  String text,
  double top, {
  required double size,
  FontWeight weight = FontWeight.w400,
  Color color = _ink,
  double left = 0,
  double width = _width,
  double spacing = 0,
}) {
  final centred = width == _width;
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: spacing,
        height: 1.2,
      ),
    ),
    textAlign: centred || width < 200 ? TextAlign.center : TextAlign.left,
    textDirection: TextDirection.ltr,
  )..layout(minWidth: width, maxWidth: width);
  painter.paint(canvas, Offset(left, top));
}
