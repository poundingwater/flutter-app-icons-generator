import 'dart:io' hide Platform;

import 'package:flutter_app_icons_generator/src/cli/asset_detector.dart';
import 'package:flutter_app_icons_generator/src/cli/logger.dart';
import 'package:flutter_app_icons_generator/src/config/config_model.dart';
import 'package:flutter_app_icons_generator/src/config/config_parser.dart';
import 'package:flutter_app_icons_generator/src/config/config_resolver.dart';
import 'package:flutter_app_icons_generator/src/config/config_validator.dart';
import 'package:flutter_app_icons_generator/src/core/asset_cleaner.dart';
import 'package:flutter_app_icons_generator/src/core/icon_generator.dart';
import 'package:flutter_app_icons_generator/src/core/platform_updater.dart';
import 'package:flutter_app_icons_generator/src/core/splash_generator.dart';
import 'package:flutter_app_icons_generator/src/platforms/android/android_updater.dart';
import 'package:flutter_app_icons_generator/src/platforms/ios/ios_updater.dart';
import 'package:flutter_app_icons_generator/src/platforms/macos/macos_updater.dart';
import 'package:flutter_app_icons_generator/src/shared/constants.dart';
import 'package:flutter_app_icons_generator/src/shared/exceptions.dart';
import 'package:flutter_app_icons_generator/src/shared/launch_json_generator.dart';
import 'package:flutter_app_icons_generator/src/flavors/flavor_dart_generator.dart';

/// Orchestrates the full icon/splash generation pipeline.
///
/// Parses configuration, validates it, cleans old assets, generates new ones,
/// and updates platform config files with continue-on-error semantics.
class PipelineRunner {
  PipelineRunner({
    required ConfigParser configParser,
    required AssetCleaner assetCleaner,
    required Map<Platform, IconGenerator> iconGenerators,
    required Map<Platform, PlatformUpdater> platformUpdaters,
    required Map<Platform, SplashGenerator> splashGenerators,
    required LaunchJsonGenerator launchJsonGenerator,
    required FlavorDartGenerator flavorDartGenerator,
    required String? Function() readLine,
  })  : _configParser = configParser,
        _assetCleaner = assetCleaner,
        _iconGenerators = iconGenerators,
        _platformUpdaters = platformUpdaters,
        _splashGenerators = splashGenerators,
        _launchJsonGenerator = launchJsonGenerator,
        _flavorDartGenerator = flavorDartGenerator,
        _readLine = readLine;

  final ConfigParser _configParser;
  final AssetCleaner _assetCleaner;
  final Map<Platform, IconGenerator> _iconGenerators;
  final Map<Platform, PlatformUpdater> _platformUpdaters;
  final Map<Platform, SplashGenerator> _splashGenerators;
  final LaunchJsonGenerator _launchJsonGenerator;
  final FlavorDartGenerator _flavorDartGenerator;
  final String? Function() _readLine;

  final AssetDetector _assetDetector = AssetDetector();

  /// Runs the full generation pipeline.
  Future<int> run(String projectRoot, Logger logger) async {
    // Parse config.
    final AppIconsConfig config;
    try {
      config = await _configParser.parse(projectRoot);
    } on AppIconsException catch (e) {
      logger.fatalError(e.message);
      return e.exitCode;
    }

    // Validate config.
    try {
      ConfigValidator.validate(config);
    } on AppIconsException catch (e) {
      logger.fatalError(e.message);
      return e.exitCode;
    }

    // Detect existing generated assets and prompt user for confirmation.
    final existingAssets = _assetDetector.detect(config, projectRoot);
    if (existingAssets.isNotEmpty) {
      logger.info('⚠️  Existing generated assets detected:');
      for (final asset in existingAssets) {
        logger.info('   • $asset');
      }
      logger.info('');
      stdout.write('These will be removed and regenerated. Continue? [y/N] ');
      final response = _readLine()?.trim().toLowerCase() ?? '';
      if (response != 'y' && response != 'yes') {
        logger.info('Aborted.');
        return 0;
      }
      logger.info('');
    }

    final stopwatch = Stopwatch()..start();
    var totalFiles = 0;
    final errors = <PlatformGenerationException>[];

    // Process each platform.
    for (final platform in config.platforms) {
      final supportsFlavors = platform == Platform.android ||
          platform == Platform.ios ||
          platform == Platform.macos;

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

    // Generate .vscode/launch.json for IDE support when flavors are configured.
    if (config.flavors.isNotEmpty) {
      _generateFlavorFiles(config, projectRoot, logger);
    }

    stopwatch.stop();
    logger.summary(totalFiles, stopwatch.elapsed);

    // Return non-zero if all platforms failed.
    if (errors.length == config.platforms.length) {
      return 1;
    }

    return 0;
  }

  /// Generates flavor Dart files and .vscode/launch.json.
  void _generateFlavorFiles(
      AppIconsConfig config, String projectRoot, Logger logger) {
    final packageName = _resolvePackageName(projectRoot);
    final dartResult = _flavorDartGenerator.generate(
      projectRoot: projectRoot,
      flavors: config.flavors.keys.toSet(),
      packageName: packageName,
    );
    if (dartResult.hasCreatedFiles) {
      for (final file in dartResult.createdFiles) {
        logger.info('✓ Created $file');
      }
    }
    if (dartResult.skippedFiles.isNotEmpty) {
      for (final file in dartResult.skippedFiles) {
        logger.verbose('  Skipped $file — already exists');
      }
    }

    final wrote = _launchJsonGenerator.generate(
      projectRoot,
      config.flavors.keys.toSet(),
    );
    if (wrote) {
      logger.info('✓ Generated .vscode/launch.json with flavor configurations');
    } else {
      logger.verbose(
          '  Skipped launch.json — file exists with user modifications');
    }
  }

  /// Configures platform-level flavor settings (build.gradle.kts, Xcode schemes, etc.)
  Future<void> _configureFlavorPlatformSettings(
    AppIconsConfig config,
    String projectRoot,
    Logger logger,
  ) async {
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

    if (config.platforms.contains(Platform.macos)) {
      try {
        final macosUpdater = _platformUpdaters[Platform.macos] as MacosUpdater?;
        if (macosUpdater != null) {
          await macosUpdater.configureFlavors(projectRoot, config.flavors);
          logger
              .verbose('  Configured macOS xcconfigs and schemes for flavors');
        }
      } on Exception catch (e) {
        logger.platformError(
            Platform.macos, 'Failed to configure macOS flavor settings: $e');
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
    final resolvedIcon = ConfigResolver.resolve(iconConfig, platform);

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

      await _assetCleaner.clean(platform, projectRoot, flavorName: flavorName);
      logger.verbose('  Cleaned old assets for $platformLogName');

      final generator = _iconGenerators[platform];
      if (generator != null) {
        await generator.generate(resolvedIcon, projectRoot,
            flavorName: flavorName);
        logger.verbose('  Generated icons for $platformLogName');
      }

      final updater = _platformUpdaters[platform];
      if (updater != null) {
        await updater.update(projectRoot, flavorName: flavorName);
        logger.verbose('  Updated config for $platformLogName');
      }

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

  /// Resolves the Dart package name from the project's `pubspec.yaml`.
  String _resolvePackageName(String projectRoot) {
    final pubspecFile = File('$projectRoot/pubspec.yaml');
    if (pubspecFile.existsSync()) {
      final content = pubspecFile.readAsStringSync();
      final nameMatch =
          RegExp(r'^name:\s*(\S+)', multiLine: true).firstMatch(content);
      if (nameMatch != null) {
        return nameMatch.group(1)!;
      }
    }
    return Uri.parse(projectRoot).pathSegments.last;
  }
}
