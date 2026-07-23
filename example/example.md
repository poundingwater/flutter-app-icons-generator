# Getting Started

> **30 seconds to your first icon set.** No configuration rabbit holes.

---

## 1. Install

Add to your `pubspec.yaml`:

```yaml
dev_dependencies:
  flutter_app_icons_generator: ^0.2.0
```

```bash
dart pub get
```

---

## 2. Initialize Config

```bash
dart run flutter_app_icons_generator --init
```

This creates `flutter_app_icons_generator.yml` in your project root.

---

## 3. Prepare Your Assets

You need **two images** — that's it:

| Asset          | What it is                                 | Size      | Format           |
| -------------- | ------------------------------------------ | --------- | ---------------- |
| **Foreground** | Your logo/icon on a transparent background | 1024×1024 | PNG (RGBA)       |
| **Background** | Solid color or image behind your logo      | 1024×1024 | PNG or hex color |

> 📁 See [`example/assets/`](https://github.com/poundingwater/flutter-app-icons-generator/tree/main/example/assets) for reference images:
>
> - `foreground.png` — 1024×1024 transparent PNG
> - `background.png` — 1024×1024 background image
> - `dev-foreground.png` — 1024×1024 dev flavor foreground
> - `prod-foreground.png` — 1024×1024 prod flavor foreground

**💡 Tip:** Use a square PNG with transparent background as your foreground. The package handles all resizing, padding, and format conversion from there.

---

## 4. Configure

Edit `flutter_app_icons_generator.yml`:

```yaml
icon:
  foreground: assets/foreground.png
  background: "#4CAF50" # hex color or path to image
  foreground_padding: 0.2 # optional — inset foreground by 20% per side (default: ~0.167)

platforms:
  - android
  - ios
```

That's the minimal config. Add more platforms as needed:

```yaml
platforms:
  - android
  - ios
  - macos
  - web
  - linux
  - windows
```

---

## 5. Generate

```bash
dart run flutter_app_icons_generator
```

Done. Icons land in the correct platform directories with manifests and plists auto-updated.

Want to see what's happening? Add `--verbose`:

```bash
dart run flutter_app_icons_generator --verbose
```

---

## App Flavors (dev / prod)

Different icon per environment — fully automated build system configuration.

```yaml
icon:
  foreground: assets/foreground.png
  background: assets/background.png

flavors:
  dev:
    bundle_identifier: com.example.myapp.dev
    icon:
      foreground: assets/dev-foreground.png
      background: "#4CAF50"
      foreground_padding: 0.15
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

Run the same command:

```bash
dart run flutter_app_icons_generator
```

**What gets auto-configured:**

| Platform    | What happens                                                                               |
| ----------- | ------------------------------------------------------------------------------------------ |
| **Android** | Per-flavor resources in `src/{flavor}/res/` + `productFlavors` block in `build.gradle.kts` |
| **iOS**     | Per-flavor `AppIcon-{flavor}.appiconset` + xcconfig files + Xcode schemes                  |
| **macOS**   | Per-flavor `AppIcon-{flavor}.appiconset` + xcconfig files + Xcode schemes                  |

Then run your app with:

```bash
flutter run --flavor dev
flutter run --flavor prod
flutter build ios --flavor prod
```

---

## Quick Reference

### CLI Commands

| Command                                          | What it does                  |
| ------------------------------------------------ | ----------------------------- |
| `dart run flutter_app_icons_generator --init`    | Generate default config file  |
| `dart run flutter_app_icons_generator`           | Generate all icons            |
| `dart run flutter_app_icons_generator --verbose` | Generate with detailed output |
| `dart run flutter_app_icons_generator -p /path`  | Specify project root          |

### Config Modes

| Mode                       | Config                      | When to use                                       |
| -------------------------- | --------------------------- | ------------------------------------------------- |
| **Adaptive** (recommended) | `foreground` + `background` | You have a logo and want platform-optimized icons |
| **Simple**                 | `all_platforms: path.png`   | You have a pre-composited square icon             |
| **Platform override**      | `icon.ios.foreground`       | You need a different look on a specific platform  |
| **Custom padding**         | `foreground_padding: 0.2`   | Control how much the foreground is inset          |

### Platform Behavior

| Platform    | What happens with your assets                                     |
| ----------- | ----------------------------------------------------------------- |
| **Android** | Foreground + background as adaptive icon layers (72dp safe zone)  |
| **iOS**     | Composited with safe-zone padding, alpha removed. 1024×1024       |
| **macOS**   | Composited with safe-zone padding, alpha removed. ICNS multi-size |
| **Windows** | Foreground only, transparency preserved. ICO 16–256px             |
| **Web**     | Foreground for favicon (ICO). Composited for PWA icons            |
| **Linux**   | Composited with safe-zone padding. 512×512 PNG                    |

---

## Next Steps

- 📖 Full API documentation → [README.md](https://github.com/poundingwater/flutter-app-icons-generator/blob/main/README.md)
- 🐛 Found a bug? → [Open an issue](https://github.com/poundingwater/flutter-app-icons-generator/issues)
- 💡 Full config reference → see "Configuration Reference" in the README
