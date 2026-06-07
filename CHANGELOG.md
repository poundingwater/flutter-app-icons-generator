# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial project scaffolding and package structure
- CLI entry point with `--init`, `--verbose`, and `--help` flags
- Configuration file parsing from `flutter_app_icons.yml`
- Source image validation (dimensions, format)
- Alpha channel removal for platform compliance
- Icon generation for Android (adaptive + standard), iOS, macOS, Web, Linux, Windows
- Native splash screen generation for all platforms
- Automatic platform configuration file updates
- Lossless PNG compression and ICO encoding
- Asset cleaning before regeneration
