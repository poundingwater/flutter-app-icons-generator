import 'package:flutter_app_icons/src/config/config_model.dart';
import 'package:flutter_app_icons/src/shared/constants.dart';

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
  /// All supported platforms, used to determine if the platforms field
  /// should be omitted (when all are selected).
  static const Set<Platform> _allPlatforms = {
    Platform.android,
    Platform.ios,
    Platform.macos,
    Platform.web,
    Platform.linux,
    Platform.windows,
  };

  @override
  String print(AppIconsConfig config) {
    final buffer = StringBuffer();

    // Icon section (required)
    buffer.writeln('icon:');
    if (config.icon.imagePath != null) {
      buffer.writeln('  image: ${config.icon.imagePath}');
    }
    if (config.icon.foregroundPath != null) {
      buffer.writeln('  foreground: ${config.icon.foregroundPath}');
    }
    if (config.icon.background != null) {
      final bgValue = _backgroundToString(config.icon.background!);
      buffer.writeln('  background: $bgValue');
    }

    // Splash section (optional, only if present)
    if (config.splash != null) {
      buffer.writeln('');
      buffer.writeln('splash:');
      buffer.writeln('  image: ${config.splash!.imagePath}');
      if (config.splash!.backgroundColor != null) {
        buffer.writeln(
            '  background_color: "${config.splash!.backgroundColor}"');
      }
    }

    // Platforms section (only if not the default set of all platforms)
    if (!_setEquals(config.platforms, _allPlatforms)) {
      buffer.writeln('');
      buffer.writeln('platforms:');
      // Sort for deterministic output
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
    return '''# flutter_app_icons.yml
# Configuration for flutter_app_icons icon and splash screen generator.
#
# For documentation, see: https://github.com/user/flutter_app_icons

# Icon configuration (required)
# Use either 'image' for a single source, or 'foreground'/'background' for adaptive icons
icon:
  # Single source image (must be at least 1024x1024, PNG or JPEG)
  image: assets/icon.png

  # OR use adaptive icon layers:
  # foreground: assets/foreground.png
  # background: "#4CAF50"  # hex color or image path

# Splash screen configuration (optional)
# splash:
#   image: assets/splash.png
#   background_color: "#FFFFFF"

# Target platforms (optional, defaults to all)
# platforms:
#   - android
#   - ios
#   - macos
#   - web
#   - linux
#   - windows
''';
  }

  /// Converts a [BackgroundConfig] to its YAML string representation.
  ///
  /// For [BackgroundColor], outputs a quoted hex string (e.g., `"#4CAF50"`).
  /// For [BackgroundImage], outputs the image path unquoted.
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
