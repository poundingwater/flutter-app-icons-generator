# Implementation Plan: flutter-app-icons

## Overview

Build a Dart CLI package (`flutter_app_icons`) from scratch that generates platform-specific app icons and native splash screens for Flutter projects. The implementation follows a pipeline architecture (parse → validate → clean → generate → update → report) with feature-first module organization. Each task builds incrementally toward the full CLI, starting with project scaffolding, then core logic, then platform-specific generators, and finally integration wiring.

## Tasks

- [x] 1. Set up project structure and core interfaces
  - [x] 1.1 Initialize Dart package with pubspec.yaml, directory structure, and dependencies
    - Create `pubspec.yaml` with package metadata, `image`, `yaml`, `args` dependencies, and `test`, `glados`, `mockito`, `build_runner` dev dependencies
    - Create directory structure: `bin/`, `lib/src/cli/`, `lib/src/config/`, `lib/src/core/`, `lib/src/platforms/{android,ios,macos,web,linux,windows}/`, `lib/src/shared/`, `test/property/`, `test/config/`, `test/core/`, `test/platforms/`
    - Create `bin/flutter_app_icons.dart` entry point
    - Create `lib/flutter_app_icons.dart` barrel file
    - Create `README.md`, `LICENSE` (MIT), `CHANGELOG.md`, `CONTRIBUTING.md`
    - _Requirements: 16.1, 16.2, 16.3, 16.4, 16.5, 16.6_

  - [x] 1.2 Define shared constants, exceptions, and Platform enum
    - Create `lib/src/shared/constants.dart` with `AndroidSizes`, `IosSizes`, `MacosSizes`, `WebSizes`, `LinuxSizes`, `WindowsSizes`
    - Create `lib/src/shared/exceptions.dart` with the sealed `AppIconsException` hierarchy and `PlatformGenerationException`
    - Create `Platform` enum in a shared location
    - _Requirements: 7.3, 8.1, 9.1, 10.1, 10.2, 11.1, 12.1_

  - [x] 1.3 Define core abstract interfaces
    - Create `IconGenerator`, `SplashGenerator`, `PlatformUpdater` abstract classes
    - Create `ImageProcessor`, `ImageOptimizer`, `AssetCleaner` abstract classes
    - Create `ConfigParser`, `ConfigPrinter` abstract classes
    - Create `Logger` abstract class with all method signatures
    - _Requirements: 16.6_

- [x] 2. Implement configuration parsing and printing
  - [x] 2.1 Implement data models (AppIconsConfig, IconConfig, BackgroundConfig, SplashConfig, SourceImage)
    - Create `lib/src/config/config_model.dart` with all data model classes
    - Implement `BackgroundConfig` as a sealed class with `BackgroundImage` and `BackgroundColor` subtypes
    - Implement `AppIconsConfig` with defaults for `platforms` field
    - _Requirements: 1.2, 1.3, 1.4, 1.5_

  - [x] 2.2 Implement ConfigParser (YAML parsing and validation)
    - Create `lib/src/config/config_parser.dart`
    - Parse `flutter_app_icons.yml` from project root
    - Handle adaptive icon config (foreground + background), combined image, splash config, and platform list
    - Throw appropriate exceptions for missing file, invalid YAML, missing required fields
    - Default to all platforms when `platforms` field is omitted
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9_

  - [x] 2.3 Implement ConfigPrinter (YAML serialization and --init output)
    - Create `lib/src/config/config_printer.dart`
    - Implement `print()` to serialize `AppIconsConfig` to YAML string
    - Implement `printDefault()` to generate commented default config file
    - _Requirements: 2.1, 2.2, 2.4_

  - [x] 2.4 Write property test for configuration round-trip (Property 1)
    - **Property 1: Configuration Round-Trip**
    - Create `test/property/config_roundtrip_test.dart`
    - Define custom `Arbitrary` instances for `AppIconsConfig`, `IconConfig`, `BackgroundConfig`, `SplashConfig`, and `Platform` subsets
    - Verify: print → parse produces semantically equivalent config
    - Minimum 100 iterations
    - **Validates: Requirements 1.2, 1.3, 1.4, 1.5, 2.4**

  - [x] 2.5 Write unit tests for ConfigParser
    - Create `test/config/config_parser_test.dart`
    - Test valid configs: combined image, adaptive icon, splash, platform subsets
    - Test error cases: missing file, invalid YAML, missing required fields
    - Test defaults: omitted platforms field defaults to all
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9_

- [x] 3. Checkpoint - Ensure config layer passes all tests
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Implement core image processing
  - [x] 4.1 Implement ImageProcessor (load, validate, resize, alpha removal, composite)
    - Create `lib/src/core/image_processor.dart`
    - Implement `loadAndValidate()`: check file exists, load with `image` package, verify >= 1024x1024, verify PNG/JPEG format
    - Implement `resize()`: use Lanczos interpolation via the `image` package
    - Implement `removeAlpha()`: composite onto white background, ensure all pixels have alpha = 255
    - Implement `composite()`: layer foreground onto background for adaptive icons
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 4.1, 4.2, 4.3, 4.4, 4.5_

  - [x] 4.2 Implement ImageOptimizer (PNG encoding, ICO encoding)
    - Create `lib/src/core/image_optimizer.dart`
    - Implement `encodePng()`: lossless PNG compression with configurable level
    - Implement `encodeIco()`: ICO format with multiple embedded sizes using the `image` package
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 12.1_

  - [x] 4.3 Implement AssetCleaner (per-platform stale asset removal)
    - Create `lib/src/core/asset_cleaner.dart`
    - Implement `clean()` for each platform: delete correct directories/files
    - Android: `android/app/src/main/res/mipmap-*` icon files
    - iOS: `ios/Runner/Assets.xcassets/AppIcon.appiconset` contents
    - macOS: `macos/Runner/Assets.xcassets/AppIcon.appiconset` contents
    - Web: `web/favicon.png`, `web/favicon.ico`, `web/icons/` folder
    - Linux: Linux icon output directory
    - Windows: `windows/runner/resources/app_icon.ico`
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7_

  - [x] 4.4 Write property test for image dimension validation (Property 2)
    - **Property 2: Image Dimension Validation**
    - Create `test/property/image_validation_test.dart`
    - Generate random width/height pairs and verify acceptance iff both >= 1024
    - Minimum 100 iterations
    - **Validates: Requirements 3.2, 3.5**

  - [x] 4.5 Write property test for alpha channel removal (Property 3)
    - **Property 3: Alpha Channel Removal Produces Opaque Output**
    - Create `test/property/alpha_removal_test.dart`
    - Generate random RGBA pixel data, apply alpha removal, verify all output pixels are fully opaque and match composite formula
    - Minimum 100 iterations
    - **Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.5, 8.3, 9.3**

  - [x] 4.6 Write property test for PNG lossless compression (Property 4)
    - **Property 4: Lossless PNG Compression Preserves Pixels**
    - Create `test/property/png_compression_test.dart`
    - Generate random image pixel grids, encode to PNG, decode back, verify pixel-identical output
    - Minimum 100 iterations
    - **Validates: Requirements 5.1**

  - [x] 4.7 Write property test for resize dimensions (Property 6)
    - **Property 6: Resize Produces Exact Target Dimensions**
    - Create `test/property/resize_test.dart`
    - Generate random source images >= 1024x1024 and random target sizes, verify output matches exact target dimensions
    - Minimum 100 iterations
    - **Validates: Requirements 8.1, 9.1, 10.1, 10.2, 11.1, 12.1**

- [x] 5. Checkpoint - Ensure core image processing tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Implement platform-specific icon generators
  - [x] 6.1 Implement Android icon generator
    - Create `lib/src/platforms/android/android_icon_generator.dart`
    - Generate standard `ic_launcher.png` at all 5 density buckets (48, 72, 96, 144, 192)
    - Generate adaptive icon foreground (`ic_launcher_foreground.png`) at adaptive sizes (108, 162, 216, 324, 432) when adaptive config is present
    - Generate `mipmap-anydpi-v26/ic_launcher.xml` referencing foreground and background layers
    - Handle background color vs background image for adaptive icons
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

  - [x] 6.2 Implement iOS icon generator
    - Create `lib/src/platforms/ios/ios_icon_generator.dart`
    - Generate single 1024x1024 PNG with no alpha channel
    - Generate `Contents.json` manifest conforming to latest Xcode asset catalog format
    - Place in `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
    - _Requirements: 8.1, 8.2, 8.3_

  - [x] 6.3 Implement macOS icon generator
    - Create `lib/src/platforms/macos/macos_icon_generator.dart`
    - Generate icons at sizes: 16, 32, 64, 128, 256, 512, 1024 with no alpha channel
    - Generate `Contents.json` manifest for macOS asset catalog
    - Place in `macos/Runner/Assets.xcassets/AppIcon.appiconset/`
    - _Requirements: 9.1, 9.2, 9.3_

  - [x] 6.4 Implement Web icon generator
    - Create `lib/src/platforms/web/web_icon_generator.dart`
    - Generate `favicon.png` (16x16) in `web/`
    - Generate PWA icons: `Icon-192.png`, `Icon-512.png` in `web/icons/`
    - Generate maskable icons: `Icon-maskable-192.png`, `Icon-maskable-512.png` in `web/icons/`
    - _Requirements: 10.1, 10.2, 10.3_

  - [x] 6.5 Implement Linux icon generator
    - Create `lib/src/platforms/linux/linux_icon_generator.dart`
    - Generate 512x512 PNG in the Linux project directory
    - _Requirements: 11.1_

  - [x] 6.6 Implement Windows icon generator
    - Create `lib/src/platforms/windows/windows_icon_generator.dart`
    - Generate `app_icon.ico` with embedded sizes: 16, 32, 48, 64, 128, 256
    - Place at `windows/runner/resources/app_icon.ico`
    - Icons have no alpha channel
    - _Requirements: 12.1, 12.2_

  - [x] 6.7 Write property test for Android density bucket completeness (Property 5)
    - **Property 5: Android Density Bucket Completeness**
    - Create `test/property/android_density_test.dart`
    - Generate random valid source images, run Android generator, verify exactly one file per density bucket with correct dimensions
    - Minimum 100 iterations
    - **Validates: Requirements 7.3, 7.4, 7.5**

- [x] 7. Implement platform updaters
  - [x] 7.1 Implement Android platform updater
    - Create `lib/src/platforms/android/android_updater.dart`
    - Ensure `android:icon="@mipmap/ic_launcher"` is set in `AndroidManifest.xml`
    - _Requirements: 7.6, 15.1_

  - [x] 7.2 Implement iOS platform updater
    - Create `lib/src/platforms/ios/ios_updater.dart`
    - Ensure `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` in Xcode project build settings
    - _Requirements: 15.2_

  - [x] 7.3 Implement Web platform updater
    - Create `lib/src/platforms/web/web_updater.dart`
    - Update `web/manifest.json` with icon entries (sizes, types)
    - Update `web/index.html` with `<link rel="icon" href="favicon.png">`
    - _Requirements: 10.4, 10.5, 15.3_

  - [x] 7.4 Implement Linux platform updater
    - Create `lib/src/platforms/linux/linux_updater.dart`
    - Verify CMake or application runner file references the generated icon
    - _Requirements: 11.2_

  - [x] 7.5 Implement Windows platform updater
    - Create `lib/src/platforms/windows/windows_updater.dart`
    - Verify `Runner.rc` references `resources/app_icon.ico`
    - _Requirements: 12.3, 15.4_

  - [x] 7.6 Implement macOS platform updater
    - Create `lib/src/platforms/macos/macos_updater.dart`
    - Verify Xcode project references `AppIcon` asset catalog entry
    - _Requirements: 15.2_

- [x] 8. Checkpoint - Ensure platform generators and updaters pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 9. Implement splash screen generators
  - [x] 9.1 Implement Android splash generator
    - Create `lib/src/platforms/android/android_splash_generator.dart`
    - Generate splash drawable resources in all density buckets
    - _Requirements: 13.1_

  - [x] 9.2 Implement iOS splash generator
    - Create `lib/src/platforms/ios/ios_splash_generator.dart`
    - Generate `LaunchImage` set in `ios/Runner/Assets.xcassets/LaunchImage.imageset/` with `Contents.json`
    - _Requirements: 13.2_

  - [x] 9.3 Implement macOS splash generator
    - Create `lib/src/platforms/macos/macos_splash_generator.dart`
    - Generate splash image in macOS assets catalog
    - _Requirements: 13.3_

  - [x] 9.4 Implement Web splash generator
    - Create `lib/src/platforms/web/web_splash_generator.dart`
    - Generate splash image and update `web/index.html` for Flutter initialization display
    - _Requirements: 13.4_

  - [x] 9.5 Implement Linux splash generator
    - Create `lib/src/platforms/linux/linux_splash_generator.dart`
    - Generate splash image resource in Linux project directory
    - _Requirements: 13.5_

  - [x] 9.6 Implement Windows splash generator
    - Create `lib/src/platforms/windows/windows_splash_generator.dart`
    - Generate splash image resource in Windows project directory
    - _Requirements: 13.6_

- [x] 10. Implement CLI runner, logger, and argument parsing
  - [x] 10.1 Implement Logger
    - Create `lib/src/cli/logger.dart`
    - Implement `platformStart()`, `fileGenerated()`, `platformComplete()`, `summary()`, `platformError()`, `fatalError()`
    - Support verbose mode for detailed file path output
    - _Requirements: 14.1, 14.2, 14.3, 14.4_

  - [x] 10.2 Implement CLI Runner (argument parsing and orchestration)
    - Create `lib/src/cli/cli_runner.dart`
    - Use `args` package to parse `--init`, `--verbose`, and `--help` flags
    - Implement full pipeline: parse → validate → clean → generate → update → report
    - Wire all platform generators, updaters, and splash generators
    - Handle `--init` flag: generate default config, exit with error if file already exists
    - Handle continue-on-error for platform generation failures
    - Skip splash generation if not configured (log informational message)
    - _Requirements: 1.7, 2.1, 2.3, 13.7, 14.1, 14.2, 14.3, 14.4_

  - [x] 10.3 Wire bin/flutter_app_icons.dart entry point to CLI Runner
    - Update `bin/flutter_app_icons.dart` to instantiate dependencies and call `CliRunner.run()`
    - _Requirements: 1.1_

- [x] 11. Checkpoint - Ensure full pipeline integration works
  - Ensure all tests pass, ask the user if questions arise.

- [x] 12. Final integration and wiring
  - [x] 12.1 Write integration test for full pipeline
    - Create `test/integration/pipeline_test.dart`
    - Set up a fixture Flutter project structure with a sample config and source image
    - Run the full pipeline and verify: correct files generated at correct paths, correct dimensions, platform config files updated
    - _Requirements: 1.1, 7.3, 8.1, 9.1, 10.1, 11.1, 12.1, 14.2_

  - [x] 12.2 Verify barrel exports and public API
    - Ensure `lib/flutter_app_icons.dart` exports all necessary public types
    - Verify `pubspec.yaml` has correct `executables` configuration for CLI activation
    - Run `dart analyze` to ensure no lint issues
    - _Requirements: 16.5, 16.6_

- [x] 13. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation at key milestones
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific examples and edge cases
- The implementation uses Dart with `image`, `yaml`, `args` packages (runtime) and `glados`, `test`, `mockito`, `build_runner` (dev)
- Platform generators are isolated modules following feature-first architecture for easy maintenance and extension

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2", "1.3"] },
    { "id": 2, "tasks": ["2.1"] },
    { "id": 3, "tasks": ["2.2", "2.3"] },
    { "id": 4, "tasks": ["2.4", "2.5"] },
    { "id": 5, "tasks": ["4.1", "4.2", "4.3"] },
    { "id": 6, "tasks": ["4.4", "4.5", "4.6", "4.7"] },
    { "id": 7, "tasks": ["6.1", "6.2", "6.3", "6.4", "6.5", "6.6"] },
    { "id": 8, "tasks": ["6.7", "7.1", "7.2", "7.3", "7.4", "7.5", "7.6"] },
    { "id": 9, "tasks": ["9.1", "9.2", "9.3", "9.4", "9.5", "9.6"] },
    { "id": 10, "tasks": ["10.1"] },
    { "id": 11, "tasks": ["10.2"] },
    { "id": 12, "tasks": ["10.3"] },
    { "id": 13, "tasks": ["12.1", "12.2"] }
  ]
}
```
