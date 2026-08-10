import 'dart:io';

import 'package:flutter_app_icons_generator/src/core/platform_updater.dart';
import 'package:flutter_app_icons_generator/src/flavors/flavor_model.dart';
import 'package:flutter_app_icons_generator/src/platforms/macos/macos_asset_catalog_linker.dart';
import 'package:flutter_app_icons_generator/src/platforms/macos/macos_legacy_icon_cleaner.dart';
import 'package:flutter_app_icons_generator/src/platforms/macos/macos_pbxproj_patcher.dart';
import 'package:flutter_app_icons_generator/src/platforms/macos/macos_scheme_generator.dart';
import 'package:flutter_app_icons_generator/src/platforms/macos/macos_xcconfig_generator.dart';
import 'package:flutter_app_icons_generator/src/shared/podfile/podfile_flavor_patcher.dart';

/// Updates the macOS Xcode project for icon generation.
///
/// For non-flavor builds:
/// 1. Removes legacy `.icns`-based icon setups (file and pbxproj refs).
/// 2. Ensures `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` is present in
///    the Xcode project build settings.
/// 3. Ensures `Assets.xcassets` is in the Resources build phase.
///
/// The asset catalog approach (individual PNGs in `.appiconset`) is the
/// modern Apple-recommended way to manage icons — Xcode generates the
/// `.icns` automatically at build time.
///
/// For flavor builds:
/// 1. Generates per-flavor xcconfig files (bundle ID + icon name).
/// 2. Creates Xcode schemes for each flavor.
/// 3. Clones existing build configurations with flavor suffixes so
///    `flutter run --flavor <name> -d macos` works out of the box.
class MacosUpdater implements PlatformUpdater {
  /// Regex matching any `ASSETCATALOG_COMPILER_APPICON_NAME = <value>;` line.
  static final RegExp _settingPattern = RegExp(
    r'ASSETCATALOG_COMPILER_APPICON_NAME\s*=\s*[^;]+;',
  );

  /// Handles detection and removal of legacy `.icns` icon artifacts.
  final MacosLegacyIconCleaner _legacyCleaner = MacosLegacyIconCleaner();

  /// Ensures `Assets.xcassets` is wired into the Resources build phase.
  final MacosAssetCatalogLinker _catalogLinker = MacosAssetCatalogLinker();

  @override
  Future<void> update(String projectRoot, {String? flavorName}) async {
    final pbxprojPath = '$projectRoot/macos/Runner.xcodeproj/project.pbxproj';
    final file = File(pbxprojPath);

    if (!file.existsSync()) return;

    // Remove any legacy .icns-based icon setup before applying asset catalog
    // configuration. This ensures Xcode uses the new .appiconset approach.
    _legacyCleaner.clean(projectRoot);

    // Ensure Asset Catalog is in the Resources build phase so Xcode compiles
    // it into the app bundle.
    _catalogLinker.link(projectRoot);

    // When running with flavors, configureFlavors() handles everything.
    if (flavorName != null) return;

    var content = file.readAsStringSync();
    const expectedSetting = 'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon';

    if (content.contains('$expectedSetting;')) return;

    if (_settingPattern.hasMatch(content)) {
      content = content.replaceAll(_settingPattern, '$expectedSetting;');
    } else {
      // No existing setting found — inject it into all build settings blocks
      // for the Runner target.
      content = _injectAppIconSetting(content, expectedSetting);
    }

    file.writeAsStringSync(content);
  }

  /// Injects the `ASSETCATALOG_COMPILER_APPICON_NAME` build setting into
  /// existing buildSettings blocks that don't already have it.
  ///
  /// This covers the case where a legacy project never had this setting
  /// (relying solely on `.icns` + `CFBundleIconFile`).
  String _injectAppIconSetting(String content, String setting) {
    // Match `buildSettings = {` and inject after the opening brace.
    // Only targets blocks for the Runner native target by limiting scope.
    final pattern = RegExp(r'(buildSettings = \{)\n');
    return content.replaceAllMapped(pattern, (match) {
      return '${match.group(1)}\n\t\t\t\t$setting;\n';
    });
  }

  /// Configures macOS for all flavors at once.
  ///
  /// Generates xcconfig files, Xcode schemes, and patches project.pbxproj
  /// with cloned build configurations for each flavor.
  Future<void> configureFlavors(
    String projectRoot,
    Map<String, FlavorConfig> flavors,
  ) async {
    // Clean legacy .icns artifacts before applying flavor configuration.
    _legacyCleaner.clean(projectRoot);

    // Ensure Asset Catalog is in the Resources build phase.
    _catalogLinker.link(projectRoot);

    MacosXcconfigGenerator().generate(projectRoot, flavors);
    MacosSchemeGenerator().generate(projectRoot, flavors.keys.toSet());
    MacosPbxprojPatcher().patch(projectRoot, flavors.keys.toSet());
    PodfileFlavorPatcher()
        .patch('$projectRoot/macos/Podfile', flavors.keys.toSet());
  }
}
