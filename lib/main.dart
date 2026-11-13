import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'admin/admin_service.dart';
import 'data/api_client.dart';
import 'data/app_updates.dart';
import 'data/auth_repository.dart';
import 'data/hint_service.dart';
import 'data/local_store.dart';
import 'data/puzzle_library.dart';
import 'data/profile_service.dart';
import 'data/puzzle_reminders.dart';
import 'data/records_repository.dart';
import 'data/score_repository.dart';
import 'data/social_sign_in.dart';
import 'game/game_controller.dart';
import 'ui/app.dart';
import 'ui/feedback.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['Fredoka'], await rootBundle.loadString('assets/fonts/Fredoka-OFL.txt'));
  });

  // One instance of each, wired here and nowhere else.
  final store = await LocalStore.open();
  final api = ApiClient();
  final social = CatalystSignIn();
  await social.start();
  final auth = AuthRepository(api, store, social);
  final library = PuzzleLibrary(api, store);
  await library.load();
  final records = RecordsRepository(api, store);
  final scores = ScoreRepository(api, () => auth.signedIn);
  final hints = HintService(api, () => auth.signedIn);
  final game = GameController(library: library, records: records, scores: scores, hints: hints);
  final feedback = GameFeedback(store);
  unawaited(auth.start());
  // "A new BluJem is out", pushed when the admin publishes and when a timed slot opens.
  unawaited(PuzzleReminders(onPuzzleOut: () => unawaited(library.sync())).start());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: library),
        ChangeNotifierProvider.value(value: records),
        ChangeNotifierProvider.value(value: game),
        ChangeNotifierProvider.value(value: feedback),
        Provider.value(value: scores),
        Provider.value(value: AdminService(api)),
        Provider.value(value: ProfileService(api)),
        Provider.value(value: AppUpdates()),
      ],
      child: const BluJemApp(),
    ),
  );
}
