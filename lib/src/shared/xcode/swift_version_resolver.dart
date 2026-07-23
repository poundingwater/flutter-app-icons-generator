import 'dart:io';

/// Resolves the Swift language version from an existing Xcode project.
class SwiftVersionResolver {
  /// Reads the iOS Runner Swift version from `ios/Runner.xcodeproj`.
  String? resolveIos(String projectRoot) {
    return _resolve('$projectRoot/ios/Runner.xcodeproj/project.pbxproj');
  }

  /// Reads the macOS Runner Swift version from `macos/Runner.xcodeproj`.
  String? resolveMacos(String projectRoot) {
    return _resolve('$projectRoot/macos/Runner.xcodeproj/project.pbxproj');
  }

  String? _resolve(String pbxprojPath) {
    final file = File(pbxprojPath);
    if (!file.existsSync()) return null;

    final content = file.readAsStringSync();
    return _extractSwiftVersion(content, 'PBXNativeTarget') ??
        _extractSwiftVersion(content, 'PBXProject');
  }

  String? _extractSwiftVersion(String content, String listType) {
    final listMatch = RegExp(
      '\/\* Build configuration list for ${RegExp.escape(listType)} "Runner" \\*\/ = \\{[^}]*?buildConfigurations = \\(\\s*([^)]+)\\)',
      dotAll: true,
    ).firstMatch(content);

    if (listMatch == null) return null;

    final configIds = _extractConfigIds(listMatch.group(1)!);

    for (final configName in ['Debug', 'Release', 'Profile']) {
      final sourceId = configIds[configName];
      if (sourceId == null) continue;

      final version = _extractSwiftVersionFromBlock(content, sourceId);
      if (version != null && version.isNotEmpty) {
        return version;
      }
    }

    return null;
  }

  String? _extractSwiftVersionFromBlock(String content, String sourceId) {
    final blockPattern = RegExp(
      '\\s*${RegExp.escape(sourceId)} /\\*[^*]*\\*/ = \\{(.*?)\\n\\s*\\};',
      dotAll: true,
    );
    final match = blockPattern.firstMatch(content);
    if (match == null) return null;

    final versionMatch = RegExp(r'\n\s*SWIFT_VERSION = ([^;]+);')
        .firstMatch(match.group(0)!);
    return versionMatch?.group(1)?.trim();
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
