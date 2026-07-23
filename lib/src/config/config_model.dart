import 'package:flutter_app_icons_generator/src/flavors/flavor_model.dart';
import 'package:flutter_app_icons_generator/src/shared/constants.dart';

/// Root configuration model parsed from flutter_app_icons_generator.yml.
class AppIconsConfig {
  const AppIconsConfig({
    required this.icon,
    this.splash,
    this.flavors = const {},
    this.platforms = const {
      Platform.android,
      Platform.ios,
    },
  });

  /// Icon configuration (required: at least one source).
  final IconConfig icon;

  /// Splash screen configuration (optional).
  final SplashConfig? splash;

  /// Map of flavor name to its configuration.
  final Map<String, FlavorConfig> flavors;

  /// Target platforms. Defaults to android and ios.
  final Set<Platform> platforms;

  /// Validates that the config has sufficient icon sources.
  ///
  /// Valid when:
  /// - [IconConfig.allPlatforms] is set, OR
  /// - [IconConfig.foregroundPath] is set (background is optional)
  bool get isValid => icon.allPlatforms != null || icon.foregroundPath != null;

  /// Creates a copy of this config with the given fields replaced.
  AppIconsConfig copyWith({
    IconConfig? icon,
    SplashConfig? splash,
    Map<String, FlavorConfig>? flavors,
    Set<Platform>? platforms,
  }) {
    return AppIconsConfig(
      icon: icon ?? this.icon,
      splash: splash ?? this.splash,
      flavors: flavors ?? this.flavors,
      platforms: platforms ?? this.platforms,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AppIconsConfig) return false;
    return icon == other.icon &&
        splash == other.splash &&
        _mapEquals(flavors, other.flavors) &&
        _setEquals(platforms, other.platforms);
  }

  @override
  int get hashCode =>
      Object.hash(icon, splash, _mapHash(flavors), Object.hashAllUnordered(platforms));

  @override
  String toString() =>
      'AppIconsConfig(icon: $icon, splash: $splash, flavors: $flavors, platforms: $platforms)';
}

/// Icon source configuration.
///
/// Supports three modes:
/// 1. `all_platforms` — single image used everywhere (simplest)
/// 2. `foreground` + `background` — adaptive layers, composited per platform
/// 3. Platform-specific overrides — fine-grained control
///
/// Resolution order per platform:
/// 1. Platform-specific override (if defined)
/// 2. Top-level foreground/background
/// 3. all_platforms fallback
class IconConfig {
  const IconConfig({
    this.allPlatforms,
    this.foregroundPath,
    this.background,
    this.foregroundPadding,
    this.platformOverrides = const {},
  });

  /// Single source image for all platforms (pre-composited).
  final String? allPlatforms;

  /// Top-level foreground layer path.
  final String? foregroundPath;

  /// Top-level background — either an image path or hex color.
  final BackgroundConfig? background;

  /// Foreground padding as a fraction (0.0–1.0) of the canvas size.
  ///
  /// Controls how much the foreground is inset from the edges when
  /// composited onto a background. Default is ~0.167 (Android's 72/108
  /// safe zone ratio = 16.7% padding per side).
  ///
  /// - `0.0` — foreground fills the entire canvas (no padding)
  /// - `0.5` — foreground is 0% of canvas (invisible, extreme)
  /// - Typical values: 0.1–0.25
  final double? foregroundPadding;

  /// Platform-specific overrides.
  final Map<Platform, PlatformIconConfig> platformOverrides;

  /// Returns true if this has adaptive layers at the top level.
  bool get isAdaptive => foregroundPath != null && background != null;

  /// Resolves the effective icon config for a given [platform].
  ///
  /// Delegates to [ConfigResolver] for intelligent hierarchical fallback.
  /// Kept for backward compatibility; prefer [ConfigResolver.resolve] directly.
  ResolvedIconConfig resolve(Platform platform) {
    // Inline import would be circular; replicate the cascade logic here
    // for backward compat. New code should use ConfigResolver.resolve().
    final override = platformOverrides[platform];

    final resolvedForeground =
        override?.foregroundPath ?? foregroundPath ?? allPlatforms;
    final resolvedBackground =
        override != null ? (override.background ?? background) : background;
    final resolvedPadding = override != null
        ? (override.foregroundPadding ?? foregroundPadding)
        : foregroundPadding;

    return ResolvedIconConfig(
      foregroundPath: resolvedForeground,
      background: resolvedBackground,
      foregroundPadding: resolvedPadding,
    );
  }

  /// Legacy compatibility: returns imagePath equivalent.
  /// Used by generators that expect the old IconConfig interface.
  String? get imagePath => allPlatforms;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! IconConfig) return false;
    return allPlatforms == other.allPlatforms &&
        foregroundPath == other.foregroundPath &&
        background == other.background &&
        foregroundPadding == other.foregroundPadding &&
        _mapEquals(platformOverrides, other.platformOverrides);
  }

  @override
  int get hashCode =>
      Object.hash(allPlatforms, foregroundPath, background, foregroundPadding, platformOverrides);

  @override
  String toString() =>
      'IconConfig(allPlatforms: $allPlatforms, foregroundPath: $foregroundPath, '
      'background: $background, platformOverrides: $platformOverrides)';
}

/// Platform-specific icon configuration override.
///
/// All fields are optional — unset fields inherit from the top-level
/// [IconConfig] via [ConfigResolver.resolve].
class PlatformIconConfig {
  const PlatformIconConfig({
    this.foregroundPath,
    this.background,
    this.foregroundPadding,
  });

  /// Platform-specific foreground image path.
  /// Null means inherit from the top-level config.
  final String? foregroundPath;

  /// Platform-specific background (optional).
  /// If null, foreground is used as-is (transparency preserved).
  final BackgroundConfig? background;

  /// Platform-specific foreground padding override (0.0–1.0).
  /// If null, falls back to the top-level [IconConfig.foregroundPadding].
  final double? foregroundPadding;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PlatformIconConfig) return false;
    return foregroundPath == other.foregroundPath &&
        background == other.background &&
        foregroundPadding == other.foregroundPadding;
  }

  @override
  int get hashCode => Object.hash(foregroundPath, background, foregroundPadding);

  @override
  String toString() =>
      'PlatformIconConfig(foregroundPath: $foregroundPath, background: $background, foregroundPadding: $foregroundPadding)';
}

/// Resolved icon configuration for a specific platform.
///
/// This is what generators receive after resolution:
/// - If [background] is non-null, composite foreground onto background.
/// - If [background] is null, use foreground as-is (preserve transparency).
class ResolvedIconConfig {
  const ResolvedIconConfig({
    required this.foregroundPath,
    this.background,
    this.foregroundPadding,
  });

  /// Path to the foreground/source image.
  final String? foregroundPath;

  /// Background config. Null means use foreground only (transparent).
  final BackgroundConfig? background;

  /// Foreground padding fraction (0.0–1.0). Null means use the default
  /// 72/108 ratio (~0.167 per side).
  final double? foregroundPadding;

  /// The effective content scale factor (1.0 - 2*padding).
  /// E.g., padding 0.167 → content occupies 66.6% of canvas.
  double get contentScale {
    final padding = foregroundPadding ?? (1.0 - 72.0 / 108.0);
    return (1.0 - 2.0 * padding).clamp(0.01, 1.0);
  }

  /// Whether this resolved config has a background to composite onto.
  bool get hasBackground => background != null;

  /// Whether this is an adaptive icon (foreground + background).
  bool get isAdaptive => foregroundPath != null && background != null;
}

/// Background configuration for adaptive icons.
sealed class BackgroundConfig {
  const BackgroundConfig();
}

/// Background specified as an image file path.
class BackgroundImage extends BackgroundConfig {
  const BackgroundImage(this.imagePath);

  /// Path to the background image file.
  final String imagePath;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BackgroundImage) return false;
    return imagePath == other.imagePath;
  }

  @override
  int get hashCode => imagePath.hashCode;

  @override
  String toString() => 'BackgroundImage(imagePath: $imagePath)';
}

/// Background specified as a solid hex color.
class BackgroundColor extends BackgroundConfig {
  const BackgroundColor(this.hexColor);

  /// Hex color string, e.g. "#FFFFFF".
  final String hexColor;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BackgroundColor) return false;
    return hexColor == other.hexColor;
  }

  @override
  int get hashCode => hexColor.hashCode;

  @override
  String toString() => 'BackgroundColor(hexColor: $hexColor)';
}

/// Splash screen configuration.
class SplashConfig {
  const SplashConfig({
    required this.imagePath,
    this.backgroundColor,
  });

  /// Path to the splash source image.
  final String imagePath;

  /// Optional background color for the splash screen.
  final String? backgroundColor;

  /// Creates a copy of this config with the given fields replaced.
  SplashConfig copyWith({
    String? imagePath,
    String? backgroundColor,
  }) {
    return SplashConfig(
      imagePath: imagePath ?? this.imagePath,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SplashConfig) return false;
    return imagePath == other.imagePath &&
        backgroundColor == other.backgroundColor;
  }

  @override
  int get hashCode => Object.hash(imagePath, backgroundColor);

  @override
  String toString() =>
      'SplashConfig(imagePath: $imagePath, backgroundColor: $backgroundColor)';
}

/// Represents a validated and loaded source image with metadata.
///
/// Used after image loading and validation to carry dimensions and format
/// information through the processing pipeline.
class SourceImage {
  const SourceImage({
    required this.path,
    required this.width,
    required this.height,
    required this.format,
  });

  /// Original file path of the source image.
  final String path;

  /// Image width in pixels.
  final int width;

  /// Image height in pixels.
  final int height;

  /// Detected image format (e.g. "png", "jpeg").
  final String format;

  /// Whether the image meets the minimum size requirement (1024x1024).
  bool get meetsMinimumSize => width >= 1024 && height >= 1024;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SourceImage) return false;
    return path == other.path &&
        width == other.width &&
        height == other.height &&
        format == other.format;
  }

  @override
  int get hashCode => Object.hash(path, width, height, format);

  @override
  String toString() =>
      'SourceImage(path: $path, width: $width, height: $height, format: $format)';
}

/// Helper to compare two sets for equality.
bool _setEquals<T>(Set<T> a, Set<T> b) {
  if (a.length != b.length) return false;
  return a.containsAll(b);
}

/// Helper to compare two maps for equality.
bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key) || a[key] != b[key]) return false;
  }
  return true;
}

/// Helper to hash a map.
int _mapHash(Map<dynamic, dynamic> map) {
  return Object.hashAllUnordered(
    map.entries.map((e) => Object.hash(e.key, e.value)),
  );
}
