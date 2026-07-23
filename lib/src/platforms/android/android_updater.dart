import 'dart:io';

import 'package:flutter_app_icons_generator/src/core/platform_updater.dart';
import 'package:flutter_app_icons_generator/src/flavors/flavor_model.dart';

/// Android platform configuration updater.
///
/// Ensures the `AndroidManifest.xml` references `@mipmap/ic_launcher`
/// as the application icon after icon generation, and configures
/// `productFlavors` in `build.gradle.kts` when flavors are used.
class AndroidUpdater implements PlatformUpdater {
  /// Path to `AndroidManifest.xml` relative to the project root.
  String _getManifestPath(String? flavorName) =>
      'android/app/src/${flavorName ?? "main"}/AndroidManifest.xml';

  @override
  Future<void> update(String projectRoot, {String? flavorName}) async {
    final manifestFile = File('$projectRoot/${_getManifestPath(flavorName)}');

    if (!manifestFile.existsSync()) {
      // Platform may not be initialized — nothing to update.
      return;
    }

    final content = manifestFile.readAsStringSync();
    final updatedContent = _ensureIconAttribute(content);

    if (updatedContent != content) {
      manifestFile.writeAsStringSync(updatedContent);
    }
  }

  /// Configures `productFlavors` in `build.gradle.kts` for all flavors.
  ///
  /// This should be called once after all flavor icons have been generated.
  /// It adds a `flavorDimensions` declaration and a `productFlavors` block
  /// with each flavor's `applicationId`.
  Future<void> configureProductFlavors(
    String projectRoot,
    Map<String, FlavorConfig> flavors,
  ) async {
    final gradleFile = File('$projectRoot/android/app/build.gradle.kts');

    if (!gradleFile.existsSync()) {
      // Try Groovy-based build.gradle as fallback.
      final groovyGradleFile = File('$projectRoot/android/app/build.gradle');
      if (groovyGradleFile.existsSync()) {
        await _configureProductFlavorsGroovy(groovyGradleFile, flavors);
        return;
      }
      return;
    }

    var content = gradleFile.readAsStringSync();

    // Check if productFlavors block already exists.
    if (content.contains('productFlavors')) {
      // Update existing productFlavors block.
      content = _updateExistingProductFlavorsKts(content, flavors);
    } else {
      // Insert a new productFlavors block inside the `android { }` block.
      content = _insertProductFlavorsKts(content, flavors);
    }

    gradleFile.writeAsStringSync(content);
  }

  /// Inserts the `flavorDimensions` and `productFlavors` block into the
  /// `android { }` section of `build.gradle.kts`.
  String _insertProductFlavorsKts(
    String content,
    Map<String, FlavorConfig> flavors,
  ) {
    final flavorsBlock = _buildProductFlavorsBlockKts(flavors);

    // Look for the `defaultConfig {` block and insert after it closes.
    final defaultConfigPattern = RegExp(
      r'defaultConfig\s*\{[^}]*\}',
      dotAll: true,
    );
    final match = defaultConfigPattern.firstMatch(content);

    if (match != null) {
      final insertPos = match.end;
      return '${content.substring(0, insertPos)}\n\n$flavorsBlock${content.substring(insertPos)}';
    }

    // Fallback: insert before the closing brace of the `android` block.
    final androidBlockEnd = content.lastIndexOf('}');
    if (androidBlockEnd > 0) {
      return '${content.substring(0, androidBlockEnd)}$flavorsBlock\n${content.substring(androidBlockEnd)}';
    }

    return content;
  }

  /// Updates an existing `productFlavors` block in `build.gradle.kts`.
  String _updateExistingProductFlavorsKts(
    String content,
    Map<String, FlavorConfig> flavors,
  ) {
    // Remove existing flavorDimensions line.
    content = content.replaceAll(
      RegExp(r'\s*flavorDimensions\s*\+?=\s*listOf\([^)]*\)\s*\n?'),
      '\n',
    );

    // Remove existing productFlavors block using brace-counting to
    // correctly handle arbitrarily nested `create(...)` entries.
    content = _removeBlockByBraceCounting(content, 'productFlavors');

    // Insert the new block after defaultConfig.
    final flavorsBlock = _buildProductFlavorsBlockKts(flavors);
    final defaultConfigPattern = RegExp(
      r'defaultConfig\s*\{[^}]*\}',
      dotAll: true,
    );
    final match = defaultConfigPattern.firstMatch(content);

    if (match != null) {
      final insertPos = match.end;
      return '${content.substring(0, insertPos)}\n\n$flavorsBlock${content.substring(insertPos)}';
    }

    return content;
  }

  /// Builds the Kotlin DSL `productFlavors` block string.
  String _buildProductFlavorsBlockKts(Map<String, FlavorConfig> flavors) {
    final buffer = StringBuffer();
    buffer.writeln('    flavorDimensions += listOf("app")');
    buffer.writeln('    productFlavors {');

    for (final entry in flavors.entries) {
      final name = entry.key;
      final config = entry.value;
      buffer.writeln('        create("$name") {');
      buffer.writeln('            dimension = "app"');
      buffer
          .writeln('            applicationId = "${config.bundleIdentifier}"');
      buffer.writeln('        }');
    }

    buffer.writeln('    }');
    return buffer.toString();
  }

  /// Configures `productFlavors` in Groovy-based `build.gradle`.
  Future<void> _configureProductFlavorsGroovy(
    File gradleFile,
    Map<String, FlavorConfig> flavors,
  ) async {
    var content = gradleFile.readAsStringSync();

    if (content.contains('productFlavors')) {
      content = _updateExistingProductFlavorsGroovy(content, flavors);
    } else {
      content = _insertProductFlavorsGroovy(content, flavors);
    }

    gradleFile.writeAsStringSync(content);
  }

  /// Inserts a Groovy-style `productFlavors` block.
  String _insertProductFlavorsGroovy(
    String content,
    Map<String, FlavorConfig> flavors,
  ) {
    final flavorsBlock = _buildProductFlavorsBlockGroovy(flavors);

    final defaultConfigPattern = RegExp(
      r'defaultConfig\s*\{[^}]*\}',
      dotAll: true,
    );
    final match = defaultConfigPattern.firstMatch(content);

    if (match != null) {
      final insertPos = match.end;
      return '${content.substring(0, insertPos)}\n\n$flavorsBlock${content.substring(insertPos)}';
    }

    return content;
  }

  /// Updates an existing Groovy-style `productFlavors` block.
  String _updateExistingProductFlavorsGroovy(
    String content,
    Map<String, FlavorConfig> flavors,
  ) {
    // Remove existing flavorDimensions line.
    content = content.replaceAll(
      RegExp(r'''\s*flavorDimensions\s+['"][^'"]*['"]\s*\n?'''),
      '\n',
    );

    // Remove existing productFlavors block using brace-counting to
    // correctly handle arbitrarily nested flavor entries.
    content = _removeBlockByBraceCounting(content, 'productFlavors');

    // Insert new block.
    final flavorsBlock = _buildProductFlavorsBlockGroovy(flavors);
    final defaultConfigPattern = RegExp(
      r'defaultConfig\s*\{[^}]*\}',
      dotAll: true,
    );
    final match = defaultConfigPattern.firstMatch(content);

    if (match != null) {
      final insertPos = match.end;
      return '${content.substring(0, insertPos)}\n\n$flavorsBlock${content.substring(insertPos)}';
    }

    return content;
  }

  /// Builds the Groovy `productFlavors` block string.
  String _buildProductFlavorsBlockGroovy(Map<String, FlavorConfig> flavors) {
    final buffer = StringBuffer();
    buffer.writeln('    flavorDimensions "app"');
    buffer.writeln('    productFlavors {');

    for (final entry in flavors.entries) {
      final name = entry.key;
      final config = entry.value;
      buffer.writeln('        $name {');
      buffer.writeln('            dimension "app"');
      buffer.writeln('            applicationId "${config.bundleIdentifier}"');
      buffer.writeln('        }');
    }

    buffer.writeln('    }');
    return buffer.toString();
  }

  /// Removes a named block (e.g. `productFlavors { ... }`) from [content]
  /// using brace-counting so that arbitrarily nested blocks are handled
  /// correctly.
  ///
  /// Any leading whitespace before the block keyword and trailing whitespace
  /// after the block's closing brace are also removed.
  String _removeBlockByBraceCounting(String content, String blockName) {
    final blockStart = RegExp('\\s*$blockName\\s*\\{');
    final match = blockStart.firstMatch(content);
    if (match == null) return content;

    // Walk forward from the opening `{` counting braces.
    final openBraceIndex = content.indexOf('{', match.start);
    var depth = 0;
    var endIndex = openBraceIndex;

    for (var i = openBraceIndex; i < content.length; i++) {
      final ch = content[i];
      if (ch == '{') {
        depth++;
      } else if (ch == '}') {
        depth--;
        if (depth == 0) {
          endIndex = i + 1;
          break;
        }
      }
    }

    // Consume trailing whitespace / blank lines.
    while (endIndex < content.length &&
        (content[endIndex] == ' ' ||
            content[endIndex] == '\t' ||
            content[endIndex] == '\n' ||
            content[endIndex] == '\r')) {
      endIndex++;
    }

    return '${content.substring(0, match.start)}\n${content.substring(endIndex)}';
  }

  /// Ensures the `<application` tag has `android:icon="@mipmap/ic_launcher"`.
  ///
  /// If the attribute is missing, it is added. If it references a different
  /// value, it is replaced.
  String _ensureIconAttribute(String content) {
    // Pattern to match android:icon with any value inside the <application tag.
    final iconAttrPattern = RegExp(r'android:icon="[^"]*"');

    // Pattern to match the opening <application tag (may span multiple lines).
    final applicationTagPattern = RegExp(r'<application\b');

    if (iconAttrPattern.hasMatch(content)) {
      // The attribute exists — check if it already has the correct value.
      final existingMatch = iconAttrPattern.firstMatch(content)!;
      final existingAttr = existingMatch.group(0)!;

      if (existingAttr == 'android:icon="@mipmap/ic_launcher"') {
        // Already correct — no changes needed.
        return content;
      }

      // Replace with the correct value.
      return content.replaceFirst(
        iconAttrPattern,
        'android:icon="@mipmap/ic_launcher"',
      );
    }

    // The attribute is not present — add it to the <application tag.
    if (applicationTagPattern.hasMatch(content)) {
      return content.replaceFirst(
        applicationTagPattern,
        '<application\n        android:icon="@mipmap/ic_launcher"',
      );
    }

    // No <application tag found — return content unchanged.
    return content;
  }
}
