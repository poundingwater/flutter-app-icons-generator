import 'dart:convert';
import 'dart:io';

import 'package:flutter_app_icons_generator/src/platforms/web/web_updater.dart';
import 'package:test/test.dart';

void main() {
  late WebUpdater updater;
  late Directory tempDir;

  setUp(() {
    updater = WebUpdater();
    tempDir = Directory.systemTemp.createTempSync('web_updater_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('WebUpdater - manifest.json', () {
    test('updates existing manifest.json with icons array', () async {
      final webDir = Directory('${tempDir.path}/web');
      webDir.createSync(recursive: true);

      final manifestFile = File('${webDir.path}/manifest.json');
      manifestFile.writeAsStringSync(jsonEncode({
        'name': 'My App',
        'short_name': 'MyApp',
        'start_url': '.',
        'display': 'standalone',
        'background_color': '#0175C2',
        'theme_color': '#0175C2',
        'icons': [
          {'src': 'old-icon.png', 'sizes': '64x64', 'type': 'image/png'},
        ],
      }));

      await updater.update(tempDir.path);

      final updatedContent = manifestFile.readAsStringSync();
      final updatedManifest =
          jsonDecode(updatedContent) as Map<String, dynamic>;

      // Existing fields should be preserved.
      expect(updatedManifest['name'], equals('My App'));
      expect(updatedManifest['short_name'], equals('MyApp'));

      // Icons array should be replaced.
      final icons = updatedManifest['icons'] as List<dynamic>;
      expect(icons.length, equals(4));

      expect(icons[0]['src'], equals('icons/Icon-192.png'));
      expect(icons[0]['sizes'], equals('192x192'));
      expect(icons[0]['type'], equals('image/png'));

      expect(icons[1]['src'], equals('icons/Icon-512.png'));
      expect(icons[1]['sizes'], equals('512x512'));
      expect(icons[1]['type'], equals('image/png'));

      expect(icons[2]['src'], equals('icons/Icon-maskable-192.png'));
      expect(icons[2]['sizes'], equals('192x192'));
      expect(icons[2]['type'], equals('image/png'));
      expect(icons[2]['purpose'], equals('maskable'));

      expect(icons[3]['src'], equals('icons/Icon-maskable-512.png'));
      expect(icons[3]['sizes'], equals('512x512'));
      expect(icons[3]['type'], equals('image/png'));
      expect(icons[3]['purpose'], equals('maskable'));
    });

    test('creates manifest.json if it does not exist', () async {
      final webDir = Directory('${tempDir.path}/web');
      webDir.createSync(recursive: true);

      await updater.update(tempDir.path);

      final manifestFile = File('${webDir.path}/manifest.json');
      expect(manifestFile.existsSync(), isTrue);

      final content =
          jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;

      expect(content['icons'], isNotNull);
      final icons = content['icons'] as List<dynamic>;
      expect(icons.length, equals(4));

      // Basic fields should exist.
      expect(content['name'], isNotNull);
      expect(content['display'], equals('standalone'));
    });

    test('creates web directory and manifest.json if neither exist', () async {
      await updater.update(tempDir.path);

      final manifestFile = File('${tempDir.path}/web/manifest.json');
      expect(manifestFile.existsSync(), isTrue);
    });

    test('produces pretty-printed JSON output', () async {
      final webDir = Directory('${tempDir.path}/web');
      webDir.createSync(recursive: true);

      await updater.update(tempDir.path);

      final manifestFile = File('${webDir.path}/manifest.json');
      final content = manifestFile.readAsStringSync();

      // Pretty-printed JSON should contain indentation.
      expect(content, contains('    '));
      // Should end with newline.
      expect(content.endsWith('\n'), isTrue);
    });
  });

  group('WebUpdater - index.html', () {
    test('replaces existing link rel="icon" tag', () async {
      final webDir = Directory('${tempDir.path}/web');
      webDir.createSync(recursive: true);

      final indexFile = File('${webDir.path}/index.html');
      indexFile.writeAsStringSync('''<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <link rel="icon" type="image/png" href="icons/old-favicon.png"/>
  <title>My App</title>
</head>
<body></body>
</html>
''');

      await updater.update(tempDir.path);

      final updatedContent = indexFile.readAsStringSync();
      expect(
        updatedContent,
        contains('<link rel="icon" type="image/png" href="favicon.png"/>'),
      );
      expect(updatedContent, isNot(contains('old-favicon.png')));
    });

    test('adds link rel="icon" tag if not present', () async {
      final webDir = Directory('${tempDir.path}/web');
      webDir.createSync(recursive: true);

      final indexFile = File('${webDir.path}/index.html');
      indexFile.writeAsStringSync('''<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>My App</title>
</head>
<body></body>
</html>
''');

      await updater.update(tempDir.path);

      final updatedContent = indexFile.readAsStringSync();
      expect(
        updatedContent,
        contains('<link rel="icon" type="image/png" href="favicon.png"/>'),
      );
    });

    test('skips index.html update if file does not exist', () async {
      final webDir = Directory('${tempDir.path}/web');
      webDir.createSync(recursive: true);

      // Only create manifest, no index.html.
      await updater.update(tempDir.path);

      final indexFile = File('${webDir.path}/index.html');
      expect(indexFile.existsSync(), isFalse);
    });

    test('handles self-closing link tag', () async {
      final webDir = Directory('${tempDir.path}/web');
      webDir.createSync(recursive: true);

      final indexFile = File('${webDir.path}/index.html');
      indexFile.writeAsStringSync('''<!DOCTYPE html>
<html>
<head>
  <link rel="icon" href="old.ico">
</head>
<body></body>
</html>
''');

      await updater.update(tempDir.path);

      final updatedContent = indexFile.readAsStringSync();
      expect(
        updatedContent,
        contains('<link rel="icon" type="image/png" href="favicon.png"/>'),
      );
      expect(updatedContent, isNot(contains('old.ico')));
    });
  });
}
