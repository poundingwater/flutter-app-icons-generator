import 'dart:io';

import 'package:flutter_app_icons/src/config/config_model.dart';
import 'package:flutter_app_icons/src/config/yaml_config_parser.dart';
import 'package:flutter_app_icons/src/shared/constants.dart';
import 'package:flutter_app_icons/src/shared/exceptions.dart';
import 'package:test/test.dart';

void main() {
  late YamlConfigParser parser;
  late Directory tempDir;

  setUp(() {
    parser = const YamlConfigParser();
    tempDir = Directory.systemTemp.createTempSync('config_parser_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  /// Helper to write a YAML config file in the temp directory.
  void writeConfig(String content) {
    File('${tempDir.path}/flutter_app_icons.yml').writeAsStringSync(content);
  }

  group('YamlConfigParser', () {
    group('file handling', () {
      test('throws ConfigNotFoundException when file does not exist', () {
        expect(
          () => parser.parse(tempDir.path),
          throwsA(isA<ConfigNotFoundException>()),
        );
      });
    });

    group('YAML parsing', () {
      test('throws ConfigParseException for malformed YAML', () {
        writeConfig('icon: [invalid: yaml: content');
        expect(
          () => parser.parse(tempDir.path),
          throwsA(isA<ConfigParseException>()),
        );
      });

      test('throws ConfigParseException when root is not a map', () {
        writeConfig('- just\n- a\n- list');
        expect(
          () => parser.parse(tempDir.path),
          throwsA(isA<ConfigParseException>()),
        );
      });
    });

    group('icon config - combined image', () {
      test('parses combined image path', () async {
        writeConfig('''
icon:
  image: assets/icon.png
''');
        final config = await parser.parse(tempDir.path);
        expect(config.icon.imagePath, 'assets/icon.png');
        expect(config.icon.isAdaptive, isFalse);
      });

      test('has no foreground or background when using combined image',
          () async {
        writeConfig('''
icon:
  image: assets/icon.png
''');
        final config = await parser.parse(tempDir.path);
        expect(config.icon.foregroundPath, isNull);
        expect(config.icon.background, isNull);
      });
    });

    group('icon config - adaptive icon', () {
      test('parses foreground + hex color background', () async {
        writeConfig('''
icon:
  foreground: assets/foreground.png
  background: "#4CAF50"
''');
        final config = await parser.parse(tempDir.path);
        expect(config.icon.foregroundPath, 'assets/foreground.png');
        expect(config.icon.background, isA<BackgroundColor>());
        expect(
          (config.icon.background! as BackgroundColor).hexColor,
          '#4CAF50',
        );
        expect(config.icon.isAdaptive, isTrue);
      });

      test('parses foreground + image background', () async {
        writeConfig('''
icon:
  foreground: assets/foreground.png
  background: assets/background.png
''');
        final config = await parser.parse(tempDir.path);
        expect(config.icon.foregroundPath, 'assets/foreground.png');
        expect(config.icon.background, isA<BackgroundImage>());
        expect(
          (config.icon.background! as BackgroundImage).imagePath,
          'assets/background.png',
        );
      });
    });

    group('validation', () {
      test('throws ConfigValidationException when icon section is missing',
          () {
        writeConfig('splash:\n  image: assets/splash.png');
        expect(
          () => parser.parse(tempDir.path),
          throwsA(isA<ConfigValidationException>()),
        );
      });

      test(
          'throws ConfigValidationException when neither image nor '
          'foreground+background provided', () {
        writeConfig('''
icon:
  foreground: assets/foreground.png
''');
        expect(
          () => parser.parse(tempDir.path),
          throwsA(isA<ConfigValidationException>()),
        );
      });

      test(
          'throws ConfigValidationException when foreground present '
          'but no background', () {
        writeConfig('''
icon:
  foreground: assets/foreground.png
''');
        expect(
          () => parser.parse(tempDir.path),
          throwsA(isA<ConfigValidationException>()),
        );
      });
    });

    group('splash config', () {
      test('parses splash with image and background color', () async {
        writeConfig('''
icon:
  image: assets/icon.png
splash:
  image: assets/splash.png
  background_color: "#FFFFFF"
''');
        final config = await parser.parse(tempDir.path);
        expect(config.splash, isNotNull);
        expect(config.splash!.imagePath, 'assets/splash.png');
        expect(config.splash!.backgroundColor, '#FFFFFF');
      });

      test('parses splash without background color', () async {
        writeConfig('''
icon:
  image: assets/icon.png
splash:
  image: assets/splash.png
''');
        final config = await parser.parse(tempDir.path);
        expect(config.splash!.backgroundColor, isNull);
      });

      test('throws ConfigValidationException when splash.image is missing',
          () {
        writeConfig('''
icon:
  image: assets/icon.png
splash:
  background_color: "#FFFFFF"
''');
        expect(
          () => parser.parse(tempDir.path),
          throwsA(isA<ConfigValidationException>()),
        );
      });
    });

    group('platforms', () {
      test('defaults to all platforms when key is omitted', () async {
        writeConfig('''
icon:
  image: assets/icon.png
''');
        final config = await parser.parse(tempDir.path);
        expect(config.platforms, Platform.values.toSet());
        expect(config.platforms.length, 6);
      });

      test('parses a subset of platforms', () async {
        writeConfig('''
icon:
  image: assets/icon.png
platforms:
  - android
  - ios
''');
        final config = await parser.parse(tempDir.path);
        expect(config.platforms, {Platform.android, Platform.ios});
      });

      test('throws ConfigParseException for unknown platform', () {
        writeConfig('''
icon:
  image: assets/icon.png
platforms:
  - android
  - unknownPlatform
''');
        expect(
          () => parser.parse(tempDir.path),
          throwsA(isA<ConfigParseException>()),
        );
      });
    });

    group('full config', () {
      test('parses complete config with all sections', () async {
        writeConfig('''
icon:
  foreground: assets/foreground.png
  background: "#4CAF50"
splash:
  image: assets/splash.png
  background_color: "#FFFFFF"
platforms:
  - android
  - ios
  - web
''');
        final config = await parser.parse(tempDir.path);
        expect(config.icon.isAdaptive, isTrue);
        expect(config.splash, isNotNull);
        expect(config.platforms.length, 3);
        expect(
          config.platforms,
          {Platform.android, Platform.ios, Platform.web},
        );
      });
    });
  });
}
