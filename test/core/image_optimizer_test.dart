import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:test/test.dart';

import '../../lib/src/core/default_image_optimizer.dart';

void main() {
  late DefaultImageOptimizer optimizer;

  setUp(() {
    optimizer = const DefaultImageOptimizer();
  });

  group('DefaultImageOptimizer', () {
    group('encodePng', () {
      test('encodes a simple image to valid PNG bytes', () {
        final image = img.Image(width: 64, height: 64);
        // Fill with some color
        img.fill(image, color: img.ColorRgba8(255, 0, 0, 255));

        final bytes = optimizer.encodePng(image);

        expect(bytes, isNotEmpty);
        // PNG magic bytes: 137 80 78 71 13 10 26 10
        expect(bytes[0], equals(137));
        expect(bytes[1], equals(80)); // 'P'
        expect(bytes[2], equals(78)); // 'N'
        expect(bytes[3], equals(71)); // 'G'
      });

      test('lossless: decode produces pixel-identical image', () {
        final image = img.Image(width: 32, height: 32);
        img.fill(image, color: img.ColorRgba8(100, 150, 200, 255));

        final bytes = optimizer.encodePng(image);
        final decoded = img.decodePng(Uint8List.fromList(bytes))!;

        expect(decoded.width, equals(32));
        expect(decoded.height, equals(32));
        // Verify pixel values are preserved
        final pixel = decoded.getPixel(0, 0);
        expect(pixel.r.toInt(), equals(100));
        expect(pixel.g.toInt(), equals(150));
        expect(pixel.b.toInt(), equals(200));
      });

      test('respects compression level parameter', () {
        final image = img.Image(width: 128, height: 128);
        img.fill(image, color: img.ColorRgba8(50, 100, 150, 255));

        final bytesLow = optimizer.encodePng(image, compressionLevel: 0);
        final bytesHigh = optimizer.encodePng(image, compressionLevel: 9);

        // Higher compression should produce smaller or equal output
        expect(bytesHigh.length, lessThanOrEqualTo(bytesLow.length));
      });

      test('uses default compression level 6', () {
        final image = img.Image(width: 16, height: 16);
        img.fill(image, color: img.ColorRgba8(0, 255, 0, 255));

        // Should not throw with default parameter
        final bytes = optimizer.encodePng(image);
        expect(bytes, isNotEmpty);
      });
    });

    group('encodeIco', () {
      test('encodes a multi-size ICO file', () {
        final image = img.Image(width: 256, height: 256);
        img.fill(image, color: img.ColorRgba8(0, 0, 255, 255));

        final sizes = [16, 32, 48, 64, 128, 256];
        final bytes = optimizer.encodeIco(image, sizes);

        expect(bytes, isNotEmpty);
        // ICO header: reserved (2 bytes) + type (2 bytes) + count (2 bytes)
        // Reserved should be 0
        expect(bytes[0], equals(0));
        expect(bytes[1], equals(0));
        // Type should be 1 (ICO)
        expect(bytes[2], equals(1));
        expect(bytes[3], equals(0));
        // Count should be 6 (little-endian)
        expect(bytes[4], equals(6));
        expect(bytes[5], equals(0));
      });

      test('encodes single size ICO', () {
        final image = img.Image(width: 64, height: 64);
        img.fill(image, color: img.ColorRgba8(128, 128, 128, 255));

        final bytes = optimizer.encodeIco(image, [32]);

        expect(bytes, isNotEmpty);
        // Count should be 1
        expect(bytes[4], equals(1));
        expect(bytes[5], equals(0));
      });

      test('throws ArgumentError for empty sizes list', () {
        final image = img.Image(width: 64, height: 64);

        expect(
          () => optimizer.encodeIco(image, []),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError for size > 256', () {
        final image = img.Image(width: 512, height: 512);

        expect(
          () => optimizer.encodeIco(image, [16, 32, 512]),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError for size < 1', () {
        final image = img.Image(width: 64, height: 64);

        expect(
          () => optimizer.encodeIco(image, [0, 16, 32]),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('produces valid ICO that can be decoded', () {
        final image = img.Image(width: 256, height: 256);
        img.fill(image, color: img.ColorRgba8(255, 128, 0, 255));

        final sizes = [16, 32, 48];
        final bytes = optimizer.encodeIco(image, sizes);

        // Decode the ICO back and verify frames
        final decoded = img.decodeIco(Uint8List.fromList(bytes));
        expect(decoded, isNotNull);
        // The first frame should be present
        expect(decoded!.width, equals(16));
        expect(decoded.height, equals(16));
      });
    });
  });
}
