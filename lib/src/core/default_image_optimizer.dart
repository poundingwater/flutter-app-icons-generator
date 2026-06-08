import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'image_optimizer.dart';

/// Default implementation of [ImageOptimizer] using the `image` package.
///
/// Provides lossless PNG encoding with configurable compression level,
/// multi-size ICO format encoding for Windows icon generation, and
/// ICNS format encoding for macOS icon generation.
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

  @override
  List<int> encodeIcns(img.Image image) {
    return _IcnsEncoder(this).encode(image);
  }
}

/// Internal ICNS encoder that produces a valid Apple Icon Image (.icns) file.
///
/// The ICNS format is:
/// - 8-byte file header: magic "icns" (4 bytes) + total file size (4 bytes BE)
/// - N icon elements, each: OSType (4 bytes) + element size (4 bytes BE) + PNG data
///
/// We use the modern PNG-based icon types (ic07–ic14, ic10) which are
/// supported on macOS 10.7+.
class _IcnsEncoder {
  _IcnsEncoder(this._optimizer);

  final DefaultImageOptimizer _optimizer;

  /// ICNS OSType codes mapped to their pixel dimensions.
  ///
  /// These are the modern PNG-based types for macOS 10.7+.
  static const List<_IcnsEntry> _entries = [
    _IcnsEntry('ic07', 128), // 128x128
    _IcnsEntry('ic08', 256), // 256x256
    _IcnsEntry('ic09', 512), // 512x512
    _IcnsEntry('ic10', 1024), // 1024x1024 (512x512@2x)
    _IcnsEntry('ic11', 32), // 32x32 (16x16@2x)
    _IcnsEntry('ic12', 64), // 64x64 (32x32@2x)
    _IcnsEntry('ic13', 256), // 256x256 (128x128@2x)
    _IcnsEntry('ic14', 512), // 512x512 (256x256@2x)
  ];

  /// Encodes the image into ICNS format.
  List<int> encode(img.Image image) {
    // Generate PNG data for each required size.
    final elements = <_IcnsElement>[];

    // Track which sizes we've already encoded to avoid duplicate work.
    final encodedSizes = <int, List<int>>{};

    for (final entry in _entries) {
      // Resize the image if we haven't already encoded this size.
      if (!encodedSizes.containsKey(entry.size)) {
        final resized = img.copyResize(
          image,
          width: entry.size,
          height: entry.size,
          interpolation: img.Interpolation.average,
        );
        encodedSizes[entry.size] = _optimizer.encodePng(resized);
      }

      final pngData = encodedSizes[entry.size]!;
      elements.add(_IcnsElement(entry.osType, pngData));
    }

    // Calculate total file size.
    // Header: 8 bytes (4 magic + 4 size)
    // Each element: 8 bytes header (4 OSType + 4 size) + PNG data length
    var totalSize = 8;
    for (final element in elements) {
      totalSize += 8 + element.data.length;
    }

    // Build the binary output.
    final buffer = ByteData(totalSize);
    var offset = 0;

    // File header: "icns" magic.
    buffer.setUint8(offset++, 0x69); // 'i'
    buffer.setUint8(offset++, 0x63); // 'c'
    buffer.setUint8(offset++, 0x6E); // 'n'
    buffer.setUint8(offset++, 0x73); // 's'

    // File header: total file size (big-endian).
    buffer.setUint32(offset, totalSize, Endian.big);
    offset += 4;

    // Write each icon element.
    for (final element in elements) {
      // OSType (4 ASCII bytes).
      for (var i = 0; i < 4; i++) {
        buffer.setUint8(offset++, element.osType.codeUnitAt(i));
      }

      // Element size: 8 (header) + data length (big-endian).
      final elementSize = 8 + element.data.length;
      buffer.setUint32(offset, elementSize, Endian.big);
      offset += 4;

      // PNG data.
      for (final byte in element.data) {
        buffer.setUint8(offset++, byte);
      }
    }

    return buffer.buffer.asUint8List();
  }
}

/// An ICNS entry definition (OSType code + target pixel size).
class _IcnsEntry {
  const _IcnsEntry(this.osType, this.size);

  /// The 4-character OSType code (e.g., 'ic07').
  final String osType;

  /// The target pixel dimension (width = height).
  final int size;
}

/// A prepared ICNS element ready to be written (OSType + PNG data).
class _IcnsElement {
  const _IcnsElement(this.osType, this.data);

  /// The 4-character OSType code.
  final String osType;

  /// The PNG-encoded image data.
  final List<int> data;
}
