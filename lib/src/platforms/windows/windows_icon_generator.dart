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
///
/// Windows icons use the foreground image directly with transparency
/// preserved — no background compositing is applied.
class WindowsIconGenerator implements IconGenerator {
  /// Creates a [WindowsIconGenerator] with the given image processor
  /// and optimizer.
  WindowsIconGenerator({
    DefaultImageProcessor? imageProcessor,
    DefaultImageOptimizer? imageOptimizer,
  })  : _imageProcessor = imageProcessor ?? DefaultImageProcessor(),
        _imageOptimizer = imageOptimizer ?? const DefaultImageOptimizer();

  final DefaultImageProcessor _imageProcessor;
  final DefaultImageOptimizer _imageOptimizer;

  @override
  Future<void> generate(ResolvedIconConfig config, String projectRoot) async {
    if (config.foregroundPath == null) {
      throw ArgumentError(
        'ResolvedIconConfig must have foregroundPath set.',
      );
    }

    // Load the foreground image — keep transparency intact for Windows.
    final sourceImage =
        await _imageProcessor.loadAndValidate(config.foregroundPath!);

    // Encode as ICO with all required sizes (transparency preserved).
    final icoBytes = _imageOptimizer.encodeIco(
      sourceImage,
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
