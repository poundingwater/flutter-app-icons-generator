// Feature: flutter-app-icons-generator, Property 4: Lossless PNG Compression Preserves Pixels
//
// For any image, encoding it to PNG with lossless compression and then
// decoding the resulting bytes SHALL produce an image that is pixel-identical
// to the input (same dimensions, same pixel values at every coordinate).
//
// **Validates: Requirements 5.1**

import 'dart:typed_data';

import 'package:glados/glados.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_app_icons_generator/src/core/default_image_optimizer.dart';

/// Custom generator for small random images (4x4 to 32x32) with random RGBA pixels.
extension ImageGenerators on Any {
  /// Generates a random image with dimensions between 4x4 and 32x32,
  /// filled with random RGBA pixel values.
  Generator<img.Image> get randomImage {
    return simple(
      generate: (random, size) {
        // Generate dimensions between 4 and 32
        final width = random.nextInt(29) + 4; // 4..32
        final height = random.nextInt(29) + 4; // 4..32

        final image = img.Image(width: width, height: height, numChannels: 4);

        // Fill with random RGBA pixel values
        for (var y = 0; y < height; y++) {
          for (var x = 0; x < width; x++) {
            final r = random.nextInt(256);
            final g = random.nextInt(256);
            final b = random.nextInt(256);
            final a = random.nextInt(256);
            image.setPixelRgba(x, y, r, g, b, a);
          }
        }

        return image;
      },
      shrink: (input) sync* {
        // Shrink toward a minimal 4x4 solid-color image
        if (input.width > 4 || input.height > 4) {
          final small = img.Image(width: 4, height: 4, numChannels: 4);
          for (var y = 0; y < 4; y++) {
            for (var x = 0; x < 4; x++) {
              small.setPixelRgba(x, y, 128, 128, 128, 255);
            }
          }
          yield small;
        }
      },
    );
  }
}

void main() {
  group('Property 4: Lossless PNG Compression Preserves Pixels', () {
    Glados(any.randomImage, ExploreConfig(numRuns: 100)).test(
      'encode to PNG then decode back produces pixel-identical output',
      (originalImage) {
        final optimizer = const DefaultImageOptimizer();

        // Encode the image to PNG using lossless compression (default level)
        final pngBytes = optimizer.encodePng(originalImage);

        // Decode the PNG bytes back to an image
        final decoded = img.decodePng(Uint8List.fromList(pngBytes));

        // Verify decoded image is not null
        expect(decoded, isNotNull, reason: 'Decoded image should not be null');

        // Verify dimensions are preserved
        expect(decoded!.width, equals(originalImage.width),
            reason: 'Width should be preserved after PNG round-trip');
        expect(decoded.height, equals(originalImage.height),
            reason: 'Height should be preserved after PNG round-trip');

        // Verify every pixel is identical
        for (var y = 0; y < originalImage.height; y++) {
          for (var x = 0; x < originalImage.width; x++) {
            final originalPixel = originalImage.getPixel(x, y);
            final decodedPixel = decoded.getPixel(x, y);

            expect(decodedPixel.r.toInt(), equals(originalPixel.r.toInt()),
                reason: 'Red channel mismatch at ($x, $y)');
            expect(decodedPixel.g.toInt(), equals(originalPixel.g.toInt()),
                reason: 'Green channel mismatch at ($x, $y)');
            expect(decodedPixel.b.toInt(), equals(originalPixel.b.toInt()),
                reason: 'Blue channel mismatch at ($x, $y)');
            expect(decodedPixel.a.toInt(), equals(originalPixel.a.toInt()),
                reason: 'Alpha channel mismatch at ($x, $y)');
          }
        }
      },
    );
  });
}
