// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:path/path.dart' as p;

/// Derives the `.loader.mjs` and `.loader.d.ts` output paths and the relative
/// `.d.ts` basename from [dtsOutputPath] (e.g. `dist/bridge.d.ts` ->
/// `dist/bridge.loader.mjs` and `dist/bridge.loader.d.ts`).
({String mjsPath, String dtsPath, String dtsBasename}) deriveLoaderPaths(
  String dtsOutputPath,
) {
  final String base;
  if (dtsOutputPath.endsWith('.d.ts')) {
    base = dtsOutputPath.substring(0, dtsOutputPath.length - '.d.ts'.length);
  } else if (dtsOutputPath.endsWith('.ts')) {
    base = dtsOutputPath.substring(0, dtsOutputPath.length - '.ts'.length);
  } else {
    base = dtsOutputPath;
  }
  return (
    mjsPath: '$base.loader.mjs',
    dtsPath: '$base.loader.d.ts',
    dtsBasename: p.basename(dtsOutputPath),
  );
}

/// Generates a TypeScript `.loader.d.ts` declaration file for the ESM bridge
/// loader from the decoded `.interop.json` [ir] Map.
String generateLoaderDtsFromInteropIr(
  Map<String, Object?> ir, {
  required String dtsBasename,
  String? globalNameOverride,
}) {
  final globalName = _resolveGlobalName(
    ir,
    globalNameOverride: globalNameOverride,
  );
  final rootClass = _resolveRootClassName(ir);
  final cleanBasename = dtsBasename.startsWith('./')
      ? dtsBasename.substring(2)
      : dtsBasename;

  final buf = StringBuffer()
    ..writeln('// Generated from Dart JS interop IR by package:js_interop_gen.')
    ..writeln('// Do not edit by hand.')
    ..writeln();

  if (rootClass != null) {
    final importedTypes = rootClass == 'DartBridgeApi'
        ? 'DartBridgeApi'
        : '$rootClass, DartBridgeApi';
    buf
      ..writeln("import type { $importedTypes } from './$cleanBasename';")
      ..writeln('export type { $importedTypes };')
      ..writeln();
  }

  final returnType = rootClass ?? 'unknown';

  buf
    ..writeln('export interface DartWasmMjsModule {')
    ..writeln('  compile(bytes: BufferSource): Promise<DartWasmCompiledApp>;')
    ..writeln(
      '  compileStreaming?('
      'response: Response | PromiseLike<Response>'
      '): Promise<DartWasmCompiledApp>;',
    )
    ..writeln('}')
    ..writeln()
    ..writeln('export interface DartWasmCompiledApp {')
    ..writeln(
      '  instantiate('
      'imports?: WebAssembly.Imports'
      '): Promise<DartWasmInstance>;',
    )
    ..writeln('}')
    ..writeln()
    ..writeln('export interface DartWasmInstance {')
    ..writeln('  invokeMain(...args: unknown[]): void;')
    ..writeln('}')
    ..writeln()
    ..writeln(
      '/** Compiles, instantiates, and initializes the dart2wasm module '
      'and returns `globalThis.$globalName`. */',
    )
    ..writeln('export function instantiateWasmBridge(')
    ..writeln('  mjsModule: DartWasmMjsModule,')
    ..writeln('  wasmSource: BufferSource | Response | PromiseLike<Response>,')
    ..writeln('  imports?: WebAssembly.Imports,')
    ..writeln('): Promise<$returnType>;')
    ..writeln()
    ..writeln(
      '/** Ensures `globalThis.self` is initialized, optionally evaluates '
      'the dart2js bundle, and returns `globalThis.$globalName`. */',
    )
    ..writeln('export function resolveJsBridge(')
    ..writeln('  evaluateJs?: () => void | PromiseLike<void>,')
    ..writeln('): Promise<$returnType>;');

  return buf.toString();
}

/// Generates an environment-agnostic `.loader.mjs` ESM module implementing
/// `instantiateWasmBridge` and `resolveJsBridge` from the decoded
/// `.interop.json` [ir] Map.
String generateLoaderMjsFromInteropIr(
  Map<String, Object?> ir, {
  required String dtsBasename,
  String? globalNameOverride,
}) {
  final globalName = _resolveGlobalName(
    ir,
    globalNameOverride: globalNameOverride,
  );
  final encodedGlobalName = jsonEncode(globalName);

  final buf = StringBuffer()
    ..writeln('// Generated from Dart JS interop IR by package:js_interop_gen.')
    ..writeln('// Do not edit by hand.')
    ..writeln('// Companion declarations: $dtsBasename')
    ..writeln()
    ..writeln('const GLOBAL_NAME = $encodedGlobalName;')
    ..writeln()
    ..writeln('function _readGlobalBridge() {')
    ..writeln('  const bridge = globalThis[GLOBAL_NAME];')
    ..writeln('  if (bridge === undefined || bridge === null) {')
    ..writeln('    throw new Error(')
    ..writeln(
      r'      `Dart JS interop bridge globalThis.${GLOBAL_NAME} was not '
      r'registered after module initialization.`,',
    )
    ..writeln('    );')
    ..writeln('  }')
    ..writeln('  return bridge;')
    ..writeln('}')
    ..writeln()
    ..writeln(
      'export async function instantiateWasmBridge('
      'mjsModule, wasmSource, imports) {',
    )
    ..writeln('  globalThis.self ??= globalThis;')
    ..writeln('  const isResponseOrPromise =')
    ..writeln(
      "    (typeof Response !== 'undefined' && "
      'wasmSource instanceof Response) ||',
    )
    ..writeln("    typeof wasmSource?.then === 'function';")
    ..writeln('  let compiledApp;')
    ..writeln(
      '  if (isResponseOrPromise && '
      "typeof mjsModule.compileStreaming === 'function') {",
    )
    ..writeln('    compiledApp = await mjsModule.compileStreaming(wasmSource);')
    ..writeln('  } else {')
    ..writeln('    const resolved = await wasmSource;')
    ..writeln('    const bytes =')
    ..writeln(
      "      typeof Response !== 'undefined' && resolved instanceof Response",
    )
    ..writeln('        ? await resolved.arrayBuffer()')
    ..writeln('        : resolved;')
    ..writeln('    compiledApp = await mjsModule.compile(bytes);')
    ..writeln('  }')
    ..writeln(
      '  const instance = await compiledApp.instantiate(imports ?? {});',
    )
    ..writeln('  instance.invokeMain();')
    ..writeln('  return _readGlobalBridge();')
    ..writeln('}')
    ..writeln()
    ..writeln('export async function resolveJsBridge(evaluateJs) {')
    ..writeln('  globalThis.self ??= globalThis;')
    ..writeln("  if (typeof evaluateJs === 'function') {")
    ..writeln('    await evaluateJs();')
    ..writeln('  }')
    ..writeln('  return _readGlobalBridge();')
    ..writeln('}');

  return buf.toString();
}

String _resolveGlobalName(
  Map<String, Object?> ir, {
  String? globalNameOverride,
}) {
  if (globalNameOverride != null && globalNameOverride.isNotEmpty) {
    return globalNameOverride;
  }
  final rawGlobals = ir['rootExports'] ?? ir['globalExports'];
  if (rawGlobals is List<Object?> && rawGlobals.isNotEmpty) {
    final first = rawGlobals.first;
    if (first is Map<Object?, Object?>) {
      final candidate =
          (first['globalName'] ?? first['globalProperty'] ?? first['name'])
              as String?;
      if (candidate != null && candidate.isNotEmpty) {
        return candidate;
      }
    }
  }
  return '__dartBridge';
}

String? _resolveRootClassName(Map<String, Object?> ir) {
  final rawGlobals = ir['rootExports'] ?? ir['globalExports'];
  final exportsList = ir['exports'];
  if (rawGlobals is List<Object?> && rawGlobals.isNotEmpty) {
    final first = rawGlobals.first;
    if (first is Map<Object?, Object?>) {
      final directJs = (first['jsName'] ?? first['interfaceName']) as String?;
      if (directJs != null && directJs.isNotEmpty) {
        return directJs;
      }
      final dartClass =
          (first['dartClass'] ?? first['exportedClass']) as String?;
      if (dartClass != null &&
          dartClass.isNotEmpty &&
          exportsList is List<Object?>) {
        for (final exp in exportsList) {
          if (exp is Map<Object?, Object?> &&
              (exp['dartClass'] == dartClass ||
                  exp['id'] == dartClass ||
                  exp['dartName'] == dartClass)) {
            final jsName = (exp['jsName'] ?? exp['name']) as String?;
            if (jsName != null && jsName.isNotEmpty) return jsName;
          }
        }
        return dartClass.split('::').last;
      }
    }
  }
  if (exportsList is List<Object?> && exportsList.isNotEmpty) {
    final first = exportsList.first;
    if (first is Map<Object?, Object?>) {
      return (first['jsName'] ?? first['name'] ?? first['dartName']) as String?;
    }
  }
  return null;
}
