import 'package:image/image.dart' as img;

import 'image_optimizer.dart';

/// Default implementation of [ImageOptimizer] using the `image` package.
///
/// Provides lossless PNG encoding with configurable compression level,
/// and multi-size ICO format encoding for Windows icon generation.
class DefaultImageOptimizer implements ImageOptimizer {
  /// Creates a [DefaultImageOptimizer].
  const DefaultImageOptimizer();

  @override
  List<int> encodePng(img.Image image, {int compressionLevel = 6}) {
    return img.encodePng(image, level: compressionLevel);
  }

  @override
  List<int> encodeIco(img.Image image, List<int> sizes) {
    if (sizes.isEmpty) {
      throw ArgumentError('sizes must not be empty');
    }

    // Validate all sizes are within ICO format limits (1-256).
    for (final size in sizes) {
      if (size < 1 || size > 256) {
        throw ArgumentError(
          'ICO format supports sizes between 1 and 256, got $size',
        );
      }
    }

    // Create the first frame at the first requested size.
    final sortedSizes = List<int>.from(sizes)..sort();
    final firstSize = sortedSizes.first;
    final firstFrame = img.copyResize(
      image,
      width: firstSize,
      height: firstSize,
      interpolation: img.Interpolation.average,
    );

    // Add remaining sizes as additional frames.
    for (var i = 1; i < sortedSizes.length; i++) {
      final size = sortedSizes[i];
      final frame = img.copyResize(
        image,
        width: size,
        height: size,
        interpolation: img.Interpolation.average,
      );
      firstFrame.addFrame(frame);
    }

    // Encode using IcoEncoder which handles multi-frame images.
    return img.IcoEncoder().encode(firstFrame);
  }
}
