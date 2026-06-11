import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;

import 'package:flutter_app_icons_generator/src/config/config_model.dart';
import 'package:flutter_app_icons_generator/src/core/default_image_optimizer.dart';
import 'package:flutter_app_icons_generator/src/core/default_image_processor.dart';
import 'package:flutter_app_icons_generator/src/core/icon_generator.dart';
import 'package:flutter_app_icons_generator/src/shared/constants.dart';

/// Generates iOS app icon assets.
///
/// Produces a single 1024x1024 PNG (no alpha channel) and the corresponding
/// `Contents.json` manifest for the Xcode asset catalog.
class IosIconGenerator implements IconGenerator {
  /// Creates an [IosIconGenerator].
  IosIconGenerator({
    DefaultImageProcessor? imageProcessor,
    DefaultImageOptimizer? imageOptimizer,
  })  : _imageProcessor = imageProcessor ?? DefaultImageProcessor(),
        _imageOptimizer = imageOptimizer ?? DefaultImageOptimizer();

  final DefaultImageProcessor _imageProcessor;
  final DefaultImageOptimizer _imageOptimizer;

  /// The filename for the generated 1024x1024 icon.
  static const String iconFilename = 'app_icon_1024.png';

  /// The relative path within the project root for the iOS app icon asset set.
  String _getAssetPath(String? flavorName) {
    final iconName = flavorName != null ? 'AppIcon-$flavorName' : 'AppIcon';
    return 'ios/Runner/Assets.xcassets/$iconName.appiconset';
  }

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

    // Composite onto background if provided, otherwise use foreground directly.
    final img.Image sourceImage;
    if (config.hasBackground) {
      sourceImage = await _compositeImage(foregroundImage, config.background!);
    } else {
      sourceImage = foregroundImage;
    }

    // iOS requires no alpha channel.
    final opaqueImage = _imageProcessor.hasTransparency(sourceImage)
        ? _imageProcessor.removeAlpha(sourceImage)
        : sourceImage;

    // Resize to 1024x1024.
    final resizedImage = _imageProcessor.resize(
      opaqueImage,
      IosSizes.appStoreSize,
      IosSizes.appStoreSize,
    );

    // Encode to PNG.
    final pngBytes = _imageOptimizer.encodePng(resizedImage);

    // Ensure the output directory exists.
    final outputDir = Directory('$projectRoot/${_getAssetPath(flavorName)}');
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    // Write the icon PNG file.
    final iconFile = File('${outputDir.path}/$iconFilename');
    iconFile.writeAsBytesSync(pngBytes);

    // Generate and write Contents.json.
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

  /// Generates the Contents.json manifest for the Xcode asset catalog.
  String _generateContentsJson() {
    final contents = {
      'images': [
        {
          'filename': iconFilename,
          'idiom': 'universal',
          'platform': 'ios',
          'size': '1024x1024',
        },
      ],
      'info': {
        'author': 'flutter_app_icons_generator',
        'version': 1,
      },
    };

    const encoder = JsonEncoder.withIndent('  ');
    return '${encoder.convert(contents)}\n';
  }
}
