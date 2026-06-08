import 'package:flutter_app_icons_generator/src/shared/constants.dart';

/// Base exception for all flutter_app_icons_generator errors.
sealed class AppIconsException implements Exception {
  /// Human-readable error message.
  String get message;

  /// CLI exit code (always 1 for fatal errors).
  int get exitCode => 1;

  @override
  String toString() => message;
}

/// Config file not found at expected path.
class ConfigNotFoundException extends AppIconsException {
  ConfigNotFoundException(this.expectedPath);

  /// The path where the config file was expected.
  final String expectedPath;

  @override
  String get message => 'Configuration file not found: $expectedPath';
}

/// YAML parsing failed.
class ConfigParseException extends AppIconsException {
  ConfigParseException(this.yamlError, {this.lineNumber});

  /// The underlying YAML parsing error description.
  final String yamlError;

  /// The line number where the error occurred, if available.
  final int? lineNumber;

  @override
  String get message => lineNumber != null
      ? 'Invalid YAML at line $lineNumber: $yamlError'
      : 'Invalid YAML: $yamlError';
}

/// Required config fields are missing.
class ConfigValidationException extends AppIconsException {
  ConfigValidationException(this.missingFields);

  /// List of field names that are missing from the config.
  final List<String> missingFields;

  @override
  String get message => 'Missing required fields: ${missingFields.join(", ")}';
}

/// Source image file not found.
class ImageNotFoundException extends AppIconsException {
  ImageNotFoundException(this.path);

  /// The path where the image was expected.
  final String path;

  @override
  String get message => 'Image not found: $path';
}

/// Source image dimensions too small.
class ImageDimensionException extends AppIconsException {
  ImageDimensionException({
    required this.actualWidth,
    required this.actualHeight,
    this.minRequired = 1024,
  });

  /// Actual width of the loaded image.
  final int actualWidth;

  /// Actual height of the loaded image.
  final int actualHeight;

  /// Minimum required dimension (1024).
  final int minRequired;

  @override
  String get message =>
      'Image dimensions ${actualWidth}x$actualHeight are below minimum '
      '${minRequired}x$minRequired';
}

/// Unsupported image format.
class ImageFormatException extends AppIconsException {
  ImageFormatException(this.detectedFormat);

  /// The format that was detected in the file.
  final String detectedFormat;

  @override
  String get message =>
      'Unsupported format "$detectedFormat". Supported: PNG, JPEG';
}

/// Config file already exists (--init conflict).
class ConfigExistsException extends AppIconsException {
  ConfigExistsException(this.path);

  /// The path where the config file already exists.
  final String path;

  @override
  String get message => 'Config file already exists: $path';
}

/// Non-fatal platform generation error.
class PlatformGenerationException implements Exception {
  PlatformGenerationException({required this.platform, required this.error});

  /// The platform that encountered the error.
  final Platform platform;

  /// Description of the error.
  final String error;

  /// Human-readable error message.
  String get message => '[$platform] Generation failed: $error';

  @override
  String toString() => message;
}
