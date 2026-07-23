# flutter_app_icons_generator

Generate app icons and splash screens for all Flutter platforms from a single config file. Supports app flavors with zero manual Xcode or Gradle setup.

> **⚠️ v0.2.2-dev** — Icon generation is fully functional across all 6 platforms. Splash screen generation is work-in-progress. Web/Linux/Windows do not support per-flavor icons.

---

## Platform Support

| Platform | Icons | Flavors | Splash |
| -------- | :---: | :-----: | :----: |
| Android  |  ✅   |   ✅    |   🚧   |
| iOS      |  ✅   |   ✅    |   🚧   |
| macOS    |  ✅   |   ✅    |   🚧   |
| Web      |  ✅   |   ❌    |   🚧   |
| Linux    |  ✅   |   ❌    |   🚧   |
| Windows  |  ✅   |   ❌    |   🚧   |

---

## Quick Start

### 1. Install

```yaml
# pubspec.yaml
dev_dependencies:
  flutter_app_icons_generator: ^0.2.2-dev
```

```bash
dart pub get
```

### 2. Initialize config

```bash
dart run flutter_app_icons_generator --init
```

This creates `flutter_app_icons_generator.yml` in your project root.

### 3. Set your assets

```yaml
# flutter_app_icons_generator.yml
icon:
  foreground: assets/icon_foreground.png # transparent PNG, min 1024x1024
  background: "#FFFFFF" # hex color or image path

platforms:
  - android
  - ios
```

### 4. Generate

```bash
dart run flutter_app_icons_generator
```

That's it. Icons are generated, platform configs updated automatically.

---

## Icon Modes

**Foreground + background (recommended)** — the tool composites the layers per platform, applies safe-zone padding, and handles format conversion:

```yaml
icon:
  foreground: assets/icon_foreground.png
  background: "#1e1e2e"
  foreground_padding: 0.2 # optional — inset foreground by 20% per side
```

`foreground_padding` controls how much the foreground is inset from the canvas edges during compositing. Expressed as a fraction of the canvas size (0.0–0.5). Defaults to ~0.167 (Android's safe-zone ratio). Set `0.0` for no padding.

**Single image** — your pre-composited image is used as-is, no padding applied:

```yaml
icon:
  all_platforms: assets/icon.png
```

**Platform overrides** — when you need a different asset for a specific platform:

```yaml
icon:
  foreground: assets/icon_foreground.png
  background: "#FFFFFF"
  ios:
    foreground: assets/ios_foreground.png
    background: "#000000"
    foreground_padding: 0.1
  web:
    foreground: assets/web_icon.png
```

---

## App Flavors

Generate separate icons for `dev`, `staging`, `prod`, etc. with automatic build system configuration.

### Config

```yaml
icon:
  foreground: assets/foreground.png
  background: "#FFFFFF"

flavors:
  dev:
    bundle_identifier: com.example.myapp.dev
    icon:
      foreground: assets/dev-foreground.png
      background: "#4CAF50"
  prod:
    bundle_identifier: com.example.myapp
    icon:
      foreground: assets/prod-foreground.png
      background: "#1e1e2e"

platforms:
  - android
  - ios
  - macos
```

### Run with a flavor

```bash
flutter run --flavor dev
flutter run --flavor prod
flutter build ios --flavor prod
flutter build appbundle --flavor prod
```

### What gets generated per flavor

**Android** — icons in `android/app/src/{flavor}/res/` (all mipmap densities + adaptive layers). `build.gradle.kts` is updated with `productFlavors` automatically:

```kotlin
flavorDimensions += listOf("app")
productFlavors {
    create("dev") { dimension = "app"; applicationId = "com.example.myapp.dev" }
    create("prod") { dimension = "app"; applicationId = "com.example.myapp" }
}
```

**iOS** — per-flavor icon assets + xcconfig files + Xcode schemes:

```
ios/Runner/Assets.xcassets/AppIcon-dev.appiconset/
ios/Flutter/Debug-dev.xcconfig
ios/Flutter/Release-dev.xcconfig
ios/Runner.xcodeproj/xcshareddata/xcschemes/dev.xcscheme
```

**macOS** — same mechanism as iOS (xcconfig + schemes + ICNS assets).

> Flavor icons on web, linux, and windows are not supported — those platforms always use the top-level `icon`.

---

## Splash Screen (Work in Progress)

Config is supported but not fully production-tested:

```yaml
splash:
  image: assets/splash.png
  background_color: "#FFFFFF"
```

Per-flavor splash is also accepted:

```yaml
flavors:
  dev:
    bundle_identifier: com.example.myapp.dev
    icon:
      foreground: assets/dev-foreground.png
      background: "#4CAF50"
    splash:
      image: assets/dev_splash.png
      background_color: "#000000"
```

---

## Configuration Reference

### `icon`

| Field                           | Required | Description                                                      |
| ------------------------------- | -------- | ---------------------------------------------------------------- |
| `all_platforms`                 | Yes\*    | Pre-composited image for all platforms (min 1024×1024, PNG/JPEG) |
| `foreground`                    | Yes\*    | Foreground layer — transparent PNG recommended                   |
| `background`                    | No       | Hex color or image path. Omit to use foreground as-is            |
| `foreground_padding`            | No       | Inset fraction (0.0–0.5). Default: ~0.167 (Android safe zone)    |
| `<platform>.foreground`         | No       | Platform-specific foreground override                            |
| `<platform>.background`         | No       | Platform-specific background override                            |
| `<platform>.foreground_padding` | No       | Platform-specific padding override                               |

\*Either `all_platforms` **or** `foreground` is required.

### `splash`

| Field              | Required | Description          |
| ------------------ | -------- | -------------------- |
| `image`            | Yes      | Path to splash image |
| `background_color` | No       | Hex background color |

### `flavors.<name>`

| Field               | Required | Description                                                                                  |
| ------------------- | -------- | -------------------------------------------------------------------------------------------- |
| `bundle_identifier` | Yes      | Unique app ID (used as `applicationId` on Android, `PRODUCT_BUNDLE_IDENTIFIER` on iOS/macOS) |
| `icon`              | Yes      | Same structure as top-level `icon`                                                           |
| `splash`            | No       | Same structure as top-level `splash`                                                         |

### `platforms`

```yaml
platforms:
  - android # default
  - ios # default
  - macos
  - web
  - linux
  - windows
```

Defaults to `[android, ios]` when omitted.

---

## Source Image Requirements

| Asset           | Min Size  | Format    | Notes                              |
| --------------- | --------- | --------- | ---------------------------------- |
| `foreground`    | 1024×1024 | PNG, JPEG | Transparent PNG gives best results |
| `background`    | 1024×1024 | PNG, JPEG | Or a hex string like `"#FFFFFF"`   |
| `all_platforms` | 1024×1024 | PNG, JPEG | Used as-is — no padding applied    |
| `splash.image`  | 1024×1024 | PNG, JPEG | Centered on splash screen          |

---

## Output Files

| Platform | Output                                                                     |
| -------- | -------------------------------------------------------------------------- |
| Android  | `android/app/src/main/res/mipmap-*/ic_launcher.png` + adaptive icon layers |
| iOS      | `ios/Runner/Assets.xcassets/AppIcon.appiconset/` (1024×1024 PNG)           |
| macOS    | `macos/Runner/Assets.xcassets/AppIcon.appiconset/` (ICNS, 16–1024px)       |
| Windows  | `windows/runner/resources/app_icon.ico` (ICO, 16–256px)                    |
| Web      | `web/favicon.ico` + `web/icons/Icon-{192,512}.png` + maskable variants     |
| Linux    | `linux/app_icon.png` (512×512 PNG)                                         |

---

## CLI Options

```
dart run flutter_app_icons_generator [options]

--init              Create a default config file
-v, --verbose       Show detailed file paths during generation
-p, --project-root  Path to Flutter project root (default: current directory)
-h, --help          Show help
```

---

## Existing Asset Detection

If icons were previously generated, the CLI will warn you before overwriting:

```
⚠️  Existing generated assets detected:
   • iOS [dev] AppIcon (AppIcon-dev.appiconset)
   • iOS [prod] AppIcon (AppIcon-prod.appiconset)

These will be removed and regenerated. Continue? [y/N]
```

---

## License

MIT — see [LICENSE](LICENSE).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup.
