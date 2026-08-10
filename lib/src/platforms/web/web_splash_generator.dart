import 'dart:io';

import 'package:flutter_app_icons_generator/src/config/config_model.dart';
import 'package:flutter_app_icons_generator/src/core/default_image_optimizer.dart';
import 'package:flutter_app_icons_generator/src/core/default_image_processor.dart';
import 'package:flutter_app_icons_generator/src/core/splash_generator.dart';

/// Generates web splash screen assets displayed during Flutter initialization.
///
/// Produces the following:
/// - `web/splash.png` (512x512) — splash image displayed while Flutter loads
/// - Optionally updates `web/index.html` to reference the splash image
///   with a loading indicator style during Flutter engine initialization.
class WebSplashGenerator implements SplashGenerator {
  /// Creates a [WebSplashGenerator] with the given image processor and optimizer.
  WebSplashGenerator({
    required this.imageProcessor,
    required this.imageOptimizer,
  });

  /// Creates a [WebSplashGenerator] with default dependencies.
  factory WebSplashGenerator.defaults() {
    return WebSplashGenerator(
      imageProcessor: DefaultImageProcessor(),
      imageOptimizer: const DefaultImageOptimizer(),
    );
  }

  /// The image processor used for loading and resizing images.
  final DefaultImageProcessor imageProcessor;

  /// The image optimizer used for PNG encoding.
  final DefaultImageOptimizer imageOptimizer;

  /// The size of the generated web splash image in pixels.
  static const int splashSize = 512;

  @override
  Future<void> generate(SplashConfig config, String projectRoot,
      {String? flavorName}) async {
    // Load and validate the source splash image.
    final sourceImage = await imageProcessor.loadAndValidate(config.imagePath);

    // Ensure the web directory exists.
    final webDir = Directory('$projectRoot/web');
    if (!webDir.existsSync()) {
      webDir.createSync(recursive: true);
    }

    // Resize the splash image to 512x512.
    final resized = imageProcessor.resize(sourceImage, splashSize, splashSize);

    // Encode and write the splash image.
    final pngBytes = imageOptimizer.encodePng(resized);
    File('$projectRoot/web/splash.png').writeAsBytesSync(pngBytes);

    // Update index.html to reference the splash image during Flutter loading.
    _updateIndexHtml(projectRoot, config.backgroundColor);
  }

  /// Updates `web/index.html` to display the splash image during
  /// Flutter engine initialization.
  ///
  /// Adds a styled container with the splash image that is displayed
  /// while Flutter loads. If a background color is provided, it is
  /// applied to the splash container.
  ///
  /// If the file doesn't exist, skips the update.
  void _updateIndexHtml(String projectRoot, String? backgroundColor) {
    final indexFile = File('$projectRoot/web/index.html');

    if (!indexFile.existsSync()) {
      return;
    }

    var content = indexFile.readAsStringSync();

    final bgColor = backgroundColor ?? '#ffffff';

    // The splash loading style and element to inject.
    const splashStyleId = 'flutter-splash-style';
    const splashElementId = 'flutter-splash';

    // Check if splash elements already exist and remove them for re-generation.
    final existingStyleRegex = RegExp(
      r'<style id="flutter-splash-style">.*?</style>\s*',
      dotAll: true,
    );
    final existingElementRegex = RegExp(
      r'<div id="flutter-splash">.*?</div>\s*',
      dotAll: true,
    );

    content = content.replaceAll(existingStyleRegex, '');
    content = content.replaceAll(existingElementRegex, '');

    // Build the splash style block.
    final splashStyle = '''
  <style id="$splashStyleId">
    #$splashElementId {
      position: fixed;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      display: flex;
      align-items: center;
      justify-content: center;
      background-color: $bgColor;
      z-index: 1000;
    }
    #$splashElementId img {
      max-width: 512px;
      max-height: 512px;
      width: 50%;
      height: auto;
    }
  </style>''';

    // Build the splash element.
    final splashElement =
        '  <div id="$splashElementId"><img src="splash.png" alt="App Splash"/></div>';

    // Insert the style inside <head>.
    final headCloseRegex = RegExp(r'</head>', caseSensitive: false);
    final headCloseMatch = headCloseRegex.firstMatch(content);

    if (headCloseMatch != null) {
      final insertPos = headCloseMatch.start;
      content =
          '${content.substring(0, insertPos)}$splashStyle\n${content.substring(insertPos)}';
    }

    // Insert the splash element at the start of <body>.
    final bodyRegex = RegExp(r'<body[^>]*>', caseSensitive: false);
    final bodyMatch = bodyRegex.firstMatch(content);

    if (bodyMatch != null) {
      final insertPos = bodyMatch.end;
      content =
          '${content.substring(0, insertPos)}\n$splashElement\n${content.substring(insertPos)}';
    }

    indexFile.writeAsStringSync(content);
  }
}
