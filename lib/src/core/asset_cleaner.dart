import 'dart:io';

import 'package:flutter_app_icons/src/shared/constants.dart';

/// Abstract interface for removing stale assets before regeneration.
///
/// Ensures a clean state by deleting all existing icon and splash assets
/// for a given platform before new assets are generated.
abstract class AssetCleaner {
  /// Removes all existing icon and splash assets for [platform] within
  /// the Flutter project at [projectRoot].
  ///
  /// This ensures that stale or default assets do not persist alongside
  /// newly generated icons.
  Future<void> clean(Platform platform, String projectRoot);
}

/// Default implementation of [AssetCleaner] that removes platform-specific
/// icon and splash assets from the file system.
///
/// The cleaner is idempotent — it does not throw if files or directories
/// do not exist.
class DefaultAssetCleaner implements AssetCleaner {
  @override
  Future<void> clean(Platform platform, String projectRoot) async {
    switch (platform) {
      case Platform.android:
        _cleanAndroid(projectRoot);
      case Platform.ios:
        _cleanIos(projectRoot);
      case Platform.macos:
        _cleanMacos(projectRoot);
      case Platform.web:
        _cleanWeb(projectRoot);
      case Platform.linux:
        _cleanLinux(projectRoot);
      case Platform.windows:
        _cleanWindows(projectRoot);
    }
  }

  /// Deletes Android icon files from all density bucket directories.
  ///
  /// Removes:
  /// - `ic_launcher.png` from each mipmap density bucket
  /// - `ic_launcher_foreground.png` from each mipmap density bucket
  /// - `ic_launcher.xml` from `mipmap-anydpi-v26`
  void _cleanAndroid(String projectRoot) {
    final resDir = '$projectRoot/android/app/src/main/res';

    for (final bucketKey in AndroidSizes.densityBuckets.keys) {
      _deleteFileIfExists('$resDir/$bucketKey/ic_launcher.png');
      _deleteFileIfExists('$resDir/$bucketKey/ic_launcher_foreground.png');
    }

    _deleteFileIfExists('$resDir/mipmap-anydpi-v26/ic_launcher.xml');
  }

  /// Deletes all contents of the iOS AppIcon.appiconset directory,
  /// but preserves the directory itself.
  void _cleanIos(String projectRoot) {
    final appiconsetDir =
        '$projectRoot/ios/Runner/Assets.xcassets/AppIcon.appiconset';
    _deleteDirectoryContents(appiconsetDir);
  }

  /// Deletes all contents of the macOS AppIcon.appiconset directory,
  /// but preserves the directory itself.
  void _cleanMacos(String projectRoot) {
    final appiconsetDir =
        '$projectRoot/macos/Runner/Assets.xcassets/AppIcon.appiconset';
    _deleteDirectoryContents(appiconsetDir);
  }

  /// Deletes web icon assets including favicons and the icons directory.
  void _cleanWeb(String projectRoot) {
    _deleteFileIfExists('$projectRoot/web/favicon.png');
    _deleteFileIfExists('$projectRoot/web/favicon.ico');
    _deleteDirectoryIfExists('$projectRoot/web/icons');
  }

  /// Deletes the Linux app icon.
  void _cleanLinux(String projectRoot) {
    _deleteFileIfExists('$projectRoot/linux/app_icon.png');
  }

  /// Deletes the Windows app icon.
  void _cleanWindows(String projectRoot) {
    _deleteFileIfExists(
        '$projectRoot/windows/runner/resources/app_icon.ico');
  }

  /// Deletes a file if it exists. Does nothing otherwise.
  void _deleteFileIfExists(String path) {
    final file = File(path);
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  /// Deletes an entire directory recursively if it exists.
  void _deleteDirectoryIfExists(String path) {
    final directory = Directory(path);
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  }

  /// Deletes all contents (files and subdirectories) within a directory,
  /// but preserves the directory itself.
  void _deleteDirectoryContents(String path) {
    final directory = Directory(path);
    if (!directory.existsSync()) {
      return;
    }

    for (final entity in directory.listSync()) {
      if (entity is File) {
        entity.deleteSync();
      } else if (entity is Directory) {
        entity.deleteSync(recursive: true);
      }
    }
  }
}
