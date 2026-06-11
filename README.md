# flutter_app_icons_generator

A Dart CLI tool that generates platform-specific app icons and native splash screens for Flutter projects with full app flavor support. One config file, all platforms and flavors handled automatically.

> **⚠️ Pre-release notice**
>
> This package is in active development (`0.1.0-dev`). The following are work-in-progress:
>
> - **Splash screen generation** — the config is parsed but splash assets are not fully production-tested across all platforms yet.
> - **Web platform flavor support** — web does not support per-flavor icons. The top-level `icon` is always used.
> - **Linux/Windows flavor support** — same as web, flavors are not applicable to these platforms.
>
> Icon generation for all 6 platforms (with and without flavors on Android, iOS, macOS) is fully functional and tested.

## Features

- Generates correctly sized, optimized icons for **iOS**, **Android**, **macOS**, **Linux**, **Windows**, and **Web**
- 🚧 Generates native splash screens for all platforms _(work-in-progress)_
- **App Flavors** — generate per-flavor icons for Android, iOS, and macOS with automatic build system configuration
- Single `foreground` + `background` approach works across all platforms
- Platform-aware compositing — the package decides how to use your assets per platform
- Automatic safe-zone padding — foreground is inset to avoid clipping by platform masks
- Supports platform-specific overrides when you need fine-grained control
- Automatically removes alpha channels where required (iOS, macOS)
- Preserves transparency where expected (Windows, Web favicon)
- Detects existing generated assets and prompts before overwriting
- Validates source images before cleaning existing assets
- Updates platform configuration files (manifests, plists, etc.) automatically

## Platform Support

| Platform | Icons | Flavors                | Splash |
| -------- | ----- | ---------------------- | ------ |
| Android  | ✅    | ✅                     | 🚧     |
| iOS      | ✅    | ✅                     | 🚧     |
| macOS    | ✅    | ✅                     | 🚧     |
| Web      | ✅    | ❌ (uses default icon) | 🚧     |
| Linux    | ✅    | ❌ (uses default icon) | 🚧     |
| Windows  | ✅    | ❌ (uses default icon) | 🚧     |

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
icon:
  # Option 1: Single image for all platforms (simplest setup)
  # all_platforms: assets/icon.png

  # Option 2: Separate foreground and background (recommended)
  foreground: assets/icon_foreground.png
  background: "#FFFFFF" # hex color or image path

# Splash screen (optional)
splash:
  image: assets/splash.png
  background_color: "#FFFFFF"

# Platforms to generate (defaults to android + ios)
platforms:
  - android
  - ios
  # - macos
  # - web
  # - linux
  # - windows
```

### Generate icons

```bash
dart run flutter_app_icons_generator
```

### Verbose output

```bash
dart run flutter_app_icons_generator --verbose
```

## App Flavors

App flavors let you generate different icons for different environments (dev, staging, prod) with automatic platform build system configuration — no manual Xcode or Gradle setup required.

### Configuration

```yaml
icon:
  foreground: assets/foreground.png
  background: assets/background.png

flavors:
  dev:
    bundle_identifier: com.example.myapp.dev
    icon:
      foreground: assets/dev_foreground.png
      background: "#4CAF50"
  prod:
    bundle_identifier: com.example.myapp
    icon:
      foreground: assets/prod_foreground.png
      background: "#1e1e2e"

platforms:
  - ios
  - android
  - macos
```

### Flavor requirements

| Field                              | Required | Description                                                                                                     |
| ---------------------------------- | -------- | --------------------------------------------------------------------------------------------------------------- |
| `flavors.<name>.bundle_identifier` | Yes      | Unique app ID for this flavor. Used as `applicationId` on Android and `PRODUCT_BUNDLE_IDENTIFIER` on iOS/macOS. |
| `flavors.<name>.icon`              | Yes      | Icon configuration (same structure as top-level `icon`).                                                        |
| `flavors.<name>.splash`            | No       | Optional splash screen for this flavor.                                                                         |

**Validation rules:**

- Every flavor must have a `bundle_identifier`
- Each `bundle_identifier` must be unique across all flavors
- When flavors are configured, the top-level `icon` is still required if non-flavor platforms (web, linux, windows) are in the platforms list

### What gets generated

#### Android

For each flavor, the generator creates resources in `android/app/src/{flavor}/res/`:

- Standard launcher icons in all density buckets (`mipmap-mdpi` through `mipmap-xxxhdpi`)
- Adaptive icon layers (foreground/background PNGs + XML descriptor)
- `values/colors.xml` with the background color (if using a hex color background)

It also configures `build.gradle.kts` (or `build.gradle`) with:

```kotlin
flavorDimensions += listOf("app")
productFlavors {
    create("dev") {
        dimension = "app"
        applicationId = "com.example.myapp.dev"
    }
    create("prod") {
        dimension = "app"
        applicationId = "com.example.myapp"
    }
}
```

#### iOS

For each flavor, the generator creates:

- `ios/Runner/Assets.xcassets/AppIcon-{flavor}.appiconset/` — 1024x1024 icon + Contents.json
- `ios/Flutter/{flavor}-Debug.xcconfig` — overrides bundle ID + icon name, includes `Debug.xcconfig`
- `ios/Flutter/{flavor}-Release.xcconfig` — overrides bundle ID + icon name, includes `Release.xcconfig`
- `ios/Flutter/{flavor}-Profile.xcconfig` — overrides bundle ID + icon name, includes `Release.xcconfig`
- `ios/Runner.xcodeproj/xcshareddata/xcschemes/{flavor}.xcscheme` — Xcode scheme for this flavor

The xcconfig files set:

```
PRODUCT_BUNDLE_IDENTIFIER = com.example.myapp.dev
ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon-dev
```

The `project.pbxproj` retains the default `AppIcon` reference — flavor-specific overrides are applied via the xcconfig/scheme mechanism.

#### macOS

macOS uses the same scheme/xcconfig mechanism as iOS. For each flavor, the generator creates:

- `macos/Runner/Assets.xcassets/AppIcon-{flavor}.appiconset/` — ICNS icon (multi-size) + Contents.json
- `macos/Flutter/{flavor}-Debug.xcconfig` — overrides bundle ID + icon name, includes `Flutter-Debug.xcconfig`
- `macos/Flutter/{flavor}-Release.xcconfig` — overrides bundle ID + icon name, includes `Flutter-Release.xcconfig`
- `macos/Flutter/{flavor}-Profile.xcconfig` — overrides bundle ID + icon name, includes `Flutter-Release.xcconfig`
- `macos/Runner.xcodeproj/xcshareddata/xcschemes/{flavor}.xcscheme` — Xcode scheme for this flavor

### Running with flavors

After generation, use Flutter's `--flavor` flag:

```bash
flutter run --flavor dev
flutter run --flavor prod
flutter build ios --flavor prod
flutter build macos --flavor prod
flutter build appbundle --flavor prod
```

### Non-flavor platforms

Platforms that don't support flavors (web, linux, windows) always use the top-level `icon` configuration. When flavors are configured and these platforms are in the list, the top-level `icon` section is required.

## Existing Asset Detection

When generated assets already exist, the CLI detects them and prompts for confirmation before overwriting:

```
⚠️  Existing generated assets detected:
   • iOS [dev] AppIcon (AppIcon-dev.appiconset)
   • iOS [prod] AppIcon (AppIcon-prod.appiconset)

These will be removed and regenerated. Continue? [y/N]
```

This prevents accidental overwrites and makes the regeneration workflow explicit.

## How It Works

The package uses your `foreground` and `background` assets intelligently per platform:

| Platform    | Behavior                                                                                                                                                                          |
| ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Android** | Uses foreground + background as native adaptive icon layers. Foreground is placed within the 72dp safe zone on a 108dp canvas. Also generates composited standard launcher icons. |
| **iOS**     | Composites foreground onto background with safe-zone padding, removes alpha. Single 1024x1024 icon.                                                                               |
| **macOS**   | Composites foreground onto background with safe-zone padding, removes alpha. Generates a single `.icns` file with all required sizes.                                             |
| **Windows** | Uses **foreground only** — transparency preserved, no padding applied. Generates multi-size ICO (16–256px).                                                                       |
| **Web**     | Favicon uses **foreground only** (ICO, 48px). PWA icons use composited image with padding.                                                                                        |
| **Linux**   | Composites foreground onto background with safe-zone padding. Single 512x512 PNG.                                                                                                 |

### Safe-Zone Padding

When compositing `foreground` onto `background`, the package automatically applies the **72/108 safe-zone ratio** (~66.67% content area, ~16.7% padding per side). This ensures your logo/icon content is never clipped by platform masks (rounded corners on iOS, circles/squircles on Android, etc.).

This padding is only applied in **foreground + background mode**. If you use `all_platforms` with a pre-composited image, it's used as-is without modification.

This means:

- You provide **one foreground PNG** (your logo/icon on transparent background)
- You provide **one background** (a hex color like `"#FFFFFF"` or an image path)
- The package handles everything else — safe-zone padding, compositing, sizing, format conversion, alpha removal

## Configuration Reference

### Icon Configuration

```yaml
icon:
  # ── Simple Mode ──────────────────────────────────────────────
  # One pre-composited image for everything (used as-is, no padding):
  all_platforms: assets/icon.png

  # ── Adaptive Mode (recommended) ─────────────────────────────
  # Separate layers — the package composites per platform with safe-zone padding:
  foreground: assets/icon_foreground.png
  background: "#FFFFFF" # hex color (e.g. "#4CAF50") or image path

  # ── Platform Overrides (optional) ───────────────────────────
  # Use a different foreground/background for a specific platform:
  ios:
    foreground: assets/ios_foreground.png
    background: "#FFFFFF"
  web:
    foreground: assets/web_icon.png
```

| Field                        | Type   | Required | Description                                                    |
| ---------------------------- | ------ | -------- | -------------------------------------------------------------- |
| `icon.all_platforms`         | String | Yes\*    | Single image for all platforms (min 1024x1024, PNG/JPEG)       |
| `icon.foreground`            | String | Yes\*    | Foreground layer (transparent PNG recommended)                 |
| `icon.background`            | String | No       | Hex color or image path. If omitted, foreground is used as-is. |
| `icon.<platform>.foreground` | String | No       | Platform-specific foreground override                          |
| `icon.<platform>.background` | String | No       | Platform-specific background override                          |

\*Either `all_platforms` OR `foreground` is required.

### Splash Configuration

```yaml
splash:
  image: assets/splash.png
  background_color: "#FFFFFF"
```

| Field                     | Type   | Required | Description                            |
| ------------------------- | ------ | -------- | -------------------------------------- |
| `splash.image`            | String | Yes      | Path to splash screen source image     |
| `splash.background_color` | String | No       | Hex background color for splash screen |

### Flavors Configuration

```yaml
flavors:
  dev:
    bundle_identifier: com.example.myapp.dev
    icon:
      foreground: assets/dev_foreground.png
      background: "#4CAF50"
    splash:
      image: assets/dev_splash.png
      background_color: "#000000"
  prod:
    bundle_identifier: com.example.myapp
    icon:
      foreground: assets/prod_foreground.png
      background: "#1e1e2e"
```

| Field                              | Type   | Required | Description                                          |
| ---------------------------------- | ------ | -------- | ---------------------------------------------------- |
| `flavors.<name>.bundle_identifier` | String | Yes      | Unique application ID for this flavor                |
| `flavors.<name>.icon`              | Map    | Yes      | Icon config (same structure as top-level `icon`)     |
| `flavors.<name>.splash`            | Map    | No       | Splash config (same structure as top-level `splash`) |

### Platforms

```yaml
platforms:
  - android
  - ios
  - macos
  - web
  - linux
  - windows
```

Defaults to `android` and `ios` when omitted. Add any combination of the 6 supported platforms.

## Source Image Requirements

| Asset           | Min Size  | Format    | Notes                                           |
| --------------- | --------- | --------- | ----------------------------------------------- |
| `foreground`    | 1024x1024 | PNG, JPEG | Transparent PNG recommended for best results    |
| `background`    | 1024x1024 | PNG, JPEG | Or use a hex color string instead               |
| `all_platforms` | 1024x1024 | PNG, JPEG | Pre-composited, used as-is (no padding applied) |
| `splash.image`  | 1024x1024 | PNG, JPEG | Centered on splash screen                       |

**Tips:**

- Use a **square PNG with transparent background** as your foreground for maximum flexibility
- The package handles all downsizing — provide the largest size and it generates everything
- For Windows, only the foreground is used (transparency preserved), so ensure your logo looks good without a background
- The safe-zone padding ensures your icon content is never clipped by rounded corners or masks

## Platform Output

| Platform | Output                                                                      | Format           |
| -------- | --------------------------------------------------------------------------- | ---------------- |
| Android  | `mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png` + adaptive layers | PNG              |
| iOS      | `AppIcon.appiconset/app_icon_1024.png` + Contents.json                      | PNG (1024x1024)  |
| macOS    | `AppIcon.appiconset/app_icon.icns` + Contents.json                          | ICNS (16–1024px) |
| Windows  | `windows/runner/resources/app_icon.ico`                                     | ICO (16–256px)   |
| Web      | `web/favicon.ico` + `web/icons/Icon-{192,512}.png` + maskable variants      | ICO + PNG        |
| Linux    | `linux/app_icon.png`                                                        | PNG (512x512)    |

## CLI Options

```
Usage: dart run flutter_app_icons_generator [options]

--init           Generate a default flutter_app_icons_generator.yml config file.
-v, --verbose    Enable verbose output with detailed file paths.
-p, --project-root  Path to the Flutter project root (defaults to current directory).
-h, --help       Show usage information.
```

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and contribution guidelines.
