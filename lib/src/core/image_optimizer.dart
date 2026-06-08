import 'package:image/image.dart' as img;

/// Abstract interface for image encoding and optimization.
///
/// Provides lossless PNG encoding, ICO format encoding, and ICNS format
/// encoding for generating optimized platform-specific icon assets.
abstract class ImageOptimizer {
  /// Encodes [image] to PNG format with lossless compression.
  ///
  /// [compressionLevel] controls the compression effort (0-9, default 6).
  /// Higher values produce smaller files but take longer to encode.
  List<int> encodePng(img.Image image, {int compressionLevel = 6});

  /// Encodes [image] to ICO format with multiple embedded sizes.
  ///
  /// [sizes] specifies the pixel dimensions to embed in the ICO file
  /// (e.g., [16, 32, 48, 64, 128, 256] for Windows icons).
  List<int> encodeIco(img.Image image, List<int> sizes);

  /// Encodes [image] to ICNS (Apple Icon Image) format with multiple sizes.
  ///
  /// Generates a valid .icns file containing PNG-encoded icon data at
  /// standard macOS sizes (16, 32, 64, 128, 256, 512, 1024).
  List<int> encodeIcns(img.Image image);
}
