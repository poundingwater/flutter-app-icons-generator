import 'dart:io';

import 'package:image/image.dart' as img;

import 'package:flutter_app_icons_generator/src/config/config_model.dart';
import 'package:flutter_app_icons_generator/src/core/icon_generator.dart';
import 'package:flutter_app_icons_generator/src/core/image_optimizer.dart';
import 'package:flutter_app_icons_generator/src/core/image_processor.dart';

/// macOS icon generator that produces an `AppIcon.icns` file.
///
/// Generates a single ICNS file containing all required icon sizes
/// (16, 32, 64, 128, 256, 512, 1024) with no alpha channel, placed in
/// the macOS Runner Assets directory.
class MacosIconGenerator implements IconGenerator {
  /// Creates a [MacosIconGenerator] with the required dependencies.
  MacosIconGenerator({
    required this.imageProcessor,
    required this.imageOptimizer,
  });

  /// Image processor for loading, resizing, and alpha removal.
  final ImageProcessor imageProcessor;

  /// Image optimizer for ICNS encoding.
  final ImageOptimizer imageOptimizer;

  /// Output directory path relative to the project root.
  static const String outputPath =
      'macos/Runner/Assets.xcassets/AppIcon.appiconset';

  /// The filename for the generated ICNS file.
  static const String icnsFilename = 'app_icon.icns';

  @override
  Future<void> generate(ResolvedIconConfig config, String projectRoot) async {
    if (config.foregroundPath == null) {
      throw ArgumentError(
        'ResolvedIconConfig must have foregroundPath set.',
      );
    }

    final foregroundImage =
        await imageProcessor.loadAndValidate(config.foregroundPath!);

    // Composite onto background if provided.
    final img.Image sourceImage;
    if (config.hasBackground) {
      sourceImage = await _compositeImage(foregroundImage, config.background!);
    } else {
      sourceImage = foregroundImage;
    }

    // macOS requires no alpha channel.
    final opaqueImage = imageProcessor.hasTransparency(sourceImage)
        ? imageProcessor.removeAlpha(sourceImage)
        : sourceImage;

    // Ensure the output directory exists.
    final outputDir = Directory('$projectRoot/$outputPath');
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    // Generate the ICNS file containing all required sizes.
    final icnsBytes = imageOptimizer.encodeIcns(opaqueImage);
    final icnsFile = File('${outputDir.path}/$icnsFilename');
    icnsFile.writeAsBytesSync(icnsBytes);

    // Generate the Contents.json manifest pointing to the ICNS file.
    final contentsJson = _generateContentsJson();
    final contentsFile = File('${outputDir.path}/Contents.json');
    contentsFile.writeAsStringSync(contentsJson);
  }

  /// Composites the foreground onto the background with padding.
  ///
  /// Applies a content inset so the foreground doesn't fill edge-to-edge.
  /// Uses the same 72/108 ratio as Android's safe zone for visual consistency
  /// across platforms (~66.67% content, ~16.7% padding per side).
  Future<img.Image> _compositeImage(
    img.Image foreground,
    BackgroundConfig background,
  ) async {
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

    // Scale foreground to 72/108 of canvas (safe zone ratio).
    final contentSize = (canvasSize * 72) ~/ 108;
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

  /// Creates a solid color background image from a hex color string.
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

  /// Generates a minimal Contents.json that references the ICNS file.
  String _generateContentsJson() {
    return '''{
  "images" : [
    {
      "filename" : "$icnsFilename",
      "idiom" : "mac"
    }
  ],
  "info" : {
    "author" : "flutter_app_icons_generator",
    "version" : 1
  }
}
''';
  }
}
