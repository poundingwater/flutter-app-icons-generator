import 'dart:io';

import 'package:flutter_app_icons/src/cli/logger.dart';
import 'package:flutter_app_icons/src/shared/constants.dart';

/// Concrete implementation of [Logger] that writes to stdout/stderr.
///
/// Supports a verbose mode that outputs detailed file paths during generation.
class ConsoleLogger implements Logger {
  /// Creates a [ConsoleLogger] with optional verbose output.
  ConsoleLogger({bool verbose = false}) : _verbose = verbose;

  /// Whether verbose output is enabled.
  final bool _verbose;

  @override
  void platformStart(Platform platform) {
    stdout.writeln('🔧 Generating ${platform.name} icons...');
  }

  @override
  void fileGenerated(String path) {
    if (_verbose) {
      stdout.writeln(path);
    }
  }

  @override
  void platformComplete(Platform platform) {
    stdout.writeln('✓ ${platform.name} complete');
  }

  @override
  void summary(int totalFiles, Duration elapsed) {
    final seconds = elapsed.inMilliseconds / 1000;
    stdout.writeln('✨ Generated $totalFiles files in ${seconds}s');
  }

  @override
  void platformError(Platform platform, String message) {
    stderr.writeln('⚠️ ${platform.name}: $message');
  }

  @override
  void fatalError(String message) {
    stderr.writeln('❌ Error: $message');
  }

  @override
  void info(String message) {
    stdout.writeln(message);
  }

  @override
  void verbose(String message) {
    if (_verbose) {
      stdout.writeln(message);
    }
  }
}
