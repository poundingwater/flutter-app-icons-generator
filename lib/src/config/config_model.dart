import 'package:flutter_app_icons_generator/src/shared/constants.dart';

/// Root configuration model parsed from flutter_app_icons_generator.yml.
class AppIconsConfig {
  const AppIconsConfig({
    required this.icon,
    this.splash,
    this.platforms = const {
      Platform.android,
      Platform.ios,
      Platform.macos,
      Platform.web,
      Platform.linux,
      Platform.windows,
    },
  });

  /// Icon configuration (required: at least one source).
  final IconConfig icon;

  /// Splash screen configuration (optional).
  final SplashConfig? splash;

  /// Target platforms. Defaults to all supported platforms.
  final Set<Platform> platforms;

  /// Validates that at least one icon source is provided.
  ///
  /// Returns `true` if the config has either a combined [IconConfig.imagePath]
  /// or both [IconConfig.foregroundPath] and [IconConfig.background] set.
  bool get isValid =>
      icon.imagePath != null ||
      (icon.foregroundPath != null && icon.background != null);

  /// Creates a copy of this config with the given fields replaced.
  AppIconsConfig copyWith({
    IconConfig? icon,
    SplashConfig? splash,
    Set<Platform>? platforms,
  }) {
    return AppIconsConfig(
      icon: icon ?? this.icon,
      splash: splash ?? this.splash,
      platforms: platforms ?? this.platforms,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AppIconsConfig) return false;
    return icon == other.icon &&
        splash == other.splash &&
        _setEquals(platforms, other.platforms);
  }

  @override
  int get hashCode =>
      Object.hash(icon, splash, Object.hashAllUnordered(platforms));

  @override
  String toString() =>
      'AppIconsConfig(icon: $icon, splash: $splash, platforms: $platforms)';
}

/// Icon source configuration.
class IconConfig {
  const IconConfig({
    this.imagePath,
    this.foregroundPath,
    this.background,
  });

  /// Combined image path (used when no separate layers).
  final String? imagePath;

  /// Foreground layer path (for adaptive icons).
  final String? foregroundPath;

  /// Background layer — either an image path or hex color.
  final BackgroundConfig? background;

  /// Returns true if this is an adaptive icon configuration.
  bool get isAdaptive => foregroundPath != null && background != null;

  /// Creates a copy of this config with the given fields replaced.
  IconConfig copyWith({
    String? imagePath,
    String? foregroundPath,
    BackgroundConfig? background,
  }) {
    return IconConfig(
      imagePath: imagePath ?? this.imagePath,
      foregroundPath: foregroundPath ?? this.foregroundPath,
      background: background ?? this.background,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! IconConfig) return false;
    return imagePath == other.imagePath &&
        foregroundPath == other.foregroundPath &&
        background == other.background;
  }

  @override
  int get hashCode => Object.hash(imagePath, foregroundPath, background);

  @override
  String toString() =>
      'IconConfig(imagePath: $imagePath, foregroundPath: $foregroundPath, background: $background)';
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
