import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:no_screenshot/no_screenshot.dart';
import 'package:provider/provider.dart';

import 'admin/admin_service.dart';
import 'data/api_client.dart';
import 'data/app_refresh.dart';
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
import 'ui/screens/play_screen.dart';
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
  unawaited(feedback.preload());
  // The plugin remembers protection across launches; only the game screen
  // turns it on, so the app always starts with it off. On Android the plugin
  // restores the saved state on a background thread as the app opens, which
  // can land after this call, so it is said again once Home is drawn.
  void allowScreenshots() => unawaited(NoScreenshot.instance.screenshotOn().catchError((Object _) => false));
  allowScreenshots();
  unawaited(auth.start());
  // "A new BluJem is out", pushed when the admin publishes and when a timed slot opens.
  unawaited(PuzzleReminders(onPuzzleOut: () => unawaited(library.sync())).start());
  final refresh = AppRefresh(() {
    library.onResumed();
    if (auth.signedIn) {
      unawaited(records.refresh());
      unawaited(auth.refreshProfile());
    }
  })..start();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: library),
        ChangeNotifierProvider.value(value: records),
        ChangeNotifierProvider.value(value: game),
        ChangeNotifierProvider.value(value: feedback),
        ChangeNotifierProvider.value(value: refresh),
        Provider.value(value: scores),
        Provider.value(value: AdminService(api)),
        Provider.value(value: ProfileService(api)),
        Provider.value(value: AppUpdates()),
      ],
      child: const BluJemApp(),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => Timer(const Duration(seconds: 1), () {
      if (!PlayScreen.open) allowScreenshots();
    }),
  );
}

