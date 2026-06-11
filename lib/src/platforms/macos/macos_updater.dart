import 'dart:io';

import 'package:flutter_app_icons_generator/src/core/platform_updater.dart';

/// Updates the macOS Xcode project to reference the `AppIcon` asset catalog entry.
///
/// Ensures `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` is present in the
/// Xcode project build settings (`project.pbxproj`). If the setting exists
/// with a different value, it is replaced. If the file does not exist (e.g.,
/// the macOS platform is not initialized), the updater does nothing.
class MacosUpdater implements PlatformUpdater {
  /// The expected build setting value.
  static const String _expectedSetting =
      'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon';

  /// Regex matching any `ASSETCATALOG_COMPILER_APPICON_NAME = <value>;` line.
  static final RegExp _settingPattern = RegExp(
    r'ASSETCATALOG_COMPILER_APPICON_NAME\s*=\s*[^;]+;',
  );

  @override
  Future<void> update(String projectRoot, {String? flavorName}) async {
    final pbxprojPath = '$projectRoot/macos/Runner.xcodeproj/project.pbxproj';
    final file = File(pbxprojPath);

    // If the file doesn't exist, the macOS platform may not be initialized.
    if (!file.existsSync()) {
      return;
    }

    var content = file.readAsStringSync();

    // Check if the correct setting already exists.
    if (content.contains('$_expectedSetting;')) {
      return;
    }

    // If the setting exists with a different value, replace it.
    if (_settingPattern.hasMatch(content)) {
      content = content.replaceAll(
        _settingPattern,
        '$_expectedSetting;',
      );
      file.writeAsStringSync(content);
    }

    // If the setting is not present at all, Flutter project templates
    // typically include it by default, so we leave it as-is.
  }
}
