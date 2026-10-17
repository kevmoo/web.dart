// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:io/io.dart';
import 'package:js_interop_gen/src/interop_ir/dts_emitter.dart';
import 'package:js_interop_gen/src/interop_ir/interop_ir_exporter.dart';
import 'package:js_interop_gen/src/interop_ir/interop_ir_schema.dart';
import 'package:js_interop_gen/src/interop_ir/loader_emitter.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> arguments) async {
  final ArgResults argResult;
  try {
    argResult = _parser.parse(arguments);
  } on FormatException catch (e) {
    stderr
      ..writeln(e.message)
      ..writeln()
      ..writeln(_usage);
    exitCode = ExitCode.usage.code;
    return;
  }

  if (argResult.flag('help')) {
    stdout.writeln(_usage);
    return;
  }

  final inputOption = argResult.option('input');
  final fromIrOption = argResult.option('from-ir');
  final emitIrOption = argResult.option('emit-ir');
  final outputOption = argResult.option('output');
  final globalNameOverride = argResult.option('global-name');
  final emitLoader = argResult.flag('emit-loader');
  final toStdout = argResult.flag('stdout');

  final inputPath =
      inputOption ?? (argResult.rest.isNotEmpty ? argResult.rest.first : null);

  if (inputPath == null && fromIrOption == null) {
    stderr
      ..writeln('Specify either --input=<file.dart> or --from-ir=<file.json>.')
      ..writeln()
      ..writeln(_usage);
    exitCode = ExitCode.usage.code;
    return;
  }

  Map<String, Object?> ir;
  if (fromIrOption != null) {
    final irFile = File(p.normalize(p.absolute(fromIrOption)));
    if (!irFile.existsSync()) {
      stderr.writeln('Input IR file does not exist: ${irFile.path}');
      exitCode = ExitCode.noInput.code;
      return;
    }
    final rawDecoded = jsonDecode(irFile.readAsStringSync());
    ir = asIrStringMap(rawDecoded);
    validateInteropIr(ir);
  } else {
    final resolvedInput = p.normalize(p.absolute(inputPath!));
    if (!File(resolvedInput).existsSync()) {
      stderr.writeln('Input Dart file does not exist: $resolvedInput');
      exitCode = ExitCode.noInput.code;
      return;
    }
    final rawIr = await extractInteropIr(resolvedInput);
    final jsonString = '${const JsonEncoder.withIndent('  ').convert(rawIr)}\n';
    if (emitIrOption != null) {
      final irOutFile = File(p.normalize(p.absolute(emitIrOption)));
      irOutFile.parent.createSync(recursive: true);
      irOutFile.writeAsStringSync(jsonString);
    }
    ir = asIrStringMap(jsonDecode(jsonString));
  }

  final dtsString = generateDtsFromInteropIr(
    ir,
    globalNameOverride: globalNameOverride,
  );

  if (toStdout && outputOption == null) {
    stdout.write(dtsString);
    return;
  }

  final resolvedOutput = _resolveOutputPath(
    outputOption: outputOption,
    inputPath: inputPath,
    fromIrPath: fromIrOption,
  );
  final outFile = File(resolvedOutput);
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(dtsString);

  if (emitLoader) {
    final loaderPaths = deriveLoaderPaths(resolvedOutput);
    final loaderMjs = generateLoaderMjsFromInteropIr(
      ir,
      dtsBasename: loaderPaths.dtsBasename,
      globalNameOverride: globalNameOverride,
    );
    final loaderDts = generateLoaderDtsFromInteropIr(
      ir,
      dtsBasename: loaderPaths.dtsBasename,
      globalNameOverride: globalNameOverride,
    );
    File(loaderPaths.mjsPath).writeAsStringSync(loaderMjs);
    File(loaderPaths.dtsPath).writeAsStringSync(loaderDts);
  }
}

String _resolveOutputPath({
  required String? outputOption,
  required String? inputPath,
  required String? fromIrPath,
}) {
  if (outputOption != null && outputOption.isNotEmpty) {
    return p.normalize(p.absolute(outputOption));
  }
  if (inputPath != null) {
    final abs = p.normalize(p.absolute(inputPath));
    if (abs.endsWith('.dart')) {
      return '${abs.substring(0, abs.length - '.dart'.length)}.d.ts';
    }
    return '$abs.d.ts';
  }
  final absIr = p.normalize(p.absolute(fromIrPath!));
  if (absIr.endsWith('.interop.json')) {
    return '${absIr.substring(0, absIr.length - '.interop.json'.length)}.d.ts';
  }
  if (absIr.endsWith('.json')) {
    return '${absIr.substring(0, absIr.length - '.json'.length)}.d.ts';
  }
  return '$absIr.d.ts';
}

final _usage = '''
Generate TypeScript .d.ts declarations and ESM loader glue from Dart @JSExport libraries.

Usage:
  dart run js_interop_gen:dart_to_dts -i <lib/bridge.dart> -o <dist/bridge.d.ts> [options]

Options:
${_parser.usage}''';

final _parser = ArgParser()
  ..addOption(
    'input',
    abbr: 'i',
    valueHelp: 'file.dart',
    help: 'Entry Dart library path containing @JSExport classes.',
  )
  ..addOption(
    'output',
    abbr: 'o',
    valueHelp: 'file.d.ts',
    help:
        'Output TypeScript declaration (.d.ts) path '
        '(defaults to <input_without_dart>.d.ts).',
  )
  ..addOption(
    'emit-ir',
    valueHelp: 'file.interop.json',
    help: 'Optional path to write the Stage 1 JSON IR sidecar.',
  )
  ..addOption(
    'from-ir',
    valueHelp: 'file.interop.json',
    help:
        'Skip Stage 1 (package:analyzer) and generate .d.ts purely from an '
        'existing .interop.json file.',
  )
  ..addFlag(
    'emit-loader',
    negatable: false,
    help:
        'Emit <base>.loader.mjs and <base>.loader.d.ts alongside <base>.d.ts.',
  )
  ..addOption(
    'global-name',
    valueHelp: 'name',
    help: 'Override the globalThis.<name> export property name.',
  )
  ..addFlag(
    'stdout',
    negatable: false,
    help: 'Write the generated .d.ts declarations to stdout.',
  )
  ..addFlag(
    'help',
    abbr: 'h',
    negatable: false,
    help: 'Print this usage information.',
  );
