import 'dart:convert';
import 'dart:io';
import 'package:code_builder/code_builder.dart' as code;
import 'package:path/path.dart' as p;

Future<void> generateBindings(String jsonPath, String outputPath) async {
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

  final interface = interfaces.first as Map<String, dynamic>;
  final interfaceName = interface['name'] as String;
  final functions = interface['functions'] as Map<String, dynamic>;

  final className = interfaceName[0].toUpperCase() + interfaceName.substring(1);
  final exportsClassName = '${className}Exports';

  final methods = <code.Method>[];
  final exportGetters = <code.Method>[];

  functions.forEach((name, func) {
    final funcMap = func as Map<String, dynamic>;
    final params = funcMap['params'] as List<dynamic>;

    final dartParams = <code.Parameter>[];
    final callArgs = <code.Expression>[];

    for (final p in params) {
      final pMap = p as Map<String, dynamic>;
      final pName = pMap['name'] as String;
      dartParams.add(code.Parameter((b) => b
        ..name = pName
        ..type = code.refer('int')));
      callArgs.add(code.refer(pName).property('toJS'));
    }

    methods.add(code.Method((b) => b
      ..name = name
      ..returns = code.refer('int')
      ..requiredParameters.addAll(dartParams)
      ..body = code.Block.of([
        code.declareVar('result').assign(code.refer('_exports')
            .property('_$name')
            .property('callAsFunction')
            .call([code.literalNull, ...callArgs])
            .asA(code.refer('JSNumber')))
            .statement,
        code.refer('result').property('toDartInt').returned.statement,
      ])));

    exportGetters.add(code.Method((b) => b
      ..name = '_$name'
      ..type = code.MethodType.getter
      ..external = true
      ..annotations.add(code.refer('JS').call([code.literalString(name)]))
      ..returns = code.refer('JSFunction')));
  });

  final library = code.Library((b) => b
    ..directives.addAll([
      code.Directive.import('dart:js_interop'),
      code.Directive.import('package:web/web.dart', as: 'web'),
    ])
    ..body.addAll([
      code.ExtensionType((b) => b
        ..name = exportsClassName
        ..primaryConstructorName = '_'
        ..representationDeclaration = code.RepresentationDeclaration((b) => b
          ..name = '_'
          ..declaredRepresentationType = code.refer('JSObject'))
        ..implements.add(code.refer('JSObject'))
        ..methods.addAll(exportGetters)),

      code.Class((b) => b
        ..name = className
        ..fields.add(code.Field((b) => b
          ..name = '_exports'
          ..type = code.refer(exportsClassName)
          ..modifier = code.FieldModifier.final$))
        ..constructors.add(code.Constructor((b) => b
          ..requiredParameters.add(code.Parameter((b) => b
            ..name = 'instance'
            ..type = code.refer('web.Instance')))
          ..initializers.add(code.refer('_exports')
              .assign(code.refer('instance').property('exports').asA(code.refer(exportsClassName)))
              .code)))
        ..methods.addAll([
          code.Method((b) => b
            ..name = 'instantiateStreaming'
            ..static = true
            ..returns = code.refer('Future<$className>')
            ..requiredParameters.add(code.Parameter((b) => b
              ..name = 'source'
              ..type = code.refer('Future<web.Response>')))
            ..body = code.Block.of([
              code.declareVar('promise').assign(code.refer('web.WebAssembly')
                  .property('instantiateStreaming')
                  .call([code.refer('source').property('toJS')]))
                  .statement,
              code.declareVar('result').assign(code.refer('promise').property('toDart').awaited).statement,
              code.refer(className).call([code.refer('result').property('instance')]).returned.statement,
            ])
            ..modifier = code.MethodModifier.async),
          code.Method((b) => b
            ..name = 'instantiate'
            ..static = true
            ..returns = code.refer('Future<$className>')
            ..requiredParameters.add(code.Parameter((b) => b
              ..name = 'bytes'
              ..type = code.refer('web.BufferSource')))
            ..body = code.Block.of([
              code.declareVar('promise').assign(code.refer('web.WebAssembly')
                  .property('instantiate')
                  .call([code.refer('bytes')]))
                  .statement,
              code.declareVar('result').assign(code.refer('promise').property('toDart').awaited).statement,
              code.declareVar('instantiated').assign(code.refer('result')
                  .asA(code.refer('web.WebAssemblyInstantiatedSource')))
                  .statement,
              code.refer(className).call([code.refer('instantiated').property('instance')]).returned.statement,
            ])
            ..modifier = code.MethodModifier.async),
          ...methods,
        ])),
    ]));

  final emitter = code.DartEmitter(
    allocator: code.Allocator(),
    orderDirectives: true,
    useNullSafetySyntax: true,
  );
  final source = library.accept(emitter).toString();

  final outputFile = File(outputPath);
  final outputDir = outputFile.parent;
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }
  
  outputFile.writeAsStringSync(source);
  print('Generated ${outputFile.path}');

  final result = Process.runSync('dart', ['format', outputFile.path]);
  if (result.exitCode != 0) {
    print('Warning: Failed to format generated file.');
    print(result.stderr);
  } else {
    print('Formatted ${outputFile.path}');
  }
}
