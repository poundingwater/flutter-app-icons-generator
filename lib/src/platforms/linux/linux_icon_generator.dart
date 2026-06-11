import 'dart:io';

import 'package:image/image.dart' as img;

import 'package:flutter_app_icons_generator/src/config/config_model.dart';
import 'package:flutter_app_icons_generator/src/core/default_image_optimizer.dart';
import 'package:flutter_app_icons_generator/src/core/default_image_processor.dart';
import 'package:flutter_app_icons_generator/src/core/icon_generator.dart';
import 'package:flutter_app_icons_generator/src/shared/constants.dart';

/// Icon generator for the Linux platform.
///
/// Generates a single 512x512 PNG icon file at
/// `{projectRoot}/linux/app_icon.png`.
///
/// Composites foreground onto background when background is provided.
class LinuxIconGenerator implements IconGenerator {
  /// Creates a [LinuxIconGenerator] with the given image processor
  /// and optimizer.
  LinuxIconGenerator({
    DefaultImageProcessor? imageProcessor,
    DefaultImageOptimizer? imageOptimizer,
  })  : _imageProcessor = imageProcessor ?? DefaultImageProcessor(),
        _imageOptimizer = imageOptimizer ?? const DefaultImageOptimizer();

  final DefaultImageProcessor _imageProcessor;
  final DefaultImageOptimizer _imageOptimizer;

  @override
  Future<void> generate(ResolvedIconConfig config, String projectRoot, {String? flavorName}) async {
    if (config.foregroundPath == null) {
      throw ArgumentError(
        'ResolvedIconConfig must have foregroundPath set.',
      );
    }

    // Load the foreground image.
    final foregroundImage =
        await _imageProcessor.loadAndValidate(config.foregroundPath!);

    // Composite onto background if provided.
    final img.Image sourceImage;
    if (config.hasBackground) {
      sourceImage = await _compositeImage(foregroundImage, config.background!);
    } else {
      sourceImage = foregroundImage;
    }

    // Resize to 512x512 for Linux desktop icon.
    final resized = _imageProcessor.resize(
      sourceImage,
      LinuxSizes.iconSize,
      LinuxSizes.iconSize,
    );

    // Encode to PNG.
    final pngBytes = _imageOptimizer.encodePng(resized);

    // Ensure the linux directory exists.
    final outputDir = Directory('$projectRoot/linux');
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    // Write the icon file.
    final outputFile = File('${outputDir.path}/app_icon.png');
    outputFile.writeAsBytesSync(pngBytes);
  }

  /// Composites the foreground onto the background with padding.
  ///
  /// Applies a content inset so the foreground doesn't fill edge-to-edge.
  /// Uses the same 72/108 ratio as Android's safe zone for visual consistency.
  Future<img.Image> _compositeImage(
    img.Image foreground,
    BackgroundConfig background,
  ) async {
    final canvasSize = foreground.width;

    final img.Image bgImage;
    switch (background) {
      case BackgroundImage(imagePath: final path):
        bgImage = await _imageProcessor.loadAndValidate(path);
      case BackgroundColor(hexColor: final hex):
        bgImage = _createColorBackground(hex, canvasSize, canvasSize);
    }

    // Resize background to canvas size.
    final resizedBg = _imageProcessor.resize(bgImage, canvasSize, canvasSize);

    // Scale foreground to 72/108 of canvas (safe zone ratio).
    final contentSize = (canvasSize * 72) ~/ 108;
    final resizedFg = _imageProcessor.resize(
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
