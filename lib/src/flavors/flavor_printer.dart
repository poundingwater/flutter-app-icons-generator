import 'package:flutter_app_icons_generator/src/config/config_model.dart';
import 'package:flutter_app_icons_generator/src/flavors/flavor_model.dart';

/// Printer for flavor configurations.
class FlavorPrinter {
  /// Serializes the flavors map to a YAML string block.
  static String printFlavors(
    Map<String, FlavorConfig> flavors, {
    required String Function(BackgroundConfig) backgroundToString,
  }) {
    if (flavors.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('');
    buffer.writeln('flavors:');

    for (final entry in flavors.entries) {
      buffer.writeln('  ${entry.key}:');
      final icon = entry.value.icon;
      final splash = entry.value.splash;
      final bundleIdentifier = entry.value.bundleIdentifier;

      buffer.writeln('    bundle_identifier: $bundleIdentifier');

      buffer.writeln('    icon:');
      if (icon.allPlatforms != null) {
        buffer.writeln('      all_platforms: ${icon.allPlatforms}');
      }
      if (icon.foregroundPath != null) {
        buffer.writeln('      foreground: ${icon.foregroundPath}');
      }
      if (icon.background != null) {
        buffer.writeln(
            '      background: ${backgroundToString(icon.background!)}');
      }

      for (final override in icon.platformOverrides.entries) {
        buffer.writeln('      ${override.key.name}:');
        buffer.writeln('        foreground: ${override.value.foregroundPath}');
        if (override.value.background != null) {
          buffer.writeln(
              '        background: ${backgroundToString(override.value.background!)}');
        }
      }

      if (splash != null) {
        buffer.writeln('    splash:');
        buffer.writeln('      image: ${splash.imagePath}');
        if (splash.backgroundColor != null) {
          buffer.writeln('      background_color: "${splash.backgroundColor}"');
        }
      }
    }

    return buffer.toString();
  }

  /// Returns the documentation block and example for flavors.
  static String printDefaultExample() {
    return '''
# ─────────────────────────────────────────────────────────────────────────────
# Flavors Configuration (optional)
# ─────────────────────────────────────────────────────────────────────────────
#
# You can define app flavors to generate different icons and splash screens
# for each environment (e.g., dev, staging, prod).
#
# Each flavor requires:
#   - `bundle_identifier`: unique app ID for this flavor (used as applicationId
#     on Android and PRODUCT_BUNDLE_IDENTIFIER on iOS)
#   - `icon`: icon configuration (same structure as the top-level `icon`)
#
# When `flavors` are configured, the generator will create flavor-specific
# assets for Android and iOS (e.g., android/app/src/dev/res,
# AppIcon-dev.appiconset) and configure platform build files automatically.
# Platforms that do not support flavors (macOS, web, linux, windows) will
# use the top-level `icon` configuration.
#
# Note: A top-level `icon` is required when non-flavor platforms
# (macOS, web, linux, windows) are included in the platforms list.
#
# Example:
# flavors:
#   dev:
#     bundle_identifier: com.example.app.dev
#     icon:
#       foreground: assets/dev_icon.png
#       background: "#4CAF50"
#   staging:
#     bundle_identifier: com.example.app.staging
#     icon:
#       all_platforms: assets/staging_icon.png
#     splash:
#       image: assets/staging_splash.png
#       background_color: "#000000"
''';
  }
}
