import 'dart:io';

import 'package:image/image.dart' as img;

import 'package:flutter_app_icons_generator/src/config/config_model.dart';
import 'package:flutter_app_icons_generator/src/core/default_image_optimizer.dart';
import 'package:flutter_app_icons_generator/src/core/default_image_processor.dart';
import 'package:flutter_app_icons_generator/src/core/icon_generator.dart';
import 'package:flutter_app_icons_generator/src/shared/constants.dart';

/// Android-specific icon generator.
///
/// Produces standard launcher icons at all 5 density buckets and,
/// when a background is provided (adaptive icon), generates foreground
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
  Future<void> generate(ResolvedIconConfig config, String projectRoot) async {
    if (config.isAdaptive) {
      await _generateAdaptiveIcons(config, projectRoot);
    } else if (config.foregroundPath != null) {
      await _generateStandardIcons(config.foregroundPath!, projectRoot);
    }
  }

  /// Generates standard `ic_launcher.png` icons at each density bucket.
  Future<void> _generateStandardIcons(
    String imagePath,
    String projectRoot,
  ) async {
    final sourceImage = await _imageProcessor.loadAndValidate(imagePath);
    final opaqueImage = _imageProcessor.hasTransparency(sourceImage)
        ? _imageProcessor.removeAlpha(sourceImage)
        : sourceImage;

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
    ResolvedIconConfig config,
    String projectRoot,
  ) async {
    final foregroundImage =
        await _imageProcessor.loadAndValidate(config.foregroundPath!);

    // Generate standard icons using a composited version.
    final compositedImage =
        await _createCompositedImage(foregroundImage, config);
    final opaqueComposited = _imageProcessor.hasTransparency(compositedImage)
        ? _imageProcessor.removeAlpha(compositedImage)
        : compositedImage;

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

    // Generate foreground at adaptive sizes with safe-zone padding.
    // Android adaptive icons use a 108dp canvas where only the center 72dp
    // (66.67%) is the guaranteed visible "safe zone". The outer 18dp on each
    // side is the parallax/crop area. We place the foreground within the safe
    // zone so it doesn't get clipped by device masks.
    for (final entry in AndroidSizes.adaptiveSizes.entries) {
      final bucketDir = entry.key;
      final canvasSize = entry.value;

      // The safe zone is 72/108 = 2/3 of the canvas.
      final safeZoneSize = (canvasSize * 72) ~/ 108;

      // Resize the foreground to fit within the safe zone.
      final resizedForeground =
          _imageProcessor.resize(foregroundImage, safeZoneSize, safeZoneSize);

      // Create a transparent canvas at the full adaptive size.
      final canvas = img.Image(
        width: canvasSize,
        height: canvasSize,
        numChannels: 4,
      );

      // Center the foreground on the canvas (offset = 18dp scaled).
      final offset = (canvasSize - safeZoneSize) ~/ 2;
      img.compositeImage(canvas, resizedForeground, dstX: offset, dstY: offset);

      final pngBytes = _imageOptimizer.encodePng(canvas);

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
      final bgImage = await _imageProcessor.loadAndValidate(bgConfig.imagePath);

      for (final entry in AndroidSizes.adaptiveSizes.entries) {
        final bucketDir = entry.key;
        final size = entry.value;

        final resized = _imageProcessor.resize(bgImage, size, size);
        final pngBytes = _imageOptimizer.encodePng(resized);

        final outputDir = Directory('$projectRoot/$_resPath/$bucketDir');
        if (!outputDir.existsSync()) {
          outputDir.createSync(recursive: true);
        }

        final outputFile = File('${outputDir.path}/ic_launcher_background.png');
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

  /// Creates a composited image by layering the foreground onto the background
  /// with safe-zone padding (72/108 ratio).
  Future<img.Image> _createCompositedImage(
    img.Image foregroundImage,
    ResolvedIconConfig config,
  ) async {
    final canvasSize = foregroundImage.width;
    final background = config.background!;

    final img.Image bgImage;
    if (background is BackgroundImage) {
      bgImage = await _imageProcessor.loadAndValidate(background.imagePath);
    } else if (background is BackgroundColor) {
      bgImage = _createColorBackground(
        background.hexColor,
        canvasSize,
        canvasSize,
      );
    } else {
      return foregroundImage;
    }

    // Resize background to canvas size.
    final resizedBg = _imageProcessor.resize(bgImage, canvasSize, canvasSize);

    // Scale foreground to 72/108 of canvas (safe zone ratio).
    final contentSize = (canvasSize * 72) ~/ 108;
    final resizedFg = _imageProcessor.resize(
      foregroundImage,
      contentSize,
      contentSize,
    );

    // Create canvas with background, then overlay centered foreground.
    final canvas = resizedBg.clone();
    final offset = (canvasSize - contentSize) ~/ 2;
    img.compositeImage(canvas, resizedFg, dstX: offset, dstY: offset);

    return canvas;
  }

  /// Creates a solid color image from a hex color string.
  img.Image _createColorBackground(String hexColor, int width, int height) {
    final color = _parseHexColor(hexColor);
    final image = img.Image(width: width, height: height, numChannels: 4);
    img.fill(image, color: color);
    return image;
  }

  /// Parses a hex color string into an [img.Color].
  img.Color _parseHexColor(String hexColor) {
    final hex = hexColor.replaceFirst('#', '');

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
      r = 255;
      g = 255;
      b = 255;
      a = 255;
    }

    return img.ColorRgba8(r, g, b, a);
  }

  /// Generates the adaptive icon XML descriptor.
  void _generateAdaptiveXml(ResolvedIconConfig config, String projectRoot) {
    final outputDir = Directory('$projectRoot/$_resPath/mipmap-anydpi-v26');
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
      final existingContent = colorsFile.readAsStringSync();
      final colorEntry =
          '    <color name="ic_launcher_background">$colorValue</color>';

      final updatedContent =
          existingContent.contains('name="ic_launcher_background"')
              ? existingContent.replaceFirst(
                  RegExp(r'<color name="ic_launcher_background">.*?</color>'),
                  '<color name="ic_launcher_background">$colorValue</color>',
                )
              : existingContent.replaceFirst(
                  '</resources>',
                  '$colorEntry\n</resources>',
                );

      colorsFile.writeAsStringSync(updatedContent);
    } else {
      final xml = '''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">$colorValue</color>
</resources>
''';
      colorsFile.writeAsStringSync(xml);
    }
  }
}
