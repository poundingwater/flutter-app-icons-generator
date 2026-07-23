import 'dart:io';

/// Detects and removes legacy `.icns`-based icon setups from macOS projects.
///
/// Older Flutter projects (and manual Xcode setups) reference a standalone
/// `.icns` file directly in:
/// 1. The file system (e.g., `macos/Runner/Assets.xcassets/AppIcon.icns`)
/// 2. The `project.pbxproj` (PBXFileReference + PBXBuildFile entries)
/// 3. The `Info.plist` is left untouched so the active icon name remains
///    available to Xcode while legacy references are removed.
///
/// When migrating to the modern asset catalog approach (`.appiconset` with
/// individual PNGs + Contents.json), these legacy references must be removed
/// or Xcode may continue using the old `.icns` instead of the asset catalog.
///
/// This cleaner is idempotent — it does nothing if no legacy artifacts exist.
class MacosLegacyIconCleaner {
  /// Removes all legacy `.icns` icon artifacts from the macOS project.
  ///
  /// Operations performed:
  /// 1. Deletes any `.icns` files found under `macos/Runner/`
  /// 2. Removes PBXFileReference and PBXBuildFile entries for `.icns` from
  ///    the pbxproj
  /// 3. Removes `.icns` entries from PBXResourcesBuildPhase file lists
  void clean(String projectRoot) {
    _deleteIcnsFiles(projectRoot);
    _cleanPbxproj(projectRoot);
  }

  /// Recursively finds and deletes all `.icns` files under `macos/`.
  void _deleteIcnsFiles(String projectRoot) {
    final macosDir = Directory('$projectRoot/macos');
    if (!macosDir.existsSync()) return;

    final icnsFiles = macosDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.icns'));

    for (final file in icnsFiles) {
      file.deleteSync();
    }
  }

  /// Removes `.icns` references from `project.pbxproj`.
  ///
  /// Handles three sections:
  /// - PBXBuildFile: lines referencing `.icns` in Resources
  /// - PBXFileReference: the file reference declaration for `.icns`
  /// - PBXResourcesBuildPhase: the file ID listed in the resources phase
  void _cleanPbxproj(String projectRoot) {
    final pbxprojPath = '$projectRoot/macos/Runner.xcodeproj/project.pbxproj';
    final file = File(pbxprojPath);
    if (!file.existsSync()) return;

    var content = file.readAsStringSync();
    final originalContent = content;

    // Collect all object IDs that reference .icns files so we can remove
    // them from build phases too.
    final icnsRefIds = <String>{};

    // Remove PBXFileReference entries for .icns files.
    // Pattern: <ID> /* <name>.icns */ = {isa = PBXFileReference; ...};
    final fileRefPattern = RegExp(
      r'^[ \t]+(\w+)\s*/\*[^*]*\.icns[^*]*\*/\s*=\s*\{[^}]*\};\s*$',
      multiLine: true,
    );
    for (final match in fileRefPattern.allMatches(content)) {
      icnsRefIds.add(match.group(1)!);
    }
    content = content.replaceAll(fileRefPattern, '');

    // Remove PBXBuildFile entries that reference .icns files.
    // Pattern: <ID> /* <name>.icns in Resources */ = {isa = PBXBuildFile; ...};
    final buildFilePattern = RegExp(
      r'^[ \t]+(\w+)\s*/\*[^*]*\.icns[^*]*\*/\s*=\s*\{[^}]*\};\s*$',
      multiLine: true,
    );
    for (final match in buildFilePattern.allMatches(content)) {
      icnsRefIds.add(match.group(1)!);
    }
    content = content.replaceAll(buildFilePattern, '');

    // Remove .icns file IDs from PBXResourcesBuildPhase and PBXGroup `files`
    // and `children` arrays. These appear as:
    //   <ID> /* <name>.icns ... */,
    final resourceLinePattern = RegExp(
      r'^[ \t]+\w+\s*/\*[^*]*\.icns[^*]*\*/\s*,\s*$',
      multiLine: true,
    );
    content = content.replaceAll(resourceLinePattern, '');

    // Also remove any remaining references by collected IDs — covers cases
    // where the comment doesn't mention .icns but the ID was associated.
    for (final id in icnsRefIds) {
      final idLinePattern = RegExp(
        '^[ \\t]+$id\\s*/\\*[^*]*\\*/\\s*,\\s*\$',
        multiLine: true,
      );
      content = content.replaceAll(idLinePattern, '');
    }

    if (content != originalContent) {
      file.writeAsStringSync(content);
    }
  }

}
