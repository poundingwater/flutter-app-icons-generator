# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0-dev]

### Added

- **App Flavors support** for Android, iOS, and macOS
  - Per-flavor icon generation with separate asset directories
  - `bundle_identifier` field (required, unique per flavor)
  - Android: auto-configures `productFlavors` in `build.gradle.kts` / `build.gradle`
  - iOS: generates per-flavor xcconfig files, Xcode schemes, and `AppIcon-{flavor}.appiconset`
  - macOS: generates per-flavor xcconfig files, Xcode schemes, and `AppIcon-{flavor}.appiconset`
- Existing asset detection with interactive `[y/N]` prompt before overwriting
- `--init` now prompts `[y/N]` when config file already exists (overwrites on confirm)
- Validation: `bundle_identifier` required for all flavors, must be unique
- Validation: top-level `icon` required when non-flavor platforms (web, linux, windows) are configured
- Example files for pub.dev (`example/` directory)

### Fixed

- Linux updater now correctly finds `my_application.cc` in `linux/runner/` (not just `linux/`)
- iOS updater no longer overwrites `project.pbxproj` icon settings when running per-flavor generation (xcconfigs handle it)

### Changed

- `FlavorConfig` now requires `bundleIdentifier` field
- `FlavorParser` validates uniqueness of `bundle_identifier` across flavors
- macOS icon generator outputs to flavor-specific `AppIcon-{flavor}.appiconset` when flavors are active
- `CliRunner` accepts optional `promptOverride` parameter for testability

## [0.1.0-dev.2]

### Added

- Initial project scaffolding and package structure
- CLI entry point with `--init`, `--verbose`, and `--help` flags
- Configuration file schema and YAML parser (not yet functional)
- Core architecture: generator interfaces, platform updater contracts, image processor abstractions
- Placeholder implementations for all 6 platforms
