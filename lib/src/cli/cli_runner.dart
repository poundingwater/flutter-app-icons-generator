import 'dart:io';

import 'package:args/args.dart';

import 'package:flutter_app_icons_generator/src/cli/console_logger.dart';
import 'package:flutter_app_icons_generator/src/cli/logger.dart';
import 'package:flutter_app_icons_generator/src/config/config_model.dart';
import 'package:flutter_app_icons_generator/src/config/config_parser.dart';
import 'package:flutter_app_icons_generator/src/config/config_printer.dart';
import 'package:flutter_app_icons_generator/src/config/config_resolver.dart';
import 'package:flutter_app_icons_generator/src/config/config_validator.dart';
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
import 'package:flutter_app_icons_generator/src/shared/launch_json_generator.dart';
import 'package:flutter_app_icons_generator/src/flavors/flavor_dart_generator.dart';

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
  /// [promptOverride] can be provided in tests to bypass interactive stdin.
  CliRunner({
    ConfigParser? configParser,
    ConfigPrinter? configPrinter,
    AssetCleaner? assetCleaner,
    Map<Platform, IconGenerator>? iconGenerators,
    Map<Platform, PlatformUpdater>? platformUpdaters,
    Map<Platform, SplashGenerator>? splashGenerators,
    LaunchJsonGenerator? launchJsonGenerator,
    FlavorDartGenerator? flavorDartGenerator,
    String? Function()? promptOverride,
  })  : _configParser = configParser ?? const YamlConfigParser(),
        _configPrinter = configPrinter ?? YamlConfigPrinter(),
        _assetCleaner = assetCleaner ?? DefaultAssetCleaner(),
        _iconGenerators = iconGenerators ?? _defaultIconGenerators(),
        _platformUpdaters = platformUpdaters ?? _defaultPlatformUpdaters(),
        _splashGenerators = splashGenerators ?? _defaultSplashGenerators(),
        _launchJsonGenerator =
            launchJsonGenerator ?? const LaunchJsonGenerator(),
        _flavorDartGenerator =
            flavorDartGenerator ?? const FlavorDartGenerator(),
        _promptOverride = promptOverride;

  final ConfigParser _configParser;
  final ConfigPrinter _configPrinter;
  final AssetCleaner _assetCleaner;
  final Map<Platform, IconGenerator> _iconGenerators;
  final Map<Platform, PlatformUpdater> _platformUpdaters;
  final Map<Platform, SplashGenerator> _splashGenerators;
  final LaunchJsonGenerator _launchJsonGenerator;
  final FlavorDartGenerator _flavorDartGenerator;
  final String? Function()? _promptOverride;

  /// Reads a line from stdin, or uses the override if provided.
  String? _readLine() {
    if (_promptOverride != null) return _promptOverride!();
    return stdin.readLineSync();
  }

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
      stdout.write('⚠️  Config file already exists: $configPath\n'
          'Overwrite? [y/N] ');
      final response = _readLine()?.trim().toLowerCase() ?? '';
      if (response != 'y' && response != 'yes') {
        logger.info('Aborted.');
        return 0;
      }
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

    // Validate config (centralized semantic checks).
    try {
      ConfigValidator.validate(config);
    } on AppIconsException catch (e) {
      logger.fatalError(e.message);
      return e.exitCode;
    }

    // Detect existing generated assets and prompt user for confirmation.
    final existingAssets = _detectExistingAssets(config, projectRoot);
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
      // Generate flavor Dart files (flavors.dart + main_<flavor>.dart).
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

      // Generate .vscode/launch.json.
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

    // macOS: configure xcconfigs and schemes
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

  /// Resolves the Dart package name from the project's `pubspec.yaml`.
  ///
  /// Falls back to the project directory name if pubspec can't be parsed.
  String _resolvePackageName(String projectRoot) {
    final pubspecFile = File('$projectRoot/pubspec.yaml');
    if (pubspecFile.existsSync()) {
      final content = pubspecFile.readAsStringSync();
      // Simple regex extraction — avoids pulling in yaml dependency here.
      final nameMatch = RegExp(r'^name:\s*(\S+)', multiLine: true)
          .firstMatch(content);
      if (nameMatch != null) {
        return nameMatch.group(1)!;
      }
    }
    // Fallback: use the directory name.
    return Uri.parse(projectRoot).pathSegments.last;
  }

  /// Detects existing generated assets for the configured platforms.
  ///
  /// Returns a list of human-readable descriptions of found assets.
  /// This enables prompting the user before overwriting.
  List<String> _detectExistingAssets(
      AppIconsConfig config, String projectRoot) {
    final detected = <String>[];

    for (final platform in config.platforms) {
      final supportsFlavors = platform == Platform.android ||
          platform == Platform.ios ||
          platform == Platform.macos;

      if (config.flavors.isNotEmpty && supportsFlavors) {
        // Check for flavor-specific assets.
        for (final flavorName in config.flavors.keys) {
          final assets =
              _detectPlatformAssets(platform, projectRoot, flavorName);
          detected.addAll(assets);
        }
      } else {
        final assets = _detectPlatformAssets(platform, projectRoot, null);
        detected.addAll(assets);
      }
    }

    return detected;
  }

  /// Detects existing generated assets for a specific platform.
  List<String> _detectPlatformAssets(
      Platform platform, String projectRoot, String? flavorName) {
    final detected = <String>[];

    switch (platform) {
      case Platform.android:
        final resDir =
            '$projectRoot/android/app/src/${flavorName ?? "main"}/res';
        final mipmapDir = Directory('$resDir/mipmap-hdpi');
        if (mipmapDir.existsSync()) {
          final icLauncher = File('$resDir/mipmap-hdpi/ic_launcher.png');
          if (icLauncher.existsSync()) {
            final label = flavorName != null
                ? 'Android [$flavorName] mipmap icons'
                : 'Android mipmap icons';
            detected.add(label);
          }
        }

      case Platform.ios:
        final iconName = flavorName != null ? 'AppIcon-$flavorName' : 'AppIcon';
        final assetDir =
            '$projectRoot/ios/Runner/Assets.xcassets/$iconName.appiconset';
        final iconFile = File('$assetDir/app_icon_1024.png');
        if (iconFile.existsSync()) {
          final label = flavorName != null
              ? 'iOS [$flavorName] AppIcon ($iconName.appiconset)'
              : 'iOS AppIcon (AppIcon.appiconset)';
          detected.add(label);
        }

      case Platform.macos:
        final iconName = flavorName != null ? 'AppIcon-$flavorName' : 'AppIcon';
        final appiconsetDir =
            '$projectRoot/macos/Runner/Assets.xcassets/$iconName.appiconset';
        // Check for modern asset catalog PNGs (generated by this package).
        final appiconsetPng = File('$appiconsetDir/app_icon_16x16.png');
        if (appiconsetPng.existsSync()) {
          final label = flavorName != null
              ? 'macOS [$flavorName] AppIcon ($iconName.appiconset)'
              : 'macOS AppIcon ($iconName.appiconset)';
          detected.add(label);
        }
        // Check for legacy .icns files anywhere under macos/Runner/.
        if (flavorName == null) {
          final runnerDir = Directory('$projectRoot/macos/Runner');
          if (runnerDir.existsSync()) {
            final hasIcns = runnerDir
                .listSync(recursive: true)
                .whereType<File>()
                .any((f) => f.path.endsWith('.icns'));
            if (hasIcns) {
              detected.add('macOS legacy .icns icon (will be migrated to asset catalog)');
            }
          }
        }

      case Platform.web:
        final faviconFile = File('$projectRoot/web/favicon.ico');
        if (faviconFile.existsSync()) {
          detected.add('Web icons (favicon.ico, PWA icons)');
        }

      case Platform.linux:
        final linuxIcon = File('$projectRoot/linux/app_icon.png');
        if (linuxIcon.existsSync()) {
          detected.add('Linux icon (app_icon.png)');
        }

      case Platform.windows:
        final windowsIcon =
            File('$projectRoot/windows/runner/resources/app_icon.ico');
        if (windowsIcon.existsSync()) {
          detected.add('Windows icon (app_icon.ico)');
        }
    }

    return detected;
  }
}
