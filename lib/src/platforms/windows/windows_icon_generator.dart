import 'dart:io';

import 'package:flutter_app_icons_generator/src/config/config_model.dart';
import 'package:flutter_app_icons_generator/src/core/default_image_optimizer.dart';
import 'package:flutter_app_icons_generator/src/core/default_image_processor.dart';
import 'package:flutter_app_icons_generator/src/core/icon_generator.dart';
import 'package:flutter_app_icons_generator/src/shared/constants.dart';

/// Icon generator for the Windows platform.
///
/// Generates a multi-size ICO file at
/// `{projectRoot}/windows/runner/resources/app_icon.ico`
/// containing embedded sizes: 16, 32, 48, 64, 128, 256.
class WindowsIconGenerator implements IconGenerator {
  /// Creates a [WindowsIconGenerator] with the given image processor and optimizer.
  WindowsIconGenerator({
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

    // Remove alpha channel (Windows icons have no alpha channel).
    final opaqueImage = _imageProcessor.removeAlpha(sourceImage);

    // Encode as ICO with all required sizes.
    final icoBytes = _imageOptimizer.encodeIco(
      opaqueImage,
      WindowsSizes.icoSizes,
    );

    // Ensure the output directory exists.
    final outputDir = Directory('$projectRoot/windows/runner/resources');
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    // Write the ICO file.
    final outputFile = File('${outputDir.path}/app_icon.ico');
    outputFile.writeAsBytesSync(icoBytes);
  }
}
