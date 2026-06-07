// Feature: flutter-app-icons, Property 2: Image Dimension Validation
//
// For any image with width `w` and height `h`, the image validation function
// SHALL accept the image if and only if `w >= 1024` AND `h >= 1024`. Images
// below either threshold SHALL be rejected with an error containing the actual
// dimensions.
//
// **Validates: Requirements 3.2, 3.5**

import 'dart:io';

import 'package:glados/glados.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_app_icons/src/core/default_image_processor.dart';
import 'package:flutter_app_icons/src/shared/exceptions.dart';

/// Generates a random dimension pair (width, height) in [1, 2048].
extension DimensionGenerators on Any {
  Generator<({int width, int height})> get dimensions {
    return simple(
      generate: (random, size) {
        final width = random.nextInt(2048) + 1;
        final height = random.nextInt(2048) + 1;
        return (width: width, height: height);
      },
      shrink: (input) sync* {
        // Shrink toward boundary (1024, 1024)
        if (input.width > 1024) {
          yield (width: 1024, height: input.height);
        }
        if (input.height > 1024) {
          yield (width: input.width, height: 1024);
        }
        if (input.width > 1 && input.width < 1024) {
          yield (width: 1, height: input.height);
        }
        if (input.height > 1 && input.height < 1024) {
          yield (width: input.width, height: 1);
        }
      },
    );
  }
}

void main() {
  group('Property 2: Image Dimension Validation', () {
    late Directory tempDir;
    late DefaultImageProcessor processor;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('image_validation_');
      processor = DefaultImageProcessor();
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    Glados(any.dimensions, ExploreConfig(numRuns: 100)).test(
      'accepts image iff both width >= 1024 and height >= 1024',
      (dims) async {
        final width = dims.width;
        final height = dims.height;

        // Create a minimal PNG image with the given dimensions.
        final image = img.Image(width: width, height: height);
        final pngBytes = img.encodePng(image);

        final filePath = '${tempDir.path}/test_image.png';
        File(filePath).writeAsBytesSync(pngBytes);

        if (width >= 1024 && height >= 1024) {
          // Should succeed without throwing.
          final result = await processor.loadAndValidate(filePath);
          expect(result.width, equals(width));
          expect(result.height, equals(height));
        } else {
          // Should throw ImageDimensionException.
          expect(
            () => processor.loadAndValidate(filePath),
            throwsA(
              isA<ImageDimensionException>()
                  .having((e) => e.actualWidth, 'actualWidth', equals(width))
                  .having(
                      (e) => e.actualHeight, 'actualHeight', equals(height)),
            ),
          );
        }
      },
    );
  });
}
