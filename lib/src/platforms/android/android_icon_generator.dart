import 'dart:io';

import 'package:image/image.dart' as img;

import 'package:flutter_app_icons/src/config/config_model.dart';
import 'package:flutter_app_icons/src/core/default_image_optimizer.dart';
import 'package:flutter_app_icons/src/core/default_image_processor.dart';
import 'package:flutter_app_icons/src/core/icon_generator.dart';
import 'package:flutter_app_icons/src/shared/constants.dart';

/// Android-specific icon generator.
///
/// Produces standard launcher icons at all 5 density buckets and,
/// when an adaptive icon configuration is present, generates foreground
/// layers at adaptive sizes plus the XML resource descriptor.
class AndroidIconGenerator implements IconGenerator {
  /// Creates an [AndroidIconGenerator] with the given image processor
  /// and optimizer.
  AndroidIconGenerator({
    DefaultImageProcessor? imageProcessor,
    DefaultImageOptimizer? imageOptimizer,
  })  : _imageProcessor = imageProcessor ?? DefaultImageProcessor(),
        _imageOptimizer = imageOptimizer ?? const DefaultImageOptimizer();

  final DefaultImageProcessor _imageProcessor;
  final DefaultImageOptimizer _imageOptimizer;

  /// Base resource path relative to the project root.
  static const _resPath = 'android/app/src/main/res';

  @override
  Future<void> generate(IconConfig config, String projectRoot) async {
    if (config.isAdaptive) {
      await _generateAdaptiveIcons(config, projectRoot);
    } else if (config.imagePath != null) {
      await _generateStandardIcons(config.imagePath!, projectRoot);
    }
  }

  /// Generates standard `ic_launcher.png` icons at each density bucket.
  Future<void> _generateStandardIcons(
    String imagePath,
    String projectRoot,
  ) async {
    final sourceImage = await _imageProcessor.loadAndValidate(imagePath);
    final opaqueImage = _imageProcessor.removeAlpha(sourceImage);

    for (final entry in AndroidSizes.densityBuckets.entries) {
      final bucketDir = entry.key;
      final size = entry.value;

      final resized = _imageProcessor.resize(opaqueImage, size, size);
      final pngBytes = _imageOptimizer.encodePng(resized);

      final outputDir = Directory('$projectRoot/$_resPath/$bucketDir');
      if (!outputDir.existsSync()) {
        outputDir.createSync(recursive: true);
      }

      final outputFile = File('${outputDir.path}/ic_launcher.png');
      outputFile.writeAsBytesSync(pngBytes);
    }
  }

  /// Generates adaptive icons: standard launcher icons (composited),
  /// foreground layers, background layers (if image), and the XML descriptor.
  Future<void> _generateAdaptiveIcons(
    IconConfig config,
    String projectRoot,
  ) async {
    final foregroundImage =
        await _imageProcessor.loadAndValidate(config.foregroundPath!);

    // Generate standard icons using a composited version (foreground on background).
    final compositedImage =
        await _createCompositedImage(foregroundImage, config, projectRoot);
    final opaqueComposited = _imageProcessor.removeAlpha(compositedImage);

    for (final entry in AndroidSizes.densityBuckets.entries) {
      final bucketDir = entry.key;
      final size = entry.value;

      final resized = _imageProcessor.resize(opaqueComposited, size, size);
      final pngBytes = _imageOptimizer.encodePng(resized);

      final outputDir = Directory('$projectRoot/$_resPath/$bucketDir');
      if (!outputDir.existsSync()) {
        outputDir.createSync(recursive: true);
      }

      final outputFile = File('${outputDir.path}/ic_launcher.png');
      outputFile.writeAsBytesSync(pngBytes);
    }

    // Generate foreground at adaptive sizes.
    for (final entry in AndroidSizes.adaptiveSizes.entries) {
      final bucketDir = entry.key;
      final size = entry.value;

      final resized = _imageProcessor.resize(foregroundImage, size, size);
      final pngBytes = _imageOptimizer.encodePng(resized);

      final outputDir = Directory('$projectRoot/$_resPath/$bucketDir');
      if (!outputDir.existsSync()) {
        outputDir.createSync(recursive: true);
      }

      final outputFile = File('${outputDir.path}/ic_launcher_foreground.png');
      outputFile.writeAsBytesSync(pngBytes);
    }

    // Generate background images at adaptive sizes if background is an image.
    if (config.background is BackgroundImage) {
      final bgConfig = config.background! as BackgroundImage;
      final bgImage =
          await _imageProcessor.loadAndValidate(bgConfig.imagePath);

      for (final entry in AndroidSizes.adaptiveSizes.entries) {
        final bucketDir = entry.key;
        final size = entry.value;

        final resized = _imageProcessor.resize(bgImage, size, size);
        final pngBytes = _imageOptimizer.encodePng(resized);

        final outputDir = Directory('$projectRoot/$_resPath/$bucketDir');
        if (!outputDir.existsSync()) {
          outputDir.createSync(recursive: true);
        }

        final outputFile =
            File('${outputDir.path}/ic_launcher_background.png');
        outputFile.writeAsBytesSync(pngBytes);
      }
    }

    // Generate the adaptive icon XML descriptor.
    _generateAdaptiveXml(config, projectRoot);

    // Generate colors.xml if background is a color.
    if (config.background is BackgroundColor) {
      _generateColorsXml(config.background! as BackgroundColor, projectRoot);
    }
  }

  /// Creates a composited image by layering the foreground onto the background.
  Future<img.Image> _createCompositedImage(
    img.Image foregroundImage,
    IconConfig config,
    String projectRoot,
  ) async {
    final background = config.background!;

    if (background is BackgroundImage) {
      final bgImage =
          await _imageProcessor.loadAndValidate(background.imagePath);
      // Resize background to match foreground dimensions for compositing.
      final resizedBg = _imageProcessor.resize(
        bgImage,
        foregroundImage.width,
        foregroundImage.height,
      );
      return _imageProcessor.composite(foregroundImage, resizedBg);
    } else if (background is BackgroundColor) {
      // Create a solid color background image.
      final bgImage = _createColorBackground(
        background.hexColor,
        foregroundImage.width,
        foregroundImage.height,
      );
      return _imageProcessor.composite(foregroundImage, bgImage);
    }

    // Fallback: return foreground as-is (should not happen with valid config).
    return foregroundImage;
  }

  /// Creates a solid color image from a hex color string.
  img.Image _createColorBackground(String hexColor, int width, int height) {
    final color = _parseHexColor(hexColor);
    final image = img.Image(width: width, height: height, numChannels: 4);
    img.fill(image, color: color);
    return image;
  }

  /// Parses a hex color string (e.g., "#4CAF50" or "#FF4CAF50") into an
  /// [img.Color].
  img.Color _parseHexColor(String hexColor) {
    final hex = hexColor.replaceFirst('#', '');

    // Handle 6-digit (RGB) and 8-digit (ARGB) hex strings.
    int r, g, b, a;
    if (hex.length == 6) {
      a = 255;
      r = int.parse(hex.substring(0, 2), radix: 16);
      g = int.parse(hex.substring(2, 4), radix: 16);
      b = int.parse(hex.substring(4, 6), radix: 16);
    } else if (hex.length == 8) {
      a = int.parse(hex.substring(0, 2), radix: 16);
      r = int.parse(hex.substring(2, 4), radix: 16);
      g = int.parse(hex.substring(4, 6), radix: 16);
      b = int.parse(hex.substring(6, 8), radix: 16);
    } else {
      // Default to white if the hex string is invalid.
      r = 255;
      g = 255;
      b = 255;
      a = 255;
    }

    return img.ColorRgba8(r, g, b, a);
  }

  /// Generates the `mipmap-anydpi-v26/ic_launcher.xml` adaptive icon descriptor.
  void _generateAdaptiveXml(IconConfig config, String projectRoot) {
    final outputDir =
        Directory('$projectRoot/$_resPath/mipmap-anydpi-v26');
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    final backgroundDrawable = config.background is BackgroundColor
        ? '@color/ic_launcher_background'
        : '@mipmap/ic_launcher_background';

    final xml = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="$backgroundDrawable"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
''';

    final outputFile = File('${outputDir.path}/ic_launcher.xml');
    outputFile.writeAsStringSync(xml);
  }

  /// Generates or updates `values/colors.xml` with the adaptive icon
  /// background color.
  void _generateColorsXml(BackgroundColor background, String projectRoot) {
    final valuesDir = Directory('$projectRoot/$_resPath/values');
    if (!valuesDir.existsSync()) {
      valuesDir.createSync(recursive: true);
    }

    final colorsFile = File('${valuesDir.path}/colors.xml');
    final colorValue = background.hexColor.startsWith('#')
        ? background.hexColor
        : '#${background.hexColor}';

    if (colorsFile.existsSync()) {
      // Update existing colors.xml — add or replace the color entry.
      final existingContent = colorsFile.readAsStringSync();
      final colorEntry =
          '    <color name="ic_launcher_background">$colorValue</color>';

      final updatedContent =
          existingContent.contains('name="ic_launcher_background"')
              ? existingContent.replaceFirst(
                  RegExp(
                      r'<color name="ic_launcher_background">.*?</color>'),
                  '<color name="ic_launcher_background">$colorValue</color>',
                )
              : existingContent.replaceFirst(
                  '</resources>',
                  '$colorEntry\n</resources>',
                );

      colorsFile.writeAsStringSync(updatedContent);
    } else {
      // Create a new colors.xml file.
      final xml = '''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">$colorValue</color>
</resources>
''';
      colorsFile.writeAsStringSync(xml);
    }
  }
}
