import 'dart:math';
import 'dart:typed_data';

import 'package:blujem/admin/admin_service.dart';
import 'package:blujem/admin/word_index.dart';
import 'package:blujem/ui/screens/admin_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Squares as the answers fill them; an upper-case letter is circled.
List<({String letter, bool circled})> squares(String marked) => [
  for (final c in marked.split('')) (letter: c.toUpperCase(), circled: c == c.toUpperCase()),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the dictionary spells the cartoon answer from the circled letters', () async {
    final index = await WordIndex.load();
    final watch = Stopwatch()..start();
    final phrases = index.phrases('MITESROUGHTAE', [5, 8]);
    expect(phrases.first.phrase, 'ROUGH ESTIMATE', reason: 'the commonest words come first');
    expect(watch.elapsedMilliseconds, lessThan(2000));
  });

  test('little words the list leaves out still make phrases', () async {
    final index = await WordIndex.load();
    expect([
      for (final p in index.phrases('TURNIA', [2, 1, 3])) p.phrase,
    ], contains('IN A RUT'));
  });

  test('one misread circle is put right to find the answer', () async {
    final index = await WordIndex.load();
    // ROUGH ESTIMATE needs 13 circles; the reading missed the last E.
    final read = squares('ROUGHxx') + squares('ESTIMATe');
    expect(finalPhrases(index, read, [5, 8]).first, 'ROUGH ESTIMATE');
    // And with one circle too many.
    final extra = squares('ROUGHX') + squares('ESTIMATE');
    expect(finalPhrases(index, extra, [5, 8]), contains('ROUGH ESTIMATE'));
  });

  test('every published puzzle is suggested, most of them first', () async {
    final index = await WordIndex.load();
    final watch = Stopwatch()..start();
    final places = <String, int>{};
    for (final (words, groups, answer) in _published) {
      final found = finalPhrases(index, _squares(words), groups).toList();
      places[answer] = found.indexOf(answer);
    }
    // ignore: avoid_print
    print('$places in ${watch.elapsedMilliseconds} ms');
    expect(places.values, everyElement(isNot(-1)), reason: '$places');
    // A joining word is never put first or last ahead of the real phrase.
    expect(places['CUT AND DRY'], 0, reason: '$places');
    expect(places['DOWN AND OUT'], 0, reason: '$places');
  });

  test('the Sunday answer, with its ten-letter word, is suggested', () async {
    final index = await WordIndex.load();
    final (words, groups, answer) = _sunday;
    final watch = Stopwatch()..start();
    final found = finalPhrases(index, _squares(words), groups);
    expect(found, contains(answer), reason: '$found');
    expect(watch.elapsedMilliseconds, lessThan(3000));
  });

  test("today's two misread circles are put right", () async {
    final index = await WordIndex.load();
    // The server also circled COHORT's C and T: 15 circles for 13 squares.
    final read = _squares(['oFTEn', 'WAFer', 'DOnKey', 'COHORT']);
    final watch = Stopwatch()..start();
    final found = finalPhrases(index, read, [4, 3, 2, 4]);
    expect(found, hasLength(12), reason: 'a guess offers more phrases');
    expect(found, contains('HEAD OFF TO WORK'));
    expect(watch.elapsedMilliseconds, lessThan(3000));
  });

  test('two circles the server missed are found too', () async {
    final index = await WordIndex.load();
    // RANGE OF TOPICS with FICKLE's F and PASTOR's O left uncircled.
    final read = _squares(['cROwN', 'PurGE', 'fICkle', 'pASToR'.replaceAll('R', 'r')]);
    final watch = Stopwatch()..start();
    expect(finalPhrases(index, read, [5, 2, 6]), contains('RANGE OF TOPICS'));
    expect(watch.elapsedMilliseconds, lessThan(3000));
  });

  test('pictures are sent as smaller JPEGs', () async {
    // Grain like a photographed page, which PNG cannot squeeze.
    final random = Random(7);
    final picture = img.Image(width: 2400, height: 1200);
    for (final p in picture) {
      final shade = 200 + random.nextInt(56);
      p
        ..r = shade
        ..g = shade
        ..b = shade;
    }
    final png = Uint8List.fromList(img.encodePng(picture));
    final sent = await shrinkForUpload(png);
    expect(sent.length, lessThan(png.length));
    final back = img.decodeJpg(sent)!;
    expect(back.width, 2000);
  });
}

/// Published puzzles, as the paper circled them: each word's letters with
/// the circled ones in upper case, and the answer it led to.
const _published = [
  (['rADar', 'puTtY', 'crUNch', 'aCcoRD'], [3, 3, 3], 'CUT AND DRY'),
  (['crAWl', 'daDDy', 'rUNOff', 'bOuNTy'], [4, 3, 3], 'DOWN AND OUT'),
  (['tiGeR', 'clInG', 'wiNNer', 'jIngLE'], [8], 'REIGNING'),
  (['brIck', 'fiGht', 'stRAND', 'faiRlY'], [6], 'GRAINY'),
  (['oFTEn', 'WAFer', 'DOnKey', 'cOHORt'], [4, 3, 2, 4], 'HEAD OFF TO WORK'),
  (['rHInO', 'afTER', 'eMerGE', 'cAcTUS'], [5, 8], 'ROUGH ESTIMATE'),
  (['pAniC', 'evENT', 'tAuGHt', 'eXCEed'], [5, 6], 'EXACT CHANGE'),
  (['zeSTy', 'cOucH', 'couNTy', 'tattOO'], [3, 2, 3], 'NOT SO HOT'),
  (['qUeST', 'pIlOT', 'pOlLeN', 'lEGacY'], [2, 3, 2, 5], 'GO OUT IN STYLE'),
  (['sHoWn', 'cRyPt', 'acCEpt', 'criSIS'], [4, 1, 4], 'CREW S SHIP'),
  (['croSS', 'knIfE', 'booGIE', 'gENTle'], [4, 6], 'SITE SEEING'),
  (['cROwN', 'PurGE', 'FICkle', 'pASTOr'], [5, 2, 6], 'RANGE OF TOPICS'),
];

/// The Sunday Jumble of 2026-11-01: six words and a ten-letter word in the answer.
const _sunday = (['cOmpEL', 'bIKini', 'tyCOoN', 'sCeniC', 'folLoW', 'pERmiT'], [5, 10], 'WRECK COLLECTION');

List<({String letter, bool circled})> _squares(List<String> words) => [for (final w in words) ...squares(w)];
