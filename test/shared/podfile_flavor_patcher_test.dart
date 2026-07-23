import 'dart:io';

import 'package:flutter_app_icons_generator/src/shared/podfile/podfile_flavor_patcher.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('podfile_flavor_patcher_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('adds missing flavor build configuration mappings', () {
    final podfile = File('${tempDir.path}/Podfile');
    podfile.writeAsStringSync('''
platform :ios, '15.0'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}
''');

    PodfileFlavorPatcher().patch(podfile.path, {'dev', 'prod'});

    final updated = podfile.readAsStringSync();
    expect(updated, contains("'Debug-dev' => :debug,"));
    expect(updated, contains("'Profile-dev' => :release,"));
    expect(updated, contains("'Release-dev' => :release,"));
    expect(updated, contains("'Debug-prod' => :debug,"));
    expect(updated, contains("'Profile-prod' => :release,"));
    expect(updated, contains("'Release-prod' => :release,"));
  });

  test('is idempotent when mappings already exist', () {
    final podfile = File('${tempDir.path}/Podfile');
    podfile.writeAsStringSync('''
project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
  'Debug-dev' => :debug,
  'Profile-dev' => :release,
  'Release-dev' => :release,
}
''');

    final patcher = PodfileFlavorPatcher();
    patcher.patch(podfile.path, {'dev'});
    final firstPass = podfile.readAsStringSync();

    patcher.patch(podfile.path, {'dev'});
    final secondPass = podfile.readAsStringSync();

    expect(secondPass, equals(firstPass));
  });
}