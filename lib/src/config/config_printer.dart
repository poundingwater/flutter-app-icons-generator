import 'package:flutter_app_icons_generator/src/config/config_model.dart';
import 'package:flutter_app_icons_generator/src/shared/constants.dart';

/// Abstract interface for serializing configuration to YAML format.
///
/// Used both for generating default configuration files (via --init) and
/// for round-trip serialization of parsed configurations.
abstract class ConfigPrinter {
  /// Serializes [config] to a YAML string.
  ///
  /// Produces a valid YAML representation that, when parsed back with
  /// [ConfigParser], produces a semantically equivalent configuration.
  String print(AppIconsConfig config);

  /// Generates a default configuration file with documentation comments.
  ///
  /// The output includes a header comment block explaining each
  /// configuration field, supported values, and usage examples.
  String printDefault();
}

/// Concrete implementation of [ConfigPrinter] that produces YAML output.
///
/// The [print] method generates valid YAML that can be parsed back by the
/// `YamlConfigParser` to produce a semantically equivalent [AppIconsConfig].
///
/// The [printDefault] method generates a fully commented YAML template
/// suitable for use with the `--init` CLI flag.
class YamlConfigPrinter implements ConfigPrinter {
  /// Default platforms (android + ios).
  static const Set<Platform> _defaultPlatforms = {
    Platform.android,
    Platform.ios,
  };

  @override
  String print(AppIconsConfig config) {
    final buffer = StringBuffer();

    // Icon section (required)
    buffer.writeln('icon:');
    if (config.icon.allPlatforms != null) {
      buffer.writeln('  all_platforms: ${config.icon.allPlatforms}');
    }
    if (config.icon.foregroundPath != null) {
      buffer.writeln('  foreground: ${config.icon.foregroundPath}');
    }
    if (config.icon.background != null) {
      final bgValue = _backgroundToString(config.icon.background!);
      buffer.writeln('  background: $bgValue');
    }

    // Platform overrides
    for (final entry in config.icon.platformOverrides.entries) {
      buffer.writeln('  ${entry.key.name}:');
      buffer.writeln('    foreground: ${entry.value.foregroundPath}');
      if (entry.value.background != null) {
        final bgValue = _backgroundToString(entry.value.background!);
        buffer.writeln('    background: $bgValue');
      }
    }

    // Splash section (optional, only if present)
    if (config.splash != null) {
      buffer.writeln('');
      buffer.writeln('splash:');
      buffer.writeln('  image: ${config.splash!.imagePath}');
      if (config.splash!.backgroundColor != null) {
        buffer
            .writeln('  background_color: "${config.splash!.backgroundColor}"');
      }
    }

    // Platforms section (only if not the default set)
    if (!_setEquals(config.platforms, _defaultPlatforms)) {
      buffer.writeln('');
      buffer.writeln('platforms:');
      final sorted = config.platforms.toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      for (final platform in sorted) {
        buffer.writeln('  - ${platform.name}');
      }
    }

    return buffer.toString();
  }

  @override
  String printDefault() {
    return '''# flutter_app_icons_generator.yml
# Configuration for flutter_app_icons_generator — app icon & splash screen generator.
#
# For documentation, see: https://github.com/poundingwater/flutter-app-icons-generator

# ─────────────────────────────────────────────────────────────────────────────
# Icon Configuration (required)
# ─────────────────────────────────────────────────────────────────────────────
#
# You can configure icons in two ways:
#
# 1. SIMPLE MODE — one image for all platforms:
#    Use `all_platforms` to provide a single pre-composited image.
#
# 2. ADAPTIVE MODE — separate foreground and background layers:
#    Use `foreground` + `background` for maximum flexibility.
#    The package composites them per platform automatically.
#    - Platforms that need opaque icons (iOS, macOS, Linux): composited
#    - Platforms that need transparency (Windows): foreground only
#    - Android: uses layers natively for adaptive icons
#
# Image requirements:
#   - Minimum size: 1024x1024 pixels
#   - Supported formats: PNG, JPEG
#   - For best results, use a square PNG with transparent background
#     as foreground, and a solid color or image as background.
#
icon:
  # Option 1: Single image for all platforms (simplest setup)
  # all_platforms: assets/icon.png

  # Option 2: Separate foreground and background (recommended)
  foreground: assets/icon_foreground.png
  background: "#FFFFFF"  # hex color (e.g. "#4CAF50") or image path

  # ───────────────────────────────────────────────────────────────────────────
  # Platform-specific overrides (optional)
  # ───────────────────────────────────────────────────────────────────────────
  #
  # Override foreground/background for specific platforms when needed.
  # Each platform override requires `foreground` and optionally `background`.
  # If background is omitted, the foreground is used as-is (transparency preserved).
  #
  # Example: Use a different foreground for iOS
  # ios:
  #   foreground: assets/ios_foreground.png
  #   background: "#FFFFFF"
  #
  # Example: Web-specific icon optimized for small sizes
  # web:
  #   foreground: assets/web_icon.png
  #   background: "#FFFFFF"

# ─────────────────────────────────────────────────────────────────────────────
# Splash Screen Configuration (optional)
# ─────────────────────────────────────────────────────────────────────────────
#
# splash:
#   image: assets/splash.png
#   background_color: "#FFFFFF"

# ─────────────────────────────────────────────────────────────────────────────
# Target Platforms (optional — defaults to android and ios)
# ─────────────────────────────────────────────────────────────────────────────
#
# Uncomment and add platforms you want to generate icons for.
# Supported: android, ios, macos, web, linux, windows
#
platforms:
  - android
  - ios
  # - macos
  # - web
  # - linux
  # - windows
''';
  }

  /// Converts a [BackgroundConfig] to its YAML string representation.
  String _backgroundToString(BackgroundConfig background) {
    return switch (background) {
      BackgroundColor(hexColor: final color) => '"$color"',
      BackgroundImage(imagePath: final path) => path,
    };
  }

  /// Compares two sets for equality.
  static bool _setEquals<T>(Set<T> a, Set<T> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }
}
