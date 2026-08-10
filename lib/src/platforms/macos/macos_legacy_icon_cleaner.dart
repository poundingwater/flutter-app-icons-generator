import 'dart:io';

import 'package:xml/xml.dart';

/// Detects and removes legacy `.icns`-based icon setups from macOS projects.
///
/// Older Flutter projects (and manual Xcode setups) reference a standalone
/// `.icns` file directly in:
/// 1. The file system (e.g., `macos/Runner/Assets.xcassets/AppIcon.icns`)
/// 2. The `project.pbxproj` (PBXFileReference + PBXBuildFile entries)
/// 3. The `Info.plist` (`CFBundleIconFile` → migrated to `CFBundleIconName`)
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
  /// 4. Migrates `CFBundleIconFile` to `CFBundleIconName` in Info.plist
  void clean(String projectRoot) {
    _deleteIcnsFiles(projectRoot);
    _cleanPbxproj(projectRoot);
    _migratePlistIconKey(projectRoot);
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

  /// Ensures `CFBundleIconFile` is removed and `CFBundleIconName` is present.
  ///
  /// Uses XML DOM parsing for structural safety — no regex on plist content.
  /// Two independent operations:
  /// - Remove: deletes the `CFBundleIconFile` key+value nodes if found.
  /// - Add: inserts `CFBundleIconName` with value `AppIcon` if absent.
  void _migratePlistIconKey(String projectRoot) {
    final plistPath = '$projectRoot/macos/Runner/Info.plist';
    final file = File(plistPath);
    if (!file.existsSync()) return;

    final document = XmlDocument.parse(file.readAsStringSync());
    final rootDict = document.rootElement.findElements('dict').firstOrNull;
    if (rootDict == null) return;

    var modified = false;

    modified = _removeKeyValue(rootDict, 'CFBundleIconFile') || modified;
    modified =
        _addKeyValue(rootDict, 'CFBundleIconName', 'AppIcon') || modified;

    if (modified) {
      file.writeAsStringSync(document.toXmlString(pretty: true, indent: '\t'));
    }
  }

  /// Removes a `<key>` and its immediately following `<string>` sibling.
  /// Returns `true` if a removal was performed.
  bool _removeKeyValue(XmlElement dict, String keyName) {
    final children = dict.children;
    for (var i = 0; i < children.length; i++) {
      final node = children[i];
      if (node is XmlElement &&
          node.localName == 'key' &&
          node.innerText == keyName) {
        // Find the next element sibling (the value).
        final valueNode = _nextElementSibling(children, i);
        if (valueNode != null) valueNode.remove();
        node.remove();
        return true;
      }
    }
    return false;
  }

  /// Adds a `<key>` + `<string>` pair to the dict if not already present.
  /// Returns `true` if an addition was performed.
  bool _addKeyValue(XmlElement dict, String keyName, String value) {
    // Check if key already exists.
    for (final child in dict.childElements) {
      if (child.localName == 'key' && child.innerText == keyName) {
        return false;
      }
    }

    dict.children.add(XmlElement(XmlName.parts('key'), [], [XmlText(keyName)]));
    dict.children
        .add(XmlElement(XmlName.parts('string'), [], [XmlText(value)]));
    return true;
  }

  /// Returns the next XmlElement sibling after index [i] in [children].
  XmlElement? _nextElementSibling(List<XmlNode> children, int i) {
    for (var j = i + 1; j < children.length; j++) {
      if (children[j] is XmlElement) return children[j] as XmlElement;
    }
    return null;
  }
}
