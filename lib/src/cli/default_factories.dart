import 'package:flutter_app_icons_generator/src/shared/constants.dart';
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

/// Factory methods that create default platform-specific generators and updaters.
abstract final class DefaultFactories {
  /// Default icon generators for all platforms.
  static Map<Platform, IconGenerator> iconGenerators() {
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
  static Map<Platform, PlatformUpdater> platformUpdaters() {
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
  static Map<Platform, SplashGenerator> splashGenerators() {
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
