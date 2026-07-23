import 'package:flutter_app_icons_generator/src/config/config_model.dart';
import 'package:flutter_app_icons_generator/src/flavors/flavor_printer.dart';
import 'package:flutter_app_icons_generator/src/shared/constants.dart';

/// Serializes [AppIconsConfig] to YAML format.
abstract class ConfigPrinter {
  /// Serializes [config] to a YAML string.
  String print(AppIconsConfig config);

  /// Generates a default YAML config template with inline documentation.
  String printDefault();
}

/// YAML implementation of [ConfigPrinter].
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
    if (config.icon.foregroundPadding != null) {
      buffer.writeln('  foreground_padding: ${config.icon.foregroundPadding}');
    }

    // Platform overrides
    for (final entry in config.icon.platformOverrides.entries) {
      buffer.writeln('  ${entry.key.name}:');
      if (entry.value.foregroundPath != null) {
        buffer.writeln('    foreground: ${entry.value.foregroundPath}');
      }
      if (entry.value.background != null) {
        final bgValue = _backgroundToString(entry.value.background!);
        buffer.writeln('    background: $bgValue');
      }
      if (entry.value.foregroundPadding != null) {
        buffer.writeln('    foreground_padding: ${entry.value.foregroundPadding}');
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

    // Flavors section
    if (config.flavors.isNotEmpty) {
      buffer.write(FlavorPrinter.printFlavors(
        config.flavors,
        backgroundToString: _backgroundToString,
      ));
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
# Docs: https://github.com/poundingwater/flutter-app-icons-generator

# Icon Configuration (required)
# Use `all_platforms` for a single image, or `foreground` + `background` for adaptive mode.
# Minimum size: 1024x1024px | Formats: PNG, JPEG
icon:
  # all_platforms: assets/icon.png
  foreground: assets/icon_foreground.png
  background: "#FFFFFF"  # hex color or image path

  # Foreground inset as fraction (0.0–0.5) or percentage. Default: ~0.167
  # foreground_padding: 0.167

  # Platform-specific overrides (optional)
  # ios:
  #   foreground: assets/ios_foreground.png
  #   background: "#FFFFFF"
  #   foreground_padding: 0.1

# Splash Screen (optional)
# splash:
#   image: assets/splash.png
#   background_color: "#FFFFFF"
${FlavorPrinter.printDefaultExample()}
# Target Platforms (defaults to android and ios)
# Supported: android, ios, macos, web, linux, windows
platforms:
  - android
  - ios
  # - macos
  # - web
  # - linux
  # - windows
''';
  }

  /// Converts [BackgroundConfig] to its YAML string value.
  String _backgroundToString(BackgroundConfig background) {
    return switch (background) {
      BackgroundColor(hexColor: final color) => '"$color"',
      BackgroundImage(imagePath: final path) => path,
    };
  }

  /// Compares two sets for equality.
  static bool _setEquals<T>(Set<T> a, Set<T> b) =>
      a.length == b.length && a.containsAll(b);
}
