# Requirements Document

## Introduction

`flutter_app_icons` is an open-source Dart CLI package that generates platform-specific app icons and native splash screens for Flutter projects. It reads a `flutter_app_icons.yml` configuration file and produces correctly sized, optimized, standards-compliant assets for iOS, Android, macOS, Linux, Windows, and Web. The package replaces existing icon assets with freshly generated ones to guarantee a clean, consistent result across all platforms.

The project follows a feature-first architecture for clean organization and scalability. It is published as an open-source package with proper documentation, licensing, and contribution guidelines.

## Glossary

- **CLI**: The command-line interface executable provided by the `flutter_app_icons` package, invoked via `dart run flutter_app_icons` or as a standalone executable.
- **Config_File**: The `flutter_app_icons.yml` YAML file located at the root of a Flutter project, defining source image paths, platform targets, and splash screen settings.
- **Source_Image**: A PNG or JPEG image file referenced in the Config_File, used as the input for icon or splash generation.
- **Foreground_Image**: A Source_Image representing the foreground layer of an adaptive icon (Android) or the primary icon content.
- **Background_Image**: A Source_Image or solid color value representing the background layer of an adaptive icon (Android).
- **Background_Color**: A hex color string (e.g., `#FFFFFF`) used as the background layer of an adaptive icon instead of a Background_Image.
- **Combined_Image**: A single Source_Image used when the developer does not need separate foreground/background layers.
- **Adaptive_Icon**: Android's icon format (API 26+) consisting of separate foreground and background layers rendered with platform-defined masking.
- **Favicon**: A set of icon files used by web browsers, including ICO format and PNG variants.
- **Native_Splash**: A platform-native splash/launch screen generated from a configured splash image, displayed during app startup.
- **Icon_Generator**: The component of the CLI responsible for reading Source_Images, removing alpha channels, optimizing output, and producing platform-specific icon assets.
- **Splash_Generator**: The component of the CLI responsible for reading splash Source_Images and producing platform-native splash screen assets.
- **Config_Parser**: The component of the CLI responsible for reading and validating the Config_File.
- **Config_Printer**: The component of the CLI responsible for serializing configuration back to valid YAML format.
- **Asset_Cleaner**: The component of the CLI responsible for removing all pre-existing icon and splash assets before generation.
- **Platform_Updater**: The component of the CLI responsible for modifying platform-specific configuration files (AndroidManifest.xml, Info.plist, index.html, etc.) to reference newly generated assets.
- **Image_Optimizer**: The component of the CLI responsible for compressing and optimizing generated images per platform requirements without visible quality loss.

## Requirements

### Requirement 1: Configuration File Parsing

**User Story:** As a Flutter developer, I want to define my icon and splash screen settings in a single YAML configuration file, so that I can manage all asset generation from one place.

#### Acceptance Criteria

1. WHEN the CLI is invoked, THE Config_Parser SHALL locate and read the `flutter_app_icons.yml` file from the Flutter project root directory.
2. WHEN the Config_File contains a `foreground` image path and a `background` field (image path or hex color string), THE Config_Parser SHALL parse both values as the Adaptive_Icon layer sources.
3. WHEN the Config_File contains a single `icon` image path instead of separate layers, THE Config_Parser SHALL parse the path as a Combined_Image source.
4. WHEN the Config_File contains a `splash` image path, THE Config_Parser SHALL parse the path as the Native_Splash source.
5. WHEN the Config_File contains a `platforms` list, THE Config_Parser SHALL parse the list to determine which platforms to generate assets for.
6. WHEN the Config_File omits the `platforms` field, THE Config_Parser SHALL default to generating assets for all supported platforms (iOS, Android, macOS, Linux, Windows, Web).
7. IF the Config_File is missing from the project root, THEN THE CLI SHALL exit with error code 1 and display a message indicating the file was not found.
8. IF the Config_File contains invalid YAML syntax, THEN THE Config_Parser SHALL exit with error code 1 and display the parsing error with line number.
9. IF the Config_File is missing required fields (at minimum one icon source path), THEN THE Config_Parser SHALL exit with error code 1 and list the missing required fields.

### Requirement 2: Configuration File Initialization

**User Story:** As a Flutter developer, I want to generate a default configuration file with helpful comments, so that I can quickly bootstrap the setup without remembering the schema.

#### Acceptance Criteria

1. WHEN the CLI is invoked with the `--init` flag, THE CLI SHALL generate a default `flutter_app_icons.yml` file in the project root directory.
2. WHEN the `--init` flag generates the Config_File, THE Config_Printer SHALL include a header comment block explaining each configuration field, supported values, and usage examples for improved developer experience.
3. IF a `flutter_app_icons.yml` file already exists when `--init` is invoked, THEN THE CLI SHALL exit with error code 1 and display a message indicating the file already exists.
4. FOR ALL valid Config_File objects, parsing the file with the Config_Parser and then printing the result with the Config_Printer SHALL produce a semantically equivalent configuration (round-trip property).

### Requirement 3: Source Image Validation

**User Story:** As a Flutter developer, I want the tool to validate my source images before processing, so that I get clear feedback if my images are unsuitable.

#### Acceptance Criteria

1. WHEN a Source_Image path is resolved, THE Icon_Generator SHALL verify the file exists at the specified path.
2. WHEN a Source_Image is loaded, THE Icon_Generator SHALL verify the image dimensions are at least 1024x1024 pixels.
3. WHEN a Source_Image is loaded, THE Icon_Generator SHALL verify the file format is PNG or JPEG.
4. IF a Source_Image file does not exist at the specified path, THEN THE Icon_Generator SHALL exit with error code 1 and display the invalid path.
5. IF a Source_Image has dimensions smaller than 1024x1024 pixels, THEN THE Icon_Generator SHALL exit with error code 1 and display the actual dimensions along with the minimum required dimensions.
6. IF a Source_Image is not in PNG or JPEG format, THEN THE Icon_Generator SHALL exit with error code 1 and display the detected format and list the supported formats.

### Requirement 4: Alpha Channel Removal

**User Story:** As a Flutter developer, I want the tool to automatically handle alpha channels in my source images, so that my icons comply with platform requirements that disallow transparency.

#### Acceptance Criteria

1. WHEN a Source_Image contains an alpha channel, THE Icon_Generator SHALL flatten the alpha channel by compositing the image onto a white background before generating icon assets.
2. WHEN generating icons for iOS, THE Icon_Generator SHALL produce output images with no alpha channel present in the PNG file metadata.
3. WHEN generating icons for Android, THE Icon_Generator SHALL produce standard (non-adaptive) launcher icons with no alpha channel.
4. WHEN generating icons for macOS, THE Icon_Generator SHALL produce output images with no alpha channel present.
5. WHEN generating the Windows ICO file, THE Icon_Generator SHALL produce icon layers with no alpha channel.

### Requirement 5: Image Optimization

**User Story:** As a Flutter developer, I want generated images to be optimized for each platform, so that my app bundle size is minimized without sacrificing visual quality.

#### Acceptance Criteria

1. WHEN generating PNG icon files, THE Image_Optimizer SHALL apply lossless compression to reduce file size without quality loss.
2. WHEN generating icons for Web, THE Image_Optimizer SHALL optimize PNG files for web delivery with reduced file size.
3. WHEN generating icons for Android, THE Image_Optimizer SHALL produce images using the optimal color depth for each density bucket.
4. WHEN generating splash images, THE Image_Optimizer SHALL apply platform-appropriate compression settings.

### Requirement 6: Asset Cleaning

**User Story:** As a Flutter developer, I want all existing icon and splash assets removed before new ones are generated, so that stale or default assets do not persist alongside my custom icons.

#### Acceptance Criteria

1. WHEN icon generation begins for Android, THE Asset_Cleaner SHALL delete all existing icon files from `android/app/src/main/res/mipmap-*` directories.
2. WHEN icon generation begins for iOS, THE Asset_Cleaner SHALL delete all existing icon files from the `ios/Runner/Assets.xcassets/AppIcon.appiconset` directory.
3. WHEN icon generation begins for macOS, THE Asset_Cleaner SHALL delete all existing icon files from the `macos/Runner/Assets.xcassets/AppIcon.appiconset` directory.
4. WHEN icon generation begins for Web, THE Asset_Cleaner SHALL delete existing favicon files (`favicon.png`, `favicon.ico`, `icons` folder) from the `web` directory.
5. WHEN icon generation begins for Linux, THE Asset_Cleaner SHALL delete existing icon files from the project's Linux icon output directory.
6. WHEN icon generation begins for Windows, THE Asset_Cleaner SHALL delete the existing `app_icon.ico` file from the `windows/runner/resources` directory.
7. WHEN splash generation begins, THE Asset_Cleaner SHALL delete all existing splash screen assets for the targeted platforms.

### Requirement 7: Android Icon Generation

**User Story:** As a Flutter developer targeting Android, I want the tool to generate adaptive icons following the latest Android standards, so that my app icon looks correct on all Android devices.

#### Acceptance Criteria

1. WHEN Android is a target platform and separate foreground/background images are provided, THE Icon_Generator SHALL produce adaptive icon resources with separate foreground and background layers.
2. WHEN Android is a target platform and a Background_Color is provided instead of a Background_Image, THE Icon_Generator SHALL produce an adaptive icon with the color value as the background layer.
3. WHEN Android is a target platform, THE Icon_Generator SHALL generate icon files for all standard density buckets: mdpi (48x48), hdpi (72x72), xhdpi (96x96), xxhdpi (144x144), and xxxhdpi (192x192).
4. WHEN Android is a target platform with adaptive icon layers, THE Icon_Generator SHALL generate `ic_launcher_foreground.png` at each density bucket and an XML resource in `mipmap-anydpi-v26` referencing both layers.
5. WHEN Android is a target platform with a Combined_Image, THE Icon_Generator SHALL generate a standard `ic_launcher.png` at each density bucket size.
6. WHEN Android icon generation completes, THE Platform_Updater SHALL ensure the `AndroidManifest.xml` references `@mipmap/ic_launcher` as the application icon.

### Requirement 8: iOS Icon Generation

**User Story:** As a Flutter developer targeting iOS, I want the tool to generate a complete icon set conforming to Apple's latest Human Interface Guidelines, so that my app icon renders correctly on all iOS devices and contexts.

#### Acceptance Criteria

1. WHEN iOS is a target platform, THE Icon_Generator SHALL generate a single 1024x1024 PNG icon file for the App Store and universal icon usage (iOS 18+ single-size standard).
2. WHEN iOS is a target platform, THE Icon_Generator SHALL generate the `Contents.json` manifest in the `AppIcon.appiconset` directory conforming to the latest Xcode asset catalog format.
3. WHEN iOS is a target platform, THE Icon_Generator SHALL produce icons with no alpha channel (transparency composited onto a white background).

### Requirement 9: macOS Icon Generation

**User Story:** As a Flutter developer targeting macOS, I want the tool to generate a complete icon set for macOS using the Xcode asset catalog format, so that my app icon appears correctly in Finder, Dock, and the App Store.

#### Acceptance Criteria

1. WHEN macOS is a target platform, THE Icon_Generator SHALL generate icon files at the following sizes: 16x16, 32x32, 64x64, 128x128, 256x256, 512x512, and 1024x1024 pixels.
2. WHEN macOS is a target platform, THE Icon_Generator SHALL generate the `Contents.json` manifest in the `AppIcon.appiconset` directory conforming to the latest Xcode asset catalog format for macOS.
3. WHEN macOS is a target platform, THE Icon_Generator SHALL produce icons with no alpha channel (transparency composited onto a white background).

### Requirement 10: Web Favicon Generation

**User Story:** As a Flutter developer targeting the web, I want the tool to generate favicons and web icons, so that my web app displays the correct icon in browser tabs, bookmarks, and PWA contexts.

#### Acceptance Criteria

1. WHEN Web is a target platform, THE Icon_Generator SHALL generate a `favicon.png` file at 16x16 pixels in the `web` directory.
2. WHEN Web is a target platform, THE Icon_Generator SHALL generate a set of PWA icons at 192x192 and 512x512 pixels in the `web/icons` directory.
3. WHEN Web is a target platform, THE Icon_Generator SHALL generate an `Icon-maskable-192.png` and `Icon-maskable-512.png` for PWA maskable icon support.
4. WHEN Web icon generation completes, THE Platform_Updater SHALL update the `web/manifest.json` file to reference the generated icon files with correct sizes and types.
5. WHEN Web icon generation completes, THE Platform_Updater SHALL update the `web/index.html` file to reference `favicon.png` in the link rel="icon" tag.

### Requirement 11: Linux Icon Generation

**User Story:** As a Flutter developer targeting Linux, I want the tool to generate appropriately sized icons, so that my app icon displays correctly in Linux desktop environments.

#### Acceptance Criteria

1. WHEN Linux is a target platform, THE Icon_Generator SHALL generate a 512x512 PNG icon in the Linux project directory.
2. WHEN Linux icon generation completes, THE Platform_Updater SHALL verify the CMake configuration or application runner file references the generated icon file path.

### Requirement 12: Windows Icon Generation

**User Story:** As a Flutter developer targeting Windows, I want the tool to generate a proper ICO file, so that my app icon appears correctly in the Windows taskbar, Start menu, and file explorer.

#### Acceptance Criteria

1. WHEN Windows is a target platform, THE Icon_Generator SHALL generate an `app_icon.ico` file containing embedded sizes of 16x16, 32x32, 48x48, 64x64, 128x128, and 256x256 pixels.
2. THE Icon_Generator SHALL place the generated ICO file at `windows/runner/resources/app_icon.ico`.
3. WHEN Windows icon generation completes, THE Platform_Updater SHALL verify the `windows/runner/Runner.rc` resource file references `resources/app_icon.ico`.

### Requirement 13: Native Splash Screen Generation

**User Story:** As a Flutter developer, I want to generate native splash screens for all platforms from my configuration, so that my app displays a branded launch screen during startup.

#### Acceptance Criteria

1. WHEN a splash image is configured and Android is a target platform, THE Splash_Generator SHALL generate splash drawable resources in all density buckets for the Android launch screen.
2. WHEN a splash image is configured and iOS is a target platform, THE Splash_Generator SHALL generate a LaunchImage set in `ios/Runner/Assets.xcassets/LaunchImage.imageset` with appropriate sizes and a `Contents.json` manifest.
3. WHEN a splash image is configured and macOS is a target platform, THE Splash_Generator SHALL generate a splash image in the macOS assets catalog.
4. WHEN a splash image is configured and Web is a target platform, THE Splash_Generator SHALL generate a splash image and update the `web/index.html` to display the splash during Flutter initialization.
5. WHEN a splash image is configured and Linux is a target platform, THE Splash_Generator SHALL generate a splash image resource in the Linux project directory.
6. WHEN a splash image is configured and Windows is a target platform, THE Splash_Generator SHALL generate a splash image resource in the Windows project directory.
7. IF no splash image is configured in the Config_File, THEN THE Splash_Generator SHALL skip splash generation and display an informational message.

### Requirement 14: CLI Output and Logging

**User Story:** As a Flutter developer, I want clear progress output and error messages from the CLI, so that I can understand what was generated and troubleshoot failures.

#### Acceptance Criteria

1. WHEN asset generation is in progress, THE CLI SHALL display the name of each platform being processed and the number of files generated.
2. WHEN asset generation completes successfully, THE CLI SHALL display a summary listing all platforms processed and total files generated.
3. IF an error occurs during generation for a specific platform, THEN THE CLI SHALL display the platform name, the error description, and continue processing remaining platforms.
4. WHEN the CLI is invoked with the `--verbose` flag, THE CLI SHALL display detailed file paths for each generated asset.

### Requirement 15: Platform Configuration Updates

**User Story:** As a Flutter developer, I want the tool to update platform-specific configuration files automatically, so that I do not need to manually edit manifests and plists after icon generation.

#### Acceptance Criteria

1. WHEN Android icons are generated, THE Platform_Updater SHALL ensure the `android:icon` attribute in `AndroidManifest.xml` is set to `@mipmap/ic_launcher`.
2. WHEN iOS icons are generated, THE Platform_Updater SHALL ensure the `ASSETCATALOG_COMPILER_APPICON_NAME` build setting in the Xcode project references `AppIcon`.
3. WHEN Web icons are generated, THE Platform_Updater SHALL ensure the `<link rel="icon">` tag in `web/index.html` points to `favicon.png`.
4. WHEN Windows icons are generated, THE Platform_Updater SHALL ensure the `IDI_APP_ICON` entry in `Runner.rc` references `resources/app_icon.ico`.

### Requirement 16: Open Source Package Structure

**User Story:** As an open-source maintainer, I want the package to follow Dart/Flutter open-source conventions, so that contributors and users can easily understand, use, and contribute to the project.

#### Acceptance Criteria

1. THE CLI SHALL include a `README.md` file with installation instructions, usage examples, configuration reference, and platform support details.
2. THE CLI SHALL include a `LICENSE` file with an MIT license.
3. THE CLI SHALL include a `CHANGELOG.md` file following Keep a Changelog format.
4. THE CLI SHALL include a `CONTRIBUTING.md` file with contribution guidelines and development setup instructions.
5. THE CLI SHALL include a `pubspec.yaml` with correct package metadata, description, repository URL, and issue tracker URL fields.
6. THE CLI SHALL follow a feature-first architecture with separate modules for each platform's icon generation logic.
