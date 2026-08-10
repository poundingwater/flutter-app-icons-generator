import 'dart:io';

import 'package:flutter_app_icons_generator/src/config/config_model.dart';
import 'package:flutter_app_icons_generator/src/core/image_optimizer.dart';
import 'package:flutter_app_icons_generator/src/core/image_processor.dart';
import 'package:flutter_app_icons_generator/src/core/splash_generator.dart';
import 'package:image/image.dart' as img;

/// Windows splash screen generator that produces a splash image resource
/// in the Windows project directory.
///
/// Generates a 512x512 splash image at
/// `{projectRoot}/windows/runner/resources/splash.png`.
class WindowsSplashGenerator implements SplashGenerator {
  /// Creates a [WindowsSplashGenerator] with the required dependencies.
  WindowsSplashGenerator({
    required this.imageProcessor,
    required this.imageOptimizer,
  });

  /// Image processor for loading, validating, and resizing splash images.
  final ImageProcessor imageProcessor;

  /// Image optimizer for PNG encoding.
  final ImageOptimizer imageOptimizer;

  /// The size for the Windows splash image.
  static const int splashSize = 512;

  @override
  Future<void> generate(SplashConfig config, String projectRoot,
      {String? flavorName}) async {
    // Load and validate the splash source image.
    final img.Image sourceImage =
        await imageProcessor.loadAndValidate(config.imagePath);

    // Resize to 512x512 for the splash image.
    final resized = imageProcessor.resize(sourceImage, splashSize, splashSize);

    // Encode the image to PNG.
    final pngBytes = imageOptimizer.encodePng(resized);

    // Ensure the windows/runner/resources directory exists.
    final outputDir = Directory('$projectRoot/windows/runner/resources');
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    // Write the splash image.
    final splashFile = File('${outputDir.path}/splash.png');
    splashFile.writeAsBytesSync(pngBytes);
  }
}
