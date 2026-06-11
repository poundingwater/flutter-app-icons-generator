import 'dart:io';

import 'package:args/args.dart';

import 'package:flutter_app_icons_generator/src/cli/console_logger.dart';
import 'package:flutter_app_icons_generator/src/cli/logger.dart';
import 'package:flutter_app_icons_generator/src/config/config_model.dart';
import 'package:flutter_app_icons_generator/src/config/config_parser.dart';
import 'package:flutter_app_icons_generator/src/config/config_printer.dart';
import 'package:flutter_app_icons_generator/src/config/yaml_config_parser.dart';
import 'package:flutter_app_icons_generator/src/core/asset_cleaner.dart';
import 'package:flutter_app_icons_generator/src/core/icon_generator.dart';
import 'package:flutter_app_icons_generator/src/core/platform_updater.dart';
import 'package:flutter_app_icons_generator/src/core/splash_generator.dart';
import 'package:flutter_app_icons_generator/src/core/default_image_optimizer.dart';
import 'package:flutter_app_icons_generator/src/core/default_image_processor.dart';
import 'package:flutter_app_icons_generator/src/platforms/android/android_icon_generator.dart';
import 'package:flutter_app_icons_generator/src/platforms/android/android_splash_generator.dart';
import 'package:flutter_app_icons_generator/src/platforms/android/android_updater.dart';
import 'package:flutter_app_icons_generator/src/platforms/ios/ios_icon_generator.dart';
import 'package:flutter_app_icons_generator/src/platforms/ios/ios_splash_generator.dart';
import 'package:flutter_app_icons_generator/src/platforms/ios/ios_updater.dart';
import 'package:flutter_app_icons_generator/src/platforms/linux/linux_icon_generator.dart';
import 'package:flutter_app_icons_generator/src/platforms/linux/linux_splash_generator.dart';
import 'package:flutter_app_icons_generator/src/platforms/linux/linux_updater.dart';
import 'package:flutter_app_icons_generator/src/platforms/macos/macos_icon_generator.dart';
import 'package:flutter_app_icons_generator/src/platforms/macos/macos_splash_generator.dart';
import 'package:flutter_app_icons_generator/src/platforms/macos/macos_updater.dart';
import 'package:flutter_app_icons_generator/src/platforms/web/web_icon_generator.dart';
import 'package:flutter_app_icons_generator/src/platforms/web/web_splash_generator.dart';
import 'package:flutter_app_icons_generator/src/platforms/web/web_updater.dart';
import 'package:flutter_app_icons_generator/src/platforms/windows/windows_icon_generator.dart';
import 'package:flutter_app_icons_generator/src/platforms/windows/windows_splash_generator.dart';
import 'package:flutter_app_icons_generator/src/platforms/windows/windows_updater.dart';
import 'package:flutter_app_icons_generator/src/shared/constants.dart';
import 'package:flutter_app_icons_generator/src/shared/exceptions.dart';

/// Default config file name.
const String _configFileName = 'flutter_app_icons_generator.yml';

/// CLI runner that orchestrates the full icon/splash generation pipeline.
///
/// Parses command-line arguments, loads configuration, and drives the
/// generation pipeline for each target platform with continue-on-error
/// semantics for individual platform failures.
class CliRunner {
  /// Creates a [CliRunner] with optional dependency overrides.
  ///
  /// If dependencies are not provided, sensible defaults are used.
  CliRunner({
    ConfigParser? configParser,
    ConfigPrinter? configPrinter,
    AssetCleaner? assetCleaner,
    Map<Platform, IconGenerator>? iconGenerators,
    Map<Platform, PlatformUpdater>? platformUpdaters,
    Map<Platform, SplashGenerator>? splashGenerators,
  })  : _configParser = configParser ?? const YamlConfigParser(),
        _configPrinter = configPrinter ?? YamlConfigPrinter(),
        _assetCleaner = assetCleaner ?? DefaultAssetCleaner(),
        _iconGenerators = iconGenerators ?? _defaultIconGenerators(),
        _platformUpdaters = platformUpdaters ?? _defaultPlatformUpdaters(),
        _splashGenerators = splashGenerators ?? _defaultSplashGenerators();

  final ConfigParser _configParser;
  final ConfigPrinter _configPrinter;
  final AssetCleaner _assetCleaner;
  final Map<Platform, IconGenerator> _iconGenerators;
  final Map<Platform, PlatformUpdater> _platformUpdaters;
  final Map<Platform, SplashGenerator> _splashGenerators;

  /// Runs the CLI with the given [arguments].
  ///
  /// Returns an exit code: 0 for success, 1 for errors.
  Future<int> run(List<String> arguments) async {
    final ArgResults args;
    try {
      args = _buildParser().parse(arguments);
    } on FormatException catch (e) {
      stderr.writeln('❌ Error: ${e.message}');
      stderr.writeln('');
      _printUsage();
      return 1;
    }

    // Handle --help flag.
    if (args['help'] as bool) {
      _printUsage();
      return 0;
    }

    final verbose = args['verbose'] as bool;
    final logger = ConsoleLogger(verbose: verbose);
    final projectRoot =
        args['project-root'] as String? ?? Directory.current.path;

    // Handle --init flag.
    if (args['init'] as bool) {
      return _handleInit(projectRoot, logger);
    }

    // Normal run: parse → validate → clean → generate → update → report.
    return _runPipeline(projectRoot, logger);
  }

  /// Handles the --init flag: generates a default config file.
  int _handleInit(String projectRoot, Logger logger) {
    final configPath = '$projectRoot/$_configFileName';
    final configFile = File(configPath);

    if (configFile.existsSync()) {
      final exception = ConfigExistsException(configPath);
      logger.fatalError(exception.message);
      return exception.exitCode;
    }

    final defaultContent = _configPrinter.printDefault();
    configFile.writeAsStringSync(defaultContent);
    logger.info('✓ Created $configPath');
    return 0;
  }

  /// Runs the full generation pipeline.
  Future<int> _runPipeline(String projectRoot, Logger logger) async {
    // Parse config.
    final AppIconsConfig config;
    try {
      config = await _configParser.parse(projectRoot);
    } on AppIconsException catch (e) {
      logger.fatalError(e.message);
      return e.exitCode;
    }

    final stopwatch = Stopwatch()..start();
    var totalFiles = 0;
    final errors = <PlatformGenerationException>[];

    // Process each platform.
    for (final platform in config.platforms) {
      final supportsFlavors =
          platform == Platform.android || platform == Platform.ios;

      if (config.flavors.isNotEmpty && supportsFlavors) {
        for (final entry in config.flavors.entries) {
          final flavorName = entry.key;
          final flavorConfig = entry.value;

          final success = await _processPlatform(
            platform: platform,
            iconConfig: flavorConfig.icon,
            splashConfig: flavorConfig.splash,
            flavorName: flavorName,
            projectRoot: projectRoot,
            logger: logger,
            errors: errors,
          );
          if (success) totalFiles++;
        }
      } else {
        if (config.isValid) {
          final success = await _processPlatform(
            platform: platform,
            iconConfig: config.icon,
            splashConfig: config.splash,
            flavorName: null,
            projectRoot: projectRoot,
            logger: logger,
            errors: errors,
          );
          if (success) totalFiles++;
        } else {
          logger.verbose(
              '  Skipped default generation for ${platform.name} (no default config)');
        }
      }
    }

    // Configure platform-level flavor settings after all assets are generated.
    if (config.flavors.isNotEmpty) {
      await _configureFlavorPlatformSettings(config, projectRoot, logger);
    }

    // Log splash skip message if not configured.
    if (config.splash == null &&
        config.flavors.values.every((f) => f.splash == null)) {
      logger
          .info('ℹ Splash screen not configured — skipping splash generation.');
    }

    stopwatch.stop();
    logger.summary(totalFiles, stopwatch.elapsed);

    // Return non-zero if all platforms failed.
    if (errors.length == config.platforms.length) {
      return 1;
    }

    return 0;
  }

  /// Configures platform-level flavor settings (build.gradle.kts, Xcode schemes, etc.)
  ///
  /// This is called once after all flavor assets have been generated, as these
  /// configurations apply to all flavors at once rather than per-flavor.
  Future<void> _configureFlavorPlatformSettings(
    AppIconsConfig config,
    String projectRoot,
    Logger logger,
  ) async {
    // Android: configure productFlavors in build.gradle.kts
    if (config.platforms.contains(Platform.android)) {
      try {
        final androidUpdater =
            _platformUpdaters[Platform.android] as AndroidUpdater?;
        if (androidUpdater != null) {
          await androidUpdater.configureProductFlavors(
              projectRoot, config.flavors);
          logger.verbose(
              '  Configured Android productFlavors in build.gradle.kts');
        }
      } on Exception catch (e) {
        logger.platformError(
            Platform.android, 'Failed to configure productFlavors: $e');
      }
    }

    // iOS: configure xcconfigs and schemes
    if (config.platforms.contains(Platform.ios)) {
      try {
        final iosUpdater = _platformUpdaters[Platform.ios] as IosUpdater?;
        if (iosUpdater != null) {
          await iosUpdater.configureFlavors(projectRoot, config.flavors);
          logger.verbose('  Configured iOS xcconfigs and schemes for flavors');
        }
      } on Exception catch (e) {
        logger.platformError(
            Platform.ios, 'Failed to configure iOS flavor settings: $e');
      }
    }
  }

  /// Processes a single platform for a specific configuration.
  Future<bool> _processPlatform({
    required Platform platform,
    required IconConfig iconConfig,
    required SplashConfig? splashConfig,
    required String? flavorName,
    required String projectRoot,
    required Logger logger,
    required List<PlatformGenerationException> errors,
  }) async {
    final resolvedIcon = iconConfig.resolve(platform);

    // Validate sources
    if (resolvedIcon.foregroundPath == null) {
      logger.fatalError(
        'No icon source configured for ${platform.name}${flavorName != null ? ' (flavor: $flavorName)' : ''}.',
      );
      return false;
    }
    final foregroundFile = File(resolvedIcon.foregroundPath!);
    if (!foregroundFile.existsSync()) {
      logger
          .fatalError('Source image not found: ${resolvedIcon.foregroundPath}');
      return false;
    }
    if (resolvedIcon.background is BackgroundImage) {
      final bgPath = (resolvedIcon.background! as BackgroundImage).imagePath;
      final bgFile = File(bgPath);
      if (!bgFile.existsSync()) {
        logger.fatalError('Background image not found: $bgPath');
        return false;
      }
    }

    final platformLogName =
        flavorName != null ? '${platform.name} [$flavorName]' : platform.name;

    try {
      logger.info('Running for $platformLogName...');

      // Clean old assets
      await _assetCleaner.clean(platform, projectRoot, flavorName: flavorName);
      logger.verbose('  Cleaned old assets for $platformLogName');

      // Generate icons
      final generator = _iconGenerators[platform];
      if (generator != null) {
        await generator.generate(resolvedIcon, projectRoot,
            flavorName: flavorName);
        logger.verbose('  Generated icons for $platformLogName');
      }

      // Update platform config files
      final updater = _platformUpdaters[platform];
      if (updater != null) {
        await updater.update(projectRoot, flavorName: flavorName);
        logger.verbose('  Updated config for $platformLogName');
      }

      // Generate splash
      if (splashConfig != null) {
        final splashGenerator = _splashGenerators[platform];
        if (splashGenerator != null) {
          await splashGenerator.generate(splashConfig, projectRoot,
              flavorName: flavorName);
          logger.verbose('  Generated splash for $platformLogName');
        }
      }

      logger.info('✓ Completed $platformLogName');
      return true;
    } on Exception catch (e) {
      final platformError = PlatformGenerationException(
        platform: platform,
        error: e.toString(),
      );
      errors.add(platformError);
      logger.platformError(platform, platformError.error);
      return false;
    }
  }

  /// Builds the argument parser.
  ArgParser _buildParser() {
    return ArgParser()
      ..addFlag(
        'init',
        help: 'Generate a default flutter_app_icons_generator.yml config file.',
        negatable: false,
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        help: 'Enable verbose output with detailed file paths.',
        negatable: false,
      )
      ..addFlag(
        'help',
        abbr: 'h',
        help: 'Show usage information.',
        negatable: false,
      )
      ..addOption(
        'project-root',
        abbr: 'p',
        help:
            'Path to the Flutter project root (defaults to current directory).',
      );
  }

  /// Prints usage/help information to stdout.
  void _printUsage() {
    stdout.writeln(
        'flutter_app_icons_generator — App Icon & Splash Screen Generator');
    stdout.writeln('');
    stdout.writeln('Usage: dart run flutter_app_icons_generator [options]');
    stdout.writeln('');
    stdout.writeln(_buildParser().usage);
  }

  /// Default icon generators for all platforms.
  static Map<Platform, IconGenerator> _defaultIconGenerators() {
    final imageProcessor = DefaultImageProcessor();
    final imageOptimizer = DefaultImageOptimizer();

    return {
      Platform.android: AndroidIconGenerator(),
      Platform.ios: IosIconGenerator(),
      Platform.macos: MacosIconGenerator(
        imageProcessor: imageProcessor,
        imageOptimizer: imageOptimizer,
      ),
      Platform.web: WebIconGenerator(
        imageProcessor: imageProcessor,
        imageOptimizer: imageOptimizer,
      ),
      Platform.linux: LinuxIconGenerator(),
      Platform.windows: WindowsIconGenerator(),
    };
  }

  /// Default platform updaters for all platforms.
  static Map<Platform, PlatformUpdater> _defaultPlatformUpdaters() {
    return {
      Platform.android: AndroidUpdater(),
      Platform.ios: IosUpdater(),
      Platform.macos: MacosUpdater(),
      Platform.web: WebUpdater(),
      Platform.linux: LinuxUpdater(),
      Platform.windows: WindowsUpdater(),
    };
  }

  /// Default splash generators for all platforms.
  static Map<Platform, SplashGenerator> _defaultSplashGenerators() {
    final imageProcessor = DefaultImageProcessor();
    final imageOptimizer = DefaultImageOptimizer();

    return {
      Platform.android: AndroidSplashGenerator(),
      Platform.ios: IosSplashGenerator(),
      Platform.macos: MacosSplashGenerator(
        imageProcessor: imageProcessor,
        imageOptimizer: imageOptimizer,
      ),
      Platform.web: WebSplashGenerator(
        imageProcessor: imageProcessor,
        imageOptimizer: imageOptimizer,
      ),
      Platform.linux: LinuxSplashGenerator(
        imageProcessor: imageProcessor,
        imageOptimizer: imageOptimizer,
      ),
      Platform.windows: WindowsSplashGenerator(
        imageProcessor: imageProcessor,
        imageOptimizer: imageOptimizer,
      ),
    };
  }
}
