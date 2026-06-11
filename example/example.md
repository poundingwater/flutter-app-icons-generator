# Examples

## Basic setup (no flavors)

Generate one set of icons for all platforms using a foreground image and background color.

```yaml
# flutter_app_icons_generator.yml

icon:
  foreground: assets/icon_foreground.png
  background: "#4CAF50"

platforms:
  - android
  - ios
  - macos
  - web
  - linux
  - windows
```

Then run:

```bash
dart run flutter_app_icons_generator
```

This generates:

- **Android**: Adaptive icon layers + standard launcher icons in all density buckets
- **iOS**: 1024x1024 composited icon in `AppIcon.appiconset`
- **macOS**: Multi-size `.icns` file in `AppIcon.appiconset`
- **Web**: `favicon.ico` + PWA icons (192px, 512px) + maskable icons + `manifest.json`
- **Linux**: 512x512 `app_icon.png`
- **Windows**: Multi-size `app_icon.ico` (16–256px)

---

## With app flavors (dev + prod)

Generate different icons per flavor for Android, iOS, and macOS. Non-flavor platforms use the top-level `icon`.

```yaml
# flutter_app_icons_generator.yml

icon:
  foreground: assets/icon_foreground.png
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
  - android
  - ios
  - macos
  - web
  - linux
  - windows
```

Then run:

```bash
dart run flutter_app_icons_generator
```

This generates:

- **Android**: Per-flavor icons in `android/app/src/{flavor}/res/` + `productFlavors` block in `build.gradle.kts`
- **iOS**: Per-flavor `AppIcon-{flavor}.appiconset` + xcconfig files + Xcode schemes
- **macOS**: Per-flavor `AppIcon-{flavor}.appiconset` + xcconfig files + Xcode schemes
- **Web/Linux/Windows**: Uses top-level `icon` (flavors are not supported on these platforms)

After generation, run your app with a specific flavor:

```bash
flutter run --flavor dev
flutter run --flavor prod
flutter build ios --flavor prod
flutter build macos --flavor prod
flutter build appbundle --flavor prod
```

---

## With splash screen

Add a splash screen alongside your icons:

```yaml
# flutter_app_icons_generator.yml

icon:
  foreground: assets/icon_foreground.png
  background: "#FFFFFF"

splash:
  image: assets/splash.png
  background_color: "#FFFFFF"

platforms:
  - android
  - ios
```

---

## Platform-specific icon override

Use a different icon for a specific platform:

```yaml
# flutter_app_icons_generator.yml

icon:
  foreground: assets/icon_foreground.png
  background: "#4CAF50"

  # Use a different foreground for iOS
  ios:
    foreground: assets/ios_foreground.png
    background: "#FFFFFF"

platforms:
  - android
  - ios
```

---

## Simple mode (single pre-composited image)

If you already have a composited icon, use `all_platforms`:

```yaml
# flutter_app_icons_generator.yml

icon:
  all_platforms: assets/icon.png

platforms:
  - android
  - ios
  - macos
```

No padding or compositing is applied — the image is used as-is.
