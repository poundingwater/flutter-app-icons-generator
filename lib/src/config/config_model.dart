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
    this.platformOverrides = const {},
  });

  /// Single source image for all platforms (pre-composited).
  final String? allPlatforms;

  /// Top-level foreground layer path.
  final String? foregroundPath;

  /// Top-level background — either an image path or hex color.
  final BackgroundConfig? background;

  /// Platform-specific overrides.
  final Map<Platform, PlatformIconConfig> platformOverrides;

  /// Returns true if this has adaptive layers at the top level.
  bool get isAdaptive => foregroundPath != null && background != null;

  /// Resolves the effective icon config for a given [platform].
  ///
  /// For platforms that need transparency (Windows), the package will
  /// use foreground-only. For others, it composites foreground onto background.
  ResolvedIconConfig resolve(Platform platform) {
    // Check platform-specific override first.
    final override = platformOverrides[platform];
    if (override != null) {
      return ResolvedIconConfig(
        foregroundPath: override.foregroundPath,
        background: override.background,
      );
    }

    // Fall back to top-level foreground/background.
    if (foregroundPath != null) {
      return ResolvedIconConfig(
        foregroundPath: foregroundPath,
        background: background,
      );
    }

    // Final fallback: all_platforms treated as foreground with no background.
    return ResolvedIconConfig(
      foregroundPath: allPlatforms,
      background: null,
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
        _mapEquals(platformOverrides, other.platformOverrides);
  }

  @override
  int get hashCode =>
      Object.hash(allPlatforms, foregroundPath, background, platformOverrides);

  @override
  String toString() =>
      'IconConfig(allPlatforms: $allPlatforms, foregroundPath: $foregroundPath, '
      'background: $background, platformOverrides: $platformOverrides)';
}

/// Platform-specific icon configuration override.
class PlatformIconConfig {
  const PlatformIconConfig({
    required this.foregroundPath,
    this.background,
  });

  /// Platform-specific foreground image path.
  final String foregroundPath;

  /// Platform-specific background (optional).
  /// If null, foreground is used as-is (transparency preserved).
  final BackgroundConfig? background;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PlatformIconConfig) return false;
    return foregroundPath == other.foregroundPath &&
        background == other.background;
  }

  @override
  int get hashCode => Object.hash(foregroundPath, background);

  @override
  String toString() =>
      'PlatformIconConfig(foregroundPath: $foregroundPath, background: $background)';
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
  });

  /// Path to the foreground/source image.
  final String? foregroundPath;

  /// Background config. Null means use foreground only (transparent).
  final BackgroundConfig? background;

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
