import 'dart:io';

import 'package:flutter_app_icons/src/config/config_model.dart';
import 'package:flutter_app_icons/src/core/default_image_optimizer.dart';
import 'package:flutter_app_icons/src/core/default_image_processor.dart';
import 'package:flutter_app_icons/src/core/icon_generator.dart';
import 'package:flutter_app_icons/src/shared/constants.dart';

/// Icon generator for the Linux platform.
///
/// Generates a single 512x512 PNG icon file at `{projectRoot}/linux/app_icon.png`.
class LinuxIconGenerator implements IconGenerator {
  /// Creates a [LinuxIconGenerator] with the given image processor and optimizer.
  LinuxIconGenerator({
    DefaultImageProcessor? imageProcessor,
    DefaultImageOptimizer? imageOptimizer,
  })  : _imageProcessor = imageProcessor ?? DefaultImageProcessor(),
        _imageOptimizer = imageOptimizer ?? const DefaultImageOptimizer();

  final DefaultImageProcessor _imageProcessor;
  final DefaultImageOptimizer _imageOptimizer;

  @override
  Future<void> generate(IconConfig config, String projectRoot) async {
    final sourcePath = config.imagePath ?? config.foregroundPath;
    if (sourcePath == null) {
      throw ArgumentError(
        'IconConfig must have either imagePath or foregroundPath set.',
      );
    }

    // Load and validate the source image.
    final sourceImage = await _imageProcessor.loadAndValidate(sourcePath);

    // Resize to 512x512 for Linux desktop icon.
    final resized = _imageProcessor.resize(
      sourceImage,
      LinuxSizes.iconSize,
      LinuxSizes.iconSize,
    );

    // Encode to PNG.
    final pngBytes = _imageOptimizer.encodePng(resized);

    // Ensure the linux directory exists.
    final outputDir = Directory('$projectRoot/linux');
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    // Write the icon file.
    final outputFile = File('${outputDir.path}/app_icon.png');
    outputFile.writeAsBytesSync(pngBytes);
  }
}
