// Feature: flutter-app-icons, Property 6: Resize Produces Exact Target Dimensions
//
// For any source image with dimensions >= 1024x1024 and any target size
// (tw, th) where 1 <= tw <= source_width and 1 <= th <= source_height,
// the resize function SHALL produce an output image with dimensions exactly
// equal to (tw, th).
//
// **Validates: Requirements 8.1, 9.1, 10.1, 10.2, 11.1, 12.1**

import 'package:glados/glados.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_app_icons_generator/src/core/default_image_processor.dart';

/// Holds a test case with source dimensions and target dimensions.
class ResizeTestCase {
  const ResizeTestCase({
    required this.sourceWidth,
    required this.sourceHeight,
    required this.targetWidth,
    required this.targetHeight,
  });

  final int sourceWidth;
  final int sourceHeight;
  final int targetWidth;
  final int targetHeight;

  @override
  String toString() =>
      'ResizeTestCase(source: ${sourceWidth}x$sourceHeight, target: ${targetWidth}x$targetHeight)';
}

extension ResizeGenerators on Any {
  /// Generates a ResizeTestCase with valid source (>= 1024) and target dimensions.
  Generator<ResizeTestCase> get resizeTestCase {
    return simple(
      generate: (random, size) {
        // Source dimensions: 1024 to 2048
        final sourceWidth = 1024 + random.nextInt(1025);
        final sourceHeight = 1024 + random.nextInt(1025);

        // Target dimensions: 1 to 512
        final targetWidth = 1 + random.nextInt(512);
        final targetHeight = 1 + random.nextInt(512);

        return ResizeTestCase(
          sourceWidth: sourceWidth,
          sourceHeight: sourceHeight,
          targetWidth: targetWidth,
          targetHeight: targetHeight,
        );
      },
      shrink: (input) sync* {
        // Shrink toward smallest valid case
        if (input.sourceWidth > 1024) {
          yield ResizeTestCase(
            sourceWidth: 1024,
            sourceHeight: input.sourceHeight,
            targetWidth: input.targetWidth,
            targetHeight: input.targetHeight,
          );
        }
        if (input.sourceHeight > 1024) {
          yield ResizeTestCase(
            sourceWidth: input.sourceWidth,
            sourceHeight: 1024,
            targetWidth: input.targetWidth,
            targetHeight: input.targetHeight,
          );
        }
        if (input.targetWidth > 1) {
          yield ResizeTestCase(
            sourceWidth: input.sourceWidth,
            sourceHeight: input.sourceHeight,
            targetWidth: 1,
            targetHeight: input.targetHeight,
          );
        }
        if (input.targetHeight > 1) {
          yield ResizeTestCase(
            sourceWidth: input.sourceWidth,
            sourceHeight: input.sourceHeight,
            targetWidth: input.targetWidth,
            targetHeight: 1,
          );
        }
      },
    );
  }
}

void main() {
  group('Property 6: Resize Produces Exact Target Dimensions', () {
    final processor = DefaultImageProcessor();

    Glados(any.resizeTestCase, ExploreConfig(numRuns: 100))
        .test('resize output has exactly the requested dimensions',
            (testCase) {
      // Create a source image with the generated dimensions.
      final source = img.Image(
        width: testCase.sourceWidth,
        height: testCase.sourceHeight,
      );

      // Perform the resize.
      final result = processor.resize(
        source,
        testCase.targetWidth,
        testCase.targetHeight,
      );

      // Verify exact target dimensions.
      expect(result.width, equals(testCase.targetWidth),
          reason:
              'Output width should be exactly ${testCase.targetWidth}, '
              'got ${result.width} '
              '(source: ${testCase.sourceWidth}x${testCase.sourceHeight})');
      expect(result.height, equals(testCase.targetHeight),
          reason:
              'Output height should be exactly ${testCase.targetHeight}, '
              'got ${result.height} '
              '(source: ${testCase.sourceWidth}x${testCase.sourceHeight})');
    });
  });
}
