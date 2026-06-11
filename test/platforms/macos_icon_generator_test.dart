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

  /// Default output path used by the macOS icon generator (no flavor).
  const macosOutputPath = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';

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
    test('generates app_icon.icns file', () async {
      final config = ResolvedIconConfig(foregroundPath: testImagePath);

      await generator.generate(config, tempDir.path);

      final outputDir = Directory(
        '${tempDir.path}/${macosOutputPath}',
      );
      expect(outputDir.existsSync(), isTrue);

      final icnsFile = File('${outputDir.path}/app_icon.icns');
      expect(icnsFile.existsSync(), isTrue, reason: 'ICNS file should exist');

      // Verify ICNS file starts with "icns" magic bytes.
      final bytes = icnsFile.readAsBytesSync();
      expect(bytes.length, greaterThan(8));
      expect(bytes[0], 0x69); // 'i'
      expect(bytes[1], 0x63); // 'c'
      expect(bytes[2], 0x6E); // 'n'
      expect(bytes[3], 0x73); // 's'
    });

    test('generates ICNS with correct file size in header', () async {
      final config = ResolvedIconConfig(foregroundPath: testImagePath);

      await generator.generate(config, tempDir.path);

      final outputDir = Directory(
        '${tempDir.path}/${macosOutputPath}',
      );
      final icnsFile = File('${outputDir.path}/app_icon.icns');
      final bytes = icnsFile.readAsBytesSync();

      // Read file size from header (bytes 4-7, big-endian).
      final headerSize =
          (bytes[4] << 24) | (bytes[5] << 16) | (bytes[6] << 8) | bytes[7];
      expect(headerSize, equals(bytes.length));
    });

    test('generates valid Contents.json manifest', () async {
      final config = ResolvedIconConfig(foregroundPath: testImagePath);

      await generator.generate(config, tempDir.path);

      final outputDir = Directory(
        '${tempDir.path}/${macosOutputPath}',
      );
      final contentsFile = File('${outputDir.path}/Contents.json');
      expect(contentsFile.existsSync(), isTrue);

      final contents =
          jsonDecode(contentsFile.readAsStringSync()) as Map<String, dynamic>;

      // Verify info section.
      final info = contents['info'] as Map<String, dynamic>;
      expect(info['author'], equals('flutter_app_icons_generator'));
      expect(info['version'], equals(1));

      // Verify images section references the ICNS file.
      final images = contents['images'] as List<dynamic>;
      expect(images.length, equals(1));
      final image = images[0] as Map<String, dynamic>;
      expect(image['filename'], equals('app_icon.icns'));
      expect(image['idiom'], equals('mac'));
    });

    test('outputs to correct directory path', () async {
      final config = ResolvedIconConfig(foregroundPath: testImagePath);

      await generator.generate(config, tempDir.path);

      final expectedPath =
          '${tempDir.path}/macos/Runner/Assets.xcassets/AppIcon.appiconset';
      expect(Directory(expectedPath).existsSync(), isTrue);
    });

    test('handles adaptive icon config with background color', () async {
      // Create a foreground image.
      final foreground = img.Image(width: 1024, height: 1024, numChannels: 4);
      img.fill(foreground, color: img.ColorRgba8(255, 0, 0, 128));
      final fgPath = '${tempDir.path}/foreground.png';
      File(fgPath).writeAsBytesSync(img.encodePng(foreground));

      final config = ResolvedIconConfig(
        foregroundPath: fgPath,
        background: const BackgroundColor('#4CAF50'),
      );

      await generator.generate(config, tempDir.path);

      final outputDir = Directory(
        '${tempDir.path}/${macosOutputPath}',
      );
      expect(outputDir.existsSync(), isTrue);

      final icnsFile = File('${outputDir.path}/app_icon.icns');
      expect(icnsFile.existsSync(), isTrue);

      // Verify it's a valid ICNS file.
      final bytes = icnsFile.readAsBytesSync();
      expect(bytes[0], 0x69);
      expect(bytes[1], 0x63);
      expect(bytes[2], 0x6E);
      expect(bytes[3], 0x73);
    });
  });
}
