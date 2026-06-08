# flutter_app_icons_generator

A Dart CLI tool that generates platform-specific app icons and native splash screens for Flutter projects.

## Features

- Generates correctly sized, optimized icons for **iOS**, **Android**, **macOS**, **Linux**, **Windows**, and **Web**
- Generates native splash screens for all platforms
- Reads configuration from a single `flutter_app_icons_generator.yml` file
- Supports adaptive icons (Android) with separate foreground/background layers
- Automatically removes alpha channels where required by platform standards
- Cleans existing assets before regeneration for a consistent result
- Updates platform configuration files (manifests, plists, etc.) automatically

## Installation

Add `flutter_app_icons_generator` as a dev dependency in your `pubspec.yaml`:

```yaml
dev_dependencies:
  flutter_app_icons_generator: ^0.1.0
```

Then run:

```bash
dart pub get
```

## Usage

### Initialize configuration

Generate a default `flutter_app_icons_generator.yml` configuration file:

```bash
dart run flutter_app_icons_generator --init
```

### Configure

Edit `flutter_app_icons_generator.yml` in your project root:

```yaml
# Icon configuration (required)
icon:
  # Option A: Single combined image
  image: assets/icon.png

  # Option B: Adaptive icon layers (Android)
  # foreground: assets/icon_foreground.png
  # background: "#4CAF50"  # hex color or image path

# Splash screen configuration (optional)
splash:
  image: assets/splash.png
  background_color: "#FFFFFF"

# Target platforms (optional, defaults to all)
platforms:
  - android
  - ios
  - macos
  - web
  - linux
  - windows
```

### Generate icons

```bash
dart run flutter_app_icons_generator
```

### Verbose output

```bash
dart run flutter_app_icons_generator --verbose
```

## Configuration Reference

| Field                     | Type   | Required | Description                                                    |
| ------------------------- | ------ | -------- | -------------------------------------------------------------- |
| `icon.image`              | String | Yes\*    | Path to a single combined icon image (min 1024x1024, PNG/JPEG) |
| `icon.foreground`         | String | Yes\*    | Path to adaptive icon foreground layer                         |
| `icon.background`         | String | Yes\*    | Path to background image or hex color (e.g. `"#FFFFFF"`)       |
| `splash.image`            | String | No       | Path to splash screen source image                             |
| `splash.background_color` | String | No       | Hex color for splash background                                |
| `platforms`               | List   | No       | Target platforms (defaults to all)                             |

\*Either `icon.image` OR both `icon.foreground` and `icon.background` are required.

## Platform Support

| Platform | Icons                  | Splash | Config Updates            |
| -------- | ---------------------- | ------ | ------------------------- |
| Android  | ✅ Adaptive + standard | ✅     | AndroidManifest.xml       |
| iOS      | ✅ 1024x1024 (iOS 18+) | ✅     | Xcode asset catalog       |
| macOS    | ✅ 16–1024px           | ✅     | Xcode asset catalog       |
| Web      | ✅ Favicon + PWA       | ✅     | manifest.json, index.html |
| Linux    | ✅ 512x512             | ✅     | CMake config              |
| Windows  | ✅ ICO (16–256px)      | ✅     | Runner.rc                 |

## Source Image Requirements

- Minimum dimensions: **1024x1024 pixels**
- Supported formats: **PNG**, **JPEG**
- Alpha channels are automatically removed where required by platform standards

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and contribution guidelines.
