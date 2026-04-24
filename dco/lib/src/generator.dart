import 'dart:convert';
import 'dart:io';
import 'package:code_builder/code_builder.dart' as code;
import 'package:dart_style/dart_style.dart';
import 'model.dart';

code.Library generateBindingsCore(WasmComponentInterface interface) {
  final interfaceName = interface.name;
  final functions = interface.functions;

  final className = interfaceName[0].toUpperCase() + interfaceName.substring(1);
  final exportsClassName = '${className}Exports';

  final methods = <code.Method>[];
  final exportGetters = <code.Method>[];

  for (final func in functions) {
    final name = func.name;
    final params = func.params;

    final dartParams = <code.Parameter>[];
    final callArgs = <code.Expression>[];

    for (final p in params) {
      dartParams.add(
        code.Parameter(
          (b) => b
            ..name = p.name
            ..type = code.refer('int'),
        ),
      );
      callArgs.add(code.refer(p.name).property('toJS'));
    }

    final tempEmitter = code.DartEmitter();
    final argsString = callArgs.map((e) => e.accept(tempEmitter)).join(', ');

    methods.add(
      code.Method(
        (b) => b
          ..name = name
          ..returns = code.refer('int')
          ..requiredParameters.addAll(dartParams)
          ..body = code.Block.of([
            code.Code(
              'final result = _exports._$name.callAsFunction('
              'null, $argsString) as JSNumber;',
            ),

            code.refer('result').property('toDartInt').returned.statement,
          ]),
      ),
    );

    exportGetters.add(
      code.Method(
        (b) => b
          ..name = '_$name'
          ..type = code.MethodType.getter
          ..external = true
          ..annotations.add(code.refer('JS').call([code.literalString(name)]))
          ..returns = code.refer('JSFunction'),
      ),
    );
  }

  return code.Library(
    (b) => b
      ..directives.addAll([
        code.Directive.import('dart:js_interop'),
        code.Directive.import('package:web/web.dart', as: 'web'),
      ])
      ..body.addAll([
        code.ExtensionType(
          (b) => b
            ..name = exportsClassName
            ..primaryConstructorName = '_'
            ..representationDeclaration = code.RepresentationDeclaration(
              (b) => b
                ..name = '_'
                ..declaredRepresentationType = code.refer('JSObject'),
            )
            ..implements.add(code.refer('JSObject'))
            ..methods.addAll(exportGetters),
        ),

        code.Class(
          (b) => b
            ..name = className
            ..fields.add(
              code.Field(
                (b) => b
                  ..name = '_exports'
                  ..type = code.refer(exportsClassName)
                  ..modifier = code.FieldModifier.final$,
              ),
            )
            ..constructors.add(
              code.Constructor(
                (b) => b
                  ..requiredParameters.add(
                    code.Parameter(
                      (b) => b
                        ..name = 'instance'
                        ..type = code.refer('web.Instance'),
                    ),
                  )
                  ..initializers.add(
                    code.Code(
                      '_exports = instance.exports as $exportsClassName',
                    ),
                  ),
              ),
            )
            ..methods.addAll([
              code.Method(
                (b) => b
                  ..name = 'instantiateStreaming'
                  ..static = true
                  ..returns = code.refer('Future<$className>')
                  ..requiredParameters.add(
                    code.Parameter(
                      (b) => b
                        ..name = 'source'
                        ..type = code.refer('Future<web.Response>'),
                    ),
                  )
                  ..body = code.Block.of([
                    const code.Code(
                      'final promise = '
                      'web.WebAssembly.instantiateStreaming(source.toJS);',
                    ),

                    const code.Code('final result = await promise.toDart;'),
                    code.Code('return $className(result.instance);'),
                  ])
                  ..modifier = code.MethodModifier.async,
              ),
              code.Method(
                (b) => b
                  ..name = 'instantiate'
                  ..static = true
                  ..returns = code.refer('Future<$className>')
                  ..requiredParameters.add(
                    code.Parameter(
                      (b) => b
                        ..name = 'bytes'
                        ..type = code.refer('web.BufferSource'),
                    ),
                  )
                  ..body = code.Block.of([
                    const code.Code(
                      'final promise = web.WebAssembly.instantiate(bytes);',
                    ),
                    const code.Code('final result = await promise.toDart;'),
                    const code.Code(
                      'final instantiated = '
                      'result as web.WebAssemblyInstantiatedSource;',
                    ),

                    code.Code('return $className(instantiated.instance);'),
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

  final interfaces = data['interfaces'] as List<dynamic>;
  if (interfaces.isEmpty) {
    throw Exception('Error: No interfaces found in JSON.');
  }

  final interfaceJson = interfaces.first as Map<String, dynamic>;
  final interface = WasmComponentInterface.fromJson(interfaceJson);

  final library = generateBindingsCore(interface);

  final emitter = code.DartEmitter(
    allocator: code.Allocator(),
    orderDirectives: true,
    useNullSafetySyntax: true,
  );
  final source = library.accept(emitter).toString();
  final formatter = DartFormatter(
    languageVersion: DartFormatter.latestShortStyleLanguageVersion,
  );
  return formatter.format(source);
}
