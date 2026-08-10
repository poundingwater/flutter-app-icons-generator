import 'dart:io';

import 'package:image/image.dart' as img;

import 'package:flutter_app_icons_generator/src/config/config_model.dart';
import 'package:flutter_app_icons_generator/src/core/default_image_optimizer.dart';
import 'package:flutter_app_icons_generator/src/core/default_image_processor.dart';
import 'package:flutter_app_icons_generator/src/core/icon_generator.dart';
import 'package:flutter_app_icons_generator/src/shared/constants.dart';

/// Generates web platform icon assets including favicon, PWA icons,
/// and maskable icons.
///
/// Produces the following files:
/// - `web/favicon.ico` (48x48 ICO)
/// - `web/icons/Icon-192.png` (192x192)
/// - `web/icons/Icon-512.png` (512x512)
/// - `web/icons/Icon-maskable-192.png` (192x192)
/// - `web/icons/Icon-maskable-512.png` (512x512)
///
/// Favicon uses the foreground image only (transparency preserved).
/// PWA and maskable icons composite foreground onto background.
class WebIconGenerator implements IconGenerator {
  /// Creates a [WebIconGenerator] with the given image processor and optimizer.
  WebIconGenerator({
    required this.imageProcessor,
    required this.imageOptimizer,
  });

  /// Creates a [WebIconGenerator] with default dependencies.
  factory WebIconGenerator.defaults() {
    return WebIconGenerator(
      imageProcessor: DefaultImageProcessor(),
      imageOptimizer: const DefaultImageOptimizer(),
    );
  }

  /// The image processor used for loading and resizing images.
  final DefaultImageProcessor imageProcessor;

  /// The image optimizer used for PNG/ICO encoding.
  final DefaultImageOptimizer imageOptimizer;

  @override
  Future<void> generate(ResolvedIconConfig config, String projectRoot,
      {String? flavorName}) async {
    if (config.foregroundPath == null) {
      throw ArgumentError(
        'ResolvedIconConfig must have foregroundPath set.',
      );
    }

    // Load the foreground image.
    final foregroundImage =
        await imageProcessor.loadAndValidate(config.foregroundPath!);

    // Ensure output directories exist.
    final webDir = Directory('$projectRoot/web');
    final iconsDir = Directory('$projectRoot/web/icons');
    if (!webDir.existsSync()) {
      webDir.createSync(recursive: true);
    }
    if (!iconsDir.existsSync()) {
      iconsDir.createSync(recursive: true);
    }

    // Generate favicon.ico — uses foreground only (transparency preserved).
    final faviconBytes = imageOptimizer.encodeIco(
      foregroundImage,
      WebSizes.faviconSizes,
    );
    File('$projectRoot/web/favicon.ico').writeAsBytesSync(faviconBytes);

    // Composite foreground onto background for PWA/maskable icons.
    final img.Image compositedImage;
    if (config.hasBackground) {
      compositedImage = await _compositeImage(
        foregroundImage,
        config.background!,
        contentScale: config.contentScale,
      );
    } else {
      compositedImage = foregroundImage;
    }

    // Generate PWA icons (composited).
    final pwaSmall = imageProcessor.resize(
      compositedImage,
      WebSizes.pwaSmall,
      WebSizes.pwaSmall,
    );
    final pwaSmallBytes = imageOptimizer.encodePng(pwaSmall);
    File('$projectRoot/web/icons/Icon-192.png').writeAsBytesSync(pwaSmallBytes);

    final pwaLarge = imageProcessor.resize(
      compositedImage,
      WebSizes.pwaLarge,
      WebSizes.pwaLarge,
    );
    final pwaLargeBytes = imageOptimizer.encodePng(pwaLarge);
    File('$projectRoot/web/icons/Icon-512.png').writeAsBytesSync(pwaLargeBytes);

    // Generate maskable icons (composited).
    final maskableSmall = imageProcessor.resize(
      compositedImage,
      WebSizes.maskableSmall,
      WebSizes.maskableSmall,
    );
    final maskableSmallBytes = imageOptimizer.encodePng(maskableSmall);
    File('$projectRoot/web/icons/Icon-maskable-192.png')
        .writeAsBytesSync(maskableSmallBytes);

    final maskableLarge = imageProcessor.resize(
      compositedImage,
      WebSizes.maskableLarge,
      WebSizes.maskableLarge,
    );
    final maskableLargeBytes = imageOptimizer.encodePng(maskableLarge);
    File('$projectRoot/web/icons/Icon-maskable-512.png')
        .writeAsBytesSync(maskableLargeBytes);
  }

  /// Composites the foreground onto the background with padding.
  ///
  /// Applies a content inset based on the configured foreground padding.
  /// Default uses the same 72/108 ratio as Android's safe zone for visual
  /// consistency.
  Future<img.Image> _compositeImage(
    img.Image foreground,
    BackgroundConfig background, {
    required double contentScale,
  }) async {
    final canvasSize = foreground.width;

    final img.Image bgImage;
    switch (background) {
      case BackgroundImage(imagePath: final path):
        bgImage = await imageProcessor.loadAndValidate(path);
      case BackgroundColor(hexColor: final hex):
        bgImage = _createColorBackground(hex, canvasSize, canvasSize);
    }

    // Resize background to canvas size.
    final resizedBg = imageProcessor.resize(bgImage, canvasSize, canvasSize);

    // Scale foreground based on configured padding.
    final contentSize = (canvasSize * contentScale).round();
    final resizedFg = imageProcessor.resize(
      foreground,
      contentSize,
      contentSize,
    );

    // Create canvas with background, then overlay centered foreground.
    final canvas = resizedBg.clone();
    final offset = (canvasSize - contentSize) ~/ 2;
    img.compositeImage(canvas, resizedFg, dstX: offset, dstY: offset);

    return canvas;
  }

  /// Creates a solid color background image.
  img.Image _createColorBackground(String hexColor, int width, int height) {
    final color = _parseHexColor(hexColor);
    final image = img.Image(width: width, height: height, numChannels: 4);
    img.fill(image, color: color);
    return image;
  }

  /// Parses a hex color string to an [img.Color].
  img.Color _parseHexColor(String hex) {
    var sanitized = hex.replaceFirst('#', '');
    if (sanitized.length == 6) {
      sanitized = 'FF$sanitized';
    }
    final value = int.parse(sanitized, radix: 16);
    final a = (value >> 24) & 0xFF;
    final r = (value >> 16) & 0xFF;
    final g = (value >> 8) & 0xFF;
    final b = value & 0xFF;
    return img.ColorRgba8(r, g, b, a);
  }
}
