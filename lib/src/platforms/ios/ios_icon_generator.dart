import 'dart:convert';
import 'dart:io';

import 'package:flutter_app_icons/src/config/config_model.dart';
import 'package:flutter_app_icons/src/core/default_image_optimizer.dart';
import 'package:flutter_app_icons/src/core/default_image_processor.dart';
import 'package:flutter_app_icons/src/core/icon_generator.dart';
import 'package:flutter_app_icons/src/shared/constants.dart';

/// Generates iOS app icon assets.
///
/// Produces a single 1024x1024 PNG (no alpha channel) and the corresponding
/// `Contents.json` manifest for the Xcode asset catalog. The output conforms
/// to the latest Xcode format using a universal idiom for iOS.
class IosIconGenerator implements IconGenerator {
  /// Creates an [IosIconGenerator].
  ///
  /// Uses [DefaultImageProcessor] for image manipulation and
  /// [DefaultImageOptimizer] for PNG encoding.
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
  static const String assetPath =
      'ios/Runner/Assets.xcassets/AppIcon.appiconset';

  @override
  Future<void> generate(IconConfig config, String projectRoot) async {
    // Determine the source image path.
    final sourcePath = config.imagePath ?? config.foregroundPath;
    if (sourcePath == null) {
      throw ArgumentError(
        'IconConfig must have either imagePath or foregroundPath set.',
      );
    }

    // Load and validate the source image.
    final sourceImage = await _imageProcessor.loadAndValidate(sourcePath);

    // Remove alpha channel (composite onto white background).
    final opaqueImage = _imageProcessor.removeAlpha(sourceImage);

    // Resize to 1024x1024.
    final resizedImage = _imageProcessor.resize(
      opaqueImage,
      IosSizes.appStoreSize,
      IosSizes.appStoreSize,
    );

    // Encode to PNG.
    final pngBytes = _imageOptimizer.encodePng(resizedImage);

    // Ensure the output directory exists.
    final outputDir = Directory('$projectRoot/$assetPath');
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

  /// Generates the Contents.json manifest for the Xcode asset catalog.
  ///
  /// Uses the latest format with a single universal 1024x1024 entry for iOS.
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
        'author': 'flutter_app_icons',
        'version': 1,
      },
    };

    const encoder = JsonEncoder.withIndent('  ');
    return '${encoder.convert(contents)}\n';
  }
}
