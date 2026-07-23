import 'dart:io';

import 'package:image/image.dart' as img;

import 'package:flutter_app_icons_generator/src/config/config_model.dart';
import 'package:flutter_app_icons_generator/src/core/icon_generator.dart';
import 'package:flutter_app_icons_generator/src/core/image_optimizer.dart';
import 'package:flutter_app_icons_generator/src/core/image_processor.dart';

/// macOS icon generator using the modern Asset Catalog approach.
///
/// Generates individual PNG files at all required sizes and scale factors
/// inside the `AppIcon.appiconset` directory with a proper `Contents.json`
/// manifest. This is the Apple-recommended way to manage app icons on macOS.
///
/// The asset catalog compiler handles `.icns` generation internally during
/// the Xcode build process, so no standalone `.icns` file is needed.
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

  /// Required icon sizes for macOS asset catalog with their scale factors.
  ///
  /// Each entry is (point size, scale factor). The pixel size is
  /// pointSize × scale.
  static const List<(int, int)> _iconSizes = [
    (16, 1),
    (16, 2),
    (32, 1),
    (32, 2),
    (128, 1),
    (128, 2),
    (256, 1),
    (256, 2),
    (512, 1),
    (512, 2),
  ];

  /// Returns the asset catalog output path for the given flavor.
  String _getAssetCatalogPath(String? flavorName) {
    final iconName = flavorName != null ? 'AppIcon-$flavorName' : 'AppIcon';
    return 'macos/Runner/Assets.xcassets/$iconName.appiconset';
  }

  @override
  Future<void> generate(ResolvedIconConfig config, String projectRoot,
      {String? flavorName}) async {
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
      sourceImage = await _compositeImage(
        foregroundImage,
        config.background!,
        contentScale: config.contentScale,
      );
    } else {
      sourceImage = foregroundImage;
    }

    // macOS requires no alpha channel.
    final opaqueImage = imageProcessor.hasTransparency(sourceImage)
        ? imageProcessor.removeAlpha(sourceImage)
        : sourceImage;

    // Ensure the asset catalog output directory exists.
    final outputDir =
        Directory('$projectRoot/${_getAssetCatalogPath(flavorName)}');
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    // Generate individual PNG files for the asset catalog.
    for (final (pointSize, scale) in _iconSizes) {
      final pixelSize = pointSize * scale;
      final resized = imageProcessor.resize(opaqueImage, pixelSize, pixelSize);
      final pngBytes = imageOptimizer.encodePng(resized);
      final filename = _pngFilename(pointSize, scale);
      File('${outputDir.path}/$filename').writeAsBytesSync(pngBytes);
    }

    // Generate the Contents.json manifest with individual PNG entries.
    final contentsJson = _generateContentsJson();
    final contentsFile = File('${outputDir.path}/Contents.json');
    contentsFile.writeAsStringSync(contentsJson);
  }

  /// Composites the foreground onto the background with padding.
  ///
  /// Applies a content inset based on the configured foreground padding.
  /// Default uses the same 72/108 ratio as Android's safe zone for visual
  /// consistency across platforms (~66.67% content, ~16.7% padding per side).
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

  /// Returns the PNG filename for a given point size and scale factor.
  String _pngFilename(int pointSize, int scale) {
    return 'app_icon_${pointSize}x$pointSize${scale > 1 ? '@${scale}x' : ''}.png';
  }

  /// Generates a Contents.json manifest with individual PNG entries
  /// at all required sizes and scale factors.
  ///
  /// This format is understood natively by the asset catalog compiler
  /// and produces no warnings.
  String _generateContentsJson() {
    final entries = <String>[];
    for (final (pointSize, scale) in _iconSizes) {
      final filename = _pngFilename(pointSize, scale);
      entries.add('''    {
      "filename" : "$filename",
      "idiom" : "mac",
      "scale" : "${scale}x",
      "size" : "${pointSize}x$pointSize"
    }''');
    }

    return '''{
  "images" : [
${entries.join(',\n')}
  ],
  "info" : {
    "author" : "flutter_app_icons_generator",
    "version" : 1
  }
}
''';
  }
}
