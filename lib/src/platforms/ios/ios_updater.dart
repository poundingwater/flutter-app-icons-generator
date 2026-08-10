import 'dart:io';

import 'package:flutter_app_icons_generator/src/core/platform_updater.dart';
import 'package:flutter_app_icons_generator/src/flavors/flavor_model.dart';
import 'package:flutter_app_icons_generator/src/platforms/ios/ios_pbxproj_patcher.dart';
import 'package:flutter_app_icons_generator/src/platforms/ios/ios_scheme_generator.dart';
import 'package:flutter_app_icons_generator/src/platforms/ios/ios_xcconfig_generator.dart';
import 'package:flutter_app_icons_generator/src/shared/podfile/podfile_flavor_patcher.dart';

/// Updates the iOS Xcode project for icon generation.
///
/// For non-flavor builds:
/// Ensures `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` is present in the
/// Xcode project build settings.
///
/// For flavor builds:
/// 1. Generates per-flavor xcconfig files (bundle ID + icon name).
/// 2. Creates Xcode schemes for each flavor.
/// 3. Clones existing build configurations with flavor suffixes so
///    `flutter run --flavor <name>` works out of the box.
class IosUpdater implements PlatformUpdater {
  /// Regex matching any `ASSETCATALOG_COMPILER_APPICON_NAME = <value>;` line.
  static final RegExp _settingPattern = RegExp(
    r'ASSETCATALOG_COMPILER_APPICON_NAME\s*=\s*[^;]+;',
  );

  @override
  Future<void> update(String projectRoot, {String? flavorName}) async {
    final pbxprojPath = '$projectRoot/ios/Runner.xcodeproj/project.pbxproj';
    final file = File(pbxprojPath);

    if (!file.existsSync()) return;

    // When running with flavors, configureFlavors() handles everything.
    if (flavorName != null) return;

    var content = file.readAsStringSync();
    const expectedSetting = 'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon';

    if (content.contains('$expectedSetting;')) return;

    if (_settingPattern.hasMatch(content)) {
      content = content.replaceAll(_settingPattern, '$expectedSetting;');
      file.writeAsStringSync(content);
    }
  }

  /// Configures iOS for all flavors at once.
  ///
  /// Generates xcconfig files, Xcode schemes, and patches project.pbxproj
  /// with cloned build configurations for each flavor.
  Future<void> configureFlavors(
    String projectRoot,
    Map<String, FlavorConfig> flavors,
  ) async {
    IosXcconfigGenerator().generate(projectRoot, flavors);
    IosSchemeGenerator().generate(projectRoot, flavors.keys.toSet());
    IosPbxprojPatcher().patch(projectRoot, flavors.keys.toSet());
    PodfileFlavorPatcher()
        .patch('$projectRoot/ios/Podfile', flavors.keys.toSet());
  }
}
