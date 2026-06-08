import 'dart:convert';
import 'dart:io';

import 'package:flutter_app_icons_generator/src/cli/cli_runner.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('pipeline_integration_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  /// Creates a 1024x1024 test PNG image at the given path.
  void createTestImage(String path) {
    final dir = Directory(path).parent;
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final image = img.Image(width: 1024, height: 1024, numChannels: 4);
    // Fill with a solid color to make it a valid source image.
    img.fill(image, color: img.ColorRgba8(76, 175, 80, 255));
    final pngBytes = img.encodePng(image);
    File(path).writeAsBytesSync(pngBytes);
  }

  /// Sets up the fixture Flutter project structure with config and source image.
  void setupFixtureProject() {
    final imagePath = '${tempDir.path}/assets/icon.png';
    createTestImage(imagePath);

    // Write flutter_app_icons_generator.yml config with absolute image path.
    final config = '''
icon:
  image: $imagePath
platforms:
  - android
  - ios
  - macos
  - web
  - linux
  - windows
''';
    File('${tempDir.path}/flutter_app_icons_generator.yml')
        .writeAsStringSync(config);

    // Create minimal AndroidManifest.xml with <application> tag.
    final androidManifestDir =
        Directory('${tempDir.path}/android/app/src/main');
    androidManifestDir.createSync(recursive: true);
    File('${androidManifestDir.path}/AndroidManifest.xml').writeAsStringSync('''
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.test">
    <application
        android:label="test_app">
        <activity android:name=".MainActivity" />
    </application>
</manifest>
''');

    // Create minimal web/index.html with <head> section.
    final webDir = Directory('${tempDir.path}/web');
    webDir.createSync(recursive: true);
    File('${webDir.path}/index.html').writeAsStringSync('''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Test App</title>
</head>
<body>
  <script src="main.dart.js"></script>
</body>
</html>
''');

    // Create minimal windows/runner/Runner.rc.
    final windowsRunnerDir = Directory('${tempDir.path}/windows/runner');
    windowsRunnerDir.createSync(recursive: true);
    File('${windowsRunnerDir.path}/Runner.rc').writeAsStringSync('''
#include "resource.h"

IDI_APP_ICON ICON "resources\\\\old_icon.ico"
''');
  }

  group('Full pipeline integration test', () {
    test('generates all platform icons and updates configs', () async {
      setupFixtureProject();

      final runner = CliRunner();
      final exitCode = await runner.run(['-p', tempDir.path]);
      expect(exitCode, equals(0));

      // ===== Verify Android icons =====
      final androidResPath = '${tempDir.path}/android/app/src/main/res';
      final androidDensities = {
        'mipmap-mdpi': 48,
        'mipmap-hdpi': 72,
        'mipmap-xhdpi': 96,
        'mipmap-xxhdpi': 144,
        'mipmap-xxxhdpi': 192,
      };

      for (final entry in androidDensities.entries) {
        final iconFile = File('$androidResPath/${entry.key}/ic_launcher.png');
        expect(iconFile.existsSync(), isTrue,
            reason: 'Android ${entry.key}/ic_launcher.png should exist');

        // Verify dimensions.
        final decoded = img.decodePng(iconFile.readAsBytesSync());
        expect(decoded, isNotNull,
            reason: '${entry.key}/ic_launcher.png should be valid PNG');
        expect(decoded!.width, equals(entry.value),
            reason: '${entry.key} width should be ${entry.value}');
        expect(decoded.height, equals(entry.value),
            reason: '${entry.key} height should be ${entry.value}');
      }

      // ===== Verify iOS icons =====
      final iosAssetPath =
          '${tempDir.path}/ios/Runner/Assets.xcassets/AppIcon.appiconset';
      final iosIconFile = File('$iosAssetPath/app_icon_1024.png');
      expect(iosIconFile.existsSync(), isTrue,
          reason: 'iOS 1024x1024 icon should exist');

      final iosDecoded = img.decodePng(iosIconFile.readAsBytesSync());
      expect(iosDecoded, isNotNull);
      expect(iosDecoded!.width, equals(1024));
      expect(iosDecoded.height, equals(1024));

      final iosContentsFile = File('$iosAssetPath/Contents.json');
      expect(iosContentsFile.existsSync(), isTrue,
          reason: 'iOS Contents.json should exist');

      // ===== Verify macOS icons =====
      final macosAssetPath =
          '${tempDir.path}/macos/Runner/Assets.xcassets/AppIcon.appiconset';
      final macosIcnsFile = File('$macosAssetPath/app_icon.icns');
      expect(macosIcnsFile.existsSync(), isTrue,
          reason: 'macOS app_icon.icns should exist');

      // Verify ICNS magic bytes.
      final icnsBytes = macosIcnsFile.readAsBytesSync();
      expect(icnsBytes[0], 0x69); // 'i'
      expect(icnsBytes[1], 0x63); // 'c'
      expect(icnsBytes[2], 0x6E); // 'n'
      expect(icnsBytes[3], 0x73); // 's'

      final macosContentsFile = File('$macosAssetPath/Contents.json');
      expect(macosContentsFile.existsSync(), isTrue,
          reason: 'macOS Contents.json should exist');

      // ===== Verify Web icons =====
      final webPath = '${tempDir.path}/web';
      final faviconFile = File('$webPath/favicon.ico');
      expect(faviconFile.existsSync(), isTrue,
          reason: 'Web favicon.ico should exist');
      // ICO file should be non-empty.
      expect(faviconFile.readAsBytesSync().length, greaterThan(0));

      final webIcon192 = File('$webPath/icons/Icon-192.png');
      expect(webIcon192.existsSync(), isTrue,
          reason: 'Web Icon-192.png should exist');
      final icon192Decoded = img.decodePng(webIcon192.readAsBytesSync());
      expect(icon192Decoded!.width, equals(192));

      final webIcon512 = File('$webPath/icons/Icon-512.png');
      expect(webIcon512.existsSync(), isTrue,
          reason: 'Web Icon-512.png should exist');
      final icon512Decoded = img.decodePng(webIcon512.readAsBytesSync());
      expect(icon512Decoded!.width, equals(512));

      final webMaskable192 = File('$webPath/icons/Icon-maskable-192.png');
      expect(webMaskable192.existsSync(), isTrue,
          reason: 'Web Icon-maskable-192.png should exist');

      final webMaskable512 = File('$webPath/icons/Icon-maskable-512.png');
      expect(webMaskable512.existsSync(), isTrue,
          reason: 'Web Icon-maskable-512.png should exist');

      // ===== Verify Linux icon =====
      final linuxIconFile = File('${tempDir.path}/linux/app_icon.png');
      expect(linuxIconFile.existsSync(), isTrue,
          reason: 'Linux app_icon.png should exist');
      final linuxDecoded = img.decodePng(linuxIconFile.readAsBytesSync());
      expect(linuxDecoded!.width, equals(512));
      expect(linuxDecoded.height, equals(512));

      // ===== Verify Windows icon =====
      final windowsIcoFile =
          File('${tempDir.path}/windows/runner/resources/app_icon.ico');
      expect(windowsIcoFile.existsSync(), isTrue,
          reason: 'Windows app_icon.ico should exist');
      // ICO file should be non-empty and have the ICO magic bytes.
      final icoBytes = windowsIcoFile.readAsBytesSync();
      expect(icoBytes.length, greaterThan(0));
      // ICO files start with 0x00 0x00 0x01 0x00.
      expect(icoBytes[0], equals(0));
      expect(icoBytes[1], equals(0));
      expect(icoBytes[2], equals(1));
      expect(icoBytes[3], equals(0));

      // ===== Verify platform config updates =====

      // Android: AndroidManifest.xml contains android:icon="@mipmap/ic_launcher"
      final manifestContent = File(
        '${tempDir.path}/android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifestContent, contains('android:icon="@mipmap/ic_launcher"'));

      // Web: index.html contains <link rel="icon" pointing to favicon.ico
      final indexHtmlContent =
          File('${tempDir.path}/web/index.html').readAsStringSync();
      expect(indexHtmlContent, contains('rel="icon"'));
      expect(indexHtmlContent, contains('favicon.ico'));

      // Windows: Runner.rc references resources\app_icon.ico
      final runnerRcContent =
          File('${tempDir.path}/windows/runner/Runner.rc').readAsStringSync();
      expect(runnerRcContent, contains(r'resources\app_icon.ico'));

      // Web: manifest.json exists with icons array
      final manifestJsonFile = File('${tempDir.path}/web/manifest.json');
      expect(manifestJsonFile.existsSync(), isTrue,
          reason: 'web/manifest.json should exist');
      final manifestJson = jsonDecode(manifestJsonFile.readAsStringSync())
          as Map<String, dynamic>;
      expect(manifestJson['icons'], isA<List>());
      expect((manifestJson['icons'] as List).length, greaterThan(0));
    });
  });

  group('--init flag integration test', () {
    test('creates config file in a clean directory', () async {
      final initDir = Directory.systemTemp.createTempSync('init_test_');
      addTearDown(() => initDir.deleteSync(recursive: true));

      final runner = CliRunner();
      final exitCode = await runner.run(['--init', '-p', initDir.path]);
      expect(exitCode, equals(0));

      final configFile =
          File('${initDir.path}/flutter_app_icons_generator.yml');
      expect(configFile.existsSync(), isTrue,
          reason: '--init should create flutter_app_icons_generator.yml');

      // Verify config file has content.
      final content = configFile.readAsStringSync();
      expect(content, contains('icon:'));
      expect(content, contains('image:'));
    });

    test('fails when config file already exists', () async {
      final initDir = Directory.systemTemp.createTempSync('init_exists_test_');
      addTearDown(() => initDir.deleteSync(recursive: true));

      // Create the config file first.
      File('${initDir.path}/flutter_app_icons_generator.yml')
          .writeAsStringSync('icon:\n  image: test.png\n');

      final runner = CliRunner();
      final exitCode = await runner.run(['--init', '-p', initDir.path]);
      expect(exitCode, equals(1),
          reason: '--init should fail with exit code 1 when config exists');
    });
  });
}
