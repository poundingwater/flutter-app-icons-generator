import 'dart:io';

/// Generates flavor-related Dart source files in the user's Flutter project.
///
/// When flavors are configured, this scaffolds the standard entry point
/// pattern used in Flutter flavor setups:
///
/// 1. `lib/flavors.dart` — Defines the `Flavor` enum and a static accessor
///    class `F` with a `late final` flavor field and convenience getters.
///
/// 2. `lib/main_<flavor>.dart` — Thin entry points for each flavor that set
///    `F.appFlavor` and delegate to `main.dart`.
///
/// This follows the industry-standard pattern for Flutter flavor management
/// where each flavor has its own entry point that configures the environment
/// before delegating to the shared `main()`.
///
/// Files are only generated if they don't already exist, to avoid overwriting
/// user customizations.
class FlavorDartGenerator {
  /// Creates a [FlavorDartGenerator].
  const FlavorDartGenerator();

  /// Generates flavor Dart files in the given [projectRoot].
  ///
  /// [flavors] is the set of flavor names (e.g., `{'dev', 'prod'}`).
  /// [packageName] is the Dart package name used in imports (from pubspec.yaml).
  ///
  /// Returns a [FlavorDartResult] indicating which files were created.
  FlavorDartResult generate({
    required String projectRoot,
    required Set<String> flavors,
    required String packageName,
  }) {
    final libDir = Directory('$projectRoot/lib');
    if (!libDir.existsSync()) {
      libDir.createSync(recursive: true);
    }

    final createdFiles = <String>[];
    final skippedFiles = <String>[];

    // 1. Generate lib/flavors.dart
    final flavorsFile = File('$projectRoot/lib/flavors.dart');
    if (!flavorsFile.existsSync()) {
      flavorsFile.writeAsStringSync(_generateFlavorsFile(flavors));
      createdFiles.add('lib/flavors.dart');
    } else {
      skippedFiles.add('lib/flavors.dart');
    }

    // 2. Generate lib/main_<flavor>.dart for each flavor
    for (final flavor in flavors) {
      final entryFile = File('$projectRoot/lib/main_$flavor.dart');
      if (!entryFile.existsSync()) {
        entryFile.writeAsStringSync(
          _generateFlavorEntryPoint(flavor, packageName),
        );
        createdFiles.add('lib/main_$flavor.dart');
      } else {
        skippedFiles.add('lib/main_$flavor.dart');
      }
    }

    // 3. Update lib/main.dart to use FutureOr<void> return type
    //    so flavor entry points can `await runner.main()`.
    final mainFile = File('$projectRoot/lib/main.dart');
    if (mainFile.existsSync()) {
      final updated = _updateMainDartSignature(mainFile);
      if (updated) {
        createdFiles.add('lib/main.dart (updated)');
      }
    }

    return FlavorDartResult(
      createdFiles: createdFiles,
      skippedFiles: skippedFiles,
    );
  }

  /// Generates the content of `lib/flavors.dart`.
  ///
  /// Defines:
  /// - A `Flavor` enum with one value per flavor name.
  /// - A static `F` class with `appFlavor` accessor and convenience getters.
  String _generateFlavorsFile(Set<String> flavors) {
    final enumValues = flavors.join(',\n  ');
    final titleCases = flavors.map((f) {
      final capitalized = f[0].toUpperCase() + f.substring(1);
      return "      case Flavor.$f:\n        return '$capitalized';";
    }).join('\n');

    return '''enum Flavor {
  $enumValues,
}

class F {
  static late final Flavor appFlavor;

  static String get name => appFlavor.name;

  static String get title {
    switch (appFlavor) {
$titleCases
    }
  }
}
''';
  }

  /// Generates a flavor-specific entry point (e.g., `lib/main_dev.dart`).
  ///
  /// This thin file sets `F.appFlavor` and delegates to the shared `main()`.
  String _generateFlavorEntryPoint(String flavor, String packageName) {
    return '''import 'dart:async';

import 'package:$packageName/flavors.dart';

import 'main.dart' as runner;

FutureOr<void> main() async {
  F.appFlavor = Flavor.$flavor;
  await runner.main();
}
''';
  }

  /// Updates `lib/main.dart` to use `FutureOr<void>` return type on `main()`.
  ///
  /// This is required so flavor entry points can `await runner.main()`.
  /// Also adds `import 'dart:async';` if not already present.
  ///
  /// Returns `true` if the file was modified, `false` if already correct.
  bool _updateMainDartSignature(File mainFile) {
    var content = mainFile.readAsStringSync();
    var modified = false;

    // Match common main() signatures that need updating.
    // Handles: void main(), Future<void> main(), main()
    final mainPattern = RegExp(
      r'^((?:void|Future<void>)\s+)?main\s*\(\s*\)',
      multiLine: true,
    );

    if (!mainPattern.hasMatch(content)) {
      // Can't find a recognizable main() — leave it alone.
      return false;
    }

    // Check if it already uses FutureOr<void>.
    if (content.contains(RegExp(r'FutureOr<void>\s+main\s*\('))) {
      // Already correct — just ensure dart:async import is present.
      if (!content.contains("import 'dart:async'")) {
        content = "import 'dart:async';\n\n$content";
        mainFile.writeAsStringSync(content);
        return true;
      }
      return false;
    }

    // Replace the return type with FutureOr<void>.
    content = content.replaceFirst(
      mainPattern,
      'FutureOr<void> main()',
    );
    modified = true;

    // Add `import 'dart:async';` if not present.
    if (!content.contains("import 'dart:async'")) {
      // Insert at the top, before other imports.
      final firstImportMatch = RegExp(r"^import\s+'", multiLine: true)
          .firstMatch(content);
      if (firstImportMatch != null) {
        content = content.substring(0, firstImportMatch.start) +
            "import 'dart:async';\n\n" +
            content.substring(firstImportMatch.start);
      } else {
        content = "import 'dart:async';\n\n$content";
      }
      modified = true;
    }

    if (modified) {
      mainFile.writeAsStringSync(content);
    }
    return modified;
  }
}

/// Result of flavor Dart file generation.
class FlavorDartResult {
  const FlavorDartResult({
    required this.createdFiles,
    required this.skippedFiles,
  });

  /// Files that were successfully created.
  final List<String> createdFiles;

  /// Files that were skipped because they already exist.
  final List<String> skippedFiles;

  /// Whether any files were created.
  bool get hasCreatedFiles => createdFiles.isNotEmpty;

  /// Whether all files were skipped.
  bool get allSkipped => createdFiles.isEmpty && skippedFiles.isNotEmpty;
}
