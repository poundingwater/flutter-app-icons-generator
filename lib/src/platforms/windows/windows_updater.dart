import 'dart:io';

import 'package:flutter_app_icons_generator/src/core/platform_updater.dart';

/// Windows platform configuration updater.
///
/// Verifies that `windows/runner/Runner.rc` references
/// `resources/app_icon.ico` as the application icon. If the file references
/// a different icon filename, it is updated. If the expected pattern is not
/// found (custom setup), or the file does not exist (platform not
/// initialized), the updater gracefully skips.
class WindowsUpdater implements PlatformUpdater {
  /// The expected icon reference in `Runner.rc`.
  static const String _expectedIconRef = r'resources\app_icon.ico';

  /// Path to `Runner.rc` relative to the project root.
  static const String _runnerRcPath = 'windows/runner/Runner.rc';

  @override
  Future<void> update(String projectRoot, {String? flavorName}) async {
    final rcFile = File('$projectRoot/$_runnerRcPath');

    if (!rcFile.existsSync()) {
      // Platform not initialized — nothing to update.
      return;
    }

    final content = rcFile.readAsStringSync();
    final updatedContent = _ensureIconReference(content);

    if (updatedContent != content) {
      rcFile.writeAsStringSync(updatedContent);
    }
  }

  /// Ensures `IDI_APP_ICON ICON` references `resources\app_icon.ico`.
  ///
  /// If the line exists but references a different file, it is replaced.
  /// If the pattern is not found at all, this may be a custom setup and
  /// the content is returned unchanged.
  String _ensureIconReference(String content) {
    // Pattern to match: IDI_APP_ICON ICON "some/path/to/icon.ico"
    // The pattern accounts for optional whitespace variations.
    final iconPattern = RegExp(
      r'(IDI_APP_ICON\s+ICON\s+)"([^"]*)"',
    );

    if (!iconPattern.hasMatch(content)) {
      // Pattern not found — custom setup, skip.
      return content;
    }

    final match = iconPattern.firstMatch(content)!;
    final currentPath = match.group(2)!;

    // Normalize backslashes for comparison.
    final normalizedCurrent = currentPath.replaceAll('/', r'\');
    final normalizedExpected = _expectedIconRef.replaceAll('/', r'\');

    if (normalizedCurrent == normalizedExpected) {
      // Already correct — no changes needed.
      return content;
    }

    // Replace with the correct reference.
    return content.replaceFirst(
      iconPattern,
      '${match.group(1)}"$_expectedIconRef"',
    );
  }
}
