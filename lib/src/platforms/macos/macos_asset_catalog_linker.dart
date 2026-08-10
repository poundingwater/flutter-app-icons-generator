import 'dart:io';

/// Ensures `Assets.xcassets` is included in the Xcode Resources build phase.
///
/// When migrating from a standalone `.icns` file to an asset catalog, the
/// `.icns` entry is removed from the Resources build phase but
/// `Assets.xcassets` may never have been added. Without a `PBXBuildFile`
/// entry linking it to the Resources phase, Xcode never compiles the asset
/// catalog into the app bundle — resulting in a blank icon.
///
/// This linker is idempotent — it skips if `Assets.xcassets` is already
/// present in the build phase.
class MacosAssetCatalogLinker {
  /// Comment marker used for the build file entry.
  static const _comment = 'Assets.xcassets in Resources';

  /// Ensures `Assets.xcassets` has a PBXBuildFile entry in the Resources
  /// build phase of `project.pbxproj`.
  void link(String projectRoot) {
    final pbxprojPath = '$projectRoot/macos/Runner.xcodeproj/project.pbxproj';
    final file = File(pbxprojPath);
    if (!file.existsSync()) return;

    var content = file.readAsStringSync();

    // Already linked — nothing to do.
    if (content.contains(_comment)) return;

    final fileRefId = _findAssetCatalogFileRef(content);
    if (fileRefId == null) return;

    final buildFileId = _generateId(content);

    content = _addBuildFileEntry(content, buildFileId, fileRefId);
    content = _addToResourcesBuildPhase(content, buildFileId);

    file.writeAsStringSync(content);
  }

  /// Finds the PBXFileReference ID for `Assets.xcassets`.
  String? _findAssetCatalogFileRef(String content) {
    final pattern = RegExp(
      r'(\w+)\s*/\*\s*Assets\.xcassets\s*\*/\s*=\s*\{isa\s*=\s*PBXFileReference',
    );
    final match = pattern.firstMatch(content);
    return match?.group(1);
  }

  /// Generates a unique 24-character hex ID not already present in content.
  String _generateId(String content) {
    // Use a deterministic seed based on the marker comment, then increment
    // until we find an unused ID.
    var hash = _comment.hashCode.abs();
    while (true) {
      final id = hash.toRadixString(16).toUpperCase().padLeft(24, '0');
      final candidate = id.substring(id.length - 24);
      if (!content.contains(candidate)) return candidate;
      hash++;
    }
  }

  /// Adds a PBXBuildFile entry for Assets.xcassets.
  String _addBuildFileEntry(
    String content,
    String buildFileId,
    String fileRefId,
  ) {
    final entry = '\t\t$buildFileId /* $_comment */ = '
        '{isa = PBXBuildFile; fileRef = $fileRefId '
        '/* Assets.xcassets */; };';

    return content.replaceFirst(
      '/* End PBXBuildFile section */',
      '$entry\n/* End PBXBuildFile section */',
    );
  }

  /// Adds the build file ID to the Runner target's Resources build phase.
  ///
  /// Locates the PBXNativeTarget named "Runner", extracts its Resources
  /// build phase ID, then inserts into that specific phase's files list.
  String _addToResourcesBuildPhase(String content, String buildFileId) {
    final phaseId = _findRunnerResourcesPhaseId(content);
    if (phaseId == null) return content;

    // Find the exact position of this phase's definition and insert after
    // its `files = (\n`. Uses indexOf for precision — regex with leading
    // `\s+` and dotAll can match across unrelated whitespace boundaries.
    final phaseHeader = '$phaseId /* Resources */ = {';
    final headerIdx = content.indexOf(phaseHeader);
    if (headerIdx == -1) return content;

    // Find `files = (\n` within this phase block (search from headerIdx).
    final filesPattern = RegExp(r'files = \(\s*\n');
    final filesMatch = filesPattern.firstMatch(content.substring(headerIdx));
    if (filesMatch == null) return content;

    final insertionIdx = headerIdx + filesMatch.end;
    final insertion = '\t\t\t\t$buildFileId /* $_comment */,\n';
    return content.substring(0, insertionIdx) +
        insertion +
        content.substring(insertionIdx);
  }

  /// Finds the PBXResourcesBuildPhase ID belonging to the Runner (app) target.
  ///
  /// Strategy: iterates PBXNativeTarget blocks, finds the one with
  /// `productType = "com.apple.product-type.application"` (the main app),
  /// then extracts its Resources build phase ID from the buildPhases list.
  String? _findRunnerResourcesPhaseId(String content) {
    // Split into individual native target blocks.
    final blockPattern = RegExp(
      r'(\w+) /\* .+? \*/ = \{\s*\n\s*isa = PBXNativeTarget;(.*?)\n\s*\};',
      dotAll: true,
    );

    for (final blockMatch in blockPattern.allMatches(content)) {
      final blockBody = blockMatch.group(2)!;

      // Identify the app target (not test bundle, not extension).
      if (!blockBody
          .contains('productType = "com.apple.product-type.application"')) {
        continue;
      }

      // Extract buildPhases list from this target block.
      final phasesMatch = RegExp(
        r'buildPhases = \(\s*\n(.*?)\)',
        dotAll: true,
      ).firstMatch(blockBody);
      if (phasesMatch == null) continue;

      return _extractResourcesPhaseId(content, phasesMatch.group(1)!);
    }

    return null;
  }

  /// Given the buildPhases list content, finds the Resources phase ID.
  String? _extractResourcesPhaseId(String content, String phasesListBody) {
    final phaseIds = RegExp(r'(\w+)\s*/\*')
        .allMatches(phasesListBody)
        .map((m) => m.group(1)!)
        .toList();

    for (final id in phaseIds) {
      final phasePattern = RegExp(
        '$id /\\* Resources \\*/ = \\{.*?isa = PBXResourcesBuildPhase',
        dotAll: true,
      );
      if (phasePattern.hasMatch(content)) return id;
    }

    return null;
  }
}
