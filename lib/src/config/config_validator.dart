import 'package:flutter_app_icons_generator/src/config/config_model.dart';
import 'package:flutter_app_icons_generator/src/shared/constants.dart';
import 'package:flutter_app_icons_generator/src/shared/exceptions.dart';

/// Centralized semantic validation for [AppIconsConfig].
///
/// Separates concerns: the YAML parser handles structural/type checks,
/// while this class handles cross-field logic, range checks, and
/// business-rule validation on the fully-parsed config.
///
/// Call [validate] after parsing to get a list of all errors at once
/// rather than failing on the first one.
class ConfigValidator {
  const ConfigValidator._();

  /// Validates the entire [config] and throws [ConfigValidationException]
  /// if any errors are found.
  ///
  /// Collects all errors before throwing so the user can fix them in one pass.
  static void validate(AppIconsConfig config) {
    final errors = <String>[];

    _validateIconSources(config, errors);
    _validatePadding(config.icon, errors);
    _validatePlatformOverrides(config.icon, errors);
    _validateFlavors(config, errors);
    _validateNonFlavorPlatforms(config, errors);

    if (errors.isNotEmpty) {
      throw ConfigValidationException(errors);
    }
  }

  /// Ensures at least one icon source is configured (when no flavors).
  static void _validateIconSources(
    AppIconsConfig config,
    List<String> errors,
  ) {
    if (config.flavors.isNotEmpty) return;

    if (!config.isValid) {
      errors.add(
        'icon.all_platforms or icon.foreground is required',
      );
    }
  }

  /// Validates top-level foreground_padding range.
  static void _validatePadding(IconConfig icon, List<String> errors) {
    final padding = icon.foregroundPadding;
    if (padding == null) return;

    if (padding < 0.0 || padding >= 0.5) {
      errors.add(
        'icon.foreground_padding must be >= 0.0 and < 0.5, got $padding',
      );
    }
  }

  /// Validates each platform override's padding range.
  static void _validatePlatformOverrides(
    IconConfig icon,
    List<String> errors,
  ) {
    for (final entry in icon.platformOverrides.entries) {
      final platform = entry.key;
      final override = entry.value;

      final padding = override.foregroundPadding;
      if (padding != null && (padding < 0.0 || padding >= 0.5)) {
        errors.add(
          'icon.${platform.name}.foreground_padding must be >= 0.0 and < 0.5, '
          'got $padding',
        );
      }
    }
  }

  /// Validates flavor icon configs (sources + padding).
  static void _validateFlavors(AppIconsConfig config, List<String> errors) {
    for (final entry in config.flavors.entries) {
      final name = entry.key;
      final flavor = entry.value;

      if (!flavor.isValid) {
        errors.add(
          'flavors.$name.icon.all_platforms or '
          'flavors.$name.icon.foreground is required',
        );
      }

      final padding = flavor.icon.foregroundPadding;
      if (padding != null && (padding < 0.0 || padding >= 0.5)) {
        errors.add(
          'flavors.$name.icon.foreground_padding must be >= 0.0 and < 0.5, '
          'got $padding',
        );
      }

      for (final pEntry in flavor.icon.platformOverrides.entries) {
        final pPadding = pEntry.value.foregroundPadding;
        if (pPadding != null && (pPadding < 0.0 || pPadding >= 0.5)) {
          errors.add(
            'flavors.$name.icon.${pEntry.key.name}.foreground_padding '
            'must be >= 0.0 and < 0.5, got $pPadding',
          );
        }
      }
    }
  }

  /// When flavors are configured, non-flavor platforms (web, linux, windows)
  /// still need a default icon source in the top-level config.
  static void _validateNonFlavorPlatforms(
    AppIconsConfig config,
    List<String> errors,
  ) {
    if (config.flavors.isEmpty) return;

    final nonFlavorPlatforms = config.platforms.where(
      (p) => p != Platform.android && p != Platform.ios && p != Platform.macos,
    );

    if (nonFlavorPlatforms.isEmpty) return;

    final hasDefaultIcon =
        config.icon.allPlatforms != null || config.icon.foregroundPath != null;

    if (!hasDefaultIcon) {
      errors.add(
        'icon is required for platforms that do not support flavors: '
        '${nonFlavorPlatforms.map((p) => p.name).join(", ")}',
      );
    }
  }
}
