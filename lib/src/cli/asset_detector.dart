import 'dart:io' hide Platform;

import 'package:flutter_app_icons_generator/src/config/config_model.dart';
import 'package:flutter_app_icons_generator/src/shared/constants.dart';

/// Detects existing generated assets for configured platforms.
///
/// Used to prompt users before overwriting previously generated files.
class AssetDetector {
  /// Detects existing generated assets for all configured platforms.
  ///
  /// Returns a list of human-readable descriptions of found assets.
  List<String> detect(AppIconsConfig config, String projectRoot) {
    final detected = <String>[];

    for (final platform in config.platforms) {
      final supportsFlavors = platform == Platform.android ||
          platform == Platform.ios ||
          platform == Platform.macos;

      if (config.flavors.isNotEmpty && supportsFlavors) {
        for (final flavorName in config.flavors.keys) {
          detected.addAll(_detectPlatformAssets(platform, projectRoot, flavorName));
        }
      } else {
        detected.addAll(_detectPlatformAssets(platform, projectRoot, null));
      }
    }

    return detected;
  }

  /// Detects existing generated assets for a specific platform.
  List<String> _detectPlatformAssets(
      Platform platform, String projectRoot, String? flavorName) {
    final detected = <String>[];

    switch (platform) {
      case Platform.android:
        final resDir =
            '$projectRoot/android/app/src/${flavorName ?? "main"}/res';
        final mipmapDir = Directory('$resDir/mipmap-hdpi');
        if (mipmapDir.existsSync()) {
          final icLauncher = File('$resDir/mipmap-hdpi/ic_launcher.png');
          if (icLauncher.existsSync()) {
            final label = flavorName != null
                ? 'Android [$flavorName] mipmap icons'
                : 'Android mipmap icons';
            detected.add(label);
          }
        }

      case Platform.ios:
        final iconName = flavorName != null ? 'AppIcon-$flavorName' : 'AppIcon';
        final assetDir =
            '$projectRoot/ios/Runner/Assets.xcassets/$iconName.appiconset';
        final iconFile = File('$assetDir/app_icon_1024.png');
        if (iconFile.existsSync()) {
          final label = flavorName != null
              ? 'iOS [$flavorName] AppIcon ($iconName.appiconset)'
              : 'iOS AppIcon (AppIcon.appiconset)';
          detected.add(label);
        }

      case Platform.macos:
        final iconName = flavorName != null ? 'AppIcon-$flavorName' : 'AppIcon';
        final appiconsetDir =
            '$projectRoot/macos/Runner/Assets.xcassets/$iconName.appiconset';
        final appiconsetPng = File('$appiconsetDir/app_icon_16x16.png');
        if (appiconsetPng.existsSync()) {
          final label = flavorName != null
              ? 'macOS [$flavorName] AppIcon ($iconName.appiconset)'
              : 'macOS AppIcon ($iconName.appiconset)';
          detected.add(label);
        }
        if (flavorName == null) {
          final runnerDir = Directory('$projectRoot/macos/Runner');
          if (runnerDir.existsSync()) {
            final hasIcns = runnerDir
                .listSync(recursive: true)
                .whereType<File>()
                .any((f) => f.path.endsWith('.icns'));
            if (hasIcns) {
              detected.add(
                  'macOS legacy .icns icon (will be migrated to asset catalog)');
            }
          }
        }

      case Platform.web:
        final faviconFile = File('$projectRoot/web/favicon.ico');
        if (faviconFile.existsSync()) {
          detected.add('Web icons (favicon.ico, PWA icons)');
        }

      case Platform.linux:
        final linuxIcon = File('$projectRoot/linux/app_icon.png');
        if (linuxIcon.existsSync()) {
          detected.add('Linux icon (app_icon.png)');
        }

      case Platform.windows:
        final windowsIcon =
            File('$projectRoot/windows/runner/resources/app_icon.ico');
        if (windowsIcon.existsSync()) {
          detected.add('Windows icon (app_icon.ico)');
        }
    }

    return detected;
  }
}
