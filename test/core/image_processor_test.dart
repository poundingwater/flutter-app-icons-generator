import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:test/test.dart';

import 'package:flutter_app_icons/src/core/default_image_processor.dart';
import 'package:flutter_app_icons/src/shared/exceptions.dart';

void main() {
  late DefaultImageProcessor processor;
  late Directory tempDir;

  setUp(() {
    processor = DefaultImageProcessor();
    tempDir = Directory.systemTemp.createTempSync('image_processor_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  /// Writes a PNG image of given dimensions to disk and returns the path.
  String createTestPng(int width, int height, {String name = 'test.png'}) {
    final image = img.Image(width: width, height: height, numChannels: 4);
    img.fill(image, color: img.ColorRgba8(100, 150, 200, 255));
    final bytes = img.encodePng(image);
    final path = '${tempDir.path}/$name';
    File(path).writeAsBytesSync(bytes);
    return path;
  }

  /// Writes a JPEG image of given dimensions to disk and returns the path.
  String createTestJpeg(int width, int height, {String name = 'test.jpg'}) {
    final image = img.Image(width: width, height: height, numChannels: 3);
    img.fill(image, color: img.ColorRgb8(100, 150, 200));
    final bytes = img.encodeJpg(image);
    final path = '${tempDir.path}/$name';
    File(path).writeAsBytesSync(bytes);
    return path;
  }

  group('loadAndValidate', () {
    test('loads a valid 1024x1024 PNG image', () async {
      final path = createTestPng(1024, 1024);
      final result = await processor.loadAndValidate(path);
      expect(result.width, 1024);
      expect(result.height, 1024);
    });

    test('loads a valid 1024x1024 JPEG image', () async {
      final path = createTestJpeg(1024, 1024);
      final result = await processor.loadAndValidate(path);
      expect(result.width, 1024);
      expect(result.height, 1024);
    });

    test('loads a valid image larger than 1024x1024', () async {
      final path = createTestPng(2048, 2048, name: 'large.png');
      final result = await processor.loadAndValidate(path);
      expect(result.width, 2048);
      expect(result.height, 2048);
    });

    test('throws ImageNotFoundException for non-existent file', () async {
      expect(
        () => processor.loadAndValidate('/non/existent/path.png'),
        throwsA(isA<ImageNotFoundException>()),
      );
    });

    test('throws ImageFormatException for unsupported extension', () async {
      final path = '${tempDir.path}/test.bmp';
      // Write a valid BMP file.
      final image = img.Image(width: 1024, height: 1024);
      File(path).writeAsBytesSync(img.encodeBmp(image));

      expect(
        () => processor.loadAndValidate(path),
        throwsA(isA<ImageFormatException>()),
      );
    });

    test('throws ImageDimensionException for image below 1024x1024', () async {
      final path = createTestPng(512, 512, name: 'small.png');
      expect(
        () => processor.loadAndValidate(path),
        throwsA(isA<ImageDimensionException>()),
      );
    });

    test('throws ImageDimensionException when width is below 1024', () async {
      final path = createTestPng(512, 1024, name: 'narrow.png');
      expect(
        () => processor.loadAndValidate(path),
        throwsA(isA<ImageDimensionException>()),
      );
    });

    test('throws ImageDimensionException when height is below 1024', () async {
      final path = createTestPng(1024, 512, name: 'short.png');
      expect(
        () => processor.loadAndValidate(path),
        throwsA(isA<ImageDimensionException>()),
      );
    });
  });

  group('resize', () {
    test('resizes image to exact target dimensions', () {
      final source = img.Image(width: 1024, height: 1024);
      final result = processor.resize(source, 48, 48);
      expect(result.width, 48);
      expect(result.height, 48);
    });

    test('resizes to non-square dimensions', () {
      final source = img.Image(width: 1024, height: 1024);
      final result = processor.resize(source, 192, 96);
      expect(result.width, 192);
      expect(result.height, 96);
    });

    test('resizes larger image down to small size', () {
      final source = img.Image(width: 2048, height: 2048);
      final result = processor.resize(source, 16, 16);
      expect(result.width, 16);
      expect(result.height, 16);
    });
  });

  group('removeAlpha', () {
    test('produces image where all pixels have alpha = 255', () {
      final source = img.Image(width: 10, height: 10, numChannels: 4);
      // Fill with semi-transparent red.
      for (final pixel in source) {
        pixel.r = 255;
        pixel.g = 0;
        pixel.b = 0;
        pixel.a = 128;
      }

      final result = processor.removeAlpha(source);

      for (final pixel in result) {
        expect(pixel.a.toInt(), 255);
      }
    });

    test('preserves opaque pixels without modification', () {
      final source = img.Image(width: 4, height: 4, numChannels: 4);
      for (final pixel in source) {
        pixel.r = 100;
        pixel.g = 150;
        pixel.b = 200;
        pixel.a = 255;
      }

      final result = processor.removeAlpha(source);

      for (final pixel in result) {
        expect(pixel.r.toInt(), 100);
        expect(pixel.g.toInt(), 150);
        expect(pixel.b.toInt(), 200);
        expect(pixel.a.toInt(), 255);
      }
    });

    test('fully transparent pixels become white', () {
      final source = img.Image(width: 4, height: 4, numChannels: 4);
      for (final pixel in source) {
        pixel.r = 0;
        pixel.g = 0;
        pixel.b = 0;
        pixel.a = 0;
      }

      final result = processor.removeAlpha(source);

      for (final pixel in result) {
        expect(pixel.r.toInt(), 255);
        expect(pixel.g.toInt(), 255);
        expect(pixel.b.toInt(), 255);
        expect(pixel.a.toInt(), 255);
      }
    });

    test('output has same dimensions as input', () {
      final source = img.Image(width: 100, height: 200, numChannels: 4);
      final result = processor.removeAlpha(source);
      expect(result.width, 100);
      expect(result.height, 200);
    });
  });

  group('composite', () {
    test('layers foreground onto background', () {
      final background = img.Image(width: 100, height: 100, numChannels: 4);
      img.fill(background, color: img.ColorRgba8(255, 0, 0, 255));

      final foreground = img.Image(width: 100, height: 100, numChannels: 4);
      img.fill(foreground, color: img.ColorRgba8(0, 0, 255, 255));

      final result = processor.composite(foreground, background);

      // Fully opaque foreground should completely cover the background.
      final pixel = result.getPixel(50, 50);
      expect(pixel.r.toInt(), 0);
      expect(pixel.g.toInt(), 0);
      expect(pixel.b.toInt(), 255);
    });

    test('does not mutate the original background', () {
      final background = img.Image(width: 50, height: 50, numChannels: 4);
      img.fill(background, color: img.ColorRgba8(255, 0, 0, 255));

      final foreground = img.Image(width: 50, height: 50, numChannels: 4);
      img.fill(foreground, color: img.ColorRgba8(0, 255, 0, 255));

      processor.composite(foreground, background);

      // Original background should still be red.
      final bgPixel = background.getPixel(25, 25);
      expect(bgPixel.r.toInt(), 255);
      expect(bgPixel.g.toInt(), 0);
      expect(bgPixel.b.toInt(), 0);
    });

    test('output has same dimensions as background', () {
      final background = img.Image(width: 200, height: 150, numChannels: 4);
      final foreground = img.Image(width: 200, height: 150, numChannels: 4);

      final result = processor.composite(foreground, background);
      expect(result.width, 200);
      expect(result.height, 150);
    });

    test('semi-transparent foreground blends with background', () {
      final background = img.Image(width: 10, height: 10, numChannels: 4);
      img.fill(background, color: img.ColorRgba8(255, 0, 0, 255));

      final foreground = img.Image(width: 10, height: 10, numChannels: 4);
      img.fill(foreground, color: img.ColorRgba8(0, 0, 255, 128));

      final result = processor.composite(foreground, background);
      final pixel = result.getPixel(5, 5);

      // Should be a blend of red background and semi-transparent blue.
      // Blue should be present, red should be partially visible.
      expect(pixel.b.toInt(), greaterThan(0));
      expect(pixel.r.toInt(), greaterThan(0));
    });
  });
}
