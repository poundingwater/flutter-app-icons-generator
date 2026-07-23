/// Example: Using flutter_app_icons_generator as a CLI tool.
///
/// This package is primarily used via the command line. Add it as a
/// dev dependency and create a `flutter_app_icons_generator.yml` config file.
///
/// ## Quick Start
///
/// 1. Add to `pubspec.yaml`:
/// ```yaml
/// dev_dependencies:
///   flutter_app_icons_generator: ^0.1.0
/// ```
///
/// 2. Generate a default config:
/// ```bash
/// dart run flutter_app_icons_generator --init
/// ```
///
/// 3. Edit `flutter_app_icons_generator.yml`:
/// ```yaml
/// icon:
///   foreground: assets/icon_foreground.png
///   background: "#4CAF50"
///
/// platforms:
///   - android
///   - ios
/// ```
///
/// 4. Generate icons:
/// ```bash
/// dart run flutter_app_icons_generator
/// ```
///
/// ## With App Flavors
///
/// ```yaml
/// icon:
///   foreground: assets/icon_foreground.png
///   background: assets/background.png
///
/// flavors:
///   dev:
///     bundle_identifier: com.example.myapp.dev
///     icon:
///       foreground: assets/dev-foreground.png
///       background: "#4CAF50"
///   prod:
///     bundle_identifier: com.example.myapp
///     icon:
///       foreground: assets/prod-foreground.png
///       background: "#1e1e2e"
///
/// platforms:
///   - android
///   - ios
///   - macos
/// ```
///
/// Then run with a flavor:
/// ```bash
/// flutter run --flavor dev
/// flutter run --flavor prod
/// ```
///
/// See [example.md](example.md) for more configuration examples.
library;

import 'package:flutter_app_icons_generator/flutter_app_icons_generator.dart';

Future<void> main() async {
  // Programmatic usage (typically you just use the CLI):
  final runner = CliRunner();
  final exitCode = await runner.run(['--verbose']);
  print('Exit code: $exitCode');
}
