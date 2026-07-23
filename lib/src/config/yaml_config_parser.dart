import 'dart:io';

import 'package:yaml/yaml.dart';

import 'package:flutter_app_icons_generator/src/config/config_model.dart';
import 'package:flutter_app_icons_generator/src/config/config_parser.dart';
import 'package:flutter_app_icons_generator/src/flavors/flavor_parser.dart';
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
    // Determine if we have flavors. If flavors are present, root icon/splash
    // are only required if there's an unflavored platform, but for simplicity
    // we can parse them if they exist.
    IconConfig? iconConfig;
    try {
      iconConfig = _parseIconConfig(yaml);
    } catch (e) {
      // If flavors exist, we can ignore the missing root icon error.
      // But we need to ensure at least flavors exist.
    }

    final splashConfig = _parseSplashConfig(yaml);
    final platforms = _parsePlatforms(yaml);

    final flavors = FlavorParser.parseFlavors(
      yaml,
      parseIcon: _parseIconConfig,
      parseSplash: _parseSplashConfig,
    );

    if (iconConfig == null && flavors.isEmpty) {
      throw ConfigValidationException(['icon']);
    }

    // Default icon config if missing (only allowed when flavors are present
    // and all platforms support flavors)
    iconConfig ??= const IconConfig();

    return AppIconsConfig(
      icon: iconConfig,
      splash: splashConfig,
      flavors: flavors,
      platforms: platforms,
    );
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
    final foregroundPadding = _parsePadding(iconNode['foreground_padding']);

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
      final platformBgValue = platformNode['background'];
      final platformPadding = _parsePadding(platformNode['foreground_padding']);

      // At least one field must be specified for a platform override to be meaningful.
      if (platformForeground == null &&
          platformBgValue == null &&
          platformPadding == null) {
        throw ConfigParseException(
          '"icon.$platformKey" must specify at least one of: '
          'foreground, background, foreground_padding',
        );
      }

      BackgroundConfig? platformBackground;
      if (platformBgValue != null) {
        platformBackground = _parseBackground(platformBgValue);
      }

      final platform = Platform.values.firstWhere((p) => p.name == platformKey);
      platformOverrides[platform] = PlatformIconConfig(
        foregroundPath: platformForeground,
        background: platformBackground,
        foregroundPadding: platformPadding,
      );
    }

    return IconConfig(
      allPlatforms: allPlatforms,
      foregroundPath: foregroundPath,
      background: background,
      foregroundPadding: foregroundPadding,
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

  /// Parses an optional foreground_padding value.
  ///
  /// Accepts numeric values or percentage strings (e.g. "20%").
  /// Returns null if not provided.
  /// Range validation is handled by [ConfigValidator].
  double? _parsePadding(dynamic value) {
    if (value == null) return null;

    double parsed;
    final str = value.toString().trim();
    if (str.endsWith('%')) {
      parsed = double.parse(str.substring(0, str.length - 1)) / 100.0;
    } else {
      parsed = double.parse(str);
    }

    return parsed;
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
