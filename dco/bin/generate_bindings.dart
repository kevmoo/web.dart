#!/usr/bin/env dart

import 'dart:io';
import 'package:dco/src/generator.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> arguments) async {
  try {
    // Default paths
    final jsonPath = 'test_component.json';
    final outputPath = p.join('example', 'example.dart');

    await generateBindings(jsonPath, outputPath);
  } catch (e, stack) {
    print('Error: $e');
    print(stack);
    exitCode = 1;
  }
}
