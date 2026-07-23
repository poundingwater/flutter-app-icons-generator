import 'dart:io';

import 'package:flutter_app_icons_generator/src/config/config_model.dart';
import 'package:flutter_app_icons_generator/src/flavors/flavor_model.dart';
import 'package:flutter_app_icons_generator/src/platforms/ios/ios_xcconfig_generator.dart';
import 'package:flutter_app_icons_generator/src/platforms/macos/macos_xcconfig_generator.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('swift_version_resolver_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  void writeMinimalPbxproj(String platformFolder, String swiftVersion) {
    final projectDir = Directory('${tempDir.path}/$platformFolder/Runner.xcodeproj');
    projectDir.createSync(recursive: true);

    File('${projectDir.path}/project.pbxproj').writeAsStringSync('''
/* Begin XCBuildConfiguration section */
111111111111111111111111 /* Debug */ = {
	isa = XCBuildConfiguration;
	buildSettings = {
		SWIFT_VERSION = $swiftVersion;
	};
	name = Debug;
	};
222222222222222222222222 /* Release */ = {
	isa = XCBuildConfiguration;
	buildSettings = {
		SWIFT_VERSION = $swiftVersion;
	};
	name = Release;
	};
333333333333333333333333 /* Profile */ = {
	isa = XCBuildConfiguration;
	buildSettings = {
		SWIFT_VERSION = $swiftVersion;
	};
	name = Profile;
	};
/* End XCBuildConfiguration section */
/* Begin XCConfigurationList section */
AAAAAAAABBBBBBBBCCCCCCCC /* Build configuration list for PBXNativeTarget "Runner" */ = {
	isa = XCConfigurationList;
	buildConfigurations = (
		111111111111111111111111 /* Debug */,
		222222222222222222222222 /* Release */,
		333333333333333333333333 /* Profile */,
	);
};
/* End XCConfigurationList section */
''');
  }

  test('ios flavor xcconfigs inherit the existing Swift version', () {
    writeMinimalPbxproj('ios', '5.0');

    IosXcconfigGenerator().generate(
      tempDir.path,
      {'dev': const FlavorConfig(
        icon: IconConfig(allPlatforms: 'icon.png'),
        bundleIdentifier: 'com.example.dev',
      )},
    );

    final generated = File('${tempDir.path}/ios/Flutter/Debug-dev.xcconfig')
        .readAsStringSync();

    expect(generated, contains('SWIFT_VERSION = 5.0'));
  });

  test('macos flavor xcconfigs inherit the existing Swift version', () {
    writeMinimalPbxproj('macos', '6.0');

    MacosXcconfigGenerator().generate(
      tempDir.path,
      {'dev': const FlavorConfig(
        icon: IconConfig(allPlatforms: 'icon.png'),
        bundleIdentifier: 'com.example.dev',
      )},
    );

    final generated = File('${tempDir.path}/macos/Flutter/Debug-dev.xcconfig')
        .readAsStringSync();

    expect(generated, contains('SWIFT_VERSION = 6.0'));
  });
}
