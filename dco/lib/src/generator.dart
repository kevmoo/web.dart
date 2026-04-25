import 'dart:convert';
import 'dart:io';
import 'package:code_builder/code_builder.dart' as code;
import 'package:dart_style/dart_style.dart';
import 'package:pub_semver/pub_semver.dart';
import 'method_generator.dart';
import 'model.dart';
import 'struct_generator.dart';
import 'utils.dart';

code.Library generateBindingsCore(
  WasmComponentInterface interface,
  WasmPackage package,
  List<WasmType> types,
) {
  final interfaceName = interface.name;
  final functions = interface.functions;

  final className = capitalize(interfaceName);

  final methodGen = MethodGenerator(types);
  final methods = functions
      .map((f) => methodGen.generateMethod(f, interfaceName))
      .toList();

  final structGen = StructGenerator(types);

  final structs = <code.ExtensionType>[];
  for (final type in types) {
    if (type is WasmRecordType) {
      structs.add(structGen.generateStruct(type));
    }
  }

  return code.Library(
    (b) => b
      ..directives.addAll([code.Directive.import('dart:js_interop_unsafe')])
      ..body.addAll([
        // Structs
        ...structs,

        // jsEval helper
        code.Method(
          (b) => b
            ..name = 'jsEval'
            ..external = true
            ..annotations.add(
              code.refer('JS', 'dart:js_interop').call([
                code.literalString('eval'),
              ]),
            )
            ..returns = code.refer('JSAny', 'dart:js_interop')
            ..requiredParameters.add(
              code.Parameter(
                (b) => b
                  ..name = 'code'
                  ..type = code.refer('String'),
              ),
            ),
        ),

        // jsBigInt helper
        code.Method(
          (b) => b
            ..name = 'jsBigInt'
            ..external = true
            ..annotations.add(
              code.refer('JS', 'dart:js_interop').call([
                code.literalString('BigInt'),
              ]),
            )
            ..returns = code.refer('JSAny', 'dart:js_interop')
            ..requiredParameters.add(
              code.Parameter(
                (b) => b
                  ..name = 'value'
                  ..type = code.refer('String'),
              ),
            ),
        ),

        // Class
        code.Class(
          (b) => b
            ..name = className
            ..fields.add(
              code.Field(
                (b) => b
                  ..name = '_module'
                  ..type = code.refer('JSObject', 'dart:js_interop')
                  ..modifier = code.FieldModifier.final$,
              ),
            )
            ..constructors.add(
              code.Constructor(
                (b) => b
                  ..requiredParameters.add(
                    code.Parameter(
                      (b) => b
                        ..name = '_module'
                        ..toThis = true,
                    ),
                  ),
              ),
            )
            ..methods.addAll([
              // load
              code.Method(
                (b) => b
                  ..name = 'load'
                  ..static = true
                  ..returns = code.TypeReference(
                    (b) => b
                      ..symbol = 'Future'
                      ..types.add(code.refer(className)),
                  )
                  ..requiredParameters.add(
                    code.Parameter(
                      (b) => b
                        ..name = 'modulePath'
                        ..type = code.refer('String'),
                    ),
                  )
                  ..body = code.Block.of([
                    code
                        .declareFinal('promise')
                        .assign(
                          code
                              .refer('jsEval')
                              .call([
                                const code.CodeExpression(
                                  code.Code('\'import("\$modulePath")\''),
                                ),
                              ])
                              .asA(code.refer('JSPromise', 'dart:js_interop')),
                        )
                        .statement,
                    code
                        .declareFinal('module')
                        .assign(
                          code
                              .refer('promise')
                              .property('toDart')
                              .awaited
                              .asA(code.refer('JSObject', 'dart:js_interop')),
                        )
                        .statement,
                    code
                        .refer(className)
                        .call([code.refer('module')])
                        .returned
                        .statement,
                  ])
                  ..modifier = code.MethodModifier.async,
              ),
              ...methods,
            ]),
        ),
      ]),
  );
}

String generateBindings(String jsonPath) {
  final jsonFile = File(jsonPath);
  if (!jsonFile.existsSync()) {
    throw Exception('Error: $jsonPath not found.');
  }

  final jsonString = jsonFile.readAsStringSync();
  final data = json.decode(jsonString) as Map<String, dynamic>;

  final model = WitModel.fromJson(data);

  final interface = model.interfaces.firstWhere((i) => i.name == 'add');
  final package = model.packages.firstWhere(
    (p) => p.namespace == 'docs' && p.packageName == 'adder',
  );

  final library = generateBindingsCore(interface, package, model.types);

  final emitter = code.DartEmitter.scoped(orderDirectives: true);

  final source = library.accept(emitter).toString();
  final fullSource = '// ignore_for_file: unnecessary_parenthesis\n\n$source';

  final formatter = DartFormatter(languageVersion: Version(3, 10, 0));
  return formatter.format(fullSource);
}
