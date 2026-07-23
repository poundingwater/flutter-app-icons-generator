import 'dart:io';

/// Patches a Flutter Podfile so custom flavor build configurations are mapped
/// to the correct CocoaPods build type.
///
/// CocoaPods needs each Xcode build configuration name to be declared in the
/// `project 'Runner', { ... }` block. When flavors add configuration names
/// such as `Debug-dev` or `Release-prod`, those entries must be present or
/// `pod install` can fail during analysis.
class PodfileFlavorPatcher {
  /// Adds flavor build-configuration mappings to the Podfile if needed.
  void patch(String podfilePath, Set<String> flavors) {
    final file = File(podfilePath);
    if (!file.existsSync()) return;

    final content = file.readAsStringSync();
    final updated = _addFlavorMappings(content, flavors);

    if (updated != content) {
      file.writeAsStringSync(updated);
    }
  }

  String _addFlavorMappings(String content, Set<String> flavors) {
    final blockPattern = RegExp(
      r'''(^\s*project\s+['"]Runner['"],\s*\{\s*$)(.*?)(^\s*\}\s*$)''',
      multiLine: true,
      dotAll: true,
    );

    final match = blockPattern.firstMatch(content);
    if (match == null) return content;

    final header = match.group(1)!;
    final body = match.group(2)!;
    final footer = match.group(3)!;

    final existingConfigs = <String>{};
    var indent = '  ';

    for (final line in body.split('\n')) {
      final mappingMatch = RegExp(
        r"^(\s*)'([^']+)'\s*=>\s*:(debug|release),?\s*$",
      ).firstMatch(line);

      if (mappingMatch != null) {
        existingConfigs.add(mappingMatch.group(2)!);
        indent = mappingMatch.group(1)!;
      }
    }

    final additions = <String>[];
    final sortedFlavors = flavors.toList()..sort();

    for (final flavor in sortedFlavors) {
      final mappings = [
        ('Debug-$flavor', ':debug'),
        ('Profile-$flavor', ':release'),
        ('Release-$flavor', ':release'),
      ];

      for (final mapping in mappings) {
        if (!existingConfigs.contains(mapping.$1)) {
          additions.add("$indent'${mapping.$1}' => ${mapping.$2},");
        }
      }
    }

    if (additions.isEmpty) return content;

    final normalizedBody = body.trimRight();
    final bodyPrefix = normalizedBody.isEmpty ? '' : '$normalizedBody\n';
    final insertion = additions.join('\n');

    return content.replaceFirst(
      match.group(0)!,
      '$header$bodyPrefix$insertion\n$footer',
    );
  }
}