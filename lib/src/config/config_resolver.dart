import 'package:flutter_app_icons_generator/src/config/config_model.dart';
import 'package:flutter_app_icons_generator/src/shared/constants.dart';

/// Resolves effective icon configuration for a given platform by walking
/// down the hierarchy and taking the nearest fallback for each field.
///
/// Resolution order (per field):
///   platform_override.field → top-level icon.field → all_platforms (foreground only)
///
/// Each field is resolved independently, so a partial platform override
/// (e.g. only `foreground_padding`) inherits remaining values from above.
///
/// Note: Validation is handled by [ConfigValidator] — this class purely resolves.
class ConfigResolver {
  const ConfigResolver._();

  /// Resolves the effective [ResolvedIconConfig] for [platform] from [icon].
  static ResolvedIconConfig resolve(IconConfig icon, Platform platform) {
    final override = icon.platformOverrides[platform];

    return ResolvedIconConfig(
      foregroundPath: _resolveForeground(icon, override),
      background: _resolveBackground(icon, override),
      foregroundPadding: _resolvePadding(icon, override),
    );
  }

  /// Foreground: override → top-level foreground → all_platforms
  static String? _resolveForeground(
    IconConfig icon,
    PlatformIconConfig? override,
  ) {
    return override?.foregroundPath ?? icon.foregroundPath ?? icon.allPlatforms;
  }

  /// Background: override → top-level background → null
  static BackgroundConfig? _resolveBackground(
    IconConfig icon,
    PlatformIconConfig? override,
  ) {
    if (override == null) return icon.background;
    return override.background ?? icon.background;
  }

  /// Padding: override → top-level padding → null (use default)
  static double? _resolvePadding(
    IconConfig icon,
    PlatformIconConfig? override,
  ) {
    if (override == null) return icon.foregroundPadding;
    return override.foregroundPadding ?? icon.foregroundPadding;
  }
}
