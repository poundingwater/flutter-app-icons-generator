/// Flutter App Icons Generator - Platform-specific app icon and splash screen generator.
///
/// A Dart CLI tool that generates correctly sized, optimized,
/// standards-compliant icon and splash screen assets for iOS, Android,
/// macOS, Linux, Windows, and Web from a single YAML configuration file.
library flutter_app_icons_generator;

// Core
export 'src/core/asset_cleaner.dart';
export 'src/core/icon_generator.dart';
export 'src/core/image_optimizer.dart';
export 'src/core/image_processor.dart';
export 'src/core/platform_updater.dart';
export 'src/core/splash_generator.dart';

// Config
export 'src/config/config_model.dart';
export 'src/config/config_parser.dart';
export 'src/config/config_printer.dart';

// Flavors
export 'src/flavors/flavor_model.dart';
export 'src/flavors/flavor_parser.dart';
export 'src/flavors/flavor_printer.dart';
export 'src/flavors/flavor_dart_generator.dart';

// CLI
export 'src/cli/cli_runner.dart';
export 'src/cli/logger.dart';

// Shared
export 'src/shared/constants.dart';
export 'src/shared/exceptions.dart';
export 'src/shared/launch_json_generator.dart';
