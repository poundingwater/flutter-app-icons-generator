import 'package:flutter_app_icons_generator/src/config/config_model.dart';

/// Abstract interface for platform-specific icon generation.
///
/// Each platform (Android, iOS, macOS, Web, Linux, Windows) provides a
/// concrete implementation that generates correctly sized icon assets
/// according to platform guidelines.
abstract class IconGenerator {
  /// Generates all icon assets for this platform.
  ///
  /// [config] contains the icon source paths and layer configuration.
  /// [projectRoot] is the root directory of the Flutter project.
  Future<void> generate(IconConfig config, String projectRoot);
}
