import 'dart:convert';
import 'dart:io';

import 'package:flutter_app_icons_generator/src/config/config_model.dart';
import 'package:flutter_app_icons_generator/src/core/default_image_optimizer.dart';
import 'package:flutter_app_icons_generator/src/core/default_image_processor.dart';
import 'package:flutter_app_icons_generator/src/platforms/macos/macos_icon_generator.dart';
import 'package:flutter_app_icons_generator/src/shared/constants.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

void main() {
  late MacosIconGenerator generator;
  late Directory tempDir;
  late String testImagePath;

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
    test('generates all required icon sizes', () async {
      final config = IconConfig(imagePath: testImagePath);

      await generator.generate(config, tempDir.path);

      final outputDir = Directory(
        '${tempDir.path}/${MacosIconGenerator.outputPath}',
      );
      expect(outputDir.existsSync(), isTrue);

      for (final size in MacosSizes.sizes) {
        final file = File('${outputDir.path}/app_icon_$size.png');
        expect(file.existsSync(), isTrue, reason: 'Missing icon at size $size');

        // Verify dimensions.
        final decoded = img.decodePng(file.readAsBytesSync());
        expect(decoded, isNotNull);
        expect(decoded!.width, equals(size));
        expect(decoded.height, equals(size));
      }
    });

    test('generates icons with no alpha channel', () async {
      final config = IconConfig(imagePath: testImagePath);

      await generator.generate(config, tempDir.path);

      final outputDir = Directory(
        '${tempDir.path}/${MacosIconGenerator.outputPath}',
      );

      for (final size in MacosSizes.sizes) {
        final file = File('${outputDir.path}/app_icon_$size.png');
        final decoded = img.decodePng(file.readAsBytesSync())!;

        // Verify every pixel has full opacity.
        for (final pixel in decoded) {
          expect(
            pixel.a,
            equals(255),
            reason: 'Alpha not removed at size $size',
          );
        }
      }
    });

    test('generates valid Contents.json manifest', () async {
      final config = IconConfig(imagePath: testImagePath);

      await generator.generate(config, tempDir.path);

      final outputDir = Directory(
        '${tempDir.path}/${MacosIconGenerator.outputPath}',
      );
      final contentsFile = File('${outputDir.path}/Contents.json');
      expect(contentsFile.existsSync(), isTrue);

      final contents =
          jsonDecode(contentsFile.readAsStringSync()) as Map<String, dynamic>;

      // Verify info section.
      final info = contents['info'] as Map<String, dynamic>;
      expect(info['author'], equals('flutter_app_icons_generator'));
      expect(info['version'], equals(1));

      // Verify images section has 10 entries.
      final images = contents['images'] as List<dynamic>;
      expect(images.length, equals(10));

      // Verify all entries have correct idiom.
      for (final entry in images) {
        final image = entry as Map<String, dynamic>;
        expect(image['idiom'], equals('mac'));
        expect(image['filename'], isNotNull);
        expect(image['scale'], isNotNull);
        expect(image['size'], isNotNull);
      }
    });

    test('Contents.json has correct scale and size mappings', () async {
      final config = IconConfig(imagePath: testImagePath);

      await generator.generate(config, tempDir.path);

      final outputDir = Directory(
        '${tempDir.path}/${MacosIconGenerator.outputPath}',
      );
      final contentsFile = File('${outputDir.path}/Contents.json');
      final contents =
          jsonDecode(contentsFile.readAsStringSync()) as Map<String, dynamic>;
      final images = contents['images'] as List<dynamic>;

      // Expected entries as specified in the task.
      final expectedEntries = [
        {'filename': 'app_icon_16.png', 'scale': '1x', 'size': '16x16'},
        {'filename': 'app_icon_32.png', 'scale': '2x', 'size': '16x16'},
        {'filename': 'app_icon_32.png', 'scale': '1x', 'size': '32x32'},
        {'filename': 'app_icon_64.png', 'scale': '2x', 'size': '32x32'},
        {'filename': 'app_icon_128.png', 'scale': '1x', 'size': '128x128'},
        {'filename': 'app_icon_256.png', 'scale': '2x', 'size': '128x128'},
        {'filename': 'app_icon_256.png', 'scale': '1x', 'size': '256x256'},
        {'filename': 'app_icon_512.png', 'scale': '2x', 'size': '256x256'},
        {'filename': 'app_icon_512.png', 'scale': '1x', 'size': '512x512'},
        {'filename': 'app_icon_1024.png', 'scale': '2x', 'size': '512x512'},
      ];

      for (var i = 0; i < expectedEntries.length; i++) {
        final actual = images[i] as Map<String, dynamic>;
        final expected = expectedEntries[i];
        expect(actual['filename'], equals(expected['filename']),
            reason: 'Entry $i filename mismatch');
        expect(actual['scale'], equals(expected['scale']),
            reason: 'Entry $i scale mismatch');
        expect(actual['size'], equals(expected['size']),
            reason: 'Entry $i size mismatch');
      }
    });

    test('outputs to correct directory path', () async {
      final config = IconConfig(imagePath: testImagePath);

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

      final config = IconConfig(
        foregroundPath: fgPath,
        background: const BackgroundColor('#4CAF50'),
      );

      await generator.generate(config, tempDir.path);

      final outputDir = Directory(
        '${tempDir.path}/${MacosIconGenerator.outputPath}',
      );
      expect(outputDir.existsSync(), isTrue);

      // Verify all icons were generated.
      for (final size in MacosSizes.sizes) {
        final file = File('${outputDir.path}/app_icon_$size.png');
        expect(file.existsSync(), isTrue);
      }
    });
  });
}
