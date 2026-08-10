import 'dart:io';

/// Patches `project.pbxproj` to add flavor-specific build configurations
/// by cloning the user's existing Debug/Release/Profile configurations.
///
/// This approach is stable across Xcode versions because it copies whatever
/// settings the user already has rather than hardcoding build settings.
/// Each cloned configuration gets a `baseConfigurationReference` pointing
/// to the flavor's xcconfig file.
class IosPbxprojPatcher {
  /// Adds flavor build configurations to the project.
  ///
  /// For each flavor, clones existing Debug/Release/Profile configurations
  /// for both the PBXProject and PBXNativeTarget, renames them to
  /// `Debug-<flavor>`, etc., and registers them in the configuration lists.
  ///
  /// Skips flavors that already have configurations present.
  void patch(String projectRoot, Set<String> flavors) {
    final pbxprojPath = '$projectRoot/ios/Runner.xcodeproj/project.pbxproj';
    final file = File(pbxprojPath);

    if (!file.existsSync()) return;

    var content = file.readAsStringSync();

    for (final flavorName in flavors) {
      if (content.contains('name = "Debug-$flavorName"')) {
        content = _updateExistingXcconfigReferences(content, flavorName);
        continue;
      }
      content = _addFlavorConfigurations(content, flavorName);
    }

    file.writeAsStringSync(content);
  }

  /// Core logic: clone existing configs, rename, inject xcconfig refs.
  String _addFlavorConfigurations(String content, String flavorName) {
    // Generate deterministic IDs for this flavor.
    final ids = _FlavorIds(flavorName);

    // 1. Add PBXFileReference entries for xcconfig files.
    content = _addXcconfigFileRefs(content, flavorName, ids);

    // 2. Clone project-level build configurations.
    content = _cloneProjectConfigs(content, flavorName, ids);

    // 3. Clone target-level build configurations.
    content = _cloneTargetConfigs(content, flavorName, ids);

    // 4. Register in configuration lists.
    content = _addToConfigLists(content, flavorName, ids);

    return content;
  }

  /// Adds PBXFileReference entries for the flavor xcconfig files.
  String _addXcconfigFileRefs(
      String content, String flavorName, _FlavorIds ids) {
    final entries = [
      '\t\t${ids.debugXcconfigRef} /* Debug-$flavorName.xcconfig */ = '
          '{isa = PBXFileReference; lastKnownFileType = text.xcconfig; '
          'name = "Debug-$flavorName.xcconfig"; '
          'path = "Flutter/Debug-$flavorName.xcconfig"; '
          'sourceTree = SOURCE_ROOT; };',
      '\t\t${ids.releaseXcconfigRef} /* Release-$flavorName.xcconfig */ = '
          '{isa = PBXFileReference; lastKnownFileType = text.xcconfig; '
          'name = "Release-$flavorName.xcconfig"; '
          'path = "Flutter/Release-$flavorName.xcconfig"; '
          'sourceTree = SOURCE_ROOT; };',
      '\t\t${ids.profileXcconfigRef} /* Profile-$flavorName.xcconfig */ = '
          '{isa = PBXFileReference; lastKnownFileType = text.xcconfig; '
          'name = "Profile-$flavorName.xcconfig"; '
          'path = "Flutter/Profile-$flavorName.xcconfig"; '
          'sourceTree = SOURCE_ROOT; };',
    ];

    return content.replaceFirst(
      '/* Begin PBXFileReference section */',
      '/* Begin PBXFileReference section */\n${entries.join('\n')}',
    );
  }

  /// Clones the project-level (PBXProject) Debug/Release/Profile configs.
  ///
  /// Finds existing configs by matching them in the project's configuration
  /// list, extracts their full buildSettings blocks, and creates copies
  /// with the flavor name suffix and xcconfig baseConfigurationReference.
  String _cloneProjectConfigs(
      String content, String flavorName, _FlavorIds ids) {
    // Find the project configuration list to get existing config IDs.
    final projectListMatch = RegExp(
      r'\/\* Build configuration list for PBXProject "Runner" \*\/ = \{[^}]*?buildConfigurations = \(\s*([^)]+)\)',
      dotAll: true,
    ).firstMatch(content);

    if (projectListMatch == null) return content;

    final configIds = _extractConfigIds(projectListMatch.group(1)!);
    final debugId = configIds['Debug'];
    final releaseId = configIds['Release'];
    final profileId = configIds['Profile'];

    final newConfigs = StringBuffer();

    if (debugId != null) {
      final cloned = _cloneConfig(
        content,
        debugId,
        'Debug-$flavorName',
        ids.projectDebug,
        baseConfigRef: ids.debugXcconfigRef,
        xcconfigName: 'Debug-$flavorName.xcconfig',
      );
      if (cloned != null) newConfigs.writeln(cloned);
    }

    if (releaseId != null) {
      final cloned = _cloneConfig(
        content,
        releaseId,
        'Release-$flavorName',
        ids.projectRelease,
        baseConfigRef: ids.releaseXcconfigRef,
        xcconfigName: 'Release-$flavorName.xcconfig',
      );
      if (cloned != null) newConfigs.writeln(cloned);
    }

    if (profileId != null) {
      final cloned = _cloneConfig(
        content,
        profileId,
        'Profile-$flavorName',
        ids.projectProfile,
        baseConfigRef: ids.profileXcconfigRef,
        xcconfigName: 'Profile-$flavorName.xcconfig',
      );
      if (cloned != null) newConfigs.writeln(cloned);
    }

    if (newConfigs.isEmpty) return content;

    return content.replaceFirst(
      '/* End XCBuildConfiguration section */',
      '${newConfigs}/* End XCBuildConfiguration section */',
    );
  }

  /// Clones the target-level (PBXNativeTarget) Debug/Release/Profile configs.
  String _cloneTargetConfigs(
      String content, String flavorName, _FlavorIds ids) {
    final targetListMatch = RegExp(
      r'\/\* Build configuration list for PBXNativeTarget "Runner" \*\/ = \{[^}]*?buildConfigurations = \(\s*([^)]+)\)',
      dotAll: true,
    ).firstMatch(content);

    if (targetListMatch == null) return content;

    final configIds = _extractConfigIds(targetListMatch.group(1)!);
    final debugId = configIds['Debug'];
    final releaseId = configIds['Release'];
    final profileId = configIds['Profile'];

    final newConfigs = StringBuffer();

    if (debugId != null) {
      final cloned = _cloneConfig(
        content,
        debugId,
        'Debug-$flavorName',
        ids.targetDebug,
        baseConfigRef: ids.debugXcconfigRef,
        xcconfigName: 'Debug-$flavorName.xcconfig',
      );
      if (cloned != null) newConfigs.writeln(cloned);
    }

    if (releaseId != null) {
      final cloned = _cloneConfig(
        content,
        releaseId,
        'Release-$flavorName',
        ids.targetRelease,
        baseConfigRef: ids.releaseXcconfigRef,
        xcconfigName: 'Release-$flavorName.xcconfig',
      );
      if (cloned != null) newConfigs.writeln(cloned);
    }

    if (profileId != null) {
      final cloned = _cloneConfig(
        content,
        profileId,
        'Profile-$flavorName',
        ids.targetProfile,
        baseConfigRef: ids.profileXcconfigRef,
        xcconfigName: 'Profile-$flavorName.xcconfig',
      );
      if (cloned != null) newConfigs.writeln(cloned);
    }

    if (newConfigs.isEmpty) return content;

    return content.replaceFirst(
      '/* End XCBuildConfiguration section */',
      '${newConfigs}/* End XCBuildConfiguration section */',
    );
  }

  /// Clones a single XCBuildConfiguration entry, replacing its ID, name,
  /// and setting the baseConfigurationReference.
  String? _cloneConfig(
    String content,
    String sourceId,
    String newName,
    String newId, {
    required String baseConfigRef,
    required String xcconfigName,
  }) {
    // Extract the full configuration block for the source ID.
    // Pattern: <id> /* Name */ = {\n ... \n\t\t};
    final blockPattern = RegExp(
      '\\s*$sourceId /\\*[^*]*\\*/ = \\{(.*?)\\n\\t\\t\\};',
      dotAll: true,
    );
    final match = blockPattern.firstMatch(content);
    if (match == null) return null;

    var block = match.group(0)!;

    // Replace the ID.
    block = block.replaceFirst(sourceId, newId);

    // Replace the comment after the ID.
    block = block.replaceFirst(
      RegExp(r'/\*[^*]*\*/'),
      '/* $newName */',
    );

    // Replace or add baseConfigurationReference.
    if (block.contains('baseConfigurationReference')) {
      block = block.replaceFirst(
        RegExp(r'baseConfigurationReference = [^;]+;'),
        'baseConfigurationReference = $baseConfigRef /* $xcconfigName */;',
      );
    } else {
      // Insert after "isa = XCBuildConfiguration;"
      block = block.replaceFirst(
        'isa = XCBuildConfiguration;',
        'isa = XCBuildConfiguration;\n'
            '\t\t\tbaseConfigurationReference = $baseConfigRef /* $xcconfigName */;',
      );
    }

    // Remove settings that should be controlled by the xcconfig.
    // Build settings in pbxproj override xcconfig values, so these must
    // be removed for the flavor xcconfig to take effect.
    block = block.replaceAll(
      RegExp(r'\n\s*ASSETCATALOG_COMPILER_APPICON_NAME = [^;]+;'),
      '',
    );
    block = block.replaceAll(
      RegExp(r'\n\s*PRODUCT_BUNDLE_IDENTIFIER = [^;]+;'),
      '',
    );

    // Replace the configuration name — the standalone `name = ...;` field.
    // This is distinct from PRODUCT_NAME, MARKETING_VERSION etc. because
    // it appears as just `name` (no prefix) at the end of the block.
    // We search from the end of the block to avoid matching buildSettings fields.
    final nameQuotedPattern = RegExp(r'\n(\t+)name = "[^"]*";\n');
    final nameUnquotedPattern = RegExp(r'\n(\t+)name = \w+;\n');

    // Find the LAST occurrence (which is the config name, not a buildSetting).
    final quotedMatches = nameQuotedPattern.allMatches(block).toList();
    final unquotedMatches = nameUnquotedPattern.allMatches(block).toList();

    if (quotedMatches.isNotEmpty) {
      final lastMatch = quotedMatches.last;
      final indent = lastMatch.group(1)!;
      block = block.substring(0, lastMatch.start) +
          '\n${indent}name = "$newName";\n' +
          block.substring(lastMatch.end);
    } else if (unquotedMatches.isNotEmpty) {
      final lastMatch = unquotedMatches.last;
      final indent = lastMatch.group(1)!;
      block = block.substring(0, lastMatch.start) +
          '\n${indent}name = "$newName";\n' +
          block.substring(lastMatch.end);
    }

    return block;
  }

  /// Adds the new flavor config IDs to both configuration lists.
  String _addToConfigLists(String content, String flavorName, _FlavorIds ids) {
    // Project configuration list.
    content = _appendToConfigList(
      content,
      'PBXProject',
      [
        '${ids.projectDebug} /* Debug-$flavorName */',
        '${ids.projectProfile} /* Profile-$flavorName */',
        '${ids.projectRelease} /* Release-$flavorName */',
      ],
    );

    // Target configuration list.
    content = _appendToConfigList(
      content,
      'PBXNativeTarget',
      [
        '${ids.targetDebug} /* Debug-$flavorName */',
        '${ids.targetProfile} /* Profile-$flavorName */',
        '${ids.targetRelease} /* Release-$flavorName */',
      ],
    );

    return content;
  }

  /// Appends entries to a specific XCConfigurationList.
  String _appendToConfigList(
      String content, String listType, List<String> entries) {
    final pattern = RegExp(
      '(\\/\\* Build configuration list for $listType "Runner" \\*\\/ = \\{[^}]*?buildConfigurations = \\([^)]*?)((\\s*)\\);)',
      dotAll: true,
    );

    final match = pattern.firstMatch(content);
    if (match == null) return content;

    final indent = match.group(3) ?? '\n\t\t\t\t';
    final newEntries = entries.map((e) => '$indent$e,').join('');

    return content.replaceFirst(
      pattern,
      '${match.group(1)}$newEntries${match.group(2)}',
    );
  }

  /// Extracts config name → ID mapping from a configuration list body.
  ///
  /// Input looks like:
  /// ```
  /// 97C147031CF9000F007C117D /* Debug */,
  /// 97C147041CF9000F007C117D /* Release */,
  /// ```
  Map<String, String> _extractConfigIds(String listBody) {
    final result = <String, String>{};
    final pattern = RegExp(r'(\w+)\s*/\*\s*(\w+)\s*\*/');

    for (final match in pattern.allMatches(listBody)) {
      final id = match.group(1)!;
      final name = match.group(2)!;
      // Only capture base configs (Debug, Release, Profile), not flavor ones.
      if (name == 'Debug' || name == 'Release' || name == 'Profile') {
        result[name] = id;
      }
    }

    return result;
  }

  /// Updates existing flavor configuration file references in `project.pbxproj`
  /// to use the new `[Mode]-[Flavor].xcconfig` naming scheme.
  String _updateExistingXcconfigReferences(String content, String flavorName) {
    final modes = ['Debug', 'Release', 'Profile'];

    for (final mode in modes) {
      final configPattern = RegExp(
        r'\w+\s*/\*\s*' +
            mode +
            '-' +
            flavorName +
            r'\s*\*/\s*=\s*\{[^}]*?baseConfigurationReference\s*=\s*(\w+)\s*/\*([^*]*)\*/\s*;',
        dotAll: true,
      );

      final matches = configPattern.allMatches(content);
      if (matches.isEmpty) continue;

      final refId = matches.first.group(1)!;

      // Update baseConfigurationReference comments to the new name format
      content = content.replaceAllMapped(
        RegExp(r'baseConfigurationReference\s*=\s*' +
            refId +
            r'\s*/\*([^*]*)\*/\s*;'),
        (match) =>
            'baseConfigurationReference = $refId /* $mode-$flavorName.xcconfig */;',
      );

      // Find and update the PBXFileReference line to point to the new filename and path
      final fileRefPattern = RegExp(refId +
          r'\s*/\*[^*]*\*/\s*=\s*\{isa\s*=\s*PBXFileReference;[^}]+?\};');

      if (fileRefPattern.hasMatch(content)) {
        content = content.replaceFirst(
          fileRefPattern,
          '$refId /* $mode-$flavorName.xcconfig */ = {isa = PBXFileReference; lastKnownFileType = text.xcconfig; name = "$mode-$flavorName.xcconfig"; path = "Flutter/$mode-$flavorName.xcconfig"; sourceTree = SOURCE_ROOT; };',
        );
      }
    }

    return content;
  }
}

/// Holds deterministic IDs for all artifacts of a single flavor.
class _FlavorIds {
  _FlavorIds(String flavor)
      : projectDebug = _hash(flavor, 'project', 'debug'),
        projectRelease = _hash(flavor, 'project', 'release'),
        projectProfile = _hash(flavor, 'project', 'profile'),
        targetDebug = _hash(flavor, 'target', 'debug'),
        targetRelease = _hash(flavor, 'target', 'release'),
        targetProfile = _hash(flavor, 'target', 'profile'),
        debugXcconfigRef = _hash(flavor, 'fileref', 'debug'),
        releaseXcconfigRef = _hash(flavor, 'fileref', 'release'),
        profileXcconfigRef = _hash(flavor, 'fileref', 'profile');

  final String projectDebug;
  final String projectRelease;
  final String projectProfile;
  final String targetDebug;
  final String targetRelease;
  final String targetProfile;
  final String debugXcconfigRef;
  final String releaseXcconfigRef;
  final String profileXcconfigRef;

  /// Generates a deterministic 24-character hex ID.
  ///
  /// Uses FNV-1a hashing to produce stable IDs across repeated runs,
  /// preventing duplicate entries in the pbxproj.
  static String _hash(String flavor, String scope, String mode) {
    final input = 'faig_ios_${flavor}_${scope}_$mode';
    var h = 0x811c9dc5;
    for (var i = 0; i < input.length; i++) {
      h ^= input.codeUnitAt(i);
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    final h2 = (h * 0x5bd1e995) & 0xFFFFFFFF;
    final h3 = (h * 0x1b873593) & 0xFFFFFFFF;
    return '${h.toRadixString(16).padLeft(8, '0')}'
            '${h2.toRadixString(16).padLeft(8, '0')}'
            '${h3.toRadixString(16).padLeft(8, '0')}'
        .toUpperCase();
  }
}
