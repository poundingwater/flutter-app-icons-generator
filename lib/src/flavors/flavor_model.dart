import 'package:flutter_app_icons_generator/src/config/config_model.dart';

/// Configuration for a specific app flavor.
class FlavorConfig {
  const FlavorConfig({
    required this.icon,
    required this.bundleIdentifier,
    this.splash,
  });

  /// Icon configuration for this flavor.
  final IconConfig icon;

  /// The bundle identifier / application ID for this flavor.
  ///
  /// Used as `applicationId` in Android `productFlavors` and
  /// `PRODUCT_BUNDLE_IDENTIFIER` in iOS build configurations.
  final String bundleIdentifier;

  /// Optional splash configuration for this flavor.
  final SplashConfig? splash;

  /// Validates that the flavor config has sufficient icon sources.
  bool get isValid => icon.allPlatforms != null || icon.foregroundPath != null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FlavorConfig) return false;
    return icon == other.icon &&
        bundleIdentifier == other.bundleIdentifier &&
        splash == other.splash;
  }

  @override
  int get hashCode => Object.hash(icon, bundleIdentifier, splash);

  @override
  String toString() =>
      'FlavorConfig(icon: $icon, bundleIdentifier: $bundleIdentifier, splash: $splash)';
}
