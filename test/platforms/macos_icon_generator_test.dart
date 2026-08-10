import 'dart:convert';
import 'dart:io';

import 'package:flutter_app_icons_generator/src/config/config_model.dart';
import 'package:flutter_app_icons_generator/src/core/default_image_optimizer.dart';
import 'package:flutter_app_icons_generator/src/core/default_image_processor.dart';
import 'package:flutter_app_icons_generator/src/platforms/macos/macos_icon_generator.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

void main() {
  late MacosIconGenerator generator;
  late Directory tempDir;
  late String testImagePath;

  /// Default asset catalog output path used by the macOS icon generator.
  const macosAssetPath = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';

  setUp(() {
    generator = MacosIconGenerator(
      imageProcessor: DefaultImageProcessor(),
      imageOptimizer: const DefaultImageOptimizer(),
    );

    // Create a temporary directory to simulate a Flutter project.
    tempDir = Directory.systemTemp.createTempSync('macos_icon_test_');

    // Create a test source image (1024x1024 RGBA).
    final testImage = img.Image(width: 1024, height: 1024, numChannels: 4);
    img.fill(testImage, color: img.ColorRgba8(100, 150, 200, 200));
    final pngBytes = img.encodePng(testImage);
    testImagePath = '${tempDir.path}/test_icon.png';
    File(testImagePath).writeAsBytesSync(pngBytes);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('MacosIconGenerator', () {
    test('generates individual PNG files in asset catalog', () async {
      final config = ResolvedIconConfig(foregroundPath: testImagePath);

      await generator.generate(config, tempDir.path);

      final outputDir = Directory('${tempDir.path}/$macosAssetPath');
      expect(outputDir.existsSync(), isTrue);

      // Verify all expected PNG files are generated.
      final expectedFiles = [
        'app_icon_16x16.png',
        'app_icon_16x16@2x.png',
        'app_icon_32x32.png',
        'app_icon_32x32@2x.png',
        'app_icon_128x128.png',
        'app_icon_128x128@2x.png',
        'app_icon_256x256.png',
        'app_icon_256x256@2x.png',
        'app_icon_512x512.png',
        'app_icon_512x512@2x.png',
      ];

      for (final filename in expectedFiles) {
        final file = File('${outputDir.path}/$filename');
        expect(file.existsSync(), isTrue,
            reason: '$filename should exist in asset catalog');
      }
    });

    test('generates PNG files with correct pixel dimensions', () async {
      final config = ResolvedIconConfig(foregroundPath: testImagePath);

      await generator.generate(config, tempDir.path);

      final outputDir = Directory('${tempDir.path}/$macosAssetPath');

      // 16x16@1x should be 16 pixels.
      final icon16 = img.decodePng(
        File('${outputDir.path}/app_icon_16x16.png').readAsBytesSync(),
      )!;
      expect(icon16.width, equals(16));
      expect(icon16.height, equals(16));

      // 16x16@2x should be 32 pixels.
      final icon16at2x = img.decodePng(
        File('${outputDir.path}/app_icon_16x16@2x.png').readAsBytesSync(),
      )!;
      expect(icon16at2x.width, equals(32));
      expect(icon16at2x.height, equals(32));

      // 512x512@2x should be 1024 pixels.
      final icon512at2x = img.decodePng(
        File('${outputDir.path}/app_icon_512x512@2x.png').readAsBytesSync(),
      )!;
      expect(icon512at2x.width, equals(1024));
      expect(icon512at2x.height, equals(1024));
    });

    test('does not generate standalone .icns file', () async {
      final config = ResolvedIconConfig(foregroundPath: testImagePath);

      await generator.generate(config, tempDir.path);

      // No .icns file should exist at the macos/ level.
      final icnsFile = File('${tempDir.path}/macos/AppIcon.icns');
      expect(icnsFile.existsSync(), isFalse,
          reason: 'Standalone .icns should not be generated');

      // No .icns file inside the appiconset either.
      final oldIcnsFile = File('${tempDir.path}/$macosAssetPath/app_icon.icns');
      expect(oldIcnsFile.existsSync(), isFalse,
          reason: 'No .icns file should be in the asset catalog');
    });

    test('generates valid Contents.json with PNG entries', () async {
      final config = ResolvedIconConfig(foregroundPath: testImagePath);

      await generator.generate(config, tempDir.path);

      final outputDir = Directory('${tempDir.path}/$macosAssetPath');
      final contentsFile = File('${outputDir.path}/Contents.json');
      expect(contentsFile.existsSync(), isTrue);

      final contents =
          jsonDecode(contentsFile.readAsStringSync()) as Map<String, dynamic>;

      // Verify info section.
      final info = contents['info'] as Map<String, dynamic>;
      expect(info['author'], equals('flutter_app_icons_generator'));
      expect(info['version'], equals(1));

      // Verify images section has entries for all 10 sizes.
      final images = contents['images'] as List<dynamic>;
      expect(images.length, equals(10));

      // Verify each entry has the required fields.
      for (final entry in images) {
        final image = entry as Map<String, dynamic>;
        expect(image.containsKey('filename'), isTrue);
        expect(image.containsKey('idiom'), isTrue);
        expect(image.containsKey('size'), isTrue);
        expect(image.containsKey('scale'), isTrue);
        expect(image['idiom'], equals('mac'));
      }

      // Verify specific entries.
      final filenames =
          images.map((e) => (e as Map<String, dynamic>)['filename']).toList();
      expect(filenames, contains('app_icon_16x16.png'));
      expect(filenames, contains('app_icon_16x16@2x.png'));
      expect(filenames, contains('app_icon_512x512.png'));
      expect(filenames, contains('app_icon_512x512@2x.png'));

      // Verify size and scale values for a specific entry.
      final entry16at2x = images.firstWhere(
        (e) =>
            (e as Map<String, dynamic>)['filename'] == 'app_icon_16x16@2x.png',
      ) as Map<String, dynamic>;
      expect(entry16at2x['size'], equals('16x16'));
      expect(entry16at2x['scale'], equals('2x'));
    });

    test('outputs to correct directory path', () async {
      final config = ResolvedIconConfig(foregroundPath: testImagePath);

      await generator.generate(config, tempDir.path);

      final expectedPath =
          '${tempDir.path}/macos/Runner/Assets.xcassets/AppIcon.appiconset';
      expect(Directory(expectedPath).existsSync(), isTrue);
    });

    test('handles adaptive icon config with background color', () async {
      // Create a foreground image with transparency.
      final foreground = img.Image(width: 1024, height: 1024, numChannels: 4);
      img.fill(foreground, color: img.ColorRgba8(255, 0, 0, 128));
      final fgPath = '${tempDir.path}/foreground.png';
      File(fgPath).writeAsBytesSync(img.encodePng(foreground));

      final config = ResolvedIconConfig(
        foregroundPath: fgPath,
        background: const BackgroundColor('#4CAF50'),
      );

      await generator.generate(config, tempDir.path);

      final outputDir = Directory('${tempDir.path}/$macosAssetPath');
      expect(outputDir.existsSync(), isTrue);

      // Verify PNGs exist.
      final icon128 = File('${outputDir.path}/app_icon_128x128.png');
      expect(icon128.existsSync(), isTrue);

      // Verify the generated PNG is valid.
      final decoded = img.decodePng(icon128.readAsBytesSync());
      expect(decoded, isNotNull);
      expect(decoded!.width, equals(128));
      expect(decoded.height, equals(128));
    });

    test('generates flavor-specific asset catalog path', () async {
      final config = ResolvedIconConfig(foregroundPath: testImagePath);

      await generator.generate(config, tempDir.path, flavorName: 'staging');

      final expectedPath =
          '${tempDir.path}/macos/Runner/Assets.xcassets/AppIcon-staging.appiconset';
      expect(Directory(expectedPath).existsSync(), isTrue);

      // PNGs should be in the flavor-specific directory.
      final pngFile = File('$expectedPath/app_icon_128x128.png');
      expect(pngFile.existsSync(), isTrue);
    });
  });
}
