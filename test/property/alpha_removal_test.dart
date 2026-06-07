// Feature: flutter-app-icons, Property 3: Alpha Channel Removal Produces Opaque Output
//
// For any RGBA image (with arbitrary pixel values including varying alpha),
// applying the alpha removal function (compositing onto a white background)
// SHALL produce an output image where every pixel has full opacity (alpha = 255)
// and the RGB values match the expected alpha-composite formula:
// output_channel = (source_channel * source_alpha + 255 * (255 - source_alpha)) / 255.
//
// **Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.5, 8.3, 9.3**

import 'package:glados/glados.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_app_icons/src/core/default_image_processor.dart';

/// Represents a test image with known pixel data for verification.
class TestImage {
  TestImage({required this.width, required this.height, required this.pixels});

  final int width;
  final int height;
  final List<List<int>> pixels; // Each pixel is [r, g, b, a]

  /// Converts to an img.Image with RGBA pixel data.
  img.Image toImage() {
    final image = img.Image(
      width: width,
      height: height,
      numChannels: 4,
    );

    var i = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final pixel = pixels[i];
        image.setPixelRgba(x, y, pixel[0], pixel[1], pixel[2], pixel[3]);
        i++;
      }
    }

    return image;
  }
}

/// Custom generators for RGBA image data.
extension ImageGenerators on Any {
  /// Generates a random image dimension between 4 and 16.
  Generator<int> get imageDimension {
    return simple(
      generate: (random, size) => random.nextInt(13) + 4, // 4 to 16
      shrink: (input) sync* {
        if (input > 4) yield 4;
      },
    );
  }

  /// Generates a random channel value (0-255).
  Generator<int> get channelValue {
    return simple(
      generate: (random, size) => random.nextInt(256),
      shrink: (input) sync* {
        if (input > 0) yield 0;
        if (input < 255 && input > 0) yield 255;
      },
    );
  }

  /// Generates a random RGBA pixel [r, g, b, a].
  Generator<List<int>> get rgbaPixel {
    return simple(
      generate: (random, size) => [
        random.nextInt(256), // r
        random.nextInt(256), // g
        random.nextInt(256), // b
        random.nextInt(256), // a
      ],
      shrink: (input) sync* {
        // Shrink toward fully opaque black
        yield [0, 0, 0, 255];
        // Shrink toward fully transparent
        if (input[3] != 0) yield [input[0], input[1], input[2], 0];
      },
    );
  }

  /// Generates a random test image with dimensions between 4x4 and 16x16.
  Generator<TestImage> get testImage {
    return simple(
      generate: (random, size) {
        final width = random.nextInt(13) + 4; // 4 to 16
        final height = random.nextInt(13) + 4; // 4 to 16
        final pixelCount = width * height;
        final pixels = <List<int>>[];
        for (var i = 0; i < pixelCount; i++) {
          pixels.add([
            random.nextInt(256), // r
            random.nextInt(256), // g
            random.nextInt(256), // b
            random.nextInt(256), // a
          ]);
        }
        return TestImage(width: width, height: height, pixels: pixels);
      },
      shrink: (input) sync* {
        // Shrink toward a 4x4 image with all opaque black pixels
        if (input.width > 4 || input.height > 4) {
          final pixels = List.generate(16, (_) => [0, 0, 0, 255]);
          yield TestImage(width: 4, height: 4, pixels: pixels);
        }
      },
    );
  }
}

/// Computes the expected alpha-composite result for a single channel.
///
/// Formula: (source_channel * source_alpha + 255 * (255 - source_alpha)) / 255
/// This matches compositing the source pixel over a white (255) background.
int expectedComposite(int sourceChannel, int sourceAlpha) {
  return ((sourceChannel * sourceAlpha) + (255 * (255 - sourceAlpha))) ~/ 255;
}

void main() {
  group('Property 3: Alpha Channel Removal Produces Opaque Output', () {
    final processor = DefaultImageProcessor();

    Glados(any.testImage, ExploreConfig(numRuns: 100)).test(
      'removeAlpha produces fully opaque output with correct composite values',
      (testImage) {
        final source = testImage.toImage();
        final result = processor.removeAlpha(source);

        // Verify output dimensions match input
        expect(result.width, equals(source.width),
            reason: 'Output width must match input width');
        expect(result.height, equals(source.height),
            reason: 'Output height must match input height');

        // Verify every pixel
        var pixelIndex = 0;
        for (var y = 0; y < result.height; y++) {
          for (var x = 0; x < result.width; x++) {
            final outputPixel = result.getPixel(x, y);
            final sourcePixelData = testImage.pixels[pixelIndex];
            final srcR = sourcePixelData[0];
            final srcG = sourcePixelData[1];
            final srcB = sourcePixelData[2];
            final srcA = sourcePixelData[3];

            // Property: All output pixels must be fully opaque
            expect(outputPixel.a.toInt(), equals(255),
                reason:
                    'Pixel ($x, $y) alpha must be 255, got ${outputPixel.a}');

            // Property: RGB values must match the alpha-composite formula
            // with ±1 tolerance for rounding differences
            final expectedR = expectedComposite(srcR, srcA);
            final expectedG = expectedComposite(srcG, srcA);
            final expectedB = expectedComposite(srcB, srcA);

            expect(
              (outputPixel.r.toInt() - expectedR).abs() <= 1,
              isTrue,
              reason:
                  'Pixel ($x, $y) R: expected $expectedR ±1, got ${outputPixel.r.toInt()} '
                  '(src: r=$srcR, a=$srcA)',
            );
            expect(
              (outputPixel.g.toInt() - expectedG).abs() <= 1,
              isTrue,
              reason:
                  'Pixel ($x, $y) G: expected $expectedG ±1, got ${outputPixel.g.toInt()} '
                  '(src: g=$srcG, a=$srcA)',
            );
            expect(
              (outputPixel.b.toInt() - expectedB).abs() <= 1,
              isTrue,
              reason:
                  'Pixel ($x, $y) B: expected $expectedB ±1, got ${outputPixel.b.toInt()} '
                  '(src: b=$srcB, a=$srcA)',
            );

            pixelIndex++;
          }
        }
      },
    );
  });
}
