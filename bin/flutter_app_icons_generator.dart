import 'dart:io';

import 'package:flutter_app_icons_generator/src/cli/cli_runner.dart';

/// CLI entry point for flutter_app_icons.
///
/// Generates platform-specific app icons and native splash screens
/// for Flutter projects from a YAML configuration file.
Future<void> main(List<String> arguments) async {
  final runner = CliRunner();
  final exitCode = await runner.run(arguments);
  exit(exitCode);
}
