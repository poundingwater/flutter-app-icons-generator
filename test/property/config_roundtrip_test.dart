// Feature: flutter-app-icons, Property 1: Configuration Round-Trip
//
// For any valid AppIconsConfig object, printing the config to YAML with
// the ConfigPrinter and then parsing the result with the ConfigParser
// SHALL produce a semantically equivalent AppIconsConfig.
//
// **Validates: Requirements 1.2, 1.3, 1.4, 1.5, 2.4**

import 'dart:io';

import 'package:glados/glados.dart';
import 'package:flutter_app_icons/src/config/config_model.dart';
import 'package:flutter_app_icons/src/config/config_printer.dart';
import 'package:flutter_app_icons/src/config/yaml_config_parser.dart';
import 'package:flutter_app_icons/src/shared/constants.dart';

/// Custom generators for the config domain types.
extension ConfigGenerators on Any {
  /// Generates a valid hex color string like "#A3F2B1".
  Generator<String> get hexColor {
    return simple(
      generate: (random, size) {
        final chars = '0123456789ABCDEF';
        final buffer = StringBuffer('#');
        for (var i = 0; i < 6; i++) {
          buffer.write(chars[random.nextInt(16)]);
        }
        return buffer.toString();
      },
      shrink: (input) sync* {
        // Shrink toward "#000000"
        if (input != '#000000') yield '#000000';
      },
    );
  }

  /// Generates a simple file path safe for YAML (alphanumeric + slashes/underscores/dots).
  Generator<String> get safePath {
    return simple(
      generate: (random, size) {
        final segments = <String>[];
        final segCount = random.nextInt(size.clamp(1, 4)) + 1;
        for (var i = 0; i < segCount; i++) {
          final len = random.nextInt(8) + 3;
          final chars = 'abcdefghijklmnopqrstuvwxyz0123456789_';
          final buffer = StringBuffer();
          // First char is always a letter
          buffer.write(chars[random.nextInt(26)]);
          for (var j = 1; j < len; j++) {
            buffer.write(chars[random.nextInt(chars.length)]);
          }
          segments.add(buffer.toString());
        }
        final path = '${segments.join("/")}.png';
        return path;
      },
      shrink: (input) sync* {
        if (input != 'a.png') yield 'a.png';
      },
    );
  }

  /// Generates a Platform value.
  Generator<Platform> get platform {
    return choose(Platform.values);
  }

  /// Generates a non-empty subset of Platform values.
  Generator<Set<Platform>> get platformSet {
    return simple(
      generate: (random, size) {
        final platforms = <Platform>{};
        // Always include at least one platform
        platforms.add(Platform.values[random.nextInt(Platform.values.length)]);
        // Randomly add more platforms
        for (final p in Platform.values) {
          if (random.nextBool()) {
            platforms.add(p);
          }
        }
        return platforms;
      },
      shrink: (input) sync* {
        // Shrink toward a single platform
        if (input.length > 1) {
          yield {input.first};
        }
      },
    );
  }

  /// Generates a BackgroundConfig (either color or image path).
  Generator<BackgroundConfig> get backgroundConfig {
    return either(
      hexColor.map((color) => BackgroundColor(color) as BackgroundConfig),
      safePath.map((path) => BackgroundImage(path) as BackgroundConfig),
    );
  }

  /// Generates a valid IconConfig.
  /// Either combined mode (imagePath set) or adaptive mode (foreground + background).
  Generator<IconConfig> get iconConfig {
    return either(
      // Combined image mode
      safePath.map(
        (path) => IconConfig(imagePath: path),
      ),
      // Adaptive mode (foreground + background)
      combine2(
        safePath,
        backgroundConfig,
        (String fg, BackgroundConfig bg) => IconConfig(
          foregroundPath: fg,
          background: bg,
        ),
      ),
    );
  }

  /// Generates an optional SplashConfig.
  Generator<SplashConfig?> get splashConfig {
    return either<SplashConfig?>(
      // No splash
      always(null),
      // Splash with image only
      safePath.map(
        (path) => SplashConfig(imagePath: path),
      ),
      // Splash with image and background color
      combine2(
        safePath,
        hexColor,
        (String path, String color) => SplashConfig(
          imagePath: path,
          backgroundColor: color,
        ),
      ),
    );
  }

  /// Generates a valid AppIconsConfig.
  Generator<AppIconsConfig> get appIconsConfig {
    return combine3(
      iconConfig,
      splashConfig,
      platformSet,
      (IconConfig icon, SplashConfig? splash, Set<Platform> platforms) =>
          AppIconsConfig(
        icon: icon,
        splash: splash,
        platforms: platforms,
      ),
    );
  }
}

void main() {
  group('Property 1: Configuration Round-Trip', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('config_roundtrip_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    Glados(any.appIconsConfig, ExploreConfig(numRuns: 100))
        .test('print then parse produces semantically equivalent config',
            (config) async {
      // Print the config to YAML
      final printer = YamlConfigPrinter();
      final yamlOutput = printer.print(config);

      // Write YAML to temp file
      final configFile = File('${tempDir.path}/flutter_app_icons.yml');
      configFile.writeAsStringSync(yamlOutput);

      // Parse the YAML back
      final parser = YamlConfigParser();
      final parsed = await parser.parse(tempDir.path);

      // Assert semantic equality
      expect(parsed.icon, equals(config.icon),
          reason: 'IconConfig should round-trip');
      expect(parsed.splash, equals(config.splash),
          reason: 'SplashConfig should round-trip');
      expect(parsed.platforms, equals(config.platforms),
          reason: 'Platforms should round-trip');
      expect(parsed, equals(config),
          reason: 'Full AppIconsConfig should round-trip');
    });
  });
}
