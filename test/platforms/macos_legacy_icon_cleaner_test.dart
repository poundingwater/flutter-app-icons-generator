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

  test('removes legacy .icns references and migrates Info.plist', () {
    final macosDir = Directory('${tempDir.path}/macos/Runner');
    macosDir.createSync(recursive: true);

    final plistFile = File('${macosDir.path}/Info.plist');
    plistFile.writeAsStringSync('''<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
\t<key>CFBundleIconFile</key>
\t<string>AppIcon</string>
\t<key>CFBundleName</key>
\t<string>MyApp</string>
</dict>
</plist>
''');

    final pbxprojFile =
        File('${tempDir.path}/macos/Runner.xcodeproj/project.pbxproj');
    pbxprojFile.parent.createSync(recursive: true);
    pbxprojFile.writeAsStringSync('''
/* Begin PBXBuildFile section */
\t\tAAAABBBBCCCCDDDDEEEEFFFF /* AppIcon.icns in Resources */ = {isa = PBXBuildFile; fileRef = 111122223333444455556666 /* AppIcon.icns */; };
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
\t\t111122223333444455556666 /* AppIcon.icns */ = {isa = PBXFileReference; lastKnownFileType = image.icns; path = AppIcon.icns; sourceTree = "<group>"; };
\t\t777788889999AAAABBBBCCCC /* Keep.png */ = {isa = PBXFileReference; lastKnownFileType = image.png; path = Keep.png; sourceTree = "<group>"; };
/* End PBXFileReference section */

/* Begin PBXResourcesBuildPhase section */
\t\tAAAABBBBCCCCDDDDEEEEFFFF /* AppIcon.icns in Resources */,
\t\t777788889999AAAABBBBCCCC /* Keep.png in Resources */,
/* End PBXResourcesBuildPhase section */
''');

    final icnsFile =
        File('${tempDir.path}/macos/Runner/Assets.xcassets/AppIcon.icns');
    icnsFile.parent.createSync(recursive: true);
    icnsFile.writeAsStringSync('legacy icon');

    cleaner.clean(tempDir.path);

    expect(icnsFile.existsSync(), isFalse);

    // Info.plist should have CFBundleIconName (asset catalog) instead of
    // CFBundleIconFile (standalone .icns). The icon name value is preserved.
    final updatedPlist = plistFile.readAsStringSync();
    expect(updatedPlist, contains('CFBundleIconName'));
    expect(updatedPlist, contains('<string>AppIcon</string>'));
    expect(updatedPlist, isNot(contains('CFBundleIconFile')));

    final updatedPbxproj = pbxprojFile.readAsStringSync();
    expect(updatedPbxproj, isNot(contains('AppIcon.icns')));
    expect(updatedPbxproj, contains('Keep.png'));
  });

  test('does not modify Info.plist if already using CFBundleIconName', () {
    final macosDir = Directory('${tempDir.path}/macos/Runner');
    macosDir.createSync(recursive: true);

    final plistFile = File('${macosDir.path}/Info.plist');
    final modernPlist = '''<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
\t<key>CFBundleIconName</key>
\t<string>AppIcon</string>
</dict>
</plist>
''';
    plistFile.writeAsStringSync(modernPlist);

    cleaner.clean(tempDir.path);

    expect(plistFile.readAsStringSync(), equals(modernPlist));
  });

  test('migrates in-place without breaking nested dict structures', () {
    final macosDir = Directory('${tempDir.path}/macos/Runner');
    macosDir.createSync(recursive: true);

    final plistFile = File('${macosDir.path}/Info.plist');
    plistFile.writeAsStringSync('''<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
\t<dict>
\t\t<key>CFBundleIconFile</key>
\t\t<string>AppIcon</string>
\t\t<key>CFBundleURLTypes</key>
\t\t<array>
\t\t\t<dict>
\t\t\t\t<key>CFBundleTypeRole</key>
\t\t\t\t<string>Editor</string>
\t\t\t</dict>
\t\t</array>
\t</dict>
</plist>
''');

    cleaner.clean(tempDir.path);

    final updatedPlist = plistFile.readAsStringSync();
    expect(updatedPlist, contains('CFBundleIconName'));
    expect(updatedPlist, isNot(contains('CFBundleIconFile')));
    // Nested dict must remain intact.
    expect(updatedPlist, contains('<key>CFBundleTypeRole</key>'));
    expect(updatedPlist, contains('<string>Editor</string>'));
    // Indentation of the new key should match the original.
    expect(updatedPlist, contains('\t\t<key>CFBundleIconName</key>'));
    expect(updatedPlist, contains('\t\t<string>AppIcon</string>'));
  });
}
