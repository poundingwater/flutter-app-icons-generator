import 'dart:io';

/// Patches `macos/Runner.xcodeproj/project.pbxproj` to add flavor-specific
/// build configurations by cloning the user's existing ones.
///
/// This is the same clone-based approach as iOS — it copies whatever settings
/// the user already has (deployment target, signing, entitlements, etc.)
/// rather than hardcoding build settings that will drift over time.
class MacosPbxprojPatcher {
  /// Adds flavor build configurations to the macOS Xcode project.
  ///
  /// For each flavor, clones existing Debug/Release/Profile configurations
  /// for both the PBXProject and PBXNativeTarget, renames them to
  /// `Debug-<flavor>`, etc., and registers them in the configuration lists.
  void patch(String projectRoot, Set<String> flavors) {
    final pbxprojPath = '$projectRoot/macos/Runner.xcodeproj/project.pbxproj';
    final file = File(pbxprojPath);

    if (!file.existsSync()) return;

    var content = file.readAsStringSync();

    for (final flavorName in flavors) {
      if (content.contains('name = "Debug-$flavorName"')) continue;
      content = _addFlavorConfigurations(content, flavorName);
    }

    file.writeAsStringSync(content);
  }

  String _addFlavorConfigurations(String content, String flavorName) {
    final ids = _FlavorIds(flavorName);

    content = _addXcconfigFileRefs(content, flavorName, ids);
    content = _cloneProjectConfigs(content, flavorName, ids);
    content = _cloneTargetConfigs(content, flavorName, ids);
    content = _addToConfigLists(content, flavorName, ids);

    return content;
  }

  String _addXcconfigFileRefs(
      String content, String flavorName, _FlavorIds ids) {
    final entries = [
      '\t\t${ids.debugXcconfigRef} /* $flavorName-Debug.xcconfig */ = '
          '{isa = PBXFileReference; lastKnownFileType = text.xcconfig; '
          'name = "$flavorName-Debug.xcconfig"; '
          'path = "Flutter/$flavorName-Debug.xcconfig"; '
          'sourceTree = "<group>"; };',
      '\t\t${ids.releaseXcconfigRef} /* $flavorName-Release.xcconfig */ = '
          '{isa = PBXFileReference; lastKnownFileType = text.xcconfig; '
          'name = "$flavorName-Release.xcconfig"; '
          'path = "Flutter/$flavorName-Release.xcconfig"; '
          'sourceTree = "<group>"; };',
      '\t\t${ids.profileXcconfigRef} /* $flavorName-Profile.xcconfig */ = '
          '{isa = PBXFileReference; lastKnownFileType = text.xcconfig; '
          'name = "$flavorName-Profile.xcconfig"; '
          'path = "Flutter/$flavorName-Profile.xcconfig"; '
          'sourceTree = "<group>"; };',
    ];

    return content.replaceFirst(
      '/* Begin PBXFileReference section */',
      '/* Begin PBXFileReference section */\n${entries.join('\n')}',
    );
  }

  String _cloneProjectConfigs(
      String content, String flavorName, _FlavorIds ids) {
    final projectListMatch = RegExp(
      r'\/\* Build configuration list for PBXProject "Runner" \*\/ = \{[^}]*?buildConfigurations = \(\s*([^)]+)\)',
      dotAll: true,
    ).firstMatch(content);

    if (projectListMatch == null) return content;

    final configIds = _extractConfigIds(projectListMatch.group(1)!);
    final newConfigs = StringBuffer();

    final clones = {
      'Debug': (ids.projectDebug, ids.debugXcconfigRef, 'Debug'),
      'Release': (ids.projectRelease, ids.releaseXcconfigRef, 'Release'),
      'Profile': (ids.projectProfile, ids.profileXcconfigRef, 'Profile'),
    };

    for (final entry in clones.entries) {
      final sourceId = configIds[entry.key];
      if (sourceId == null) continue;

      final (newId, xcconfigRef, mode) = entry.value;
      final cloned = _cloneConfig(
        content, sourceId, '$mode-$flavorName', newId,
        baseConfigRef: xcconfigRef,
        xcconfigName: '$flavorName-$mode.xcconfig',
      );
      if (cloned != null) newConfigs.writeln(cloned);
    }

    if (newConfigs.isEmpty) return content;

    return content.replaceFirst(
      '/* End XCBuildConfiguration section */',
      '${newConfigs}/* End XCBuildConfiguration section */',
    );
  }

  String _cloneTargetConfigs(
      String content, String flavorName, _FlavorIds ids) {
    final targetListMatch = RegExp(
      r'\/\* Build configuration list for PBXNativeTarget "Runner" \*\/ = \{[^}]*?buildConfigurations = \(\s*([^)]+)\)',
      dotAll: true,
    ).firstMatch(content);

    if (targetListMatch == null) return content;

    final configIds = _extractConfigIds(targetListMatch.group(1)!);
    final newConfigs = StringBuffer();

    final clones = {
      'Debug': (ids.targetDebug, ids.debugXcconfigRef, 'Debug'),
      'Release': (ids.targetRelease, ids.releaseXcconfigRef, 'Release'),
      'Profile': (ids.targetProfile, ids.profileXcconfigRef, 'Profile'),
    };

    for (final entry in clones.entries) {
      final sourceId = configIds[entry.key];
      if (sourceId == null) continue;

      final (newId, xcconfigRef, mode) = entry.value;
      final cloned = _cloneConfig(
        content, sourceId, '$mode-$flavorName', newId,
        baseConfigRef: xcconfigRef,
        xcconfigName: '$flavorName-$mode.xcconfig',
      );
      if (cloned != null) newConfigs.writeln(cloned);
    }

    if (newConfigs.isEmpty) return content;

    return content.replaceFirst(
      '/* End XCBuildConfiguration section */',
      '${newConfigs}/* End XCBuildConfiguration section */',
    );
  }

  String? _cloneConfig(
    String content,
    String sourceId,
    String newName,
    String newId, {
    required String baseConfigRef,
    required String xcconfigName,
  }) {
    final blockPattern = RegExp(
      '\\s*$sourceId /\\*[^*]*\\*/ = \\{(.*?)\\n\\t\\t\\};',
      dotAll: true,
    );
    final match = blockPattern.firstMatch(content);
    if (match == null) return null;

    var block = match.group(0)!;

    block = block.replaceFirst(sourceId, newId);
    block = block.replaceFirst(RegExp(r'/\*[^*]*\*/'), '/* $newName */');

    if (block.contains('baseConfigurationReference')) {
      block = block.replaceFirst(
        RegExp(r'baseConfigurationReference = [^;]+;'),
        'baseConfigurationReference = $baseConfigRef /* $xcconfigName */;',
      );
    } else {
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
    // This is distinct from PRODUCT_NAME etc. because it appears as just
    // `name` (no prefix) at the end of the block. We find the LAST occurrence
    // which is always the config name, not a buildSettings field.
    final nameQuotedPattern = RegExp(r'\n(\t+)name = "[^"]*";\n');
    final nameUnquotedPattern = RegExp(r'\n(\t+)name = \w+;\n');

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

  String _addToConfigLists(
      String content, String flavorName, _FlavorIds ids) {
    content = _appendToConfigList(content, 'PBXProject', [
      '${ids.projectDebug} /* Debug-$flavorName */',
      '${ids.projectProfile} /* Profile-$flavorName */',
      '${ids.projectRelease} /* Release-$flavorName */',
    ]);

    content = _appendToConfigList(content, 'PBXNativeTarget', [
      '${ids.targetDebug} /* Debug-$flavorName */',
      '${ids.targetProfile} /* Profile-$flavorName */',
      '${ids.targetRelease} /* Release-$flavorName */',
    ]);

    return content;
  }

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

  Map<String, String> _extractConfigIds(String listBody) {
    final result = <String, String>{};
    final pattern = RegExp(r'(\w+)\s*/\*\s*(\w+)\s*\*/');

    for (final match in pattern.allMatches(listBody)) {
      final id = match.group(1)!;
      final name = match.group(2)!;
      if (name == 'Debug' || name == 'Release' || name == 'Profile') {
        result[name] = id;
      }
    }

    return result;
  }
}

/// Deterministic IDs for a single macOS flavor's artifacts.
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

  static String _hash(String flavor, String scope, String mode) {
    final input = 'faig_macos_${flavor}_${scope}_$mode';
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
