# Contributing to flutter_app_icons_generator

Thank you for your interest in contributing! This document provides guidelines and instructions for contributing to the project.

## Development Setup

### Prerequisites

- [Dart SDK](https://dart.dev/get-dart) >= 3.0.0
- Git

### Getting Started

1. Fork and clone the repository:

```bash
git clone https://github.com/your-username/flutter-app-icons-generator.git
cd flutter-app-icons-generator
```

2. Install dependencies:

```bash
dart pub get
```

3. Run tests:

```bash
dart test
```

4. Run the CLI locally:

```bash
dart run flutter_app_icons_generator --help
```

## Project Structure

```
flutter-app-icons-generator/
├── bin/                          # CLI entry point
├── lib/
│   ├── flutter_app_icons_generator.dart   # Public barrel file
│   └── src/
│       ├── cli/                 # CLI runner and logger
│       ├── config/              # Config parsing and printing
│       ├── core/                # Image processing, optimization, cleaning
│       ├── platforms/           # Per-platform generators and updaters
│       │   ├── android/
│       │   ├── ios/
│       │   ├── macos/
│       │   ├── web/
│       │   ├── linux/
│       │   └── windows/
│       └── shared/              # Constants, exceptions, enums
└── test/
    ├── config/                  # Config parser/printer tests
    ├── core/                    # Image processor, cleaner tests
    ├── platforms/               # Per-platform generator tests
    └── property/                # Property-based tests (glados)
```

## Architecture

The project follows a **feature-first architecture** with a **pipeline pattern**:

1. **Parse** - Read and validate YAML configuration
2. **Validate** - Check source images (existence, dimensions, format)
3. **Clean** - Remove existing assets for targeted platforms
4. **Generate** - Create platform-specific icon and splash assets
5. **Update** - Modify platform configuration files
6. **Report** - Display progress and results

## Code Style

- Follow the [Dart style guide](https://dart.dev/effective-dart/style)
- Run `dart analyze` before submitting PRs
- Run `dart format .` to format code

## Testing

We use three types of tests:

- **Unit tests** (`package:test`): Verify specific examples and edge cases
- **Property-based tests** (`package:glados`): Verify universal properties hold across all inputs
- **Integration tests**: Verify the full pipeline with fixture projects

Run all tests:

```bash
dart test
```

Run only property-based tests:

```bash
dart test test/property/
```

## Submitting Changes

1. Create a feature branch from `main`
2. Make your changes with clear, focused commits
3. Ensure all tests pass: `dart test`
4. Ensure no lint issues: `dart analyze`
5. Open a pull request with a clear description of the changes

## Reporting Issues

- Use GitHub Issues to report bugs or request features
- Include steps to reproduce for bug reports
- Include your Dart SDK version and OS

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
