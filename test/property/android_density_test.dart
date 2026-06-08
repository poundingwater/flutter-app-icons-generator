// Feature: flutter-app-icons-generator, Property 5: Android Density Bucket Completeness
//
// For any valid source image and Android icon configuration (combined image),
// the Android icon generator SHALL produce exactly one icon file per density
// bucket (mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi), and each file's dimensions
// SHALL match the expected pixel size for that density (48, 72, 96, 144, 192).
//
// **Validates: Requirements 7.3, 7.4, 7.5**

import 'dart:io';

import 'package:glados/glados.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_app_icons_generator/src/config/config_model.dart';
import 'package:flutter_app_icons_generator/src/platforms/android/android_icon_generator.dart';
import 'package:flutter_app_icons_generator/src/shared/constants.dart';

/// Holds a generated source image size for testing.
class SourceImageSize {
  const SourceImageSize({required this.width, required this.height});

  final int width;
  final int height;

  @override
  String toString() => 'SourceImageSize(${width}x$height)';
}

extension AndroidDensityGenerators on Any {
  /// Generates a valid source image size (>= 1024x1024, up to 2048x2048).
  Generator<SourceImageSize> get sourceImageSize {
    return simple(
      generate: (random, size) {
        final width = 1024 + random.nextInt(1025); // 1024 to 2048
        final height = 1024 + random.nextInt(1025); // 1024 to 2048
        return SourceImageSize(width: width, height: height);
      },
      shrink: (input) sync* {
        // Shrink toward minimum valid size
        if (input.width > 1024) {
          yield SourceImageSize(width: 1024, height: input.height);
        }
        if (input.height > 1024) {
          yield SourceImageSize(width: input.width, height: 1024);
        }
      },
    );
  }
}

void main() {
  group('Property 5: Android Density Bucket Completeness', () {
    late Directory tempDir;
    late AndroidIconGenerator generator;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('android_density_test_');
      generator = AndroidIconGenerator();
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    Glados(any.sourceImageSize, ExploreConfig(numRuns: 100)).test(
      'generates exactly one icon per density bucket with correct dimensions',
      (sourceSize) async {
        // Create a source image with the generated dimensions.
        final sourceImage = img.Image(
          width: sourceSize.width,
          height: sourceSize.height,
          numChannels: 4,
        );
        // Fill with some color so it's a valid image.
        img.fill(sourceImage, color: img.ColorRgba8(100, 150, 200, 255));

        // Write the source image to a temp file.
        final sourceFile = File('${tempDir.path}/source_icon.png');
        sourceFile.writeAsBytesSync(img.encodePng(sourceImage));

        // Create a combined IconConfig pointing to the source image.
        final config = IconConfig(imagePath: sourceFile.path);

        // Run the Android generator.
        await generator.generate(config, tempDir.path);

        // Verify exactly one file per density bucket with correct dimensions.
        final generatedFiles = <String>[];

        for (final entry in AndroidSizes.densityBuckets.entries) {
          final bucket = entry.key;
          final expectedSize = entry.value;

          final outputPath =
              '${tempDir.path}/android/app/src/main/res/$bucket/ic_launcher.png';
          final outputFile = File(outputPath);

          // Verify the file exists.
          expect(outputFile.existsSync(), isTrue,
              reason: 'Expected icon file at $bucket to exist '
                  '(source: ${sourceSize.width}x${sourceSize.height})');

          // Decode and verify dimensions.
          final decoded = img.decodePng(outputFile.readAsBytesSync());
          expect(decoded, isNotNull,
              reason: 'Icon at $bucket should be a valid PNG');
          expect(decoded!.width, equals(expectedSize),
              reason:
                  'Icon at $bucket should be ${expectedSize}x$expectedSize, '
                  'got ${decoded.width}x${decoded.height}');
          expect(decoded.height, equals(expectedSize),
              reason:
                  'Icon at $bucket should be ${expectedSize}x$expectedSize, '
                  'got ${decoded.width}x${decoded.height}');

          generatedFiles.add(outputPath);
        }

        // Verify exactly 5 files generated (one per bucket).
        expect(generatedFiles.length, equals(5),
            reason: 'Should generate exactly 5 density bucket icons');
      },
    );
  });
}
