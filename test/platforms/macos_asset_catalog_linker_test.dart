import 'dart:io';

import 'package:flutter_app_icons_generator/src/platforms/macos/macos_asset_catalog_linker.dart';
import 'package:test/test.dart';

/// Minimal pbxproj with two targets (Runner + RunnerTests) to verify the
/// linker inserts into the correct (Runner) build phase.
///
/// RunnerTests is listed FIRST to ensure the linker doesn't just pick the
/// first PBXResourcesBuildPhase it encounters.
String _buildPbxproj({bool includeAssetCatalogBuildFile = false}) {
  final buildFileEntry = includeAssetCatalogBuildFile
      ? '\t\tBBBBBBBB00000001 /* Assets.xcassets in Resources */ = '
          '{isa = PBXBuildFile; fileRef = AAAA000011112222 '
          '/* Assets.xcassets */; };\n'
      : '';

  return '''
/* Begin PBXBuildFile section */
${buildFileEntry}\t\tCCCC000011112222 /* Main.storyboard in Resources */ = {isa = PBXBuildFile; fileRef = DDDD000011112222 /* Main.storyboard */; };
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
\t\tAAAA000011112222 /* Assets.xcassets */ = {isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; };
\t\tDDDD000011112222 /* Main.storyboard */ = {isa = PBXFileReference; lastKnownFileType = file.storyboard; path = Main.storyboard; sourceTree = "<group>"; };
/* End PBXFileReference section */

/* Begin PBXNativeTarget section */
\t\t331C80D2294CF70F00263BE5 /* RunnerTests */ = {
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildPhases = (
\t\t\t\t331C80D3294CF70F00263BE5 /* Resources */,
\t\t\t\t331C80D4294CF70F00263BE5 /* Sources */,
\t\t\t);
\t\t\tname = RunnerTests;
\t\t\tproductName = RunnerTests;
\t\t\tproductType = "com.apple.product-type.bundle.unit-test";
\t\t};
\t\t33CC10EC2044A3C60003C045 /* Runner */ = {
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildPhases = (
\t\t\t\t33CC10EB2044A3C60003C045 /* Resources */,
\t\t\t\t33CC10E92044A3C60003C045 /* Sources */,
\t\t\t);
\t\t\tname = Runner;
\t\t\tproductName = Runner;
\t\t\tproductType = "com.apple.product-type.application";
\t\t};
/* End PBXNativeTarget section */

/* Begin PBXResourcesBuildPhase section */
\t\t331C80D3294CF70F00263BE5 /* Resources */ = {
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
\t\t33CC10EB2044A3C60003C045 /* Resources */ = {
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\tCCCC000011112222 /* Main.storyboard in Resources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXResourcesBuildPhase section */
''';
}

void main() {
  late Directory tempDir;
  late MacosAssetCatalogLinker linker;

  setUp(() {
    tempDir =
        Directory.systemTemp.createTempSync('macos_asset_catalog_linker_');
    linker = MacosAssetCatalogLinker();
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('adds Assets.xcassets to Runner build phase, not RunnerTests', () {
    final pbxprojFile =
        File('${tempDir.path}/macos/Runner.xcodeproj/project.pbxproj');
    pbxprojFile.parent.createSync(recursive: true);
    pbxprojFile.writeAsStringSync(_buildPbxproj());

    linker.link(tempDir.path);

    final updated = pbxprojFile.readAsStringSync();

    // Should have a PBXBuildFile entry.
    expect(updated, contains('Assets.xcassets in Resources'));
    expect(
      updated,
      contains('fileRef = AAAA000011112222 /* Assets.xcassets */'),
    );

    // The entry must be in the Runner phase (33CC10EB...).
    final runnerPhase = RegExp(
      r'33CC10EB2044A3C60003C045 /\* Resources \*/ = \{.*?files = \(\s*\n(.*?)\);',
      dotAll: true,
    ).firstMatch(updated);
    expect(runnerPhase, isNotNull);
    expect(
      runnerPhase!.group(1),
      contains('Assets.xcassets in Resources'),
    );

    // RunnerTests phase must NOT have the entry.
    final testsPhase = RegExp(
      r'331C80D3294CF70F00263BE5 /\* Resources \*/ = \{.*?files = \(\s*\n(.*?)\);',
      dotAll: true,
    ).firstMatch(updated);
    expect(testsPhase, isNotNull);
    expect(
      testsPhase!.group(1),
      isNot(contains('Assets.xcassets in Resources')),
    );
  });

  test('skips when Assets.xcassets already in Resources build phase', () {
    final pbxprojFile =
        File('${tempDir.path}/macos/Runner.xcodeproj/project.pbxproj');
    pbxprojFile.parent.createSync(recursive: true);
    final original = _buildPbxproj(includeAssetCatalogBuildFile: true);
    pbxprojFile.writeAsStringSync(original);

    linker.link(tempDir.path);

    expect(pbxprojFile.readAsStringSync(), equals(original));
  });

  test('skips when pbxproj does not exist', () {
    expect(() => linker.link(tempDir.path), returnsNormally);
  });

  test('skips when Assets.xcassets has no PBXFileReference', () {
    final pbxprojFile =
        File('${tempDir.path}/macos/Runner.xcodeproj/project.pbxproj');
    pbxprojFile.parent.createSync(recursive: true);
    final original = '''
/* Begin PBXBuildFile section */
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
/* End PBXFileReference section */

/* Begin PBXNativeTarget section */
\t\t33CC10EC2044A3C60003C045 /* Runner */ = {
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildPhases = (
\t\t\t\t33CC10EB2044A3C60003C045 /* Resources */,
\t\t\t);
\t\t\tname = Runner;
\t\t\tproductType = "com.apple.product-type.application";
\t\t};
/* End PBXNativeTarget section */

/* Begin PBXResourcesBuildPhase section */
\t\t33CC10EB2044A3C60003C045 /* Resources */ = {
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXResourcesBuildPhase section */
''';
    pbxprojFile.writeAsStringSync(original);

    linker.link(tempDir.path);

    expect(pbxprojFile.readAsStringSync(), equals(original));
  });
}
