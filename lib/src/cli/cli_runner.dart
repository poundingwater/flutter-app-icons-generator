import 'dart:io' hide Platform;

import 'package:flutter_app_icons_generator/src/cli/arg_parser.dart';
import 'package:flutter_app_icons_generator/src/cli/console_logger.dart';
import 'package:flutter_app_icons_generator/src/cli/default_factories.dart';
import 'package:flutter_app_icons_generator/src/cli/logger.dart';
import 'package:flutter_app_icons_generator/src/cli/pipeline_runner.dart';
import 'package:flutter_app_icons_generator/src/config/config_parser.dart';
import 'package:flutter_app_icons_generator/src/config/config_printer.dart';
import 'package:flutter_app_icons_generator/src/config/yaml_config_parser.dart';
import 'package:flutter_app_icons_generator/src/core/asset_cleaner.dart';
import 'package:flutter_app_icons_generator/src/core/icon_generator.dart';
import 'package:flutter_app_icons_generator/src/core/platform_updater.dart';
import 'package:flutter_app_icons_generator/src/core/splash_generator.dart';
import 'package:flutter_app_icons_generator/src/shared/constants.dart';
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
        _iconGenerators = iconGenerators ?? DefaultFactories.iconGenerators(),
        _platformUpdaters =
            platformUpdaters ?? DefaultFactories.platformUpdaters(),
        _splashGenerators =
            splashGenerators ?? DefaultFactories.splashGenerators(),
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

  final CliArgParser _argParser = CliArgParser();

  /// Reads a line from stdin, or uses the override if provided.
  String? _readLine() {
    if (_promptOverride != null) return _promptOverride!();
    return stdin.readLineSync();
  }

  /// Runs the CLI with the given [arguments].
  ///
  /// Returns an exit code: 0 for success, 1 for errors.
  Future<int> run(List<String> arguments) async {
    final args;
    try {
      args = _argParser.build().parse(arguments);
    } on FormatException catch (e) {
      stderr.writeln('❌ Error: ${e.message}');
      stderr.writeln('');
      _argParser.printUsage();
      return 1;
    }

    // Handle --help flag.
    if (args['help'] as bool) {
      _argParser.printUsage();
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
    final pipeline = PipelineRunner(
      configParser: _configParser,
      assetCleaner: _assetCleaner,
      iconGenerators: _iconGenerators,
      platformUpdaters: _platformUpdaters,
      splashGenerators: _splashGenerators,
      launchJsonGenerator: _launchJsonGenerator,
      flavorDartGenerator: _flavorDartGenerator,
      readLine: _readLine,
    );
    return pipeline.run(projectRoot, logger);
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
}
