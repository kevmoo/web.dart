// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:js_interop_gen/src/interop_ir/dts_emitter.dart';
import 'package:js_interop_gen/src/interop_ir/interop_ir_exporter.dart';
import 'package:js_interop_gen/src/interop_ir/interop_ir_schema.dart';
import 'package:js_interop_gen/src/interop_ir/loader_emitter.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  final pkgRoot = Directory.current.path;
  final tscPath = p.join(
    pkgRoot,
    'lib',
    'src',
    'node_modules',
    '.bin',
    Platform.isWindows ? 'tsc.cmd' : 'tsc',
  );

  Future<void> verifyWithTsc(List<String> files) async {
    final result = await Process.run(tscPath, <String>[
      '--noEmit',
      '--strict',
      '--target',
      'ES2022',
      '--module',
      'ES2022',
      '--moduleResolution',
      'bundler',
      ...files,
    ]);
    expect(
      result.exitCode,
      0,
      reason:
          'tsc --noEmit --strict failed:\n'
          'STDOUT:\n${result.stdout}\n'
          'STDERR:\n${result.stderr}',
    );
  }

  group('Stage 2 (Pure JSON Sidecar -> .d.ts & .loader.{mjs,d.ts})', () {
    final syntheticIr = <String, Object?>{
      'schemaVersion': 1,
      'version': '1.0.0',
      'rootExports': <Object?>[
        <String, Object?>{
          'globalName': '__testDartBridge',
          'globalProperty': '__testDartBridge',
          'dartClass': 'pkg::TestBridge',
          'jsName': 'TestBridge',
        },
      ],
      'exports': <Object?>[
        <String, Object?>{
          'dartClass': 'pkg::TestBridge',
          'dartName': 'TestBridge',
          'jsName': 'TestBridge',
          'docComment': 'Primary test bridge.',
          'members': <Object?>[
            <String, Object?>{
              'kind': 'method',
              'dartName': 'compute',
              'jsName': 'compute',
              'positionalParams': <Object?>[
                <String, Object?>{
                  'name': 'input',
                  'required': true,
                  'type': <String, Object?>{
                    'kind': 'extensionType',
                    'name': 'InputConfigJS',
                    'nullable': false,
                  },
                },
                <String, Object?>{
                  'name': 'onChange',
                  'required': false,
                  'type': <String, Object?>{
                    'kind': 'extensionType',
                    'name': 'OnChangeJS',
                    'nullable': true,
                  },
                },
              ],
              'returnType': <String, Object?>{
                'kind': 'extensionType',
                'name': 'ReturnOnlyLiteralJS',
                'nullable': false,
              },
            },
            <String, Object?>{
              'kind': 'method',
              'dartName': 'openSession',
              'jsName': 'openSession',
              'positionalParams': <Object?>[],
              'returnType': <String, Object?>{
                'kind': 'extensionType',
                'name': 'SessionRef',
                'nullable': false,
              },
            },
          ],
        },
      ],
      'extensionTypes': <String, Object?>{
        'pkg::InputConfigJS': <String, Object?>{
          'id': 'pkg::InputConfigJS',
          'name': 'InputConfigJS',
          'representationType': <String, Object?>{
            'kind': 'jsBuiltin',
            'name': 'JSObject',
          },
          'typeParameters': <Object?>[],
          'implements': <Object?>['JSObject'],
          'properties': <Object?>[
            <String, Object?>{
              'dartName': 'label',
              'jsName': 'label',
              'readonly': true,
              'hasSetter': false,
              'type': <String, Object?>{
                'kind': 'primitive',
                'name': 'String',
                'nullable': true,
              },
            },
            <String, Object?>{
              'dartName': 'totalTaxes',
              'jsName': 'total_taxes',
              'readonly': false,
              'hasSetter': true,
              'type': <String, Object?>{
                'kind': 'primitive',
                'name': 'double',
                'nullable': true,
              },
              'setterType': <String, Object?>{
                'kind': 'primitive',
                'name': 'double',
                'nullable': false,
              },
            },
          ],
          'literalFactoryParams': <Object?>[],
        },
        'pkg::ReturnOnlyLiteralJS': <String, Object?>{
          'id': 'pkg::ReturnOnlyLiteralJS',
          'name': 'ReturnOnlyLiteralJS',
          'representationType': <String, Object?>{
            'kind': 'jsBuiltin',
            'name': 'JSObject',
          },
          'typeParameters': <Object?>[],
          'implements': <Object?>['JSObject'],
          'properties': <Object?>[],
          'literalFactoryParams': <Object?>[
            <String, Object?>{
              'dartName': 'net',
              'jsName': 'net',
              'required': true,
              'type': <String, Object?>{
                'kind': 'primitive',
                'name': 'double',
                'nullable': false,
              },
            },
            <String, Object?>{
              'dartName': 'taxId',
              'jsName': 'tax_id',
              'required': false,
              'type': <String, Object?>{
                'kind': 'primitive',
                'name': 'String',
                'nullable': true,
              },
            },
          ],
        },
        'pkg::OnChangeJS': <String, Object?>{
          'id': 'pkg::OnChangeJS',
          'name': 'OnChangeJS',
          'representationType': <String, Object?>{
            'kind': 'jsBuiltin',
            'name': 'JSFunction',
          },
          'typeParameters': <Object?>[],
          'implements': <Object?>['JSFunction'],
          'properties': <Object?>[],
          'literalFactoryParams': <Object?>[],
          'callSignature': <String, Object?>{
            'positionalParams': <Object?>[
              <String, Object?>{
                'name': 'count',
                'required': true,
                'type': <String, Object?>{
                  'kind': 'primitive',
                  'name': 'int',
                  'nullable': false,
                },
              },
            ],
            'returnType': <String, Object?>{
              'kind': 'primitive',
              'name': 'void',
              'nullable': false,
            },
          },
        },
        'pkg::SessionRef': <String, Object?>{
          'id': 'pkg::SessionRef',
          'name': 'SessionRef',
          'representationType': <String, Object?>{
            'kind': 'externalDartRef',
            'dartType': 'ReportSession',
          },
          'typeParameters': <Object?>[],
          'implements': <Object?>[],
          'properties': <Object?>[],
          'literalFactoryParams': <Object?>[],
        },
      },
    };

    test(
      'handles all 4 interop traps and passes tsc --noEmit --strict',
      () async {
        expect(isValidInteropIr(syntheticIr), isTrue);
        final dts = generateDtsFromInteropIr(syntheticIr);

        // Trap 1: Return-only literal factory params become fields.
        expect(
          dts,
          contains(
            'export interface ReturnOnlyLiteralJS {\n'
            '  net: number;\n'
            '  tax_id?: string;\n'
            '}',
          ),
        );
        // Trap 2: Mutable setter omits `| null` while readonly keeps `| null`.
        expect(
          dts,
          contains(
            'export interface InputConfigJS {\n'
            '  readonly label?: string | null;\n'
            '  total_taxes?: number;\n'
            '}',
          ),
        );
        // Trap 3: Typed JSFunction closure extension type.
        expect(
          dts,
          contains('export type OnChangeJS = (count: number) => void;'),
        );
        // Trap 4: Branded unique symbol for ExternalDartReference<T>.
        expect(
          dts,
          contains('declare const __SessionRefBrand: unique symbol;'),
        );
        expect(
          dts,
          contains(
            'export type SessionRef = '
            '{ readonly [__SessionRefBrand]: "ReportSession" };',
          ),
        );
        expect(dts, contains('var __testDartBridge: TestBridge | undefined;'));

        final loaderDts = generateLoaderDtsFromInteropIr(
          syntheticIr,
          dtsBasename: 'bridge.d.ts',
        );
        final loaderMjs = generateLoaderMjsFromInteropIr(
          syntheticIr,
          dtsBasename: 'bridge.d.ts',
        );

        expect(
          loaderDts,
          contains(
            "import type { TestBridge, DartBridgeApi } from './bridge.d.ts';",
          ),
        );
        expect(loaderDts, contains('export function instantiateWasmBridge('));
        expect(loaderDts, contains('): Promise<TestBridge>;'));
        expect(loaderDts, contains('export function resolveJsBridge('));
        expect(loaderMjs, contains('const GLOBAL_NAME = "__testDartBridge";'));
        expect(loaderMjs, contains('globalThis.self ??= globalThis;'));
        expect(loaderMjs, contains('mjsModule.compileStreaming(wasmSource)'));
        expect(loaderMjs, contains('instance.invokeMain();'));

        final tempDir = Directory.systemTemp.createTempSync(
          'dart_to_dts_stage2_',
        );
        try {
          final dtsFile = File(p.join(tempDir.path, 'bridge.d.ts'))
            ..writeAsStringSync(dts);
          File(
            p.join(tempDir.path, 'bridge.loader.mjs'),
          ).writeAsStringSync(loaderMjs);
          final loaderDtsFile = File(p.join(tempDir.path, 'bridge.loader.d.ts'))
            ..writeAsStringSync(loaderDts);
          final consumerTsFile = File(p.join(tempDir.path, 'consumer.ts'))
            ..writeAsStringSync('''
import type { InputConfigJS, SessionRef } from './bridge.d.ts';
import { instantiateWasmBridge, resolveJsBridge } from './bridge.loader';

export async function run(mjs: any, wasm: Response) {
  const bridge = await instantiateWasmBridge(mjs, wasm);
  const jsBridge = await resolveJsBridge();
  const cfg: InputConfigJS = { label: null, total_taxes: 42 };
  const res = bridge.compute(cfg, (count) => {
    const c: number = count;
    void c;
  });
  const netVal: number = res.net;
  const session: SessionRef = jsBridge.openSession();
  return { netVal, session };
}
''');
          await verifyWithTsc(<String>[
            dtsFile.path,
            loaderDtsFile.path,
            consumerTsFile.path,
          ]);
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      },
    );
  });

  group('Stage 1 + Stage 2 + CLI Integration', () {
    test(
      'bin/dart_to_dts.dart extracts IR, emits .d.ts and loader, and passes tsc',
      () async {
        final tempDir = Directory.systemTemp.createTempSync('dart_to_dts_cli_');
        try {
          final dartFile = File(p.join(tempDir.path, 'mini_bridge.dart'))
            ..writeAsStringSync('''
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

class EngineSession {}

extension type EngineSessionRef._(ExternalDartReference<EngineSession> _)
    implements ExternalDartReference<EngineSession> {}

extension type QueryInputJS._(JSObject _) implements JSObject {
  external String get query;
  @JS('max_rows')
  external int? get maxRows;
  @JS('max_rows')
  external set maxRows(int? value);
}

extension type QueryOutputJS._(JSObject _) implements JSObject {
  external factory QueryOutputJS({
    required int totalCount,
    String? nextCursor,
  });
}

extension type RowCallbackJS._(JSFunction _) implements JSFunction {
  external void call(int rowIndex, String value);
}

@JSExport()
class MiniBridge {
  EngineSessionRef createSession() =>
      EngineSession()
          .toExternalReference as EngineSessionRef;

  QueryOutputJS runQuery(
    EngineSessionRef session,
    QueryInputJS input, [
    RowCallbackJS? onRow,
  ]) => QueryOutputJS(totalCount: 1);
}

void main() {
  final wrapper = createJSInteropWrapper<MiniBridge>(MiniBridge());
  globalContext.setProperty('__miniBridge'.toJS, wrapper);
}
''');

          final outDts = p.join(tempDir.path, 'dist', 'mini_bridge.d.ts');
          final outIr = p.join(
            tempDir.path,
            'dist',
            'mini_bridge.interop.json',
          );
          final cliScript = p.join(pkgRoot, 'bin', 'dart_to_dts.dart');

          // 1. Run CLI with -i, -o, --emit-ir, --emit-loader.
          final run1 = await Process.run(Platform.resolvedExecutable, <String>[
            cliScript,
            '-i',
            dartFile.path,
            '-o',
            outDts,
            '--emit-ir',
            outIr,
            '--emit-loader',
          ], workingDirectory: pkgRoot);
          expect(run1.exitCode, 0, reason: 'STDERR: ${run1.stderr}');

          final loaderPaths = deriveLoaderPaths(outDts);
          expect(File(outDts).existsSync(), isTrue);
          expect(File(outIr).existsSync(), isTrue);
          expect(File(loaderPaths.mjsPath).existsSync(), isTrue);
          expect(File(loaderPaths.dtsPath).existsSync(), isTrue);

          final dtsContent = File(outDts).readAsStringSync();
          expect(dtsContent, contains('export interface MiniBridge {'));
          expect(
            dtsContent,
            contains('var __miniBridge: MiniBridge | undefined;'),
          );

          final loaderMjsContent = File(loaderPaths.mjsPath).readAsStringSync();
          expect(
            loaderMjsContent,
            contains('const GLOBAL_NAME = "__miniBridge";'),
          );

          await verifyWithTsc(<String>[outDts, loaderPaths.dtsPath]);

          // 2. Run CLI with --from-ir and --global-name override.
          final fromIrDts = p.join(tempDir.path, 'dist', 'custom.d.ts');
          final run2 = await Process.run(Platform.resolvedExecutable, <String>[
            cliScript,
            '--from-ir',
            outIr,
            '-o',
            fromIrDts,
            '--emit-loader',
            '--global-name',
            '__customGlobalBridge',
          ], workingDirectory: pkgRoot);
          expect(run2.exitCode, 0, reason: 'STDERR: ${run2.stderr}');

          final customLoaderPaths = deriveLoaderPaths(fromIrDts);
          expect(
            File(fromIrDts).readAsStringSync(),
            contains('var __customGlobalBridge: MiniBridge | undefined;'),
          );
          expect(
            File(customLoaderPaths.mjsPath).readAsStringSync(),
            contains('const GLOBAL_NAME = "__customGlobalBridge";'),
          );
          await verifyWithTsc(<String>[fromIrDts, customLoaderPaths.dtsPath]);
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      },
    );
  });

  final invoiceNinjaEntry = File(
    '/usr/local/google/home/kevmoo/github/_invoiceninja_flutter-js-bridge/'
    'packages/admin_js_bridge/lib/admin_js_bridge.dart',
  );

  group(
    'Dogfooding on package:admin_js_bridge (Invoice Ninja)',
    () {
      test(
        'extracts 21 extension types + 15 @JSExport methods and passes tsc',
        () async {
          final ir = await extractInteropIr(invoiceNinjaEntry.path);
          final roundTripped = asIrStringMap(
            jsonDecode(const JsonEncoder.withIndent('  ').convert(ir)),
          );
          validateInteropIr(roundTripped);

          final exports = roundTripped['exports'] as List<Object?>;
          expect(exports, hasLength(1));
          final bridge = exports.first as Map<String, Object?>;
          expect(bridge['jsName'], 'InvoiceninjaDartBridge');
          final members = bridge['members'] as List<Object?>;
          expect(members, hasLength(15));

          final extTypes =
              roundTripped['extensionTypes'] as Map<String, Object?>;
          expect(extTypes, hasLength(21));

          final dts = generateDtsFromInteropIr(roundTripped);
          final loaderDts = generateLoaderDtsFromInteropIr(
            roundTripped,
            dtsBasename: 'bridge.d.ts',
          );
          final loaderMjs = generateLoaderMjsFromInteropIr(
            roundTripped,
            dtsBasename: 'bridge.d.ts',
          );

          expect(
            loaderMjs,
            contains('const GLOBAL_NAME = "__invoiceninjaDartBridge";'),
          );

          final tempDir = Directory.systemTemp.createTempSync(
            'dart_to_dts_invoiceninja_',
          );
          try {
            final dtsFile = File(p.join(tempDir.path, 'bridge.d.ts'))
              ..writeAsStringSync(dts);
            final loaderDtsFile = File(
              p.join(tempDir.path, 'bridge.loader.d.ts'),
            )..writeAsStringSync(loaderDts);
            await verifyWithTsc(<String>[dtsFile.path, loaderDtsFile.path]);
          } finally {
            tempDir.deleteSync(recursive: true);
          }
        },
      );
    },
    skip: !invoiceNinjaEntry.existsSync()
        ? 'Invoice Ninja checkout not present at ${invoiceNinjaEntry.path}'
        : false,
  );
}
