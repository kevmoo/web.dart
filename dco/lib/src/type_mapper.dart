import 'package:code_builder/code_builder.dart' as code;
import 'model.dart';

class TypeMapper {
  code.Reference mapDartType(WitType? type) {
    if (type == null) return code.refer('void');
    return switch (type) {
      PrimitiveWitType(name: 'string') => code.refer('String'),
      PrimitiveWitType(name: 'u64') => code.refer('int'),
      PrimitiveWitType(name: _) => code.refer(
        'int',
      ), // Fallback for other primitives

      ReferenceWitType(id: _) => code.refer('int'), // Fallback for references
    };
  }

  code.Expression mapToJS(WitType type, String name) => switch (type) {
    PrimitiveWitType(name: 'string') => code.refer(name).property('toJS'),
    PrimitiveWitType(name: 'u64') => code.refer('jsBigInt').call([
      code.refer(name).property('toString').call([]),
    ]),
    PrimitiveWitType(name: _) => code.refer(name).property('toJS'),
    ReferenceWitType(id: _) => code.refer(name).property('toJS'),
  };
}
