import 'dart:convert';
import 'dart:io';

import 'package:flutter_app_icons_generator/src/config/config_model.dart';
import 'package:flutter_app_icons_generator/src/core/default_image_optimizer.dart';
import 'package:flutter_app_icons_generator/src/core/default_image_processor.dart';
import 'package:flutter_app_icons_generator/src/core/splash_generator.dart';

/// Generates iOS native splash screen (LaunchImage) assets.
///
/// Produces a single high-quality splash PNG and the corresponding
/// `Contents.json` manifest for the Xcode asset catalog. The image is
/// referenced at all three scales (1x, 2x, 3x) using the universal idiom.
class IosSplashGenerator implements SplashGenerator {
  /// Creates an [IosSplashGenerator].
  ///
  /// Uses [DefaultImageProcessor] for image loading and
  /// [DefaultImageOptimizer] for PNG encoding.
  IosSplashGenerator({
    DefaultImageProcessor? imageProcessor,
    DefaultImageOptimizer? imageOptimizer,
  })  : _imageProcessor = imageProcessor ?? DefaultImageProcessor(),
        _imageOptimizer = imageOptimizer ?? DefaultImageOptimizer();

  final DefaultImageProcessor _imageProcessor;
  final DefaultImageOptimizer _imageOptimizer;

  /// The filename for the generated splash image.
  static const String splashFilename = 'splash.png';

  /// The relative path within the project root for the iOS LaunchImage asset set.
  String _getAssetPath(String? flavorName) {
    final splashName = flavorName != null ? 'LaunchImage-$flavorName' : 'LaunchImage';
    return 'ios/Runner/Assets.xcassets/$splashName.imageset';
  }

  @override
  Future<void> generate(SplashConfig config, String projectRoot, {String? flavorName}) async {
    // Load the source splash image.
    final sourceImage = await _imageProcessor.loadAndValidate(config.imagePath);

    // Encode the source image to PNG (use full resolution for all scales).
    final pngBytes = _imageOptimizer.encodePng(sourceImage);

    // Ensure the output directory exists.
    final outputDir = Directory('$projectRoot/${_getAssetPath(flavorName)}');
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    // Write the splash PNG file.
    final splashFile = File('${outputDir.path}/$splashFilename');
    splashFile.writeAsBytesSync(pngBytes);

    // Generate and write Contents.json.
    final contentsJson = _generateContentsJson();
    final contentsFile = File('${outputDir.path}/Contents.json');
    contentsFile.writeAsStringSync(contentsJson);
  }

  /// Generates the Contents.json manifest for the LaunchImage asset catalog.
  ///
  /// References the single splash image at all three scales (1x, 2x, 3x)
  /// using the universal idiom.
  String _generateContentsJson() {
    final contents = {
      'images': [
        {
          'filename': splashFilename,
          'idiom': 'universal',
          'scale': '1x',
        },
        {
          'filename': splashFilename,
          'idiom': 'universal',
          'scale': '2x',
        },
        {
          'filename': splashFilename,
          'idiom': 'universal',
          'scale': '3x',
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
