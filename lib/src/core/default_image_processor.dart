import 'dart:io';

import 'package:image/image.dart' as img;

import 'package:flutter_app_icons_generator/src/core/image_processor.dart';
import 'package:flutter_app_icons_generator/src/shared/exceptions.dart';

/// Concrete implementation of [ImageProcessor] using the `image` package.
///
/// Handles loading, validating, resizing, alpha removal, and compositing
/// of source images for the icon generation pipeline.
class DefaultImageProcessor implements ImageProcessor {
  /// Supported file extensions for source images.
  static const _supportedExtensions = {'.png', '.jpg', '.jpeg'};

  @override
  Future<img.Image> loadAndValidate(String path) async {
    final file = File(path);

    // Check file existence.
    if (!file.existsSync()) {
      throw ImageNotFoundException(path);
    }

    // Validate file extension before attempting decode.
    final extension = _fileExtension(path);
    if (!_supportedExtensions.contains(extension)) {
      throw ImageFormatException(extension.isEmpty ? 'unknown' : extension);
    }

    // Read and decode the image bytes.
    final bytes = file.readAsBytesSync();
    final image = img.decodeImage(bytes);

    if (image == null) {
      throw ImageFormatException('unrecognized');
    }

    // Validate minimum dimensions.
    if (image.width < 1024 || image.height < 1024) {
      throw ImageDimensionException(
        actualWidth: image.width,
        actualHeight: image.height,
      );
    }

    return image;
  }

  @override
  img.Image resize(img.Image source, int width, int height) {
    return img.copyResize(
      source,
      width: width,
      height: height,
      interpolation: img.Interpolation.cubic,
    );
  }

  @override
  img.Image removeAlpha(img.Image source) {
    // Create a white background image with the same dimensions.
    final result = img.Image(
      width: source.width,
      height: source.height,
      numChannels: 4,
    );

    // Fill with white.
    img.fill(result, color: img.ColorRgba8(255, 255, 255, 255));

    // Composite the source image onto the white background.
    img.compositeImage(result, source);

    // Ensure all pixels have alpha = 255.
    for (final pixel in result) {
      pixel.a = 255;
    }

    return result;
  }

  @override
  img.Image composite(img.Image foreground, img.Image background) {
    // Create a copy of the background to avoid mutating the original.
    final result = background.clone();

    // Layer the foreground on top of the background.
    img.compositeImage(result, foreground);

    return result;
  }

  /// Extracts the lowercase file extension from a path.
  String _fileExtension(String path) {
    final lastDot = path.lastIndexOf('.');
    if (lastDot == -1 || lastDot == path.length - 1) {
      return '';
    }
    return path.substring(lastDot).toLowerCase();
  }
}
