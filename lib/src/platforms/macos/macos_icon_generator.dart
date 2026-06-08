import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;

import 'package:flutter_app_icons_generator/src/config/config_model.dart';
import 'package:flutter_app_icons_generator/src/core/icon_generator.dart';
import 'package:flutter_app_icons_generator/src/core/image_optimizer.dart';
import 'package:flutter_app_icons_generator/src/core/image_processor.dart';
import 'package:flutter_app_icons_generator/src/shared/constants.dart';

/// macOS icon generator that produces all required icon sizes and a
/// `Contents.json` manifest for the Xcode asset catalog.
///
/// Generates icons at 16, 32, 64, 128, 256, 512, and 1024 pixels with
/// no alpha channel, placed in the AppIcon.appiconset directory.
class MacosIconGenerator implements IconGenerator {
  /// Creates a [MacosIconGenerator] with the required dependencies.
  MacosIconGenerator({
    required this.imageProcessor,
    required this.imageOptimizer,
  });

  /// Image processor for loading, resizing, and alpha removal.
  final ImageProcessor imageProcessor;

  /// Image optimizer for PNG encoding.
  final ImageOptimizer imageOptimizer;

  /// Output directory path relative to the project root.
  static const String outputPath =
      'macos/Runner/Assets.xcassets/AppIcon.appiconset';

  @override
  Future<void> generate(IconConfig config, String projectRoot) async {
    final sourceImage = await _loadSourceImage(config);

    // Remove alpha channel (macOS icons must not have transparency).
    final opaqueImage = imageProcessor.removeAlpha(sourceImage);

    // Ensure the output directory exists.
    final outputDir = Directory('$projectRoot/$outputPath');
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    // Generate icon files at each required size.
    for (final size in MacosSizes.sizes) {
      final resized = imageProcessor.resize(opaqueImage, size, size);
      final pngBytes = imageOptimizer.encodePng(resized);
      final filename = _filenameForSize(size);
      final file = File('${outputDir.path}/$filename');
      file.writeAsBytesSync(pngBytes);
    }

    // Generate the Contents.json manifest.
    final contentsJson = _generateContentsJson();
    final contentsFile = File('${outputDir.path}/Contents.json');
    contentsFile.writeAsStringSync(contentsJson);
  }

  /// Loads the source image from the config.
  ///
  /// If the config has a combined [IconConfig.imagePath], uses that directly.
  /// For adaptive configs, composites the foreground onto the background.
  Future<img.Image> _loadSourceImage(IconConfig config) async {
    if (config.imagePath != null) {
      return imageProcessor.loadAndValidate(config.imagePath!);
    }

    // Adaptive icon: composite foreground onto background.
    final foreground =
        await imageProcessor.loadAndValidate(config.foregroundPath!);

    final img.Image background;
    switch (config.background!) {
      case BackgroundImage(imagePath: final path):
        background = await imageProcessor.loadAndValidate(path);
      case BackgroundColor(hexColor: final hex):
        background =
            _createColorBackground(hex, foreground.width, foreground.height);
    }

    return imageProcessor.composite(foreground, background);
  }

  /// Creates a solid color background image from a hex color string.
  img.Image _createColorBackground(String hexColor, int width, int height) {
    final color = _parseHexColor(hexColor);
    final image = img.Image(width: width, height: height, numChannels: 4);
    img.fill(image, color: color);
    return image;
  }

  /// Parses a hex color string (e.g. "#4CAF50" or "4CAF50") to an [img.Color].
  img.Color _parseHexColor(String hex) {
    var sanitized = hex.replaceFirst('#', '');
    if (sanitized.length == 6) {
      sanitized = 'FF$sanitized'; // Add full opacity.
    }
    final value = int.parse(sanitized, radix: 16);
    final a = (value >> 24) & 0xFF;
    final r = (value >> 16) & 0xFF;
    final g = (value >> 8) & 0xFF;
    final b = value & 0xFF;
    return img.ColorRgba8(r, g, b, a);
  }

  /// Returns the filename for a given icon size.
  String _filenameForSize(int size) => 'app_icon_$size.png';

  /// Generates the Contents.json manifest for the macOS asset catalog.
  String _generateContentsJson() {
    final images = <Map<String, String>>[];

    // 16x16 @1x
    images.add(_imageEntry(16, '1x', '16x16'));
    // 16x16 @2x (32px)
    images.add(_imageEntry(32, '2x', '16x16'));
    // 32x32 @1x
    images.add(_imageEntry(32, '1x', '32x32'));
    // 32x32 @2x (64px)
    images.add(_imageEntry(64, '2x', '32x32'));
    // 128x128 @1x
    images.add(_imageEntry(128, '1x', '128x128'));
    // 128x128 @2x (256px)
    images.add(_imageEntry(256, '2x', '128x128'));
    // 256x256 @1x
    images.add(_imageEntry(256, '1x', '256x256'));
    // 256x256 @2x (512px)
    images.add(_imageEntry(512, '2x', '256x256'));
    // 512x512 @1x
    images.add(_imageEntry(512, '1x', '512x512'));
    // 512x512 @2x (1024px)
    images.add(_imageEntry(1024, '2x', '512x512'));

    final contents = {
      'images': images,
      'info': {
        'author': 'flutter_app_icons_generator',
        'version': 1,
      },
    };

    const encoder = JsonEncoder.withIndent('  ');
    return '${encoder.convert(contents)}\n';
  }

  /// Creates a single image entry for the Contents.json manifest.
  Map<String, String> _imageEntry(int pixelSize, String scale, String size) {
    return {
      'filename': _filenameForSize(pixelSize),
      'idiom': 'mac',
      'scale': scale,
      'size': size,
    };
  }
}
