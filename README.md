# BluJem (Flutter)

The daily word-jumble game for **Android, iOS and macOS**, ported from the
Android app at `../JumbleAndroid`. It plays against the same Catalyst project
(`BluJem`, Development) and the same functions: `jumble_auth`,
`jumble_data` and `jumble_ai`. The backend is unchanged.

```bash
flutter pub get
flutter test
flutter run -d macos      # or an Android device / iPhone
```

`flutter test test_screens --update-goldens` renders the main screens to
`test_screens/shots/` with a fake session and no network, for design review.

## Layout

```
lib/
  main.dart                 wires one instance of everything, nothing else
  core/dates.dart           date and clock formatting
  models/                   Puzzle (one model for server, cache and bundled sheets),
                            AnswerShape, BoxRect, records (Account, Completion, scores)
  data/
    api_client.dart         the only HTTP client: POST {base}/server/{fn}/execute/{route}
    auth_repository.dart    sign-in / sign-up / Zoho+Google trade / username
    social_sign_in.dart     Catalyst SDK hosted login (Android & iOS only)
    puzzle_library.dart     published + bundled sheets, today / stand-in / awaiting, sync
    records_repository.dart finished runs per account, stats and streaks
    score_repository.dart   points clock, scoring, leaderboard
    hint_service.dart       AI hint when available, glossary ladder always
  game/
    board.dart              the rules, as a pure immutable Board (no timers, no I/O)
    game_controller.dart    one run: clocks, hints, finish, scoring
    cartoon.dart            finds the cartoon frame on an uploaded sheet
  ui/                       theme, screens, widgets
```

`Board` is where the game lives. Every row (the four words and the final
answer) is a pool of letters plus an order, so a move is just a reorder and
undo is just an earlier order. The answer row's pool is the circled letters of
the solved words, so it follows the words the way the paper does.

## What changed from the Android app

Same rules, simpler code:

- **One row model.** Android kept the answer row twice (`finalOrder` and
  `finalTyped`), with two code paths in every action. Here every row is the
  same `RowState`.
- **One HTTP client.** Android had three OkHttp clients with their own token
  and error handling. Here there is `ApiClient`.
- **One hint path.** The offline ladder was built in three places (repository,
  dictionary provider, AI repository). Here it is in `HintService`.
- **Published and bundled sheets are kept apart.** Android stored them in one
  list and sliced off the samples with `dropLast(bundled.size)`.
- **Removed dead code:** `showTryAgain` (never set true), the wrong-answer
  sound that depended on it, `explainFocusedWord` and `localScore` (never
  called), and the hand-written sample hints (always replaced by glossary
  hints).
- **Fixed:** a newly downloaded sheet no longer replaces a puzzle the player
  opened from History; the final-answer hint now counts letters, not
  punctuation (`"CREW'S"` is 5 letters, not 8).

The board is drawn as game tiles rather than over the photo of the sheet. The
sheet is still there: the cartoon page crops it, and "View printed sheet"
shows the whole thing.

## Not in this app

- **Admin tools** (sheet upload, OCR, layout detection, the editor, Daily
  Puzzles). Admins keep using the Android app.
- **Background "today's puzzle is up" notifications.** While the app is open,
  it checks every minute and switches to today's puzzle when it arrives.
- **In-app APK updates.** The stores handle updates.

## Sign-in

Email and password work everywhere. **Continue with Zoho or Google** uses the
Catalyst SDK's hosted page on Android and iOS. The SDK reads the
console-issued files already used by the native apps:

- `android/app/src/main/assets/app_configuration_development.properties`
  (redirect `dailyjumble://`)
- `ios/Runner/AppConfigurationDevelopment.plist` (redirect `bluejem://`)

Both files hold the OAuth client secret, so keep them out of public repos.

The SDK has no macOS build, so the button is hidden there.

## Known build issues

- **iOS Simulator:** Zoho's `ZohoPortalAuth` pod (used by `zcatalyst_sdk`)
  has no arm64 simulator slice, and iOS 26+ simulators on Apple Silicon run
  arm64 only. The Podfile's `post_install` runs `tool/zoho_sim_framework.sh`,
  which builds `ios/ZohoSim/` (Zoho's arm64 objects re-tagged for the
  simulator by `tool/arm64_to_sim.py`) and points simulator builds at it.
  `ios/Flutter/Debug.xcconfig` and `Release.xcconfig` override Flutter's own
  arm64-simulator exclusion. Device builds still link Zoho's original
  library. Run `pod install` with `LANG=en_US.UTF-8` set.
- **Android on this office network:** `repo.maven.apache.org` returns 404 for
  some Kotlin artifacts. Use Google's mirror
  (`https://maven-central.storage-download.googleapis.com/maven2/`) ahead of
  Central, for example through a Gradle init script.
