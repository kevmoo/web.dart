import 'package:code_builder/code_builder.dart' as code;
import 'model.dart';

class TypeMapper {
  final List<WasmType> _types;

  TypeMapper(this._types);

  code.Reference mapDartType(WitType? type) {
    if (type == null) return code.refer('void');
    return switch (type) {
      PrimitiveWitType(name: 'string') => code.refer('String'),
      PrimitiveWitType(name: 'u64') => code.refer('int'),
      PrimitiveWitType(name: _) => code.refer(
        'int',
      ), // Fallback for other primitives
      ReferenceWitType(id: final id) => _mapReferenceType(id),
    };
  }

  code.Reference _mapReferenceType(int id) {
    if (id < _types.length) {
      final type = _types[id];
      if (type is WasmRecordType && type.name != null) {
        final name = type.name!;
        final className = name[0].toUpperCase() + name.substring(1);
        return code.refer(className);
      }
    }
    return code.refer('int'); // Fallback
  }

  code.Expression mapToJS(WitType type, String name) => switch (type) {
    PrimitiveWitType(name: 'string') => code.refer(name).property('toJS'),
    PrimitiveWitType(name: 'u64') => code.refer('jsBigInt').call([
      code.refer(name).property('toString').call([]),
    ]),
    PrimitiveWitType(name: _) => code.refer(name).property('toJS'),
    ReferenceWitType(id: final id) => _mapReferenceToJS(id, name),
  };

  code.Expression _mapReferenceToJS(int id, String name) {
    if (id < _types.length) {
      final type = _types[id];
      if (type is WasmRecordType) {
        // Structs are extension types on JSObject, so they are already JS
        // objects!

        return code.refer(name);
      }
    }
    return code.refer(name).property('toJS'); // Fallback
  }
}
