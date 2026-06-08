import 'dart:io';

import 'package:flutter_app_icons_generator/src/core/platform_updater.dart';

/// Android platform configuration updater.
///
/// Ensures the `AndroidManifest.xml` references `@mipmap/ic_launcher`
/// as the application icon after icon generation.
class AndroidUpdater implements PlatformUpdater {
  /// Path to `AndroidManifest.xml` relative to the project root.
  static const _manifestPath = 'android/app/src/main/AndroidManifest.xml';

  @override
  Future<void> update(String projectRoot) async {
    final manifestFile = File('$projectRoot/$_manifestPath');

    if (!manifestFile.existsSync()) {
      // Platform may not be initialized — nothing to update.
      return;
    }

    final content = manifestFile.readAsStringSync();
    final updatedContent = _ensureIconAttribute(content);

    if (updatedContent != content) {
      manifestFile.writeAsStringSync(updatedContent);
    }
  }

  /// Ensures the `<application` tag has `android:icon="@mipmap/ic_launcher"`.
  ///
  /// If the attribute is missing, it is added. If it references a different
  /// value, it is replaced.
  String _ensureIconAttribute(String content) {
    // Pattern to match android:icon with any value inside the <application tag.
    final iconAttrPattern = RegExp(r'android:icon="[^"]*"');

    // Pattern to match the opening <application tag (may span multiple lines).
    final applicationTagPattern = RegExp(r'<application\b');

    if (iconAttrPattern.hasMatch(content)) {
      // The attribute exists — check if it already has the correct value.
      final existingMatch = iconAttrPattern.firstMatch(content)!;
      final existingAttr = existingMatch.group(0)!;

      if (existingAttr == 'android:icon="@mipmap/ic_launcher"') {
        // Already correct — no changes needed.
        return content;
      }

      // Replace with the correct value.
      return content.replaceFirst(
        iconAttrPattern,
        'android:icon="@mipmap/ic_launcher"',
      );
    }

    // The attribute is not present — add it to the <application tag.
    if (applicationTagPattern.hasMatch(content)) {
      return content.replaceFirst(
        applicationTagPattern,
        '<application\n        android:icon="@mipmap/ic_launcher"',
      );
    }

    // No <application tag found — return content unchanged.
    return content;
  }
}
