import 'dart:io';

import 'package:yaml/yaml.dart';

import 'package:flutter_app_icons_generator/src/config/config_model.dart';
import 'package:flutter_app_icons_generator/src/config/config_parser.dart';
import 'package:flutter_app_icons_generator/src/shared/constants.dart';
import 'package:flutter_app_icons_generator/src/shared/exceptions.dart';

/// Default config file name looked up in the project root.
const String _configFileName = 'flutter_app_icons_generator.yml';

/// Platform names that can appear as keys under the `icon` section.
const Set<String> _platformKeys = {
  'android',
  'ios',
  'macos',
  'web',
  'linux',
  'windows',
};

/// Concrete implementation of [ConfigParser] that reads and validates
/// a `flutter_app_icons_generator.yml` file using the `yaml` package.
class YamlConfigParser implements ConfigParser {
  /// Creates a [YamlConfigParser].
  const YamlConfigParser();

  @override
  Future<AppIconsConfig> parse(String projectRoot) async {
    final configPath = '$projectRoot/$_configFileName';
    final file = File(configPath);

    if (!file.existsSync()) {
      throw ConfigNotFoundException(configPath);
    }

    final content = await file.readAsString();

    final YamlMap yaml;
    try {
      final parsed = loadYaml(content);
      if (parsed is! YamlMap) {
        throw ConfigParseException('Expected a YAML map at root level');
      }
      yaml = parsed;
    } on YamlException catch (e) {
      final line = e.span?.start.line;
      throw ConfigParseException(
        e.message,
        lineNumber: line != null ? line + 1 : null,
      );
    }

    return _buildConfig(yaml);
  }

  /// Constructs an [AppIconsConfig] from the parsed YAML map.
  AppIconsConfig _buildConfig(YamlMap yaml) {
    final iconConfig = _parseIconConfig(yaml);
    final splashConfig = _parseSplashConfig(yaml);
    final platforms = _parsePlatforms(yaml);

    final config = AppIconsConfig(
      icon: iconConfig,
      splash: splashConfig,
      platforms: platforms,
    );

    if (!config.isValid) {
      throw ConfigValidationException([
        'icon.all_platforms or icon.foreground',
      ]);
    }

    return config;
  }

  /// Parses the `icon` section of the YAML config.
  ///
  /// Supports:
  /// - `all_platforms` — single image fallback
  /// - `foreground` + optional `background` — adaptive layers
  /// - Platform keys (android, ios, etc.) — platform-specific overrides
  /// - Legacy `image` key — treated as `all_platforms` for backward compat
  IconConfig _parseIconConfig(YamlMap yaml) {
    final iconNode = yaml['icon'];
    if (iconNode == null) {
      throw ConfigValidationException(['icon']);
    }
    if (iconNode is! YamlMap) {
      throw ConfigParseException('Expected "icon" to be a map');
    }

    // Support legacy `image` key as alias for `all_platforms`.
    final allPlatforms =
        (iconNode['all_platforms'] ?? iconNode['image']) as String?;
    final foregroundPath = iconNode['foreground'] as String?;
    final backgroundValue = iconNode['background'];

    BackgroundConfig? background;
    if (backgroundValue != null) {
      background = _parseBackground(backgroundValue);
    }

    // Parse platform-specific overrides.
    final platformOverrides = <Platform, PlatformIconConfig>{};
    for (final platformKey in _platformKeys) {
      final platformNode = iconNode[platformKey];
      if (platformNode == null) continue;

      if (platformNode is! YamlMap) {
        throw ConfigParseException(
          'Expected "icon.$platformKey" to be a map',
        );
      }

      final platformForeground = platformNode['foreground'] as String?;
      if (platformForeground == null) {
        throw ConfigValidationException(['icon.$platformKey.foreground']);
      }

      final platformBgValue = platformNode['background'];
      BackgroundConfig? platformBackground;
      if (platformBgValue != null) {
        platformBackground = _parseBackground(platformBgValue);
      }

      final platform = Platform.values.firstWhere((p) => p.name == platformKey);
      platformOverrides[platform] = PlatformIconConfig(
        foregroundPath: platformForeground,
        background: platformBackground,
      );
    }

    return IconConfig(
      allPlatforms: allPlatforms,
      foregroundPath: foregroundPath,
      background: background,
      platformOverrides: platformOverrides,
    );
  }

  /// Parses a background value — either a hex color string or image path.
  BackgroundConfig _parseBackground(dynamic value) {
    final bgStr = value.toString();
    if (bgStr.startsWith('#')) {
      return BackgroundColor(bgStr);
    } else {
      return BackgroundImage(bgStr);
    }
  }

  /// Parses the optional `splash` section of the YAML config.
  SplashConfig? _parseSplashConfig(YamlMap yaml) {
    final splashNode = yaml['splash'];
    if (splashNode == null) return null;
    if (splashNode is! YamlMap) {
      throw ConfigParseException('Expected "splash" to be a map');
    }

    final imagePath = splashNode['image'] as String?;
    if (imagePath == null) {
      throw ConfigValidationException(['splash.image']);
    }

    final backgroundColor = splashNode['background_color'] as String?;

    return SplashConfig(
      imagePath: imagePath,
      backgroundColor: backgroundColor,
    );
  }

  /// Parses the optional `platforms` list.
  /// Defaults to android and ios if omitted.
  Set<Platform> _parsePlatforms(YamlMap yaml) {
    final platformsNode = yaml['platforms'];
    if (platformsNode == null) {
      return const {Platform.android, Platform.ios};
    }

    if (platformsNode is! YamlList) {
      throw ConfigParseException('Expected "platforms" to be a list');
    }

    final platforms = <Platform>{};
    for (final entry in platformsNode) {
      final name = entry.toString().toLowerCase();
      final matched = Platform.values.where((p) => p.name == name);
      if (matched.isEmpty) {
        throw ConfigParseException(
          'Unknown platform "$name". '
          'Supported: ${Platform.values.map((p) => p.name).join(", ")}',
        );
      }
      platforms.add(matched.first);
    }

    return platforms;
  }
}
