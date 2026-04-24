#!/usr/bin/env dart

import 'dart:io';
import 'package:dco/src/generator.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> arguments) async {
  try {
    // Default paths
    const jsonPath = 'test_component.json';

    final outputPath = p.join('example', 'example.dart');

    final source = generateBindings(jsonPath);
    final outputFile = File(outputPath);
    final outputDir = outputFile.parent;
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }
    outputFile.writeAsStringSync(source);
    print('Generated and formatted ${outputFile.path}');
  } catch (e, stack) {
    print('Error: $e');
    print(stack);
    exitCode = 1;
  }
}
