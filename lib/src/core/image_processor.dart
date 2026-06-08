import 'package:image/image.dart' as img;

/// Abstract interface for image loading, validation, resizing, and manipulation.
///
/// Handles all image operations required by the icon generation pipeline:
/// loading source images, validating dimensions and format, resizing to
/// target sizes, removing alpha channels, and compositing layers.
abstract class ImageProcessor {
  /// Loads and validates a source image from [path].
  ///
  /// Validates that:
  /// - The file exists at the specified path
  /// - The image dimensions are at least 1024x1024 pixels
  /// - The file format is PNG or JPEG
  ///
  /// Throws [ImageNotFoundException] if the file doesn't exist.
  /// Throws [ImageDimensionException] if dimensions are below minimum.
  /// Throws [ImageFormatException] if the format is unsupported.
  Future<img.Image> loadAndValidate(String path);

  /// Resizes [source] to the target [width] and [height] using cubic
  /// interpolation for high-quality downscaling.
  img.Image resize(img.Image source, int width, int height);

  /// Returns `true` if [source] contains any pixel with alpha less than 255.
  bool hasTransparency(img.Image source);

  /// Removes the alpha channel from [source] by compositing onto a white
  /// background.
  ///
  /// Returns an image where every pixel has full opacity (alpha = 255).
  img.Image removeAlpha(img.Image source);

  /// Composites [foreground] onto [background], layering the foreground
  /// image on top of the background image.
  ///
  /// Used for generating adaptive icons with separate foreground/background
  /// layers.
  img.Image composite(img.Image foreground, img.Image background);
}
