import 'dart:io';

import 'package:args/args.dart';

/// Builds and manages CLI argument parsing for the generator.
class CliArgParser {
  /// Builds the [ArgParser] with all supported flags and options.
  ArgParser build() {
    return ArgParser()
      ..addFlag(
        'init',
        help: 'Generate a default flutter_app_icons_generator.yml config file.',
        negatable: false,
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        help: 'Enable verbose output with detailed file paths.',
        negatable: false,
      )
      ..addFlag(
        'help',
        abbr: 'h',
        help: 'Show usage information.',
        negatable: false,
      )
      ..addOption(
        'project-root',
        abbr: 'p',
        help:
            'Path to the Flutter project root (defaults to current directory).',
      );
  }

  /// Prints usage/help information to stdout.
  void printUsage() {
    stdout.writeln(
        'flutter_app_icons_generator — App Icon & Splash Screen Generator');
    stdout.writeln('');
    stdout.writeln('Usage: dart run flutter_app_icons_generator [options]');
    stdout.writeln('');
    stdout.writeln(build().usage);
  }
}
