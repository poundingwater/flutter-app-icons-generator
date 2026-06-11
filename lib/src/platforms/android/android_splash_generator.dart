import 'dart:io';

import 'package:flutter_app_icons_generator/src/config/config_model.dart';
import 'package:flutter_app_icons_generator/src/core/default_image_optimizer.dart';
import 'package:flutter_app_icons_generator/src/core/default_image_processor.dart';
import 'package:flutter_app_icons_generator/src/core/splash_generator.dart';

/// Android-specific splash screen generator.
///
/// Generates a single splash drawable image in the `drawable` resource
/// directory. The image is saved at its original size (up to source
/// dimensions) and Android handles scaling at runtime.
class AndroidSplashGenerator implements SplashGenerator {
  /// Creates an [AndroidSplashGenerator] with the given image processor
  /// and optimizer.
  AndroidSplashGenerator({
    DefaultImageProcessor? imageProcessor,
    DefaultImageOptimizer? imageOptimizer,
  })  : _imageProcessor = imageProcessor ?? DefaultImageProcessor(),
        _imageOptimizer = imageOptimizer ?? const DefaultImageOptimizer();

  final DefaultImageProcessor _imageProcessor;
  final DefaultImageOptimizer _imageOptimizer;

  /// Base resource path relative to the project root.
  String _getResPath(String? flavorName) => 'android/app/src/${flavorName ?? "main"}/res';

  @override
  Future<void> generate(SplashConfig config, String projectRoot, {String? flavorName}) async {
    final sourceImage = await _imageProcessor.loadAndValidate(config.imagePath);

    // Use the source image directly — Android handles scaling.
    final pngBytes = _imageOptimizer.encodePng(sourceImage);

    final outputDir = Directory('$projectRoot/${_getResPath(flavorName)}/drawable');
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    final outputFile = File('${outputDir.path}/splash.png');
    outputFile.writeAsBytesSync(pngBytes);
  }
}
