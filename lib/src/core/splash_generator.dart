import 'package:flutter_app_icons_generator/src/config/config_model.dart';

/// Abstract interface for platform-specific splash screen generation.
///
/// Each platform provides a concrete implementation that generates
/// native splash screen assets displayed during app startup.
abstract class SplashGenerator {
  /// Generates splash screen assets for this platform.
  ///
  /// [config] contains the splash image path and background color settings.
  /// [projectRoot] is the root directory of the Flutter project.
  Future<void> generate(SplashConfig config, String projectRoot);
}
