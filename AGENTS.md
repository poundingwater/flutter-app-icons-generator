# AGENTS.md — Flutter App Icons Generator

> **Note for AI Agents:** You must strictly follow the architectural conventions, coding style, and operational directives defined in this document. Always read this file before making modifications or adding new features.

---

## 1. Project Overview & Tech Stack

A Dart CLI tool that generates platform-specific app icons and native splash screens for Flutter projects with full app flavor support.

- **Language:** Dart (SDK ^3.0.0)
- **Type:** CLI executable (pub package)
- **Dependencies:** `args`, `image`, `yaml`
- **Dev Dependencies:** `test`, `mockito`, `glados` (property-based testing), `build_runner`
- **Supported Platforms:** Android, iOS, macOS, Linux, Windows, Web

---

## 2. Core AI Operating Directives

- Proactively audit for architectural flaws. Prefer scalable, future-proof solutions over quick patches.
- Restrict external explanations to 2–3 concise bullet points max; prefer inline code comments.
- This is a pure Dart package — no Flutter SDK dependency. Use `dart` commands, not `flutter`.

---

## 3. Directory & Architectural Structure

This project follows a **layered module architecture** with platform-specific generators isolated from core logic.

```text
├── bin/
│   └── flutter_app_icons_generator.dart   <-- CLI entry point
├── lib/
│   ├── flutter_app_icons_generator.dart   <-- Public barrel export
│   └── src/
│       ├── cli/                           <-- CLI layer (arg parsing, runner, logging)
│       │   ├── arg_parser.dart            <-- Command-line argument definitions
│       │   ├── asset_detector.dart        <-- Detects asset files in project
│       │   ├── cli_runner.dart            <-- Top-level CLI orchestration
│       │   ├── console_logger.dart        <-- Console output implementation
│       │   ├── default_factories.dart     <-- DI factory defaults
│       │   ├── logger.dart                <-- Logger interface
│       │   └── pipeline_runner.dart       <-- Pipeline execution logic
│       ├── config/                        <-- Configuration parsing & validation
│       │   ├── config_model.dart          <-- Config data model
│       │   ├── config_parser.dart         <-- Parser interface
│       │   ├── config_printer.dart        <-- Config summary output
│       │   ├── config_resolver.dart       <-- Resolves merged config values
│       │   ├── config_validator.dart      <-- Validates config integrity
│       │   └── yaml_config_parser.dart    <-- YAML-specific parser implementation
│       ├── core/                          <-- Core generation engine
│       │   ├── asset_cleaner.dart         <-- Cleans stale generated assets
│       │   ├── icon_generator.dart        <-- Icon generation orchestrator
│       │   ├── image_optimizer.dart       <-- Image optimizer interface
│       │   ├── default_image_optimizer.dart
│       │   ├── image_processor.dart       <-- Image processor interface
│       │   ├── default_image_processor.dart
│       │   ├── platform_updater.dart      <-- Platform manifest updater interface
│       │   └── splash_generator.dart      <-- Splash screen generation
│       ├── flavors/                       <-- App flavor support
│       │   ├── flavor_model.dart          <-- Flavor data model
│       │   ├── flavor_parser.dart         <-- Parses flavor configurations
│       │   ├── flavor_printer.dart        <-- Flavor summary output
│       │   └── flavor_dart_generator.dart <-- Generates Dart flavor constants
│       ├── platforms/                     <-- Platform-specific generators
│       │   ├── android/
│       │   ├── ios/
│       │   ├── macos/
│       │   ├── linux/
│       │   ├── windows/
│       │   └── web/
│       └── shared/                        <-- Cross-cutting shared utilities
│           ├── constants.dart             <-- Shared constants
│           ├── exceptions.dart            <-- Custom exception types
│           ├── launch_json_generator.dart <-- VS Code launch config generation
│           ├── podfile/                   <-- CocoaPods helpers
│           └── xcode/                     <-- Xcode project manipulation
├── test/
│   ├── config/                            <-- Config layer tests
│   ├── core/                              <-- Core engine tests
│   ├── integration/                       <-- Integration tests
│   ├── platforms/                         <-- Platform generator tests
│   ├── property/                          <-- Property-based tests (glados)
│   └── shared/                            <-- Shared utility tests
├── example/                               <-- Example config files and assets
├── scripts/                               <-- Makefile modules (.mk files)
└── _tasks/                                <-- Task/issue tracking documents
```

---

## 4. Core Coding Rules & Guardrails

### A. File Size & Component Splitting

- **Strict Maximum Length:** Keep all files under **200 lines**.
- **Platform Generators:** Each platform lives in its own sub-directory under `platforms/`. Platform-specific logic must never leak into `core/` or `config/`.
- **Interface Segregation:** Core abstractions (`image_processor.dart`, `image_optimizer.dart`, `platform_updater.dart`) define contracts. Default implementations live in separate files (`default_image_processor.dart`, etc.).

### B. Code Style & Typing

- **Idiomatic Dart:** Write clean, performance-optimized, idiomatic Dart code.
- **Strict Typing:** Avoid `dynamic` unless interacting with JSON/YAML deserialization boundaries.
- **Linter Rules:** Enforced via `analysis_options.yaml`:
  - `prefer_final_locals`
  - `prefer_single_quotes`
  - `sort_constructors_first`
  - `unawaited_futures`
- **File Naming:** Use snake_case. Meaningful suffixes where applicable: `_model.dart`, `_parser.dart`, `_generator.dart`, `_validator.dart`.
- **Prefer `final`** for all local variables and parameters that are not reassigned.
- **Use single quotes** for strings unless the string contains a single quote.

### C. Architecture Principles

- **Dependency Inversion:** Core logic depends on interfaces (e.g., `ImageProcessor`, `ImageOptimizer`, `PlatformUpdater`). Implementations are injected via factory constructors.
- **Pipeline Pattern:** The CLI uses a pipeline architecture (`pipeline_runner.dart`) — each step is a discrete unit.
- **Platform Isolation:** Each platform generator is self-contained. Adding a new platform means adding a new directory under `platforms/` without modifying existing platform code.
- **Config-Driven:** All behavior is driven by the parsed YAML config model. No hardcoded paths or platform assumptions in core logic.

### E. Native File Modification Policy

- **No regex on structured formats.** Do not use regex-based string manipulation to modify `project.pbxproj`, `Info.plist`, or any XML/plist/AST-structured file.
- **Plist files:** Use `package:xml` DOM parsing for all plist reads and writes.
- **pbxproj files:** Use the structural parser in `lib/src/shared/xcode/` (once migrated). Until then, existing regex-based code is legacy — do not extend it, do not add new regex-based pbxproj modifications.
- **New pbxproj work:** If a task requires modifying `project.pbxproj`, implement the structural parser first (see `_tasks/migrate-pbxproj-to-structural-parsing.md`).
- **Rationale:** pbxproj is a NeXTSTEP ASCII plist with nested blocks and multiple targets. Regex cannot reliably scope to the correct target/section and has caused wrong-target insertion bugs.

### D. Testing Conventions

- **Unit tests** mirror the `lib/src/` structure under `test/`.
- **Property-based tests** use the `glados` package for fuzz/generative testing.
- **Integration tests** live in `test/integration/` and test full pipeline runs.
- **Mocking** uses `mockito` for interface-based test doubles.

---

## 5. How to Apply Code Changes (Edit Strategy)

1. **Targeted Edits:** Make surgical modifications. Retain existing comments, structural layouts, and untouched helper methods.
2. **Preserve Invariants:** Do not alter existing public API signatures without explicit instruction.
3. **Platform Isolation:** Do not leak platform-specific logic into `core/`, `config/`, or `shared/`. Keep platform code in `platforms/<platform>/`.
4. **Interface-First:** When adding new capabilities, define the interface in `core/` first, then implement.
5. **Config Awareness:** New features that require user configuration must update `config_model.dart`, `config_parser.dart`, and `config_validator.dart`.

---

## 6. Verification Commands

Run these exact terminal commands to verify your changes before finalizing a task:

```bash
# Full verification (mirrors CI) — format check + analyze + test
make verify

# Individual steps:
make format-check    # Check formatting without modifying files
make analyze         # Static analysis (fatal on infos and warnings)
make test            # Run all tests

# Other useful commands:
make get             # Install dependencies
make format          # Auto-format code
make build           # Compile executable
make generate        # Run build_runner code generation
make publish-dry-run # Validate package for pub.dev
```

**CI Pipeline** (`.github/workflows/verify.yml`) runs on all PRs and pushes to `main`:

1. `dart pub get`
2. `dart format --output=none --set-exit-if-changed .`
3. `dart analyze --fatal-infos --fatal-warnings`
4. `dart test`

---

## 7. Task Workflow

- Task/issue documents live in `_tasks/`. Reference these when working on specific issues.
- Always run `make verify` before considering a task complete.
- Commit messages should be concise and descriptive (imperative mood).
