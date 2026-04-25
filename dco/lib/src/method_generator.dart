import 'package:code_builder/code_builder.dart' as code;
import 'model.dart';
import 'type_mapper.dart';

class MethodGenerator {
  final TypeMapper _typeMapper = TypeMapper();

  code.Method generateMethod(WasmFunction func, String interfaceName) {
    final name = func.name;
    final params = func.params;
    final resultType = func.result;

    final dartParams = <code.Parameter>[];
    final callArgs = <code.Expression>[];

    for (final p in params) {
      final pName = p.name;
      dartParams.add(
        code.Parameter(
          (b) => b
            ..name = pName
            ..type = _typeMapper.mapDartType(p.type),
        ),
      );
      callArgs.add(_typeMapper.mapToJS(p.type, pName));
    }

    final bodyStatements = [
      code
          .declareFinal('iface')
          .assign(
            code
                .refer('_module')
                .property('getProperty')
                .call([code.literalString(interfaceName).property('toJS')])
                .asA(code.refer('JSObject', 'dart:js_interop')),
          )
          .statement,
      code
          .declareFinal('func')
          .assign(
            code
                .refer('iface')
                .property('getProperty')
                .call([code.literalString(name).property('toJS')])
                .asA(code.refer('JSFunction', 'dart:js_interop')),
          )
          .statement,
    ];

    if (resultType is PrimitiveWitType && resultType.name == 'string') {
      bodyStatements.addAll([
        code
            .declareFinal('result')
            .assign(
              code
                  .refer('func')
                  .property('callAsFunction')
                  .call([code.literalNull, ...callArgs])
                  .asA(code.refer('JSString', 'dart:js_interop')),
            )
            .statement,
        code.refer('result').property('toDart').returned.statement,
      ]);
    } else if (resultType is PrimitiveWitType && resultType.name == 'u64') {
      bodyStatements.addAll([
        code
            .declareFinal('result')
            .assign(
              code.refer('func').property('callAsFunction').call([
                code.literalNull,
                ...callArgs,
              ]),
            )
            .statement,
        code
            .refer('int')
            .property('parse')
            .call([code.refer('result').property('toString').call([])])
            .returned
            .statement,
      ]);
    } else {
      bodyStatements.addAll([
        code
            .declareFinal('result')
            .assign(
              code.refer('func').property('callAsFunction').call([
                code.literalNull,
                ...callArgs,
              ]),
            )
            .statement,
        code.refer('result').returned.statement,
      ]);
    }

    return code.Method(
      (b) => b
        ..name = name
        ..returns = _typeMapper.mapDartType(resultType)
        ..requiredParameters.addAll(dartParams)
        ..body = code.Block.of(bodyStatements),
    );
  }
}
