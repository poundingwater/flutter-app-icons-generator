import 'dart:io';

import 'package:flutter_app_icons_generator/src/config/config_model.dart';
import 'package:flutter_app_icons_generator/src/core/image_optimizer.dart';
import 'package:flutter_app_icons_generator/src/core/image_processor.dart';
import 'package:flutter_app_icons_generator/src/core/splash_generator.dart';
import 'package:image/image.dart' as img;

/// Linux splash screen generator that produces a splash image resource
/// in the Linux project directory.
///
/// Generates a 512x512 splash image at `{projectRoot}/linux/splash.png`.
class LinuxSplashGenerator implements SplashGenerator {
  /// Creates a [LinuxSplashGenerator] with the required dependencies.
  LinuxSplashGenerator({
    required this.imageProcessor,
    required this.imageOptimizer,
  });

  /// Image processor for loading, validating, and resizing splash images.
  final ImageProcessor imageProcessor;

  /// Image optimizer for PNG encoding.
  final ImageOptimizer imageOptimizer;

  /// The size for the Linux splash image.
  static const int splashSize = 512;

  @override
  Future<void> generate(SplashConfig config, String projectRoot, {String? flavorName}) async {
    // Load and validate the splash source image.
    final img.Image sourceImage =
        await imageProcessor.loadAndValidate(config.imagePath);

    // Resize to 512x512 for a reasonable splash image size.
    final resized = imageProcessor.resize(sourceImage, splashSize, splashSize);

    // Encode the image to PNG.
    final pngBytes = imageOptimizer.encodePng(resized);

    // Ensure the linux directory exists.
    final outputDir = Directory('$projectRoot/linux');
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    // Write the splash image.
    final splashFile = File('${outputDir.path}/splash.png');
    splashFile.writeAsBytesSync(pngBytes);
  }
}
