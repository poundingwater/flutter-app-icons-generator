import 'dart:io';

import 'package:flutter_app_icons/src/config/config_model.dart';
import 'package:flutter_app_icons/src/core/default_image_optimizer.dart';
import 'package:flutter_app_icons/src/core/default_image_processor.dart';
import 'package:flutter_app_icons/src/core/icon_generator.dart';
import 'package:flutter_app_icons/src/shared/constants.dart';

/// Generates web platform icon assets including favicon, PWA icons,
/// and maskable icons.
///
/// Produces the following files:
/// - `web/favicon.png` (16x16)
/// - `web/icons/Icon-192.png` (192x192)
/// - `web/icons/Icon-512.png` (512x512)
/// - `web/icons/Icon-maskable-192.png` (192x192)
/// - `web/icons/Icon-maskable-512.png` (512x512)
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

  /// The image optimizer used for PNG encoding.
  final DefaultImageOptimizer imageOptimizer;

  @override
  Future<void> generate(IconConfig config, String projectRoot) async {
    final sourcePath = config.imagePath ?? config.foregroundPath;
    if (sourcePath == null) {
      throw ArgumentError(
        'IconConfig must have either imagePath or foregroundPath set.',
      );
    }

    // Load and validate the source image.
    final sourceImage = await imageProcessor.loadAndValidate(sourcePath);

    // Ensure output directories exist.
    final webDir = Directory('$projectRoot/web');
    final iconsDir = Directory('$projectRoot/web/icons');
    if (!webDir.existsSync()) {
      webDir.createSync(recursive: true);
    }
    if (!iconsDir.existsSync()) {
      iconsDir.createSync(recursive: true);
    }

    // Generate favicon.png (16x16).
    final favicon = imageProcessor.resize(
      sourceImage,
      WebSizes.faviconSize,
      WebSizes.faviconSize,
    );
    final faviconBytes = imageOptimizer.encodePng(favicon);
    File('$projectRoot/web/favicon.png').writeAsBytesSync(faviconBytes);

    // Generate PWA icons.
    final pwaSmall = imageProcessor.resize(
      sourceImage,
      WebSizes.pwaSmall,
      WebSizes.pwaSmall,
    );
    final pwaSmallBytes = imageOptimizer.encodePng(pwaSmall);
    File('$projectRoot/web/icons/Icon-192.png')
        .writeAsBytesSync(pwaSmallBytes);

    final pwaLarge = imageProcessor.resize(
      sourceImage,
      WebSizes.pwaLarge,
      WebSizes.pwaLarge,
    );
    final pwaLargeBytes = imageOptimizer.encodePng(pwaLarge);
    File('$projectRoot/web/icons/Icon-512.png')
        .writeAsBytesSync(pwaLargeBytes);

    // Generate maskable icons (same source, same resize — naming differentiates).
    final maskableSmall = imageProcessor.resize(
      sourceImage,
      WebSizes.maskableSmall,
      WebSizes.maskableSmall,
    );
    final maskableSmallBytes = imageOptimizer.encodePng(maskableSmall);
    File('$projectRoot/web/icons/Icon-maskable-192.png')
        .writeAsBytesSync(maskableSmallBytes);

    final maskableLarge = imageProcessor.resize(
      sourceImage,
      WebSizes.maskableLarge,
      WebSizes.maskableLarge,
    );
    final maskableLargeBytes = imageOptimizer.encodePng(maskableLarge);
    File('$projectRoot/web/icons/Icon-maskable-512.png')
        .writeAsBytesSync(maskableLargeBytes);
  }
}
