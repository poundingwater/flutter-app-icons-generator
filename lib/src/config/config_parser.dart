import 'package:flutter_app_icons/src/config/config_model.dart';

/// Abstract interface for parsing the flutter_app_icons.yml configuration file.
///
/// Reads and validates the YAML configuration, producing a strongly-typed
/// [AppIconsConfig] object for use in the generation pipeline.
abstract class ConfigParser {
  /// Parses the flutter_app_icons.yml file from [projectRoot].
  ///
  /// Locates the configuration file, parses the YAML content, and validates
  /// that all required fields are present and correctly structured.
  ///
  /// Throws [ConfigNotFoundException] if the file doesn't exist.
  /// Throws [ConfigParseException] if the YAML syntax is invalid.
  /// Throws [ConfigValidationException] if required fields are missing.
  Future<AppIconsConfig> parse(String projectRoot);
}
