# Development

Use Flutter 3.47.8 (Dart 3.13), Java 17 or 21, and the Android SDK. Start with `flutter doctor -v`. Android API 24 is the minimum supported device version.

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter devices
flutter run -d DEVICE_ID
```

Enable USB debugging on a physical Android phone and approve its computer authorization prompt. To build a standalone test APK:

```sh
flutter build apk --debug
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`. Release distribution requires your own signing configuration. Keep keystores, `key.properties`, tokens, and local SDK paths out of Git.

## Device tests

```sh
flutter test integration_test/ad_blocker_test.dart -d DEVICE_ID
flutter test integration_test/app_test.dart -d DEVICE_ID
```

The first test exercises native request blocking, cosmetic rules, popup protection, script evaluation, and a site exception against a local HTTP fixture. The second drives the app UI with a fake script repository and local page, exercising domain discovery, script selection, editor persistence, execution results, and the protection dialog. Device tests temporarily install a test build under the application ID. Use `flutter run -d DEVICE_ID` afterward to restore the normal app.

Unit tests cover legacy preferences, failures, script result decoding/cleanup/timeouts, domain normalization, discovery cache, stale responses, and browser state transitions. GitHub Actions runs formatting, static analysis, unit tests and Android compilation on pushes and pull requests. Device tests require a connected phone or emulator and run separately.

## Git workflow

Create a branch for a change, keep generated files excluded, and run the relevant checks before opening a pull request. Keep `pubspec.lock` in version control because this is an application. Document changes to settings keys, domain matching and script format. Do not commit the `build/`, `.dart_tool/`, or local SDK folders.

To connect a new remote after signing in with GitHub CLI:

```sh
gh auth login
gh repo create script-browser --private --source . --remote origin --push
```

The app currently reads public script repositories. If this app source repository is private, configure a separate public script repository. Do not switch a repository to public without reviewing its contents and visibility preference.
