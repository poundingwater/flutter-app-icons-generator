import 'package:flutter_app_icons_generator/src/shared/constants.dart';

/// Abstract interface for CLI progress and error reporting.
///
/// Provides structured logging methods for each stage of the icon
/// generation pipeline, supporting both normal and verbose output modes.
abstract class Logger {
  /// Logs the start of icon/splash generation for [platform].
  void platformStart(Platform platform);

  /// Logs that a file was generated at [path].
  ///
  /// In verbose mode, displays the full file path. In normal mode,
  /// this may be suppressed or summarized.
  void fileGenerated(String path);

  /// Logs successful completion of generation for [platform].
  void platformComplete(Platform platform);

  /// Logs the final summary with [totalFiles] generated and [elapsed] time.
  void summary(int totalFiles, Duration elapsed);

  /// Logs a non-fatal error for [platform] with [message].
  ///
  /// Generation continues for remaining platforms after a platform error.
  void platformError(Platform platform, String message);

  /// Logs a fatal error with [message].
  ///
  /// Indicates the CLI must exit immediately.
  void fatalError(String message);

  /// Logs an informational [message].
  void info(String message);

  /// Logs a verbose detail [message].
  ///
  /// Only displayed when the CLI is invoked with the --verbose flag.
  void verbose(String message);
}
