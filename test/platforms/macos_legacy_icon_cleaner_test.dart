import 'dart:io';

import 'package:flutter_app_icons_generator/src/platforms/macos/macos_legacy_icon_cleaner.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late MacosLegacyIconCleaner cleaner;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('macos_legacy_icon_cleaner_');
    cleaner = MacosLegacyIconCleaner();
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('removes legacy .icns references without changing Info.plist', () {
    final macosDir = Directory('${tempDir.path}/macos/Runner');
    macosDir.createSync(recursive: true);

    final plistFile = File('${macosDir.path}/Info.plist');
    final originalPlist = '''<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
</dict>
</plist>
''';
    plistFile.writeAsStringSync(originalPlist);

    final pbxprojFile =
        File('${tempDir.path}/macos/Runner.xcodeproj/project.pbxproj');
    pbxprojFile.parent.createSync(recursive: true);
    pbxprojFile.writeAsStringSync('''
/* Begin PBXBuildFile section */
		AAAABBBBCCCCDDDDEEEEFFFF /* AppIcon.icns in Resources */ = {isa = PBXBuildFile; fileRef = 111122223333444455556666 /* AppIcon.icns */; };
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		111122223333444455556666 /* AppIcon.icns */ = {isa = PBXFileReference; lastKnownFileType = image.icns; path = AppIcon.icns; sourceTree = "<group>"; };
		777788889999AAAABBBBCCCC /* Keep.png */ = {isa = PBXFileReference; lastKnownFileType = image.png; path = Keep.png; sourceTree = "<group>"; };
/* End PBXFileReference section */

/* Begin PBXResourcesBuildPhase section */
		AAAABBBBCCCCDDDDEEEEFFFF /* AppIcon.icns in Resources */,
		777788889999AAAABBBBCCCC /* Keep.png in Resources */,
/* End PBXResourcesBuildPhase section */
''');

    final icnsFile = File('${tempDir.path}/macos/Runner/Assets.xcassets/AppIcon.icns');
    icnsFile.parent.createSync(recursive: true);
    icnsFile.writeAsStringSync('legacy icon');

    cleaner.clean(tempDir.path);

    expect(icnsFile.existsSync(), isFalse);
    expect(plistFile.readAsStringSync(), equals(originalPlist));

    final updatedPbxproj = pbxprojFile.readAsStringSync();
    expect(updatedPbxproj, isNot(contains('AppIcon.icns')));
    expect(updatedPbxproj, contains('Keep.png'));
  });
}