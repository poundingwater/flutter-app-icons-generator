import 'package:yaml/yaml.dart';

import 'package:flutter_app_icons_generator/src/config/config_model.dart';
import 'package:flutter_app_icons_generator/src/flavors/flavor_model.dart';
import 'package:flutter_app_icons_generator/src/shared/exceptions.dart';

/// Parser for flavor configurations.
class FlavorParser {
  /// Parses the `flavors` section of the YAML config.
  static Map<String, FlavorConfig> parseFlavors(
    YamlMap yaml, {
    required IconConfig Function(YamlMap) parseIcon,
    required SplashConfig? Function(YamlMap) parseSplash,
  }) {
    final flavorsNode = yaml['flavors'];
    if (flavorsNode == null) return const {};

    if (flavorsNode is! YamlMap) {
      throw ConfigParseException('Expected "flavors" to be a map');
    }

    final flavors = <String, FlavorConfig>{};
    final bundleIds = <String, String>{}; // bundleId -> flavorName

    for (final entry in flavorsNode.entries) {
      final flavorName = entry.key.toString();
      final flavorData = entry.value;

      if (flavorData is! YamlMap) {
        throw ConfigParseException('Expected flavor "$flavorName" to be a map');
      }

      // Check if 'icon' is provided
      if (flavorData['icon'] == null) {
        throw ConfigValidationException(['flavors.$flavorName.icon']);
      }

      // Check if 'bundle_identifier' is provided
      final bundleIdentifier = flavorData['bundle_identifier'] as String?;
      if (bundleIdentifier == null || bundleIdentifier.trim().isEmpty) {
        throw ConfigValidationException(
            ['flavors.$flavorName.bundle_identifier']);
      }

      // Check for duplicate bundle identifiers
      if (bundleIds.containsKey(bundleIdentifier)) {
        throw ConfigParseException(
          'Duplicate bundle_identifier "$bundleIdentifier" found in flavors '
          '"${bundleIds[bundleIdentifier]}" and "$flavorName". '
          'Each flavor must have a unique bundle_identifier.',
        );
      }
      bundleIds[bundleIdentifier] = flavorName;

      final iconConfig = parseIcon(flavorData);
      final splashConfig = parseSplash(flavorData);

      final flavorConfig = FlavorConfig(
        icon: iconConfig,
        bundleIdentifier: bundleIdentifier,
        splash: splashConfig,
      );

      if (!flavorConfig.isValid) {
        throw ConfigValidationException([
          'flavors.$flavorName.icon.all_platforms or flavors.$flavorName.icon.foreground'
        ]);
      }

      flavors[flavorName] = flavorConfig;
    }

    return flavors;
  }
}
