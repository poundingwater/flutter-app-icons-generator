import 'dart:convert';
import 'dart:io';

import 'package:flutter_app_icons_generator/src/config/config_model.dart';
import 'package:flutter_app_icons_generator/src/core/image_optimizer.dart';
import 'package:flutter_app_icons_generator/src/core/image_processor.dart';
import 'package:flutter_app_icons_generator/src/core/splash_generator.dart';

/// macOS splash screen generator that produces a launch image in the
/// Xcode asset catalog format.
///
/// Generates a splash image at `macos/Runner/Assets.xcassets/LaunchImage.imageset/`
/// with a universal `Contents.json` manifest entry.
class MacosSplashGenerator implements SplashGenerator {
  /// Creates a [MacosSplashGenerator] with the required dependencies.
  MacosSplashGenerator({
    required this.imageProcessor,
    required this.imageOptimizer,
  });

  /// Image processor for loading and validating splash images.
  final ImageProcessor imageProcessor;

  /// Image optimizer for PNG encoding.
  final ImageOptimizer imageOptimizer;

  /// Output directory path relative to the project root.
  static const String outputPath =
      'macos/Runner/Assets.xcassets/LaunchImage.imageset';

  @override
  Future<void> generate(SplashConfig config, String projectRoot) async {
    // Load and validate the splash source image.
    final sourceImage = await imageProcessor.loadAndValidate(config.imagePath);

    // Encode the image to PNG.
    final pngBytes = imageOptimizer.encodePng(sourceImage);

    // Ensure the output directory exists.
    final outputDir = Directory('$projectRoot/$outputPath');
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    // Write the splash image.
    final splashFile = File('${outputDir.path}/splash.png');
    splashFile.writeAsBytesSync(pngBytes);

    // Generate the Contents.json manifest.
    final contentsJson = _generateContentsJson();
    final contentsFile = File('${outputDir.path}/Contents.json');
    contentsFile.writeAsStringSync(contentsJson);
  }

  /// Generates the Contents.json manifest for the LaunchImage imageset.
  ///
  /// Uses a universal idiom entry so the splash image applies to all
  /// macOS device configurations.
  String _generateContentsJson() {
    final contents = {
      'images': [
        {
          'filename': 'splash.png',
          'idiom': 'universal',
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
