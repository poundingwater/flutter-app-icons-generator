import 'dart:convert';
import 'dart:io';

import 'package:flutter_app_icons/src/core/platform_updater.dart';

/// Updates web platform configuration files to reference generated icon assets.
///
/// This updater modifies:
/// - `web/manifest.json`: Sets the `icons` array with PWA icon entries
/// - `web/index.html`: Ensures a `<link rel="icon">` tag references `favicon.png`
class WebUpdater implements PlatformUpdater {
  @override
  Future<void> update(String projectRoot) async {
    _updateManifestJson(projectRoot);
    _updateIndexHtml(projectRoot);
  }

  /// Updates `web/manifest.json` with the icon entries for PWA support.
  ///
  /// If the file exists, parses it and replaces the `icons` array.
  /// If the file doesn't exist, creates it with basic fields and the icons array.
  void _updateManifestJson(String projectRoot) {
    final manifestFile = File('$projectRoot/web/manifest.json');

    Map<String, dynamic> manifest;

    if (manifestFile.existsSync()) {
      final content = manifestFile.readAsStringSync();
      manifest = jsonDecode(content) as Map<String, dynamic>;
    } else {
      // Create directory if needed and start with basic fields.
      final webDir = Directory('$projectRoot/web');
      if (!webDir.existsSync()) {
        webDir.createSync(recursive: true);
      }
      manifest = <String, dynamic>{
        'name': '',
        'short_name': '',
        'start_url': '.',
        'display': 'standalone',
        'background_color': '#ffffff',
        'theme_color': '#ffffff',
      };
    }

    // Set/replace the icons array with standard PWA icon entries.
    manifest['icons'] = <Map<String, dynamic>>[
      {
        'src': 'icons/Icon-192.png',
        'sizes': '192x192',
        'type': 'image/png',
      },
      {
        'src': 'icons/Icon-512.png',
        'sizes': '512x512',
        'type': 'image/png',
      },
      {
        'src': 'icons/Icon-maskable-192.png',
        'sizes': '192x192',
        'type': 'image/png',
        'purpose': 'maskable',
      },
      {
        'src': 'icons/Icon-maskable-512.png',
        'sizes': '512x512',
        'type': 'image/png',
        'purpose': 'maskable',
      },
    ];

    // Write back pretty-printed JSON.
    const encoder = JsonEncoder.withIndent('    ');
    manifestFile.writeAsStringSync('${encoder.convert(manifest)}\n');
  }

  /// Updates `web/index.html` to include a `<link rel="icon">` tag
  /// pointing to `favicon.png`.
  ///
  /// If an existing `<link rel="icon"` tag is found, replaces its href.
  /// If not present, adds the tag inside the `<head>` section.
  /// If the file doesn't exist, skips the update.
  void _updateIndexHtml(String projectRoot) {
    final indexFile = File('$projectRoot/web/index.html');

    if (!indexFile.existsSync()) {
      return;
    }

    var content = indexFile.readAsStringSync();

    // Regex to match existing <link rel="icon" ...> tags.
    final iconLinkRegex = RegExp(
      r'<link\s+[^>]*rel="icon"[^>]*/?>',
      caseSensitive: false,
    );

    if (iconLinkRegex.hasMatch(content)) {
      // Replace the existing tag's href with favicon.png.
      content = content.replaceAll(
        iconLinkRegex,
        '<link rel="icon" type="image/png" href="favicon.png"/>',
      );
    } else {
      // Insert the link tag inside <head>.
      final headRegex = RegExp(r'<head[^>]*>', caseSensitive: false);
      final headMatch = headRegex.firstMatch(content);

      if (headMatch != null) {
        final insertPosition = headMatch.end;
        content = '${content.substring(0, insertPosition)}\n'
            '  <link rel="icon" type="image/png" href="favicon.png"/>'
            '${content.substring(insertPosition)}';
      }
    }

    indexFile.writeAsStringSync(content);
  }
}
